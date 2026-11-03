# Overview: Fleets, Environments And Promotion (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, starts an in-cluster Git server, bootstraps Flux from it, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The Flux command-line tool 2.9.6, and Flux bootstrapped from `gitops/fleet` at the path `clusters/kind`, with podinfo in the namespace `podinfo`.
- Gitea, an in-cluster Git server, with the lab-only user `gitops` and the password `gitops-password`. The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`. It holds `apps/podinfo-staging/` and `apps/podinfo-production/`, both without a Namespace object.
- Two "remote cluster" sides, which in this playground live in the same cluster:

  | Object | What it is |
  | --- | --- |
  | ServiceAccount `flux-deployer` in `staging-access` | The account for staging, limited by a Role to `podinfo-staging` |
  | ServiceAccount `flux-deployer` in `production-access` | The account for production, limited by a Role to `podinfo-production` |
  | Secrets `flux-deployer-token` in each | A long-lived token and the CA certificate of that account |

No kubeconfig Secrets and no deliveries exist yet. You build them in the practice tasks.

To use `git` from your machine, start a port-forward in a second terminal and leave it running. If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

## Helpers

Paste these once in each new terminal. `make_kubeconfig staging` prints a kubeconfig for the staging account, and `make_kubeconfig production` for the production account. `store_kubeconfig` puts it in a Secret in `flux-system` under the key `value`.

```sh
make_kubeconfig() {
  local token ca
  token="$(kubectl -n "$1-access" get secret flux-deployer-token -o jsonpath='{.data.token}' | base64 --decode)"
  ca="$(kubectl -n "$1-access" get secret flux-deployer-token -o jsonpath='{.data.ca\.crt}')"
  cat <<YAML
apiVersion: v1
kind: Config
clusters:
  - name: $1
    cluster:
      server: https://kubernetes.default.svc
      certificate-authority-data: ${ca}
users:
  - name: flux-deployer
    user:
      token: ${token}
contexts:
  - name: $1
    context:
      cluster: $1
      user: flux-deployer
      namespace: podinfo-$1
current-context: $1
YAML
}
store_kubeconfig() {
  make_kubeconfig "$1" | kubectl -n flux-system create secret generic "$1-kubeconfig" \
    --from-file=value=/dev/stdin --dry-run=client -o yaml | kubectl apply -f -
}
```

## Practice tasks

- Run `store_kubeconfig staging` and `store_kubeconfig production`. Then apply two Kustomizations with `spec.kubeConfig`, one per folder.
- Add `dependsOn: [{name: podinfo-staging}]` to production, and break the staging image tag. Watch production wait, then fix the tag.
- Remove `wait: true` from staging, break the image tag again, and see that staging is `Ready` anyway.
- Turn `apps/podinfo-production` into a base plus overlay with `kustomize edit`, or by hand, and point the Kustomization at the overlay.
- Add `postBuild.substitute` with a variable to the production Kustomization and use `${variable}` in the Deployment.
- Run `flux diff kustomization podinfo-production --path ./apps/podinfo-production` from a clone of the repository.
- Suspend and resume `podinfo-production` with `flux suspend` and `flux resume`, and read the SUSPENDED column.
