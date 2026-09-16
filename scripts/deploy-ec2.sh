#!/usr/bin/env bash
#
# deploy-ec2.sh
# Lanza una instancia EC2 con el instance profile LabInstanceProfile, copia
# el codigo y arranca la app como servicio. Requiere que ya existan la red,
# el bucket, la RDS y el secret.
#
# Necesita:
#   - EC2_KEY_NAME  : nombre del key pair (default: vockey)
#   - EC2_KEY_PATH  : ruta al .pem (default: ~/labsuser.pem)
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
require_cmd aws
require_cmd ssh
require_cmd scp

if [[ -f "${STATE_DIR}/network.env" ]]; then
  source "${STATE_DIR}/network.env"
else
  echo "Corre setup-network.sh primero." >&2
  exit 1
fi

if [[ ! -f "$EC2_KEY_PATH" ]]; then
  echo "ERROR: no encuentro la llave SSH en ${EC2_KEY_PATH}." >&2
  echo "Descarga labsuser.pem del Learner Lab o exporta EC2_KEY_PATH." >&2
  exit 1
fi
chmod 400 "$EC2_KEY_PATH" 2>/dev/null || true

# Resuelve el AMI de Amazon Linux 2023 si no se dio uno.
if [[ -z "$EC2_AMI" ]]; then
  EC2_AMI="$(aws ssm get-parameters \
    --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query 'Parameters[0].Value' --output text --region "$AWS_REGION")"
fi
echo "AMI: ${EC2_AMI}"

echo "Lanzando instancia EC2 (${EC2_TYPE})..."
INSTANCE_ID="$(aws ec2 run-instances \
  --image-id "$EC2_AMI" \
  --instance-type "$EC2_TYPE" \
  --key-name "$EC2_KEY_NAME" \
  --security-group-ids "$EC2_SG_ID" \
  --iam-instance-profile Name="$INSTANCE_PROFILE" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT}}]" \
  --region "$AWS_REGION" \
  --query 'Instances[0].InstanceId' --output text)"
echo "Instancia: ${INSTANCE_ID}"

echo "Esperando a que este running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"

PUBLIC_IP="$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region "$AWS_REGION")"

cat > "${STATE_DIR}/ec2.env" <<EOF
export INSTANCE_ID=${INSTANCE_ID}
export PUBLIC_IP=${PUBLIC_IP}
EOF

echo "IP publica: ${PUBLIC_IP}"
echo "Esperando a que SSH responda..."
for _ in $(seq 1 30); do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$EC2_KEY_PATH" \
       ec2-user@"$PUBLIC_IP" "echo ok" >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

echo "Copiando codigo a la instancia..."
ssh -o StrictHostKeyChecking=no -i "$EC2_KEY_PATH" ec2-user@"$PUBLIC_IP" \
  "sudo mkdir -p /opt/instabox && sudo chown ec2-user:ec2-user /opt/instabox"
scp -o StrictHostKeyChecking=no -i "$EC2_KEY_PATH" -r \
  "${ROOT_DIR}/app" "${ROOT_DIR}/requirements.txt" "${ROOT_DIR}/scripts/remote-setup.sh" \
  ec2-user@"$PUBLIC_IP":/opt/instabox/

echo "Ejecutando setup remoto..."
ssh -o StrictHostKeyChecking=no -i "$EC2_KEY_PATH" ec2-user@"$PUBLIC_IP" \
  "AWS_REGION='${AWS_REGION}' S3_BUCKET='${S3_BUCKET}' SECRET_NAME='${SECRET_NAME}' APP_PORT='${APP_PORT}' bash /opt/instabox/remote-setup.sh"

echo ""
echo "======================================================"
echo " InstaBox desplegado."
echo " URL base:  http://${PUBLIC_IP}:${APP_PORT}"
echo " Health:    http://${PUBLIC_IP}:${APP_PORT}/health"
echo "======================================================"
