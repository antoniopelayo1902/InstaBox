#!/usr/bin/env bash
#
# setup-secret.sh
# Crea (o actualiza) el secret en AWS Secrets Manager con las credenciales
# de RDS que la app leera en tiempo de ejecucion.
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
require_cmd aws

if [[ -z "${DB_HOST:-}" ]]; then
  echo "No hay estado de RDS. Corre setup-rds.sh primero." >&2
  exit 1
fi

SECRET_JSON="$(cat <<EOF
{
  "host": "${DB_HOST}",
  "port": ${DB_PORT},
  "dbname": "${DB_NAME}",
  "username": "${DB_USER}",
  "password": "${DB_PASSWORD}"
}
EOF
)"

if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "El secret '${SECRET_NAME}' ya existe. Actualizando valor..."
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string "$SECRET_JSON" \
    --region "$AWS_REGION" >/dev/null
else
  echo "Creando secret '${SECRET_NAME}'..."
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --description "Credenciales RDS de InstaBox" \
    --secret-string "$SECRET_JSON" \
    --region "$AWS_REGION" >/dev/null
fi

echo "Secret listo: ${SECRET_NAME}"
