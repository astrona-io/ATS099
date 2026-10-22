#!/usr/bin/env bash
# PASS when team-b's Flux Kustomization impersonates team-b from a source in team-b, is Ready, and podinfo runs in team-b.
set -uo pipefail

KS="kubectl -n team-b get kustomization team-b"
if ! $KS >/dev/null 2>&1; then
  echo "FAIL: there is no Kustomization team-b in the namespace team-b."
  exit 1
fi
SA="$($KS -o jsonpath='{.spec.serviceAccountName}')"
if [ "$SA" != "team-b" ]; then
  echo "FAIL: Kustomization team-b impersonates '$SA', expected the ServiceAccount 'team-b'."
  exit 1
fi
SOURCE_NS="$($KS -o jsonpath='{.spec.sourceRef.namespace}')"
if [ -n "$SOURCE_NS" ] && [ "$SOURCE_NS" != "team-b" ]; then
  echo "FAIL: Kustomization team-b uses a source in the namespace '$SOURCE_NS'."
  exit 1
fi
READY="$($KS -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')"
if [ "$READY" != "True" ]; then
  echo "FAIL: Kustomization team-b is not Ready."
  $KS
  exit 1
fi
AVAILABLE="$(kubectl -n team-b get deployment podinfo -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
if [ "${AVAILABLE:-0}" -lt 1 ]; then
  echo "FAIL: the podinfo Deployment in team-b has no available replica."
  exit 1
fi
BINDINGS="$(kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .subjects[*]}{.namespace}/{.name}{" "}{end}{"\n"}{end}' | grep ' team-b/team-b' || true)"
if [ -n "$BINDINGS" ]; then
  echo "FAIL: a ClusterRoleBinding grants the ServiceAccount team-b/team-b cluster-wide rights: $BINDINGS"
  exit 1
fi
echo "PASS: team-b reconciles as team-b, and podinfo runs in team-b."
exit 0
