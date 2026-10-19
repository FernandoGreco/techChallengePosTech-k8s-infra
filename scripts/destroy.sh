#!/usr/bin/env bash

set -euo pipefail

# Diretorios do projeto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../environments/homolog"

echo "========================================"
echo " Tech Challenge - Destroy Kubernetes AWS"
echo "========================================"

# Verificar ferramentas necessarias
for cmd in aws terraform; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERRO: comando '$cmd' nao encontrado."
    exit 1
  fi
done

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

# Selecionar configuracao Terraform da conta AWS
TFVARS_FILE="${TERRAFORM_DIR}/accounts/${CURRENT_AWS_ACCOUNT_ID}.tfvars"

if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "ERRO: arquivo de configuracao nao encontrado:"
  echo "$TFVARS_FILE"
  echo "Destruicao cancelada por seguranca."
  exit 1
fi

echo "Configuracao Terraform selecionada: $TFVARS_FILE"

# Selecionar estado Terraform da conta AWS
TERRAFORM_WORK_DIR="${SCRIPT_DIR}/../.terraform-accounts/${CURRENT_AWS_ACCOUNT_ID}"
STATE_FILE="${TERRAFORM_WORK_DIR}/terraform.tfstate"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERRO: estado Terraform nao encontrado:"
  echo "$STATE_FILE"
  echo "Destruicao cancelada por seguranca."
  exit 1
fi

export TF_DATA_DIR="${TERRAFORM_WORK_DIR}/data"
export TF_CLI_ARGS_init="-backend-config=path=${STATE_FILE}"

echo "Estado Terraform selecionado: $STATE_FILE"

echo ""
echo "========================================"
echo " Inicializando Terraform para destruicao"
echo "========================================"

cd "$TERRAFORM_DIR"

terraform init -reconfigure -input=false

echo ""
echo "========================================"
echo " Validando configuracao Terraform"
echo "========================================"

terraform validate

echo ""
echo "Terraform inicializado e validado com sucesso!"

echo ""
echo "Verificando recursos no estado Terraform..."

if [[ -z "$(terraform state list)" ]]; then
  echo "Nenhum recurso encontrado no estado Terraform."
  echo "Destruicao cancelada por seguranca."
  exit 1
fi

echo "Recursos encontrados no estado Terraform."

echo ""
echo "========================================"
echo " Gerando plano de destruicao"
echo "========================================"

terraform plan -destroy -input=false -var-file="$TFVARS_FILE" -out=destroy.tfplan

echo ""
echo "========================================"
echo " Recursos previstos para exclusao"
echo "========================================"

terraform show -no-color destroy.tfplan

echo ""
echo "Plano de destruicao gerado."
echo "Nenhum recurso foi excluido."

echo ""
echo "========================================"
echo " Confirmacao de destruicao"
echo "========================================"

echo "ATENCAO: os recursos listados serao excluidos!"
echo "Conta AWS: $CURRENT_AWS_ACCOUNT_ID"

read -r -p "Digite DESTRUIR para confirmar: " CONFIRMATION

if [[ "$CONFIRMATION" != "DESTRUIR" ]]; then
  echo "Destruicao cancelada. Nenhum recurso foi excluido."
  exit 0
fi

echo ""
echo "Aplicando plano de destruicao..."

terraform apply -input=false destroy.tfplan

echo ""
echo "========================================"
echo " Destruicao concluida!"
echo "========================================"