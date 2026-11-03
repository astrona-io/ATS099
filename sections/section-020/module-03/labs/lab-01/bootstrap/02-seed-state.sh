#!/usr/bin/env bash
# Creates the starting state for ats-099-lab-020-03.
#
# The shared bootstrap already did the work: Flux runs from gitops/fleet and
# the Kustomization podinfo uses wait: true. Changing it is the task.
set -euo pipefail

echo "[lab] Starting state ready."
flux get kustomizations -A || true
