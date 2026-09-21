USE bikestores;

-- ============================================================
-- BikeStores Analytics
-- Data Quality - 05 Business Rule Checks
-- ============================================================


-- ------------------------------------------------------------
-- 1. order_items - quantity must be positive
-- ------------------------------------------------------------

SELECT
	COUNT(*) AS invalid_quantity_count
FROM order_items
WHERE quantity  <= 0;

-- ------------------------------------------------------------
-- 2. order_items - list_price must be positive
-- ------------------------------------------------------------

SELECT
	COUNT(*) AS invalid_list_price_count
FROM order_items
WHERE list_price <=0;

-- ------------------------------------------------------------
-- 3. order_items - discount must be between 0 and 1
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS invalid_discount_count
FROM order_items
WHERE discount < 0
   OR discount > 1;
   
-- ------------------------------------------------------------
-- 4. products - list_price must be positive
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS invalid_product_price_count
FROM products
WHERE list_price <= 0;


-- ------------------------------------------------------------
-- 5. products - model year sanity check
-- ------------------------------------------------------------

SELECT
    MIN(model_year) AS min_model_year,
    MAX(model_year) AS max_model_year
FROM products;


-- ------------------------------------------------------------
-- 6. stocks - quantity cannot be negative
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS negative_stock_count
FROM stocks
WHERE quantity < 0;

-- ------------------------------------------------------------
-- 7. orders - required date cannot be before order date
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS invalid_required_date_count
FROM orders
WHERE required_date < order_date;

-- ------------------------------------------------------------
-- 8. orders - shipped date cannot be before order date
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS invalid_shipped_date_count
FROM orders
WHERE shipped_date IS NOT NULL
  AND shipped_date < order_date;
  
-- ------------------------------------------------------------
-- 9. orders - late shipments
-- Not a data error, only a business condition
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS late_shipment_count
FROM orders
WHERE shipped_date IS NOT NULL
  AND shipped_date > required_date;
  
-- ------------------------------------------------------------
-- 10. orders - shipped order status consistency
-- ------------------------------------------------------------

SELECT
    order_status,
    COUNT(*) AS total_orders,
    SUM(shipped_date IS NULL) AS null_shipped_date,
    SUM(shipped_date IS NOT NULL) AS shipped_date_present
FROM orders
GROUP BY order_status
ORDER BY order_status;

-- ------------------------------------------------------------
-- 11. stocks - quantity distribution
-- ------------------------------------------------------------

SELECT
    MIN(quantity) AS min_stock,
    MAX(quantity) AS max_stock,
    AVG(quantity) AS avg_stock
FROM stocks;

-- ------------------------------------------------------------
-- 12. order_items - discount distribution
-- ------------------------------------------------------------

SELECT
    discount,
    COUNT(*) AS item_count
FROM order_items
GROUP BY discount
ORDER BY discount;