#!/usr/bin/env bash
# PASS when Secret staging-kubeconfig holds a kubeconfig for https://kubernetes.default.svc that signs in as flux-deployer.
set -uo pipefail

KEY="$(kubectl -n flux-system get kustomization podinfo-staging -o jsonpath='{.spec.kubeConfig.secretRef.key}' 2>/dev/null)"
KUBECONFIG_TEXT=""
for key in $KEY value value.yaml; do
  data="$(kubectl -n flux-system get secret staging-kubeconfig -o "jsonpath={.data.${key//./\\.}}" 2>/dev/null)"
  if [ -n "$data" ]; then
    KUBECONFIG_TEXT="$(printf '%s' "$data" | base64 --decode)"
    break
  fi
done
if [ -z "$KUBECONFIG_TEXT" ]; then
  echo "FAIL: Secret staging-kubeconfig in flux-system has no kubeconfig under the key the Kustomization reads (value or value.yaml)."
  exit 1
fi
if ! printf '%s' "$KUBECONFIG_TEXT" | grep -qE 'server: *https://kubernetes\.default\.svc(:443)?/?$'; then
  echo "FAIL: the kubeconfig does not point at https://kubernetes.default.svc."
  exit 1
fi
TOKEN="$(printf '%s\n' "$KUBECONFIG_TEXT" | awk '/^[[:space:]]*token:/{print $2; exit}')"
if [ -z "$TOKEN" ]; then
  echo "FAIL: the kubeconfig has no user token."
  exit 1
fi
USERNAME="$(kubectl create -o jsonpath='{.status.user.username}' -f - 2>/dev/null <<YAML
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: ${TOKEN}
YAML
)"
if [ "$USERNAME" != "system:serviceaccount:staging-access:flux-deployer" ]; then
  echo "FAIL: the kubeconfig's token signs in as '${USERNAME:-nobody}', expected the ServiceAccount staging-access/flux-deployer."
  exit 1
fi
echo "PASS: the kubeconfig signs in as flux-deployer at https://kubernetes.default.svc."
exit 0
