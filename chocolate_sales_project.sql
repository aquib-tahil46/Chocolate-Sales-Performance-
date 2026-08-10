-- ============================================================
-- Chocolate Sales Performance Dashboard
-- SQL Pipeline: Schema, Load, Cleaning, Star Schema, Analytics
-- Author: Aquib Tahil
-- Stack: MySQL 8 -> Power BI (Import mode)
-- ============================================================


-- ============================================================
-- 1. SCHEMA
-- ============================================================
CREATE DATABASE IF NOT EXISTS chocolate_sales;
USE chocolate_sales;

CREATE TABLE stores (
  store_id     VARCHAR(10) PRIMARY KEY,
  store_name   VARCHAR(100),
  city         VARCHAR(50),
  country      VARCHAR(50),
  store_type   VARCHAR(30)
);

CREATE TABLE products (
  product_id     VARCHAR(10) PRIMARY KEY,
  product_name   VARCHAR(100),
  brand          VARCHAR(50),
  category       VARCHAR(50),
  cocoa_percent  INT,
  weight_g       INT
);

CREATE TABLE customers (
  customer_id      VARCHAR(10) PRIMARY KEY,
  age              INT,
  gender           VARCHAR(10),
  loyalty_member   TINYINT,
  join_date        VARCHAR(20)
);

CREATE TABLE calendar_raw (
  date_txt      VARCHAR(20),
  year          INT,
  month         INT,
  day           INT,
  week          INT,
  day_of_week   INT
);

CREATE TABLE sales (
  order_id     VARCHAR(15) PRIMARY KEY,
  order_date   VARCHAR(20),
  product_id   VARCHAR(10),
  store_id     VARCHAR(10),
  customer_id  VARCHAR(10),
  quantity     INT,
  unit_price   DECIMAL(10,2),
  discount     DECIMAL(4,2),
  revenue      DECIMAL(12,2),
  cost         DECIMAL(12,2),
  profit       DECIMAL(12,2)
);


-- ============================================================
-- 2. LOAD DATA
-- Update file paths to your local environment before running.
-- Requires local_infile enabled on both client and server:
--   SET GLOBAL local_infile = 1;
-- (or use MySQL Workbench's Table Data Import Wizard instead)
-- ============================================================
SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE '/path/to/stores.csv'
  INTO TABLE stores FIELDS TERMINATED BY ',' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE '/path/to/products.csv'
  INTO TABLE products FIELDS TERMINATED BY ',' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE '/path/to/customers.csv'
  INTO TABLE customers FIELDS TERMINATED BY ',' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE '/path/to/calendar.csv'
  INTO TABLE calendar_raw FIELDS TERMINATED BY ',' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE '/path/to/sales.csv'
  INTO TABLE sales FIELDS TERMINATED BY ',' IGNORE 1 ROWS;


-- ============================================================
-- 3. DATE CLEANING
-- Source dates arrive as text in YYYY-MM-DD format.
-- ============================================================
ALTER TABLE sales        ADD COLUMN order_date_clean DATE;
ALTER TABLE customers    ADD COLUMN join_date_clean   DATE;
ALTER TABLE calendar_raw ADD COLUMN date_clean        DATE;

SET SQL_SAFE_UPDATES = 0;

UPDATE sales        SET order_date_clean = STR_TO_DATE(order_date, '%Y-%m-%d');
UPDATE customers    SET join_date_clean  = STR_TO_DATE(join_date, '%Y-%m-%d');
UPDATE calendar_raw SET date_clean       = STR_TO_DATE(date_txt, '%Y-%m-%d');


-- ============================================================
-- 4. DATA INTEGRITY CHECKS
-- Each should return 0.
-- ============================================================
SELECT COUNT(*) AS null_dates
FROM sales
WHERE order_date_clean IS NULL;

SELECT COUNT(*) AS orphan_products
FROM sales s
LEFT JOIN products p ON s.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS orphan_stores
FROM sales s
LEFT JOIN stores st ON s.store_id = st.store_id
WHERE st.store_id IS NULL;

-- Duplicate order_id check
SELECT order_id, COUNT(*) AS c
FROM sales
GROUP BY order_id
HAVING c > 1;

-- Known data-quality finding (documented, not silently hidden):
-- 9,764 rows (~1% of sales) reference two invalid product codes
-- (P0000: 4,895 rows; P0201: 4,869 rows) not present in `products`.
-- Excluded from product-level visuals in the Power BI report;
-- flagged here for source-system follow-up.
SELECT product_id, COUNT(*) AS cnt
FROM sales
WHERE product_id NOT IN (SELECT product_id FROM products)
GROUP BY product_id
ORDER BY cnt DESC;


-- ============================================================
-- 5. STAR SCHEMA VIEWS (Power BI data source)
-- ============================================================
CREATE OR REPLACE VIEW dim_calendar AS
SELECT date_clean AS date, year, month, day, week, day_of_week
FROM calendar_raw
WHERE date_clean IS NOT NULL;

CREATE OR REPLACE VIEW fact_sales AS
SELECT
  s.order_id,
  s.order_date_clean AS order_date,
  s.product_id,
  s.store_id,
  s.customer_id,
  s.quantity,
  s.unit_price,
  s.discount,
  s.revenue,
  s.cost,
  s.profit
FROM sales s
WHERE s.order_date_clean IS NOT NULL;


-- ============================================================
-- 6. KPI VALIDATION
-- Cross-check totals against Power BI KPI cards.
-- ============================================================
SELECT ROUND(SUM(revenue) / 1000000, 2) AS total_revenue_millions FROM fact_sales;
SELECT SUM(quantity)                    AS total_boxes            FROM fact_sales;
SELECT COUNT(DISTINCT order_id)         AS total_shipments        FROM fact_sales;


-- ============================================================
-- 7. ANALYTICAL QUERIES
-- Each mirrors one dashboard visual.
-- ============================================================

-- Monthly revenue trend (line chart)
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, SUM(revenue) AS monthly_revenue
FROM fact_sales
GROUP BY month
ORDER BY month;

-- Monthly boxes shipped (area chart)
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, SUM(quantity) AS monthly_boxes
FROM fact_sales
GROUP BY month
ORDER BY month;

-- Monthly shipment count trend (area chart)
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, COUNT(DISTINCT order_id) AS shipments
FROM fact_sales
GROUP BY month
ORDER BY month;

-- Revenue by country (donut chart)
SELECT
  st.country,
  SUM(f.revenue) AS revenue,
  ROUND(100 * SUM(f.revenue) / SUM(SUM(f.revenue)) OVER (), 1) AS pct_of_total
FROM fact_sales f
JOIN stores st ON f.store_id = st.store_id
GROUP BY st.country
ORDER BY revenue DESC;

-- Top stores by revenue (table visual)
SELECT
  st.store_name,
  SUM(f.revenue) AS amount,
  SUM(f.quantity) AS boxes,
  COUNT(DISTINCT f.order_id) AS ships
FROM fact_sales f
JOIN stores st ON f.store_id = st.store_id
GROUP BY st.store_name
ORDER BY amount DESC
LIMIT 15;

-- Boxes shipped per product (bar chart)
SELECT p.product_name, SUM(f.quantity) AS boxes
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
GROUP BY p.product_name
ORDER BY boxes DESC
LIMIT 15;

-- Profit margin by category
SELECT
  p.category,
  ROUND(SUM(f.profit) / SUM(f.revenue) * 100, 2) AS profit_margin_pct
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY profit_margin_pct DESC;

-- Loyalty vs non-loyalty revenue contribution
SELECT
  c.loyalty_member,
  SUM(f.revenue) AS revenue,
  COUNT(DISTINCT f.customer_id) AS customers
FROM fact_sales f
JOIN customers c ON f.customer_id = c.customer_id
GROUP BY c.loyalty_member;
