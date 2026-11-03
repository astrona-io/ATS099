#!/usr/bin/env bash
# PASS when a POST to the Receiver path changes the reconcile annotation of GitRepository flux-system.
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

path="$(kubectl -n flux-system get receiver fleet-push -o jsonpath='{.status.webhookPath}' 2>/dev/null)"
if [ -z "$path" ]; then
  echo "FAIL: Receiver fleet-push has no webhookPath yet."
  exit 1
fi
annotation() {
  kubectl -n flux-system get gitrepository flux-system -o jsonpath='{.metadata.annotations.reconcile\.fluxcd\.io/requestedAt}' 2>/dev/null
}
before="$(annotation)"
sleep 2
if ! kubectl -n gitea exec deploy/tester -- curl -fsS -X POST "http://webhook-receiver.flux-system${path}" >/dev/null 2>&1; then
  echo "FAIL: the POST to http://webhook-receiver.flux-system${path} did not succeed."
  exit 1
fi
for _ in $(seq 1 20); do
  after="$(annotation)"
  if [ -n "$after" ] && [ "$after" != "$before" ]; then
    echo "PASS: the Receiver asked GitRepository flux-system to reconcile."
    exit 0
  fi
  sleep 2
done
echo "FAIL: the annotation reconcile.fluxcd.io/requestedAt of GitRepository flux-system did not change after the POST."
exit 1
