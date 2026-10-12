#!/usr/bin/env python3
# migrate_to_newlunacare.py
#
# Copies every Firestore document (all collections + subcollections) from the old
# project (lunacare-d181e) into the new project (newlunacare), keeping the same ids.
# users/{uid}/doctor_comments is written as users/{uid}/doctor_notes.
# The source project is only read, never modified. Safe to re-run: subcollections already
# fully present in the destination are skipped (keeps reads low on the free Spark plan).
#
#    python3 migrate_to_newlunacare.py --dry-run
#    python3 migrate_to_newlunacare.py
#
# Auth users (same uid, email, password) are copied with --auth. Hash params come from the
# OLD project console: Authentication > Users > (menu) > Password hash parameters.
#
#    python3 migrate_to_newlunacare.py --auth --hash-key '<base64_signer_key>' --salt-separator 'Bw=='

import argparse
import base64
import glob
import json
import os
import sys
from collections import Counter

import firebase_admin
from firebase_admin import auth, credentials, firestore
from google.cloud.firestore_v1 import DocumentReference

SRC_PROJECT = "lunacare-d181e"
DST_PROJECT = "newlunacare"
RENAMES = {"doctor_comments": "doctor_notes"}
HERE = os.path.dirname(os.path.abspath(__file__))


def default_key(project):
    keys = sorted(glob.glob(os.path.join(HERE, f"{project}-firebase-adminsdk*.json")))
    if keys:
        return keys[0]
    keys = sorted(glob.glob(os.path.expanduser(f"~/Downloads/{project}-firebase-adminsdk*.json")))
    return keys[0] if keys else None


def parse_args():
    parser = argparse.ArgumentParser(description="Copy Firestore data from lunacare-d181e to newlunacare.")
    parser.add_argument("--src-key", default=default_key(SRC_PROJECT))
    parser.add_argument("--dst-key", default=default_key(DST_PROJECT))
    parser.add_argument("--dry-run", action="store_true", help="Count documents only, write nothing.")
    parser.add_argument("--auth", action="store_true", help="Copy Auth users instead of Firestore data.")
    parser.add_argument("--hash-key", help="base64_signer_key from the old project's password hash parameters.")
    parser.add_argument("--salt-separator", default="Bw==")
    parser.add_argument("--rounds", type=int, default=8)
    parser.add_argument("--mem-cost", type=int, default=14)
    return parser.parse_args()


def init_client(key_path, expected_project, app_name):
    if not key_path or not os.path.isfile(key_path):
        sys.exit(f"Key for {expected_project} not found: {key_path}")
    with open(key_path) as f:
        project_id = json.load(f).get("project_id")
    if project_id != expected_project:
        sys.exit(f"{os.path.basename(key_path)} is for '{project_id}', expected '{expected_project}'.")
    print(f"{app_name}: {expected_project} ({os.path.basename(key_path)})")
    app = firebase_admin.initialize_app(credentials.Certificate(key_path), {"projectId": project_id}, name=app_name)
    return app


def rename_path(path):
    parts = path.split("/")
    for i in range(0, len(parts), 2):
        parts[i] = RENAMES.get(parts[i], parts[i])
    return "/".join(parts)


def convert(value, dst):
    if isinstance(value, DocumentReference):
        return dst.document(rename_path(value.path))
    if isinstance(value, dict):
        return {k: convert(v, dst) for k, v in value.items()}
    if isinstance(value, list):
        return [convert(v, dst) for v in value]
    return value


class BatchWriter:
    def __init__(self, client, size=400):
        self.client, self.size = client, size
        self.batch, self.pending, self.written = client.batch(), 0, 0

    def set(self, ref, data):
        self.batch.set(ref, data)
        self.pending += 1
        if self.pending >= self.size:
            self.flush()

    def flush(self):
        if self.pending:
            self.batch.commit()
            self.written += self.pending
            print(f"  written {self.written}", flush=True)
            self.batch, self.pending = self.client.batch(), 0

    def close(self):
        self.flush()


def col_path(col_ref):
    return "/".join(col_ref._path)


def doc_count(col_ref):
    return int(col_ref.count().get()[0][0].value)


def collection_key(path):
    parts = path.split("/")
    return "/".join(p if i % 2 == 0 else "*" for i, p in enumerate(parts))


def copy_docs(col_ref, dst, writer):
    n = 0
    for snap in col_ref.stream():
        n += 1
        if writer:
            writer.set(dst.document(rename_path(snap.reference.path)), convert(snap.to_dict(), dst))
    return n


def copy_auth(src_app, dst_app, args):
    records = []
    for u in auth.list_users(app=src_app).iterate_all():
        records.append(auth.ImportUserRecord(
            uid=u.uid,
            email=u.email,
            email_verified=u.email_verified,
            display_name=u.display_name,
            phone_number=u.phone_number,
            photo_url=u.photo_url,
            disabled=u.disabled,
            password_hash=base64.urlsafe_b64decode(u.password_hash) if u.password_hash else None,
            password_salt=base64.urlsafe_b64decode(u.password_salt) if u.password_salt else None,
            custom_claims=u.custom_claims,
            user_metadata=auth.UserMetadata(u.user_metadata.creation_timestamp, u.user_metadata.last_sign_in_timestamp),
            provider_data=[auth.UserProvider(uid=p.uid, provider_id=p.provider_id, email=p.email,
                                             display_name=p.display_name, photo_url=p.photo_url)
                           for p in u.provider_data],
        ))
    print(f"Users in {SRC_PROJECT}: {len(records)}")
    if args.dry_run:
        return
    if not args.hash_key:
        sys.exit("--hash-key is required for --auth.")
    hash_alg = auth.UserImportHash.scrypt(
        key=base64.b64decode(args.hash_key),
        salt_separator=base64.b64decode(args.salt_separator),
        rounds=args.rounds,
        memory_cost=args.mem_cost,
    )
    imported, failed = 0, 0
    for i in range(0, len(records), 1000):
        result = auth.import_users(records[i:i + 1000], hash_alg=hash_alg, app=dst_app)
        imported += result.success_count
        failed += result.failure_count
        for err in result.errors:
            print(f"  FAILED {records[i + err.index].email}: {err.reason}")
    print(f"Imported {imported}, failed {failed}")
    if failed:
        sys.exit(1)


def main():
    args = parse_args()
    src_app = init_client(args.src_key, SRC_PROJECT, "src")
    dst_app = init_client(args.dst_key, DST_PROJECT, "dst")
    if args.auth:
        copy_auth(src_app, dst_app, args)
        return
    src = firestore.client(src_app)
    dst = firestore.client(dst_app)

    writer = None if args.dry_run else BatchWriter(dst)
    totals, copied, skipped, pairs = Counter(), Counter(), Counter(), []
    for col in src.collections():
        print(f"Copying {col.id}...", flush=True)
        snaps = list(col.stream())
        totals[col.id] += len(snaps)
        copied[col.id] += len(snaps)
        for snap in snaps:
            if writer:
                writer.set(dst.document(rename_path(snap.reference.path)), convert(snap.to_dict(), dst))
            for sub in snap.reference.collections():
                dst_sub = dst.collection(rename_path(col_path(sub)))
                key = collection_key(rename_path(col_path(sub)))
                src_n = doc_count(sub)
                totals[key] += src_n
                pairs.append((col_path(dst_sub), src_n, dst_sub))
                if doc_count(dst_sub) >= src_n:
                    skipped[key] += src_n
                    continue
                copied[key] += copy_docs(sub, dst, writer)
    if writer:
        writer.close()

    print("\nDocuments per collection" + (" (dry run, nothing written):" if args.dry_run else ":"))
    print(f"  {'collection':40} {'total':>7} {'copied':>7} {'skipped':>8}")
    for key in sorted(totals):
        print(f"  {key:40} {totals[key]:>7} {copied[key]:>7} {skipped[key]:>8}")
    print(f"  {'TOTAL':40} {sum(totals.values()):>7} {sum(copied.values()):>7} {sum(skipped.values()):>8}")
    print("  (skipped = already fully present in destination)")

    if args.dry_run:
        return

    print("\nVerifying destination...")
    mismatches = [(path, want, doc_count(ref)) for path, want, ref in pairs]
    mismatches = [m for m in mismatches if m[2] < m[1]]
    for path, want, got in mismatches:
        print(f"  MISMATCH {path}: expected {want}, found {got}")
    leftover = int(dst.collection_group("doctor_comments").count().get()[0][0].value)
    print(f"  Subcollections checked: {len(pairs)}, mismatches: {len(mismatches)}")
    print(f"  doctor_comments docs in {DST_PROJECT}: {leftover}")
    if mismatches or leftover:
        sys.exit(1)
    print("Done.")


if __name__ == "__main__":
    main()
