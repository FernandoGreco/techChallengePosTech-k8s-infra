#!/usr/bin/env bash
set -euo pipefail

# Executar no control plane, com values/RBAC sem credenciais nesta pasta.
# O Secret deve ser criado separadamente via stdin; nunca passar token ao Helm.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTEXT="kubernetes-admin@kubernetes"
NAMESPACE="grafana-monitoring"
HELM_VERSION="v3.22.1"
CHART_VERSION="4.5.5"
HELM_BIN="${HOME}/.local/bin/helm"

for command in kubectl curl tar sha256sum; do
  command -v "$command" >/dev/null
done
test "$(kubectl config current-context)" = "$CONTEXT"
kubectl --context="$CONTEXT" get secret grafana-cloud-credentials \
  --namespace="$NAMESPACE" -o name >/dev/null

if [[ ! -x "$HELM_BIN" ]] || [[ "$($HELM_BIN version --template '{{.Version}}')" != "$HELM_VERSION" ]]; then
  HELM_TMP="$(mktemp -d)"
  trap 'rm -f "$HELM_TMP/helm.tar.gz" "$HELM_TMP/helm.sha256" "$HELM_TMP/linux-amd64/helm" "$HELM_TMP/linux-amd64/LICENSE" "$HELM_TMP/linux-amd64/README.md"; rmdir "$HELM_TMP/linux-amd64" "$HELM_TMP"' EXIT
  curl -fsSL --connect-timeout 10 --max-time 60 \
    "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" -o "$HELM_TMP/helm.tar.gz"
  curl -fsSL --connect-timeout 10 --max-time 30 \
    "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz.sha256sum" -o "$HELM_TMP/helm.sha256"
  EXPECTED_SHA="$(awk '{print $1}' "$HELM_TMP/helm.sha256")"
  [[ "$EXPECTED_SHA" =~ ^[a-fA-F0-9]{64}$ ]]
  printf '%s  %s\n' "$EXPECTED_SHA" "$HELM_TMP/helm.tar.gz" | sha256sum -c -
  tar -xzf "$HELM_TMP/helm.tar.gz" -C "$HELM_TMP"
  mkdir -p "${HOME}/.local/bin"
  install -m 755 "$HELM_TMP/linux-amd64/helm" "$HELM_BIN"
fi

kubectl --context="$CONTEXT" apply -f "$SCRIPT_DIR/grafana-rbac.yaml"
"$HELM_BIN" upgrade --install grafana-cloud k8s-monitoring \
  --repo https://grafana.github.io/helm-charts \
  --version "$CHART_VERSION" \
  --kube-context "$CONTEXT" \
  --namespace "$NAMESPACE" --create-namespace \
  --values "$SCRIPT_DIR/grafana-lightweight.values.yaml" \
  --wait --timeout 5m --history-max 3

# O Operator cria os pods Alloy depois que o release está pronto.
for attempt in {1..30}; do
  if kubectl --context="$CONTEXT" -n "$NAMESPACE" get daemonset grafana-cloud-alloy-daemon >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl --context="$CONTEXT" -n "$NAMESPACE" rollout status daemonset/grafana-cloud-alloy-daemon --timeout=180s
kubectl --context="$CONTEXT" -n "$NAMESPACE" rollout status daemonset/grafana-cloud-node-exporter --timeout=120s
kubectl --context="$CONTEXT" -n "$NAMESPACE" get pods -o wide
