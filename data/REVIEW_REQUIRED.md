# Revisión mínima antes de abrir ventas

La importación de los archivos entregados generó 455 productos (337 de venta y
118 insumos) y 537 líneas de receta normalizadas. Dos registros no se asociaron
de forma automática:

- `.` — registro vacío del origen; se excluye.
- `SHOT TEQUILA 30-30` — no existe con ese nombre en el catálogo de venta.

Para el segundo, Administración debe decidir si se vende como una variante de
`30-30 BLANCO`, `30-30 REPOSADO` u otro producto, antes de activarlo. No se le
asignó una receta por inferencia para evitar descontar una botella equivocada.

`products.csv` y `recipes.csv` son compatibilidad histórica. La carga oficial
usa `ev2-catalog.json`, producido por `build-ev2-source-data.mjs` desde los PDF
conservados en `source/`.
