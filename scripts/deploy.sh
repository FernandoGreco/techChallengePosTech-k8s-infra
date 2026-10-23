#!/usr/bin/env bash

set -euo pipefail

# Diretorio do ambiente Terraform
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../environments/homolog"

echo "========================================"
echo " Tech Challenge - Deploy Kubernetes AWS"
echo "========================================"

# Verificar ferramentas necessarias
for cmd in aws terraform; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERRO: comando '$cmd' nao encontrado."
    exit 1
  fi
done

# Confirmar a conta AWS autenticada
echo ""
echo "Verificando identidade AWS..."
aws sts get-caller-identity

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
  exit 1
fi

echo "Configuracao Terraform selecionada: $TFVARS_FILE"

echo ""
echo "Validando chave SSH..."

if [[ -z "${SSH_PRIVATE_KEY_PATH:-}" ]]; then
  echo "ERRO: variavel SSH_PRIVATE_KEY_PATH nao configurada."
  exit 1
fi

if [[ ! -f "$SSH_PRIVATE_KEY_PATH" ]]; then
  echo "ERRO: arquivo de chave SSH nao encontrado:"
  echo "$SSH_PRIVATE_KEY_PATH"
  exit 1
fi

SSH_USER="${SSH_USER:-ubuntu}"

echo "Chave SSH encontrada."
echo "Usuario SSH: $SSH_USER"

# Isolar os dados e o estado Terraform por conta AWS
TERRAFORM_STATE_ROOT="${TERRAFORM_STATE_ROOT:-${SCRIPT_DIR}/../.terraform-accounts}"
TERRAFORM_WORK_DIR="${TERRAFORM_STATE_ROOT}/${CURRENT_AWS_ACCOUNT_ID}"

mkdir -p "$TERRAFORM_WORK_DIR"

export TF_DATA_DIR="${TERRAFORM_WORK_DIR}/data"

# Caminho do estado Terraform, separado por conta AWS
TERRAFORM_STATE_PATH="${TERRAFORM_WORK_DIR}/terraform.tfstate"

# No Git Bash do Windows, converter para um caminho compativel
if command -v cygpath >/dev/null 2>&1; then
  TERRAFORM_STATE_PATH="$(cygpath -m "$TERRAFORM_STATE_PATH")"
fi

echo ""
echo "========================================"
echo " Inicializando Terraform"
echo "========================================"

cd "$TERRAFORM_DIR"

terraform init -reconfigure -input=false \
  -backend-config="path=${TERRAFORM_STATE_PATH}"

echo ""
echo "========================================"
echo " Validando configuracao Terraform"
echo "========================================"

terraform fmt -check
terraform validate

echo ""
echo "Terraform inicializado e validado com sucesso!"

echo ""
echo "========================================"
echo " Gerando plano Terraform"
echo "========================================"

terraform plan -input=false -var-file="$TFVARS_FILE" -out=tfplan

echo ""
echo "========================================"
echo " Resumo do plano"
echo "========================================"

terraform show -no-color tfplan

echo ""
echo "Plano Terraform gerado com sucesso!"
echo "Nenhum recurso foi criado ou alterado."

echo ""
echo "========================================"
echo " Confirmacao do deploy"
echo "========================================"

read -r -p "Deseja aplicar este plano Terraform? (sim/nao): " CONFIRMATION

if [[ "$CONFIRMATION" != "sim" ]]; then
  echo "Deploy cancelado. Nenhum recurso foi aplicado."
  exit 0
fi

echo ""
echo "Aplicando plano Terraform..."

terraform apply -input=false tfplan

echo ""
echo "========================================"
echo " Deploy concluido com sucesso!"
echo "========================================"

terraform output

echo ""
echo "========================================"
echo " Identificando Worker Kubernetes"
echo "========================================"

WORKER_ID="$(terraform output -raw worker_id)"

if [[ -z "$WORKER_ID" ]]; then
  echo "ERRO: ID da instancia Worker nao encontrado."
  exit 1
fi

echo "Worker identificado: $WORKER_ID"

echo ""
echo "Consultando IP publico do Worker..."

WORKER_PUBLIC_IP="$(aws ec2 describe-instances \
  --instance-ids "$WORKER_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)"

if [[ -z "$WORKER_PUBLIC_IP" || "$WORKER_PUBLIC_IP" == "None" ]]; then
  echo "ERRO: IP publico do Worker nao encontrado."
  exit 1
fi

echo "IP publico do Worker: $WORKER_PUBLIC_IP"

echo ""
echo "========================================"
echo " Aguardando SSH do Worker"
echo "========================================"

SSH_READY=false

for tentativa in {1..12}; do
  echo "Tentativa SSH $tentativa/12..."

  if ssh \
    -i "$SSH_PRIVATE_KEY_PATH" \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=accept-new \
    "${SSH_USER}@${WORKER_PUBLIC_IP}" \
    "echo 'Conexao SSH com Worker estabelecida!'"; then

    SSH_READY=true
    break
  fi

  sleep 10
done

if [[ "$SSH_READY" != "true" ]]; then
  echo "ERRO: nao foi possivel conectar ao Worker por SSH."
  exit 1
fi

echo ""
echo "========================================"
echo " Identificando Control Plane"
echo "========================================"

CONTROL_PLANE_ID="$(terraform output -raw control_plane_id)"

if [[ -z "$CONTROL_PLANE_ID" ]]; then
  echo "ERRO: ID do Control Plane nao encontrado."
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
echo "========================================"
echo " Aguardando SSH do Control Plane"
echo "========================================"

CONTROL_PLANE_SSH_READY=false

for tentativa in {1..12}; do
  echo "Tentativa SSH Control Plane $tentativa/12..."

  if ssh \
    -i "$SSH_PRIVATE_KEY_PATH" \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=accept-new \
    "${SSH_USER}@${CONTROL_PLANE_PUBLIC_IP}" \
    "echo 'Conexao SSH com Control Plane estabelecida!'"; then

    CONTROL_PLANE_SSH_READY=true
    break
  fi

  sleep 10
done

if [[ "$CONTROL_PLANE_SSH_READY" != "true" ]]; then
  echo "ERRO: nao foi possivel conectar ao Control Plane por SSH."
  exit 1
fi

echo ""
echo "========================================"
echo " Aguardando inicializacao das instancias"
echo "========================================"

echo "Aguardando cloud-init do Control Plane..."
ssh \
  -i "$SSH_PRIVATE_KEY_PATH" \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  "${SSH_USER}@${CONTROL_PLANE_PUBLIC_IP}" \
  "sudo cloud-init status --wait"

echo ""
echo "Aguardando cloud-init do Worker..."
ssh \
  -i "$SSH_PRIVATE_KEY_PATH" \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  "${SSH_USER}@${WORKER_PUBLIC_IP}" \
  "sudo cloud-init status --wait"

echo ""
echo "========================================"
echo " Validando Control Plane Kubernetes"
echo "========================================"

ssh \
  -i "$SSH_PRIVATE_KEY_PATH" \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  "${SSH_USER}@${CONTROL_PLANE_PUBLIC_IP}" \
  "kubectl cluster-info"

echo ""
echo "========================================"
echo " Associando Worker ao Kubernetes"
echo "========================================"

echo "Verificando se o Worker ja pertence ao cluster..."

WORKER_ALREADY_JOINED="$(ssh \
  -i "$SSH_PRIVATE_KEY_PATH" \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  "${SSH_USER}@${WORKER_PUBLIC_IP}" \
  "if [ -f /etc/kubernetes/kubelet.conf ]; then echo sim; else echo nao; fi")"

if [[ "$WORKER_ALREADY_JOINED" == "sim" ]]; then
  echo "Worker ja possui configuracao de associacao."
  echo "Nenhum novo kubeadm join sera executado."
else
  echo "Gerando comando atualizado de associacao..."

  # O token nao e exibido no terminal nem gravado localmente.
  # O comando e transmitido diretamente por SSH ao Worker.
  ssh \
    -i "$SSH_PRIVATE_KEY_PATH" \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=accept-new \
    "${SSH_USER}@${CONTROL_PLANE_PUBLIC_IP}" \
    "sudo kubeadm token create --print-join-command" \
    | ssh \
        -i "$SSH_PRIVATE_KEY_PATH" \
        -o BatchMode=yes \
        -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=accept-new \
        "${SSH_USER}@${WORKER_PUBLIC_IP}" \
        "sudo bash -se"

  echo "Comando de associacao executado."
fi

echo ""
echo "========================================"
echo " Aguardando Worker ficar Ready"
echo "========================================"

WORKER_READY=false

for tentativa in {1..30}; do
  echo "Verificando nos Kubernetes: tentativa $tentativa/30..."

  if ssh \
    -i "$SSH_PRIVATE_KEY_PATH" \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=accept-new \
    "${SSH_USER}@${CONTROL_PLANE_PUBLIC_IP}" \
    "kubectl get nodes --no-headers | awk '\$2 == \"Ready\" {count++} END {exit !(count >= 2)}'"; then

    WORKER_READY=true
    break
  fi

  sleep 10
done

if [[ "$WORKER_READY" != "true" ]]; then
  echo "ERRO: cluster nao atingiu dois nos Ready."
  exit 1
fi

echo ""
echo "========================================"
echo " Estado final dos nos Kubernetes"
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
echo " Estado final dos pods Kubernetes"
echo "========================================"

ssh \
  -i "$SSH_PRIVATE_KEY_PATH" \
  -o BatchMode=yes \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  "${SSH_USER}@${CONTROL_PLANE_PUBLIC_IP}" \
  "kubectl get pods -A -o wide"

echo ""
echo "========================================"
echo " Kubernetes provisionado e validado!"
echo "========================================"