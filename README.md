# EV2 POS y App Web

Proyecto independiente para EV2 Clandestino. No usa ni modifica el proyecto existente de `ev2.system`.

## Qué funciona en esta base MVP

- Registro por correo/teléfono y contraseña; roles de cliente y personal.
- Eventos, mapa de zonas disponible/reservada, reservas con tolerancia de tres horas, productos y créditos incluidos.
- Accesos QR de un solo uso: validación de INE, denegación trazable y activación de reserva al primer acceso válido.
- Pedido con folio único: creación → cobro confirmado → barra de zona → listo → entregado. El POS permite efectivo y terminal (con referencia); la app cobra por Mercado Pago.
- Mercado Pago Checkout con importe calculado en servidor y webhook que consulta a Mercado Pago antes de liberar la reserva o pedido. Ningún navegador puede marcar un pago como aprobado.
- Cola bartender por hora de pago y cola de mesero por hora real de preparación.
- Inventario de almacén y ambas barras, con movimientos auditables y descuento automático de recetas por mililitros y unidades físicas (`1 oz = 30 ml`).
- Flirty: solo usuarios visibles, regalo pagado, aceptación/rechazo sin reembolso.
- Tipo de cambio administrable por evento, redondeado hacia abajo.

## Antes de producción

La base es funcional, pero se deben completar estos datos operativos antes de abrir ventas reales:

1. El catálogo, recetario y plano recibidos ya están incluidos en `data/source/`; el proceso `node data/build-ev2-source-data.mjs` genera datos normalizados. Tras levantar Docker, se carga con `docker compose exec api node data/import-catalog.js`. Conserva por producto el mayor precio de base/B2/B3.
2. Crear la primera cuenta de administrador directamente en PostgreSQL o mediante un script de alta protegido.
3. Para Mercado Pago, crea una aplicación de pruebas o producción y agrega `MP_ACCESS_TOKEN`, `API_BASE_URL=https://api.ev2.system` y `APP_BASE_URL=https://app.ev2.system` únicamente en `.env` del VPS. Configura en Mercado Pago la notificación `https://api.ev2.system/webhooks/mercadopago`. Las credenciales nunca van en el navegador ni en Git.
4. Configurar correo/SMS y los proveedores OAuth de Facebook/Instagram para inicio de sesión y recuperación de contraseña.
5. El plano autorizado de dos plantas se usa como base del mapa interactivo y se cargan las zonas VIP 13–18, 32–45 y 46–53. Administración puede editar los precios e inclusiones específicos de cada evento antes de publicarlo.
6. Revisa los dos registros que no se pudieron asociar con seguridad en [data/REVIEW_REQUIRED.md](data/REVIEW_REQUIRED.md). No se activa ninguna receta por aproximación.

## Despliegue en Ubuntu 24.04 / Hostinger

1. Crea el repositorio privado `ev2-pos-app-web` y sube esta carpeta. Sigue `GITHUB_UPLOAD.md`; no subas `.env`.
2. En el VPS instala Docker Engine, Docker Compose plugin, Nginx y Certbot.
3. Clona el repo en, por ejemplo, `/opt/ev2-pos-app-web`; copia `.env.example` a `.env`, define `POSTGRES_PASSWORD` y un `JWT_SECRET` aleatorio largo.
4. Levanta los servicios con `docker compose up -d --build` y carga el catálogo/recetario/plano con `docker compose exec api node data/import-catalog.js`.
5. En Hostinger crea los registros A para `app.ev2.system`, `pos.ev2.system` y `api.ev2.system` apuntando al VPS.
6. Habilita `deploy/nginx-ev2.conf`, valida Nginx y emite SSL con Certbot para los tres subdominios.
7. Comprueba `https://api.ev2.system/health` antes de abrir las interfaces.

Si ya se creó la base antes de esta versión, aplica la migración de pagos una única vez:

```bash
docker compose exec -T db psql -U ev2 -d ev2 < database/migrations/001_payments_and_reservations.sql
```

Los servicios se publican solo en `127.0.0.1`; Nginx es la única puerta pública. Esto mantiene separado el proyecto existente del dominio principal.

## Seguridad operacional

- Los QR almacenan solo hashes de tokens aleatorios; no contienen nombre, precio ni permisos.
- El escaneo marca el acceso como usado y conserva auditoría de denegaciones.
- Las operaciones críticas se registran en `audit_log` y los movimientos de inventario no se sobrescriben.
- Para contingencias (teléfono sin batería), recepción debe buscar la reserva, validar INE y emitir un pase temporal de un solo uso desde un flujo administrativo autorizado.
- Un menor o identificación inválida queda denegado; el titular puede reasignar un acceso no usado a otro adulto.
