#!/bin/bash
set -euo pipefail

export KUBECONFIG=/etc/kubernetes/admin.conf

if [ ! -f "$KUBECONFIG" ]; then
  echo "Control Plane ainda nao inicializado."
  exit 1
fi

CALICO_VERSION="v3.30.3"

kubectl apply -f \
  "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

echo "Manifesto do Calico aplicado."

kubectl rollout status \
  daemonset/calico-node \
  -n kube-system \
  --timeout=300s

echo "Calico inicializado."