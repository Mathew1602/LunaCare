"""The notebook's 3 test personas (semi-high, high, average), seeded so every model version can be
scored on identical inputs. Scores + features go into metrics.json for the Step 10 Mac parity test."""
import numpy as np
import pandas as pd

from features import BASE_FEATURES, summarize_window

DAYS = 30


def _window(cols: dict) -> pd.DataFrame:
    return pd.DataFrame({b: np.asarray(cols[b], dtype=float) for b in BASE_FEATURES})


def _semi_high(rng):
    sleep_trouble = rng.normal(7.5, 1.0, DAYS).clip(1, 10)
    resting_hr = np.linspace(72, 82, DAYS)
    fatigue = (0.5 * 6.5 + 0.4 * sleep_trouble + 0.015 * (resting_hr - 65) + rng.normal(0, 0.6, DAYS)).clip(1, 10)
    const = dict(bleeding_1to10=2, hair_loss_1to10=1, appetite_issue_1to10=6, sleep_hours=6.5,
                 deep_sleep_hours=1.0, rem_sleep_hours=1.5, core_sleep_hours=4.0, sleep_efficiency_pct=80,
                 wake_after_sleep_onset_min=30, avg_heart_rate_bpm=85, walking_heart_rate_avg_bpm=100,
                 hrv_sdnn_ms=35, respiratory_rate_bpm=16, oxygen_saturation_pct=98, vo2max_ml_kg_min=30,
                 distance_walked_km=2.0, flights_climbed=1, active_energy_kcal=200, basal_energy_kcal=1400,
                 exercise_minutes=5, stand_hours=6, weight_kg=68)
    return _window({
        "mood_1to5": rng.normal(2.2, 0.4, DAYS).clip(1, 5),
        "sleep_trouble_1to10": sleep_trouble, "fatigue_1to10": fatigue,
        "resting_heart_rate_bpm": resting_hr,
        "steps": rng.normal(2500, 500, DAYS).clip(0, 20000),
        "sunlight_hours": rng.normal(0.2, 0.1, DAYS).clip(0, 24),
        **{k: [v] * DAYS for k, v in const.items()},
    })


def _high(rng):
    sleep_trouble = rng.normal(7.0, 1.0, DAYS).clip(1, 10)
    resting_hr = np.linspace(75, 85, DAYS)
    fatigue = (0.5 * 7.5 + 0.4 * sleep_trouble + 0.015 * (resting_hr - 65) + rng.normal(0, 0.7, DAYS)).clip(1, 10)
    const = dict(bleeding_1to10=2, hair_loss_1to10=1, appetite_issue_1to10=5, sleep_hours=6,
                 deep_sleep_hours=1, rem_sleep_hours=1.5, core_sleep_hours=3.5, sleep_efficiency_pct=85,
                 wake_after_sleep_onset_min=20, avg_heart_rate_bpm=80, walking_heart_rate_avg_bpm=95,
                 hrv_sdnn_ms=30, respiratory_rate_bpm=16, oxygen_saturation_pct=98, vo2max_ml_kg_min=35,
                 distance_walked_km=1.5, flights_climbed=2, active_energy_kcal=150, basal_energy_kcal=1400,
                 exercise_minutes=10, stand_hours=8, weight_kg=70)
    return _window({
        "mood_1to5": rng.normal(2.0, 0.5, DAYS).clip(1, 5),
        "sleep_trouble_1to10": sleep_trouble, "fatigue_1to10": fatigue,
        "resting_heart_rate_bpm": resting_hr,
        "steps": rng.normal(2000, 500, DAYS).clip(0, 10000),
        "sunlight_hours": rng.normal(0.5, 0.2, DAYS).clip(0, 24),
        **{k: [v] * DAYS for k, v in const.items()},
    })


def _average(rng):
    n = DAYS
    return _window({
        "mood_1to5": rng.normal(4.2, 0.5, n).clip(1, 5).round(0),
        "sleep_trouble_1to10": rng.normal(1.5, 0.5, n).clip(1, 10).round(0),
        "resting_heart_rate_bpm": rng.normal(65, 2, n),
        "steps": rng.normal(8500, 1500, n).clip(0, 20000),
        "sunlight_hours": rng.normal(3.5, 1.0, n).clip(0, 24),
        "fatigue_1to10": rng.normal(2.0, 0.5, n).clip(1, 10).round(0),
        "bleeding_1to10": np.clip(5 * np.exp(-0.2 * np.arange(n)), 1, 10).round(0),
        "hair_loss_1to10": rng.normal(1.5, 0.5, n).clip(1, 10).round(0),
        "appetite_issue_1to10": rng.normal(5.0, 0.5, n).clip(1, 10).round(0),
        "sleep_hours": rng.normal(7.5, 0.8, n).clip(3, 12),
        "deep_sleep_hours": rng.normal(1.5, 0.3, n).clip(0, 5),
        "rem_sleep_hours": rng.normal(2.0, 0.4, n).clip(0, 5),
        "core_sleep_hours": rng.normal(4.0, 0.5, n).clip(0, 10),
        "sleep_efficiency_pct": rng.normal(95, 2, n).clip(0, 100),
        "wake_after_sleep_onset_min": rng.normal(15, 5, n).clip(0, 100),
        "avg_heart_rate_bpm": rng.normal(75, 5, n),
        "walking_heart_rate_avg_bpm": rng.normal(100, 10, n),
        "hrv_sdnn_ms": rng.normal(65, 10, n).clip(10, 150),
        "respiratory_rate_bpm": rng.normal(14, 1, n),
        "oxygen_saturation_pct": rng.normal(99, 0.5, n).clip(90, 100),
        "vo2max_ml_kg_min": rng.normal(45, 2, n),
        "distance_walked_km": rng.normal(5.0, 1.0, n),
        "flights_climbed": rng.normal(5, 2, n),
        "active_energy_kcal": rng.normal(400, 50, n),
        "basal_energy_kcal": rng.normal(1400, 20, n),
        "exercise_minutes": rng.normal(45, 15, n),
        "stand_hours": rng.normal(12, 2, n),
        "weight_kg": rng.normal(65, 0.5, n),
    })


def persona_features(seed: int = 42) -> dict:
    """{name: {feature: float}} for the 3 notebook personas."""
    rng = np.random.default_rng(seed)
    return {name: {k: float(v) for k, v in summarize_window(fn(rng)).items()}
            for name, fn in (("semi_high", _semi_high), ("high", _high), ("average", _average))}
