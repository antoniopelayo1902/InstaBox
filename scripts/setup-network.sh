#!/usr/bin/env bash
#
# setup-network.sh
# Crea los security groups en la VPC default:
#   - EC2 SG: permite SSH (22) y el puerto de la app desde internet.
#   - RDS SG: permite PostgreSQL (5432) SOLO desde el EC2 SG (y desde tu IP,
#             para poder inicializar el esquema desde tu maquina).
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
require_cmd aws

VPC_ID="$(default_vpc_id)"
echo "VPC default: ${VPC_ID}"

# --- EC2 SG ---
EC2_SG_ID="$(sg_id_by_name "$EC2_SG_NAME")"
if [[ -z "$EC2_SG_ID" || "$EC2_SG_ID" == "None" ]]; then
  EC2_SG_ID="$(aws ec2 create-security-group \
    --group-name "$EC2_SG_NAME" \
    --description "InstaBox EC2 SG" \
    --vpc-id "$VPC_ID" --region "$AWS_REGION" \
    --query 'GroupId' --output text)"
  echo "EC2 SG creado: ${EC2_SG_ID}"
else
  echo "EC2 SG ya existe: ${EC2_SG_ID}"
fi

aws ec2 authorize-security-group-ingress --group-id "$EC2_SG_ID" \
  --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$AWS_REGION" 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "$EC2_SG_ID" \
  --protocol tcp --port "$APP_PORT" --cidr 0.0.0.0/0 --region "$AWS_REGION" 2>/dev/null || true

# --- RDS SG ---
RDS_SG_ID="$(sg_id_by_name "$RDS_SG_NAME")"
if [[ -z "$RDS_SG_ID" || "$RDS_SG_ID" == "None" ]]; then
  RDS_SG_ID="$(aws ec2 create-security-group \
    --group-name "$RDS_SG_NAME" \
    --description "InstaBox RDS SG" \
    --vpc-id "$VPC_ID" --region "$AWS_REGION" \
    --query 'GroupId' --output text)"
  echo "RDS SG creado: ${RDS_SG_ID}"
else
  echo "RDS SG ya existe: ${RDS_SG_ID}"
fi

# 5432 desde el EC2 SG
aws ec2 authorize-security-group-ingress --group-id "$RDS_SG_ID" \
  --protocol tcp --port "$DB_PORT" --source-group "$EC2_SG_ID" --region "$AWS_REGION" 2>/dev/null || true

# 5432 desde tu IP publica (para correr init-db.sh desde tu maquina)
MY_IP="$(curl -s https://checkip.amazonaws.com || true)"
if [[ -n "$MY_IP" ]]; then
  aws ec2 authorize-security-group-ingress --group-id "$RDS_SG_ID" \
    --protocol tcp --port "$DB_PORT" --cidr "${MY_IP}/32" --region "$AWS_REGION" 2>/dev/null || true
  echo "Acceso a RDS permitido desde tu IP: ${MY_IP}/32"
fi

# Persistimos ids
cat > "${STATE_DIR}/network.env" <<EOF
export VPC_ID=${VPC_ID}
export EC2_SG_ID=${EC2_SG_ID}
export RDS_SG_ID=${RDS_SG_ID}
EOF

echo "Network lista. EC2_SG=${EC2_SG_ID}  RDS_SG=${RDS_SG_ID}"
