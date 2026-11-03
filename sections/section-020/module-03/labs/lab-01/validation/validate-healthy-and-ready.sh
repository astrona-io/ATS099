#!/usr/bin/env bash
# PASS when the Kustomization podinfo has Ready and Healthy set to True.
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

ready="$(kubectl -n flux-system get kustomization podinfo -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
healthy="$(kubectl -n flux-system get kustomization podinfo -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}' 2>/dev/null)"
if [ "$ready" != "True" ]; then
  echo "FAIL: the condition Ready of Kustomization podinfo is '$ready', expected True."
  kubectl -n flux-system get kustomization podinfo 2>&1 || true
  exit 1
fi
if [ "$healthy" != "True" ]; then
  echo "FAIL: the condition Healthy of Kustomization podinfo is '$healthy', expected True."
  exit 1
fi
available="$(kubectl -n podinfo get deployment podinfo -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
if [ "${available:-0}" -lt 1 ]; then
  echo "FAIL: the Deployment podinfo in podinfo has no available replica."
  exit 1
fi
echo "PASS: the Kustomization podinfo is Ready and Healthy."
exit 0
