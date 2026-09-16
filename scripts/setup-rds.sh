#!/usr/bin/env bash
#
# setup-rds.sh
# Crea la instancia RDS PostgreSQL y espera a que este disponible.
# Guarda host/puerto/password en .state/rds.env para los siguientes scripts.
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
require_cmd aws

# Necesitamos el security group de RDS.
if [[ -f "${STATE_DIR}/network.env" ]]; then
  source "${STATE_DIR}/network.env"
else
  echo "Primero corre setup-network.sh" >&2
  exit 1
fi

# Genera password si no se definio una.
if [[ -z "${DB_PASSWORD}" ]]; then
  DB_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=@ "' | cut -c1-20)"
  echo "Password generada para RDS (se guardara en Secrets Manager)."
fi

if aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" \
     --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "La instancia RDS '${DB_INSTANCE_ID}' ya existe. No la recreo."
else
  echo "Creando instancia RDS '${DB_INSTANCE_ID}' (esto tarda varios minutos)..."
  aws rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --db-instance-class "$DB_CLASS" \
    --engine postgres \
    --engine-version "$DB_ENGINE_VERSION" \
    --master-username "$DB_USER" \
    --master-user-password "$DB_PASSWORD" \
    --allocated-storage "$DB_STORAGE" \
    --db-name "$DB_NAME" \
    --vpc-security-group-ids "$RDS_SG_ID" \
    --publicly-accessible \
    --no-multi-az \
    --backup-retention-period 0 \
    --port "$DB_PORT" \
    --region "$AWS_REGION" >/dev/null
fi

echo "Esperando a que la instancia este disponible..."
aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE_ID" --region "$AWS_REGION"

DB_HOST="$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].Endpoint.Address' --output text --region "$AWS_REGION")"

# Persistimos estado para los siguientes scripts.
cat > "${STATE_DIR}/rds.env" <<EOF
export DB_HOST=${DB_HOST}
export DB_PORT=${DB_PORT}
export DB_NAME=${DB_NAME}
export DB_USER=${DB_USER}
export DB_PASSWORD='${DB_PASSWORD}'
EOF

echo "RDS disponible en: ${DB_HOST}:${DB_PORT}"
