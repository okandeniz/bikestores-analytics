from datetime import datetime, timezone
import hashlib
import json

import numpy as np
import pandas as pd
from sqlalchemy import text

from script.late_shipment_predictor import (
    LateShipmentPredictor,
)
from src.database import create_db_engine


PREDICTION_TABLE = (
    "ml_late_shipment_predictions"
)

METRICS_TABLE = (
    "ml_late_shipment_model_metrics"
)


def build_model_version(predictor):
    """
    Create a stable version ID from the model metadata
    when an explicit version is not stored.
    """

    explicit_version = predictor.metadata.get(
        "model_version"
    )

    if explicit_version:
        return explicit_version

    version_payload = {
        "model_name": predictor.model_name,
        "threshold": predictor.threshold,
        "training_start":
            predictor.metadata.get(
                "training_start"
            ),
        "training_end":
            predictor.metadata.get(
                "training_end"
            ),
        "hyperparameters":
            predictor.metadata.get(
                "hyperparameters"
            ),
    }

    serialized = json.dumps(
        version_payload,
        sort_keys=True,
        default=str,
    )

    digest = hashlib.sha256(
        serialized.encode("utf-8")
    ).hexdigest()[:10]

    return f"late-shipment-{digest}"


def build_prediction_dataframe(
    predictor,
    model_version,
):
    """
    Score all saved historical test samples.
    """

    if not predictor.test_samples:
        raise ValueError(
            "No historical test samples found."
        )

    raw = pd.DataFrame(
        predictor.test_samples
    )

    predictions = predictor.predict(
        raw
    )

    if predictions.empty:
        raise ValueError(
            "Late shipment prediction output is empty."
        )

    predictions["order_date"] = pd.to_datetime(
        predictions["order_date"]
    ).dt.date

    actual = predictions[
        "actual_is_late"
    ].astype(int)

    predicted = predictions[
        "predicted_late"
    ].astype(int)

    predictions["prediction_result"] = np.select(
        [
            (actual == 1) & (predicted == 1),
            (actual == 0) & (predicted == 0),
            (actual == 0) & (predicted == 1),
            (actual == 1) & (predicted == 0),
        ],
        [
            "TP",
            "TN",
            "FP",
            "FN",
        ],
        default=None,
    )

    predictions["is_correct"] = (
        actual == predicted
    ).astype(int)

    predictions["model_version"] = (
        model_version
    )

    predictions["prediction_scope"] = (
        "historical_test"
    )

    predictions["scored_at"] = (
        datetime.now(timezone.utc)
        .replace(tzinfo=None)
    )

    columns = [
        "model_version",
        "prediction_scope",

        "order_id",
        "order_date",

        "store_id",
        "staff_id",

        "required_lead_days",
        "distinct_products",
        "total_units",

        "net_order_value",
        "effective_discount_pct",

        "late_probability",
        "late_probability_pct",

        "predicted_late",
        "risk_alert",

        "decision_threshold",

        "actual_is_late",

        "prediction_result",
        "is_correct",

        "scored_at",
    ]

    return predictions[
        columns
    ].copy()


def build_metrics_dataframe(
    predictor,
    model_version,
):
    """
    Convert saved model metadata into
    a Power BI friendly SQL row.
    """

    metadata = predictor.metadata
    evaluation = metadata.get(
        "evaluation",
        {}
    )

    row = {
        "model_version":
            model_version,

        "model_name":
            predictor.model_name,

        "decision_threshold":
            predictor.threshold,

        "roc_auc":
            evaluation.get("roc_auc"),

        "pr_auc":
            evaluation.get("pr_auc"),

        "precision_score":
            evaluation.get("precision"),

        "recall_score":
            evaluation.get("recall"),

        "f1_score":
            evaluation.get("f1"),

        "f2_score":
            evaluation.get("f2"),

        "training_rows":
            metadata.get("training_rows"),

        "training_start":
            metadata.get("training_start"),

        "training_end":
            metadata.get("training_end"),

        "test_period":
            evaluation.get("test_period"),

        "generated_at":
            datetime.now(timezone.utc)
            .replace(tzinfo=None),
    }

    df = pd.DataFrame([row])

    for column in [
        "training_start",
        "training_end",
    ]:
        if df[column].notna().any():
            df[column] = pd.to_datetime(
                df[column]
            ).dt.date

    return df


def validate_predictions(df):
    """
    Validate exported prediction rows.
    """

    if df.empty:
        raise ValueError(
            "Prediction dataframe is empty."
        )

    key_columns = [
        "model_version",
        "prediction_scope",
        "order_id",
    ]

    if df[key_columns].duplicated().any():
        raise ValueError(
            "Duplicate prediction keys found."
        )

    probability = df[
        "late_probability"
    ]

    if (
        (probability < 0)
        | (probability > 1)
    ).any():
        raise ValueError(
            "Invalid late probabilities found."
        )

    if not set(
        df["predicted_late"].unique()
    ).issubset({0, 1}):
        raise ValueError(
            "Invalid predicted_late values."
        )

    if not set(
        df["actual_is_late"].unique()
    ).issubset({0, 1}):
        raise ValueError(
            "Invalid actual_is_late values."
        )


def upsert_predictions(
    engine,
    df,
):
    query = text(
        f"""
        INSERT INTO {PREDICTION_TABLE} (
            model_version,
            prediction_scope,

            order_id,
            order_date,

            store_id,
            staff_id,

            required_lead_days,
            distinct_products,
            total_units,

            net_order_value,
            effective_discount_pct,

            late_probability,
            late_probability_pct,

            predicted_late,
            risk_alert,

            decision_threshold,

            actual_is_late,

            prediction_result,
            is_correct,

            scored_at
        )
        VALUES (
            :model_version,
            :prediction_scope,

            :order_id,
            :order_date,

            :store_id,
            :staff_id,

            :required_lead_days,
            :distinct_products,
            :total_units,

            :net_order_value,
            :effective_discount_pct,

            :late_probability,
            :late_probability_pct,

            :predicted_late,
            :risk_alert,

            :decision_threshold,

            :actual_is_late,

            :prediction_result,
            :is_correct,

            :scored_at
        )
        ON DUPLICATE KEY UPDATE
            late_probability =
                VALUES(late_probability),

            late_probability_pct =
                VALUES(late_probability_pct),

            predicted_late =
                VALUES(predicted_late),

            risk_alert =
                VALUES(risk_alert),

            decision_threshold =
                VALUES(decision_threshold),

            actual_is_late =
                VALUES(actual_is_late),

            prediction_result =
                VALUES(prediction_result),

            is_correct =
                VALUES(is_correct),

            scored_at =
                VALUES(scored_at);
        """
    )

    records = df.to_dict(
        orient="records"
    )

    with engine.begin() as connection:
        connection.execute(
            query,
            records,
        )


def upsert_metrics(
    engine,
    df,
):
    query = text(
        f"""
        INSERT INTO {METRICS_TABLE} (
            model_version,
            model_name,
            decision_threshold,

            roc_auc,
            pr_auc,
            precision_score,
            recall_score,
            f1_score,
            f2_score,

            training_rows,
            training_start,
            training_end,

            test_period,
            generated_at
        )
        VALUES (
            :model_version,
            :model_name,
            :decision_threshold,

            :roc_auc,
            :pr_auc,
            :precision_score,
            :recall_score,
            :f1_score,
            :f2_score,

            :training_rows,
            :training_start,
            :training_end,

            :test_period,
            :generated_at
        )
        ON DUPLICATE KEY UPDATE
            model_name =
                VALUES(model_name),

            decision_threshold =
                VALUES(decision_threshold),

            roc_auc =
                VALUES(roc_auc),

            pr_auc =
                VALUES(pr_auc),

            precision_score =
                VALUES(precision_score),

            recall_score =
                VALUES(recall_score),

            f1_score =
                VALUES(f1_score),

            f2_score =
                VALUES(f2_score),

            training_rows =
                VALUES(training_rows),

            training_start =
                VALUES(training_start),

            training_end =
                VALUES(training_end),

            test_period =
                VALUES(test_period),

            generated_at =
                VALUES(generated_at);
        """
    )

    records = (
        df.where(
            pd.notna(df),
            None,
        )
        .to_dict(
            orient="records"
        )
    )

    with engine.begin() as connection:
        connection.execute(
            query,
            records,
        )


def main():
    print(
        "Loading saved late shipment model..."
    )

    predictor = LateShipmentPredictor()

    model_version = build_model_version(
        predictor
    )

    print(
        "Model version:",
        model_version,
    )

    print(
        "Scoring historical test samples..."
    )

    predictions_df = (
        build_prediction_dataframe(
            predictor,
            model_version,
        )
    )

    validate_predictions(
        predictions_df
    )

    metrics_df = (
        build_metrics_dataframe(
            predictor,
            model_version,
        )
    )

    print(
        "\nPrediction preview:"
    )

    print(
        predictions_df.head().to_string(
            index=False
        )
    )

    print(
        "\nPrediction rows:",
        len(predictions_df)
    )

    print(
        "Alerts:",
        int(
            predictions_df[
                "predicted_late"
            ].sum()
        )
    )

    print(
        "\nConnecting to MySQL..."
    )

    engine = create_db_engine()

    try:
        upsert_predictions(
            engine,
            predictions_df,
        )

        upsert_metrics(
            engine,
            metrics_df,
        )

    finally:
        engine.dispose()

    print(
        "\nLate shipment export completed."
    )


if __name__ == "__main__":
    main()