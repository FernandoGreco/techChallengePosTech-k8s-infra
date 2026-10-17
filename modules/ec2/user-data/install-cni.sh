#!/bin/bash
set -euo pipefail

export KUBECONFIG=/etc/kubernetes/admin.conf

CALICO_VERSION="v3.30.3"

echo "Iniciando instalacao do Calico ${CALICO_VERSION}..."

# Verificar inicializacao do Control Plane
if [ ! -f "$KUBECONFIG" ]; then
  echo "ERRO: Control Plane ainda nao inicializado."
  exit 1
fi

# Verificar comunicacao com Kubernetes
kubectl cluster-info

# Instalar Calico
kubectl apply -f \
  "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

echo "Aguardando inicializacao do Calico..."

# Verificar DaemonSet
kubectl rollout status \
  daemonset/calico-node \
  -n kube-system \
  --timeout=300s

# Verificar Deployment do controlador
kubectl rollout status \
  deployment/calico-kube-controllers \
  -n kube-system \
  --timeout=300s

echo "Status dos componentes Calico:"
kubectl get pods -n kube-system

echo "Instalacao do Calico finalizada."