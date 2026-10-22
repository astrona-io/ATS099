#!/usr/bin/env bash
# PASS when flux-deployer still has no rights outside podinfo-staging.
set -uo pipefail

AS="system:serviceaccount:staging-access:flux-deployer"
if [ "$(kubectl auth can-i create clusterroles --as="$AS" 2>/dev/null)" = "yes" ]; then
  echo "FAIL: flux-deployer may create ClusterRoles. The remote account must stay limited to podinfo-staging."
  exit 1
fi
if [ "$(kubectl auth can-i create deployments -n podinfo --as="$AS" 2>/dev/null)" = "yes" ]; then
  echo "FAIL: flux-deployer may create Deployments in podinfo. It must be limited to podinfo-staging."
  exit 1
fi
BINDINGS="$(kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .subjects[*]}{.namespace}/{.name}{" "}{end}{"\n"}{end}' | grep ' staging-access/flux-deployer' || true)"
if [ -n "$BINDINGS" ]; then
  echo "FAIL: a ClusterRoleBinding grants flux-deployer cluster-wide rights: $BINDINGS"
  exit 1
fi
echo "PASS: flux-deployer is still limited to podinfo-staging."
exit 0
