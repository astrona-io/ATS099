#!/usr/bin/env bash
# PASS when Kustomization podinfo checks Deployment podinfo, times out after 2m, retries every 1m and wait is not true.
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

k() { kubectl -n flux-system get kustomization podinfo -o jsonpath="$1" 2>/dev/null; }
if ! kubectl -n flux-system get kustomization podinfo >/dev/null 2>&1; then
  echo "FAIL: there is no Kustomization podinfo in flux-system."
  exit 1
fi
if [ "$(k '{.spec.wait}')" = "true" ]; then
  echo "FAIL: spec.wait is true, so spec.healthChecks is ignored."
  exit 1
fi
checks="$(k '{range .spec.healthChecks[*]}{.kind}/{.name}/{.namespace}{"\n"}{end}')"
if ! printf '%s\n' "$checks" | grep -qx 'Deployment/podinfo/podinfo'; then
  echo "FAIL: spec.healthChecks does not list the Deployment podinfo in the namespace podinfo."
  exit 1
fi
case "$(k '{.spec.timeout}')" in
  2m|2m0s) ;;
  *) echo "FAIL: spec.timeout is '$(k '{.spec.timeout}')', expected 2m."; exit 1 ;;
esac
case "$(k '{.spec.retryInterval}')" in
  1m|1m0s) ;;
  *) echo "FAIL: spec.retryInterval is '$(k '{.spec.retryInterval}')', expected 1m."; exit 1 ;;
esac
if [ "$(k '{.spec.prune}')" != "true" ] || [ "$(k '{.spec.path}')" != "./apps/podinfo" ]; then
  echo "FAIL: prune must stay true and path must stay ./apps/podinfo."
  exit 1
fi
echo "PASS: the Kustomization podinfo checks the Deployment podinfo with the new timeout and retry interval."
exit 0
