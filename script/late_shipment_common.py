# script/late_shipment_common.py

from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler


CATEGORICAL_FEATURES = [
    "store_id",
    "staff_id",
    "order_month_number",
    "order_dayofweek",
]

NUMERICAL_FEATURES = [
    "required_lead_days",
    "distinct_products",
    "total_units",
    "net_order_value",
    "effective_discount_pct",
]

MODEL_FEATURES = (
    CATEGORICAL_FEATURES
    + NUMERICAL_FEATURES
)

TARGET = "is_late"

FINAL_THRESHOLD = 0.20


BEST_LOGISTIC_PARAMS = {
    "C": 0.01,
    "l1_ratio": 0.0,
    "class_weight": None,
}

def build_preprocessor():
    """
    Build preprocessing steps for the
    late shipment classification model.
    """

    categorical_transformer = Pipeline(
        steps=[
            (
                "imputer",
                SimpleImputer(
                    strategy="most_frequent"
                ),
            ),
            (
                "onehot",
                OneHotEncoder(
                    handle_unknown="ignore"
                ),
            ),
        ]
    )

    numerical_transformer = Pipeline(
        steps=[
            (
                "imputer",
                SimpleImputer(
                    strategy="median"
                ),
            ),
            (
                "scaler",
                StandardScaler(),
            ),
        ]
    )

    return ColumnTransformer(
        transformers=[
            (
                "categorical",
                categorical_transformer,
                CATEGORICAL_FEATURES,
            ),
            (
                "numerical",
                numerical_transformer,
                NUMERICAL_FEATURES,
            ),
        ]
    )

def build_late_shipment_model():
    """
    Build the final tuned Logistic Regression model.
    """

    preprocessor = build_preprocessor()

    classifier = LogisticRegression(
        C=BEST_LOGISTIC_PARAMS["C"],
        l1_ratio=BEST_LOGISTIC_PARAMS["l1_ratio"],
        class_weight=BEST_LOGISTIC_PARAMS[
            "class_weight"
        ],
        solver="liblinear",
        max_iter=2000,
        random_state=42,
    )

    return Pipeline(
        steps=[
            (
                "preprocessor",
                preprocessor,
            ),
            (
                "model",
                classifier,
            ),
        ]
    )