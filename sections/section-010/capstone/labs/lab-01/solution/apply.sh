#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the capstone stays broken for the student.
# Taken from solution.md - if one changes, change the other.
#
# All three faults are fixed in Git, in the tenant's folder. The lockdown and
# team-a stay exactly as they are.
set -euo pipefail

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

put_file fleet tenants/team-b/rbac.yaml "Bind team-b's own ServiceAccount" <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: team-b
  labels:
    toolkit.fluxcd.io/tenant: team-b
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: team-b
  namespace: team-b
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-b-reconciler
  namespace: team-b
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: team-b
    namespace: team-b
YAML

put_file fleet tenants/team-b/source.yaml "Move team-b's source into team-b" <<'YAML'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: team-b
  namespace: team-b
spec:
  interval: 1m
  url: http://gitea.localtest.me:3000/gitops/team-b.git
  ref:
    branch: main
YAML

put_file fleet tenants/team-b/sync.yaml "Run team-b as team-b, from its own source" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: team-b
  namespace: team-b
spec:
  interval: 5m
  serviceAccountName: team-b
  sourceRef:
    kind: GitRepository
    name: team-b
  path: ./app
  targetNamespace: team-b
  prune: true
YAML

sync_now
wait_ready kustomization flux-system tenants
flux reconcile source git team-b -n team-b >/dev/null 2>&1 || true
flux reconcile kustomization team-b -n team-b >/dev/null 2>&1 || true
wait_ready kustomization team-b team-b
kubectl -n team-b rollout status deployment/podinfo --timeout=300s
