"""Helpers para subir y descargar objetos de S3."""

import io

import boto3

from .config import AWS_REGION, S3_BUCKET

_s3 = boto3.client("s3", region_name=AWS_REGION)


def upload_fileobj(fileobj, key, content_type="image/jpeg"):
    """Sube un objeto tipo archivo a S3_BUCKET/<key>."""
    _s3.upload_fileobj(
        fileobj,
        S3_BUCKET,
        key,
        ExtraArgs={"ContentType": content_type},
    )
    return key


def download_bytes(key):
    """Descarga un objeto de S3 y lo regresa como BytesIO."""
    buffer = io.BytesIO()
    _s3.download_fileobj(S3_BUCKET, key, buffer)
    buffer.seek(0)
    return buffer


def delete_keys(keys):
    """Borra una lista de objetos de S3 (usado al finalizar el evento)."""
    keys = [k for k in keys if k]
    if not keys:
        return
    _s3.delete_objects(
        Bucket=S3_BUCKET,
        Delete={"Objects": [{"Key": k} for k in keys]},
    )
