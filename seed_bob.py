
#    pip install -r requirements.txt
#    export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
#    python seed_bob.py --dry-run
#    python seed_bob.py [--wipe]
#

import argparse
import glob
import json
import math
import os
import random
import sys
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import firebase_admin
from firebase_admin import auth, credentials, firestore

PROJECT_ID = "lunacare-d181e"
BOB_EMAIL = "bob@gmail.com"
BOB_PASSWORD = "1234567"
BOB_FIRST_NAME = "Bob"
REFERENCE_EMAIL = "mattboyd1602@gmail.com"

START = date(2026, 9, 1)
END = date(2026, 12, 31)
TZ = ZoneInfo("America/Toronto")

COLLECTIONS = ("measurements", "mood_logs", "symptom_logs")
DEFAULT_HOME_METRICS = ["sleep", "activeEnergy", "restingHR", "hrv", "steps"]
SYMPTOM_KEYS = ["Fatigue", "Bleeding", "Hair Loss", "Appetite", "Sleep Trouble"]

MOOD_TO_1TO5 = {4: 5, 2: 4, 0: 3, -1: 2, -2: 1}

MEASUREMENT_FIELDS = [
    "mood1to5", "bleeding1to10", "hairLoss1to10", "appetiteIssue1to10", "sleepTrouble1to10",
    "steps", "distanceWalkedKm", "flightsClimbed", "activeEnergyKcal", "basalEnergyKcal",
    "exerciseMinutes", "standHours", "sunlightHours",
    "avgHeartRateBpm", "restingHRBpm", "walkingHeartRateAvgBpm", "hrvSDNNms",
    "respiratoryRateBpm", "oxygenSaturationPct", "vo2Max",
    "sleepHours", "deepSleepHours", "remSleepHours", "coreSleepHours",
    "sleepEfficiencyPct", "wakeAfterSleepOnsetMin", "weightKg",
]


def parse_args():
    parser = argparse.ArgumentParser(description="Seed LunaCare test user Bob.")
    parser.add_argument("--key", help="Path to service account JSON (defaults to GOOGLE_APPLICATION_CREDENTIALS).")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be written without writing.")
    parser.add_argument("--wipe", action="store_true", help="Delete Bob's existing docs in the seeded collections first.")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for reproducible data.")
    return parser.parse_args()


def init_firebase(key_path):
    if not key_path and not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        local_keys = sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "*firebase-adminsdk*.json")))
        key_path = local_keys[0] if local_keys else None
    key_path = key_path or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not key_path or not os.path.isfile(key_path):
        sys.exit("Service account key not found. Pass --key, set GOOGLE_APPLICATION_CREDENTIALS, "
                 "or place *firebase-adminsdk*.json next to this script.")
    print(f"Using key: {os.path.basename(key_path)}")
    firebase_admin.initialize_app(credentials.Certificate(key_path), {"projectId": PROJECT_ID})
    return firestore.client()


def get_or_create_bob(dry_run):
    try:
        user = auth.get_user_by_email(BOB_EMAIL)
        print(f"Bob already exists: uid={user.uid}")
        return user.uid
    except auth.UserNotFoundError:
        pass
    if dry_run:
        print("[dry-run] Would create auth user bob@gmail.com")
        return "DRY_RUN_UID"
    user = auth.create_user(email=BOB_EMAIL, password=BOB_PASSWORD, display_name=BOB_FIRST_NAME)
    print(f"Created Bob: uid={user.uid}")
    return user.uid


def inspect_reference_user(db):
    try:
        ref_uid = auth.get_user_by_email(REFERENCE_EMAIL).uid
    except auth.UserNotFoundError:
        print(f"Reference user {REFERENCE_EMAIL} not found; using app schema only.")
        return {}, {}

    user_ref = db.collection("users").document(ref_uid)
    profile = (user_ref.get().to_dict() or {})
    shapes = {"users": sorted(profile.keys())}
    for name in COLLECTIONS:
        docs = list(user_ref.collection(name).limit(1).stream())
        shapes[name] = sorted(docs[0].to_dict().keys()) if docs else []

    print(f"Reference user {REFERENCE_EMAIL} (uid={ref_uid}) fields:")
    for name, keys in shapes.items():
        print(f"  {name}: {keys if keys else '(no docs)'}")

    ref_measurement_keys = set(shapes["measurements"]) - {"createdAt", "updatedAt", "source"}
    extra = ref_measurement_keys - set(MEASUREMENT_FIELDS)
    missing = set(MEASUREMENT_FIELDS) - ref_measurement_keys
    if extra:
        print(f"  WARNING: reference measurements has fields not generated: {sorted(extra)}")
    if shapes["measurements"] and missing:
        print(f"  Note: generating fields the reference sample lacks: {sorted(missing)}")
    return profile, shapes


def clamp(value, low, high):
    return max(low, min(high, value))


def jitter(rng, center, spread, low, high, digits=1):
    return float(round(clamp(rng.gauss(center, spread), low, high), digits))


def local_dt(day, hour, minute=0):
    return datetime.combine(day, time(hour, minute), tzinfo=TZ)


def pick_mood(rng):
    return rng.choices([4, 2, 0, -1], weights=[45, 45, 9, 1])[0]


def pick_symptom(rng):
    return rng.choices([0, 2, 6], weights=[60, 35, 5])[0]


def build_day(rng, day, index, total_days):
    weekend = day.weekday() >= 5
    seasonal = math.cos(2 * math.pi * index / 7)
    progress = index / max(total_days - 1, 1)

    mood = pick_mood(rng)
    symptoms = {key: pick_symptom(rng) for key in SYMPTOM_KEYS}

    steps = int(clamp(rng.gauss(9500 if weekend else 8200, 1200), 6000, 11000))
    sleep_hours = jitter(rng, 8.0 if weekend else 7.5, 0.35, 7.0, 8.5, 2)
    deep = round(sleep_hours * rng.uniform(0.15, 0.20), 2)
    rem = round(sleep_hours * rng.uniform(0.20, 0.25), 2)
    core = round(sleep_hours - deep - rem, 2)

    measurement = {
        "mood1to5": float(MOOD_TO_1TO5[mood]),
        "bleeding1to10": float(rng.choice([1, 1, 1, 2])),
        "hairLoss1to10": float(rng.choice([1, 1, 2, 3])),
        "appetiteIssue1to10": float(rng.choice([1, 1, 1, 2])),
        "sleepTrouble1to10": float(rng.choice([1, 1, 2, 3])),
        "steps": steps,
        "distanceWalkedKm": round(steps * 0.00075, 2),
        "flightsClimbed": float(rng.randint(3, 12)),
        "activeEnergyKcal": jitter(rng, 420 + (steps - 8500) * 0.03, 40, 300, 550),
        "basalEnergyKcal": jitter(rng, 1400, 20, 1350, 1450),
        "exerciseMinutes": float(rng.randint(20, 50)),
        "standHours": float(rng.randint(9, 13)),
        "sunlightHours": jitter(rng, 1.4 + 0.8 * (1 - progress) + (0.5 if weekend else 0), 0.4, 1.0, 3.0, 2),
        "avgHeartRateBpm": jitter(rng, 75, 2.5, 70, 80),
        "restingHRBpm": jitter(rng, 62 - 0.5 * seasonal, 1.8, 58, 66),
        "walkingHeartRateAvgBpm": jitter(rng, 97, 3.5, 90, 105),
        "hrvSDNNms": jitter(rng, 52 + 2 * seasonal, 5, 40, 65),
        "respiratoryRateBpm": jitter(rng, 14.5, 0.6, 13, 16),
        "oxygenSaturationPct": round(rng.uniform(0.96, 0.99), 3),
        "vo2Max": jitter(rng, 35 + 1.5 * progress, 0.6, 33, 38),
        "sleepHours": sleep_hours,
        "deepSleepHours": deep,
        "remSleepHours": rem,
        "coreSleepHours": core,
        "sleepEfficiencyPct": jitter(rng, 91.5, 1.8, 88, 95),
        "wakeAfterSleepOnsetMin": jitter(rng, 20, 5, 10, 30),
        "weightKg": round(68 - 2 * progress + rng.uniform(-0.2, 0.2), 1),
    }
    return mood, symptoms, measurement


def build_docs(total_days, rng):
    docs = []
    for index in range(total_days):
        day = START + timedelta(days=index)
        day_key = day.isoformat()
        mood, symptoms, measurement = build_day(rng, day, index, total_days)
        log_time = local_dt(day, 20, rng.randint(0, 59))

        docs.append(("measurements", day_key, {
            **measurement,
            "createdAt": local_dt(day, 0),
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "source": "seed",
        }))
        docs.append(("mood_logs", f"seed-{day_key}", {
            "mood": mood,
            "createdAt": log_time,
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "tags": ["manual"],
            "source": "manual",
        }))
        docs.append(("symptom_logs", f"seed-{day_key}", {
            "values": symptoms,
            "createdAt": log_time + timedelta(minutes=1),
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "tags": ["manual"],
            "source": "manual",
        }))
    return docs


def wipe(db, uid):
    user_ref = db.collection("users").document(uid)
    for name in COLLECTIONS:
        deleted = 0
        while True:
            batch_docs = list(user_ref.collection(name).limit(400).stream())
            if not batch_docs:
                break
            batch = db.batch()
            for doc in batch_docs:
                batch.delete(doc.reference)
            batch.commit()
            deleted += len(batch_docs)
        print(f"Wiped {deleted} docs from {name}")


def write_profile(db, uid, reference_profile):
    home_metrics = reference_profile.get("homeMetrics") or DEFAULT_HOME_METRICS
    db.collection("users").document(uid).set({
        "email": BOB_EMAIL,
        "firstName": BOB_FIRST_NAME,
        "lastName": "",
        "displayName": BOB_FIRST_NAME,
        "cloudSync": True,
        "homeMetrics": home_metrics,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }, merge=True)
    print(f"Wrote profile users/{uid} (cloudSync=True, homeMetrics={home_metrics})")


def write_docs(db, uid, docs):
    user_ref = db.collection("users").document(uid)
    for start in range(0, len(docs), 400):
        batch = db.batch()
        for collection, doc_id, data in docs[start:start + 400]:
            batch.set(user_ref.collection(collection).document(doc_id), data)
        batch.commit()
    counts = {name: sum(1 for c, _, _ in docs if c == name) for name in COLLECTIONS}
    print(f"Wrote {len(docs)} docs: {counts}")


def main():
    args = parse_args()
    db = init_firebase(args.key)
    rng = random.Random(args.seed)
    total_days = (END - START).days + 1

    reference_profile, _ = inspect_reference_user(db)
    uid = get_or_create_bob(args.dry_run)
    docs = build_docs(total_days, rng)

    if args.dry_run:
        print(f"[dry-run] {total_days} days, {len(docs)} docs. Sample day:")
        for collection, doc_id, data in docs[:3]:
            printable = {k: (v.isoformat() if isinstance(v, datetime) else str(v) if k == "updatedAt" else v)
                         for k, v in data.items()}
            print(f"  users/{uid}/{collection}/{doc_id}:")
            print("   ", json.dumps(printable, indent=2).replace("\n", "\n    "))
        return

    if args.wipe:
        wipe(db, uid)
    write_profile(db, uid, reference_profile)
    write_docs(db, uid, docs)
    print("Done.")


if __name__ == "__main__":
    main()
