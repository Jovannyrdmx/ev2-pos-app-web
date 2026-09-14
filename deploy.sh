#!/usr/bin/env bash
# EV2 Clandestino — deploy local en un VPS Ubuntu con Docker ya instalado.
# No modifica Nginx, Caddy, DNS ni otros proyectos del servidor.
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

fail() { printf '\nError: %s\n' "$1" >&2; exit 1; }
note() { printf '\n==> %s\n' "$1"; }

command -v docker >/dev/null 2>&1 || fail "Docker no está instalado. Instálalo antes de ejecutar este script."
docker compose version >/dev/null 2>&1 || fail "Falta el complemento Docker Compose."

if [[ ! -f .env ]]; then
  note "Creando .env privado con secretos aleatorios"
  umask 077
  cp .env.example .env
  postgres_password="$(openssl rand -base64 36 | tr -d '\n' | tr '/+' 'ab')"
  jwt_secret="$(openssl rand -hex 48)"
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${postgres_password}|" .env
  sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${jwt_secret}|" .env
  printf 'Se creó .env. Añade las credenciales de Mercado Pago antes de aceptar pagos reales.\n'
fi

note "Construyendo e iniciando servicios"
docker compose up -d --build

note "Esperando a que PostgreSQL esté disponible"
for _attempt in $(seq 1 30); do
  if docker compose exec -T db pg_isready -U ev2 -d ev2 >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
docker compose exec -T db pg_isready -U ev2 -d ev2 >/dev/null 2>&1 || fail "PostgreSQL no quedó disponible. Ejecuta: docker compose logs db"

note "Cargando catálogo, recetas y plano EV2"
docker compose exec -T api node data/import-catalog.js

note "Comprobando API"
if ! docker compose exec -T api wget -qO- http://localhost:3000/health >/dev/null; then
  fail "La API no respondió. Ejecuta: docker compose logs api"
fi

cat <<'EOF'

Despliegue local listo.

Servicios internos:
  App cliente: http://127.0.0.1:8080
  POS:         http://127.0.0.1:8081
  API:         http://127.0.0.1:3000/health

Para hacerlos públicos con HTTPS aún debes apuntar los DNS de app.ev2.system,
pos.ev2.system y api.ev2.system al VPS y conectarlos desde el proxy web que ya
usa el servidor. Este script no altera el proyecto existente en ev2.system.
EOF
