"""Train and save the forecast bundle: python -m script.train."""

import argparse
import hashlib
import importlib.metadata
import json
from datetime import datetime, timezone
from pathlib import Path

import joblib
import pandas as pd

from script.common import (
    DEFAULT_MODEL_PATH, FEATURES, GROUPS, PROJECT_ROOT, TRAIN_START,
    add_sales_features, compare_forecasts, complete_calendar, fit_models, rolling_evaluation,
)


def load_sales(end_month):
    # Import database configuration only during training. Serving works without MySQL.
    from src.database import create_db_engine

    query = """
        SELECT DATE_FORMAT(order_date, '%%Y-%%m-01') AS month_start,
               store_id, store_name, category_id, category_name,
               SUM(realized_units_sold) AS units_sold
        FROM vw_excel_order_items
        WHERE order_date >= %(start)s AND order_date < %(end)s AND is_completed = 1
        GROUP BY DATE_FORMAT(order_date, '%%Y-%%m-01'),
                 store_id, store_name, category_id, category_name
        ORDER BY store_id, category_id, month_start
    """
    engine = create_db_engine()
    try:
        return pd.read_sql_query(query, engine, params={
            "start": "2016-01-01", "end": (end_month + pd.offsets.MonthBegin(1)).date(),
        })
    finally:
        engine.dispose()


def train(end_month="2018-03", model_path=DEFAULT_MODEL_PATH):
    end = pd.Timestamp(end_month)
    if end.day != 1 or end < pd.Timestamp("2018-03-01"):
        raise ValueError("Use a month start from March 2018 onward, for example 2018-03.")
    raw = load_sales(end)
    history, added_rows = complete_calendar(raw, end)
    data = add_sales_features(history)

    # Select using 2017 only. The test never changes the selected settings.
    validation = rolling_evaluation(data, pd.date_range("2017-07-01", "2017-12-01", freq="MS"))
    validation_scores = compare_forecasts(validation)
    selected_model = validation_scores.loc[0, "model"]
    test = rolling_evaluation(data, pd.date_range("2018-01-01", "2018-03-01", freq="MS"))
    test_scores = compare_forecasts(test)

    # Fit fresh production models on all available history, not just the last test fold.
    production_training = data[data.month_start >= TRAIN_START]
    preprocessor, models = fit_models(production_training)
    created_at = datetime.now(timezone.utc).isoformat()
    history_hash = hashlib.sha256(history.to_csv(index=False).encode()).hexdigest()
    metadata = {
        "schema_version": 1,
        "model_version": f"{datetime.now(timezone.utc):%Y%m%dT%H%M%S}-{history_hash[:8]}",
        "trained_at": created_at,
        "selected_model": selected_model,
        "data_start": history.month_start.min().strftime("%Y-%m-%d"),
        "data_end": end.strftime("%Y-%m-%d"),
        "forecast_month": (end + pd.offsets.MonthBegin(1)).strftime("%Y-%m-%d"),
        "training_start": TRAIN_START.strftime("%Y-%m-%d"),
        "history_rows": len(history), "training_rows": len(production_training),
        "series_count": history[GROUPS].drop_duplicates().shape[0],
        "added_zero_rows": added_rows, "features": FEATURES,
        "validation_period": "July–December 2017", "test_period": "January–March 2018",
        "target": "Recorded completed sales, in units",
        "horizon": "One month ahead",
        "data_sha256": history_hash,
        "versions": {name: importlib.metadata.version(name) for name in
                     ["pandas", "numpy", "scikit-learn", "xgboost", "lightgbm", "joblib"]},
        "notes": [
            "Missing source rows are zero recorded sales; historical stock availability is unknown.",
            "Historical completed-sales totals are assumed known before each forecast month.",
            "Settings were chosen on 2017 validation; the three-month historical test is limited evidence.",
            "Predictions use the saved data snapshot. Retrain and restart the API after a completed month is added.",
        ],
    }
    bundle = {
        "metadata": metadata, "preprocessor": preprocessor, "models": models,
        "history": history, "validation_predictions": validation, "test_predictions": test,
    }
    model_path = Path(model_path).resolve()
    model_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = model_path.with_suffix(".tmp")
    joblib.dump(bundle, temporary, compress=3)
    temporary.replace(model_path)
    model_path.with_suffix(".json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")

    output_dir = PROJECT_ROOT / "outputs" / "ml" / "service_training"
    output_dir.mkdir(parents=True, exist_ok=True)
    history.to_csv(output_dir / "monthly_sales.csv", index=False)
    validation.to_csv(output_dir / "validation_predictions.csv", index=False)
    test.to_csv(output_dir / "test_predictions.csv", index=False)
    validation_scores.to_csv(output_dir / "validation_scores.csv", index=False)
    test_scores.to_csv(output_dir / "test_scores.csv", index=False)
    print("Selected on validation:", selected_model)
    print(test_scores.to_string(index=False))
    print("Saved model and preprocessor:", model_path)
    print("Next forecast month:", metadata["forecast_month"])
    return model_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--end-month", default="2018-03", help="Last fully observed month (YYYY-MM).")
    parser.add_argument("--model-path", type=Path, default=DEFAULT_MODEL_PATH)
    args = parser.parse_args()
    train(args.end_month, args.model_path)
