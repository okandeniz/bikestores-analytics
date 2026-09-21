USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Machine Learning Output Tables
-- 01 - Demand Forecasting
-- ============================================================


-- ------------------------------------------------------------
-- 1. Production demand forecasts
-- Grain:
-- model_version x forecast_month x store x category
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ml_demand_forecast (
    forecast_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    model_version VARCHAR(100) NOT NULL,

    forecast_month DATE NOT NULL,

    store_id INT NOT NULL,
    category_id INT NOT NULL,

    selected_model VARCHAR(50) NOT NULL,

    predicted_units DECIMAL(14,4) NOT NULL,

    xgboost_prediction DECIMAL(14,4) NULL,
    lightgbm_prediction DECIMAL(14,4) NULL,

    last_month_units DECIMAL(14,4) NULL,
    three_month_average DECIMAL(14,4) NULL,
    last_year_units DECIMAL(14,4) NULL,

    generated_at DATETIME NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_ml_demand_forecast
        UNIQUE (
            model_version,
            forecast_month,
            store_id,
            category_id
        ),

    INDEX idx_demand_forecast_month (
        forecast_month
    ),

    INDEX idx_demand_forecast_store (
        store_id
    ),

    INDEX idx_demand_forecast_category (
        category_id
    )
);


-- ------------------------------------------------------------
-- 2. Model evaluation scores
-- Grain:
-- model_version x evaluation period x model
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ml_demand_model_scores (
    score_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    model_version VARCHAR(100) NOT NULL,

    evaluation_period VARCHAR(20) NOT NULL,
    period_label VARCHAR(100) NULL,

    model_name VARCHAR(50) NOT NULL,

    mae DECIMAL(14,6) NULL,
    rmse DECIMAL(14,6) NULL,
    wape DECIMAL(14,6) NULL,
    bias DECIMAL(14,6) NULL,

    evaluation_rows INT NOT NULL,

    generated_at DATETIME NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_ml_demand_model_scores
        UNIQUE (
            model_version,
            evaluation_period,
            model_name
        ),

    INDEX idx_demand_scores_period (
        evaluation_period
    )
);

SHOW TABLES LIKE 'ml_demand%';

DESCRIBE ml_demand_forecast;

SELECT
    forecast_month,
    selected_model,
    COUNT(*) AS forecast_rows,
    ROUND(SUM(predicted_units), 2) AS forecast_units
FROM ml_demand_forecast
GROUP BY
    forecast_month,
    selected_model;
    
SELECT
    evaluation_period,
    period_label,
    model_name,
    ROUND(mae, 3) AS mae,
    ROUND(rmse, 3) AS rmse,
    ROUND(wape, 2) AS wape,
    ROUND(bias, 3) AS bias,
    evaluation_rows
FROM ml_demand_model_scores
ORDER BY
    evaluation_period,
    mae;