"""Set a doctor-verified PPD label on users/{uid}.ppdLabel (admin SDK, bypasses rules).

Usage (from repo root, inside functions-ml venv):
    python federated-learning/scripts/set_ppd_label.py --uid <uid> --status ppd|no_ppd|unverified [--by demo-doctor]
    python federated-learning/scripts/set_ppd_label.py --email <email> --status ppd
    python federated-learning/scripts/set_ppd_label.py --list

GOOGLE_APPLICATION_CREDENTIALS defaults to ~/Downloads/newlunacare-firebase-adminsdk-fbsvc-0968d9f0e2.json.
"""
import argparse

from _admin import init_admin
from firebase_admin import auth, firestore

STATUSES = ("unverified", "ppd", "no_ppd")


def list_opted_in(db):
    docs = db.collection("users").where(filter=firestore.FieldFilter("consent.contributeToModel", "==", True)).stream()
    rows = 0
    for doc in docs:
        d = doc.to_dict()
        label = d.get("ppdLabel") or {}
        sample = db.collection("training_samples").document(d.get("flPseudoId") or "-").get()
        state = "none" if not sample.exists else ("pending" if sample.get("pending") else "ready")
        print(f"{doc.id}  {d.get('email', '-'):<32} label={label.get('status', 'unverified'):<10} "
              f"pseudoId={'yes' if d.get('flPseudoId') else 'no':<3} sample={state}")
        rows += 1
    print(f"{rows} opted-in user(s)")


def main():
    ap = argparse.ArgumentParser()
    who = ap.add_mutually_exclusive_group(required=True)
    who.add_argument("--uid")
    who.add_argument("--email")
    who.add_argument("--list", action="store_true")
    ap.add_argument("--status", choices=STATUSES)
    ap.add_argument("--by", default="demo-doctor")
    args = ap.parse_args()

    init_admin()
    db = firestore.client()

    if args.list:
        list_opted_in(db)
        return
    if not args.status:
        ap.error("--status is required with --uid/--email")

    uid = args.uid or auth.get_user_by_email(args.email).uid
    ref = db.collection("users").document(uid)
    if not ref.get().exists:
        raise SystemExit(f"users/{uid} does not exist")

    ref.set({"ppdLabel": {"status": args.status,
                          "verifiedAt": firestore.SERVER_TIMESTAMP,
                          "verifiedBy": args.by}}, merge=True)
    print(f"users/{uid}.ppdLabel.status = {args.status} (by {args.by})")


if __name__ == "__main__":
    main()
