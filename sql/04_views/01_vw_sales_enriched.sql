USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- View: vw_sales_enriched
--
-- Grain:
-- 1 row = 1 item within an order
-- ============================================================


-- Examination of the tables:

SELECT * FROM order_items LIMIT 10;

SELECT * FROM orders LIMIT 10;

SELECT * FROM products LIMIT 10;

SELECT * FROM brands LIMIT 10;

SELECT * FROM categories LIMIT 10;

SELECT * FROM customers LIMIT 10;

SELECT * FROM stores LIMIT 10;

SELECT * FROM staffs LIMIT 10;

CREATE OR REPLACE VIEW vw_sales_enriched AS

SELECT
	-- --------------------------------------------------------
    -- Order identifiers
    -- --------------------------------------------------------
    o.order_id,
    oi.item_id,
    -- --------------------------------------------------------
    -- Order information
    -- --------------------------------------------------------
    o.order_status,
    
    CASE
		WHEN o.order_status = 1 THEN 'Pending'
        WHEN o.order_status = 2 THEN 'Processing'
        WHEN o.order_status = 3 THEN 'Rejected'
        WHEN o.order_status = 4 THEN 'Completed'
        ELSE 'Unknown'
	END AS order_status_name,
    
    CASE
		WHEN o.order_status = 4 THEN 1
        ELSE 0
	END AS is_completed,
    
    o.order_date,
    o.required_date,
    o.shipped_date,

    -- --------------------------------------------------------
    -- Time dimensions
    -- --------------------------------------------------------
    YEAR(o.order_date) AS order_year,
    QUARTER(o.order_date) AS order_quarter,
    MONTH(o.order_date) AS order_month,
    MONTHNAME(o.order_date) AS order_month_name,
    
    DATE_FORMAT(
		o.order_date,
        '%Y-%m'
	) AS order_year_month,
    
    -- --------------------------------------------------------
    -- Shipping metrics
    -- --------------------------------------------------------
    DATEDIFF(
		o.required_date,
        o.order_date
	) AS required_lead_days,
    
	CASE
		WHEN o.shipped_date IS NOT NULL
		THEN DATEDIFF(
			o.shipped_date,
			o.order_date
		)
		ELSE NULL
	END AS shipping_days,

	CASE
        WHEN o.shipped_date IS NULL THEN NULL
        WHEN o.shipped_date > o.required_date THEN 1
        ELSE 0
    END AS is_late,
    
    CASE
        WHEN o.shipped_date IS NULL THEN NULL
        WHEN o.shipped_date > o.required_date
        THEN DATEDIFF(
            o.shipped_date,
            o.required_date
        )
        ELSE 0
    END AS delay_days,
    
    -- --------------------------------------------------------
    -- Customer
    -- --------------------------------------------------------
    c.customer_id,
    CONCAT(
		c.first_name,
        ' ',
        c.last_name
	) AS customer_name,
    
    c.city AS customer_city,
    c.state AS customer_state,
    c.zip_code AS customer_zip_code,
    
    -- --------------------------------------------------------
    -- Store
    -- --------------------------------------------------------
    s.store_id,
    s.store_name,

    s.city AS store_city,
    s.state AS store_state,
    
    -- --------------------------------------------------------
    -- Staff
    -- --------------------------------------------------------
    st.staff_id,

    CONCAT(
        st.first_name,
        ' ',
        st.last_name
    ) AS staff_name,
    
    -- --------------------------------------------------------
    -- Product
    -- --------------------------------------------------------
    p.product_id,
    p.product_name,
    p.model_year,

    b.brand_id,
    b.brand_name,

    cat.category_id,
    cat.category_name,
    
    -- --------------------------------------------------------
    -- Transaction values
    -- --------------------------------------------------------
    oi.quantity,

    oi.list_price AS item_list_price,

    oi.discount,
	
    -- Gross value before discount
    ROUND(
        oi.quantity * oi.list_price,
        2
    ) AS gross_sales,

    -- Monetary discount
    ROUND(
        oi.quantity
        * oi.list_price
        * oi.discount,
        2
    ) AS discount_amount,

    -- Net transactional sales
    ROUND(
        oi.quantity
        * oi.list_price
        * (1 - oi.discount),
        2
    ) AS net_sales,
    
    -- Completed-order sales only
    CASE
        WHEN o.order_status = 4
        THEN ROUND(
            oi.quantity
            * oi.list_price
            * (1 - oi.discount),
            2
        )
        ELSE 0
    END AS realized_net_sales

FROM order_items oi

INNER JOIN orders o
	ON oi.order_id = o.order_id
    
INNER JOIN products p
	ON oi.product_id = p.product_id
    
INNER JOIN brands b
    ON p.brand_id = b.brand_id

INNER JOIN categories cat
    ON p.category_id = cat.category_id

INNER JOIN customers c
    ON o.customer_id = c.customer_id

INNER JOIN stores s
    ON o.store_id = s.store_id

INNER JOIN staffs st
    ON o.staff_id = st.staff_id;
    
SELECT * FROM vw_sales_enriched LIMIT 10;

-- ============================================================
-- VIEW VALIDATION
-- ============================================================


-- ------------------------------------------------------------
-- 1. Row count must match order_items
-- ------------------------------------------------------------

SELECT
    (SELECT COUNT(*) FROM order_items) AS order_items_rows,
    (SELECT COUNT(*) FROM vw_sales_enriched) AS view_rows;
    
SELECT
	order_status_name,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(*) AS order_items,
    ROUND(SUM(net_sales), 2) AS potential_net_sales,
    ROUND(SUM(realized_net_sales), 2) AS realized_net_sales
FROM vw_sales_enriched
GROUP BY
	order_status,
    order_status_name
ORDER BY order_status;