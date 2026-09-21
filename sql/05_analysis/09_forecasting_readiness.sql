USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Business Analysis - 09 Forecasting Readiness
--
-- Reliable period:
-- 2016-01-01 to 2018-04-30
-- ============================================================


-- ------------------------------------------------------------
-- 1. Store x Category monthly density
-- ------------------------------------------------------------

WITH monthly_activity AS (

    SELECT
        store_id,
        store_name,
        category_id,
        category_name,

        COUNT(
            DISTINCT DATE_FORMAT(order_date, '%Y-%m')
        ) AS active_months,

        SUM(quantity) AS total_units,

        COUNT(
            DISTINCT order_id
        ) AS total_orders

    FROM vw_sales_enriched

    WHERE is_completed = 1
      AND order_date >= '2016-01-01'
      AND order_date < '2018-05-01'

    GROUP BY
        store_id,
        store_name,
        category_id,
        category_name
)

SELECT
    store_name,
    category_name,

    active_months,

    28 AS possible_months,

    ROUND(
        active_months * 100.0 / 28,
        2
    ) AS monthly_activity_pct,

    total_units,
    total_orders,

    ROUND(
        total_units / 28.0,
        2
    ) AS avg_units_per_calendar_month

FROM monthly_activity

ORDER BY
    monthly_activity_pct,
    store_name,
    category_name;
    
-- General monthly density summary

WITH monthly_activity AS (

    SELECT
        store_id,
        category_id,

        COUNT(
            DISTINCT DATE_FORMAT(order_date, '%Y-%m')
        ) AS active_months

    FROM vw_sales_enriched

    WHERE is_completed = 1
      AND order_date >= '2016-01-01'
      AND order_date < '2018-05-01'

    GROUP BY
        store_id,
        category_id
)

SELECT
    COUNT(*) AS store_category_series,

    ROUND(
        AVG(active_months),
        2
    ) AS avg_active_months,

    MIN(active_months) AS min_active_months,

    MAX(active_months) AS max_active_months,

    ROUND(
        AVG(active_months / 28.0) * 100,
        2
    ) AS avg_monthly_density_pct

FROM monthly_activity;

-- Weekly density

WITH weekly_activity AS (

    SELECT
        store_id,
        store_name,
        category_id,
        category_name,

        COUNT(
            DISTINCT YEARWEEK(order_date, 3)
        ) AS active_weeks,

        SUM(quantity) AS total_units,

        COUNT(
            DISTINCT order_id
        ) AS total_orders

    FROM vw_sales_enriched

    WHERE is_completed = 1
      AND order_date >= '2016-01-01'
      AND order_date < '2018-05-01'

    GROUP BY
        store_id,
        store_name,
        category_id,
        category_name
),

period AS (

    SELECT
        TIMESTAMPDIFF(
            WEEK,
            '2016-01-01',
            '2018-05-01'
        ) + 1 AS possible_weeks

)

SELECT
    wa.store_name,
    wa.category_name,

    wa.active_weeks,
    p.possible_weeks,

    ROUND(
        wa.active_weeks * 100.0
        / p.possible_weeks,
        2
    ) AS weekly_activity_pct,

    wa.total_units,

    ROUND(
        wa.total_units * 1.0
        / p.possible_weeks,
        2
    ) AS avg_units_per_calendar_week

FROM weekly_activity wa

CROSS JOIN period p

ORDER BY
    weekly_activity_pct,
    wa.store_name,
    wa.category_name;
    
-- Weekly density summary
WITH weekly_activity AS (

    SELECT
        store_id,
        category_id,

        COUNT(
            DISTINCT YEARWEEK(order_date, 3)
        ) AS active_weeks

    FROM vw_sales_enriched

    WHERE is_completed = 1
      AND order_date >= '2016-01-01'
      AND order_date < '2018-05-01'

    GROUP BY
        store_id,
        category_id
),

period AS (

    SELECT
        TIMESTAMPDIFF(
            WEEK,
            '2016-01-01',
            '2018-05-01'
        ) + 1 AS possible_weeks

)

SELECT
    COUNT(*) AS store_category_series,

    ROUND(
        AVG(active_weeks),
        2
    ) AS avg_active_weeks,

    MIN(active_weeks) AS min_active_weeks,

    MAX(active_weeks) AS max_active_weeks,

    ROUND(
        AVG(
            active_weeks * 1.0
            / possible_weeks
        ) * 100,
        2
    ) AS avg_weekly_density_pct

FROM weekly_activity

CROSS JOIN period;
