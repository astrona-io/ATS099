#!/usr/bin/env bash
# Creates the starting state for ats-099-capstone-010.
#
# Locks the controllers down, onboards team-a correctly, and onboards team-b
# with three faults, all in Git:
#   1. Kustomization team-b sets no serviceAccountName, so under
#      --default-service-account=default it runs as team-b/default, which may
#      do nothing;
#   2. the RoleBinding in team-b names the ServiceAccount team-b in the
#      namespace team-a, so it grants nothing to team-b/team-b;
#   3. Kustomization team-b uses a GitRepository in flux-system, which
#      --no-cross-namespace-refs refuses.
# Repairing all three is the task. Nothing here repairs them.
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

echo "[lab] Locking the controllers down..."
put_file fleet clusters/kind/flux-system/kustomization.yaml "Lock Flux down for tenants" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - gotk-components.yaml
  - gotk-sync.yaml
patches:
  - patch: |
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --no-cross-namespace-refs=true
    target:
      kind: Deployment
      name: "(kustomize-controller|helm-controller|notification-controller|image-reflector-controller|image-automation-controller)"
  - patch: |
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --no-remote-bases=true
    target:
      kind: Deployment
      name: "kustomize-controller"
  - patch: |
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --default-service-account=default
    target:
      kind: Deployment
      name: "(kustomize-controller|helm-controller)"
  - patch: |
      - op: add
        path: /spec/serviceAccountName
        value: kustomize-controller
    target:
      kind: Kustomization
      name: "flux-system"
YAML

put_file fleet clusters/kind/podinfo.yaml "Run podinfo as kustomize-controller" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 5m
  serviceAccountName: kustomize-controller
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./apps/podinfo
  prune: true
  wait: true
  timeout: 3m
YAML

echo "[lab] Onboarding team-a..."
put_file fleet tenants/team-a/rbac.yaml "Onboard team-a: RBAC" <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: team-a
  labels:
    toolkit.fluxcd.io/tenant: team-a
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: team-a
  namespace: team-a
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-a-reconciler
  namespace: team-a
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: team-a
    namespace: team-a
YAML

put_file fleet tenants/team-a/sync.yaml "Onboard team-a: sync" <<'YAML'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: team-a
  namespace: team-a
spec:
  interval: 1m
  url: http://gitea.localtest.me:3000/gitops/team-a.git
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: team-a
  namespace: team-a
spec:
  interval: 5m
  serviceAccountName: team-a
  sourceRef:
    kind: GitRepository
    name: team-a
  path: ./app
  targetNamespace: team-a
  prune: true
YAML

echo "[lab] Onboarding team-b, with faults..."
put_file fleet tenants/team-b/rbac.yaml "Onboard team-b: RBAC" <<'YAML'
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
    namespace: team-a
YAML

put_file fleet tenants/team-b/source.yaml "Onboard team-b: source" <<'YAML'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: team-b
  namespace: flux-system
spec:
  interval: 1m
  url: http://gitea.localtest.me:3000/gitops/team-b.git
  ref:
    branch: main
YAML

put_file fleet tenants/team-b/sync.yaml "Onboard team-b: sync" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: team-b
  namespace: team-b
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: team-b
    namespace: flux-system
  path: ./app
  targetNamespace: team-b
  prune: true
YAML

put_file fleet clusters/kind/tenants.yaml "Apply the tenants folder" <<'YAML'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: tenants
  namespace: flux-system
spec:
  interval: 5m
  serviceAccountName: kustomize-controller
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./tenants
  prune: true
YAML

sync_now
kubectl -n flux-system rollout status deployment/kustomize-controller --timeout=300s
sync_now
wait_ready kustomization flux-system flux-system
wait_ready kustomization flux-system tenants
wait_ready kustomization team-a team-a
kubectl -n team-a rollout status deployment/podinfo --timeout=300s
flux reconcile kustomization team-b -n team-b >/dev/null 2>&1 || true

echo "[lab] Starting state ready. team-a deploys; team-b does not."
flux get kustomizations -A || true
