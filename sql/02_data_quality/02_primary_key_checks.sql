USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Data Quality - 02 Primary Key & Grain Checks
-- ============================================================


-- ------------------------------------------------------------
-- 1. brands
-- Expected grain:
-- 1 row = 1 brand
-- Primary key: brand_id
-- ------------------------------------------------------------

SELECT
	COUNT(*) AS total_rows,
    COUNT(DISTINCT brand_id) AS unique_brand_ids
FROM brands;

SELECT
	brand_id,
    COUNT(*) AS row_count
FROM brands
GROUP BY brand_id
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 2. categories
-- Expected grain:
-- 1 row = 1 category
-- Primary key: category_id
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT category_id) AS unique_category_ids
FROM categories;

SELECT
    category_id,
    COUNT(*) AS row_count
FROM categories
GROUP BY category_id
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 3. customers
-- Expected grain:
-- 1 row = 1 customer
-- Primary key: customer_id
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customer_ids
FROM customers;

SELECT
    customer_id,
    COUNT(*) AS row_count
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 4. orders
-- Expected grain:
-- 1 row = 1 order
-- Primary key: order_id
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_order_ids
FROM orders;

SELECT
    order_id,
    COUNT(*) AS row_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 5. order_items
-- Expected grain:
-- 1 row = 1 item within an order
-- Composite primary key: (order_id, item_id)
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(
        DISTINCT CONCAT(order_id, '-', item_id)
    ) AS unique_order_item_keys
FROM order_items;

SELECT
    order_id,
    item_id,
    COUNT(*) AS row_count
FROM order_items
GROUP BY
    order_id,
    item_id
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 6. products
-- Expected grain:
-- 1 row = 1 product
-- Primary key: product_id
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS unique_product_ids
FROM products;

SELECT
    product_id,
    COUNT(*) AS row_count
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 7. staffs
-- Expected grain:
-- 1 row = 1 staff member
-- Primary key: staff_id
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT staff_id) AS unique_staff_ids
FROM staffs;

SELECT
    staff_id,
    COUNT(*) AS row_count
FROM staffs
GROUP BY staff_id
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 8. stores
-- Expected grain:
-- 1 row = 1 store
-- Primary key: store_id
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT store_id) AS unique_store_ids
FROM stores;

SELECT
    store_id,
    COUNT(*) AS row_count
FROM stores
GROUP BY store_id
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 9. stocks
-- Expected grain:
-- 1 row = 1 product at 1 store
-- Composite primary key: (store_id, product_id)
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(
        DISTINCT CONCAT(store_id, '-', product_id)
    ) AS unique_stock_keys
FROM stocks;

SELECT
    store_id,
    product_id,
    COUNT(*) AS row_count
FROM stocks
GROUP BY
    store_id,
    product_id
HAVING COUNT(*) > 1;