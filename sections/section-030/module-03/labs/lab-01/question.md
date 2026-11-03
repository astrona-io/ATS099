# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Environments and promotion

## Scenario

Flux on this cluster delivers podinfo to a staging cluster through the Secret `staging-kubeconfig`. A production cluster has its own account and its own Secret, `production-kubeconfig`, both in `flux-system`, and the folder `apps/podinfo-production` is already in `gitops/fleet`. Nothing delivers production yet. In this lab both "clusters" are the same API server, reached at `https://kubernetes.default.svc`, each with its own namespace and account.

Production must only be applied after staging is healthy. Today the staging Kustomization has no health check, so it is `Ready` as soon as the manifests are applied, and a `dependsOn` on it would not protect production.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Change the Kustomization `podinfo-staging` in `gitops/fleet` so that `Ready` means the application runs.
2. Commit a Kustomization named `podinfo-production` in `flux-system`, in a file under `clusters/kind/`, that applies `./apps/podinfo-production` through `production-kubeconfig`, depends on `podinfo-staging`, prunes, and waits for its own objects.
3. Wait until `podinfo-production` is `Ready` and podinfo runs in `podinfo-production`.

## Constraints

- Do not give either account more rights. No ClusterRoleBinding may name them.
- Do not commit any kubeconfig or token to Git.
- Do not apply the production files yourself; Flux must apply them.

## Done when

- `podinfo-staging` has `wait: true` or `healthChecks`, in Git and in the cluster, and is `Ready`.
- `podinfo-production` is in Git, uses `production-kubeconfig` and `./apps/podinfo-production`, depends on `podinfo-staging`, and is `Ready`.
- podinfo runs in `podinfo-production`, and its Deployment is in the Kustomization's inventory.
- Neither account can change the other environment's namespace.
