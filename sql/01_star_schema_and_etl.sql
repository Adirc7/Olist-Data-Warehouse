select
	cast(price as decimal(10,2)) as final_price,
	cast(freight_value as decimal(10,2)) as final_freight
from stg_order_items;

select * from dbo.products;
select * from dbo.sellers;
select * from dbo.stg_customers;
select * from dbo.stg_geolocation;
select * from dbo.stg_order_items;
select * from dbo.stg_order_payments;
select * from dbo.stg_order_reviews;
select * from dbo.stg_orders;
select * from dbo.stg_product_category_name_translation;

create table dim_customer (
	customer_key int identity(1,1) primary key,
	customer_id nvarchar(255),
	customer_unique_id nvarchar(255),
	customer_zip_code_prefix int,
	customer_city nvarchar(255),
	customer_state nvarchar(50)
);

create table dim_seller(
	seller_key int identity(1,1) primary key,
	seller_id nvarchar(255),
	seller_zip_code_prefix INT,
    seller_city NVARCHAR(255),
    seller_state NVARCHAR(50)
);

CREATE TABLE dim_product (
    product_key INT IDENTITY(1,1) PRIMARY KEY,
    product_id NVARCHAR(255), -- Natural Business Key
    product_category_english NVARCHAR(255),
    product_weight_g DECIMAL(10,2),
    product_length_cm DECIMAL(10,2),
    product_height_cm DECIMAL(10,2),
    product_width_cm DECIMAL(10,2)
);

CREATE TABLE dim_date (
    date_key INT PRIMARY KEY, -- Smart Surrogate Key (YYYYMMDD)
    full_date DATE,
    year INT,
    quarter INT,
    month INT,
    day_of_week NVARCHAR(50)
);

-- Create Fact Table
CREATE TABLE fact_order_items (
    fact_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id NVARCHAR(255),
    order_item_id INT,
    
    -- Surrogate Foreign Keys
    customer_key INT,
    seller_key INT,
    product_key INT,
    order_purchase_date_key INT,
    
    -- Measures
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2),
    delivery_delay_days INT,
    
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (seller_key) REFERENCES dim_seller(seller_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (order_purchase_date_key) REFERENCES dim_date(date_key)
);

INSERT INTO dim_customer (customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state)
SELECT DISTINCT 
    customer_id, 
    customer_unique_id, 
    TRY_CAST(customer_zip_code_prefix AS INT), 
    UPPER(TRIM(customer_city)), 
    UPPER(TRIM(customer_state))
FROM stg_customers
WHERE customer_id IS NOT NULL;

select * from dim_customer;

INSERT INTO dim_seller (seller_id, seller_zip_code_prefix, seller_city, seller_state)
SELECT DISTINCT 
    seller_id, 
    TRY_CAST(seller_zip_code_prefix AS INT), 
    UPPER(TRIM(seller_city)), 
    UPPER(TRIM(seller_state))
FROM dbo.sellers
WHERE seller_id IS NOT NULL;
    
select * from dbo.sellers;

INSERT INTO dim_product (product_id, product_category_english, product_weight_g, product_length_cm, product_height_cm, product_width_cm)
SELECT DISTINCT 
    p.product_id,
    COALESCE(t.column2, 'UNKNOWN'),
    TRY_CAST(p.product_weight_g AS DECIMAL(10,2)),
    TRY_CAST(p.product_length_cm AS DECIMAL(10,2)),
    TRY_CAST(p.product_height_cm AS DECIMAL(10,2)),
    TRY_CAST(p.product_width_cm AS DECIMAL(10,2))
FROM dbo.products p
LEFT JOIN dbo.stg_product_category_name_translation t ON p.product_category_name = t.column1
WHERE p.product_id IS NOT NULL;


select * from dbo.stg_product_category_name_translation;
select * from dim_product;

INSERT INTO dim_date (date_key, full_date, year, quarter, month, day_of_week)
SELECT DISTINCT 
    CAST(FORMAT(TRY_CAST(order_purchase_timestamp AS DATE), 'yyyyMMdd') AS INT),
    TRY_CAST(order_purchase_timestamp AS DATE),
    DATEPART(YEAR, TRY_CAST(order_purchase_timestamp AS DATE)),
    DATEPART(QUARTER, TRY_CAST(order_purchase_timestamp AS DATE)),
    DATEPART(MONTH, TRY_CAST(order_purchase_timestamp AS DATE)),
    DATENAME(WEEKDAY, TRY_CAST(order_purchase_timestamp AS DATE))
FROM stg_orders
WHERE TRY_CAST(order_purchase_timestamp AS DATE) IS NOT NULL;

select * from dim_date;

INSERT INTO fact_order_items (
    order_id, order_item_id, customer_key, seller_key, product_key, 
    order_purchase_date_key, price, freight_value, delivery_delay_days
)
SELECT 
    i.order_id,
    TRY_CAST(i.order_item_id AS INT),
    dc.customer_key, -- Retrieving the surrogate key
    ds.seller_key,   -- Retrieving the surrogate key
    dp.product_key,  -- Retrieving the surrogate key
    CAST(FORMAT(TRY_CAST(o.order_purchase_timestamp AS DATE), 'yyyyMMdd') AS INT),
    TRY_CAST(i.price AS DECIMAL(10,2)),
    TRY_CAST(i.freight_value AS DECIMAL(10,2)),
    DATEDIFF(DAY, TRY_CAST(o.order_estimated_delivery_date AS DATE), TRY_CAST(o.order_delivered_customer_date AS DATE))
FROM stg_order_items i
INNER JOIN stg_orders o 
    ON i.order_id = o.order_id
-- LEFT JOIN to dimension tables to lookup surrogate keys based on natural keys
LEFT JOIN dim_customer dc 
    ON o.customer_id = dc.customer_id
LEFT JOIN dim_seller ds 
    ON i.seller_id = ds.seller_id
LEFT JOIN dim_product dp 
    ON i.product_id = dp.product_id
WHERE o.order_status = 'delivered'
  AND TRY_CAST(i.order_item_id AS INT) IS NOT NULL;


select * from fact_order_items;




