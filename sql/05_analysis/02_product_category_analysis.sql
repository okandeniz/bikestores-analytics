USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Business Analysis - 02 Product & Category Analysis
-- ============================================================


-- ------------------------------------------------------------
-- 1. Category Performance
-- Completed orders only
-- ------------------------------------------------------------

SELECT * FROM vw_sales_enriched LIMIT 10;

-- Which categories are driving the company's sales revenue?

SELECT
	category_id,
    category_name,
    
    ROUND(
		SUM(realized_net_sales),
        2
	) AS net_sales,
    
    SUM(quantity) AS units_sold,
    
    COUNT(DISTINCT order_id) AS orders,
    
    COUNT(DISTINCT customer_id) AS customers,
    
    ROUND(
        SUM(realized_net_sales)
        / COUNT(DISTINCT order_id),
        2
    ) AS revenue_per_order
    
FROM vw_sales_enriched
WHERE is_completed = 1
GROUP BY
	category_id,
    category_name
ORDER BY net_sales DESC;

-- ------------------------------------------------------------
-- 2. Category Revenue Contribution
-- ------------------------------------------------------------

WITH category_sales AS (
	
    SELECT
		category_id,
        category_name,
        SUM(realized_net_sales) AS net_sales
        
	FROM vw_sales_enriched
    
    WHERE is_completed = 1
    
    GROUP BY
        category_id,
        category_name
)

SELECT
	category_id,
    category_name,
    
    ROUND(
		net_sales,
        2
	) AS net_sales,
    
    ROUND(
		net_sales *100.0
        / SUM(net_sales) OVER (),
        2
	) AS revenue_share_pct

FROM category_sales
ORDER BY net_sales DESC;

-- ------------------------------------------------------------
-- 3. Category Sales Value per Unit
-- ------------------------------------------------------------

SELECT
	category_name,
    SUM(quantity) AS unıts_sold,
    
    ROUND(
		SUM(realized_net_sales),
        2
	) AS net_sales,
    
    ROUND(
        SUM(realized_net_sales)
        / NULLIF(SUM(quantity), 0),
        2
    ) AS avg_net_sales_per_unit
    
FROM vw_sales_enriched
WHERE is_completed = 1
GROUP BY category_name
ORDER BY avg_net_sales_per_unit DESC;

-- ------------------------------------------------------------
-- 4. Brand Performance
-- ------------------------------------------------------------

SELECT
	brand_id,
    brand_name,
    
    ROUND(
		SUM(realized_net_sales),
        2
	) AS net_sales,
    
    SUM(quantity) AS units_sold,
    
    COUNT(DISTINCT order_id) AS orders,
    
    COUNT(DISTINCT product_id) AS products_sold,
    
    ROUND(
        SUM(realized_net_sales)
        / NULLIF(SUM(quantity), 0),
        2
    ) AS avg_net_sales_per_unit
    
FROM vw_sales_enriched
WHERE is_completed = 1
GROUP BY
	brand_id,
    brand_name
ORDER BY net_sales DESC;

-- ------------------------------------------------------------
-- 5. Brand Revenue Contribution
-- ------------------------------------------------------------

WITH brand_sales AS (

    SELECT
        brand_id,
        brand_name,
        SUM(realized_net_sales) AS net_sales

    FROM vw_sales_enriched

    WHERE is_completed = 1

    GROUP BY
        brand_id,
        brand_name
)

SELECT
    brand_name,

    ROUND(
        net_sales,
        2
    ) AS net_sales,

    ROUND(
        net_sales * 100.0
        / SUM(net_sales) OVER (),
        2
    ) AS revenue_share_pct

FROM brand_sales

ORDER BY net_sales DESC;

-- ------------------------------------------------------------
-- 6. Top 15 Products by Net Sales
-- ------------------------------------------------------------

SELECT
	product_id,
    product_name,
    brand_name,
    category_name,
    
    ROUND(
		SUM(realized_net_sales),
        2
	) AS net_sales,
    
    SUM(quantity) AS units_sold,
    
    COUNT(DISTINCT order_id) AS orders,
    
    ROUND(
		SUM(realized_net_sales)
        / NULLIF(SUM(quantity), 0),
        2
	) AS avg_net_sales_per_unit
    
FROM vw_sales_enriched
WHERE is_completed = 1
GROUP BY
    product_id,
    product_name,
    brand_name,
    category_name

ORDER BY net_sales DESC

LIMIT 15;

-- ------------------------------------------------------------
-- 7. Top 15 Products by Units Sold
-- ------------------------------------------------------------

SELECT
    product_id,
    product_name,
    brand_name,
    category_name,

    SUM(quantity) AS units_sold,

    ROUND(
        SUM(realized_net_sales),
        2
    ) AS net_sales,

    ROUND(
        SUM(realized_net_sales)
        / NULLIF(SUM(quantity), 0),
        2
    ) AS avg_net_sales_per_unit

FROM vw_sales_enriched

WHERE is_completed = 1

GROUP BY
    product_id,
    product_name,
    brand_name,
    category_name

ORDER BY units_sold DESC

LIMIT 15;

-- ------------------------------------------------------------
-- 8. Discount Performance by Category
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
    ) AS discount_amount,
    
    ROUND(
        SUM(realized_net_sales),
        2
    ) AS net_sales,
    
    ROUND(
        SUM(discount_amount)
        / NULLIF(SUM(gross_sales), 0)
        * 100,
        2
    ) AS effective_discount_pct,
    
    SUM(quantity) AS units_sold
    
FROM vw_sales_enriched
WHERE is_completed = 1
GROUP BY category_name
ORDER BY net_sales DESC;

-- ------------------------------------------------------------
-- 9. Discount Level Performance
-- ------------------------------------------------------------

SELECT
	ROUND(discount * 100, 0) AS discount_pct,
    
    COUNT(DISTINCT order_id) AS orders,
    
    SUM(quantity) AS units_sold,
    
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
	
