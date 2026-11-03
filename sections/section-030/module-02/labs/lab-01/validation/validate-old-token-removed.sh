#!/usr/bin/env bash
# PASS when the old token Secret is gone and exactly one token Secret remains for flux-deployer.
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

if kubectl -n staging-access get secret flux-deployer-token >/dev/null 2>&1; then
  echo "FAIL: the old token Secret flux-deployer-token still exists. Delete it so the old token stops working."
  exit 1
fi
COUNT="$(kubectl -n staging-access get secrets -o jsonpath='{range .items[?(@.type=="kubernetes.io/service-account-token")]}{.metadata.annotations.kubernetes\.io/service-account\.name}{"\n"}{end}' 2>/dev/null | grep -c '^flux-deployer$' || true)"
if [ "$COUNT" != "1" ]; then
  echo "FAIL: found $COUNT token Secrets for flux-deployer; exactly 1 is expected after the rotation."
  exit 1
fi
echo "PASS: the old token Secret is deleted and one token Secret remains."
exit 0
