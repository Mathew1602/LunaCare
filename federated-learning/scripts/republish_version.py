"""Roll back by republishing an older model version as a new, higher version (phones only move forward).

Usage (from repo root, inside functions-ml venv):
    python federated-learning/scripts/republish_version.py --from-version 1
"""
import argparse
import json
import tempfile
from pathlib import Path

from _admin import init_admin
from publish import MODELS_PREFIX, write_version

FILES = ("PPDRiskModel.mlmodel", "ppd_xgb_artifact.pkl", "metrics.json")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from-version", type=int, required=True)
    args = ap.parse_args()

    init_admin()
    from firebase_admin import firestore, storage
    db, bucket = firestore.client(), storage.bucket()

    source = db.collection("ml_models").document("history").collection("versions") \
        .document(f"v{args.from_version}").get().to_dict()
    if not source:
        raise SystemExit(f"ml_models/history/versions/v{args.from_version} not found")
    version = int(db.collection("ml_models").document("current").get().get("version")) + 1

    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        files = {}
        for name in FILES:
            files[name] = tmp / name
            bucket.blob(f"{MODELS_PREFIX}/v{args.from_version}/{name}").download_to_filename(str(files[name]))
        metrics = json.loads(files["metrics.json"].read_text())
        metrics.update(version=version, republishedFrom=args.from_version)
        files["metrics.json"].write_text(json.dumps(metrics, indent=2))
        record = write_version(db, bucket, version, files, source["metrics"],
                               {"runId": f"republish-v{args.from_version}", "republishedFrom": args.from_version})
    print(f"published v{version} = v{args.from_version} (sha256 {record['sha256'][:12]}…)")


if __name__ == "__main__":
    main()
