#!/usr/bin/env bash
# Source this file after validating EXPECTED_AWS_ACCOUNT_ID and AWS credentials.
set -euo pipefail
TF_BACKEND_BUCKET="${TF_BACKEND_BUCKET:-fiap-tc3-k8s-tfstate-${EXPECTED_AWS_ACCOUNT_ID}}"
if [[ ! "$TF_BACKEND_BUCKET" =~ ^[a-z0-9][a-z0-9.-]{2,62}$ ]]; then
  echo "ERRO: nome de bucket S3 invalido." >&2
  exit 1
fi
terraform init -reconfigure -input=false -backend-config="bucket=${TF_BACKEND_BUCKET}"
