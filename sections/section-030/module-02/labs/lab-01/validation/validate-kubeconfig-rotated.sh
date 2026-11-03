#!/usr/bin/env bash
# PASS when staging-kubeconfig holds a token that is not the old token and that signs in as staging-access/flux-deployer.
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

sha_of() {
  # sha_of: prints the SHA-256 of standard input.
  if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1
}

KC="$(kubectl -n flux-system get secret staging-kubeconfig -o jsonpath='{.data.value}' 2>/dev/null | base64 --decode 2>/dev/null)"
if [ -z "$KC" ]; then
  echo "FAIL: Secret staging-kubeconfig in flux-system has no key 'value'."
  exit 1
fi
TOKEN="$(printf '%s\n' "$KC" | sed -n 's/^ *token: *//p' | head -n 1)"
if [ -z "$TOKEN" ]; then
  echo "FAIL: the kubeconfig in staging-kubeconfig has no token entry."
  exit 1
fi
OLD_HASH="$(kubectl -n staging-access get configmap rotation-state -o jsonpath='{.data.old-token-sha256}' 2>/dev/null)"
if [ -z "$OLD_HASH" ]; then
  echo "FAIL: ConfigMap rotation-state in staging-access is missing. Do not delete it."
  exit 1
fi
if [ "$(printf '%s' "$TOKEN" | sha_of)" = "$OLD_HASH" ]; then
  echo "FAIL: staging-kubeconfig still holds the old token. Put the new token in the kubeconfig."
  exit 1
fi
REVIEW="$(kubectl create -o jsonpath='{.status.authenticated} {.status.user.username}' -f - <<EOF 2>/dev/null
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: ${TOKEN}
EOF
)"
if [ "$REVIEW" != "true system:serviceaccount:staging-access:flux-deployer" ]; then
  echo "FAIL: the token in staging-kubeconfig does not sign in as staging-access/flux-deployer (TokenReview answered: '$REVIEW')."
  exit 1
fi
echo "PASS: staging-kubeconfig holds a new, valid token for flux-deployer."
exit 0
