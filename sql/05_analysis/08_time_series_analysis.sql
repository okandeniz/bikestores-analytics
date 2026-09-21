USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Business Analysis - 08 Time Series Analysis
--
-- Reliable analytical period:
-- 2016-01-01 to 2018-04-30
-- ============================================================


-- ------------------------------------------------------------
-- 1. Monthly Sales Performance
-- ------------------------------------------------------------

SELECT
	order_year,
    order_month,
    order_month_name,
    order_year_month,
    
    COUNT(*) AS completed_orders,
    
    SUM(total_units) AS units_sold,
    
    ROUND(
        SUM(realized_order_value),
        2
    ) AS net_sales,
    
    ROUND(
        SUM(realized_order_value) / COUNT(*),
        2
    ) AS average_order_value
    
FROM vw_order_summary

WHERE is_completed = 1
	AND order_date < '2018-05-01'

GROUP BY
	order_year,
    order_month,
    order_month_name,
    order_year_month
    
ORDER BY
    order_year,
    order_month;
    
-- ------------------------------------------------------------
-- 2. Month-over-Month Net Sales Growth
-- ------------------------------------------------------------

WITH monthly_sales AS (
	
    SELECT
		YEAR(order_date) AS order_year,
        MONTH(order_date) AS order_month,
        
        DATE_FORMAT(
			order_date,
            '%Y-%m'
		) AS year_monthh,
        
        SUM(realized_order_value) AS net_sales
        
	FROM vw_order_summary
    
    WHERE is_completed = 1
      AND order_date < '2018-05-01'
      
	GROUP BY
        YEAR(order_date),
        MONTH(order_date),
        DATE_FORMAT(order_date, '%Y-%m')
),

growth AS (
	
    SELECT
		*,
        
        LAG(net_sales) OVER (
			ORDER BY order_year, order_month
		) AS previous_month_sales
		
	FROM monthly_sales
)

SELECT
	year_monthh,
    
    ROUND(
        net_sales,
        2
    ) AS net_sales,
    
    ROUND(
        previous_month_sales,
        2
    ) AS previous_month_sales,
    
    ROUND(
        (
            net_sales - previous_month_sales
        )
        / NULLIF(previous_month_sales, 0)
        * 100,
        2
    ) AS mom_growth_pct
    
FROM growth

ORDER BY
	order_year,
    order_month;
    
-- ------------------------------------------------------------
-- 3. Year-over-Year Monthly Growth
-- ------------------------------------------------------------

WITH monthly_sales AS (

    SELECT
        YEAR(order_date) AS order_year,
        MONTH(order_date) AS order_month,

        SUM(realized_order_value) AS net_sales

    FROM vw_order_summary

    WHERE is_completed = 1
      AND order_date < '2018-05-01'

    GROUP BY
        YEAR(order_date),
        MONTH(order_date)
)

SELECT
    cy.order_year,
    cy.order_month,

    ROUND(
        cy.net_sales,
        2
    ) AS current_sales,

    ROUND(
        py.net_sales,
        2
    ) AS previous_year_sales,

    ROUND(
        (
            cy.net_sales - py.net_sales
        )
        / NULLIF(py.net_sales, 0)
        * 100,
        2
    ) AS yoy_growth_pct

FROM monthly_sales cy

INNER JOIN monthly_sales py
    ON cy.order_year = py.order_year + 1
   AND cy.order_month = py.order_month

ORDER BY
    cy.order_year,
    cy.order_month;


-- ------------------------------------------------------------
-- 4. Seasonality
-- Full years only: 2016 and 2017
-- ------------------------------------------------------------

WITH monthly AS (

    SELECT
        YEAR(order_date) AS order_year,
        MONTH(order_date) AS month_number,
        MONTHNAME(order_date) AS month_name,

        SUM(realized_order_value) AS monthly_sales,
        COUNT(*) AS monthly_orders,
        SUM(total_units) AS monthly_units

    FROM vw_order_summary

    WHERE is_completed = 1
      AND order_date >= '2016-01-01'
      AND order_date < '2018-01-01'

    GROUP BY
        YEAR(order_date),
        MONTH(order_date),
        MONTHNAME(order_date)
)

SELECT
    month_number,
    month_name,

    ROUND(
        AVG(monthly_sales),
        2
    ) AS avg_monthly_net_sales,

    ROUND(
        AVG(monthly_orders),
        2
    ) AS avg_monthly_orders,

    ROUND(
        AVG(monthly_units),
        2
    ) AS avg_monthly_units

FROM monthly

GROUP BY
    month_number,
    month_name

ORDER BY month_number;

-- ------------------------------------------------------------
-- 5. Monthly Category Sales
-- ------------------------------------------------------------
SELECT
	order_year,
    order_month,
    order_year_month,
    
    category_id,
    category_name,
    
    SUM(quantity) AS units_sold,
    
    ROUND(
        SUM(realized_net_sales),
        2
    ) AS net_sales
    
FROM vw_sales_enriched
WHERE is_completed = 1
	AND order_date < '2018-05-01'
    
GROUP BY
	order_year,
    order_month,
    order_year_month,
    category_id,
    category_name

ORDER BY
	order_year,
    order_month,
    category_name;
    
-- ------------------------------------------------------------
-- 6. Monthly Store Performance
-- ------------------------------------------------------------

SELECT
    order_year,
    order_month,
    order_year_month,

    store_id,
    store_name,

    COUNT(DISTINCT order_id) AS completed_orders,

    SUM(total_units) AS units_sold,

    ROUND(
        SUM(realized_order_value),
        2
    ) AS net_sales

FROM vw_order_summary

WHERE is_completed = 1
  AND order_date < '2018-05-01'

GROUP BY
    order_year,
    order_month,
    order_year_month,
    store_id,
    store_name

ORDER BY
    order_year,
    order_month,
    store_id;
    
-- ------------------------------------------------------------
-- 7. Full-Year Performance
-- ------------------------------------------------------------

WITH yearly_sales AS (
	
    SELECT
		order_year,
        
        SUM(realized_order_value) AS net_sales,
        SUM(total_units) AS units_sold,
        COUNT(*) AS completed_orders
	
    FROM vw_order_summary
    
    WHERE is_completed = 1
		AND order_year IN (2016, 2017)
        
	GROUP BY order_year
)

SELECT
	order_year,
    ROUND(net_sales, 2) AS net_sales,
    
    units_sold,
    completed_orders,
    
    ROUND(
		(
			net_sales
            - LAG(net_sales) OVER (
				ORDER BY order_year
			)
		)
        /
        NULLIF(
            LAG(net_sales) OVER (
                ORDER BY order_year
            ),
            0
        )
        * 100,
        2
    ) AS yoy_net_sales_growth_pct
    
FROM yearly_sales

ORDER BY order_year;

		