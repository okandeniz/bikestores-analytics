USE bikestores;
-- ============================================================
-- BikeStores Analytics
-- Data Quality - 01 Schema Overview
-- ============================================================


-- ------------------------------------------------------------
-- 1. Show all tables
-- ------------------------------------------------------------
SHOW TABLES;

-- ------------------------------------------------------------
-- 2. Row counts
-- ------------------------------------------------------------

SELECT 'brands' AS table_name, COUNT(*) AS row_count
FROM brands

UNION ALL

SELECT 'categories', COUNT(*)
FROM categories

UNION ALL

SELECT 'customers', COUNT(*)
FROM customers

UNION ALL

SELECT 'order_items', COUNT(*)
FROM order_items

UNION ALL

SELECT 'orders', COUNT(*)
FROM orders

UNION ALL

SELECT 'products', COUNT(*)
FROM products

UNION ALL

SELECT 'staffs', COUNT(*)
FROM staffs

UNION ALL

SELECT 'stocks', COUNT(*)
FROM stocks

UNION ALL

SELECT 'stores', COUNT(*)
FROM stores;

-- ------------------------------------------------------------
-- 3. Dataset date range
-- ------------------------------------------------------------

SELECT * FROM orders LIMIT 10;

SELECT
	MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    DATEDIFF(
		MAX(order_date),
        MIN(order_date)
	) AS dataset_period_days
FROM orders;

-- ------------------------------------------------------------
-- 4. Orders by year
-- ------------------------------------------------------------
SELECT
	YEAR(order_date) AS order_year,
    COUNT(*) AS total_orders
FROM orders
GROUP BY YEAR(order_date)
ORDER BY order_year;

-- ------------------------------------------------------------
-- 5. Orders by month
-- ------------------------------------------------------------

SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    COUNT(*) AS total_orders
FROM orders
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY month;

DESCRIBE orders;

DESCRIBE order_items;
