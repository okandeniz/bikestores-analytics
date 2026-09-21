USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Business Analysis - 06 Customer & Geography Analysis
-- ============================================================


-- ------------------------------------------------------------
-- 1. Customer performance by state
-- ------------------------------------------------------------

SELECT
	customer_state,
    
    COUNT(DISTINCT customer_id) AS customers,
    
    COUNT(*) AS completed_orders,
    
    SUM(total_units) AS units_sold,
    
    ROUND(
        SUM(realized_order_value),
        2
    ) AS net_sales,
    
    ROUND(
        SUM(realized_order_value)
        / COUNT(DISTINCT customer_id),
        2
    ) AS revenue_per_customer,
    
    ROUND(
        SUM(realized_order_value)
        / COUNT(*),
        2
    ) AS average_order_value
    
FROM vw_order_summary
WHERE is_completed = 1
GROUP BY customer_state
ORDER BY net_sales DESC;

-- State Revenue Share
WITH state_sales AS (

    SELECT
        customer_state,
        SUM(realized_order_value) AS net_sales

    FROM vw_order_summary

    WHERE is_completed = 1

    GROUP BY customer_state
)

SELECT
    customer_state,

    ROUND(
        net_sales,
        2
    ) AS net_sales,

    ROUND(
        net_sales * 100.0
        / SUM(net_sales) OVER (),
        2
    ) AS revenue_share_pct

FROM state_sales

ORDER BY net_sales DESC;

-- City Performance

SELECT
    customer_state,
    customer_city,

    COUNT(DISTINCT customer_id) AS customers,

    SUM(total_units) AS units_sold,

    ROUND(
        SUM(realized_order_value),
        2
    ) AS net_sales,

    ROUND(
        SUM(realized_order_value)
        / COUNT(DISTINCT customer_id),
        2
    ) AS revenue_per_customer

FROM vw_order_summary

WHERE is_completed = 1

GROUP BY
    customer_state,
    customer_city

HAVING COUNT(DISTINCT customer_id) >= 5

ORDER BY net_sales DESC;

-- Store × Customer Geography

SELECT
    store_name,
    customer_state,

    COUNT(*) AS completed_orders,

    ROUND(
        SUM(realized_order_value),
        2
    ) AS net_sales,

    ROUND(
        SUM(realized_order_value)
        / COUNT(*),
        2
    ) AS average_order_value

FROM vw_order_summary

WHERE is_completed = 1

GROUP BY
    store_id,
    store_name,
    customer_state

ORDER BY
    store_name,
    net_sales DESC;

-- Customer spending distribution
WITH customer_value AS (

    SELECT
        customer_id,
        customer_name,
        customer_state,
        customer_city,
        realized_order_value AS customer_value

    FROM vw_order_summary

    WHERE is_completed = 1
),

quartiles AS (

    SELECT
        *,
        NTILE(4) OVER (
            ORDER BY customer_value
        ) AS spending_quartile

    FROM customer_value
)

SELECT
    spending_quartile,

    COUNT(*) AS customers,

    ROUND(
        MIN(customer_value),
        2
    ) AS min_customer_value,

    ROUND(
        AVG(customer_value),
        2
    ) AS avg_customer_value,

    ROUND(
        MAX(customer_value),
        2
    ) AS max_customer_value

FROM quartiles

GROUP BY spending_quartile

ORDER BY spending_quartile;

-- Top Customer Value Concentration

WITH customer_sales AS (

    SELECT
        customer_id,
        realized_order_value AS net_sales

    FROM vw_order_summary

    WHERE is_completed = 1
),

ranked AS (

    SELECT
        *,

        ROW_NUMBER() OVER (
            ORDER BY net_sales DESC
        ) AS customer_rank,

        COUNT(*) OVER () AS total_customers,

        SUM(net_sales) OVER () AS total_sales

    FROM customer_sales
)

SELECT
    ROUND(
        SUM(
            CASE
                WHEN customer_rank
                     <= CEIL(total_customers * 0.20)
                THEN net_sales
                ELSE 0
            END
        ) * 100.0
        / MAX(total_sales),
        2
    ) AS top_20_customer_revenue_share_pct

FROM ranked;
