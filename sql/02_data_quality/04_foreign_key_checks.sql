USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Data Quality - 04 Foreign Key Checks
-- ============================================================


-- ------------------------------------------------------------
-- 1. orders -> customers
-- ------------------------------------------------------------

SELECT
	COUNT(*) AS orphan_records
FROM orders o
LEFT JOIN customers c
	ON o.customer_id = c.customer_id
WHERE o.customer_id IS NOT NULL
	AND c.customer_id IS NULL;
    
-- ------------------------------------------------------------
-- 2. orders -> stores
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM orders o
LEFT JOIN stores s
    ON o.store_id = s.store_id
WHERE s.store_id IS NULL;

-- ------------------------------------------------------------
-- 3. orders -> staffs
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM orders o
LEFT JOIN staffs st
    ON o.staff_id = st.staff_id
WHERE st.staff_id IS NULL;

-- ------------------------------------------------------------
-- 4. order_items -> orders
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- ------------------------------------------------------------
-- 5. order_items -> products
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- ------------------------------------------------------------
-- 6. products -> brands
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM products p
LEFT JOIN brands b
    ON p.brand_id = b.brand_id
WHERE b.brand_id IS NULL;

-- ------------------------------------------------------------
-- 7. products -> categories
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM products p
LEFT JOIN categories c
    ON p.category_id = c.category_id
WHERE c.category_id IS NULL;

-- ------------------------------------------------------------
-- 8. stocks -> stores
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM stocks st
LEFT JOIN stores s
    ON st.store_id = s.store_id
WHERE s.store_id IS NULL;

-- ------------------------------------------------------------
-- 9. stocks -> products
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM stocks st
LEFT JOIN products p
    ON st.product_id = p.product_id
WHERE p.product_id IS NULL;

-- ------------------------------------------------------------
-- 10. staffs -> stores
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM staffs st
LEFT JOIN stores s
    ON st.store_id = s.store_id
WHERE s.store_id IS NULL;

-- ------------------------------------------------------------
-- 11. staffs -> manager
-- Self-referencing foreign key
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM staffs st
LEFT JOIN staffs manager
    ON st.manager_id = manager.staff_id
WHERE st.manager_id IS NOT NULL
  AND manager.staff_id IS NULL;