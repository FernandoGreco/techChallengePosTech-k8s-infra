#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes >/dev/null || {
  echo "Metrics Server indisponível: corrija antes do teste"; exit 1;
}
kubectl apply -f hpa-lab.yaml
kubectl -n hpa-lab rollout status deployment/cpu-demo --timeout=180s
kubectl -n hpa-lab delete pod gerador-carga --ignore-not-found --wait=true
kubectl -n hpa-lab run gerador-carga --image=busybox:1.36 --restart=Never --   /bin/sh -c 'while true; do wget -q -O- http://cpu-demo.hpa-lab.svc.cluster.local >/dev/null; done'
echo "Em outro terminal: kubectl -n hpa-lab get hpa,pods -w"
echo "Aguarde alguns minutos para o HPA reagir; a escala não é instantânea."
echo "Para parar: bash tests/hpa-limpar.sh (a partir da raiz)"
