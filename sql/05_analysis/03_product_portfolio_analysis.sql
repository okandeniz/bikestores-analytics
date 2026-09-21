USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Business Analysis - 03 Product Portfolio Analysis
-- ============================================================


-- ------------------------------------------------------------
-- 1. ABC Product Classification
--
-- A: Products generating the first ~80% of revenue
-- B: Products generating the next ~15%
-- C: Remaining products
-- ------------------------------------------------------------

WITH product_sales AS (

    SELECT
        product_id,
        product_name,
        brand_name,
        category_name,

        SUM(quantity) AS units_sold,

        SUM(realized_net_sales) AS net_sales

    FROM vw_sales_enriched

    WHERE is_completed = 1

    GROUP BY
        product_id,
        product_name,
        brand_name,
        category_name
),

product_ranked AS (

    SELECT
        *,

        SUM(net_sales) OVER (
            ORDER BY net_sales DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS cumulative_sales,

        SUM(net_sales) OVER () AS total_sales

    FROM product_sales
),

product_abc AS (

    SELECT
        *,

        cumulative_sales
        / NULLIF(total_sales, 0) AS cumulative_sales_share,

        CASE
            WHEN cumulative_sales
                 / NULLIF(total_sales, 0) <= 0.80
                THEN 'A'

            WHEN cumulative_sales
                 / NULLIF(total_sales, 0) <= 0.95
                THEN 'B'

            ELSE 'C'
        END AS abc_class

    FROM product_ranked
)

SELECT
    product_id,
    product_name,
    brand_name,
    category_name,

    units_sold,

    ROUND(net_sales, 2) AS net_sales,

    ROUND(
        net_sales * 100.0
        / total_sales,
        2
    ) AS revenue_share_pct,

    ROUND(
        cumulative_sales_share * 100,
        2
    ) AS cumulative_revenue_pct,

    abc_class

FROM product_abc

ORDER BY net_sales DESC;


-- ------------------------------------------------------------
-- 2. ABC Class Summary
-- ------------------------------------------------------------

WITH product_sales AS (

    SELECT
        product_id,
        SUM(quantity) AS units_sold,
        SUM(realized_net_sales) AS net_sales

    FROM vw_sales_enriched

    WHERE is_completed = 1

    GROUP BY product_id
),

ranked AS (

    SELECT
        *,

        SUM(net_sales) OVER (
            ORDER BY net_sales DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        )
        /
        SUM(net_sales) OVER () AS cumulative_share

    FROM product_sales
),

abc AS (

    SELECT
        *,

        CASE
            WHEN cumulative_share <= 0.80 THEN 'A'
            WHEN cumulative_share <= 0.95 THEN 'B'
            ELSE 'C'
        END AS abc_class

    FROM ranked
)

SELECT
    abc_class,

    COUNT(*) AS product_count,

    SUM(units_sold) AS units_sold,

    ROUND(
        SUM(net_sales),
        2
    ) AS net_sales,

    ROUND(
        SUM(net_sales) * 100.0
        / SUM(SUM(net_sales)) OVER (),
        2
    ) AS revenue_share_pct

FROM abc

GROUP BY abc_class

ORDER BY abc_class;

-- ------------------------------------------------------------
-- 3. Category x Brand Performance
-- ------------------------------------------------------------

SELECT
    category_name,
    brand_name,

    SUM(quantity) AS units_sold,

    ROUND(
        SUM(realized_net_sales),
        2
    ) AS net_sales,

    COUNT(
        DISTINCT product_id
    ) AS products_sold

FROM vw_sales_enriched

WHERE is_completed = 1

GROUP BY
    category_name,
    brand_name

ORDER BY
    category_name,
    net_sales DESC;
    
-- ------------------------------------------------------------
-- 4. Store x Category Performance
-- ------------------------------------------------------------

SELECT
    store_name,
    category_name,

    COUNT(DISTINCT order_id) AS orders,

    SUM(quantity) AS units_sold,

    ROUND(
        SUM(realized_net_sales),
        2
    ) AS net_sales,

    ROUND(
        SUM(realized_net_sales)
        / NULLIF(COUNT(DISTINCT order_id), 0),
        2
    ) AS revenue_per_order

FROM vw_sales_enriched

WHERE is_completed = 1

GROUP BY
    store_id,
    store_name,
    category_id,
    category_name

ORDER BY
    store_name,
    net_sales DESC;
    
-- ------------------------------------------------------------
-- 5. Products with no completed sales
-- ------------------------------------------------------------

WITH sold_products AS (

    SELECT DISTINCT
        product_id

    FROM vw_sales_enriched

    WHERE is_completed = 1
)

SELECT
    COUNT(*) AS products_without_completed_sales

FROM products p

LEFT JOIN sold_products sp
    ON p.product_id = sp.product_id

WHERE sp.product_id IS NULL;


-- ------------------------------------------------------------
-- 6. Products with no completed sales - detail
-- ------------------------------------------------------------

WITH sold_products AS (

    SELECT DISTINCT
        product_id

    FROM vw_sales_enriched

    WHERE is_completed = 1
)

SELECT
    p.product_id,
    p.product_name,
    p.model_year,
    b.brand_name,
    c.category_name,
    p.list_price

FROM products p

LEFT JOIN sold_products sp
    ON p.product_id = sp.product_id

INNER JOIN brands b
    ON p.brand_id = b.brand_id

INNER JOIN categories c
    ON p.category_id = c.category_id

WHERE sp.product_id IS NULL

ORDER BY
    p.model_year DESC,
    p.product_id;
    
WITH sold_products AS (
	SELECT DISTINCT product_id
    FROM vw_sales_enriched
    WHERE is_completed = 1
)

SELECT
    p.model_year,
    COUNT(*) AS product_count
FROM products p
LEFT JOIN sold_products sp
    ON p.product_id = sp.product_id
WHERE sp.product_id IS NULL
GROUP BY p.model_year
ORDER BY p.model_year;

