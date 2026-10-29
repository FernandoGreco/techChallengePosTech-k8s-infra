#!/usr/bin/env bash
set -euo pipefail
CONTEXT="kubernetes-admin@kubernetes"
test "$(kubectl config current-context)" = "$CONTEXT"
KUBECTL=(kubectl --context="$CONTEXT")
echo "=== Cluster e recursos ==="
"${KUBECTL[@]}" get nodes
"${KUBECTL[@]}" top nodes
echo "=== Namespace de monitoramento ==="
"${KUBECTL[@]}" -n grafana-monitoring get pods -o wide
"${KUBECTL[@]}" -n grafana-monitoring top pods --containers
echo "=== Helm releases ==="
HELM_BIN="$(command -v helm || true)"
HELM_BIN="${HELM_BIN:-${HOME}/.local/bin/helm}"
if [[ -x "$HELM_BIN" ]]; then
  "$HELM_BIN" list --kube-context "$CONTEXT" -n grafana-monitoring
else
  echo "Helm ausente neste host: validação de release não executada"
fi
echo "=== Eventos recentes ==="
"${KUBECTL[@]}" -n grafana-monitoring get events --sort-by=.lastTimestamp \
  -o custom-columns=TYPE:.type,REASON:.reason,OBJECT:.involvedObject.name | tail -15
echo "Confirme ingestao com validar-cloud.ps1 ou consultas no portal Grafana Cloud."
