#!/bin/bash
set -euo pipefail

export KUBECONFIG=/etc/kubernetes/admin.conf

# Production uses the same pinned release with CA verification on both TLS hops.
# The helper is supplied by scripts/bootstrap-production.mjs after verified join.
if [[ "${METRICS_TLS_MODE:-lab}" == "secure" ]]; then
  : "${METRICS_TLS_HELPER:?Provide the reviewed kubelet-serving-tls.py helper}"
  python3 "$METRICS_TLS_HELPER" install-metrics
  kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s
  kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=120s
  exit 0
fi
if [[ "${DEPLOY_ENVIRONMENT:-homolog}" == "production" ]]; then
  echo 'Production requires METRICS_TLS_MODE=secure; insecure TLS is refused.' >&2
  exit 1
fi

METRICS_SERVER_VERSION="v0.8.0"

echo "Instalando Metrics Server ${METRICS_SERVER_VERSION}..."

if [[ ! -f "$KUBECONFIG" ]]; then
  echo "ERRO: Control Plane nao inicializado."
  exit 1
fi

# Em kubeadm, certificados de kubelet normalmente nao possuem CA valida para Metrics Server.
# Somente para laboratorio: usar --kubelet-insecure-tls (nao recomendado para producao).
# Preparar o manifesto antes do apply evita dois rollouts e argumentos duplicados.
METRICS_DIR="$(mktemp -d)"
trap 'rm -f "$METRICS_DIR/components.yaml" "$METRICS_DIR/kustomization.yaml"; rmdir "$METRICS_DIR"' EXIT
curl -fsSL --connect-timeout 10 --max-time 60 \
  "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml" \
  -o "$METRICS_DIR/components.yaml"

cat > "$METRICS_DIR/kustomization.yaml" <<'KUSTOMIZATION'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - components.yaml
patches:
  - target:
      kind: Deployment
      name: metrics-server
      namespace: kube-system
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --kubelet-insecure-tls
KUSTOMIZATION

kubectl apply -k "$METRICS_DIR"

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
