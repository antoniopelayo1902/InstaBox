#!/usr/bin/env bash
#
# remote-setup.sh
# Se ejecuta DENTRO de la instancia EC2 (lo copia deploy-ec2.sh).
# Instala dependencias, crea el venv y levanta la app como servicio systemd.
#
# Recibe por ambiente: AWS_REGION, S3_BUCKET, SECRET_NAME, APP_PORT
#
set -euo pipefail

APP_DIR=/opt/instabox

echo ">> Instalando paquetes del sistema..."
sudo dnf install -y python3.11 python3.11-pip dejavu-sans-fonts >/dev/null 2>&1 \
  || sudo dnf install -y python3 python3-pip dejavu-sans-fonts >/dev/null 2>&1 \
  || sudo yum install -y python3 python3-pip dejavu-sans-fonts >/dev/null 2>&1

PYBIN="$(command -v python3.11 || command -v python3)"
echo ">> Usando ${PYBIN}"

cd "$APP_DIR"
"$PYBIN" -m venv .venv
.venv/bin/pip install --upgrade pip >/dev/null
.venv/bin/pip install -r requirements.txt

echo ">> Creando servicio systemd..."
sudo tee /etc/systemd/system/instabox.service >/dev/null <<UNIT
[Unit]
Description=InstaBox API
After=network.target

[Service]
User=ec2-user
WorkingDirectory=${APP_DIR}
Environment=AWS_REGION=${AWS_REGION}
Environment=S3_BUCKET=${S3_BUCKET}
Environment=DB_SECRET_NAME=${SECRET_NAME}
ExecStart=${APP_DIR}/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port ${APP_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now instabox
sleep 3
sudo systemctl --no-pager status instabox || true
echo ">> InstaBox corriendo en el puerto ${APP_PORT}"
