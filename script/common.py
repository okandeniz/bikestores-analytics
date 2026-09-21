"""The same monthly features and model settings as the simplified notebook."""

from pathlib import Path

import numpy as np
import pandas as pd
from lightgbm import LGBMRegressor
from sklearn.compose import ColumnTransformer
from sklearn.metrics import mean_absolute_error, mean_squared_error
from sklearn.preprocessing import OneHotEncoder
from xgboost import XGBRegressor

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL_PATH = PROJECT_ROOT / "models" / "demand_forecast.joblib"
KEYS = ["store_id", "category_id", "month_start"]
GROUPS = ["store_id", "category_id"]
CATEGORIES = ["store_id", "category_id", "month"]
NUMBERS = ["lag_1", "lag_2", "lag_3", "rolling_mean_3", "rolling_mean_6"]
FEATURES = CATEGORIES + NUMBERS
METHODS = ["XGBoost", "LightGBM", "Last month", "3-month average", "Last year"]
TRAIN_START = pd.Timestamp("2016-04-01")


def complete_calendar(raw, end_month):
    """Missing source rows mean zero recorded sales, not known stock availability."""
    raw = raw.copy()
    raw["month_start"] = pd.to_datetime(raw["month_start"])
    if raw.empty or raw.duplicated(KEYS).any():
        raise ValueError("Sales must contain unique store-category-month rows.")
    units = pd.to_numeric(raw["units_sold"], errors="raise")
    if not np.isfinite(units).all() or (units < 0).any() or (units % 1 != 0).any():
        raise ValueError("Units sold must be finite, non-negative integers.")
    raw["units_sold"] = units.astype(int)
    months = pd.date_range("2016-01-01", end_month, freq="MS")
    if set(raw["month_start"]) != set(months):
        raise ValueError("The source must cover every month in the requested period.")
    stores = raw[["store_id", "store_name"]].drop_duplicates()
    categories = raw[["category_id", "category_name"]].drop_duplicates()
    if stores["store_id"].duplicated().any() or categories["category_id"].duplicated().any():
        raise ValueError("Each store and category ID must have one name.")
    calendar = pd.MultiIndex.from_product(
        [sorted(stores.store_id), sorted(categories.category_id), months], names=KEYS
    ).to_frame(index=False)
    sales = calendar.merge(raw[KEYS + ["units_sold"]], on=KEYS, how="left", validate="one_to_one")
    added_rows = int(sales.units_sold.isna().sum())
    sales["units_sold"] = sales.units_sold.fillna(0).astype(int)
    sales = sales.merge(stores, on="store_id", validate="many_to_one")
    sales = sales.merge(categories, on="category_id", validate="many_to_one")
    if sales.units_sold.sum() != raw.units_sold.sum():
        raise ValueError("Sales totals changed while completing the calendar.")
    return sales.sort_values(KEYS).reset_index(drop=True), added_rows


def add_sales_features(sales):
    data = sales.sort_values(KEYS).copy()
    data["month"] = data.month_start.dt.month
    grouped_sales = data.groupby(GROUPS)["units_sold"]
    for lag in [1, 2, 3, 12]:
        data[f"lag_{lag}"] = grouped_sales.shift(lag)
    for window in [3, 6]:
        data[f"rolling_mean_{window}"] = grouped_sales.transform(
            lambda values: values.shift(1).rolling(window, min_periods=1).mean()
        )
    return data.sort_values(["month_start", *GROUPS]).reset_index(drop=True)


def create_models():
    # These settings were selected on the notebook's 2017 validation months.
    xgb = XGBRegressor(
        n_estimators=150, learning_rate=0.025, max_depth=3,
        min_child_weight=15, reg_alpha=0.1, reg_lambda=5.0,
        objective="reg:squarederror", tree_method="hist", random_state=42, n_jobs=2,
    )
    lgbm = LGBMRegressor(
        n_estimators=150, learning_rate=0.04, max_depth=3,
        num_leaves=7, min_child_samples=15, reg_lambda=5.0,
        objective="regression_l1", random_state=42, n_jobs=2,
        deterministic=True, force_col_wise=True, verbosity=-1,
    )
    preprocessor = ColumnTransformer([
        ("categories", OneHotEncoder(handle_unknown="ignore", sparse_output=False), CATEGORIES),
        ("numbers", "passthrough", NUMBERS),
    ])
    return preprocessor, {"XGBoost": xgb, "LightGBM": lgbm}


def fit_models(training):
    preprocessor, models = create_models()
    inputs = preprocessor.fit_transform(training[FEATURES])
    models["XGBoost"].fit(inputs, np.log1p(training.units_sold))
    models["LightGBM"].fit(inputs, training.units_sold)
    return preprocessor, models


def predict_models(preprocessor, models, rows):
    inputs = preprocessor.transform(rows[FEATURES])
    result = rows[KEYS + ["units_sold", "store_name", "category_name"]].copy()
    result["XGBoost"] = np.maximum(0, np.expm1(models["XGBoost"].predict(inputs))).astype(float)
    result["LightGBM"] = np.maximum(0, models["LightGBM"].predict(inputs))
    result["Last month"] = rows.lag_1
    result["3-month average"] = rows.rolling_mean_3
    result["Last year"] = rows.lag_12
    if not np.isfinite(result[METHODS].to_numpy()).all():
        raise ValueError("Not enough history for all forecasting methods.")
    return result


def compare_forecasts(predictions):
    scores = []
    actual = predictions.units_sold.to_numpy(dtype=float)
    for name in METHODS:
        predicted = predictions[name].to_numpy(dtype=float)
        error = predicted - actual
        scores.append({
            "model": name, "mae": mean_absolute_error(actual, predicted),
            "rmse": np.sqrt(mean_squared_error(actual, predicted)),
            "wape": float(np.abs(error).sum() / actual.sum() * 100) if actual.sum() else None,
            "bias": float(error.mean()), "rows": len(actual),
        })
    return pd.DataFrame(scores).sort_values("mae").reset_index(drop=True)


def rolling_evaluation(data, months):
    results = []
    expected_rows = data[GROUPS].drop_duplicates().shape[0]
    for month in months:
        train = data[(data.month_start >= TRAIN_START) & (data.month_start < month)]
        forecast = data[data.month_start == month]
        if train.empty or len(forecast) != expected_rows or train.month_start.max() >= month:
            raise ValueError(f"Invalid training/forecast split for {month:%Y-%m}.")
        preprocessor, models = fit_models(train)
        results.append(predict_models(preprocessor, models, forecast))
    return pd.concat(results, ignore_index=True)
