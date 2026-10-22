#!/usr/bin/env bash
# PASS when the podinfo Deployment has the UID it had before Flux was removed and is in podinfo's inventory.
set -uo pipefail

BEFORE="$(kubectl -n gitea get configmap dr-baseline -o jsonpath='{.data.podinfo-deployment}' 2>/dev/null)"
NOW="$(kubectl -n podinfo get deployment podinfo -o jsonpath='{.metadata.uid}' 2>/dev/null)"
if [ -z "$BEFORE" ]; then
  echo "FAIL: the baseline ConfigMap dr-baseline in gitea is missing; it must not be deleted."
  exit 1
fi
if [ "$NOW" != "$BEFORE" ]; then
  echo "FAIL: the podinfo Deployment was deleted and created again (UID $BEFORE before, ${NOW:-none} now). Recovery must not touch the workloads."
  exit 1
fi
INVENTORY="$(kubectl -n flux-system get kustomization podinfo -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}' 2>/dev/null)"
if ! printf '%s\n' "$INVENTORY" | grep -qx 'podinfo_podinfo_apps_Deployment'; then
  echo "FAIL: the podinfo Deployment is not in the inventory of Kustomization podinfo; Flux has not adopted it."
  exit 1
fi
echo "PASS: Flux adopted the same podinfo Deployment (UID $NOW)."
exit 0
