# Overview: Kubeconfig Secrets, Tokens And Remote Rights (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, starts an in-cluster Git server, bootstraps Flux from it, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The Flux command-line tool 2.9.6, and Flux bootstrapped from `gitops/fleet` at the path `clusters/kind`, with podinfo in the namespace `podinfo`.
- Gitea, an in-cluster Git server, with the lab-only user `gitops` and the password `gitops-password`. The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`. It also holds `apps/podinfo-staging/`, podinfo without a Namespace object.
- The "remote cluster" side, which in this playground lives in the same cluster:

  | Object | What it is |
  | --- | --- |
  | ServiceAccount `flux-deployer` in `staging-access` | The account Flux uses on the "remote cluster" |
  | Secret `flux-deployer-token` in `staging-access` | A long-lived token and the CA certificate for that account |
  | Role `deployer` and RoleBinding in `podinfo-staging` | Lets `flux-deployer` change Deployments and Services in `podinfo-staging`, and nothing else |

No kubeconfig Secret and no delivery exist yet. You build them in the first practice task.

To use `git` from your machine, start a port-forward in a second terminal and leave it running. If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

## Helpers

Paste these once in each new terminal. `make_kubeconfig` prints a kubeconfig for `flux-deployer` from a token Secret in `staging-access`. `can_deployer` asks Kubernetes whether `flux-deployer` may do something. `token_valid` asks the API server whether a token is accepted, using a TokenReview.

```sh
make_kubeconfig() {
  local token ca
  token="$(kubectl -n staging-access get secret "$1" -o jsonpath='{.data.token}' | base64 --decode)"
  ca="$(kubectl -n staging-access get secret "$1" -o jsonpath='{.data.ca\.crt}')"
  cat <<YAML
apiVersion: v1
kind: Config
clusters:
  - name: staging
    cluster:
      server: https://kubernetes.default.svc
      certificate-authority-data: ${ca}
users:
  - name: flux-deployer
    user:
      token: ${token}
contexts:
  - name: staging
    context:
      cluster: staging
      user: flux-deployer
      namespace: podinfo-staging
current-context: staging
YAML
}
can_deployer() {
  kubectl auth can-i "$@" --as=system:serviceaccount:staging-access:flux-deployer
}
token_valid() {
  kubectl create -o jsonpath='{.status.authenticated}{"\n"}' -f - <<EOF
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: $1
EOF
}
```

## Practice tasks

- Build the delivery: `make_kubeconfig flux-deployer-token > staging.kubeconfig`, store it with `kubectl -n flux-system create secret generic staging-kubeconfig --from-file=value=staging.kubeconfig`, and apply a `Kustomization` named `podinfo-staging` with `spec.kubeConfig.secretRef.name: staging-kubeconfig` for `./apps/podinfo-staging`.
- Store the kubeconfig under the key `config` and read the error. Then fix it with `spec.kubeConfig.secretRef.key` and not by renaming the key.
- Create a short-lived token with `kubectl -n staging-access create token flux-deployer --duration=10m`, put it in the kubeconfig, and check it with `token_valid`.
- Rotate the long-lived token: create a second token Secret, replace the key in `staging-kubeconfig`, delete `flux-deployer-token`, and check the old token with `token_valid`.
- Take `delete` out of the Role `deployer`, remove `service.yaml` from Git and read the prune error.
- Delete the Kustomization with `prune: true`, and watch what happens to the Deployment. Repeat with `spec.deletionPolicy: Orphan`.
