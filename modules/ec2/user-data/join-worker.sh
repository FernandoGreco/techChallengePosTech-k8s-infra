#!/bin/bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Uso: $0 <control-plane-ip> <token> <ca-cert-hash>"
  exit 1
fi

CONTROL_PLANE_IP="$1"
TOKEN="$2"
CA_CERT_HASH="$3"

if [ -f /etc/kubernetes/kubelet.conf ]; then
  echo "Worker ja associado ao cluster."
  exit 0
fi

kubeadm join "${CONTROL_PLANE_IP}:6443" \
  --token "${TOKEN}" \
  --discovery-token-ca-cert-hash "${CA_CERT_HASH}"

echo "Worker associado ao cluster."