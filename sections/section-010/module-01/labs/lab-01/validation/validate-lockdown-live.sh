#!/usr/bin/env bash
# PASS when the controllers run with the lockdown flags and flux-system runs as kustomize-controller.
set -uo pipefail

args_of() {
  kubectl -n flux-system get deployment "$1" -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null
}

KUSTOMIZE="$(args_of kustomize-controller)"
HELM="$(args_of helm-controller)"
NOTIFICATION="$(args_of notification-controller)"
for flag in --no-cross-namespace-refs=true --no-remote-bases=true --default-service-account=default; do
  printf '%s' "$KUSTOMIZE" | grep -q -- "$flag" || { echo "FAIL: kustomize-controller runs without $flag."; exit 1; }
done
for flag in --no-cross-namespace-refs=true --default-service-account=default; do
  printf '%s' "$HELM" | grep -q -- "$flag" || { echo "FAIL: helm-controller runs without $flag."; exit 1; }
done
printf '%s' "$NOTIFICATION" | grep -q -- --no-cross-namespace-refs=true || {
  echo "FAIL: notification-controller runs without --no-cross-namespace-refs=true."; exit 1; }

SA="$(kubectl -n flux-system get kustomization flux-system -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)"
if [ "$SA" != "kustomize-controller" ]; then
  echo "FAIL: Kustomization flux-system has serviceAccountName '$SA', expected 'kustomize-controller'."
  exit 1
fi
for name in flux-system podinfo; do
  READY="$(kubectl -n flux-system get kustomization "$name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
  if [ "$READY" != "True" ]; then
    echo "FAIL: Kustomization $name in flux-system is not Ready under the lockdown."
    kubectl -n flux-system get kustomization "$name" 2>/dev/null
    exit 1
  fi
done
echo "PASS: the controllers are locked down, and flux-system and podinfo are Ready."
exit 0
