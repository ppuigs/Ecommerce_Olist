CREATE OR REPLACE VIEW pedidos_entregados AS
SELECT
    order_id,
    customer_id,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    DATE_DIFF('day', order_approved_at, order_delivered_carrier_date)              AS order_prep_days,
    DATE_DIFF('day', order_delivered_carrier_date, order_delivered_customer_date)  AS order_carried_days,
    DATE_DIFF('day', order_estimated_delivery_date, order_delivered_customer_date) AS order_delay_days
FROM orders
WHERE order_status = 'delivered';

-- Duplicados en orders? - NO
SELECT order_id,  COUNT(*) AS n
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Duplicados en customers? - NO (el customer_unique_id es el customer real, está repetido)
SELECT customer_id,  COUNT(*) AS n
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Duplicados en customers? - NO 
SELECT seller_id,  COUNT(*) AS n
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- Duplicados en products? - NO 
SELECT product_id,  COUNT(*) AS n
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Duplicados en reviews? - NO. Pero las reviews pueden ser dobles para diferentes order_id
SELECT review_id, order_id,  COUNT(*) AS n
FROM reviews
GROUP BY review_id, order_id
HAVING COUNT(*) > 1;

-- Duplicados en payments? - NO, un order se puede pagar dividido, pero el payment_sequential lo hace único.
SELECT order_id, payment_sequential, COUNT(*) AS n
FROM payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;

-- Hay celdas vacías en los timings de orders?  
--total|errores_de_pedido|sin_compra|sin_transportista|sin_entrega|sin_estimacion|
-----+-----------------+----------+-----------------+-----------+--------------+
--99441|                0|       160|             1783|       2965|             0|
-- Siguiente, ver cuantos de estos no son orders en proceso
SELECT 
COUNT(*) AS total,
COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS errores_de_pedido,
COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS sin_compra,
COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS sin_transportista,
COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS sin_entrega,
COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) AS sin_estimacion
from orders

-- Visión general, hay preparacion o transportes negativos? Cuando llegan tarde y temprano?
--tota  |preparacion_negativos|transporte_negativos|llegan_antes|llegan_al_dia|sin_fecha_entrega|llegan_tarde|min(order_prep_days)|
--------+--------------------+--------------------+------------+-------------+-----------------+------------+--------------------+--
-- 96478|                 674|                  20|       88644|         1292|                8|        6534|                -171| 
--max(order_prep_days)|min(order_carried_days)|max(order_carried_days)|min(order_delay_days)|max(order_delay_days)|
--------------------+-----------------------+-----------------------+---------------------+---------------------+
--                126|                    -16|                    205|                 -147|                  188|

-- LOS DATOS MÁS RELEVANTES SON  LA CANTIDAD DE PAQUETES QUE SE PREPARAN ANTES DE HABER PAGADO EL PEDIDO (errores, aunque vamos a ver las reviews para 
--saber si son errores que vale la pena estudiar más en profundidad),
-- LA CANTIDAD DE PAQUETES QUE LLEGAN ANTES Y LOS QUE LLEGAN TARDE.

-- Se van a estudiar esos tres casos.
SELECT
    COUNT(*) AS total,
	COUNT(*) FILTER (WHERE order_prep_days < 0)    AS preparacion_negativos,
    COUNT(*) FILTER (WHERE order_carried_days < 0) AS transporte_negativos,
    COUNT(*) FILTER (WHERE order_delay_days < 0)   AS llegan_antes,
    COUNT(*) FILTER (WHERE order_delay_days = 0)   AS llegan_al_dia,
    COUNT(*) FILTER (WHERE order_delay_days IS NULL)   AS sin_fecha_entrega,
    COUNT(*) FILTER (WHERE order_delay_days > 0)   AS llegan_tarde,
    MIN(order_prep_days), MAX(order_prep_days),
    MIN(order_carried_days), MAX(order_carried_days),
    MIN(order_delay_days), MAX(order_delay_days)
FROM pedidos_entregados;

--Preparación negativa.
--errores|
-------+
--     38|

SELECT COUNT(*) FILTER (WHERE DATE_DIFF('day',pe.order_approved_at,pe.order_delivered_customer_date)<0) as errores from orders o
LEFT JOIN pedidos_entregados pe
ON pe.order_id=o.order_id

WHERE order_prep_days < 0

--PARTE IMPORTANTE: customer_delivery_date vs estimated_delivery_date

WITH reviews_filtro as (SELECT 
pe.order_id, 
pe.customer_id,
order_delay_days,
review_id, 
review_score, 
review_comment_message, 
review_creation_date, 
review_answer_timestamp, 
ROW_NUMBER()OVER(PARTITION BY pe.order_id ORDER BY review_creation_date DESC, review_answer_timestamp DESC) as rn
from pedidos_entregados pe
LEFT JOIN reviews
ON pe.order_id=reviews.order_id)
-- Pedidos por grupo con su avg review_score. 
--entrega          |pedidos|nota_media        |
-----------------+-------+------------------+
--1. Antes de plazo|  88644| 4.294000884724885|
--2. El mismo día  |   1292|        4.03359375|
--3. Con retraso   |   6534|2.2708039492242595|
--                 |      8|               4.5|
-- AL VER QUE HAY DIFERENCIA CLARA; SE GUARDA LA REVIEW_SCORE EN pedidos_entregados
SELECT
CASE
	WHEN order_delay_days < 0 THEN '1. Antes de plazo'
	WHEN order_delay_days = 0 THEN '2. El mismo día'
	WHEN order_delay_days > 0 THEN '3. Con retraso'
    END AS entrega,
COUNT(*) AS pedidos,
AVG(review_score) AS nota_media FROM reviews_filtro
WHERE rn = 1
GROUP BY entrega
ORDER BY entrega;

--pedidos entregados está bien hecho?
SELECT COUNT(*) from pedidos_entregados





