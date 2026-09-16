"""Configuracion de la aplicacion.

Estos valores son CONFIGURACION (no credenciales): el nombre del bucket,
el nombre del secret y la region. Se leen de variables de ambiente porque
cambian entre despliegues.

Las CREDENCIALES de la base de datos NO estan aqui: se leen en tiempo de
ejecucion desde AWS Secrets Manager (ver secrets.py).
"""

import os

# Region de AWS donde viven los recursos.
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

# Bucket de S3 para las fotos. Obligatorio.
S3_BUCKET = os.environ.get("S3_BUCKET", "")

# Nombre del secret en Secrets Manager con las credenciales de RDS.
DB_SECRET_NAME = os.environ.get("DB_SECRET_NAME", "instabox/rds")

# Prefijos ("folders") dentro del bucket.
PICTURES_PREFIX = "pictures/"
POLAROIDS_PREFIX = "polaroids/"

# Tamano de la foto original reducida (requisito: 128x128).
THUMB_SIZE = (128, 128)

# Limite de tamano de subida (bytes) para /upload.
MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB

# Tipos de imagen permitidos en /upload.
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png"}
