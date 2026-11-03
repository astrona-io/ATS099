#!/usr/bin/env bash
# Runs before the reference solution is applied.
#
# Waits for Gitea, the tester pod, and the Flux controllers that exist. Some
# labs start with Flux uninstalled on purpose, so a missing controller is not
# an error here.
set -eu

kubectl -n gitea rollout status deployment/gitea --timeout=300s
kubectl -n gitea rollout status deployment/tester --timeout=300s
for controller in source-controller kustomize-controller helm-controller notification-controller; do
  if kubectl -n flux-system get deployment "$controller" >/dev/null 2>&1; then
    kubectl -n flux-system rollout status "deployment/$controller" --timeout=300s
  fi
done
for _ in $(seq 1 60); do
  if kubectl -n gitea exec deploy/tester -- \
       curl -fsS http://gitea-http.gitea:3000/api/healthz >/dev/null 2>&1; then
    exit 0
  fi
  sleep 2
done
echo "Gitea did not answer on /api/healthz." >&2
exit 1
