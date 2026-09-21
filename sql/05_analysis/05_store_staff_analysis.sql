USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Business Analysis - 05 Store & Staff Performance
-- ============================================================


-- ------------------------------------------------------------
-- 1. Store Performance
-- ------------------------------------------------------------

SELECT * FROM vw_order_summary LIMIT 10;

SELECT * FROM vw_sales_enriched LIMIT 10;

SELECT
	store_id,
    store_name,
    
    COUNT(*) AS completed_orders,
    
    COUNT(
        DISTINCT customer_id
    ) AS customers,
    
    SUM(total_units) AS units_sold,
    
    ROUND(
        SUM(realized_order_value),
        2
    ) AS net_sales,
    
    ROUND(
        SUM(realized_order_value)
        / COUNT(*),
        2
    ) AS average_order_value,
    
    ROUND(
        SUM(realized_order_value)
        / COUNT(DISTINCT customer_id),
        2
    ) AS revenue_per_customer
    
FROM vw_order_summary
WHERE is_completed = 1

GROUP BY
	store_id,
    store_name
ORDER BY net_sales DESC;

-- Store Revenue Share

WITH store_sales AS (

    SELECT
        store_id,
        store_name,
        SUM(realized_order_value) AS net_sales

    FROM vw_order_summary

    WHERE is_completed = 1

    GROUP BY
        store_id,
        store_name
)

SELECT
    store_name,

    ROUND(
        net_sales,
        2
    ) AS net_sales,

    ROUND(
        net_sales * 100.0
        / SUM(net_sales) OVER (),
        2
    ) AS revenue_share_pct

FROM store_sales

ORDER BY net_sales DESC;

-- Store Shipping Performance

SELECT
	store_id,
    store_name,
    
    COUNT(*) AS shipped_orders,
    
    SUM(is_late) AS late_orders,
    
    ROUND(
        SUM(is_late) * 100.0
        / COUNT(*),
        2
    ) AS late_shipment_rate_pct,
    
    ROUND(
        AVG(shipping_days),
        2
    ) AS avg_shipping_days,
    
    ROUND(
        AVG(
            CASE
                WHEN is_late = 1
                THEN delay_days
            END
        ),
        2
    ) AS avg_late_days
    
FROM vw_order_summary

WHERE shipped_date IS NOT NULL

GROUP BY
	store_id,
    store_name
ORDER BY late_shipment_rate_pct DESC;

-- Staff Performance

SELECT
    staff_id,
    staff_name,
    store_name,

    COUNT(*) AS completed_orders,

    COUNT(
        DISTINCT customer_id
    ) AS customers,

    SUM(total_units) AS units_sold,

    ROUND(
        SUM(realized_order_value),
        2
    ) AS net_sales,

    ROUND(
        SUM(realized_order_value)
        / COUNT(*),
        2
    ) AS average_order_value,

    ROUND(
        SUM(realized_order_value)
        / COUNT(DISTINCT customer_id),
        2
    ) AS revenue_per_customer

FROM vw_order_summary

WHERE is_completed = 1

GROUP BY
    staff_id,
    staff_name,
    store_id,
    store_name

ORDER BY net_sales DESC;

-- Staff Shipping Performance

SELECT
    staff_id,
    staff_name,
    store_name,

    COUNT(*) AS shipped_orders,

    SUM(is_late) AS late_orders,

    ROUND(
        SUM(is_late) * 100.0
        / COUNT(*),
        2
    ) AS late_shipment_rate_pct,

    ROUND(
        AVG(shipping_days),
        2
    ) AS avg_shipping_days

FROM vw_order_summary

WHERE shipped_date IS NOT NULL

GROUP BY
    staff_id,
    staff_name,
    store_id,
    store_name

ORDER BY late_shipment_rate_pct DESC;



