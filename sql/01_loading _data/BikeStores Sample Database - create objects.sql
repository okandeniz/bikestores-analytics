/*
--------------------------------------------------------------------
BikeStores - MySQL Version
Original SQL Server Database:
© 2017 sqlservertutorial.net
--------------------------------------------------------------------
*/

-- ============================================================
-- CREATE DATABASE
-- ============================================================

CREATE DATABASE IF NOT EXISTS BikeStores;

USE BikeStores;


-- ============================================================
-- PRODUCTION TABLES
-- ============================================================

-- Categories
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(255) NOT NULL
);


-- Brands
CREATE TABLE brands (
    brand_id INT AUTO_INCREMENT PRIMARY KEY,
    brand_name VARCHAR(255) NOT NULL
);


-- Products
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    brand_id INT NOT NULL,
    category_id INT NOT NULL,
    model_year SMALLINT NOT NULL,
    list_price DECIMAL(10, 2) NOT NULL,

    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id)
        REFERENCES categories(category_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_products_brand
        FOREIGN KEY (brand_id)
        REFERENCES brands(brand_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


-- ============================================================
-- SALES TABLES
-- ============================================================

-- Customers
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    phone VARCHAR(25),
    email VARCHAR(255) NOT NULL,
    street VARCHAR(255),
    city VARCHAR(50),
    state VARCHAR(25),
    zip_code VARCHAR(5)
);


-- Stores
CREATE TABLE stores (
    store_id INT AUTO_INCREMENT PRIMARY KEY,
    store_name VARCHAR(255) NOT NULL,
    phone VARCHAR(25),
    email VARCHAR(255),
    street VARCHAR(255),
    city VARCHAR(255),
    state VARCHAR(10),
    zip_code VARCHAR(5)
);


-- Staffs
CREATE TABLE staffs (
    staff_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(25),
    active TINYINT NOT NULL,
    store_id INT NOT NULL,
    manager_id INT,

    CONSTRAINT fk_staffs_store
        FOREIGN KEY (store_id)
        REFERENCES stores(store_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_staffs_manager
        FOREIGN KEY (manager_id)
        REFERENCES staffs(staff_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);


-- Orders
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    order_status TINYINT NOT NULL,

    -- Order status:
    -- 1 = Pending
    -- 2 = Processing
    -- 3 = Rejected
    -- 4 = Completed

    order_date DATE NOT NULL,
    required_date DATE NOT NULL,
    shipped_date DATE,
    store_id INT NOT NULL,
    staff_id INT NOT NULL,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_orders_store
        FOREIGN KEY (store_id)
        REFERENCES stores(store_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_orders_staff
        FOREIGN KEY (staff_id)
        REFERENCES staffs(staff_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);


-- Order Items
CREATE TABLE order_items (
    order_id INT NOT NULL,
    item_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    list_price DECIMAL(10, 2) NOT NULL,
    discount DECIMAL(4, 2) NOT NULL DEFAULT 0,

    PRIMARY KEY (order_id, item_id),

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


-- ============================================================
-- STOCK TABLE
-- ============================================================

CREATE TABLE stocks (
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT,

    PRIMARY KEY (store_id, product_id),

    CONSTRAINT fk_stocks_store
        FOREIGN KEY (store_id)
        REFERENCES stores(store_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_stocks_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);