#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

[[ "${CONFIRM_PRODUCTION_HPA:-}" == sim ]] || { echo 'CONFIRM_PRODUCTION_HPA=sim required' >&2; exit 1; }
: "${EXPECTED_CONTROL_PLANE_NODE:?Expected production Control Plane node required}"
: "${EXPECTED_WORKER_NODE:?Expected production Worker node required}"
[[ "$EXPECTED_CONTROL_PLANE_NODE" != "$EXPECTED_WORKER_NODE" ]]
k() { kubectl --request-timeout=15s "$@"; }
[[ "$(k config current-context)" == kubernetes-admin@kubernetes ]]
[[ "$(k get nodes -o name | wc -l | tr -d ' ')" == 2 ]]
for node in "$EXPECTED_CONTROL_PLANE_NODE" "$EXPECTED_WORKER_NODE"; do
  [[ "$(k get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" == True ]]
done
k get --raw /apis/metrics.k8s.io/v1beta1/nodes >/dev/null

namespace=production-hpa-lab
if k get namespace "$namespace" >/dev/null 2>&1; then
  [[ "$(k get namespace "$namespace" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}')" == tc3-production-hpa ]] || {
    echo 'Existing namespace is not owned by this isolated test' >&2; exit 1;
  }
fi
if k -n "$namespace" get job hpa-load-bounded >/dev/null 2>&1; then
  echo 'Load Job already exists; inspect before another test' >&2; exit 1
fi

created_load=false
cleanup() {
  if [[ "$created_load" == true ]]; then
    k -n "$namespace" delete job hpa-load-bounded --ignore-not-found --wait=false
    for attempt in {1..12}; do
      remaining="$(k -n "$namespace" get pods -l job-name=hpa-load-bounded -o name)"
      if [[ -z "$remaining" ]]; then return; fi
      sleep 3
    done
    echo 'Load Pod removal remains pending' >&2
    return 1
  fi
}
trap cleanup EXIT

date -u '+%Y-%m-%dT%H:%M:%SZ'
k apply -k ..
# Short API queries keep each wait bounded even if a watch connection stalls.
for attempt in {1..18}; do
  current="$(k -n "$namespace" get hpa cpu-demo -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}')"
  ready="$(k -n "$namespace" get deployment cpu-demo -o jsonpath='{.status.readyReplicas}')"
  if [[ -n "$current" && "$ready" == 1 ]]; then break; fi
  sleep 5
done
[[ -n "$current" && "$ready" == 1 ]] || { echo 'Baseline metrics/one replica unavailable' >&2; exit 1; }
echo 'HPA_STAGE=baseline'
k -n "$namespace" get hpa,deploy,pods

k create -f load-job.yaml
created_load=true
scaled_up=false
for attempt in {1..36}; do
  ready="$(k -n "$namespace" get deployment cpu-demo -o jsonpath='{.status.readyReplicas}')"
  desired="$(k -n "$namespace" get hpa cpu-demo -o jsonpath='{.status.desiredReplicas}')"
  if [[ "$ready" == 2 && "$desired" == 2 ]]; then scaled_up=true; break; fi
  sleep 5
done
[[ "$scaled_up" == true ]] || { echo 'Scale-up was not observed within the bounded test' >&2; exit 1; }
echo 'HPA_STAGE=scale-up'
k -n "$namespace" get hpa,deploy,pods
k -n "$namespace" top pods
complete=false
for attempt in {1..34}; do
  condition="$(k -n "$namespace" get job hpa-load-bounded -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}')"
  failed="$(k -n "$namespace" get job hpa-load-bounded -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}')"
  if [[ "$condition" == True ]]; then complete=true; break; fi
  [[ "$failed" != True ]] || { echo 'Bounded load Job failed; inspect its events' >&2; exit 1; }
  sleep 5
done
[[ "$complete" == true ]] || { echo 'Bounded load Job did not complete' >&2; exit 1; }
k -n "$namespace" logs job/hpa-load-bounded
cleanup
created_load=false

scaled_down=false
for attempt in {1..36}; do
  ready="$(k -n "$namespace" get deployment cpu-demo -o jsonpath='{.status.readyReplicas}')"
  desired="$(k -n "$namespace" get hpa cpu-demo -o jsonpath='{.status.desiredReplicas}')"
  if [[ "$ready" == 1 && "$desired" == 1 ]]; then scaled_down=true; break; fi
  sleep 5
done
[[ "$scaled_down" == true ]] || { echo 'Scale-down remains pending after load stopped' >&2; exit 1; }
echo 'HPA_STAGE=scale-down'
k -n "$namespace" get hpa,deploy,pods
k -n "$namespace" get events --field-selector reason=SuccessfulRescale --sort-by=.lastTimestamp
date -u '+%Y-%m-%dT%H:%M:%SZ'
echo 'HPA_RESULT=PASS scale=1-2-1 load-job-removed=true'
