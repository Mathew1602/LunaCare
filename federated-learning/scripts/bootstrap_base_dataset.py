"""One-time: build the synthetic user-level table, upload it, and publish the current model as v1.

Usage (from repo root, inside functions-ml venv):
    python federated-learning/scripts/bootstrap_base_dataset.py \
        --csv ~/Documents/ML/CapstonPPD/synthetic_ppd_30day_v4_continuousCHATGPT.csv [--dry-run] [--force]
"""
import argparse
import json
import tempfile
from pathlib import Path

import joblib
import pandas as pd
from sklearn.model_selection import GroupShuffleSplit

from _admin import REPO, init_admin
from features import BASE_FEATURES, TARGET_COL, X_COLUMNS, summarize_window
from publish import persona_report, validate_spec, write_version
from weekly_retrain import BASE_PARQUET, SEED, evaluate
from convert import booster_base_score

import coremltools as ct


def build_user_level(csv: Path) -> pd.DataFrame:
    df = pd.read_csv(csv, parse_dates=["date"]).sort_values(["user_id", "date"])
    rows = []
    for uid, g in df.groupby("user_id"):
        feats = summarize_window(g[BASE_FEATURES].reset_index(drop=True))
        rows.append({"user_id": uid, **feats, TARGET_COL: g[TARGET_COL].iloc[-1]})
    user_level = pd.DataFrame(rows)[["user_id", *X_COLUMNS, TARGET_COL]]

    gss = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=SEED)
    _, test_idx = next(gss.split(user_level[X_COLUMNS], user_level[TARGET_COL], groups=user_level["user_id"]))
    user_level["split"] = "train"
    user_level.loc[user_level.index[test_idx], "split"] = "test"
    return user_level


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True)
    ap.add_argument("--artifact", default=str(Path.home() / "Documents/ML/CapstonPPD/ppd_xgb_artifact.pkl"))
    ap.add_argument("--mlmodel", default=str(REPO / "LunaCare/MachineLearning/PPDRiskModel.mlmodel"))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true", help="overwrite an existing ml_models/current")
    args = ap.parse_args()

    user_level = build_user_level(Path(args.csv).expanduser())
    artifact = joblib.load(args.artifact)
    model = artifact["model"]
    assert list(artifact["X_columns"]) == X_COLUMNS

    metrics = evaluate(model, user_level, user_level.iloc[0:0])
    report = persona_report(model)
    mlmodel = ct.models.MLModel(args.mlmodel, skip_model_load=True)
    validate_spec(mlmodel, model.n_estimators, booster_base_score(model))

    counts = user_level["split"].value_counts().to_dict()
    print(f"user_level: {len(user_level)} users {counts}")
    print(f"v1 metrics: {metrics}")
    print(f"persona scores: {report['persona_scores']}")
    if args.dry_run:
        return

    init_admin()
    from firebase_admin import firestore, storage
    db, bucket = firestore.client(), storage.bucket()
    if db.collection("ml_models").document("current").get().exists and not args.force:
        raise SystemExit("ml_models/current already exists; pass --force to overwrite")

    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        parquet = tmp / "user_level.parquet"
        user_level.to_parquet(parquet, index=False)
        bucket.blob(BASE_PARQUET).upload_from_filename(str(parquet))
        print(f"uploaded {BASE_PARQUET}")

        metrics_json = tmp / "metrics.json"
        metrics_json.write_text(json.dumps({"version": 1, "base_score": booster_base_score(model),
                                            **metrics, **report}, indent=2))
        record = write_version(db, bucket, 1, {
            "PPDRiskModel.mlmodel": Path(args.mlmodel),
            "ppd_xgb_artifact.pkl": Path(args.artifact),
            "metrics.json": metrics_json,
        }, metrics, {"runId": "bootstrap"})
    print(f"published v1: {record['mlmodelPath']} sha256 {record['sha256'][:12]}…")


if __name__ == "__main__":
    main()
