USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Business Analysis - 07 Discount Effectiveness
-- ============================================================


-- ------------------------------------------------------------
-- 1. Overall discount-level performance
-- ------------------------------------------------------------

SELECT
	ROUND(discount * 100.0, 0) AS discount_pct,
    
    COUNT(*) AS order_lines,
    
    COUNT(DISTINCT order_id) AS orders,
    
    COUNT(DISTINCT product_id) AS products,
    
    SUM(quantity) AS units_sold,
    
    ROUND(
        AVG(quantity),
        2
    ) AS avg_units_per_line,
    
    ROUND(
        SUM(gross_sales),
        2
    ) AS gross_sales,
    
    ROUND(
        SUM(discount_amount),
        2
    ) AS discount_amount,
    
    ROUND(
        SUM(realized_net_sales),
        2
    ) AS net_sales,
    
    ROUND(
        SUM(realized_net_sales)
        / NULLIF(SUM(quantity), 0),
        2
    ) AS net_sales_per_unit
    
FROM vw_sales_enriched

WHERE is_completed = 1
GROUP BY discount
ORDER BY discount;

-- ------------------------------------------------------------
-- 2. Discount variation by product
-- ------------------------------------------------------------


WITH product_discount_count AS (
	
    SELECT
		product_id,
        COUNT(DISTINCT discount) AS discount_levels
	FROM vw_sales_enriched
    WHERE is_completed = 1
    GROUP BY product_id
)

SELECT
	discount_levels,
    COUNT(*) AS product_count
    
FROM product_discount_count

GROUP BY discount_levels

ORDER BY discount_levels;

-- ------------------------------------------------------------
-- 3. Product-level discount performance
-- ------------------------------------------------------------

SELECT
	product_id,
    product_name,
    category_name,
    brand_name,
    
    ROUND(discount * 100.0, 0) AS discount_pct,
    
    COUNT(*) AS order_lines,
    
    COUNT(DISTINCT order_id) AS orders,
    
    SUM(quantity) AS units_sold,
    
    ROUND(
        AVG(quantity),
        2
    ) AS avg_units_per_line,
    
    ROUND(
        SUM(realized_net_sales),
        2
    ) AS net_sales,

	
    ROUND(
        SUM(realized_net_sales)
        / NULLIF(SUM(quantity), 0),
        2
    ) AS net_sales_per_unit

    
FROM vw_sales_enriched

WHERE is_completed = 1

GROUP BY
	product_id,
    product_name,
    brand_name,
    discount

ORDER BY
    product_id,
    discount;
    
-- ------------------------------------------------------------
-- 4. Same-product comparison: 5% vs 20%
-- ------------------------------------------------------------

WITH product_discount AS (
	
    SELECT
		product_id,
        discount,
        
        COUNT(*) AS order_lines,
        
        SUM(quantity) AS units_sold,
        
        AVG(quantity) AS avg_units_per_line
        
	FROM vw_sales_enriched
    
    WHERE is_completed = 1
		AND discount IN (0.05, 0.20)
        
	GROUP BY
		product_id,
        discount
),

paried_products AS (
	
    SELECT
		product_id,
        
        MAX(
			CASE
				WHEN discount = 0.05
                THEN avg_units_per_line
			END
		) AS avg_units_5pct,
        
        MAX(
            CASE
                WHEN discount = 0.20
                THEN avg_units_per_line
            END
        ) AS avg_units_20pct,
			
        MAX(
            CASE
                WHEN discount = 0.05
                THEN order_lines
            END
        ) AS lines_5pct,

        MAX(
            CASE
                WHEN discount = 0.20
                THEN order_lines
            END
        ) AS lines_20pct

    FROM product_discount

    GROUP BY product_id
)

SELECT
	COUNT(*) AS comparable_products,
    
    ROUND(
        AVG(avg_units_5pct),
        3
    ) AS avg_units_per_line_5pct,
    
    ROUND(
        AVG(avg_units_20pct),
        3
    ) AS avg_units_per_line_20pct,
    
    ROUND(
        AVG(avg_units_20pct - avg_units_5pct),
        3
    ) AS avg_difference
    
FROM paried_products

WHERE avg_units_5pct IS NOT NULL
	AND avg_units_20pct IS NOT NULL;
    
-- ------------------------------------------------------------
-- 5. Product response: 5% vs 20%
-- ------------------------------------------------------------

WITH product_discount AS (

    SELECT
        product_id,
        discount,

        AVG(quantity) AS avg_units_per_line

    FROM vw_sales_enriched

    WHERE is_completed = 1
      AND discount IN (0.05, 0.20)

    GROUP BY
        product_id,
        discount
),

paired AS (

    SELECT
        product_id,

        MAX(
            CASE
                WHEN discount = 0.05
                THEN avg_units_per_line
            END
        ) AS units_5,

        MAX(
            CASE
                WHEN discount = 0.20
                THEN avg_units_per_line
            END
        ) AS units_20

    FROM product_discount

    GROUP BY product_id
)

SELECT
    CASE
        WHEN units_20 > units_5
            THEN 'Higher Volume at 20%'

        WHEN units_20 < units_5
            THEN 'Lower Volume at 20%'

        ELSE 'No Difference'
    END AS volume_response,

    COUNT(*) AS product_count

FROM paired

WHERE units_5 IS NOT NULL
  AND units_20 IS NOT NULL

GROUP BY volume_response

ORDER BY product_count DESC;

-- ------------------------------------------------------------
-- 6. Discount cost by category
-- ------------------------------------------------------------

SELECT
	category_name,
    
    ROUND(
		SUM(gross_sales),
        2
	) AS gross_sales,
    
    ROUND(
        SUM(discount_amount),
        2
    ) AS discount_cost,
    
    ROUND(
        SUM(realized_net_sales),
        2
    ) AS net_sales,
    
    ROUND(
        SUM(discount_amount) * 100.0
        / NULLIF(SUM(gross_sales), 0),
        2
    ) AS effective_discount_pct,
    
    ROUND(
        SUM(discount_amount) * 100.0
        / SUM(
            SUM(discount_amount)
        ) OVER (),
        2
    ) AS share_of_total_discount_cost_pct
    
FROM vw_sales_enriched

WHERE is_completed = 1

GROUP BY category_name

ORDER BY discount_cost DESC;

-- Discount cost by brand

SELECT
    brand_name,

    ROUND(
        SUM(gross_sales),
        2
    ) AS gross_sales,

    ROUND(
        SUM(discount_amount),
        2
    ) AS discount_cost,

    ROUND(
        SUM(realized_net_sales),
        2
    ) AS net_sales,

    ROUND(
        SUM(discount_amount) * 100.0
        / NULLIF(SUM(gross_sales), 0),
        2
    ) AS effective_discount_pct

FROM vw_sales_enriched

WHERE is_completed = 1

GROUP BY brand_name

ORDER BY discount_cost DESC;
