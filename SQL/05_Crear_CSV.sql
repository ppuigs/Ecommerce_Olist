COPY pedidos_limpios  TO 'C:/Users/jpuig/Proyectos/ecommerce/datos/pedidos_limpios.csv'  (HEADER, DELIMITER ',');
COPY items_entregados TO 'C:/Users/jpuig/Proyectos/ecommerce/datos/items_entregados.csv' (HEADER, DELIMITER ',');
COPY productos        TO 'C:/Users/jpuig/Proyectos/ecommerce/datos/productos.csv'        (HEADER, DELIMITER ',');
COPY vendedores       TO 'C:/Users/jpuig/Proyectos/ecommerce/datos/vendedores.csv'        (HEADER, DELIMITER ',');