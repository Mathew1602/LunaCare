import json

import coremltools as ct

from features import TARGET_COL


def booster_base_score(model) -> float:
    params = json.loads(model.get_booster().save_config())["learner"]["learner_model_param"]
    return float(params["base_score"].strip("[]"))


def to_coreml(model, feature_names: list) -> ct.models.MLModel:
    """coremltools assumes base_score 0.5; XGBoost >= 2 learns it, so patch the real value in."""
    converted = ct.converters.xgboost.convert(
        model, feature_names=feature_names, target=TARGET_COL, mode="regressor"
    )
    spec = converted.get_spec()
    spec.treeEnsembleRegressor.treeEnsemble.basePredictionValue[0] = booster_base_score(model)
    return ct.models.MLModel(spec)
