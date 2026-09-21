USE BikeStores;

SELECT 
    ord.order_id,
    CONCAT(cus.first_name, ' ', cus.last_name) AS customer,
    cus.city,
    cus.state,
    ord.order_date,

    SUM(ite.quantity) AS total_units,

    ROUND(
        SUM(ite.quantity * ite.list_price),
        2
    ) AS gross_revenue,

    ROUND(
        SUM(ite.quantity * ite.list_price * ite.discount),
        2
    ) AS discount_amount,

    ROUND(
        SUM(ite.quantity * ite.list_price * (1 - ite.discount)),
        2
    ) AS net_revenue,

    pro.product_name,
    cat.category_name,
    sto.store_name,

    CONCAT(
        sta.first_name,
        ' ',
        sta.last_name
    ) AS sales_rep

FROM orders AS ord

JOIN customers AS cus
    ON ord.customer_id = cus.customer_id

JOIN order_items AS ite
    ON ord.order_id = ite.order_id

JOIN products AS pro
    ON ite.product_id = pro.product_id

JOIN categories AS cat
    ON pro.category_id = cat.category_id

JOIN stores AS sto
    ON ord.store_id = sto.store_id

JOIN staffs AS sta
    ON ord.staff_id = sta.staff_id

GROUP BY 
    ord.order_id,
    CONCAT(cus.first_name, ' ', cus.last_name),
    cus.city,
    cus.state,
    ord.order_date,
    pro.product_name,
    cat.category_name,
    sto.store_name,
    CONCAT(sta.first_name, ' ', sta.last_name);