# script/late_shipment_train.py

from pathlib import Path
import json
import sys

import joblib
import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(
        0,
        str(PROJECT_ROOT),
    )


from src.database import create_db_engine

from script.late_shipment_common import (
    MODEL_FEATURES,
    TARGET,
    FINAL_THRESHOLD,
    BEST_LOGISTIC_PARAMS,
    build_late_shipment_model,
)

START_DATE = "2016-01-01"
END_DATE_EXCLUSIVE = "2018-04-01"
TEST_START_DATE = "2018-01-01"
TEST_END_DATE_EXCLUSIVE = "2018-04-01"

MODEL_DIR = (
    PROJECT_ROOT
    / "models"
)

MODEL_PATH = (
    MODEL_DIR
    / "late_shipment_risk.joblib"
)

METADATA_PATH = (
    MODEL_DIR
    / "late_shipment_risk.json"
)

TEST_SAMPLES_PATH = (
    MODEL_DIR
    / "late_shipment_test_samples.json"
)

def load_training_data():
    """
    Load reliable completed orders from MySQL.
    """

    query = """
    SELECT
        order_id,
        order_date,
        required_date,

        store_id,
        store_name,

        staff_id,
        staff_name,

        distinct_products,
        total_units,

        net_order_value,
        effective_discount_pct,

        required_lead_days,
        is_late

    FROM vw_excel_orders

    WHERE is_reliable_period = 1
    AND is_completed = 1
    AND shipped_date IS NOT NULL
    AND is_late IS NOT NULL
    AND order_date >= %(start_date)s
    AND order_date < %(end_date)s

    ORDER BY
        order_date,
        order_id;
    """

    engine = create_db_engine()

    try:
        data = pd.read_sql_query(
            query,
            engine,
            params={
                "start_date": START_DATE,
                "end_date": END_DATE_EXCLUSIVE,
            },
        )

    finally:
        engine.dispose()

    return data

def build_reference_data(data):
    """
    Build store and staff reference data
    for the prediction interface.
    """

    stores = (
        data[
            [
                "store_id",
                "store_name",
            ]
        ]
        .drop_duplicates()
        .sort_values("store_id")
        .to_dict(
            orient="records"
        )
    )

    staff = (
        data[
            [
                "staff_id",
                "staff_name",
                "store_id",
            ]
        ]
        .drop_duplicates()
        .sort_values(
            [
                "store_id",
                "staff_id",
            ]
        )
        .to_dict(
            orient="records"
        )
    )

    return {
        "stores": stores,
        "staff": staff,
    }

def build_test_samples(data):
    """Prepare raw orders from the model's historical test period."""

    test_data = data[
        (data["order_date"] >= TEST_START_DATE)
        & (data["order_date"] < TEST_END_DATE_EXCLUSIVE)
    ].copy()

    columns = [
        "order_id",
        "order_date",
        "store_id",
        "staff_id",
        "required_lead_days",
        "distinct_products",
        "total_units",
        "net_order_value",
        "effective_discount_pct",
        TARGET,
    ]
    test_data = test_data[columns].sort_values("order_id")
    test_data["order_date"] = test_data["order_date"].dt.date.astype(str)
    test_data = test_data.rename(columns={TARGET: "actual_is_late"})

    integer_columns = [
        "order_id",
        "store_id",
        "staff_id",
        "required_lead_days",
        "distinct_products",
        "total_units",
        "actual_is_late",
    ]
    test_data[integer_columns] = test_data[integer_columns].astype(int)
    test_data[["net_order_value", "effective_discount_pct"]] = test_data[
        ["net_order_value", "effective_discount_pct"]
    ].astype(float)

    return test_data.to_dict(orient="records")

def save_test_samples(test_samples):
    """Save test examples separately so the API can use older model bundles."""

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "test_period": f"{TEST_START_DATE} to 2018-03-31",
        "samples": test_samples,
    }
    with open(TEST_SAMPLES_PATH, "w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2)

def prepare_training_data(data):
    """
    Prepare model features and target.
    """

    df = data.copy()

    df["order_date"] = pd.to_datetime(
        df["order_date"]
    )

    df["required_date"] = pd.to_datetime(
        df["required_date"]
    )

    numeric_columns = [
        "distinct_products",
        "total_units",
        "net_order_value",
        "effective_discount_pct",
        "required_lead_days",
    ]

    for column in numeric_columns:
        df[column] = pd.to_numeric(
            df[column],
            errors="coerce",
        )

    df["is_late"] = (
        df["is_late"]
        .astype("int8")
    )

    df["order_month_number"] = (
        df["order_date"]
        .dt.month
    )

    df["order_dayofweek"] = (
        df["order_date"]
        .dt.dayofweek
    )

    return df

def validate_training_data(data):
    """
    Validate the final training dataset.
    """

    if data.empty:
        raise ValueError(
            "Training dataset is empty."
        )

    if not data["order_id"].is_unique:
        raise ValueError(
            "Duplicate order IDs found."
        )

    target_values = set(
        data[TARGET].unique()
    )

    if not target_values.issubset(
        {0, 1}
    ):
        raise ValueError(
            "Target contains invalid values."
        )

    missing_features = (
        data[MODEL_FEATURES]
        .isna()
        .sum()
    )

    if missing_features.sum() > 0:
        print(
            "Warning: Missing feature values detected."
        )

        print(
            missing_features[
                missing_features > 0
            ]
        )

def train_model(data):
    """
    Train the final production model.
    """

    X = data[
        MODEL_FEATURES
    ].copy()

    y = data[
        TARGET
    ].copy()

    model = build_late_shipment_model()

    model.fit(
        X,
        y,
    )

    return model

def save_model_bundle(
    model,
    training_data,
):
    """
    Save model and metadata.
    """

    MODEL_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    reference_data = build_reference_data(
        training_data
    )
    test_samples = build_test_samples(training_data)

    bundle = {
        "model": model,
        "threshold": FINAL_THRESHOLD,
        "model_features": MODEL_FEATURES,
        "model_name":
            "Tuned Logistic Regression",
        "target": TARGET,
        "reference_data": reference_data,
        "test_samples": test_samples,
    }

    joblib.dump(
        bundle,
        MODEL_PATH,
    )
    save_test_samples(test_samples)

    metadata = {
        "model_name":
            "Tuned Logistic Regression",

        "target":
            TARGET,

        "threshold":
            FINAL_THRESHOLD,

        "hyperparameters":
            BEST_LOGISTIC_PARAMS,

        "features":
            MODEL_FEATURES,

        "reference_data":
            reference_data,

        "training_rows":
            int(len(training_data)),

        "training_start":
            training_data[
                "order_date"
            ]
            .min()
            .date()
            .isoformat(),

        "training_end":
            training_data[
                "order_date"
            ]
            .max()
            .date()
            .isoformat(),

        "training_late_rate":
            float(
                training_data[
                    TARGET
                ].mean()
            ),

        "test_sample_count":
            len(test_samples),

        "evaluation": {
            "test_period":
                "2018-01-01 to 2018-03-31",

            "roc_auc":
                0.800,

            "pr_auc":
                0.559,

            "precision":
                0.448,

            "recall":
                1.000,

            "f1":
                0.619,

            "f2":
                0.802,
        },
    }

    with open(
        METADATA_PATH,
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(
            metadata,
            file,
            indent=4,
        )

def main():
    """
    Train and save the late shipment risk model.
    """

    print(
        "Loading training data..."
    )

    data = load_training_data()

    data = prepare_training_data(
        data
    )

    validate_training_data(
        data
    )

    print(
        f"Training rows : {len(data):,}"
    )

    print(
        "Training period:",
        data["order_date"]
        .min()
        .date(),
        "to",
        data["order_date"]
        .max()
        .date(),
    )

    print(
        f"Late rate     : "
        f"{data[TARGET].mean() * 100:.2f}%"
    )

    print(
        "\nTraining model..."
    )

    model = train_model(
        data
    )

    save_model_bundle(
        model=model,
        training_data=data,
    )

    print(
        "\nTraining completed."
    )

    print(
        f"Model saved to:\n{MODEL_PATH}"
    )

    print(
        f"\nMetadata saved to:\n{METADATA_PATH}"
    )


if __name__ == "__main__":
    main()
