#!/usr/bin/env bash
# OS prep for the "Recover A Cluster From Git" playground (`ats-099-playground-040-01`).
# Environment preparation only. There is no task and no grading.
#
# The same script in every ATS099 environment. It never creates the objects a
# task asks for. It:
#   1. puts the Flux CLI (pinned) on the PATH,
#   2. starts Gitea, the tester pod and the webhook receiver,
#   3. makes gitea.localtest.me resolve to Gitea inside the cluster,
#   4. creates the Gitea user gitops, the private repository gitops/fleet and
#      any extra repositories under manifests/repos (public) and
#      manifests/private-repos (private), seeded with their files,
#   5. bootstraps Flux from gitops/fleet (path clusters/kind) and waits for it.
set -euo pipefail
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

FLUX_VERSION="2.9.6"
GIT_HOST="gitea.localtest.me"
GIT_USER="gitops"
GIT_PASSWORD="gitops-password"
REPO="fleet"
REPO_URL="http://${GIT_HOST}:3000/${GIT_USER}/${REPO}.git"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

# Pin the version rather than accepting whatever flux happens to be on the
# machine: the CLI installs controllers of its own version, and the course is
# written against ${FLUX_VERSION}.
have_version=""
command -v flux >/dev/null 2>&1 && \
  have_version=$(flux version --client 2>/dev/null | awk '/flux:/{print $2}' | sed 's/^v//')
if [ "$have_version" != "$FLUX_VERSION" ]; then
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; esac
  WORK="$(mktemp -d)"
  echo "[playground] Downloading Flux CLI ${FLUX_VERSION} (${OS}/${ARCH})..."
  curl -fsSL "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_${OS}_${ARCH}.tar.gz" \
    | tar -xz -C "$WORK" flux
  install -m 0755 "$WORK/flux" "$BIN_DIR/flux"
  rm -rf "$WORK"
fi
flux version --client

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR=""
for candidate in "$SCRIPT_DIR/../manifests" "./manifests" "$SCRIPT_DIR/manifests"; do
  [ -d "$candidate" ] && { MANIFEST_DIR="$candidate"; break; }
done

# lab-start.yaml is also listed under bootstrap.manifests in config.yaml, so it
# may already be applied. kubectl apply is idempotent.
echo "[playground] Applying Gitea, the tester pod and the webhook receiver..."
kubectl apply -f "$MANIFEST_DIR/lab-start.yaml"
kubectl -n gitea rollout status deployment/gitea --timeout=300s
kubectl -n gitea rollout status deployment/tester --timeout=300s
kubectl -n monitoring rollout status deployment/webhook-receiver --timeout=300s

# One Git address for the reader's machine and the cluster: gitea.localtest.me
# resolves to 127.0.0.1 on the machine (reached through a port-forward), and
# this CoreDNS rewrite sends the same name to the Gitea Service in the cluster.
if ! kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' | grep -q "$GIT_HOST"; then
  echo "[playground] Adding the CoreDNS rewrite for ${GIT_HOST}..."
  # The answer is rewritten back to the asked name: Go programs such as the
  # Flux controllers ignore DNS answers whose name differs from the question.
  COREFILE="$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' \
    | awk '/^[[:space:]]*kubernetes / && !done {
        print "    rewrite stop {"
        print "        name regex gitea\\.localtest\\.me gitea-http.gitea.svc.cluster.local"
        print "        answer name gitea-http\\.gitea\\.svc\\.cluster\\.local gitea.localtest.me"
        print "    }"
        done=1
      } {print}')"
  kubectl -n kube-system create configmap coredns --from-literal=Corefile="$COREFILE" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n kube-system rollout restart deployment/coredns
  kubectl -n kube-system rollout status deployment/coredns --timeout=120s
fi

gitea_api() {
  # gitea_api METHOD PATH [JSON]: calls the Gitea API from the tester pod.
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    printf '%s' "$body" | kubectl -n gitea exec -i deploy/tester -- \
      curl -fsS -u "$GIT_USER:$GIT_PASSWORD" -X "$method" -H 'Content-Type: application/json' \
      --data-binary @- "http://gitea-http.gitea:3000/api/v1$path"
  else
    kubectl -n gitea exec deploy/tester -- \
      curl -fsS -u "$GIT_USER:$GIT_PASSWORD" -X "$method" "http://gitea-http.gitea:3000/api/v1$path"
  fi
}

seed_repository() {
  # seed_repository NAME PRIVATE DIR: creates gitops/NAME and commits every file in DIR.
  local name="$1" private="$2" dir="$3" file content
  gitea_api GET "/repos/$GIT_USER/$name" >/dev/null 2>&1 || \
    gitea_api POST "/user/repos" "{\"name\":\"$name\",\"auto_init\":true,\"default_branch\":\"main\",\"private\":$private}" >/dev/null
  [ -d "$dir" ] || return 0
  (cd "$dir" && find . -type f | sed 's|^\./||' | sort) | while read -r file; do
    gitea_api GET "/repos/$GIT_USER/$name/contents/$file" >/dev/null 2>&1 && continue
    content="$(base64 < "$dir/$file" | tr -d '\n')"
    gitea_api POST "/repos/$GIT_USER/$name/contents/$file" \
      "{\"content\":\"$content\",\"message\":\"Add $file\",\"branch\":\"main\"}" >/dev/null
  done
}

echo "[playground] Creating the Gitea user ${GIT_USER} and the repositories..."
# Gitea can refuse the first commands while it finishes starting, so retry
# until the user exists; fail here rather than later at the first clone.
gitea_user_ready=false
for _ in $(seq 1 30); do
  kubectl -n gitea exec deploy/gitea -- gitea admin user create \
    --username "$GIT_USER" --password "$GIT_PASSWORD" --email gitops@example.com \
    --admin --must-change-password=false >/dev/null 2>&1 && { gitea_user_ready=true; break; }
  kubectl -n gitea exec deploy/gitea -- gitea admin user list 2>/dev/null \
    | awk 'NR > 1 {print $2}' | grep -x "$GIT_USER" >/dev/null && { gitea_user_ready=true; break; }
  sleep 2
done
[ "$gitea_user_ready" = true ] || { echo "ERROR: could not create the Gitea user $GIT_USER." >&2; exit 1; }
seed_repository "$REPO" true "$MANIFEST_DIR/repo"
for dir in "$MANIFEST_DIR"/repos/*/; do
  [ -d "$dir" ] && seed_repository "$(basename "$dir")" false "$dir"
done
for dir in "$MANIFEST_DIR"/private-repos/*/; do
  [ -d "$dir" ] && seed_repository "$(basename "$dir")" true "$dir"
done

if ! kubectl -n flux-system get kustomization flux-system >/dev/null 2>&1; then
  # flux bootstrap clones and pushes from this machine, so Gitea must answer at
  # http://gitea.localtest.me:3000 here. The port-forward stops when this
  # script ends. A real Git server uses HTTPS or SSH; plain HTTP is lab-only.
  kubectl -n gitea port-forward svc/gitea-http 3000:3000 >/dev/null 2>&1 &
  PORT_FORWARD_PID=$!
  trap 'kill "$PORT_FORWARD_PID" 2>/dev/null || true' EXIT
  reachable=false
  # Only Gitea's own health answer counts: another program on port 3000
  # (a dev server, Grafana) answers too, and Flux would then talk to it.
  for _ in $(seq 1 30); do
    case "$(curl -fsS "http://${GIT_HOST}:3000/api/healthz" 2>/dev/null)" in *'"status"'*pass*) true ;; *) false ;; esac && { reachable=true; break; }
    sleep 1
  done
  if [ "$reachable" != true ]; then
    echo "[playground] ERROR: Gitea does not answer at http://${GIT_HOST}:3000 on this machine." >&2
    echo "[playground] If 127.0.0.1:3000 works, add this line to /etc/hosts and start again: 127.0.0.1 ${GIT_HOST}" >&2
    exit 1
  fi
  echo "[playground] Bootstrapping Flux from ${REPO_URL}..."
  flux bootstrap git \
    --url="$REPO_URL" \
    --branch=main \
    --path=clusters/kind \
    --username="$GIT_USER" \
    --password="$GIT_PASSWORD" \
    --token-auth=true \
    --allow-insecure-http=true \
    --silent
fi

kubectl -n flux-system wait kustomization/flux-system --for=condition=Ready --timeout=300s
if [ -f "$MANIFEST_DIR/repo/clusters/kind/podinfo.yaml" ]; then
  for _ in $(seq 1 60); do
    kubectl -n flux-system get kustomization podinfo >/dev/null 2>&1 && break
    sleep 2
  done
  kubectl -n flux-system wait kustomization/podinfo --for=condition=Ready --timeout=300s
fi
echo "[playground] Flux manages the cluster from gitops/fleet."

echo "[playground] Ready."
flux get kustomizations -A || true
echo "[playground] Start the port-forward in a second terminal before you use git:"
echo "  kubectl -n gitea port-forward svc/gitea-http 3000:3000"
