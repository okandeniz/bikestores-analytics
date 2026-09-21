USE bikestores;
    
-- ============================================================
-- BikeStores Analytics
-- View: vw_inventory_priority
--
-- Grain:
-- 1 row = 1 store-product inventory record
-- ============================================================

SELECT * FROM vw_product_portfolio LIMIT 15;


CREATE OR REPLACE VIEW vw_inventory_priority AS

SELECT
    st.store_id,
    s.store_name,

    st.product_id,
    pp.product_name,
    pp.model_year,

    pp.brand_id,
    pp.brand_name,

    pp.category_id,
    pp.category_name,

    pp.abc_class,

    pp.units_sold AS historical_units_sold,
    pp.net_sales AS historical_net_sales,

    st.quantity AS current_stock,

    CASE
        WHEN st.quantity = 0 THEN 'Out of Stock'
        WHEN st.quantity <= 5 THEN 'Low Stock'
        WHEN st.quantity <= 15 THEN 'Medium Stock'
        ELSE 'High Stock'
    END AS stock_status,

    CASE

        WHEN pp.abc_class = 'A'
             AND st.quantity = 0
            THEN 'Critical Replenishment'

        WHEN pp.abc_class = 'A'
             AND st.quantity <= 5
            THEN 'Replenishment Priority'

        WHEN pp.abc_class = 'B'
             AND st.quantity <= 5
            THEN 'Review Replenishment'

        WHEN pp.abc_class = 'C'
             AND st.quantity > 15
            THEN 'Overstock Review'

        WHEN pp.abc_class = 'N'
             AND pp.model_year <= 2017
             AND st.quantity > 15
            THEN 'Slow-Moving Review'

        WHEN pp.abc_class = 'N'
             AND pp.model_year >= 2018
            THEN 'Monitor - Limited History'

        ELSE 'Normal'
    END AS inventory_action

FROM stocks st

INNER JOIN stores s
    ON st.store_id = s.store_id

INNER JOIN vw_product_portfolio pp
    ON st.product_id = pp.product_id;


SELECT * FROM vw_inventory_priority LIMIT 10;
    
SELECT
    inventory_action,
    COUNT(*) AS store_product_count,
    SUM(current_stock) AS total_stock_units
FROM vw_inventory_priority
GROUP BY inventory_action
ORDER BY store_product_count DESC;

SELECT
    store_name,
    product_name,
    brand_name,
    category_name,
    abc_class,
    current_stock,
    inventory_action
FROM vw_inventory_priority
WHERE inventory_action IN (
    'Critical Replenishment',
    'Replenishment Priority',
    'Review Replenishment'
)
ORDER BY
    CASE inventory_action
        WHEN 'Critical Replenishment' THEN 1
        WHEN 'Replenishment Priority' THEN 2
        WHEN 'Review Replenishment' THEN 3
    END,
    historical_net_sales DESC;
    
SELECT
    store_name,
    product_name,
    model_year,
    brand_name,
    category_name,
    abc_class,
    current_stock,
    historical_units_sold,
    historical_net_sales,
    inventory_action
FROM vw_inventory_priority
WHERE inventory_action IN (
    'Overstock Review',
    'Slow-Moving Review'
)
ORDER BY
    current_stock DESC,
    historical_net_sales ASC;