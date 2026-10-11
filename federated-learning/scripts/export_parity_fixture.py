"""Export a Swift/Python feature + prediction parity fixture.

Usage (from repo root, inside functions-ml venv):
    python federated-learning/scripts/export_parity_fixture.py \
        [--artifact ~/Documents/ML/CapstonPPD/ppd_xgb_artifact.pkl] [--check-coreml]
"""
import argparse
import json
import math
import sys
from datetime import date, timedelta
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "federated-learning" / "functions-ml"))

from features import BASE_FEATURES, FEATURE_SCHEMA_VERSION, WINDOW_DAYS, X_COLUMNS, summarize_window  # noqa: E402

SWIFT_KEYS = {
    "fatigue_1to10": "fatigue1to10", "mood_1to5": "mood1to5", "bleeding_1to10": "bleeding1to10",
    "hair_loss_1to10": "hairLoss1to10", "appetite_issue_1to10": "appetiteIssue1to10",
    "sleep_trouble_1to10": "sleepTrouble1to10", "sleep_hours": "sleepHours",
    "deep_sleep_hours": "deepSleepHours", "rem_sleep_hours": "remSleepHours",
    "core_sleep_hours": "coreSleepHours", "sleep_efficiency_pct": "sleepEfficiencyPct",
    "wake_after_sleep_onset_min": "wakeAfterSleepOnsetMin", "avg_heart_rate_bpm": "avgHeartRateBpm",
    "resting_heart_rate_bpm": "restingHRBpm", "walking_heart_rate_avg_bpm": "walkingHeartRateAvgBpm",
    "hrv_sdnn_ms": "hrvSDNNms", "respiratory_rate_bpm": "respiratoryRateBpm",
    "oxygen_saturation_pct": "oxygenSaturationPct", "vo2max_ml_kg_min": "vo2Max", "steps": "steps",
    "distance_walked_km": "distanceWalkedKm", "flights_climbed": "flightsClimbed",
    "active_energy_kcal": "activeEnergyKcal", "basal_energy_kcal": "basalEnergyKcal",
    "exercise_minutes": "exerciseMinutes", "stand_hours": "standHours",
    "sunlight_hours": "sunlightHours", "weight_kg": "weightKg",
}

PROFILE = {
    "fatigue_1to10": (7.0, 1.2, 1, 10), "mood_1to5": (2.4, 0.6, 1, 5),
    "bleeding_1to10": (2.5, 1.0, 1, 10), "hair_loss_1to10": (2.0, 0.8, 1, 10),
    "appetite_issue_1to10": (6.0, 1.0, 1, 10), "sleep_trouble_1to10": (7.0, 1.0, 1, 10),
    "sleep_hours": (6.0, 0.8, 2, 12), "deep_sleep_hours": (1.0, 0.3, 0, 4),
    "rem_sleep_hours": (1.4, 0.3, 0, 4), "core_sleep_hours": (3.6, 0.5, 0, 8),
    "sleep_efficiency_pct": (82, 5, 40, 100), "wake_after_sleep_onset_min": (35, 10, 0, 120),
    "avg_heart_rate_bpm": (82, 4, 50, 130), "resting_heart_rate_bpm": (74, 3, 45, 110),
    "walking_heart_rate_avg_bpm": (98, 6, 60, 150), "hrv_sdnn_ms": (38, 8, 10, 150),
    "respiratory_rate_bpm": (16, 1, 10, 25), "oxygen_saturation_pct": (97.5, 0.8, 90, 100),
    "vo2max_ml_kg_min": (31, 1.5, 15, 60), "steps": (3500, 1200, 0, 20000),
    "distance_walked_km": (2.4, 0.8, 0, 15), "flights_climbed": (2, 1.5, 0, 30),
    "active_energy_kcal": (220, 60, 0, 1200), "basal_energy_kcal": (1420, 30, 1000, 2000),
    "exercise_minutes": (12, 8, 0, 120), "stand_hours": (7, 2, 0, 18),
    "sunlight_hours": (0.6, 0.4, 0, 8), "weight_kg": (69, 0.4, 40, 150),
}

WINDOW_END = date(2025, 3, 2)


def make_days(rng: np.random.Generator) -> pd.DataFrame:
    rows = {}
    for base, (mu, sd, lo, hi) in PROFILE.items():
        vals = np.clip(rng.normal(mu, sd, WINDOW_DAYS), lo, hi)
        rows[base] = np.round(vals) if base == "steps" else np.round(vals, 4)
    return pd.DataFrame(rows)


def sparsify(df: pd.DataFrame, rng: np.random.Generator) -> pd.DataFrame:
    df = df.copy()
    df.loc[rng.choice(WINDOW_DAYS - 1, 8, replace=False)] = np.nan
    for base in BASE_FEATURES:
        df.loc[rng.random(WINDOW_DAYS) < 0.15, base] = np.nan
    df.loc[WINDOW_DAYS - 1, ["mood_1to5", "fatigue_1to10"]] = np.nan
    df["weight_kg"] = np.nan
    df.loc[[3, 15, 27], "weight_kg"] = [69.2, 68.8, 68.5]
    df["vo2max_ml_kg_min"] = np.nan
    df.loc[10, "vo2max_ml_kg_min"] = 31.0
    df["oxygen_saturation_pct"] = np.nan
    return df


def to_json_value(v):
    return None if v is None or (isinstance(v, float) and math.isnan(v)) else float(v)


def measurements(df: pd.DataFrame) -> list:
    out = []
    for i, row in df.iterrows():
        if row.isna().all():
            continue
        day = WINDOW_END - timedelta(days=WINDOW_DAYS - 1 - i)
        m = {"createdAt": f"{day.isoformat()}T12:00:00Z", "source": "fixture"}
        for base, key in SWIFT_KEYS.items():
            v = row[base]
            if not np.isnan(v):
                m[key] = int(v) if base == "steps" else float(v)
        out.append(m)
    return out


def build_case(name: str, df: pd.DataFrame, model) -> dict:
    feats = summarize_window(df)
    X = pd.DataFrame([[feats[c] for c in X_COLUMNS]], columns=X_COLUMNS)
    return {
        "name": name,
        "measurements": measurements(df),
        "features": {k: to_json_value(feats[k]) for k in X_COLUMNS},
        "prediction": float(model.predict(X)[0]),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifact", default=str(Path.home() / "Documents/ML/CapstonPPD/ppd_xgb_artifact.pkl"))
    ap.add_argument("--mlmodel", default=str(REPO / "LunaCare/MachineLearning/PPDRiskModel.mlmodel"))
    ap.add_argument("--out", default=str(REPO / "LunaCare/FederatedLearning/ppd_parity_fixture.json"))
    ap.add_argument("--check-coreml", action="store_true", help="also compare against Core ML (macOS only)")
    args = ap.parse_args()

    artifact = joblib.load(args.artifact)
    if list(artifact["X_columns"]) != X_COLUMNS:
        sys.exit("X_COLUMNS in features.py does not match the artifact's X_columns")
    model = artifact["model"]

    rng = np.random.default_rng(42)
    complete = make_days(rng)
    cases = [build_case("complete", complete, model), build_case("sparse", sparsify(complete, rng), model)]

    fixture = {
        "featureSchemaVersion": FEATURE_SCHEMA_VERSION,
        "windowEnd": f"{WINDOW_END.isoformat()}T12:00:00Z",
        "featureTolerance": 1e-6,
        "predictionTolerance": 1e-4,
        "cases": cases,
    }
    Path(args.out).write_text(json.dumps(fixture, indent=1))
    print(f"wrote {args.out}")
    for c in cases:
        print(f"  {c['name']}: {len(c['measurements'])} days, prediction {c['prediction']:.6f}")

    if args.check_coreml:
        import coremltools as ct

        mlmodel = ct.models.MLModel(args.mlmodel)
        for c in cases:
            inputs = {k: (np.nan if v is None else v) for k, v in c["features"].items()}
            got = mlmodel.predict(inputs)["ppd_risk_score_0to1"]
            diff = abs(got - c["prediction"])
            print(f"  coreml {c['name']}: {got:.6f} (diff {diff:.2e}) {'OK' if diff < 1e-4 else 'MISMATCH'}")


if __name__ == "__main__":
    main()
