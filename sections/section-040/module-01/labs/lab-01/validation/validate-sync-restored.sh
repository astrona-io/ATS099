#!/usr/bin/env bash
# PASS when flux-system syncs gitops/fleet at ./clusters/kind again and both flux-system and podinfo are Ready.
set -uo pipefail

URL="$(kubectl -n flux-system get gitrepository flux-system -o jsonpath='{.spec.url}' 2>/dev/null)"
KS_PATH="$(kubectl -n flux-system get kustomization flux-system -o jsonpath='{.spec.path}' 2>/dev/null)"
if [ "$URL" != "http://gitea.localtest.me:3000/gitops/fleet.git" ] || [ "$KS_PATH" != "./clusters/kind" ]; then
  echo "FAIL: flux-system must sync http://gitea.localtest.me:3000/gitops/fleet.git at ./clusters/kind (url '$URL', path '$KS_PATH')."
  exit 1
fi
for name in flux-system podinfo; do
  READY="$(kubectl -n flux-system get kustomization "$name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
  if [ "$READY" != "True" ]; then
    echo "FAIL: Kustomization $name is not Ready."
    exit 1
  fi
done
echo "PASS: Flux syncs gitops/fleet again, and podinfo is Ready."
exit 0
