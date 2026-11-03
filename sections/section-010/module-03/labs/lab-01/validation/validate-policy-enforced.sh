#!/usr/bin/env bash
# PASS when a server-side dry run of a Kustomization without a ServiceAccount is rejected in team-a and one with a ServiceAccount is accepted.
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

manifest() {
  cat <<YAML
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: grader-probe
  namespace: team-a
spec:
  interval: 5m
  $1
  sourceRef:
    kind: GitRepository
    name: team-a
  path: ./app
  targetNamespace: team-a
YAML
}
rejected=false
for _ in $(seq 1 30); do
  if ! manifest "" | kubectl apply --dry-run=server -f - >/dev/null 2>&1; then rejected=true; break; fi
  sleep 2
done
if [ "$rejected" != true ]; then
  echo "FAIL: a Kustomization without serviceAccountName was accepted in team-a."
  exit 1
fi
if ! manifest "serviceAccountName: team-a" | kubectl apply --dry-run=server -f - >/dev/null 2>&1; then
  echo "FAIL: a Kustomization with serviceAccountName: team-a was rejected in team-a."
  exit 1
fi
echo "PASS: the API server rejects a tenant Kustomization without a ServiceAccount and accepts one with it."
exit 0
