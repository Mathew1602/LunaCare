import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest
from xgboost import XGBRegressor

import publish
import weekly_retrain
from build_training_sample import clean_features
from convert import booster_base_score, to_coreml
from features import TARGET_COL, X_COLUMNS, to_matrix

RNG = np.random.default_rng(0)


def fake_features(n, nan_frac=0.1):
    X = RNG.normal(size=(n, len(X_COLUMNS)))
    X[RNG.random(X.shape) < nan_frac] = np.nan
    return [{k: (None if np.isnan(v) else float(v)) for k, v in zip(X_COLUMNS, row)} for row in X]


def fake_base(n=60):
    df = to_matrix(fake_features(n))
    df[TARGET_COL] = RNG.random(n)
    df["split"] = ["test" if i % 5 == 0 else "train" for i in range(n)]
    return df


def fake_real(n, pos=None):
    labels = [1.0 if i < (pos if pos is not None else n // 2) else 0.0 for i in range(n)]
    return pd.DataFrame({"id": [f"p{i}" for i in range(n)], "features": fake_features(n),
                         "label": labels, "usedInVersion": [None] * n})


@pytest.fixture(scope="module")
def small_model():
    base = fake_base()
    m = XGBRegressor(n_estimators=12, max_depth=3, base_score=None, random_state=0)
    m.fit(base[X_COLUMNS], base[TARGET_COL])
    return m


def test_to_matrix_keeps_order_and_nan():
    df = to_matrix([{"fatigue_1to10_mean": 3.0, "weight_kg_last": None}])
    assert list(df.columns) == X_COLUMNS
    assert df.iloc[0]["fatigue_1to10_mean"] == 3.0
    assert np.isnan(df.iloc[0]["weight_kg_last"])
    assert np.isnan(df.iloc[0]["steps_mean"])


def test_split_real_is_fixed_per_sample():
    real = fake_real(200)
    tr, ho = weekly_retrain.split_real(real)
    assert len(tr) + len(ho) == 200 and set(tr["id"]).isdisjoint(ho["id"])
    assert 20 <= len(ho) <= 60
    _, ho_sub = weekly_retrain.split_real(real.iloc[:50])
    assert set(ho_sub["id"]) == set(ho["id"]) & set(real.iloc[:50]["id"])


def test_split_real_empty():
    tr, ho = weekly_retrain.split_real(fake_real(0))
    assert len(tr) == 0 and len(ho) == 0


def test_build_training_set_weights():
    base = fake_base()
    X, y, w = weekly_retrain.build_training_set(base, fake_real(4))
    n_synth = (base["split"] == "train").sum()
    assert list(X.columns) == X_COLUMNS
    assert len(X) == len(y) == len(w) == n_synth + 4
    assert (w[:n_synth] == 1.0).all() and (w[n_synth:] == weekly_retrain.REAL_WEIGHT).all()


def test_gate():
    cur = {"mae_synth": 0.100, "mae_real": 0.30}
    big = {"n_real_holdout": 5}
    assert weekly_retrain.gate(cur, {"mae_synth": 0.104, "mae_real": 0.29, **big})[0]
    assert not weekly_retrain.gate(cur, {"mae_synth": 0.106, "mae_real": 0.10, **big})[0]
    assert not weekly_retrain.gate(cur, {"mae_synth": 0.090, "mae_real": 0.31, **big})[0]
    none = {"mae_synth": 0.1, "mae_real": None, "n_real_holdout": 0}
    assert weekly_retrain.gate({"mae_synth": 0.1, "mae_real": None}, none)[0]


def test_gate_ignores_tiny_real_holdout():
    cur = {"mae_synth": 0.100, "mae_real": 0.30}
    assert weekly_retrain.gate(cur, {"mae_synth": 0.100, "mae_real": 0.90, "n_real_holdout": 2})[0]


def test_gate_bounds_drift_from_baseline():
    cur = {"mae_synth": 0.104, "mae_real": None}
    new = {"mae_synth": 0.107, "mae_real": None, "n_real_holdout": 0}
    assert weekly_retrain.gate(cur, new)[0]
    ok, reason = weekly_retrain.gate(cur, new, baseline_mae_synth=0.100)
    assert not ok and "baseline" in reason


def test_clean_features():
    assert clean_features({"steps_mean": 1, "weight_kg_last": None}) == {"steps_mean": 1.0, "weight_kg_last": None}
    assert clean_features({"steps_mean": "abc"}) is None
    assert clean_features({"steps_mean": True}) is None
    assert clean_features({"steps_mean": float("inf")}) is None
    assert clean_features({"not_a_feature": 1.0}) is None
    assert clean_features({}) is None and clean_features(None) is None


def test_count_new_skips_promoted_and_candidate_samples():
    real = fake_real(4)
    real["candidateRun"] = [None, "run1", None, None]
    real.loc[2, "usedInVersion"] = 3
    assert weekly_retrain.count_new(real) == 2


class FakeBatch:
    def __init__(self, commits):
        self.commits, self.ops = commits, 0

    def update(self, ref, fields):
        self.ops += 1

    def commit(self):
        self.commits.append(self.ops)


def test_stamp_samples_chunks_batches():
    commits = []

    class DB:
        def batch(self):
            return FakeBatch(commits)

        def collection(self, name):
            return FakeRef([], name)

    weekly_retrain.stamp_samples(DB(), [f"p{i}" for i in range(950)], {"usedInVersion": 4})
    assert commits == [400, 400, 150]


def test_evaluate_real_metrics(small_model):
    m = weekly_retrain.evaluate(small_model, fake_base(), fake_real(6))
    assert m["n_real_holdout"] == 6 and m["mae_real"] is not None and m["auc_real"] is not None


def test_coreml_structure(small_model):
    mlm = to_coreml(small_model, X_COLUMNS)
    publish.validate_spec(mlm, small_model.n_estimators, booster_base_score(small_model))


@pytest.mark.skipif(sys.platform != "darwin", reason="Core ML prediction needs macOS")
def test_coreml_matches_xgboost_with_missing(small_model):
    mlm = to_coreml(small_model, X_COLUMNS)
    rows = fake_features(5, nan_frac=0.4)
    expected = small_model.predict(to_matrix(rows))
    for row, exp in zip(rows, expected):
        got = mlm.predict({k: (np.nan if v is None else v) for k, v in row.items()})[TARGET_COL]
        assert abs(got - exp) < 1e-4


def test_persona_features_are_deterministic():
    a, b = publish.persona_features(), publish.persona_features()
    assert a == b and set(a) == {"semi_high", "high", "average"}
    assert all(len(f) == len(X_COLUMNS) for f in a.values())


class FakeBlob:
    def __init__(self, log, path):
        self.log, self.path = log, path

    def upload_from_filename(self, f):
        self.log.append(("storage", self.path))

    def upload_from_string(self, s, content_type=None):
        self.log.append(("storage", self.path, json.loads(s)))


class FakeBucket:
    def __init__(self, log):
        self.log = log

    def blob(self, path):
        return FakeBlob(self.log, path)


class FakeRef:
    def __init__(self, log, path):
        self.log, self.path = log, path

    def collection(self, name):
        return FakeRef(self.log, f"{self.path}/{name}")

    def document(self, name):
        return FakeRef(self.log, f"{self.path}/{name}")

    def set(self, data, merge=False):
        self.log.append(("firestore", self.path, data))


class FakeDB(FakeRef):
    def __init__(self, log):
        super().__init__(log, "")

    def collection(self, name):
        return FakeRef(self.log, name)


def test_publish_uploads_then_switches_current_last(small_model):
    log = []
    version = publish.publish(FakeDB(log), FakeBucket(log), small_model, {"mae_synth": 0.1}, {"version": 3}, "run1")
    assert version == 4
    paths = [e[1] for e in log]
    assert paths[:3] == ["ml/models/v4/PPDRiskModel.mlmodel", "ml/models/v4/ppd_xgb_artifact.pkl",
                         "ml/models/v4/metrics.json"]
    assert paths[3:] == ["ml_models/history/versions/v4", "ml/models/current.json", "ml_models/current"]
    current = log[-1][2]
    assert current["version"] == 4 and len(current["sha256"]) == 64
    assert current["mlmodelPath"] == "ml/models/v4/PPDRiskModel.mlmodel"
