#!/usr/bin/env bash
# Creates the starting state for ats-099-lab-030-01.
#
# Creates the "remote cluster" side: the ServiceAccount flux-deployer in
# staging-access, its long-lived token Secret, and a Role in podinfo-staging
# that lets it change Deployments and Services there and nothing else. The
# kubeconfig Secret and the Flux Kustomization that uses it are the task.
set -euo pipefail
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/remote-access.yaml"
for _ in $(seq 1 30); do
  kubectl -n staging-access get secret flux-deployer-token -o jsonpath='{.data.token}' 2>/dev/null | grep -q . && break
  sleep 2
done
echo "[lab] Starting state ready. flux-deployer may change Deployments and Services in podinfo-staging only."
