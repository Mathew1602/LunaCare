"""Weekly retrain: synthetic base + doctor-verified real samples, gated on fixed holdouts."""
import hashlib
import json
import tempfile
import traceback
from datetime import datetime, timedelta, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from google.cloud import firestore
from sklearn.metrics import mean_absolute_error, r2_score, roc_auc_score
from xgboost import XGBRegressor

from features import FEATURE_SCHEMA_VERSION, TARGET_COL, X_COLUMNS, to_matrix
from build_training_sample import clean_features, resolve_pending

BASE_PARQUET = "ml/base/user_level.parquet"
CANDIDATES_PREFIX = "ml/candidates"
MIN_NEW_LABELS = 5
HOLDOUT_BUCKETS = 5
REAL_WEIGHT = 5.0
SYNTH_MAE_SLACK = 0.005
MIN_REAL_HOLDOUT = 5
BASELINE_VERSION = 1
BATCH_LIMIT = 400
LOCK_TTL = timedelta(hours=1)
SEED = 42

HYPERPARAMS = dict(
    n_estimators=600, learning_rate=0.02, max_depth=5, subsample=0.8, colsample_bytree=0.8,
    reg_alpha=0.2, reg_lambda=1.0, objective="reg:squarederror", random_state=SEED, n_jobs=-1,
)


def is_holdout(sample_id: str) -> bool:
    """~20% by hash of the pseudoId, so a sample stays in the same split across runs and versions."""
    return int(hashlib.sha256(sample_id.encode()).hexdigest()[:8], 16) % HOLDOUT_BUCKETS == 0


def split_real(real: pd.DataFrame):
    mask = real["id"].map(is_holdout).astype(bool)
    return real[~mask], real[mask]


def build_training_set(base: pd.DataFrame, real_train: pd.DataFrame):
    synth = base[base["split"] == "train"]
    X = pd.concat([synth[X_COLUMNS], to_matrix(real_train["features"].tolist())], ignore_index=True)
    y = np.concatenate([synth[TARGET_COL].to_numpy(float), real_train["label"].to_numpy(float)])
    w = np.concatenate([np.ones(len(synth)), np.full(len(real_train), REAL_WEIGHT)])
    return X, y, w


def train(X, y, w) -> XGBRegressor:
    model = XGBRegressor(**HYPERPARAMS)
    model.fit(X, y, sample_weight=w, verbose=False)
    return model


def evaluate(model, base: pd.DataFrame, real_holdout: pd.DataFrame) -> dict:
    test = base[base["split"] == "test"]
    pred = model.predict(test[X_COLUMNS])
    m = {"mae_synth": float(mean_absolute_error(test[TARGET_COL], pred)),
         "r2_synth": float(r2_score(test[TARGET_COL], pred)),
         "mae_real": None, "auc_real": None, "n_real_holdout": int(len(real_holdout))}
    if len(real_holdout):
        y = real_holdout["label"].to_numpy(float)
        p = model.predict(to_matrix(real_holdout["features"].tolist()))
        m["mae_real"] = float(mean_absolute_error(y, p))
        if len(set(y)) == 2:
            m["auc_real"] = float(roc_auc_score(y, p))
    return m


def gate(current: dict, new: dict, baseline_mae_synth: float = None) -> tuple:
    """Not worse than the current model, and never drifting more than the slack from the fixed v1 baseline."""
    if new["mae_synth"] > current["mae_synth"] + SYNTH_MAE_SLACK:
        return False, f"synthetic MAE {new['mae_synth']:.4f} > current {current['mae_synth']:.4f} + {SYNTH_MAE_SLACK}"
    if baseline_mae_synth is not None and new["mae_synth"] > baseline_mae_synth + SYNTH_MAE_SLACK:
        return False, f"synthetic MAE {new['mae_synth']:.4f} > baseline v{BASELINE_VERSION} {baseline_mae_synth:.4f} + {SYNTH_MAE_SLACK}"
    if new["n_real_holdout"] >= MIN_REAL_HOLDOUT and new["mae_real"] > current["mae_real"]:
        return False, f"real MAE {new['mae_real']:.4f} > current {current['mae_real']:.4f}"
    return True, "passed gate"


def load_real_samples(db) -> pd.DataFrame:
    rows = []
    for doc in db.collection("training_samples").where(filter=firestore.FieldFilter("pending", "==", False)).stream():
        d = doc.to_dict()
        features = clean_features(d.get("features"))
        if d.get("featureSchemaVersion") != FEATURE_SCHEMA_VERSION or features is None:
            continue
        rows.append({"id": doc.id, "features": features, "label": float(d["label"]),
                     "usedInVersion": d.get("usedInVersion"), "candidateRun": d.get("candidateRun")})
    return pd.DataFrame(rows, columns=["id", "features", "label", "usedInVersion", "candidateRun"])


def count_new(real: pd.DataFrame) -> int:
    """Samples never promoted and not already evaluated in a candidate run with the same data."""
    return int((real["usedInVersion"].isna() & real["candidateRun"].isna()).sum())


def stamp_samples(db, ids, fields: dict) -> None:
    ids = list(ids)
    for start in range(0, len(ids), BATCH_LIMIT):
        batch = db.batch()
        for sid in ids[start:start + BATCH_LIMIT]:
            batch.update(db.collection("training_samples").document(sid), fields)
        batch.commit()


def baseline_mae_synth(db):
    doc = db.collection("ml_models").document("history").collection("versions").document(f"v{BASELINE_VERSION}").get()
    return ((doc.to_dict() or {}).get("metrics") or {}).get("mae_synth") if doc.exists else None


def acquire_lock(db, run_id: str, now: datetime = None) -> bool:
    """One retrain at a time, so two runs can never publish the same version number."""
    ref = db.collection("training_runs").document("_lock")
    now = now or datetime.now(timezone.utc)

    @firestore.transactional
    def txn(transaction):
        snap = ref.get(transaction=transaction)
        if snap.exists and now - snap.get("at") < LOCK_TTL:
            return False
        transaction.set(ref, {"runId": run_id, "at": now})
        return True

    return txn(db.transaction())


def release_lock(db, run_id: str) -> None:
    ref = db.collection("training_runs").document("_lock")
    snap = ref.get()
    if snap.exists and snap.get("runId") == run_id:
        ref.delete()


def _download(bucket, path: str, tmp: Path) -> Path:
    local = tmp / Path(path).name
    bucket.blob(path).download_to_filename(str(local))
    return local


def run_retrain(db, bucket, force: bool = False) -> dict:
    from publish import publish

    run_ref = db.collection("training_runs").document()
    run_ref.set({"startedAt": firestore.SERVER_TIMESTAMP, "status": "running"})
    result = {"runId": run_ref.id}
    if not acquire_lock(db, run_ref.id):
        result.update(status="skipped", reason="another retrain is running")
        run_ref.set({**result, "finishedAt": firestore.SERVER_TIMESTAMP}, merge=True)
        return result
    try:
        result["pendingResolved"] = resolve_pending(db)
        real = load_real_samples(db)
        n_new = count_new(real)
        result.update(nReal=int(len(real)), nNewLabels=n_new)

        if n_new < MIN_NEW_LABELS and not force:
            result.update(status="skipped", reason=f"{n_new} new labels < {MIN_NEW_LABELS}")
            return result

        current = db.collection("ml_models").document("current").get().to_dict()
        baseline = baseline_mae_synth(db)
        with tempfile.TemporaryDirectory() as d:
            tmp = Path(d)
            base = pd.read_parquet(_download(bucket, BASE_PARQUET, tmp))
            current_model = joblib.load(_download(bucket, current["pklPath"], tmp))["model"]

            real_train, real_holdout = split_real(real)
            X, y, w = build_training_set(base, real_train)
            model = train(X, y, w)

            cur_m = evaluate(current_model, base, real_holdout)
            new_m = evaluate(model, base, real_holdout)
            promote, reason = gate(cur_m, new_m, baseline)
            result.update(nSynthetic=int((base["split"] == "train").sum()), nRealTrain=int(len(real_train)),
                          metrics={"current": cur_m, "new": new_m, "baselineMaeSynth": baseline}, reason=reason)

            if promote:
                version = publish(db, bucket, model, new_m, current, run_id=run_ref.id)
                result.update(status="promoted", version=version)
                try:
                    stamp_samples(db, real["id"], {"usedInVersion": version})
                except Exception as e:
                    result["stampError"] = f"{type(e).__name__}: {e}"
            else:
                prefix = f"{CANDIDATES_PREFIX}/{run_ref.id}"
                joblib.dump({"model": model, "X_columns": X_COLUMNS}, tmp / "ppd_xgb_artifact.pkl")
                bucket.blob(f"{prefix}/ppd_xgb_artifact.pkl").upload_from_filename(str(tmp / "ppd_xgb_artifact.pkl"))
                bucket.blob(f"{prefix}/metrics.json").upload_from_string(
                    json.dumps(result["metrics"], indent=2), content_type="application/json")
                stamp_samples(db, real["id"], {"candidateRun": run_ref.id})
                result.update(status="candidate", candidatePath=prefix)
        return result
    except Exception as e:
        result.update(status="failed", reason=f"{type(e).__name__}: {e}", trace=traceback.format_exc()[-2000:])
        return result
    finally:
        release_lock(db, run_ref.id)
        run_ref.set({**result, "finishedAt": firestore.SERVER_TIMESTAMP}, merge=True)
