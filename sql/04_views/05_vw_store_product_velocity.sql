USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- View: vw_store_product_velocity
--
-- Grain:
-- 1 row = 1 store-product combination
--
-- Demand window:
-- 2017-05-01 to 2018-04-30
-- ============================================================


SELECT * FROM vw_product_portfolio LIMIT 10;

CREATE OR REPLACE VIEW vw_store_product_velocity AS

WITH parameters AS (
	
    SELECT
		DATE('2017-05-01') AS start_date,
        DATE('2018-05-01') AS end_date
),

sales_12m AS (
	
    SELECT
		vse.store_id,
        vse.product_id,
        
        SUM(vse.quantity) AS units_sold_12m,
        
        ROUND(
			SUM(vse.realized_net_sales),
            2
		) AS net_sales_12m,
        
        COUNT(
            DISTINCT vse.order_id
        ) AS orders_12m,
        
        COUNT(
            DISTINCT DATE_FORMAT(
                vse.order_date,
                '%Y-%m'
            )
        ) AS active_sales_months
        
	FROM vw_sales_enriched vse
    
    CROSS JOIN parameters p
    
    WHERE vse.is_completed = 1
		AND vse.order_date >= p.start_date
        AND vse.order_date < p.end_date
        
	GROUP BY
		vse.store_id,
        vse.product_id
)

SELECT
	st.store_id,
    s.store_name,
    
    st.product_id,
    pp.product_name,
    pp.model_year,
    pp.brand_name,
    pp.category_name,
    pp.abc_class,
    
    st.quantity AS current_stock,
    
    COALESCE(
        sl.units_sold_12m,
        0
    ) AS units_sold_12m,
    
    COALESCE(
        sl.net_sales_12m,
        0
    ) AS net_sales_12m,
    
    COALESCE(
        sl.orders_12m,
        0
    ) AS orders_12m,
    
    COALESCE(
        sl.active_sales_months,
        0
    ) AS active_sales_months,
    
	-- Average monthly demand including months with zero sales
    ROUND(
        COALESCE(sl.units_sold_12m, 0) / 12.0,
        2
    ) AS avg_monthly_units_12m,
    
    CASE
		WHEN COALESCE(sl.active_sales_months, 0) > 0
        THEN ROUND(
			sl.units_sold_12m
            / sl.active_sales_months,
            2
		)
        ELSE 0
	END AS avg_units_per_active_month
    
FROM stocks st

INNER JOIN stores s
    ON st.store_id = s.store_id
    
INNER JOIN vw_product_portfolio pp
    ON st.product_id = pp.product_id
    
LEFT JOIN sales_12m sl
    ON st.store_id = sl.store_id
   AND st.product_id = sl.product_id;

-- Control

SELECT
    (SELECT COUNT(*) FROM stocks) AS stock_rows,
    (SELECT COUNT(*) FROM vw_store_product_velocity) AS velocity_rows;
    
SELECT
    COUNT(*) AS total_rows,
    COUNT(
        DISTINCT CONCAT(
            store_id,
            '-',
            product_id
        )
    ) AS unique_store_products
FROM vw_store_product_velocity;

-- Sales velocity distribution

SELECT * FROM vw_store_product_velocity LIMIT 10;

SELECT
	CASE
		WHEN units_sold_12m = 0
			THEN 'No Sales'
		
        WHEN units_sold_12m <= 5
			THEN 'Very Low Demand'
		
        WHEN units_sold_12m <= 15
			THEN 'Low Demand'
            
		WHEN units_sold_12m <= 30
			THEN 'Medium Demand'
		
        ELSE 'High Demand'
	END AS demand_band,
        
	COUNT(*) AS store_product_count
        
FROM vw_store_product_velocity
GROUP BY demand_band

ORDER BY
    CASE demand_band
        WHEN 'No Sales' THEN 1
        WHEN 'Very Low Demand' THEN 2
        WHEN 'Low Demand' THEN 3
        WHEN 'Medium Demand' THEN 4
        WHEN 'High Demand' THEN 5
    END;
