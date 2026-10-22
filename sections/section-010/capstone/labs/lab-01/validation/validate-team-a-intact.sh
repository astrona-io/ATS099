#!/usr/bin/env bash
# PASS when team-a still reconciles as team-a and podinfo still runs in team-a.
set -uo pipefail

SA="$(kubectl -n team-a get kustomization team-a -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)"
READY="$(kubectl -n team-a get kustomization team-a -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
if [ "$SA" != "team-a" ] || [ "$READY" != "True" ]; then
  echo "FAIL: Kustomization team-a must still impersonate team-a and be Ready (serviceAccountName '$SA', Ready '$READY')."
  exit 1
fi
AVAILABLE="$(kubectl -n team-a get deployment podinfo -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
if [ "${AVAILABLE:-0}" -lt 1 ]; then
  echo "FAIL: podinfo in team-a has no available replica."
  exit 1
fi
echo "PASS: team-a is untouched and still deploys."
exit 0
