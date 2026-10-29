#!/usr/bin/env bash
set -euo pipefail
# Executed by SSH on an already reachable control plane. No backend init,
# token generation, installs, apply or Security Group changes.
test "$(kubectl config current-context)" = kubernetes-admin@kubernetes
kubectl wait --for=condition=Ready nodes --all --timeout=60s
READY_COUNT="$(kubectl get nodes --no-headers | awk '$2 == "Ready" {count++} END {print count+0}')"
[[ "$READY_COUNT" -eq 2 ]]
kubectl -n kube-system rollout status daemonset/calico-node --timeout=60s
kubectl -n kube-system rollout status deployment/coredns --timeout=60s
kubectl -n kube-system rollout status deployment/metrics-server --timeout=60s
kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=60s
kubectl get nodes -o wide
kubectl top nodes
