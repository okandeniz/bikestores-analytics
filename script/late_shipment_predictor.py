# script/late_shipment_predictor.py

from pathlib import Path
import json
import secrets

import joblib
import numpy as np
import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]

DEFAULT_MODEL_PATH = (
    PROJECT_ROOT
    / "models"
    / "late_shipment_risk.joblib"
)


RAW_REQUIRED_COLUMNS = [
    "order_date",
    "store_id",
    "staff_id",
    "distinct_products",
    "total_units",
    "net_order_value",
    "effective_discount_pct",
]


class LateShipmentPredictor:
    """
    Load the trained late shipment model
    and generate shipment-risk predictions.
    """

    def __init__(
        self,
        model_path=DEFAULT_MODEL_PATH,
    ):
        self.model_path = Path(model_path)

        if not self.model_path.exists():
            raise FileNotFoundError(
                f"Model file not found: "
                f"{self.model_path}"
            )

        bundle = joblib.load(
            self.model_path
        )

        self.model = bundle["model"]

        self.threshold = float(
            bundle["threshold"]
        )

        self.model_features = bundle[
            "model_features"
        ]

        self.model_name = bundle[
            "model_name"
        ]

        self.metadata = bundle.get("metadata", {})
        metadata_path = self.model_path.with_suffix(".json")
        if not self.metadata and metadata_path.exists():
            with open(metadata_path, encoding="utf-8") as file:
                self.metadata = json.load(file)

        self.reference_data = bundle.get(
            "reference_data",
            {
                "stores": [],
                "staff": [],
            },
        )

        self.test_samples = bundle.get("test_samples", [])
        samples_path = self.model_path.with_name("late_shipment_test_samples.json")
        if not self.test_samples and samples_path.exists():
            with open(samples_path, encoding="utf-8") as file:
                self.test_samples = json.load(file).get("samples", [])

    # ---------------------------------------------------------
    # Reference Data
    # ---------------------------------------------------------

    def get_store_options(self):
        """
        Return store names mapped to store IDs.

        Example:
        {
            "Santa Cruz Bikes": 1,
            "Baldwin Bikes": 2,
            "Rowlett Bikes": 3
        }
        """

        return {
            item["store_name"]: int(
                item["store_id"]
            )
            for item in self.reference_data[
                "stores"
            ]
        }

    def get_staff_options(
        self,
        store_id=None,
    ):
        """
        Return staff names mapped to staff IDs.

        Staff can optionally be filtered
        by store ID.
        """

        staff = self.reference_data[
            "staff"
        ]

        if store_id is not None:

            staff = [
                item
                for item in staff
                if int(
                    item["store_id"]
                ) == int(store_id)
            ]

        return {
            item["staff_name"]: int(
                item["staff_id"]
            )
            for item in staff
        }

    def get_store_name(
        self,
        store_id,
    ):
        """
        Return store name for a store ID.
        """

        for item in self.reference_data[
            "stores"
        ]:

            if int(
                item["store_id"]
            ) == int(store_id):

                return item[
                    "store_name"
                ]

        raise ValueError(
            f"Unknown store_id: {store_id}"
        )

    def get_staff_name(
        self,
        staff_id,
    ):
        """
        Return staff name for a staff ID.
        """

        for item in self.reference_data[
            "staff"
        ]:

            if int(
                item["staff_id"]
            ) == int(staff_id):

                return item[
                    "staff_name"
                ]

        raise ValueError(
            f"Unknown staff_id: {staff_id}"
        )

    def validate_store_staff_pair(
        self,
        store_id,
        staff_id,
    ):
        """
        Validate that a staff member
        belongs to the selected store.
        """

        if not self.reference_data[
            "staff"
        ]:
            return

        valid_pair = any(
            int(item["store_id"])
            == int(store_id)
            and int(item["staff_id"])
            == int(staff_id)
            for item in self.reference_data[
                "staff"
            ]
        )

        if not valid_pair:
            raise ValueError(
                "The selected staff member "
                "does not belong to the "
                "selected store."
            )

    def get_random_test_sample(self):
        """Return one saved order from the historical test period."""

        if not self.test_samples:
            raise ValueError(
                "No test samples are available. Retrain the model "
                "with python -m script.late_shipment_train."
            )

        return dict(secrets.choice(self.test_samples))

    # ---------------------------------------------------------
    # Feature Preparation
    # ---------------------------------------------------------

    def prepare_features(
        self,
        data,
    ):
        """
        Convert raw order information into
        model-ready features.
        """

        if not isinstance(
            data,
            pd.DataFrame,
        ):
            raise TypeError(
                "Input data must be "
                "a pandas DataFrame."
            )

        if data.empty:
            raise ValueError(
                "Input data is empty."
            )

        df = data.copy()

        # -----------------------------------------------------
        # Required raw columns
        # -----------------------------------------------------

        missing_columns = [
            column
            for column in RAW_REQUIRED_COLUMNS
            if column not in df.columns
        ]

        if missing_columns:
            raise ValueError(
                "Missing required columns: "
                f"{missing_columns}"
            )

        # -----------------------------------------------------
        # Dates
        # -----------------------------------------------------

        df["order_date"] = pd.to_datetime(
            df["order_date"],
            errors="coerce",
        )

        if df["order_date"].isna().any():
            raise ValueError(
                "Invalid order_date "
                "values found."
            )

        # Lead time can be provided directly
        # or calculated from required_date.
        if (
            "required_lead_days"
            not in df.columns
        ):

            if (
                "required_date"
                not in df.columns
            ):
                raise ValueError(
                    "Either "
                    "required_lead_days "
                    "or required_date "
                    "must be provided."
                )

            df[
                "required_date"
            ] = pd.to_datetime(
                df["required_date"],
                errors="coerce",
            )

            if (
                df["required_date"]
                .isna()
                .any()
            ):
                raise ValueError(
                    "Invalid required_date "
                    "values found."
                )

            df[
                "required_lead_days"
            ] = (
                df["required_date"]
                - df["order_date"]
            ).dt.days

        # -----------------------------------------------------
        # Numeric conversion
        # -----------------------------------------------------

        numeric_columns = [
            "store_id",
            "staff_id",
            "required_lead_days",
            "distinct_products",
            "total_units",
            "net_order_value",
            "effective_discount_pct",
        ]

        for column in numeric_columns:

            df[column] = pd.to_numeric(
                df[column],
                errors="coerce",
            )

        if (
            df[numeric_columns]
            .isna()
            .any()
            .any()
        ):

            invalid_columns = (
                df[numeric_columns]
                .columns[
                    df[numeric_columns]
                    .isna()
                    .any()
                ]
                .tolist()
            )

            raise ValueError(
                "Invalid numeric values "
                "found in: "
                f"{invalid_columns}"
            )

        # -----------------------------------------------------
        # Business validation
        # -----------------------------------------------------

        if (
            df["required_lead_days"]
            <= 0
        ).any():
            raise ValueError(
                "required_lead_days "
                "must be positive."
            )

        if (
            df["distinct_products"]
            <= 0
        ).any():
            raise ValueError(
                "distinct_products "
                "must be positive."
            )

        if (
            df["total_units"]
            <= 0
        ).any():
            raise ValueError(
                "total_units "
                "must be positive."
            )

        if (
            df["distinct_products"]
            > df["total_units"]
        ).any():
            raise ValueError(
                "distinct_products "
                "cannot be greater "
                "than total_units."
            )

        if (
            df["net_order_value"]
            < 0
        ).any():
            raise ValueError(
                "net_order_value "
                "cannot be negative."
            )

        if (
            df[
                "effective_discount_pct"
            ] < 0
        ).any():
            raise ValueError(
                "effective_discount_pct "
                "cannot be negative."
            )

        if (
            df[
                "effective_discount_pct"
            ] > 100
        ).any():
            raise ValueError(
                "effective_discount_pct "
                "cannot be greater "
                "than 100."
            )

        # -----------------------------------------------------
        # Store-staff relationship
        # -----------------------------------------------------

        for row in df[
            [
                "store_id",
                "staff_id",
            ]
        ].itertuples(
            index=False
        ):

            self.validate_store_staff_pair(
                store_id=row.store_id,
                staff_id=row.staff_id,
            )

        # -----------------------------------------------------
        # Calendar features
        # -----------------------------------------------------

        df[
            "order_month_number"
        ] = (
            df["order_date"]
            .dt.month
        )

        df[
            "order_dayofweek"
        ] = (
            df["order_date"]
            .dt.dayofweek
        )

        return df[
            self.model_features
        ].copy()

    # ---------------------------------------------------------
    # Prediction
    # ---------------------------------------------------------

    def predict(
        self,
        data,
    ):
        """
        Predict late shipment probability
        and alert status.
        """

        prepared_data = (
            self.prepare_features(
                data
            )
        )

        probabilities = (
            self.model.predict_proba(
                prepared_data
            )[:, 1]
        )

        predictions = (
            probabilities
            >= self.threshold
        ).astype(int)

        results = data.copy()

        results[
            "late_probability"
        ] = probabilities

        results[
            "late_probability_pct"
        ] = (
            probabilities
            * 100
        )

        results[
            "predicted_late"
        ] = predictions

        results[
            "risk_alert"
        ] = np.where(
            predictions == 1,
            "Alert",
            "No Alert",
        )

        results[
            "decision_threshold"
        ] = self.threshold

        return results
