#!/usr/bin/env bash
# PASS when podinfo runs in podinfo-staging and its Deployment and Service are in the Kustomization's inventory.
set -uo pipefail
# grep -q stops reading at the first match; under pipefail the command
# writing into the pipe then fails with SIGPIPE and a match looks like a
# failure. This wrapper reads all input instead and keeps grep's exit status.
grep() {
  local arg quiet=0 args=()
  for arg in "$@"; do
    case "$arg" in
      --quiet|--silent) quiet=1 ;;
      --*) args+=("$arg") ;;
      -*q*) quiet=1; [ "$arg" = "-q" ] || args+=("${arg//q/}") ;;
      *) args+=("$arg") ;;
    esac
  done
  if [ "$quiet" = 1 ]; then command grep "${args[@]}" >/dev/null; else command grep "$@"; fi
}

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
