USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- View: vw_inventory_risk
--
-- Grain:
-- 1 row = 1 store-product combination
--
-- Note:
-- Inventory classifications are analytical indicators,
-- not formal replenishment policies.
-- ============================================================

CREATE OR REPLACE VIEW vw_inventory_risk AS

SELECT
    *,

    CASE
        WHEN avg_monthly_units_12m > 0
        THEN ROUND(
            current_stock / avg_monthly_units_12m,
            2
        )
        ELSE NULL
    END AS stock_coverage_months,

    CASE

        -- Historical demand exists but no inventory remains
        WHEN units_sold_12m > 0
             AND current_stock = 0
            THEN 'Stockout Risk'

        -- Meaningful historical demand + <= 1 month coverage
        WHEN units_sold_12m >= 12
             AND current_stock / avg_monthly_units_12m <= 1
            THEN 'High Replenishment Priority'

        -- Moderate historical demand + <= 2 months coverage
        WHEN units_sold_12m >= 6
             AND current_stock / avg_monthly_units_12m <= 2
            THEN 'Replenishment Review'

        -- No sales observed in the 12-month demand window
        WHEN units_sold_12m = 0
             AND current_stock > 0
            THEN 'No Recent Demand'

        -- Sparse demand: coverage metric is unreliable
        WHEN units_sold_12m BETWEEN 1 AND 5
             AND current_stock > 0
            THEN 'Slow Demand Review'

        -- Overstock flag only when demand history is sufficient
        WHEN units_sold_12m >= 6
             AND current_stock / avg_monthly_units_12m > 6
            THEN 'Potential Overstock'

        ELSE 'Healthy / Monitor'

    END AS inventory_risk

FROM vw_store_product_velocity;
    
 -- Inventory Risk Summary
 
SELECT * FROM vw_inventory_risk LIMIT 10;

SELECT
    inventory_risk,

    COUNT(*) AS store_product_count,

    SUM(current_stock) AS stock_units,

    ROUND(
        SUM(net_sales_12m),
        2
    ) AS net_sales_12m

FROM vw_inventory_risk

GROUP BY inventory_risk

ORDER BY store_product_count DESC;

-- Critical stocks

 SELECT
    store_name,
    product_name,
    brand_name,
    category_name,
    abc_class,

    current_stock,
    units_sold_12m,
    avg_monthly_units_12m,
    stock_coverage_months,

    inventory_risk

FROM vw_inventory_risk

WHERE inventory_risk IN (
    'Stockout Risk',
    'High Replenishment Priority',
    'Replenishment Review'
)

ORDER BY
    CASE inventory_risk
        WHEN 'Stockout Risk' THEN 1
        WHEN 'High Replenishment Priority' THEN 2
        WHEN 'Replenishment Review' THEN 3
    END,

    net_sales_12m DESC;
    
-- overstock
SELECT
    store_name,
    product_name,
    model_year,
    brand_name,
    category_name,
    abc_class,

    current_stock,
    units_sold_12m,
    avg_monthly_units_12m,
    stock_coverage_months,

    inventory_risk

FROM vw_inventory_risk

WHERE inventory_risk IN (
    'Potential Overstock',
    'No Recent Demand'
)

ORDER BY
    current_stock DESC;
    
SELECT
    abc_class,
    inventory_risk,
    COUNT(*) AS product_store_count,
    SUM(current_stock) AS stock_units,

    ROUND(
        SUM(net_sales_12m),
        2
    ) AS net_sales_12m

FROM vw_inventory_risk

GROUP BY
    abc_class,
    inventory_risk

ORDER BY
    abc_class,
    product_store_count DESC;

