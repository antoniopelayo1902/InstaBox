#!/usr/bin/env bash
#
# setup-s3.sh
# Crea el bucket de S3 y los prefijos pictures/ y polaroids/.
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
require_cmd aws

echo "Creando bucket s3://${S3_BUCKET} en ${AWS_REGION}..."

if aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
  echo "El bucket ya existe y es accesible."
else
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION"
  else
    aws s3api create-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi
  echo "Bucket creado."
fi

# Prefijos (folders logicos)
aws s3api put-object --bucket "$S3_BUCKET" --key "pictures/"  >/dev/null
aws s3api put-object --bucket "$S3_BUCKET" --key "polaroids/" >/dev/null

echo "Listo: s3://${S3_BUCKET}/pictures/  y  s3://${S3_BUCKET}/polaroids/"
