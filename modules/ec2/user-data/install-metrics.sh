#!/bin/bash
set -euo pipefail

export KUBECONFIG=/etc/kubernetes/admin.conf

METRICS_SERVER_VERSION="v0.8.0"

echo "Instalando Metrics Server ${METRICS_SERVER_VERSION}..."

if [[ ! -f "$KUBECONFIG" ]]; then
  echo "ERRO: Control Plane nao inicializado."
  exit 1
fi

kubectl apply -f \
  "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"

# Em kubeadm, certificados de kubelet normalmente nao possuem CA valida para Metrics Server.
# Somente para laboratorio: usar --kubelet-insecure-tls (nao recomendado para producao).
kubectl -n kube-system patch deployment metrics-server --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

echo "Aguardando inicializacao do Metrics Server..."

kubectl rollout status \
  deployment/metrics-server \
  -n kube-system \
  --timeout=300s

echo "Verificando disponibilidade da API de metricas..."

kubectl wait --for=condition=Available \
  apiservice/v1beta1.metrics.k8s.io \
  --timeout=180s

kubectl get apiservice v1beta1.metrics.k8s.io

echo "Instalacao do Metrics Server finalizada."