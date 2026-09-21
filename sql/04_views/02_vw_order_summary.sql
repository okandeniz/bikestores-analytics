USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- View: vw_order_summary
--
-- Grain:
-- 1 row = 1 order
-- ============================================================

CREATE OR REPLACE VIEW vw_order_summary AS

SELECT
    -- --------------------------------------------------------
    -- Order
    -- --------------------------------------------------------
    order_id,
    order_status,
    order_status_name,
    is_completed,

    order_date,
    required_date,
    shipped_date,

    -- --------------------------------------------------------
    -- Time dimensions
    -- --------------------------------------------------------
    order_year,
    order_quarter,
    order_month,
    order_month_name,
    order_year_month,

    -- --------------------------------------------------------
    -- Shipping
    -- --------------------------------------------------------
    required_lead_days,
    shipping_days,
    is_late,
    delay_days,

    -- --------------------------------------------------------
    -- Customer
    -- --------------------------------------------------------
    customer_id,
    customer_name,
    customer_city,
    customer_state,
    customer_zip_code,

    -- --------------------------------------------------------
    -- Store
    -- --------------------------------------------------------
    store_id,
    store_name,
    store_city,
    store_state,

    -- --------------------------------------------------------
    -- Staff
    -- --------------------------------------------------------
    staff_id,
    staff_name,

    -- --------------------------------------------------------
    -- Order metrics
    -- --------------------------------------------------------
    COUNT(*) AS line_item_count,

    COUNT(DISTINCT product_id) AS distinct_products,

    SUM(quantity) AS total_units,

    ROUND(
        SUM(gross_sales),
        2
    ) AS gross_order_value,

    ROUND(
        SUM(discount_amount),
        2
    ) AS discount_amount,

    ROUND(
        SUM(net_sales),
        2
    ) AS net_order_value,

    ROUND(
        SUM(realized_net_sales),
        2
    ) AS realized_order_value,

    -- Gross-sales-weighted discount rate
    ROUND(
        SUM(discount_amount)
        / NULLIF(SUM(gross_sales), 0),
        4
    ) AS effective_discount_rate

FROM vw_sales_enriched

GROUP BY
    order_id,
    order_status,
    order_status_name,
    is_completed,

    order_date,
    required_date,
    shipped_date,

    order_year,
    order_quarter,
    order_month,
    order_month_name,
    order_year_month,

    required_lead_days,
    shipping_days,
    is_late,
    delay_days,

    customer_id,
    customer_name,
    customer_city,
    customer_state,
    customer_zip_code,

    store_id,
    store_name,
    store_city,
    store_state,

    staff_id,
    staff_name;
    
SELECT * FROM vw_order_summary LIMIT 10;
    
-- ============================================================
-- VIEW VALIDATION
-- ============================================================


-- ------------------------------------------------------------
-- 1. One row per order
-- ------------------------------------------------------------

SELECT
    (SELECT COUNT(*) FROM orders) AS source_orders,
    (SELECT COUNT(*) FROM vw_order_summary) AS view_orders;
    
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM vw_order_summary;

SELECT
    ROUND(
        SUM(realized_net_sales),
        2
    ) AS item_level_realized_sales
FROM vw_sales_enriched;


SELECT
    ROUND(
        SUM(realized_order_value),
        2
    ) AS order_level_realized_sales
FROM vw_order_summary;

SELECT
    order_status_name,
    COUNT(*) AS total_orders,
    SUM(total_units) AS total_units,
    ROUND(
        SUM(net_order_value),
        2
    ) AS net_order_value,
    ROUND(
        SUM(realized_order_value),
        2
    ) AS realized_order_value
FROM vw_order_summary
GROUP BY
    order_status,
    order_status_name
ORDER BY order_status;