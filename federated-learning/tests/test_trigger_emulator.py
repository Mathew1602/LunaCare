"""Step 7 trigger in the emulator:
firebase emulators:exec --only firestore,functions "functions-ml/venv/bin/python -m pytest tests/test_trigger_emulator.py"
"""
import os
import time
from datetime import datetime, timedelta, timezone

import pytest

pytestmark = pytest.mark.skipif(not os.environ.get("FIRESTORE_EMULATOR_HOST"), reason="needs Firestore emulator")

PID = "pid-emu"
UID = "uid-emu"


@pytest.fixture(scope="module")
def db():
    from google.auth.credentials import AnonymousCredentials
    from google.cloud import firestore
    return firestore.Client(project="newlunacare", credentials=AnonymousCredentials())


def sample(db):
    return db.collection("training_samples").document(PID)


def wait_for(db, predicate, timeout=30):
    deadline = time.time() + timeout
    while time.time() < deadline:
        snap = sample(db).get()
        if predicate(snap):
            return snap
        time.sleep(0.5)
    raise AssertionError(f"timeout, sample = {snap.to_dict() if snap.exists else None}")


def test_sample_lifecycle(db):
    from google.cloud import firestore

    user = db.collection("users").document(UID)
    now = datetime.now(timezone.utc)
    user.set({"consent": {"contributeToModel": True}, "flPseudoId": PID})

    user.set({"ppdLabel": {"status": "ppd", "verifiedAt": now - timedelta(days=20), "verifiedBy": "t"}}, merge=True)
    snap = wait_for(db, lambda s: s.exists and s.get("pending") is True)
    assert snap.get("labelStatus") == "ppd"

    db.collection("fl_contributions").document(PID).collection("snapshots").document("old").set(
        {"features": {"steps_mean": 1.0}, "windowEnd": now - timedelta(days=40), "featureSchemaVersion": 1})
    db.collection("fl_contributions").document(PID).collection("snapshots").document("after").set(
        {"features": {"steps_mean": 9.0}, "windowEnd": now + timedelta(days=1), "featureSchemaVersion": 1})
    db.collection("fl_contributions").document(PID).collection("snapshots").document("recent").set(
        {"features": {"steps_mean": 5.0}, "windowEnd": now - timedelta(days=3), "featureSchemaVersion": 1})

    user.set({"ppdLabel": {"status": "ppd", "verifiedAt": firestore.SERVER_TIMESTAMP, "verifiedBy": "t"}}, merge=True)
    snap = wait_for(db, lambda s: s.exists and s.get("pending") is False)
    assert snap.get("label") == 1.0 and snap.get("snapshotId") == "recent"
    assert snap.get("features") == {"steps_mean": 5.0}

    user.set({"ppdLabel": {"status": "no_ppd", "verifiedAt": firestore.SERVER_TIMESTAMP, "verifiedBy": "t"}}, merge=True)
    snap = wait_for(db, lambda s: s.exists and s.get("labelStatus") == "no_ppd")
    assert snap.get("label") == 0.0

    user.set({"ppdLabel": {"status": "unverified", "verifiedAt": firestore.SERVER_TIMESTAMP, "verifiedBy": "t"}}, merge=True)
    wait_for(db, lambda s: not s.exists)

    user.set({"ppdLabel": {"status": "ppd", "verifiedAt": firestore.SERVER_TIMESTAMP, "verifiedBy": "t"}}, merge=True)
    wait_for(db, lambda s: s.exists and s.get("label") == 1.0)
    user.set({"consent": {"contributeToModel": False}}, merge=True)
    wait_for(db, lambda s: not s.exists)

    contributions = db.collection("fl_contributions").document(PID).collection("snapshots")
    deadline = time.time() + 30
    while len(contributions.get()) and time.time() < deadline:
        time.sleep(0.5)
    assert not contributions.get(), "opt-out must delete contributions server-side"

    contributions.document("recent").set(
        {"features": {"steps_mean": 5.0}, "windowEnd": now - timedelta(days=3), "featureSchemaVersion": 1})
    user.set({"consent": {"contributeToModel": True}}, merge=True)
    snap = wait_for(db, lambda s: s.exists and s.get("pending") is False)
    assert snap.get("label") == 1.0 and snap.get("snapshotId") == "recent"
    user.delete()
    wait_for(db, lambda s: not s.exists)


def test_resolve_pending(db):
    from build_training_sample import resolve_pending

    now = datetime.now(timezone.utc)
    db.collection("users").document("uid-p").set({
        "consent": {"contributeToModel": True}, "flPseudoId": "pid-p",
        "ppdLabel": {"status": "no_ppd", "verifiedAt": now, "verifiedBy": "t"}})
    deadline = time.time() + 30
    while not db.collection("training_samples").document("pid-p").get().exists and time.time() < deadline:
        time.sleep(0.5)
    db.collection("fl_contributions").document("pid-p").collection("snapshots").document("s").set(
        {"features": {"steps_mean": 2.0}, "windowEnd": now - timedelta(days=1), "featureSchemaVersion": 1})

    counts = resolve_pending(db)
    assert counts["ready"] >= 1
    assert db.collection("training_samples").document("pid-p").get().get("label") == 0.0


def test_snapshot_after_label_expires(db):
    """Strict leakage rule: a snapshot uploaded after verification never qualifies; pending expires after 30 days."""
    from build_training_sample import PENDING_MAX_AGE, resolve_pending

    now = datetime.now(timezone.utc)
    db.collection("users").document("uid-x").set({
        "consent": {"contributeToModel": True}, "flPseudoId": "pid-x",
        "ppdLabel": {"status": "ppd", "verifiedAt": now, "verifiedBy": "t"}})
    ref = db.collection("training_samples").document("pid-x")
    deadline = time.time() + 30
    while not ref.get().exists and time.time() < deadline:
        time.sleep(0.5)
    db.collection("fl_contributions").document("pid-x").collection("snapshots").document("later").set(
        {"features": {"steps_mean": 2.0}, "windowEnd": now + timedelta(hours=1), "featureSchemaVersion": 1})

    resolve_pending(db, now=now + timedelta(days=1))
    assert ref.get().get("pending") is True
    counts = resolve_pending(db, now=now + PENDING_MAX_AGE + timedelta(days=1))
    assert counts["expired"] >= 1 and not ref.get().exists


def test_malformed_snapshot_is_not_used(db):
    from build_training_sample import sync_sample

    now = datetime.now(timezone.utc)
    db.collection("fl_contributions").document("pid-bad").collection("snapshots").document("s").set(
        {"features": {"steps_mean": "abc"}, "windowEnd": now - timedelta(days=1), "featureSchemaVersion": 1})
    user = {"consent": {"contributeToModel": True}, "flPseudoId": "pid-bad",
            "ppdLabel": {"status": "ppd", "verifiedAt": now, "verifiedBy": "t"}}
    assert sync_sample(db, "pid-bad", user) == "invalid"
    assert not db.collection("training_samples").document("pid-bad").get().exists


def test_retrain_lock(db):
    from weekly_retrain import LOCK_TTL, acquire_lock, release_lock

    db.collection("training_runs").document("_lock").delete()
    now = datetime.now(timezone.utc)
    assert acquire_lock(db, "run-a", now)
    assert not acquire_lock(db, "run-b", now)
    release_lock(db, "run-b")
    assert not acquire_lock(db, "run-b", now)
    assert acquire_lock(db, "run-c", now + LOCK_TTL + timedelta(minutes=1))
    release_lock(db, "run-c")
    assert not db.collection("training_runs").document("_lock").get().exists
