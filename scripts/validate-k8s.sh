#!/usr/bin/env bash

set -euo pipefail

# Diretorios do projeto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../environments/homolog"

echo "========================================"
echo " Tech Challenge - Validacao Kubernetes"
echo "========================================"

echo ""
echo "Verificando ferramentas necessarias..."

for cmd in aws ssh; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERRO: comando '$cmd' nao encontrado."
    exit 1
  fi
done

echo "Ferramentas necessarias encontradas!"

echo ""
echo "Validando conta AWS..."

if [[ -z "${EXPECTED_AWS_ACCOUNT_ID:-}" ]]; then
  echo "ERRO: variavel EXPECTED_AWS_ACCOUNT_ID nao configurada."
  exit 1
fi

CURRENT_AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

if [[ "$CURRENT_AWS_ACCOUNT_ID" != "$EXPECTED_AWS_ACCOUNT_ID" ]]; then
  echo "ERRO: conta AWS incorreta!"
  echo "Conta esperada: $EXPECTED_AWS_ACCOUNT_ID"
  echo "Conta autenticada: $CURRENT_AWS_ACCOUNT_ID"
  exit 1
fi

echo "Conta AWS validada com sucesso: $CURRENT_AWS_ACCOUNT_ID"

# Selecionar estado Terraform da conta AWS
TERRAFORM_WORK_DIR="${SCRIPT_DIR}/../.terraform-accounts/${CURRENT_AWS_ACCOUNT_ID}"
STATE_FILE="${TERRAFORM_WORK_DIR}/terraform.tfstate"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERRO: estado Terraform nao encontrado:"
  echo "$STATE_FILE"
  echo "Validacao Kubernetes cancelada."
  exit 1
fi

export TF_DATA_DIR="${TERRAFORM_WORK_DIR}/data"
export TF_CLI_ARGS_init="-backend-config=path=${STATE_FILE}"

echo "Estado Terraform selecionado: $STATE_FILE"

echo ""
echo "========================================"
echo " Identificando Control Plane"
echo "========================================"

cd "$TERRAFORM_DIR"

CONTROL_PLANE_ID="$(terraform output -raw control_plane_id)"

if [[ -z "$CONTROL_PLANE_ID" ]]; then
  echo "ERRO: ID do control plane nao encontrado."
  exit 1
fi

echo "Control Plane identificado: $CONTROL_PLANE_ID"

echo ""
echo "Consultando IP publico do Control Plane..."

CONTROL_PLANE_PUBLIC_IP="$(aws ec2 describe-instances \
  --instance-ids "$CONTROL_PLANE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)"

if [[ -z "$CONTROL_PLANE_PUBLIC_IP" || "$CONTROL_PLANE_PUBLIC_IP" == "None" ]]; then
  echo "ERRO: IP publico do Control Plane nao encontrado."
  exit 1
fi

echo "IP publico do Control Plane: $CONTROL_PLANE_PUBLIC_IP"

echo ""
echo "Validando chave SSH..."

if [[ -z "${SSH_PRIVATE_KEY_PATH:-}" ]]; then
  echo "ERRO: variavel SSH_PRIVATE_KEY_PATH nao configurada."
  exit 1
fi

if [[ ! -f "$SSH_PRIVATE_KEY_PATH" ]]; then
  echo "ERRO: chave SSH nao encontrada:"
  echo "$SSH_PRIVATE_KEY_PATH"
  exit 1
fi

echo "Chave SSH encontrada."

echo ""
echo "Configurando usuario SSH..."

SSH_USER="${SSH_USER:-ubuntu}"

echo "Usuario SSH: $SSH_USER"

echo ""
echo "========================================"
echo " Testando conexao SSH com Control Plane"
echo "========================================"

ssh \
  -i "$SSH_PRIVATE_KEY_PATH" \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  "${SSH_USER}@${CONTROL_PLANE_PUBLIC_IP}" \
  "echo 'Conexao SSH estabelecida com sucesso!'"

  echo ""
echo "========================================"
echo " Verificando nos Kubernetes"
echo "========================================"

ssh \
  -i "$SSH_PRIVATE_KEY_PATH" \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  "${SSH_USER}@${CONTROL_PLANE_PUBLIC_IP}" \
  "kubectl get nodes -o wide"

  echo ""
echo "========================================"
echo " Verificando pods Kubernetes"
echo "========================================"

ssh \
  -i "$SSH_PRIVATE_KEY_PATH" \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  "${SSH_USER}@${CONTROL_PLANE_PUBLIC_IP}" \
  "kubectl get pods -A -o wide"