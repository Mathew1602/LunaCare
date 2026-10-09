
#    pip install -r requirements.txt
#    export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
#    python seed_patients.py --dry-run
#    python seed_patients.py
#
# Creates 13 demo patients (10 typical, 3 high-risk), 4 doctors, links patients <-> doctors,
# fills missing days of health data for every existing account, and writes doctor notes.
# Never deletes or overwrites existing health logs.

import argparse
import glob
import hashlib
import math
import os
import random
import sys
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import firebase_admin
from firebase_admin import auth, credentials, firestore

PROJECT_ID = "newlunacare"
PASSWORD = "1234567"

START = date(2026, 9, 1)
END = date(2026, 12, 31)
TZ = ZoneInfo("America/Toronto")

COLLECTIONS = ("measurements", "mood_logs", "symptom_logs")
DEFAULT_HOME_METRICS = ["sleep", "activeEnergy", "restingHR", "hrv", "steps"]
SYMPTOM_KEYS = ["Fatigue", "Bleeding", "Hair Loss", "Appetite", "Sleep Trouble"]
SYMPTOM_FIELDS = {
    "Fatigue": "fatigue1to10",
    "Bleeding": "bleeding1to10",
    "Hair Loss": "hairLoss1to10",
    "Appetite": "appetiteIssue1to10",
    "Sleep Trouble": "sleepTrouble1to10",
}

MOODS = [4, 2, 0, -1, -2]
MOOD_TO_1TO5 = {4: 5, 2: 4, 0: 3, -1: 2, -2: 1}
SYMPTOM_LEVELS = [0, 2, 6, 9]
SYMPTOM_TO_1TO10 = {0: (1, 1), 2: (2, 4), 6: (5, 7), 9: (8, 10)}


def persona(mood, symptoms, sleep, steps, hrv, rhr, weight, vo2, efficiency, waso, risk="typical"):
    return {"mood": mood, "symptoms": symptoms, "sleep": sleep, "steps": steps, "hrv": hrv,
            "rhr": rhr, "weight": weight, "vo2": vo2, "efficiency": efficiency, "waso": waso, "risk": risk}


TYPICAL = persona([45, 45, 9, 1, 0], [60, 35, 5, 0], 7.6, 8500, 52, 62, 68, 35, 91.5, 20)

NEW_PATIENTS = [
    ("Sarah", "Thompson", persona([50, 40, 9, 1, 0], [65, 30, 5, 0], 7.8, 11500, 62, 56, 61, 40, 93, 15)),
    ("Priya", "Patel", persona([35, 50, 12, 3, 0], [55, 38, 7, 0], 6.9, 7200, 48, 64, 64, 33, 89, 24)),
    ("Emily", "Nguyen", persona([40, 45, 12, 3, 0], [50, 42, 8, 0], 7.2, 9000, 55, 61, 58, 36, 91, 19)),
    ("Olivia", "Martin", persona([45, 42, 11, 2, 0], [60, 34, 6, 0], 8.1, 6800, 50, 63, 72, 32, 92, 18)),
    ("Hannah", "Kim", persona([30, 50, 15, 5, 0], [45, 45, 10, 0], 6.6, 8000, 46, 65, 60, 34, 88, 26)),
    ("Jessica", "Rossi", persona([55, 38, 6, 1, 0], [70, 27, 3, 0], 7.5, 10200, 58, 59, 66, 38, 92, 17)),
    ("Aisha", "Mohamed", persona([40, 46, 11, 3, 0], [55, 38, 7, 0], 7.0, 7600, 49, 63, 70, 33, 90, 22)),
    ("Chloe", "Tremblay", persona([48, 42, 9, 1, 0], [62, 33, 5, 0], 7.9, 9400, 57, 60, 63, 37, 93, 16)),
    ("Laura", "Garcia", persona([35, 48, 13, 4, 0], [50, 40, 10, 0], 7.1, 6400, 44, 66, 75, 30, 89, 23)),
    ("Natalie", "Wong", persona([45, 44, 10, 1, 0], [58, 36, 6, 0], 7.4, 8800, 53, 62, 59, 36, 91, 20)),
    ("Megan", "Clarke", persona([2, 8, 20, 40, 30], [5, 20, 45, 30], 5.2, 3200, 27, 78, 74, 29, 79, 48, "high")),
    ("Rachel", "Singh", persona([3, 10, 22, 35, 30], [8, 22, 40, 30], 5.6, 4100, 31, 76, 67, 30, 81, 42, "high")),
    ("Danielle", "Brooks", persona([1, 6, 18, 40, 35], [5, 15, 45, 35], 4.9, 2700, 24, 80, 79, 28, 77, 55, "high")),
]

DOCTORS = [
    {"id": "dr-maya-chen", "firstName": "Maya", "lastName": "Chen",
     "specialty": "Family Medicine / Women's Health", "organization": "Oakville Women's Health Centre",
     "cpsoNumber": "000000 (Demo)", "email": "maya.chen@lunacare-demo.ca", "phone": "(905) 555-0142",
     "accessLevel": "Authorized Physician", "authorized": True},
    {"id": "dr-james-okafor", "firstName": "James", "lastName": "Okafor",
     "specialty": "Perinatal Psychiatry", "organization": "Halton Perinatal Mental Health Clinic",
     "cpsoNumber": "000001 (Demo)", "email": "james.okafor@lunacare-demo.ca", "phone": "(905) 555-0187",
     "accessLevel": "Authorized Physician", "authorized": True},
    {"id": "dr-sofia-alvarez", "firstName": "Sofia", "lastName": "Alvarez",
     "specialty": "Obstetrics & Gynecology", "organization": "Mississauga Maternity Associates",
     "cpsoNumber": "000002 (Demo)", "email": "sofia.alvarez@lunacare-demo.ca", "phone": "(905) 555-0119",
     "accessLevel": "Authorized Physician", "authorized": True},
    {"id": "dr-ethan-walsh", "firstName": "Ethan", "lastName": "Walsh",
     "specialty": "Family Medicine", "organization": "Burlington Family Health Team",
     "cpsoNumber": "000003 (Demo)", "email": "ethan.walsh@lunacare-demo.ca", "phone": "(905) 555-0163",
     "accessLevel": "Authorized Physician", "authorized": True},
]
PRIMARY_DOCTOR = "dr-maya-chen"
PSYCHIATRIST = "dr-james-okafor"
OBGYN = "dr-sofia-alvarez"


def parse_args():
    parser = argparse.ArgumentParser(description="Seed LunaCare demo patients and doctors.")
    parser.add_argument("--key", help="Path to service account JSON (defaults to GOOGLE_APPLICATION_CREDENTIALS).")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be written without writing.")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for reproducible data.")
    return parser.parse_args()


def init_firebase(key_path):
    if not key_path and not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        local_keys = sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), f"{PROJECT_ID}-firebase-adminsdk*.json")))
        key_path = local_keys[0] if local_keys else None
    key_path = key_path or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not key_path or not os.path.isfile(key_path):
        sys.exit("Service account key not found. Pass --key, set GOOGLE_APPLICATION_CREDENTIALS, "
                 "or place *firebase-adminsdk*.json next to this script.")
    print(f"Using key: {os.path.basename(key_path)}")
    firebase_admin.initialize_app(credentials.Certificate(key_path), {"projectId": PROJECT_ID})
    return firestore.client()


def stable_rng(base_seed, text):
    digest = hashlib.sha256(f"{base_seed}:{text}".encode()).hexdigest()
    return random.Random(int(digest[:12], 16))


def clamp(value, low, high):
    return max(low, min(high, value))


def jitter(rng, center, spread, low, high, digits=1):
    return float(round(clamp(rng.gauss(center, spread), low, high), digits))


def local_dt(day, hour, minute=0):
    return datetime.combine(day, time(hour, minute), tzinfo=TZ)


def build_day(rng, p, day, index, total_days):
    weekend = day.weekday() >= 5
    seasonal = math.cos(2 * math.pi * index / 7)
    progress = index / max(total_days - 1, 1)
    high = p["risk"] == "high"

    mood = rng.choices(MOODS, weights=p["mood"])[0]
    symptoms = {key: rng.choices(SYMPTOM_LEVELS, weights=p["symptoms"])[0] for key in SYMPTOM_KEYS}

    steps = int(clamp(rng.gauss(p["steps"] * (1.12 if weekend else 1.0), p["steps"] * 0.15),
                      p["steps"] * 0.5, p["steps"] * 1.4))
    sleep_low, sleep_high = (3.5, 7.0) if high else (6.0, 9.0)
    sleep_hours = jitter(rng, p["sleep"] + (0.3 if weekend else 0), 0.45 if high else 0.35, sleep_low, sleep_high, 2)
    deep = round(sleep_hours * rng.uniform(0.10, 0.14) if high else sleep_hours * rng.uniform(0.15, 0.20), 2)
    rem = round(sleep_hours * rng.uniform(0.15, 0.20) if high else sleep_hours * rng.uniform(0.20, 0.25), 2)
    core = round(sleep_hours - deep - rem, 2)
    active_energy = jitter(rng, 420 + (steps - 8500) * 0.03, 40, 120, 650)

    measurement = {
        "mood1to5": float(MOOD_TO_1TO5[mood]),
        **{SYMPTOM_FIELDS[key]: float(rng.randint(*SYMPTOM_TO_1TO10[level])) for key, level in symptoms.items()},
        "steps": steps,
        "distanceWalkedKm": round(steps * 0.00075, 2),
        "flightsClimbed": float(rng.randint(0, 4) if high else rng.randint(3, 12)),
        "activeEnergyKcal": active_energy,
        "basalEnergyKcal": jitter(rng, 1400, 20, 1350, 1450),
        "exerciseMinutes": float(rng.randint(0, 15) if high else rng.randint(20, 50)),
        "standHours": float(rng.randint(4, 8) if high else rng.randint(9, 13)),
        "sunlightHours": jitter(rng, (0.6 if high else 1.4) + 0.8 * (1 - progress) + (0.5 if weekend else 0), 0.4, 0.2, 3.0, 2),
        "avgHeartRateBpm": jitter(rng, p["rhr"] + 13, 2.5, p["rhr"] + 6, p["rhr"] + 20),
        "restingHRBpm": jitter(rng, p["rhr"] - 0.5 * seasonal, 1.8, p["rhr"] - 5, p["rhr"] + 5),
        "walkingHeartRateAvgBpm": jitter(rng, p["rhr"] + 35, 3.5, p["rhr"] + 25, p["rhr"] + 45),
        "hrvSDNNms": jitter(rng, p["hrv"] + 2 * seasonal, 5, max(p["hrv"] - 14, 12), p["hrv"] + 14),
        "respiratoryRateBpm": jitter(rng, 16.5 if high else 14.5, 0.6, 12, 19),
        "oxygenSaturationPct": round(rng.uniform(0.95, 0.98) if high else rng.uniform(0.96, 0.99), 3),
        "vo2Max": jitter(rng, p["vo2"] + (0 if high else 1.5 * progress), 0.6, p["vo2"] - 3, p["vo2"] + 3),
        "sleepHours": sleep_hours,
        "deepSleepHours": deep,
        "remSleepHours": rem,
        "coreSleepHours": core,
        "sleepEfficiencyPct": jitter(rng, p["efficiency"], 1.8, p["efficiency"] - 6, min(p["efficiency"] + 4, 97)),
        "wakeAfterSleepOnsetMin": jitter(rng, p["waso"], 5, max(p["waso"] - 12, 5), p["waso"] + 15),
        "weightKg": round(p["weight"] + (0.5 if high else -2) * progress + rng.uniform(-0.2, 0.2), 1),
    }
    return mood, symptoms, measurement


def build_docs(rng, p, skip_days=None):
    skip_days = skip_days or {}
    total_days = (END - START).days + 1
    docs = []
    for index in range(total_days):
        day = START + timedelta(days=index)
        day_key = day.isoformat()
        mood, symptoms, measurement = build_day(rng, p, day, index, total_days)
        log_time = local_dt(day, 20, rng.randint(0, 59))

        if day_key not in skip_days.get("measurements", ()):
            docs.append(("measurements", day_key, {
                **measurement,
                "createdAt": local_dt(day, 0),
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "source": "seed",
            }))
        if day_key not in skip_days.get("mood_logs", ()):
            docs.append(("mood_logs", f"seed-{day_key}", {
                "mood": mood,
                "createdAt": log_time,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "tags": ["manual"],
                "source": "manual",
            }))
        if day_key not in skip_days.get("symptom_logs", ()):
            docs.append(("symptom_logs", f"seed-{day_key}", {
                "values": symptoms,
                "createdAt": log_time + timedelta(minutes=1),
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "tags": ["manual"],
                "source": "manual",
            }))
    return docs


def existing_days(db, uid):
    user_ref = db.collection("users").document(uid)
    lower, upper = local_dt(START, 0), local_dt(END, 23, 59)
    days = {}
    measurement_docs = {}
    for name in COLLECTIONS:
        found = set()
        for doc in user_ref.collection(name).where("createdAt", ">=", lower).where("createdAt", "<=", upper).stream():
            data = doc.to_dict() or {}
            created = data.get("createdAt")
            day_key = created.astimezone(TZ).date().isoformat() if isinstance(created, datetime) else doc.id
            found.add(day_key)
            if name == "measurements":
                measurement_docs[doc.id] = data
        if name == "measurements":
            for doc in user_ref.collection(name).stream():
                if START.isoformat() <= doc.id <= END.isoformat():
                    found.add(doc.id)
                    measurement_docs.setdefault(doc.id, doc.to_dict() or {})
        days[name] = found
    return days, measurement_docs


def get_or_create_user(email, first, last, dry_run):
    try:
        user = auth.get_user_by_email(email)
        print(f"  {email} already exists: uid={user.uid}")
        return user.uid, False
    except auth.UserNotFoundError:
        pass
    if dry_run:
        print(f"  [dry-run] Would create auth user {email}")
        return f"DRY_RUN_{first.upper()}", True
    user = auth.create_user(email=email, password=PASSWORD, display_name=f"{first} {last}")
    print(f"  Created {email}: uid={user.uid}")
    return user.uid, True


def write_docs(db, uid, docs, dry_run):
    counts = {name: sum(1 for c, _, _ in docs if c == name) for name in COLLECTIONS}
    if dry_run:
        print(f"    [dry-run] Would write {len(docs)} docs: {counts}")
        return
    user_ref = db.collection("users").document(uid)
    for start in range(0, len(docs), 400):
        batch = db.batch()
        for collection, doc_id, data in docs[start:start + 400]:
            batch.set(user_ref.collection(collection).document(doc_id), data)
        batch.commit()
    print(f"    Wrote {len(docs)} docs: {counts}")


def write_new_profile(db, uid, email, first, last, dry_run):
    data = {
        "email": email,
        "firstName": first,
        "lastName": last,
        "displayName": f"{first} {last}",
        "cloudSync": True,
        "homeMetrics": DEFAULT_HOME_METRICS,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    if dry_run:
        print(f"    [dry-run] Would write profile users/{uid}")
        return
    db.collection("users").document(uid).set(data, merge=True)


def fill_missing_profile(db, uid, user_record, dry_run):
    ref = db.collection("users").document(uid)
    profile = ref.get().to_dict() or {}
    name_parts = (user_record.display_name or "").split(" ", 1)
    defaults = {
        "email": user_record.email or "",
        "firstName": name_parts[0] if name_parts[0] else (user_record.email or "User").split("@")[0].capitalize(),
        "lastName": name_parts[1] if len(name_parts) > 1 else "",
        "cloudSync": True,
        "homeMetrics": DEFAULT_HOME_METRICS,
    }
    missing = {k: v for k, v in defaults.items() if k not in profile}
    if "displayName" not in profile:
        first = profile.get("firstName", defaults["firstName"])
        last = profile.get("lastName", defaults["lastName"])
        missing["displayName"] = f"{first} {last}".strip()
    if "createdAt" not in profile:
        missing["createdAt"] = firestore.SERVER_TIMESTAMP
    if not missing:
        return profile
    print(f"    Filling missing profile fields: {sorted(missing)}")
    if not dry_run:
        ref.set({**missing, "updatedAt": firestore.SERVER_TIMESTAMP}, merge=True)
    return {**profile, **missing}


def assign_doctors(rng, risk, force_primary):
    others = [d["id"] for d in DOCTORS]
    chosen = []
    if force_primary:
        chosen.append(PRIMARY_DOCTOR)
    if risk == "high":
        chosen.append(PSYCHIATRIST)
    target = rng.randint(max(len(chosen), 2 if risk == "high" else 1), 3)
    pool = [d for d in others if d not in chosen]
    rng.shuffle(pool)
    while len(chosen) < target:
        chosen.append(pool.pop())
    return chosen


def mean(values):
    values = [v for v in values if isinstance(v, (int, float))]
    return sum(values) / len(values) if values else None


def comment_window(measurements_by_day):
    today = min(max(date.today(), START), END)
    days = sorted(k for k in measurements_by_day if k <= today.isoformat())[-14:]
    if not days:
        days = sorted(measurements_by_day)[:14]
    return days


def metric_comments(measurements_by_day):
    days = comment_window(measurements_by_day)
    if not days:
        return []
    rows = [measurements_by_day[d] for d in days]
    avg = lambda field: mean(r.get(field) for r in rows)
    last_day = days[-1]
    found = []

    sleep = avg("sleepHours")
    if sleep is not None:
        if sleep < 6.5:
            text = (f"Your sleep has averaged {sleep:.1f}h over the last two weeks, which is below the 7h we aim for. "
                    "Short sleep can make mood symptoms harder to manage. Let's talk about a wind-down routine and "
                    "whether someone can cover a night feed so you get one longer stretch.")
        else:
            text = (f"Sleep is averaging {sleep:.1f}h over the last two weeks. That's a healthy range, so keep "
                    "protecting that routine.")
        found.append(("sleep", text, sleep < 6.5))

    hrv = avg("hrvSDNNms")
    if hrv is not None:
        if hrv < 38:
            text = (f"Your HRV has averaged {hrv:.0f} ms recently, which points to higher physiological stress. "
                    "Gentle breathing exercises and short walks can help. We'll keep an eye on this trend.")
        else:
            text = f"HRV is steady at about {hrv:.0f} ms, a good sign of recovery. No changes needed."
        found.append(("hrv", text, hrv < 38))

    rhr = avg("restingHRBpm")
    if rhr is not None:
        if rhr > 70:
            text = (f"Resting heart rate is averaging {rhr:.0f} bpm, which is higher than I'd like. Please make sure "
                    "you're hydrating and resting, and mention any palpitations at your next visit.")
        else:
            text = f"Resting heart rate is around {rhr:.0f} bpm, well within normal range."
        found.append(("restingHR", text, rhr > 70))

    steps = avg("steps")
    if steps is not None:
        if steps < 5000:
            text = (f"Daily steps are averaging about {steps:,.0f}. Even a 10-15 minute walk outside each day can "
                    "lift mood and energy. Let's set a small goal of 5,000 steps.")
        else:
            text = f"Great activity levels, averaging about {steps:,.0f} steps a day. Keep it up."
        found.append(("steps", text, steps < 5000))

    mood = avg("mood1to5")
    if mood is not None:
        if mood < 3:
            text = (f"Your mood check-ins have averaged {mood:.1f}/5 over the last two weeks. I'd like to book a "
                    "follow-up to talk about how you're feeling.")
        else:
            text = f"Mood check-ins have averaged {mood:.1f}/5. Thank you for logging consistently, this really helps."
        found.append(("mood", text, mood < 3))

    symptom_avg = mean(avg(f) for f in SYMPTOM_FIELDS.values())
    if symptom_avg is not None:
        if symptom_avg >= 4.5:
            text = (f"Symptom severity is averaging {symptom_avg:.1f}/10, with fatigue and sleep trouble standing out. "
                    "Let's review these together and consider bloodwork to rule out anemia or thyroid changes.")
        else:
            text = f"Symptoms are mild, averaging {symptom_avg:.1f}/10. Keep logging so we can spot any changes early."
        found.append(("symptoms", text, symptom_avg >= 4.5))

    return [(metric, text, concern, last_day) for metric, text, concern in found]


def doctor_for_metric(metric, doctor_ids, rng):
    preferred = {"mood": PSYCHIATRIST, "symptoms": OBGYN, "hrv": PSYCHIATRIST}.get(metric)
    if preferred in doctor_ids:
        return preferred
    if PRIMARY_DOCTOR in doctor_ids:
        return PRIMARY_DOCTOR
    return rng.choice(doctor_ids)


def build_comments(rng, measurements_by_day, doctor_ids):
    candidates = metric_comments(measurements_by_day)
    concerns = [c for c in candidates if c[2]]
    positives = [c for c in candidates if not c[2]]
    rng.shuffle(positives)
    picked = concerns + positives[:max(0, rng.randint(3, 6) - len(concerns))]
    picked = picked[:6]

    doctors = {d["id"]: d for d in DOCTORS}
    today = datetime.now(TZ)
    comments = []
    for offset, (metric, text, _, day_key) in enumerate(picked):
        doctor_id = doctor_for_metric(metric, doctor_ids, rng)
        doctor = doctors[doctor_id]
        comments.append((f"{doctor_id}-{metric}", {
            "doctorId": doctor_id,
            "doctorName": f"Dr. {doctor['firstName']} {doctor['lastName']}",
            "metric": metric,
            "dayKey": day_key,
            "text": text,
            "createdAt": today - timedelta(days=offset, hours=rng.randint(1, 8)),
        }))
    return comments


def write_links_and_comments(db, uid, doctor_ids, comments, dry_run):
    if dry_run:
        print(f"    [dry-run] Would link doctors {doctor_ids} and write {len(comments)} comments")
        for doc_id, data in comments:
            print(f"      - {data['metric']} ({data['doctorName']}): {data['text'][:70]}...")
        return
    user_ref = db.collection("users").document(uid)
    batch = db.batch()
    batch.set(user_ref, {"doctorIds": firestore.ArrayUnion(doctor_ids)}, merge=True)
    for doctor_id in doctor_ids:
        batch.set(db.collection("doctors").document(doctor_id),
                  {"patientIds": firestore.ArrayUnion([uid])}, merge=True)
    for doc_id, data in comments:
        batch.set(user_ref.collection("doctor_notes").document(doc_id), data)
    batch.commit()
    print(f"    Linked doctors {doctor_ids}, wrote {len(comments)} comments")


def write_doctors(db, dry_run):
    for doctor in DOCTORS:
        data = {k: v for k, v in doctor.items() if k != "id"}
        if dry_run:
            print(f"  [dry-run] Would write doctors/{doctor['id']}")
            continue
        db.collection("doctors").document(doctor["id"]).set({
            **data,
            "createdAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)
        print(f"  Wrote doctors/{doctor['id']}")


def measurements_from_docs(docs):
    return {doc_id: data for collection, doc_id, data in docs if collection == "measurements"}


def main():
    args = parse_args()
    db = init_firebase(args.key)
    summary = {"created": 0, "new_existing": 0, "existing": 0, "docs": 0, "comments": 0}
    doctor_patients = {d["id"]: 0 for d in DOCTORS}

    print("Doctors:")
    write_doctors(db, args.dry_run)

    new_emails = set()
    print("\nNew patients:")
    for first, last, p in NEW_PATIENTS:
        email = f"{first.lower()}@gmail.com"
        new_emails.add(email)
        rng = stable_rng(args.seed, email)
        uid, created = get_or_create_user(email, first, last, args.dry_run)
        summary["created" if created else "new_existing"] += 1
        print(f"    persona={p['risk']}")
        write_new_profile(db, uid, email, first, last, args.dry_run)
        docs = build_docs(rng, p)
        write_docs(db, uid, docs, args.dry_run)
        summary["docs"] += len(docs)

        doctor_ids = assign_doctors(rng, p["risk"], force_primary=False)
        comments = build_comments(rng, measurements_from_docs(docs), doctor_ids)
        write_links_and_comments(db, uid, doctor_ids, comments, args.dry_run)
        summary["comments"] += len(comments)
        for doctor_id in doctor_ids:
            doctor_patients[doctor_id] += 1

    print("\nExisting accounts:")
    for user in auth.list_users().iterate_all():
        if (user.email or "").lower() in new_emails:
            continue
        summary["existing"] += 1
        print(f"  {user.email or '(no email)'} uid={user.uid}")
        rng = stable_rng(args.seed, user.uid)
        fill_missing_profile(db, user.uid, user, args.dry_run)

        skip, existing_measurements = existing_days(db, user.uid)
        print(f"    existing days: " + ", ".join(f"{k}={len(v)}" for k, v in skip.items()))
        docs = build_docs(rng, TYPICAL, skip)
        write_docs(db, user.uid, docs, args.dry_run)
        summary["docs"] += len(docs)

        doctor_ids = assign_doctors(rng, "typical", force_primary=True)
        all_measurements = {**measurements_from_docs(docs), **existing_measurements}
        comments = build_comments(rng, all_measurements, doctor_ids)
        write_links_and_comments(db, user.uid, doctor_ids, comments, args.dry_run)
        summary["comments"] += len(comments)
        for doctor_id in doctor_ids:
            doctor_patients[doctor_id] += 1

    print("\nSummary:")
    print(f"  New users created: {summary['created']} (already existed: {summary['new_existing']})")
    print(f"  Existing accounts updated: {summary['existing']}")
    print(f"  Health docs {'to write' if args.dry_run else 'written'}: {summary['docs']}")
    print(f"  Doctor comments: {summary['comments']}")
    print(f"  Patients per doctor (this run): {doctor_patients}")
    print("Dry run complete." if args.dry_run else "Done.")


if __name__ == "__main__":
    main()
