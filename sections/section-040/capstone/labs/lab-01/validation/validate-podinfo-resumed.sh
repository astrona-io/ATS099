#!/usr/bin/env bash
# PASS when podinfo is no longer suspended in Git or in the cluster, is Ready, and kept its Deployment UID.
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
  for _ in $(seq 1 30); do
    curl -fsS "http://${GIT_HOST}:3000/api/healthz" >/dev/null 2>&1 && return 0
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

if read_file fleet clusters/kind/podinfo.yaml 2>/dev/null | grep -qE '^[[:space:]]*suspend:[[:space:]]*true'; then
  echo "FAIL: clusters/kind/podinfo.yaml in Git still says suspend: true."
  exit 1
fi
SUSPENDED="$(kubectl -n flux-system get kustomization podinfo -o jsonpath='{.spec.suspend}' 2>/dev/null)"
if [ "$SUSPENDED" = "true" ]; then
  echo "FAIL: Kustomization podinfo is still suspended in the cluster."
  exit 1
fi
if [ "$(ready_status kustomization flux-system podinfo)" != "True" ]; then
  echo "FAIL: Kustomization podinfo is not Ready."
  exit 1
fi
BEFORE="$(kubectl -n gitea get configmap dr-baseline -o jsonpath='{.data.podinfo-deployment}' 2>/dev/null)"
NOW="$(kubectl -n podinfo get deployment podinfo -o jsonpath='{.metadata.uid}' 2>/dev/null)"
if [ -z "$BEFORE" ] || [ "$NOW" != "$BEFORE" ]; then
  echo "FAIL: the podinfo Deployment is not the one that ran before (UID ${BEFORE:-unknown} before, ${NOW:-none} now)."
  exit 1
fi
echo "PASS: podinfo is resumed through Git, Ready, and the same Deployment."
exit 0
