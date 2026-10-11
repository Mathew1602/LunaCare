import numpy as np
import pandas as pd

from schema import BASE_FEATURES, FEATURE_SCHEMA_VERSION, SUFFIXES, TARGET_COL, WINDOW_DAYS, X_COLUMNS  # noqa: F401


def summarize_window(window: pd.DataFrame) -> dict:
    """Mirror of PPDFeaturePipeline.rawFeatures. One row per day in window order; missing = NaN.

    Same as the notebook's summarize_user_window except `_last` is the last observed value.
    The notebook used the day-30 value, which is NaN for some synthetic users (hrv, SpO2, VO2max,
    weight), so v1 saw slightly different `_last` features. Retrained models (v2+) use this function.
    """
    x = np.arange(len(window), dtype=float)
    feats = {}
    for base in BASE_FEATURES:
        y = window[base].to_numpy(dtype=float) if base in window else np.full(len(window), np.nan)
        mask = ~np.isnan(y)
        obs = y[mask]
        n = obs.size
        feats[f"{base}_mean"] = obs.mean() if n else np.nan
        feats[f"{base}_std"] = obs.std(ddof=1) if n >= 2 else np.nan
        feats[f"{base}_min"] = obs.min() if n else np.nan
        feats[f"{base}_max"] = obs.max() if n else np.nan
        feats[f"{base}_slope"] = np.polyfit(x[mask], obs, 1)[0] if n >= 2 else np.nan
        feats[f"{base}_last"] = obs[-1] if n else np.nan
    return feats


def to_matrix(rows: list) -> pd.DataFrame:
    """Feature dicts (None = missing) -> float DataFrame in training column order."""
    return pd.DataFrame(rows).reindex(columns=X_COLUMNS).astype(float)
