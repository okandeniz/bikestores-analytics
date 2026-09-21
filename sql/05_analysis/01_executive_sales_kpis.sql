USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Business Analysis - 01 Executive Sales KPIs
-- ============================================================


-- ------------------------------------------------------------
-- 1. Executive KPI Summary
-- Completed orders only for realized sales metrics
-- ------------------------------------------------------------

SELECT * FROM vw_order_summary LIMIT 10;

SELECT
	ROUND(
		SUM(realized_order_value),
        2
	) AS net_sales,
    
    SUM(
		CASE
			WHEN is_completed = 1 THEN 1
            ELSE 0
		END
	) AS completed_orders,
    
    SUM(
        CASE
            WHEN is_completed = 1 THEN total_units
            ELSE 0
        END
    ) AS units_sold,
    
    COUNT(
        DISTINCT CASE
            WHEN is_completed = 1 THEN customer_id
        END
    ) AS active_customers,
    
    ROUND(
        SUM(realized_order_value)
        /
        NULLIF(
            SUM(
                CASE
                    WHEN is_completed = 1 THEN 1
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS average_order_value,
    
    ROUND(
        SUM(
            CASE
                WHEN is_completed = 1
                THEN discount_amount
                ELSE 0
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN is_completed = 1
                    THEN gross_order_value
                    ELSE 0
                END
            ),
            0
        ) * 100,
        2
    ) AS avg_effective_discount_pct
    
FROM vw_order_summary;

-- ------------------------------------------------------------
-- 2. Order Status Overview
-- ------------------------------------------------------------

SELECT
	order_status,
    order_status_name,
    COUNT(*) AS total_orders,
    
    ROUND(
		COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
	) AS order_share_pct

FROM vw_order_summary
GROUP BY
    order_status,
    order_status_name

ORDER BY order_status;

-- ------------------------------------------------------------
-- 3. Completion Rate
-- ------------------------------------------------------------

SELECT
	COUNT(*) AS total_orders,
    
    SUM(is_completed) AS completed_orders,
    
    ROUND(
		SUM(is_completed) * 100.0
        / COUNT(*),
        2
	) AS completion_rate_pct
    
FROM vw_order_summary;


-- ------------------------------------------------------------
-- 4. Yearly Sales Performance
-- ------------------------------------------------------------

SELECT

	order_year,
    
    ROUND(
		SUM(realized_order_value),
        2
    ) AS net_sales,
    
    SUM(is_completed) AS completed_orders,
    
    SUM(
        CASE
            WHEN is_completed = 1
            THEN total_units
            ELSE 0
        END
    ) AS units_sold,
    
    COUNT(
        DISTINCT CASE
            WHEN is_completed = 1
            THEN customer_id
        END
    ) AS active_customers,
    
    ROUND(
        SUM(realized_order_value)
        / NULLIF(SUM(is_completed), 0),
        2
    ) AS average_order_value

FROM vw_order_summary

GROUP BY order_year

ORDER BY order_year;


-- ------------------------------------------------------------
-- 5. Monthly Sales Trend
-- ------------------------------------------------------------

SELECT
    order_year,
    order_month,
    order_month_name,
    order_year_month,

    ROUND(
        SUM(realized_order_value),
        2
    ) AS net_sales,

    SUM(is_completed) AS completed_orders,

    SUM(
        CASE
            WHEN is_completed = 1
            THEN total_units
            ELSE 0
        END
    ) AS units_sold,

    ROUND(
        SUM(realized_order_value)
        / NULLIF(SUM(is_completed), 0),
        2
    ) AS average_order_value

FROM vw_order_summary

GROUP BY
    order_year,
    order_month,
    order_month_name,
    order_year_month

ORDER BY
    order_year,
    order_month;
    
-- ------------------------------------------------------------
-- 6. Shipping Performance
-- Completed / shipped orders only
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS shipped_orders,

    SUM(is_late) AS late_orders,

    COUNT(*) - SUM(is_late) AS on_time_orders,

    ROUND(
        SUM(is_late) * 100.0
        / COUNT(*),
        2
    ) AS late_shipment_rate_pct,

    ROUND(
        AVG(shipping_days),
        2
    ) AS avg_shipping_days,

    ROUND(
        AVG(delay_days),
        2
    ) AS avg_delay_days

FROM vw_order_summary

WHERE shipped_date IS NOT NULL;

-- ------------------------------------------------------------
-- 7. Late Orders Only
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS late_orders,

    ROUND(
        AVG(delay_days),
        2
    ) AS avg_late_days,

    MAX(delay_days) AS max_late_days

FROM vw_order_summary

WHERE is_late = 1;

-- ------------------------------------------------------------
-- 8. Gross Sales vs Discount vs Net Sales
-- Completed orders only
-- ------------------------------------------------------------

SELECT
    ROUND(
        SUM(gross_order_value),
        2
    ) AS gross_sales,

    ROUND(
        SUM(discount_amount),
        2
    ) AS discount_amount,

    ROUND(
        SUM(realized_order_value),
        2
    ) AS net_sales,

    ROUND(
        SUM(discount_amount)
        / NULLIF(SUM(gross_order_value), 0)
        * 100,
        2
    ) AS discount_impact_pct

FROM vw_order_summary

WHERE is_completed = 1;

-- ------------------------------------------------------------
-- 9. Customer completed-order frequency
-- Important for future RFM analysis
-- ------------------------------------------------------------

WITH customer_orders AS (

    SELECT
        customer_id,
        COUNT(*) AS completed_order_count

    FROM vw_order_summary

    WHERE is_completed = 1

    GROUP BY customer_id

)

SELECT
    completed_order_count,
    COUNT(*) AS customer_count

FROM customer_orders

GROUP BY completed_order_count

ORDER BY completed_order_count;

-- ------------------------------------------------------------
-- 10. Customer frequency range
-- ------------------------------------------------------------

SELECT
    MIN(completed_order_count) AS min_orders,
    MAX(completed_order_count) AS max_orders,
    AVG(completed_order_count) AS avg_orders

FROM (

    SELECT
        customer_id,
        COUNT(*) AS completed_order_count

    FROM vw_order_summary

    WHERE is_completed = 1

    GROUP BY customer_id

) customer_orders;

