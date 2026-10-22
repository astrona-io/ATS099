#!/usr/bin/env bash
# PASS when team-a's Flux Kustomization impersonates team-a, is Ready, and podinfo runs in team-a.
set -uo pipefail

KS="kubectl -n team-a get kustomization team-a"
if ! $KS >/dev/null 2>&1; then
  echo "FAIL: there is no Kustomization team-a in the namespace team-a."
  exit 1
fi
SA="$($KS -o jsonpath='{.spec.serviceAccountName}')"
if [ "$SA" != "team-a" ]; then
  echo "FAIL: Kustomization team-a impersonates '$SA', expected the ServiceAccount 'team-a'."
  exit 1
fi
SOURCE_NS="$($KS -o jsonpath='{.spec.sourceRef.namespace}')"
if [ -n "$SOURCE_NS" ] && [ "$SOURCE_NS" != "team-a" ]; then
  echo "FAIL: Kustomization team-a uses a source in the namespace '$SOURCE_NS'."
  exit 1
fi
READY="$($KS -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')"
if [ "$READY" != "True" ]; then
  echo "FAIL: Kustomization team-a is not Ready."
  $KS
  exit 1
fi
AVAILABLE="$(kubectl -n team-a get deployment podinfo -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
if [ "${AVAILABLE:-0}" -lt 1 ]; then
  echo "FAIL: the podinfo Deployment in team-a has no available replica."
  exit 1
fi
BINDINGS="$(kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .subjects[*]}{.namespace}/{.name}{" "}{end}{"\n"}{end}' | grep ' team-a/team-a' || true)"
if [ -n "$BINDINGS" ]; then
  echo "FAIL: a ClusterRoleBinding grants the ServiceAccount team-a/team-a cluster-wide rights: $BINDINGS"
  exit 1
fi
echo "PASS: team-a reconciles as team-a, and podinfo runs in team-a."
exit 0
