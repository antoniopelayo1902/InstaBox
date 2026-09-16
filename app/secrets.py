"""Lectura de credenciales de RDS desde AWS Secrets Manager.

La instancia EC2 usa el instance profile LabInstanceProfile, que tiene
permiso para leer este secret. Asi NUNCA guardamos usuario/contrasena en
variables de ambiente ni en el codigo.

El secret debe ser un JSON con esta forma:
{
  "host": "...",
  "port": 5432,
  "dbname": "instabox",
  "username": "instabox_admin",
  "password": "..."
}
"""

import json
from functools import lru_cache

import boto3

from .config import AWS_REGION, DB_SECRET_NAME


@lru_cache(maxsize=1)
def get_db_secret():
    """Devuelve el dict con las credenciales de RDS (cacheado)."""
    client = boto3.client("secretsmanager", region_name=AWS_REGION)
    response = client.get_secret_value(SecretId=DB_SECRET_NAME)
    return json.loads(response["SecretString"])
