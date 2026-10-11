"""training_samples/{pseudoId} sync: one doctor-labelled 30-day window per opted-in mother."""
import math
from datetime import datetime, timedelta, timezone

from google.cloud import firestore

from schema import X_COLUMNS

SNAPSHOT_MAX_AGE = timedelta(days=14)
PENDING_MAX_AGE = timedelta(days=30)
LABEL_VALUE = {"ppd": 1.0, "no_ppd": 0.0}
_X_SET = set(X_COLUMNS)


def watched(d: dict) -> tuple:
    label = d.get("ppdLabel") or {}
    consent = (d.get("consent") or {}).get("contributeToModel")
    return label.get("status"), label.get("verifiedAt"), consent, d.get("flPseudoId")


def clean_features(features) -> dict | None:
    """Client-written snapshot features -> {X_COLUMN: float | None}, or None if anything is malformed."""
    if not isinstance(features, dict) or not features or not set(features) <= _X_SET:
        return None
    out = {}
    for k, v in features.items():
        if v is None:
            out[k] = None
        elif isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v):
            out[k] = float(v)
        else:
            return None
    return out


def latest_snapshot_before(db, pid: str, verified_at):
    """Newest snapshot whose window ends on or before the verification (no post-diagnosis leakage)."""
    snaps = (db.collection("fl_contributions").document(pid).collection("snapshots")
             .where(filter=firestore.FieldFilter("windowEnd", "<=", verified_at))
             .order_by("windowEnd", direction=firestore.Query.DESCENDING)
             .limit(1).get())
    if not snaps or verified_at - snaps[0].get("windowEnd") > SNAPSHOT_MAX_AGE:
        return None
    return snaps[0]


def delete_contributions(db, pid: str) -> None:
    """Server-side opt-out cleanup, so a failed client delete never leaves data behind."""
    db.recursive_delete(db.collection("fl_contributions").document(pid))


def sync_sample(db, pid: str, user: dict, now: datetime = None) -> str:
    """Create, mark pending, expire or delete training_samples/{pid} from the user doc. Returns the action."""
    ref = db.collection("training_samples").document(pid)
    label = user.get("ppdLabel") or {}
    status = label.get("status", "unverified")
    consent = (user.get("consent") or {}).get("contributeToModel", False)
    verified_at = label.get("verifiedAt")

    if not consent or status not in LABEL_VALUE or verified_at is None:
        ref.delete()
        return "deleted"

    snap = latest_snapshot_before(db, pid, verified_at)
    if snap is None:
        if (now or datetime.now(timezone.utc)) - verified_at > PENDING_MAX_AGE:
            ref.delete()
            print(f"training_samples/{pid[:8]}…: expired, no snapshot within "
                  f"{SNAPSHOT_MAX_AGE.days} days before verifiedAt; re-verify after the next upload")
            return "expired"
        ref.set({"pending": True, "labelStatus": status, "verifiedAt": verified_at})
        return "pending"

    features = clean_features(snap.get("features"))
    if features is None:
        ref.delete()
        print(f"training_samples/{pid[:8]}…: snapshot {snap.id} has malformed features")
        return "invalid"

    ref.set({
        "pending": False,
        "features": features,
        "label": LABEL_VALUE[status],
        "labelStatus": status,
        "verifiedAt": verified_at,
        "snapshotId": snap.id,
        "featureSchemaVersion": snap.get("featureSchemaVersion"),
        "usedInVersion": None,
        "createdAt": firestore.SERVER_TIMESTAMP,
    })
    return "ready"


def resolve_pending(db, now: datetime = None) -> dict:
    """Retry pending samples (label set before a recent snapshot existed); expire old ones."""
    counts = {"ready": 0, "pending": 0, "deleted": 0, "expired": 0, "invalid": 0}
    for doc in db.collection("training_samples").where(filter=firestore.FieldFilter("pending", "==", True)).stream():
        users = (db.collection("users").where(filter=firestore.FieldFilter("flPseudoId", "==", doc.id))
                 .limit(1).get())
        action = sync_sample(db, doc.id, users[0].to_dict() if users else {}, now)
        counts[action] += 1
    return counts
