"""Convert, validate and version a model, then write ml_models/current last (the switch phones watch)."""
import hashlib
import json
import tempfile
from pathlib import Path

import joblib
from google.cloud import firestore

from convert import booster_base_score, to_coreml
from features import BASE_FEATURES, FEATURE_SCHEMA_VERSION, TARGET_COL, X_COLUMNS, to_matrix
from personas import persona_features

MODELS_PREFIX = "ml/models"


def validate_spec(mlmodel, n_estimators: int, base_score: float):
    spec = mlmodel.get_spec()
    inputs = [i.name for i in spec.description.input]
    outputs = [o.name for o in spec.description.output]
    ensemble = spec.treeEnsembleRegressor.treeEnsemble
    trees = len({n.treeId for n in ensemble.nodes})
    if inputs != X_COLUMNS:
        raise ValueError(f"Core ML inputs mismatch ({len(inputs)} inputs)")
    if outputs != [TARGET_COL]:
        raise ValueError(f"Core ML outputs {outputs} != [{TARGET_COL}]")
    if trees != n_estimators:
        raise ValueError(f"Core ML has {trees} trees, expected {n_estimators}")
    if abs(ensemble.basePredictionValue[0] - base_score) > 1e-6:
        raise ValueError("Core ML basePredictionValue does not match XGBoost base_score")


def persona_report(model) -> dict:
    feats = persona_features()
    scores = model.predict(to_matrix(list(feats.values())))
    return {"persona_scores": {k: float(s) for k, s in zip(feats, scores)}, "persona_features": feats}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_version(db, bucket, version: int, files: dict, metrics: dict, extra: dict = None) -> dict:
    """Upload files {name: local Path} to ml/models/v{N}/ and write history, current.json, then ml_models/current."""
    prefix = f"{MODELS_PREFIX}/v{version}"
    for name, local in files.items():
        bucket.blob(f"{prefix}/{name}").upload_from_filename(str(local))

    record = {
        "version": version,
        "mlmodelPath": f"{prefix}/PPDRiskModel.mlmodel",
        "pklPath": f"{prefix}/ppd_xgb_artifact.pkl",
        "metricsPath": f"{prefix}/metrics.json",
        "sha256": sha256(files["PPDRiskModel.mlmodel"]),
        "metrics": metrics,
        "featureSchemaVersion": FEATURE_SCHEMA_VERSION,
        "trainedAt": firestore.SERVER_TIMESTAMP,
        **(extra or {}),
    }
    db.collection("ml_models").document("history").collection("versions").document(f"v{version}") \
        .set({**record, "status": "promoted"})
    bucket.blob(f"{MODELS_PREFIX}/current.json").upload_from_string(
        json.dumps({"version": version, "pklPath": record["pklPath"], "sha256": record["sha256"]}),
        content_type="application/json")
    db.collection("ml_models").document("current").set(record)
    return record


def publish(db, bucket, model, metrics: dict, current: dict, run_id: str = None) -> int:
    version = int(current.get("version", 0)) + 1
    base_score = booster_base_score(model)
    mlmodel = to_coreml(model, X_COLUMNS)
    mlmodel.short_description = f"LunaCare PPD risk v{version}"
    validate_spec(mlmodel, model.n_estimators, base_score)

    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        files = {"PPDRiskModel.mlmodel": tmp / "PPDRiskModel.mlmodel",
                 "ppd_xgb_artifact.pkl": tmp / "ppd_xgb_artifact.pkl",
                 "metrics.json": tmp / "metrics.json"}
        mlmodel.save(str(files["PPDRiskModel.mlmodel"]))
        joblib.dump({"model": model, "feature_cols": BASE_FEATURES, "target_col": TARGET_COL,
                     "X_columns": X_COLUMNS, "version": version}, files["ppd_xgb_artifact.pkl"])
        files["metrics.json"].write_text(json.dumps(
            {"version": version, "runId": run_id, "base_score": base_score, **metrics, **persona_report(model)},
            indent=2))
        write_version(db, bucket, version, files, metrics, {"runId": run_id})
    return version
