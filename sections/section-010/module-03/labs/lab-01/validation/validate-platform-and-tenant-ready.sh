#!/usr/bin/env bash
# PASS when flux-system, tenants and team-a Kustomizations are Ready.
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

for pair in "flux-system flux-system" "flux-system tenants" "team-a team-a"; do
  set -- $pair
  ready="$(kubectl -n "$1" get kustomization "$2" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
  if [ "$ready" != "True" ]; then
    echo "FAIL: Kustomization $2 in $1 is not Ready."
    exit 1
  fi
done
echo "PASS: the platform and the tenant are Ready."
exit 0
