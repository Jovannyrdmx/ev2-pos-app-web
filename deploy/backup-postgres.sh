#!/usr/bin/env sh
set -eu

# Run from the repository directory. BACKUP_DIR must be outside the repository.
BACKUP_DIR=${BACKUP_DIR:-/var/backups/ev2}
mkdir -p "$BACKUP_DIR"
umask 077
stamp=$(date -u +%Y%m%dT%H%M%SZ)
docker compose exec -T db pg_dump -U ev2 -d ev2 | gzip > "$BACKUP_DIR/ev2-$stamp.sql.gz"
find "$BACKUP_DIR" -type f -name 'ev2-*.sql.gz' -mtime +30 -delete
