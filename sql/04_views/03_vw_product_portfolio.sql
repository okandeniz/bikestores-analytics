USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- View: vw_product_portfolio
--
-- Grain:
-- 1 row = 1 product
--
-- Purpose:
-- Product sales performance and ABC/N classification
-- ============================================================

SELECT * FROM vw_sales_enriched LIMIT 10;


CREATE OR REPLACE VIEW vw_product_portfolio AS

WITH product_sales AS (

    SELECT
        p.product_id,
        p.product_name,
        p.model_year,
        p.list_price AS catalog_list_price,

        b.brand_id,
        b.brand_name,

        c.category_id,
        c.category_name,

        COALESCE(
            SUM(
                CASE
                    WHEN vse.is_completed = 1
                    THEN vse.quantity
                    ELSE 0
                END
            ),
            0
        ) AS units_sold,

        COALESCE(
            SUM(
                CASE
                    WHEN vse.is_completed = 1
                    THEN vse.realized_net_sales
                    ELSE 0
                END
            ),
            0
        ) AS net_sales

    FROM products p

    INNER JOIN brands b
        ON p.brand_id = b.brand_id

    INNER JOIN categories c
        ON p.category_id = c.category_id

    LEFT JOIN vw_sales_enriched vse
        ON p.product_id = vse.product_id

    GROUP BY
        p.product_id,
        p.product_name,
        p.model_year,
        p.list_price,
        b.brand_id,
        b.brand_name,
        c.category_id,
        c.category_name
),

ranked AS (

    SELECT
        *,

        SUM(net_sales) OVER (
            ORDER BY net_sales DESC, product_id
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS cumulative_sales,

        SUM(net_sales) OVER () AS total_sales

    FROM product_sales
),

classified AS (

    SELECT
        *,

        CASE
            WHEN net_sales = 0 THEN 'N'

            WHEN cumulative_sales
                 / NULLIF(total_sales, 0) <= 0.80
                THEN 'A'

            WHEN cumulative_sales
                 / NULLIF(total_sales, 0) <= 0.95
                THEN 'B'

            ELSE 'C'
        END AS abc_class

    FROM ranked
)

SELECT
    product_id,
    product_name,
    model_year,
    catalog_list_price,

    brand_id,
    brand_name,

    category_id,
    category_name,

    units_sold,

    ROUND(
        net_sales,
        2
    ) AS net_sales,

    ROUND(
        net_sales * 100.0
        / NULLIF(total_sales, 0),
        2
    ) AS revenue_share_pct,

    abc_class

FROM classified;


SELECT * FROM vw_product_portfolio LIMIT 15;

SELECT
    abc_class,
    COUNT(*) AS product_count
FROM vw_product_portfolio
GROUP BY abc_class
ORDER BY abc_class;