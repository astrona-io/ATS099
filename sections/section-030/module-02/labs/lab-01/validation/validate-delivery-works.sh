#!/usr/bin/env bash
# PASS when the Kustomization podinfo-staging reconciles with the new Secret, podinfo runs, and flux-deployer is still limited to podinfo-staging.
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

SECRET="$(kubectl -n flux-system get kustomization podinfo-staging -o jsonpath='{.spec.kubeConfig.secretRef.name}' 2>/dev/null)"
if [ "$SECRET" != "staging-kubeconfig" ]; then
  echo "FAIL: Kustomization podinfo-staging must still use the Secret staging-kubeconfig (it uses '$SECRET')."
  exit 1
fi
if ! flux reconcile kustomization podinfo-staging -n flux-system --timeout=2m >/dev/null 2>&1; then
  echo "FAIL: reconciling podinfo-staging with the current staging-kubeconfig does not succeed."
  kubectl -n flux-system get kustomization podinfo-staging
  exit 1
fi
STATUS="$(kubectl -n flux-system get kustomization podinfo-staging -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
if [ "$STATUS" != "True" ]; then
  echo "FAIL: Kustomization podinfo-staging is not Ready."
  exit 1
fi
AVAILABLE="$(kubectl -n podinfo-staging get deployment podinfo -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
if [ -z "$AVAILABLE" ] || [ "$AVAILABLE" -lt 1 ]; then
  echo "FAIL: podinfo has no available replica in podinfo-staging."
  exit 1
fi
AS="system:serviceaccount:staging-access:flux-deployer"
if [ "$(kubectl auth can-i create clusterroles --as="$AS" 2>/dev/null)" = "yes" ] || [ "$(kubectl auth can-i create deployments -n podinfo --as="$AS" 2>/dev/null)" = "yes" ]; then
  echo "FAIL: flux-deployer has more rights than before. The rotation must not widen the account."
  exit 1
fi
echo "PASS: the delivery works with the new token and the account is still scoped."
exit 0
