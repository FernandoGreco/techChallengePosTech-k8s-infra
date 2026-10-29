#!/usr/bin/env bash
set -euo pipefail
kubectl delete namespace hpa-lab --ignore-not-found --wait=true
echo "Namespace hpa-lab excluído."
