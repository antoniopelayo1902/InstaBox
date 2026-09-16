#!/usr/bin/env bash
#
# init-db.sh
# Aplica sql/schema.sql sobre la instancia RDS. Requiere psql y que tu IP
# tenga acceso al puerto 5432 (setup-network.sh ya lo permite).
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
require_cmd psql

if [[ -z "${DB_HOST:-}" ]]; then
  echo "No hay estado de RDS. Corre setup-rds.sh primero." >&2
  exit 1
fi

echo "Aplicando esquema en ${DB_HOST}:${DB_PORT}/${DB_NAME}..."
PGPASSWORD="$DB_PASSWORD" psql \
  -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -v ON_ERROR_STOP=1 \
  -f "${ROOT_DIR}/sql/schema.sql"

echo "Esquema aplicado. Tablas creadas: events, photos."
