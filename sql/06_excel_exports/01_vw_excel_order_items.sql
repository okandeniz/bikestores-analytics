USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Excel Export View: vw_excel_order_items
--
-- Grain:
-- 1 row = 1 order item
--
-- Main use:
-- Sales, store, staff, product and discount analysis
-- ============================================================

SELECT * FROM vw_sales_enriched LIMIT 10;

CREATE OR REPLACE VIEW vw_excel_order_items AS

SELECT
	-- Order Keys
	order_id,
    item_id,
    
    -- Date dimensions
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
    
    -- Order status
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
    
    -- Product hierarchy
    category_id,
    category_name,

    brand_id,
    brand_name,

    product_id,
    product_name,
    model_year,
    
    -- Transaction metrics
    quantity,

    item_list_price,

    discount,

    ROUND(
        discount * 100,
        0
    ) AS discount_pct,

    gross_sales,
    discount_amount,
    net_sales,
    
    -- Realized sales metrics
    -- Completed orders only
    
    CASE
		WHEN is_completed = 1
			THEN quantity
		ELSE 0
	END AS realized_units_sold,
    
    CASE
        WHEN is_completed = 1
            THEN gross_sales
        ELSE 0
    END AS realized_gross_sales,
    
    CASE
        WHEN is_completed = 1
            THEN discount_amount
        ELSE 0
    END AS realized_discount_amount,
    
    realized_net_sales,
    
    -- Operations
    required_date,
    shipped_date,
    required_lead_days,
    shipping_days,
    is_late,
    delay_days
    
FROM vw_sales_enriched;

-- Control

SELECT
    COUNT(*) AS total_rows,
    COUNT(
        DISTINCT CONCAT(
            order_id,
            '-',
            item_id
        )
    ) AS unique_order_items
FROM vw_excel_order_items;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM vw_excel_orders;

SELECT
    COUNT(*) AS total_rows,
    COUNT(
        DISTINCT CONCAT(
            store_id,
            '-',
            product_id
        )
    ) AS unique_store_products,

    SUM(current_stock) AS total_stock_units
FROM vw_excel_inventory;

SELECT
    ROUND(
        SUM(realized_net_sales),
        2
    ) AS net_sales
FROM vw_excel_order_items;

SELECT
    ROUND(
        SUM(realized_order_value),
        2
    ) AS net_sales
FROM vw_excel_orders;