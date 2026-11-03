#!/usr/bin/env bash
# PASS when podinfo-production is Ready, depends on podinfo-staging, runs in podinfo-production, and both accounts stay scoped.
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

if ! kubectl -n flux-system get kustomization podinfo-production >/dev/null 2>&1; then
  echo "FAIL: Kustomization podinfo-production does not exist in the cluster yet."
  exit 1
fi
SECRET="$(kubectl -n flux-system get kustomization podinfo-production -o jsonpath='{.spec.kubeConfig.secretRef.name}' 2>/dev/null)"
DEPENDS="$(kubectl -n flux-system get kustomization podinfo-production -o jsonpath='{.spec.dependsOn[*].name}' 2>/dev/null)"
KS_PATH="$(kubectl -n flux-system get kustomization podinfo-production -o jsonpath='{.spec.path}' 2>/dev/null)"
if [ "$SECRET" != "production-kubeconfig" ] || [ "$DEPENDS" != "podinfo-staging" ] || [ "${KS_PATH#./}" != "apps/podinfo-production" ]; then
  echo "FAIL: podinfo-production must use production-kubeconfig, apply ./apps/podinfo-production and depend only on podinfo-staging (secret '$SECRET', path '$KS_PATH', dependsOn '$DEPENDS')."
  exit 1
fi
if [ "$(kubectl -n flux-system get kustomization podinfo-production -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" != "True" ]; then
  echo "FAIL: Kustomization podinfo-production is not Ready."
  kubectl -n flux-system get kustomization podinfo-production
  exit 1
fi
AVAILABLE="$(kubectl -n podinfo-production get deployment podinfo -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
if [ -z "$AVAILABLE" ] || [ "$AVAILABLE" -lt 1 ]; then
  echo "FAIL: podinfo has no available replica in podinfo-production."
  exit 1
fi
INVENTORY="$(kubectl -n flux-system get kustomization podinfo-production -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}' 2>/dev/null)"
if ! printf '%s' "$INVENTORY" | grep -q 'podinfo-production_podinfo_apps_Deployment'; then
  echo "FAIL: the Deployment in podinfo-production is not in the inventory. Flux must apply it, not you."
  exit 1
fi
STG="system:serviceaccount:staging-access:flux-deployer"
PRD="system:serviceaccount:production-access:flux-deployer"
if [ "$(kubectl auth can-i create deployments -n podinfo-production --as="$STG" 2>/dev/null)" = "yes" ] || \
   [ "$(kubectl auth can-i create deployments -n podinfo-staging --as="$PRD" 2>/dev/null)" = "yes" ] || \
   [ "$(kubectl auth can-i create clusterroles --as="$PRD" 2>/dev/null)" = "yes" ]; then
  echo "FAIL: an account has more rights than before. Each account must stay inside its own namespace."
  exit 1
fi
echo "PASS: production is delivered after staging, through its own kubeconfig, and both accounts are scoped."
exit 0
