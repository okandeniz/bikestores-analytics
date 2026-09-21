USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Data Quality - 03 NULL Checks
-- ============================================================


-- ------------------------------------------------------------
-- 1. Identify nullable columns
-- ------------------------------------------------------------

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'bikestores'
  AND IS_NULLABLE = 'YES'
ORDER BY
    TABLE_NAME,
    ORDINAL_POSITION;
    
-- ------------------------------------------------------------
-- 2. NULL counts - customers
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    SUM(phone IS NULL) AS null_phone,
    SUM(street IS NULL) AS null_street,
    SUM(city IS NULL) AS null_city,
    SUM(state IS NULL) AS null_state,
    SUM(zip_code IS NULL) AS null_zip_code
FROM customers;


-- ------------------------------------------------------------
-- 3. NULL counts - orders
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    SUM(customer_id IS NULL) AS null_customer_id,
    SUM(shipped_date IS NULL) AS null_shipped_date
FROM orders;


-- ------------------------------------------------------------
-- 4. NULL counts - staffs
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    SUM(phone IS NULL) AS null_phone,
    SUM(manager_id IS NULL) AS null_manager_id
FROM staffs;


-- ------------------------------------------------------------
-- 5. NULL counts - stocks
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    SUM(quantity IS NULL) AS null_quantity
FROM stocks;


-- ------------------------------------------------------------
-- 6. NULL counts - stores
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    SUM(phone IS NULL) AS null_phone,
    SUM(email IS NULL) AS null_email,
    SUM(street IS NULL) AS null_street,
    SUM(city IS NULL) AS null_city,
    SUM(state IS NULL) AS null_state,
    SUM(zip_code IS NULL) AS null_zip_code
FROM stores;

-- ------------------------------------------------------------
-- 8. Investigate NULL shipped dates
-- ------------------------------------------------------------

SELECT
	order_status,
    COUNT(*) AS total_orders,
    SUM(shipped_date IS NULL) AS null_shipped_date,
    SUM(shipped_date IS NOT NULL) AS shipped_orders
FROM orders
GROUP BY order_status
ORDER BY order_status;

SELECT
    order_status,
    COUNT(*) AS orders_with_null_shipped_date
FROM orders
WHERE shipped_date IS NULL
GROUP BY order_status
ORDER BY order_status;

SELECT
    staff_id,
    first_name,
    last_name,
    manager_id
FROM staffs
WHERE manager_id IS NULL;