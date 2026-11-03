#!/usr/bin/env bash
# PASS when the team-a Kustomization is Ready and podinfo runs in team-a.
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

ready="$(kubectl -n team-a get kustomization team-a -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
if [ "$ready" != "True" ]; then
  echo "FAIL: Kustomization team-a in team-a is not Ready."
  kubectl -n team-a get kustomization team-a 2>&1 || true
  exit 1
fi
sa="$(kubectl -n team-a get kustomization team-a -o jsonpath='{.spec.serviceAccountName}')"
if [ "$sa" != "team-a" ]; then
  echo "FAIL: Kustomization team-a impersonates '$sa', expected team-a."
  exit 1
fi
available="$(kubectl -n team-a get deployment podinfo -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
if [ "${available:-0}" -lt 1 ]; then
  echo "FAIL: the podinfo Deployment in team-a has no available replica."
  exit 1
fi
echo "PASS: team-a still deploys podinfo."
exit 0
