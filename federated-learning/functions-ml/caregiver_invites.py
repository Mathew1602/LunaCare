"""Redeem caregiver invites: link the caller (a caregiver) to the mother who invited them.

Two ways in, both through the `redeem_caregiver_invite` callable:
- no code: link every pending invite sent to the caller's sign-in email (runs on each app open)
- code: link that one invite (backup if the caregiver signed up with a different email)

Runs with the Admin SDK because the security rules never let a caregiver add a mother to their own
`userIds`. Each invite is linked in one transaction and then deleted, so it works once.
Code format must match CaregiverInvite in the iOS app (6 chars, no look-alike characters).
"""

from datetime import datetime, timezone

from firebase_admin import firestore
from firebase_functions import https_fn

CODE_LENGTH = 6
PERMISSION_KEYS = ("mood", "symptoms", "riskAlerts", "doctorContact")
Error = https_fn.FunctionsErrorCode


def _fail(code: https_fn.FunctionsErrorCode, message: str):
    raise https_fn.HttpsError(code, message)


def _normalize_code(raw) -> str:
    return "".join(c for c in str(raw or "").upper() if c.isalnum())


def _clean_permissions(raw) -> dict:
    raw = raw if isinstance(raw, dict) else {}
    return {key: raw.get(key) is True for key in PERMISSION_KEYS}


def _doctor_contacts(db, mother_uid: str) -> list:
    """Same shape as DoctorContact in the app; the grant is the only doc a caregiver can read."""
    contacts = []
    for doc in db.collection("doctors").where("patientIds", "array_contains", mother_uid).stream():
        d = doc.to_dict()
        if not d.get("authorized") or not d.get("firstName") or not d.get("lastName"):
            continue
        contacts.append({
            "id": doc.id,
            "name": f"Dr. {d['firstName']} {d['lastName']}",
            "specialty": d.get("specialty", ""),
            "phone": d.get("phone", ""),
            "email": d.get("email", ""),
        })
    return contacts


def _link(db, invite_ref, caregiver_uid: str, caregiver_email: str) -> str:
    """Links one invite in a transaction and returns the mother's first name."""
    caregiver_ref = db.collection("caregivers").document(caregiver_uid)

    @firestore.transactional
    def run(tx) -> str:
        invite = invite_ref.get(transaction=tx)
        if not invite.exists:
            _fail(Error.NOT_FOUND, "This code isn't valid. Check it and try again.")
        data = invite.to_dict()
        expires_at = data.get("expiresAt")
        if not expires_at or expires_at < datetime.now(timezone.utc):
            _fail(Error.FAILED_PRECONDITION, "This invite has expired. Ask for a new one.")

        invited_email = data.get("email", "")
        if invited_email and invited_email != caregiver_email:
            _fail(Error.PERMISSION_DENIED, "This invite was sent to a different email address.")
        mother_uid = data.get("motherUid")
        if not mother_uid or mother_uid == caregiver_uid:
            _fail(Error.INVALID_ARGUMENT, "You can't accept your own invite.")
        if not caregiver_ref.get(transaction=tx).exists:
            _fail(Error.FAILED_PRECONDITION, "Only family caregiver accounts can accept invites.")

        mother = db.collection("users").document(mother_uid).get(transaction=tx)
        mother_name = (mother.to_dict() or {}).get("firstName", "") if mother.exists else ""

        permissions = _clean_permissions(data.get("permissions"))
        grant = {
            "permissions": permissions,
            "relationship": data.get("relationship", ""),
            "createdAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        if mother_name:
            grant["motherName"] = mother_name
        if permissions["doctorContact"]:
            grant["doctorContacts"] = _doctor_contacts(db, mother_uid)

        grant_ref = db.collection("users").document(mother_uid).collection("caregivers").document(caregiver_uid)
        tx.set(grant_ref, grant, merge=True)
        tx.update(caregiver_ref, {
            "userIds": firestore.ArrayUnion([mother_uid]),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        })
        tx.delete(invite_ref)
        return mother_name

    return run(db.transaction())


def redeem(db, caregiver_uid: str, caregiver_email: str, raw_code=None) -> dict:
    email = (caregiver_email or "").strip().lower()

    if raw_code:
        code = _normalize_code(raw_code)
        if len(code) != CODE_LENGTH:
            _fail(Error.INVALID_ARGUMENT, "Enter the 6-character code.")
        name = _link(db, db.collection("invites").document(code), caregiver_uid, email)
        return {"linked": 1, "motherNames": [name]}

    if not email:
        return {"linked": 0, "motherNames": []}

    names = []
    for doc in db.collection("invites").where("email", "==", email).stream():
        try:
            names.append(_link(db, doc.reference, caregiver_uid, email))
        except https_fn.HttpsError as err:
            # An expired or otherwise unusable invite shouldn't block the others.
            print(f"invites/{doc.id[:3]}…: skipped ({err.message})")
    return {"linked": len(names), "motherNames": names}
