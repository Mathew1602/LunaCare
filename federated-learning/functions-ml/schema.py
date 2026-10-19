"""Feature names and schema version. No heavy imports, so the Firestore trigger stays light."""
FEATURE_SCHEMA_VERSION = 1
WINDOW_DAYS = 30
TARGET_COL = "ppd_risk_score_0to1"

BASE_FEATURES = [
    "fatigue_1to10", "mood_1to5", "bleeding_1to10", "hair_loss_1to10",
    "appetite_issue_1to10", "sleep_trouble_1to10",
    "sleep_hours", "deep_sleep_hours", "rem_sleep_hours", "core_sleep_hours",
    "sleep_efficiency_pct", "wake_after_sleep_onset_min",
    "avg_heart_rate_bpm", "resting_heart_rate_bpm", "walking_heart_rate_avg_bpm",
    "hrv_sdnn_ms", "respiratory_rate_bpm", "oxygen_saturation_pct", "vo2max_ml_kg_min",
    "steps", "distance_walked_km", "flights_climbed", "active_energy_kcal",
    "basal_energy_kcal", "exercise_minutes", "stand_hours", "sunlight_hours", "weight_kg",
]
SUFFIXES = ["mean", "std", "min", "max", "slope", "last"]
X_COLUMNS = [f"{base}_{suffix}" for base in BASE_FEATURES for suffix in SUFFIXES]
