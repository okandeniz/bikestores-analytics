USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Excel Export View: vw_excel_orders
--
-- Grain:
-- 1 row = 1 order
--
-- Main use:
-- Order KPIs and operational analysis
-- ============================================================

SELECT * FROM vw_order_summary LIMIT 10;

CREATE OR REPLACE VIEW vw_excel_orders AS

SELECT
	-- Order
    order_id,
    
    order_date,
    order_year AS report_year,
    order_quarter AS report_quarter,
    order_month AS month_number,
    order_month_name AS month_name,
    order_year_month AS year_monthh,
    
    CAST(
        DATE_FORMAT(order_date, '%Y-%m-01')
        AS DATE
    ) AS month_start,

    CASE
        WHEN order_date < '2018-05-01'
            THEN 1
        ELSE 0
    END AS is_reliable_period,

    CASE
        WHEN order_date < '2018-05-01'
            THEN 'Reliable Reporting Period'
        ELSE 'Sparse / Incomplete Period'
    END AS reporting_period_status,
    
    -- Status
    order_status,
    order_status_name,
    is_completed,
    
    -- Region / Store
    store_state AS region,
    
    store_id,
    store_name,
    
    -- Staff
    staff_id,
    staff_name,
    
    -- Customer
    customer_id,
    customer_name,
    customer_state,
    customer_city,
    
    -- Order composition
    line_item_count,
    distinct_products,
    total_units,
    
    -- Order value
    gross_order_value,
    discount_amount,
    net_order_value,
    realized_order_value,
    
    ROUND(
        effective_discount_rate * 100,
        2
    ) AS effective_discount_pct,
    
    -- Completed-order metrics
    
    CASE
        WHEN is_completed = 1
            THEN total_units
        ELSE 0
    END AS realized_units_sold,

    CASE
        WHEN is_completed = 1
            THEN gross_order_value
        ELSE 0
    END AS realized_gross_order_value,

    CASE
        WHEN is_completed = 1
            THEN discount_amount
        ELSE 0
    END AS realized_discount_amount,
    
    -- Operations
    
    required_date,
    shipped_date,

    required_lead_days,
    shipping_days,
    is_late,
    delay_days

FROM vw_order_summary;