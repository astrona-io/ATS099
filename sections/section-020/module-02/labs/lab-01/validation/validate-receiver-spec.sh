#!/usr/bin/env bash
# PASS when Receiver fleet-push is Ready, generic, uses receiver-token and targets GitRepository flux-system.
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

if ! kubectl -n flux-system get receiver fleet-push >/dev/null 2>&1; then
  echo "FAIL: there is no Receiver fleet-push in flux-system."
  exit 1
fi
type="$(kubectl -n flux-system get receiver fleet-push -o jsonpath='{.spec.type}')"
if [ "$type" != "generic" ]; then
  echo "FAIL: Receiver fleet-push has type '$type', expected generic."
  exit 1
fi
secret="$(kubectl -n flux-system get receiver fleet-push -o jsonpath='{.spec.secretRef.name}')"
if [ "$secret" != "receiver-token" ]; then
  echo "FAIL: Receiver fleet-push uses the Secret '$secret', expected receiver-token."
  exit 1
fi
token="$(kubectl -n flux-system get secret receiver-token -o jsonpath='{.data.token}' 2>/dev/null)"
if [ -z "$token" ]; then
  echo "FAIL: the Secret receiver-token in flux-system has no key token."
  exit 1
fi
targets="$(kubectl -n flux-system get receiver fleet-push -o jsonpath='{range .spec.resources[*]}{.kind}/{.name}{"\n"}{end}')"
if ! printf '%s\n' "$targets" | grep -qx 'GitRepository/flux-system'; then
  echo "FAIL: Receiver fleet-push does not list GitRepository flux-system in spec.resources."
  exit 1
fi
ready="$(kubectl -n flux-system get receiver fleet-push -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')"
path="$(kubectl -n flux-system get receiver fleet-push -o jsonpath='{.status.webhookPath}')"
if [ "$ready" != "True" ] || [ -z "$path" ]; then
  echo "FAIL: Receiver fleet-push is not Ready or has no webhookPath."
  exit 1
fi
echo "PASS: Receiver fleet-push is ready and targets GitRepository flux-system."
exit 0
