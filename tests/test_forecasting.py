"""Focused tests with synthetic sales. No database or production model is required."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import joblib
import numpy as np
import pandas as pd
from fastapi.testclient import TestClient

from backend.main import create_app
from script.common import (
    FEATURES, GROUPS, TRAIN_START, add_sales_features, complete_calendar,
    fit_models, rolling_evaluation,
)
from script.late_shipment_common import MODEL_FEATURES, build_late_shipment_model
from script.predictor import ForecastPredictor


def sample_sales():
    rows = []
    for store in [1, 2]:
        for category in [1, 2]:
            for index, month in enumerate(pd.date_range("2016-01-01", "2018-03-01", freq="MS")):
                rows.append({"store_id": store, "store_name": f"Store {store}",
                             "category_id": category, "category_name": f"Category {category}",
                             "month_start": month, "units_sold": (store * 5 + category * 3 + index * 2) % 21})
    return pd.DataFrame(rows)


class FeatureTests(unittest.TestCase):
    def test_missing_calendar_month_is_zero_and_lag_is_previous_calendar_month(self):
        raw = sample_sales().drop(index=1)
        history, added = complete_calendar(raw, "2018-03-01")
        self.assertEqual(added, 1)
        self.assertEqual(len(history), 108)
        data = add_sales_features(history)
        march = data[(data.store_id == 1) & (data.category_id == 1) & (data.month_start == "2016-03-01")]
        self.assertEqual(march.lag_1.iloc[0], 0)

    def test_duplicate_or_negative_sales_are_rejected(self):
        raw = sample_sales()
        with self.assertRaises(ValueError):
            complete_calendar(pd.concat([raw, raw.iloc[:1]]), "2018-03-01")
        raw.loc[0, "units_sold"] = -1
        with self.assertRaises(ValueError):
            complete_calendar(raw, "2018-03-01")

    def test_current_and_future_targets_do_not_change_prediction_features(self):
        history = sample_sales()
        original = add_sales_features(history)
        history.loc[history.month_start >= "2017-07-01", "units_sold"] += 1000
        changed = add_sales_features(history)
        earlier = original.month_start <= "2017-07-01"
        pd.testing.assert_frame_equal(original.loc[earlier, FEATURES], changed.loc[earlier, FEATURES])


class ServiceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.path = Path(cls.directory.name) / "model.joblib"
        cls.late_path = Path(cls.directory.name) / "late_model.joblib"
        history = sample_sales()
        data = add_sales_features(history)
        preprocessor, models = fit_models(data[data.month_start >= TRAIN_START])
        validation = rolling_evaluation(data, pd.date_range("2017-07-01", "2017-12-01", freq="MS"))
        test = rolling_evaluation(data, pd.date_range("2018-01-01", "2018-03-01", freq="MS"))
        bundle = {
            "metadata": {"schema_version": 1, "model_version": "test-version", "selected_model": "XGBoost",
                         "forecast_month": "2018-04-01", "test_period": "Jan–Mar 2018",
                         "validation_period": "Jul–Dec 2017", "data_start": "2016-01-01",
                         "data_end": "2018-03-01", "trained_at": "2026-09-18T12:00:00+00:00",
                         "series_count": 4, "history_rows": 108, "added_zero_rows": 0,
                         "features": FEATURES, "versions": {"scikit-learn": "test"},
                         "training_rows": 72},
            "history": history, "preprocessor": preprocessor, "models": models,
            "validation_predictions": validation, "test_predictions": test,
        }
        joblib.dump(bundle, cls.path)

        late_rows = []
        targets = []
        for index in range(48):
            store_id = 1 if index % 2 == 0 else 2
            staff_id = 10 if store_id == 1 else 20
            lead_days = index % 5 + 1
            distinct_products = index % 4 + 1
            total_units = distinct_products + index % 6
            late_rows.append({
                "store_id": store_id, "staff_id": staff_id,
                "order_month_number": index % 12 + 1, "order_dayofweek": index % 7,
                "required_lead_days": lead_days, "distinct_products": distinct_products,
                "total_units": total_units, "net_order_value": 500.0 + index * 75,
                "effective_discount_pct": float(index % 15),
            })
            targets.append(int(lead_days <= 2 or total_units >= 7))
        late_model = build_late_shipment_model()
        late_model.fit(pd.DataFrame(late_rows)[MODEL_FEATURES], targets)
        joblib.dump({
            "model": late_model, "threshold": 0.20, "model_features": MODEL_FEATURES,
            "model_name": "Test Logistic Regression",
            "metadata": {
                "training_rows": 48, "training_start": "2016-01-01",
                "training_end": "2017-12-31", "training_late_rate": 0.33,
                "evaluation": {
                    "test_period": "2018-01-01 to 2018-03-31", "roc_auc": 0.80,
                    "pr_auc": 0.56, "precision": 0.45, "recall": 1.0,
                    "f1": 0.62, "f2": 0.80,
                },
            },
            "test_samples": [{
                "order_id": 101, "order_date": "2018-02-15", "store_id": 1,
                "staff_id": 10, "required_lead_days": 2, "distinct_products": 3,
                "total_units": 6, "net_order_value": 1200.0,
                "effective_discount_pct": 5.0, "actual_is_late": 1,
            }],
            "reference_data": {
                "stores": [
                    {"store_id": 1, "store_name": "Store 1"},
                    {"store_id": 2, "store_name": "Store 2"},
                ],
                "staff": [
                    {"staff_id": 10, "staff_name": "Staff 1", "store_id": 1},
                    {"staff_id": 20, "staff_name": "Staff 2", "store_id": 2},
                ],
            },
        }, cls.late_path)

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    def test_saved_predictor_does_not_refit_and_predictions_are_nonnegative(self):
        predictor = ForecastPredictor(self.path)
        with patch.object(predictor.models["XGBoost"], "fit", side_effect=AssertionError("Must not refit")):
            result = predictor.forecast()
        self.assertEqual(len(result["rows"]), 4)
        self.assertTrue(all(row["prediction"] >= 0 for row in result["rows"]))
        self.assertAlmostEqual(sum(row["prediction"] for row in result["rows"]), result["summary"]["forecast_units"])
        # Strict JSON serialization fails on NaN or infinity.
        json.dumps(result, allow_nan=False)

    def test_filters_and_horizon_are_validated(self):
        predictor = ForecastPredictor(self.path)
        self.assertEqual(len(predictor.forecast(store_id=1, category_id=2)["rows"]), 1)
        with self.assertRaises(ValueError):
            predictor.forecast(store_id=99)
        with self.assertRaises(ValueError):
            predictor.forecast("2018-05-01")

    def test_api_contracts_validation_and_filtered_metrics(self):
        with TestClient(create_app(self.path, self.late_path)) as client:
            self.assertEqual(client.get("/health").status_code, 200)
            self.assertEqual(client.get("/model-info").status_code, 200)
            response = client.post("/forecast", json={"store_id": 1, "category_id": 2})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(len(response.json()["rows"]), 1)
            for body in [{"store_id": 99}, {"store_id": "1"}, {"month": "2018-05-01"}, {"month": "bad"}, {"extra": 1}]:
                self.assertEqual(client.post("/forecast", json=body).status_code, 422)
            response = client.get("/performance", params={"store_id": 1, "category_id": 2})
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertTrue(all(row["rows"] == 3 for row in data["scores"]))
            actual = np.array([row["units_sold"] for row in data["predictions"]])
            predicted = np.array([row["XGBoost"] for row in data["predictions"]])
            xgb_score = next(row for row in data["scores"] if row["model"] == "XGBoost")
            self.assertAlmostEqual(xgb_score["mae"], np.abs(predicted - actual).mean(), places=8)
            self.assertEqual(client.get("/performance?period=invalid").status_code, 422)

    def test_late_shipment_api_returns_probability_prediction_and_advice(self):
        with TestClient(create_app(self.path, self.late_path)) as client:
            info = client.get("/late-shipment/model-info")
            self.assertEqual(info.status_code, 200)
            self.assertEqual(len(info.json()["stores"]), 2)
            self.assertEqual(info.json()["test_sample_count"], 1)
            self.assertEqual(info.json()["evaluation"]["roc_auc"], 0.80)

            sample = client.get("/late-shipment/random-test-order")
            self.assertEqual(sample.status_code, 200)
            self.assertEqual(sample.json()["order_id"], 101)
            self.assertEqual(sample.json()["actual_is_late"], 1)

            body = {
                "order_date": "2026-09-18", "store_id": 1, "staff_id": 10,
                "required_lead_days": 2, "distinct_products": 3, "total_units": 6,
                "net_order_value": 1200.0, "effective_discount_pct": 5.0,
            }
            response = client.post("/late-shipment/predict", json=body)
            self.assertEqual(response.status_code, 200)
            result = response.json()
            self.assertGreaterEqual(result["late_probability"], 0)
            self.assertLessEqual(result["late_probability"], 1)
            self.assertIn(result["prediction"], ["Gecikebilir", "Zamanında gönderilebilir"])
            self.assertTrue(result["recommendation"]["actions"])

            invalid_pair = {**body, "staff_id": 20}
            self.assertEqual(client.post("/late-shipment/predict", json=invalid_pair).status_code, 422)
            invalid_count = {**body, "distinct_products": 8, "total_units": 4}
            self.assertEqual(client.post("/late-shipment/predict", json=invalid_count).status_code, 422)

    def test_missing_model_is_not_reported_as_healthy(self):
        missing_path = Path(self.directory.name) / "missing.joblib"
        with TestClient(create_app(missing_path, self.late_path)) as client:
            self.assertEqual(client.get("/health").status_code, 503)
            self.assertEqual(client.get("/model-info").status_code, 503)
            self.assertEqual(client.post("/forecast", json={}).status_code, 503)


if __name__ == "__main__":
    unittest.main()
