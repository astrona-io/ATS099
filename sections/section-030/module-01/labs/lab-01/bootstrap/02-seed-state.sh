#!/usr/bin/env bash
# Creates the starting state for ats-099-lab-030-01.
#
# Creates the "remote cluster" side: the ServiceAccount flux-deployer in
# staging-access, its long-lived token Secret, and a Role in podinfo-staging
# that lets it change Deployments and Services there and nothing else. The
# kubeconfig Secret and the Flux Kustomization that uses it are the task.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/remote-access.yaml"
for _ in $(seq 1 30); do
  kubectl -n staging-access get secret flux-deployer-token -o jsonpath='{.data.token}' 2>/dev/null | grep -q . && break
  sleep 2
done
echo "[lab] Starting state ready. flux-deployer may change Deployments and Services in podinfo-staging only."
