#!/usr/bin/env bash
# PASS when a podinfo failure reaches the webhook receiver as an error and the recovery sends no info event.
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

# >>> helpers (generated; the same block in every script that needs Git)
GIT_HOST="gitea.localtest.me"
GIT_USER="gitops"
GIT_PASSWORD="${GIT_PASSWORD:-gitops-password}"
GITEA_API="http://gitea-http.gitea:3000/api/v1"
export PATH="/usr/local/bin:$HOME/.local/bin:$PATH"

gitea_api() {
  # gitea_api METHOD PATH [JSON]: calls the Gitea API from the tester pod.
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    printf '%s' "$body" | kubectl -n gitea exec -i deploy/tester -- \
      curl -fsS -u "$GIT_USER:$GIT_PASSWORD" -X "$method" -H 'Content-Type: application/json' \
      --data-binary @- "$GITEA_API$path"
  else
    kubectl -n gitea exec deploy/tester -- \
      curl -fsS -u "$GIT_USER:$GIT_PASSWORD" -X "$method" "$GITEA_API$path"
  fi
}

read_file() {
  # read_file REPOSITORY PATH: prints one file from main.
  kubectl -n gitea exec deploy/tester -- \
    curl -fsS -u "$GIT_USER:$GIT_PASSWORD" "$GITEA_API/repos/$GIT_USER/$1/raw/$2?ref=main"
}

list_files() {
  # list_files REPOSITORY DIRECTORY: prints the file paths in one directory of main.
  kubectl -n gitea exec deploy/tester -- sh -c \
    "curl -fsS -u '$GIT_USER:$GIT_PASSWORD' '$GITEA_API/repos/$GIT_USER/$1/contents/$2?ref=main' | jq -r '.[] | select(.type==\"file\") | .path'"
}

file_sha() {
  # file_sha REPOSITORY PATH: prints the blob SHA of one file, or nothing.
  kubectl -n gitea exec deploy/tester -- sh -c \
    "curl -fsS -u '$GIT_USER:$GIT_PASSWORD' '$GITEA_API/repos/$GIT_USER/$1/contents/$2?ref=main' 2>/dev/null | jq -r '.sha // empty'" || true
}

put_file() {
  # put_file REPOSITORY PATH MESSAGE < CONTENT: creates or updates one file on main.
  local repository="$1" path="$2" message="$3" content sha
  content="$(base64 | tr -d '\n')"
  sha="$(file_sha "$repository" "$path")"
  if [ -n "$sha" ]; then
    gitea_api PUT "/repos/$GIT_USER/$repository/contents/$path" \
      "{\"content\":\"$content\",\"message\":\"$message\",\"branch\":\"main\",\"sha\":\"$sha\"}" >/dev/null
  else
    gitea_api POST "/repos/$GIT_USER/$repository/contents/$path" \
      "{\"content\":\"$content\",\"message\":\"$message\",\"branch\":\"main\"}" >/dev/null
  fi
}

delete_file() {
  # delete_file REPOSITORY PATH MESSAGE: deletes one file on main, if it exists.
  local sha
  sha="$(file_sha "$1" "$2")"
  [ -n "$sha" ] || return 0
  gitea_api DELETE "/repos/$GIT_USER/$1/contents/$2" \
    "{\"sha\":\"$sha\",\"message\":\"$3\",\"branch\":\"main\"}" >/dev/null
}

start_port_forward() {
  # Makes Gitea answer at http://gitea.localtest.me:3000 on this machine until the script ends.
  kubectl -n gitea port-forward svc/gitea-http 3000:3000 >/dev/null 2>&1 &
  PORT_FORWARD_PID=$!
  trap 'kill "$PORT_FORWARD_PID" 2>/dev/null || true' EXIT
  # Only Gitea's own health answer counts: another program on port 3000
  # (a dev server, Grafana) answers too, and Flux would then talk to it.
  for _ in $(seq 1 30); do
    case "$(curl -fsS "http://${GIT_HOST}:3000/api/healthz" 2>/dev/null)" in *'"status"'*pass*) true ;; *) false ;; esac && return 0
    sleep 1
  done
  echo "ERROR: Gitea does not answer at http://${GIT_HOST}:3000. Check the port-forward and /etc/hosts (127.0.0.1 ${GIT_HOST})." >&2
  return 1
}

sync_now() {
  # sync_now: makes Flux fetch gitops/fleet and apply clusters/kind now.
  flux reconcile kustomization flux-system --with-source >/dev/null 2>&1 || true
}

wait_ready() {
  # wait_ready KIND NAMESPACE NAME [SECONDS]: waits for a Flux object to be Ready.
  local seconds="${4:-300}"
  for _ in $(seq 1 60); do
    kubectl -n "$2" get "$1" "$3" >/dev/null 2>&1 && break
    sleep 2
  done
  kubectl -n "$2" wait "$1/$3" --for=condition=Ready --timeout="${seconds}s"
}

ready_status() {
  # ready_status KIND NAMESPACE NAME: prints True, False, Unknown or nothing.
  kubectl -n "$2" get "$1" "$3" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null
}
# <<< helpers

restore() {
  flux resume kustomization flux-system >/dev/null 2>&1 || true
  sync_now
  flux reconcile kustomization podinfo >/dev/null 2>&1 || true
}
trap restore EXIT

receiver_log() {
  kubectl -n monitoring logs deploy/webhook-receiver --since-time="$START" 2>/dev/null
}

# Hold flux-system still, so it does not put the broken path back too early.
flux suspend kustomization flux-system >/dev/null
START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
sleep 2
kubectl -n flux-system patch kustomization podinfo --type merge \
  -p '{"spec":{"path":"./apps/does-not-exist"}}' >/dev/null
flux reconcile kustomization podinfo >/dev/null 2>&1 || true

DELIVERED=false
for _ in $(seq 1 30); do
  LOG="$(receiver_log)"
  if printf '%s' "$LOG" | grep -q 'podinfo' && printf '%s' "$LOG" | grep -qE 'severity.{0,6}error'; then
    DELIVERED=true
    break
  fi
  sleep 2
done
if [ "$DELIVERED" != true ]; then
  echo "FAIL: the podinfo failure did not reach the webhook receiver as an error event."
  exit 1
fi

# Put podinfo back: flux-system re-applies clusters/kind/podinfo.yaml from Git.
restore
trap - EXIT
wait_ready kustomization flux-system podinfo 180 >/dev/null 2>&1 || true
sleep 15
if receiver_log | grep -qE 'severity.{0,6}info'; then
  echo "FAIL: the receiver got info events. The Alert forwards more than errors."
  exit 1
fi
echo "PASS: the failure arrived as an error, and the recovery sent no info event."
exit 0
