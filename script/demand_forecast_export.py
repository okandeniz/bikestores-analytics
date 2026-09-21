from datetime import datetime, timezone

import pandas as pd
from sqlalchemy import text

from script.predictor import ForecastPredictor
from src.database import create_db_engine


FORECAST_TABLE = "ml_demand_forecast"
SCORES_TABLE = "ml_demand_model_scores"


def build_forecast_dataframe(predictor):
    """
    Generate the production one-month-ahead forecast
    for all store-category series.
    """

    result = predictor.forecast()

    rows = pd.DataFrame(result["rows"])

    if rows.empty:
        raise ValueError("Forecast output is empty.")

    forecast_df = pd.DataFrame({
        "model_version": result["model_version"],
        "forecast_month": pd.to_datetime(
            result["forecast_month"]
        ).date(),

        "store_id": rows["store_id"].astype(int),
        "category_id": rows["category_id"].astype(int),

        "selected_model": result["model"],

        "predicted_units": rows["prediction"].astype(float),

        "xgboost_prediction": rows["XGBoost"].astype(float),
        "lightgbm_prediction": rows["LightGBM"].astype(float),

        "last_month_units": rows["Last month"].astype(float),
        "three_month_average": rows["3-month average"].astype(float),
        "last_year_units": rows["Last year"].astype(float),
    })

    forecast_df["generated_at"] = (
        datetime.now(timezone.utc)
        .replace(tzinfo=None)
    )

    return forecast_df


def build_score_dataframe(predictor):
    """
    Export validation and test performance
    for every forecasting method.
    """

    frames = []

    for period in ["validation", "test"]:

        result = predictor.performance(
            period=period
        )

        scores = pd.DataFrame(
            result["scores"]
        )

        if scores.empty:
            continue

        scores = scores.rename(
            columns={
                "model": "model_name",
                "rows": "evaluation_rows",
            }
        )

        scores["model_version"] = (
            predictor.metadata["model_version"]
        )

        scores["evaluation_period"] = period

        scores["period_label"] = (
            result["period_label"]
        )

        scores["generated_at"] = (
            datetime.now(timezone.utc)
            .replace(tzinfo=None)
        )

        frames.append(
            scores[
                [
                    "model_version",
                    "evaluation_period",
                    "period_label",
                    "model_name",
                    "mae",
                    "rmse",
                    "wape",
                    "bias",
                    "evaluation_rows",
                    "generated_at",
                ]
            ]
        )

    if not frames:
        raise ValueError(
            "No model evaluation scores found."
        )

    return pd.concat(
        frames,
        ignore_index=True
    )


def upsert_forecasts(
    engine,
    forecast_df,
):
    """
    Insert forecasts and safely update the same
    model-version / month / store / category
    combination if the script is rerun.
    """

    query = text(
        f"""
        INSERT INTO {FORECAST_TABLE} (
            model_version,
            forecast_month,
            store_id,
            category_id,
            selected_model,
            predicted_units,
            xgboost_prediction,
            lightgbm_prediction,
            last_month_units,
            three_month_average,
            last_year_units,
            generated_at
        )
        VALUES (
            :model_version,
            :forecast_month,
            :store_id,
            :category_id,
            :selected_model,
            :predicted_units,
            :xgboost_prediction,
            :lightgbm_prediction,
            :last_month_units,
            :three_month_average,
            :last_year_units,
            :generated_at
        )
        ON DUPLICATE KEY UPDATE
            selected_model =
                VALUES(selected_model),

            predicted_units =
                VALUES(predicted_units),

            xgboost_prediction =
                VALUES(xgboost_prediction),

            lightgbm_prediction =
                VALUES(lightgbm_prediction),

            last_month_units =
                VALUES(last_month_units),

            three_month_average =
                VALUES(three_month_average),

            last_year_units =
                VALUES(last_year_units),

            generated_at =
                VALUES(generated_at);
        """
    )

    records = forecast_df.to_dict(
        orient="records"
    )

    with engine.begin() as connection:
        connection.execute(
            query,
            records
        )


def upsert_scores(
    engine,
    scores_df,
):
    """
    Insert validation/test model scores.
    """

    query = text(
        f"""
        INSERT INTO {SCORES_TABLE} (
            model_version,
            evaluation_period,
            period_label,
            model_name,
            mae,
            rmse,
            wape,
            bias,
            evaluation_rows,
            generated_at
        )
        VALUES (
            :model_version,
            :evaluation_period,
            :period_label,
            :model_name,
            :mae,
            :rmse,
            :wape,
            :bias,
            :evaluation_rows,
            :generated_at
        )
        ON DUPLICATE KEY UPDATE
            period_label =
                VALUES(period_label),

            mae =
                VALUES(mae),

            rmse =
                VALUES(rmse),

            wape =
                VALUES(wape),

            bias =
                VALUES(bias),

            evaluation_rows =
                VALUES(evaluation_rows),

            generated_at =
                VALUES(generated_at);
        """
    )

    records = scores_df.to_dict(
        orient="records"
    )

    with engine.begin() as connection:
        connection.execute(
            query,
            records
        )


def validate_forecast_export(
    forecast_df,
):
    """
    Basic integrity checks before writing
    predictions to MySQL.
    """

    key_columns = [
        "model_version",
        "forecast_month",
        "store_id",
        "category_id",
    ]

    if forecast_df[key_columns].duplicated().any():
        raise ValueError(
            "Duplicate forecast keys found."
        )

    numeric_columns = [
        "predicted_units",
        "xgboost_prediction",
        "lightgbm_prediction",
        "last_month_units",
        "three_month_average",
        "last_year_units",
    ]

    if forecast_df[numeric_columns].isna().any().any():
        raise ValueError(
            "Missing forecast values found."
        )

    if (
        forecast_df[numeric_columns] < 0
    ).any().any():
        raise ValueError(
            "Negative forecast values found."
        )


def main():
    print(
        "Loading saved demand forecasting model..."
    )

    predictor = ForecastPredictor()

    print(
        "Generating production forecast..."
    )

    forecast_df = build_forecast_dataframe(
        predictor
    )

    validate_forecast_export(
        forecast_df
    )

    print(
        "Preparing model evaluation scores..."
    )

    scores_df = build_score_dataframe(
        predictor
    )

    print(
        "\nForecast preview:"
    )

    print(
        forecast_df.head().to_string(
            index=False
        )
    )

    print(
        "\nForecast rows:",
        len(forecast_df)
    )

    print(
        "Forecast month:",
        forecast_df[
            "forecast_month"
        ].iloc[0]
    )

    print(
        "Selected model:",
        forecast_df[
            "selected_model"
        ].iloc[0]
    )

    print(
        "\nConnecting to MySQL..."
    )

    engine = create_db_engine()

    try:
        upsert_forecasts(
            engine,
            forecast_df
        )

        upsert_scores(
            engine,
            scores_df
        )

    finally:
        engine.dispose()

    print(
        "\nDemand forecasting export completed."
    )

    print(
        f"Forecast rows exported: "
        f"{len(forecast_df)}"
    )

    print(
        f"Score rows exported: "
        f"{len(scores_df)}"
    )


if __name__ == "__main__":
    main()