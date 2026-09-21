USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Excel Export View: vw_excel_inventory
--
-- Grain:
-- 1 row = 1 store-product inventory record
--
-- Main use:
-- Current inventory and inventory-risk analysis
-- ============================================================

SELECT * FROM vw_inventory_risk  LIMIT 10;

CREATE OR REPLACE VIEW vw_excel_inventory AS

SELECT
	-- Region / Store
    s.state AS region,
    
    vir.store_id,
    vir.store_name,
    
    -- Product
	vir.product_id,
    vir.product_name,
    vir.model_year,

    vir.brand_name,
    vir.category_name,

    vir.abc_class,
    
    -- Current inventory
    vir.current_stock,
    
    CASE
        WHEN vir.current_stock = 0
            THEN 'Out of Stock'

        WHEN vir.current_stock <= 5
            THEN 'Low Stock'

        WHEN vir.current_stock <= 15
            THEN 'Medium Stock'

        ELSE 'High Stock'
    END AS stock_status,
    
    -- Historical demand
    vir.units_sold_12m,
    vir.net_sales_12m,
    vir.orders_12m,

    vir.active_sales_months,

    vir.avg_monthly_units_12m,
    vir.avg_units_per_active_month,
    
    -- Inventory coverage / risk
    vir.stock_coverage_months,
    vir.inventory_risk
    
FROM vw_inventory_risk vir

INNER JOIN stores s
	ON vir.store_id = s.store_id
    
