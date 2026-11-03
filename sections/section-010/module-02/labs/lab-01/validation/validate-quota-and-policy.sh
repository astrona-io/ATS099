#!/usr/bin/env bash
# PASS when team-a-quota allows 10 pods and default-deny-ingress blocks all ingress in team-a.
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

pods="$(kubectl -n team-a get resourcequota team-a-quota -o jsonpath='{.spec.hard.pods}' 2>/dev/null)"
if [ "$pods" != "10" ]; then
  echo "FAIL: ResourceQuota team-a-quota in team-a does not allow exactly 10 pods (found '${pods}')."
  exit 1
fi
np="default-deny-ingress"
if ! kubectl -n team-a get networkpolicy "$np" >/dev/null 2>&1; then
  echo "FAIL: there is no NetworkPolicy $np in team-a."
  exit 1
fi
selector="$(kubectl -n team-a get networkpolicy "$np" -o jsonpath='{.spec.podSelector}')"
types="$(kubectl -n team-a get networkpolicy "$np" -o jsonpath='{.spec.policyTypes[*]}')"
rules="$(kubectl -n team-a get networkpolicy "$np" -o jsonpath='{.spec.ingress}')"
if [ "$selector" != "{}" ]; then
  echo "FAIL: NetworkPolicy $np does not select every pod (podSelector is '$selector')."
  exit 1
fi
if [ "$types" != "Ingress" ] || [ -n "$rules" ]; then
  echo "FAIL: NetworkPolicy $np must list policyTypes Ingress and no ingress rules."
  exit 1
fi
echo "PASS: the quota and the default-deny policy exist in team-a."
exit 0
