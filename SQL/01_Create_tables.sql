SET file_search_path = 'C:/Users/jpuig/Proyectos/ecommerce';

CREATE TABLE orders    AS SELECT * FROM read_csv('olist_orders_dataset.csv');
CREATE TABLE customers    AS SELECT * FROM read_csv('olist_customers_dataset.csv');
CREATE TABLE geolocation  AS SELECT * FROM read_csv('olist_geolocation_dataset.csv');
CREATE TABLE order_items  AS SELECT * FROM read_csv('olist_order_items_dataset.csv');
CREATE TABLE payments     AS SELECT * FROM read_csv('olist_order_payments_dataset.csv');
CREATE TABLE reviews      AS SELECT * FROM read_csv('olist_order_reviews_dataset.csv');
CREATE TABLE products     AS SELECT * FROM read_csv('olist_products_dataset.csv');
CREATE TABLE sellers      AS SELECT * FROM read_csv('olist_sellers_dataset.csv');
CREATE TABLE category_translation AS SELECT * FROM read_csv('product_category_name_translation.csv');