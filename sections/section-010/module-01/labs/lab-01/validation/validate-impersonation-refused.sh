#!/usr/bin/env bash
# PASS when a Flux Kustomization that impersonates team-a cannot create a ClusterRole.
set -uo pipefail

PROBE=grader-escalate
cleanup() {
  kubectl -n team-a delete kustomization "$PROBE" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl delete clusterrole team-a-escalate --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

if ! kubectl -n team-a get gitrepository team-a >/dev/null 2>&1; then
  echo "FAIL: there is no GitRepository team-a in the namespace team-a to test with."
  exit 1
fi

# The grader's own Flux Kustomization: the tenant's source, the tenant's
# ServiceAccount, and a folder that holds a ClusterRole.
kubectl apply -f - >/dev/null <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: grader-escalate
  namespace: team-a
spec:
  interval: 10m
  serviceAccountName: team-a
  sourceRef:
    kind: GitRepository
    name: team-a
  path: ./escalate
  prune: false
YAML

STATUS=""
for _ in $(seq 1 45); do
  STATUS="$(kubectl -n team-a get kustomization "$PROBE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
  [ "$STATUS" = "True" ] || [ "$STATUS" = "False" ] && break
  sleep 2
done

if kubectl get clusterrole team-a-escalate >/dev/null 2>&1; then
  echo "FAIL: a Kustomization running as team-a created the ClusterRole team-a-escalate. The tenant has cluster-wide rights."
  exit 1
fi
if [ "$STATUS" != "False" ]; then
  echo "FAIL: the test Kustomization did not report a refusal (Ready is '$STATUS')."
  exit 1
fi
MESSAGE="$(kubectl -n team-a get kustomization "$PROBE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}')"
echo "PASS: Kubernetes refused the ClusterRole for team-a. Message: ${MESSAGE:0:200}"
exit 0
