"""Re-convert ppd_xgb_artifact.pkl into the app's bundled PPDRiskModel.mlmodel with the correct base_score.

Usage (from repo root, inside functions-ml venv):
    python federated-learning/scripts/convert_bundled_model.py \
        [--artifact ~/Documents/ML/CapstonPPD/ppd_xgb_artifact.pkl]
"""
import argparse
import sys
from pathlib import Path

import joblib

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "federated-learning" / "functions-ml"))

from convert import booster_base_score, to_coreml  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifact", default=str(Path.home() / "Documents/ML/CapstonPPD/ppd_xgb_artifact.pkl"))
    ap.add_argument("--out", default=str(REPO / "LunaCare/MachineLearning/PPDRiskModel.mlmodel"))
    args = ap.parse_args()

    artifact = joblib.load(args.artifact)
    model = artifact["model"]
    mlmodel = to_coreml(model, list(artifact["X_columns"]))
    mlmodel.short_description = "LunaCare PPD risk (XGBoost, bundled v0)"
    mlmodel.save(args.out)
    print(f"wrote {args.out} (base_score {booster_base_score(model):.8f})")


if __name__ == "__main__":
    main()
