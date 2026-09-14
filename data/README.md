# Datos operativos de EV2

Estos archivos son plantillas de importación. Complétalos con el catálogo, el recetario y el plano finales antes de abrir ventas.

- `products.csv`: un producto vendible o insumo por fila. Para B2/B3 use un solo SKU y el mayor de ambos precios.
- `recipes.csv`: cada ingrediente de cada bebida preparada. Las cantidades están en mililitros; use `1 oz = 30 ml`.
- `zones.csv`: cada mesa, zona VIP o punto de entrega; `bar_key` determina a qué barra se enruta un pedido.

El sistema no debe arrancar ventas con precios, recetas o mapa de ejemplo. Los PDFs finales no están incluidos en este directorio: guárdelos en un repositorio privado o conviértalos a estas plantillas para una importación verificable.
