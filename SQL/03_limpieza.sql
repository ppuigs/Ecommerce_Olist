-- Info de los tiempos de  preparación, transporte y retraso
-- SE LIMPIAN DATOS DE pedidos_entregados. 
-- 			Solo la review más actual (en los 547 casos que  hay más de una review por order)
--			Orders que tenenmos la fecha de entrega
--			Los tiempos de preparacion y transporte negativos han sido reemplazados por NULL
CREATE OR REPLACE TABLE pedidos_limpios AS
WITH seller_pedido AS (
    -- Estado del seller de cada pedido (solo pedidos con un único seller;
    -- los 1.275 con varios quedan con seller_state NULL)
    SELECT oi.order_id, ANY_VALUE(s.seller_state) AS seller_state
    FROM order_items oi
    JOIN sellers s ON oi.seller_id = s.seller_id
    GROUP BY oi.order_id
    HAVING COUNT(DISTINCT oi.seller_id) = 1),
estados (uf, nombre) AS (
    -- Nombres completos de los estados, como los reconoce el Shape Map de Power BI
    VALUES
        ('AC', 'Acre'),              ('AL', 'Alagoas'),            ('AP', 'Amapa'),
        ('AM', 'Amazonas'),          ('BA', 'Bahia'),              ('CE', 'Ceara'),
        ('DF', 'Distrito Federal'),  ('ES', 'Espirito Santo'),     ('GO', 'Goias'),
        ('MA', 'Maranhao'),          ('MT', 'Mato Grosso'),        ('MS', 'Mato Grosso do Sul'),
        ('MG', 'Minas Gerais'),      ('PA', 'Para'),               ('PB', 'Paraiba'),
        ('PR', 'Parana'),            ('PE', 'Pernambuco'),         ('PI', 'Piaui'),
        ('RJ', 'Rio de Janeiro'),    ('RN', 'Rio Grande do Norte'),('RS', 'Rio Grande do Sul'),
        ('RO', 'Rondonia'),          ('RR', 'Roraima'),            ('SC', 'Santa Catarina'),
        ('SP', 'Sao Paulo'),         ('SE', 'Sergipe'),            ('TO', 'Tocantins')
)
SELECT
    pe.order_id,
    pe.customer_id, c.customer_city, c.customer_state, e.nombre AS customer_state_name,
    sp.seller_state,
    CASE
        WHEN sp.seller_state IS NULL             THEN NULL
        WHEN sp.seller_state = c.customer_state  THEN 'Mismo estado'
        ELSE                                          'Otro estado'
    END AS distancia,
    pe.order_purchase_timestamp,
    pe.order_approved_at,
    pe.order_delivered_carrier_date,
    pe.order_delivered_customer_date,
    pe.order_estimated_delivery_date,
    CASE WHEN pe.order_prep_days >= 0    THEN pe.order_prep_days END    AS order_prep_days,
    CASE WHEN pe.order_carried_days >= 0 THEN pe.order_carried_days END AS order_carried_days,
    pe.order_delay_days,
    -- Tramo de retraso (texto para los gráficos) y su orden (para ordenarlos en Power BI)
    CASE
    WHEN order_delay_days < 0   THEN 'Con antelación'
    WHEN order_delay_days = 0   THEN 'El mismo día'
    WHEN order_delay_days = 1   THEN '1 día'
    WHEN order_delay_days = 2   THEN '2 días'
    WHEN order_delay_days = 3   THEN '3 días'
    WHEN order_delay_days <= 7  THEN '4-7 días'
    WHEN order_delay_days <= 14 THEN '8-14 días'
    ELSE                             'Más de 14 días'
END AS tramo_retraso,
    CASE
    WHEN order_delay_days < 0   THEN 0
    WHEN order_delay_days = 0   THEN 1
    WHEN order_delay_days = 1   THEN 2
    WHEN order_delay_days = 2   THEN 3
    WHEN order_delay_days = 3   THEN 4
    WHEN order_delay_days <= 7  THEN 5
    WHEN order_delay_days <= 14 THEN 6
    ELSE                             7
END AS tramo_retraso_orden,
    -- Días desde la compra hasta la entrega (aunque llegue a tiempo, esperar mucho baja la nota)
    CASE
    WHEN date_diff('day', pe.order_purchase_timestamp, pe.order_delivered_customer_date) <= 7  THEN '0-7 días'
    WHEN date_diff('day', pe.order_purchase_timestamp, pe.order_delivered_customer_date) <= 14 THEN '8-14 días'
    WHEN date_diff('day', pe.order_purchase_timestamp, pe.order_delivered_customer_date) <= 21 THEN '15-21 días'
    ELSE                                                                                       '22 días o más'
END AS tramo_dias_entrega,
    CASE
    WHEN date_diff('day', pe.order_purchase_timestamp, pe.order_delivered_customer_date) <= 7  THEN 1
    WHEN date_diff('day', pe.order_purchase_timestamp, pe.order_delivered_customer_date) <= 14 THEN 2
    WHEN date_diff('day', pe.order_purchase_timestamp, pe.order_delivered_customer_date) <= 21 THEN 3
    ELSE                                                                                       4
END AS tramo_dias_entrega_orden,
    r.review_score,
    r.review_comment_message,
    -- Motivo de la queja en reviews de 1-2 estrellas, buscando palabras clave (portugués, con y sin acentos).
    -- Un comentario puede tener varios motivos: se queda el primero que coincide, en este orden.
    -- regexp_matches busca el texto en cualquier parte del comentario. (Con SIMILAR TO '.*x.*' fallaban
    -- los 812 comentarios con saltos de línea, porque el '.' no incluye el salto de línea.)
    CASE
    WHEN review_score > 2 OR review_comment_message IS NULL THEN NULL
    -- Envío: no llegó, sigue esperando, o llegó solo una parte del pedido
    WHEN regexp_matches(lower(review_comment_message), 'não recebi|nao recebi|não chegou|nao chegou|ainda não|ainda nao|aguardando|faltando|faltou|falta |incomplet|só veio|so veio|veio apenas|veio somente|apenas (um|1|uma)|somente (um|1|uma)|só (um|1|uma)|so (um|1|uma)|parcial') THEN 'No llegó / incompleto'
    -- Vendedor: envió otro producto
    WHEN regexp_matches(lower(review_comment_message), 'errad|trocad|outro produto|não corresponde|nao corresponde|não é o que|nao e o que|não foi o produto|nao foi o produto') THEN 'Producto equivocado'
    -- Vendedor: embalaje
    WHEN regexp_matches(lower(review_comment_message), 'quebrad|danificad|amassad|avariad|rachad|riscad|estragad') THEN 'Dañado'
    -- Vendedor: el producto no es como en la foto o la descripción
    WHEN regexp_matches(lower(review_comment_message), 'foto|anúncio|anuncio|descrição|descricao|diferente|falsific|original|menor do que|maior do que') THEN 'No es como el anuncio'
    -- Producto: calidad
    WHEN regexp_matches(lower(review_comment_message), 'qualidade|defeito|não funciona|nao funciona|parou de funcionar|frágil|fragil') THEN 'Calidad / defecto'
    -- Vendedor: posventa (devoluciones, cambios, no contestan, factura)
    WHEN regexp_matches(lower(review_comment_message), 'devolu|troca|estorno|reembols|contato|resposta|retorno|atendimento|nota fiscal|cancel') THEN 'Atención / devolución'
    ELSE 'Otros'
END AS motivo_queja,
CASE motivo_queja
    WHEN 'Calidad / defecto'     THEN 'Producto'
    WHEN 'No llegó / incompleto' THEN 'Envío'
    WHEN 'Otros'                 THEN 'Sin clasificar'
    WHEN NULL                    THEN NULL
    ELSE                              'Vendedor'
END AS responsable_queja,
    r.review_creation_date,
    r.review_answer_timestamp
FROM pedidos_entregados pe
LEFT JOIN reviews r ON pe.order_id = r.order_id
LEFT JOIN customers c ON pe.customer_id=c.customer_id
LEFT JOIN estados e        ON c.customer_state = e.uf
LEFT JOIN seller_pedido sp ON pe.order_id = sp.order_id
WHERE pe.order_delivered_customer_date IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY pe.order_id
                           ORDER BY r.review_creation_date DESC, r.review_answer_timestamp DESC) = 1;

-- items con el precio pero solo los de la tabla de datos limpia
CREATE OR REPLACE TABLE items_entregados AS
SELECT * FROM order_items
WHERE order_id IN (SELECT order_id FROM pedidos_limpios);


-- productos: categoría en inglés (sin categoría → 'unknown')
CREATE OR REPLACE TABLE productos AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category
FROM products p
LEFT JOIN category_translation t ON p.product_category_name = t.product_category_name;

SELECT COUNT(*) FROM pedidos_limpios;

-- vendedores: una fila por seller, con su ubicación
CREATE OR REPLACE TABLE vendedores AS
SELECT seller_id, seller_city, seller_state
FROM sellers;


  


