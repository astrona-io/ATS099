#!/usr/bin/env bash
# PASS when app-credentials and registry-auth exist in podinfo with the values that were backed up.
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

for NAME in app-credentials registry-auth; do
  if ! kubectl -n podinfo get secret "$NAME" >/dev/null 2>&1; then
    echo "FAIL: the Secret $NAME does not exist in the namespace podinfo."
    exit 1
  fi
  WANT="$(kubectl -n gitea get configmap dr-baseline -o jsonpath="{.data.$NAME-sha256}" 2>/dev/null)"
  if [ -z "$WANT" ]; then
    echo "FAIL: the ConfigMap dr-baseline in the namespace gitea is missing. Do not delete it."
    exit 1
  fi
  HAVE="$(kubectl -n podinfo get secret "$NAME" -o jsonpath='{.data.password}' | sha_of)"
  if [ "$HAVE" != "$WANT" ]; then
    echo "FAIL: the Secret $NAME exists but its password is not the one in the backup. Restore it from the backup; do not create a new value."
    exit 1
  fi
done
echo "PASS: both Secrets are back with the backed-up values."
exit 0
