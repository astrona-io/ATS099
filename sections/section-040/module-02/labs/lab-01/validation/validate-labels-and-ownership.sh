#!/usr/bin/env bash
# PASS when both restored Secrets keep the label dr-backup=critical and carry no Flux ownership labels.
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

for NAME in app-credentials registry-auth; do
  LABEL="$(kubectl -n podinfo get secret "$NAME" -o jsonpath='{.metadata.labels.dr-backup}' 2>/dev/null)"
  if [ "$LABEL" != "critical" ]; then
    echo "FAIL: the Secret $NAME must have the label dr-backup=critical, as in the backup (found '$LABEL')."
    exit 1
  fi
  OWNER="$(kubectl -n podinfo get secret "$NAME" -o jsonpath='{.metadata.labels.kustomize\.toolkit\.fluxcd\.io/name}' 2>/dev/null)"
  if [ -n "$OWNER" ]; then
    echo "FAIL: the Secret $NAME is owned by the Flux Kustomization '$OWNER'. It must stay outside Flux."
    exit 1
  fi
done
echo "PASS: the labels are kept and Flux does not own the Secrets."
exit 0
