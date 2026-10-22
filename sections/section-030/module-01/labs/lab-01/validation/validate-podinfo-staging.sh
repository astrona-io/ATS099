#!/usr/bin/env bash
# PASS when podinfo runs in podinfo-staging and its Deployment and Service are in the Kustomization's inventory.
set -uo pipefail

AVAILABLE="$(kubectl -n podinfo-staging get deployment podinfo -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
if [ "${AVAILABLE:-0}" -lt 1 ]; then
  echo "FAIL: the podinfo Deployment in podinfo-staging has no available replica."
  exit 1
fi
INVENTORY="$(kubectl -n flux-system get kustomization podinfo-staging -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}' 2>/dev/null)"
for id in podinfo-staging_podinfo_apps_Deployment podinfo-staging_podinfo__Service; do
  if ! printf '%s\n' "$INVENTORY" | grep -qx "$id"; then
    echo "FAIL: '$id' is not in the inventory of Kustomization podinfo-staging. Flux did not apply it."
    exit 1
  fi
done
echo "PASS: podinfo runs in podinfo-staging, applied by podinfo-staging."
exit 0
