#!/usr/bin/env bash
# Creates the starting state for ats-099-capstone-040.
#
# Builds a healthy cluster with a second, private source (gitops/private-config,
# read with the Secret private-config-auth, which is not in Git), then:
#   1. commits `suspend: true` to clusters/kind/podinfo.yaml, as a maintenance
#      window would, and never takes it out;
#   2. records the UIDs of the podinfo Deployment and the private-settings
#      ConfigMap in the ConfigMap dr-baseline (namespace gitea);
#   3. runs `flux uninstall` without --keep-namespace, so the flux-system
#      namespace and every Secret in it are gone.
# Bringing Flux back is the task. Nothing here does it.
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

echo "[lab] Adding the private source gitops/private-config..."
flux create secret git private-config-auth \
  --url="http://${GIT_HOST}:3000/${GIT_USER}/private-config.git" \
  --username="$GIT_USER" --password="$GIT_PASSWORD"
put_file fleet clusters/kind/private-config.yaml "Add the private configuration source" <<'YAML'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: private-config
  namespace: flux-system
spec:
  interval: 1m
  url: http://gitea.localtest.me:3000/gitops/private-config.git
  ref:
    branch: main
  secretRef:
    name: private-config-auth
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: private-config
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: private-config
  path: ./app
  prune: true
  dependsOn:
    - name: podinfo
YAML
sync_now
wait_ready kustomization flux-system private-config
kubectl -n podinfo get configmap private-settings

echo "[lab] Committing a maintenance suspend that nobody takes out..."
put_file fleet clusters/kind/podinfo.yaml "Pause podinfo for maintenance" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo
  namespace: flux-system
spec:
  suspend: true
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./apps/podinfo
  prune: true
  wait: true
  timeout: 3m
YAML
sync_now

kubectl -n gitea create configmap dr-baseline \
  --from-literal=podinfo-deployment="$(kubectl -n podinfo get deployment podinfo -o jsonpath='{.metadata.uid}')" \
  --from-literal=private-settings="$(kubectl -n podinfo get configmap private-settings -o jsonpath='{.metadata.uid}')" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[lab] Uninstalling Flux together with the flux-system namespace..."
flux uninstall --silent
for _ in $(seq 1 90); do
  kubectl get namespace flux-system >/dev/null 2>&1 || break
  sleep 2
done
echo "[lab] Starting state ready. Flux and the flux-system namespace are gone; the workloads still run."
