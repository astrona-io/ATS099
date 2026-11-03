#!/usr/bin/env bash
# Creates the starting state for ats-099-lab-020-02.
#
# The shared bootstrap already did the work: Flux runs from gitops/fleet with
# podinfo. No Receiver and no token Secret exist. Creating them is the task.
set -euo pipefail

echo "[lab] Starting state ready."
flux get kustomizations -A || true
kubectl -n flux-system get receivers 2>&1 || true
