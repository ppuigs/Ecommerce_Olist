-- Nota media por días de retraso
SELECT
CASE 
WHEN order_delay_days <0  THEN '0. Con antelación'
WHEN order_delay_days = 0  THEN '00. A tiempo'
WHEN order_delay_days <= 1  THEN '1. 1 día'
WHEN order_delay_days <= 2  THEN '2. 2 días'
WHEN order_delay_days <= 3  THEN '3. 3 día'
WHEN order_delay_days <= 7  THEN '4. 4-7 días'
WHEN order_delay_days <= 14 THEN '5. 8-14 días'
ELSE '6. Más de 14 días' END AS retraso,
COUNT(*) AS pedidos,
ROUND(AVG(review_score), 2)AS nota_media
FROM pedidos_limpios
GROUP BY retraso
ORDER BY retraso;

SELECT customer_state, AVG(review_score) as avg_score from pedidos_limpios
GROUP BY customer_state
ORDER BY avg_score

WITH filtro_seller as (SELECT pl.order_id, order_prep_days, order_carried_days, order_delay_days, review_score from pedidos_limpios pl
LEFT JOIN items_entregados ie ON pl.order_id=ie.order_id
GROUP BY pl.order_id
HAVING COUNT(DISTINCT seller_id)=1)
SELECT seller_id, AVG(order_prep_days), AVG(order_carried_days), AVG(order_delay_days), AVG(review_score) from filtro_seller 
GROUP BY seller_id

WITH un_seller AS (
    SELECT order_id, ANY_VALUE(seller_id) AS seller_id
    FROM items_entregados
    GROUP BY order_id
    HAVING COUNT(DISTINCT seller_id) = 1
),
productos_seller AS (
    SELECT seller_id, COUNT(DISTINCT product_id) AS productos_distintos
    FROM items_entregados
    GROUP BY seller_id
)
SELECT
    ps.productos_distintos,
    us.seller_id,
    COUNT(*) AS pedidos,
    ROUND(AVG(pl.order_prep_days), 1) AS prep_media,
    COUNT(*) FILTER (WHERE pl.order_prep_days > 30) AS pedidos_prep_30d,
    ROUND(AVG(pl.order_carried_days), 1) AS transporte_medio,
    ROUND(100.0 * COUNT(*) FILTER (WHERE pl.order_delay_days > 0) / COUNT(*), 1) AS pct_tarde,
    ROUND(AVG(pl.review_score), 2) AS nota_media
FROM un_seller us
JOIN pedidos_limpios pl  ON us.order_id = pl.order_id
JOIN productos_seller ps ON us.seller_id = ps.seller_id
GROUP BY us.seller_id, ps.productos_distintos
HAVING COUNT(*) >= 30
ORDER BY nota_media
LIMIT 50;