USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Data Quality - 06 Categorical & String Checks
-- ============================================================


-- ------------------------------------------------------------
-- 1. Order status domain
-- ------------------------------------------------------------

SELECT
    order_status,
    COUNT(*) AS order_count
FROM orders
GROUP BY order_status
ORDER BY order_status;


-- ------------------------------------------------------------
-- 2. Customer states
-- ------------------------------------------------------------

SELECT
    state,
    COUNT(*) AS customer_count
FROM customers
GROUP BY state
ORDER BY state;


-- ------------------------------------------------------------
-- 3. Customer cities
-- ------------------------------------------------------------

SELECT
    city,
    COUNT(*) AS customer_count
FROM customers
GROUP BY city
ORDER BY city;


-- ------------------------------------------------------------
-- 4. Store states and cities
-- ------------------------------------------------------------

SELECT
    state,
    city,
    COUNT(*) AS store_count
FROM stores
GROUP BY
    state,
    city
ORDER BY
    state,
    city;


-- ------------------------------------------------------------
-- 5. Brands
-- ------------------------------------------------------------

SELECT
    brand_id,
    brand_name
FROM brands
ORDER BY brand_name;


-- ------------------------------------------------------------
-- 6. Categories
-- ------------------------------------------------------------

SELECT
    category_id,
    category_name
FROM categories
ORDER BY category_name;

-- ------------------------------------------------------------
-- 7. Customer string whitespace
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS rows_with_whitespace
FROM customers
WHERE first_name <> TRIM(first_name)
   OR last_name <> TRIM(last_name)
   OR email <> TRIM(email)
   OR city <> TRIM(city)
   OR state <> TRIM(state)
   OR zip_code <> TRIM(zip_code);
   
-- ------------------------------------------------------------
-- 8. Product dimension whitespace
-- ------------------------------------------------------------

SELECT
    (
        SELECT COUNT(*)
        FROM brands
        WHERE brand_name <> TRIM(brand_name)
    ) AS brand_whitespace_count,

    (
        SELECT COUNT(*)
        FROM categories
        WHERE category_name <> TRIM(category_name)
    ) AS category_whitespace_count,

    (
        SELECT COUNT(*)
        FROM products
        WHERE product_name <> TRIM(product_name)
    ) AS product_whitespace_count;
    
-- ------------------------------------------------------------
-- 9. Empty string checks
-- ------------------------------------------------------------

SELECT
    SUM(TRIM(first_name) = '') AS empty_first_name,
    SUM(TRIM(last_name) = '') AS empty_last_name,
    SUM(TRIM(email) = '') AS empty_email,
    SUM(TRIM(city) = '') AS empty_city,
    SUM(TRIM(state) = '') AS empty_state
FROM customers;