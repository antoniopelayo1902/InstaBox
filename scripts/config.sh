#!/usr/bin/env bash
#
# config.sh
# Configuracion compartida por todos los scripts. Puedes sobreescribir
# cualquier valor exportando la variable antes de correr los scripts, por ej:
#   export S3_BUCKET=instabox-miequipo-123
#
# Se hace `source` desde los demas scripts.

export AWS_REGION="${AWS_REGION:-us-east-1}"
export PROJECT="${PROJECT:-instabox}"

# ----- S3 (el nombre debe ser UNICO a nivel global) -----
export S3_BUCKET="${S3_BUCKET:-instabox-$(whoami)-demo}"

# ----- RDS PostgreSQL -----
export DB_INSTANCE_ID="${DB_INSTANCE_ID:-instabox-db}"
export DB_NAME="${DB_NAME:-instabox}"
export DB_USER="${DB_USER:-instabox_admin}"
export DB_PASSWORD="${DB_PASSWORD:-}"          # si esta vacio, setup-rds.sh genera una
export DB_ENGINE_VERSION="${DB_ENGINE_VERSION:-16.9}"
export DB_CLASS="${DB_CLASS:-db.t3.micro}"
export DB_STORAGE="${DB_STORAGE:-20}"
export DB_PORT="${DB_PORT:-5432}"

# ----- Secrets Manager -----
export SECRET_NAME="${SECRET_NAME:-instabox/rds}"

# ----- EC2 -----
export EC2_TYPE="${EC2_TYPE:-t3.micro}"
export EC2_AMI="${EC2_AMI:-}"                  # si esta vacio, se resuelve AL2023
export EC2_KEY_NAME="${EC2_KEY_NAME:-vockey}"  # key pair del Learner Lab
export EC2_KEY_PATH="${EC2_KEY_PATH:-$HOME/labsuser.pem}"
export INSTANCE_PROFILE="${INSTANCE_PROFILE:-LabInstanceProfile}"
export APP_PORT="${APP_PORT:-8000}"

# ----- Security groups -----
export EC2_SG_NAME="${EC2_SG_NAME:-instabox-ec2-sg}"
export RDS_SG_NAME="${RDS_SG_NAME:-instabox-rds-sg}"

# ----- Estado local (gitignored) -----
# Aqui persistimos endpoints, ids y password entre scripts.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
export STATE_DIR="${ROOT_DIR}/.state"
mkdir -p "$STATE_DIR"

# Carga estado previo si existe.
[[ -f "${STATE_DIR}/rds.env" ]] && source "${STATE_DIR}/rds.env"
[[ -f "${STATE_DIR}/ec2.env" ]] && source "${STATE_DIR}/ec2.env"

# ----- helpers -----
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: falta el comando '$1'." >&2; exit 1; }
}

default_vpc_id() {
  aws ec2 describe-vpcs \
    --filters Name=isDefault,Values=true \
    --query 'Vpcs[0].VpcId' --output text --region "$AWS_REGION"
}

sg_id_by_name() {
  aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$1" \
    --query 'SecurityGroups[0].GroupId' --output text --region "$AWS_REGION" 2>/dev/null
}
