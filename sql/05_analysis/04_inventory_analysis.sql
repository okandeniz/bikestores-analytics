USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Business Analysis - 04 Inventory Analysis
-- ============================================================


-- ------------------------------------------------------------
-- 1. Stock coverage
-- ------------------------------------------------------------

SELECT
    (SELECT COUNT(*) FROM products)
    *
    (SELECT COUNT(*) FROM stores)
        AS expected_store_product_combinations,

    (SELECT COUNT(*) FROM stocks)
        AS actual_stock_records,

    (
        (SELECT COUNT(*) FROM products)
        *
        (SELECT COUNT(*) FROM stores)
        -
        (SELECT COUNT(*) FROM stocks)
    ) AS missing_combinations;
    
-- ------------------------------------------------------------
-- 2. Missing store-product combinations
-- ------------------------------------------------------------

SELECT

	s.store_id,
    s.store_name,

    p.product_id,
    p.product_name,
    p.model_year,

    b.brand_name,
    c.category_name
	
FROM stores s

CROSS JOIN products p

LEFT JOIN stocks st
    ON s.store_id = st.store_id
   AND p.product_id = st.product_id
   
INNER JOIN brands b
    ON p.brand_id = b.brand_id
    
INNER JOIN categories c
    ON p.category_id = c.category_id
    
WHERE st.product_id IS NULL

ORDER BY
    p.product_id,
    s.store_id;
    
-- ------------------------------------------------------------
-- 3. Current out-of-stock records
-- ------------------------------------------------------------

SELECT
    s.store_name,
    p.product_id,
    p.product_name,
    p.model_year,
    b.brand_name,
    c.category_name,
    st.quantity

FROM stocks st

INNER JOIN stores s
    ON st.store_id = s.store_id

INNER JOIN products p
    ON st.product_id = p.product_id

INNER JOIN brands b
    ON p.brand_id = b.brand_id

INNER JOIN categories c
    ON p.category_id = c.category_id

WHERE st.quantity = 0

ORDER BY
    s.store_name,
    p.product_name;
    
-- ------------------------------------------------------------
-- 4. Stock status summary
-- ------------------------------------------------------------

SELECT
    CASE
        WHEN quantity = 0 THEN 'Out of Stock'
        WHEN quantity <= 5 THEN 'Low Stock'
        WHEN quantity <= 15 THEN 'Medium Stock'
        ELSE 'High Stock'
    END AS stock_status,

    COUNT(*) AS store_product_count

FROM stocks

GROUP BY stock_status

ORDER BY
    CASE stock_status
        WHEN 'Out of Stock' THEN 1
        WHEN 'Low Stock' THEN 2
        WHEN 'Medium Stock' THEN 3
        WHEN 'High Stock' THEN 4
    END;
    
-- ------------------------------------------------------------
-- 5. Missing stock combinations by store
-- ------------------------------------------------------------

WITH missing_stock AS (

    SELECT
        s.store_id,
        s.store_name,
        p.product_id,
        p.product_name,
        p.model_year

    FROM stores s

    CROSS JOIN products p

    LEFT JOIN stocks st
        ON s.store_id = st.store_id
       AND p.product_id = st.product_id

    WHERE st.product_id IS NULL
)

SELECT
    store_name,
    COUNT(*) AS missing_product_count
FROM missing_stock
GROUP BY
    store_id,
    store_name
ORDER BY missing_product_count DESC;

-- ------------------------------------------------------------
-- 6. Missing stock combinations by model year
-- ------------------------------------------------------------

WITH missing_stock AS (

    SELECT
        s.store_id,
        p.product_id,
        p.model_year

    FROM stores s

    CROSS JOIN products p

    LEFT JOIN stocks st
        ON s.store_id = st.store_id
       AND p.product_id = st.product_id

    WHERE st.product_id IS NULL
)

SELECT
    model_year,
    COUNT(*) AS missing_combination_count
FROM missing_stock
GROUP BY model_year
ORDER BY model_year;

-- ------------------------------------------------------------
-- 7. Inventory quantity summary
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS stock_records,

    SUM(quantity = 0) AS out_of_stock_records,

    SUM(quantity BETWEEN 1 AND 5) AS stock_1_5,

    SUM(quantity BETWEEN 6 AND 15) AS stock_6_15,

    SUM(quantity > 15) AS stock_above_15,

    SUM(quantity) AS total_units_in_stock

FROM stocks;

-- ------------------------------------------------------------
-- 8. Inventory by store
-- ------------------------------------------------------------

SELECT
    s.store_id,
    s.store_name,

    COUNT(*) AS products_listed,

    SUM(st.quantity) AS total_stock_units,

    SUM(st.quantity = 0) AS out_of_stock_products,

    ROUND(
        AVG(st.quantity),
        2
    ) AS avg_stock_per_product

FROM stocks st

INNER JOIN stores s
    ON st.store_id = s.store_id

GROUP BY
    s.store_id,
    s.store_name

ORDER BY total_stock_units DESC;


-- ------------------------------------------------------------
-- 9. No-sales products with inventory
-- ------------------------------------------------------------

WITH completed_product_sales AS (

    SELECT
        product_id,
        SUM(quantity) AS units_sold,
        SUM(realized_net_sales) AS net_sales

    FROM vw_sales_enriched

    WHERE is_completed = 1

    GROUP BY product_id
),

product_inventory AS (

    SELECT
        product_id,
        COUNT(*) AS stores_listed,
        SUM(quantity) AS total_stock,
        SUM(quantity = 0) AS out_of_stock_stores

    FROM stocks

    GROUP BY product_id
)

SELECT
    p.product_id,
    p.product_name,
    p.model_year,
    b.brand_name,
    c.category_name,

    COALESCE(pi.stores_listed, 0) AS stores_listed,
    COALESCE(pi.total_stock, 0) AS total_stock,
    COALESCE(pi.out_of_stock_stores, 0) AS out_of_stock_stores

FROM products p

INNER JOIN brands b
    ON p.brand_id = b.brand_id

INNER JOIN categories c
    ON p.category_id = c.category_id

LEFT JOIN completed_product_sales ps
    ON p.product_id = ps.product_id

LEFT JOIN product_inventory pi
    ON p.product_id = pi.product_id

WHERE ps.product_id IS NULL

ORDER BY
    p.model_year,
    total_stock DESC;
    
