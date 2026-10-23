#!/usr/bin/env bash
# PASS when the podinfo Deployment has the UID it had before Flux was removed and is in podinfo's inventory.
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
