#!/usr/bin/env bash
#
# teardown.sh
# Elimina TODOS los recursos creados por la practica:
#   EC2, RDS, Secret, bucket S3 (vaciado) y los security groups.
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
require_cmd aws

echo "ADVERTENCIA: se eliminaran EC2, RDS, el secret, el bucket S3 y los SGs de InstaBox."
read -r -p "Escribe 'si' para continuar: " confirm
if [[ "$confirm" != "si" ]]; then
  echo "Cancelado."
  exit 0
fi

[[ -f "${STATE_DIR}/network.env" ]] && source "${STATE_DIR}/network.env"

# --- EC2 ---
if [[ -n "${INSTANCE_ID:-}" ]]; then
  echo ">> Terminando EC2 ${INSTANCE_ID}..."
  aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" >/dev/null || true
  aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" || true
fi

# --- RDS ---
if aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo ">> Eliminando RDS ${DB_INSTANCE_ID} (sin snapshot)..."
  aws rds delete-db-instance \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --skip-final-snapshot \
    --delete-automated-backups \
    --region "$AWS_REGION" >/dev/null || true
  echo ">> Esperando a que RDS termine de borrarse..."
  aws rds wait db-instance-deleted --db-instance-identifier "$DB_INSTANCE_ID" --region "$AWS_REGION" || true
fi

# --- Secret ---
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo ">> Eliminando secret ${SECRET_NAME}..."
  aws secretsmanager delete-secret --secret-id "$SECRET_NAME" \
    --force-delete-without-recovery --region "$AWS_REGION" >/dev/null || true
fi

# --- S3 ---
if aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
  echo ">> Vaciando y eliminando bucket ${S3_BUCKET}..."
  aws s3 rm "s3://${S3_BUCKET}" --recursive >/dev/null || true
  aws s3api delete-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" || true
fi

# --- Security groups (despues de que EC2 y RDS ya no existen) ---
if [[ -n "${RDS_SG_ID:-}" ]]; then
  echo ">> Eliminando RDS SG ${RDS_SG_ID}..."
  aws ec2 delete-security-group --group-id "$RDS_SG_ID" --region "$AWS_REGION" 2>/dev/null || true
fi
if [[ -n "${EC2_SG_ID:-}" ]]; then
  echo ">> Eliminando EC2 SG ${EC2_SG_ID}..."
  aws ec2 delete-security-group --group-id "$EC2_SG_ID" --region "$AWS_REGION" 2>/dev/null || true
fi

# --- estado local ---
rm -f "${STATE_DIR}"/rds.env "${STATE_DIR}"/ec2.env "${STATE_DIR}"/network.env

echo ""
echo "Teardown completo. Verifica en la consola que no quede nada."
