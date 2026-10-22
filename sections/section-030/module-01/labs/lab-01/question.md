# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Remote clusters

## Scenario

The platform wants Flux on this cluster to deliver podinfo to the staging cluster. The staging team created an account for Flux there: the ServiceAccount `flux-deployer` in `staging-access`, with a long-lived token in the Secret `flux-deployer-token` and a Role that lets it change Deployments and Services in `podinfo-staging` only. In this lab the "staging cluster" is the same API server, reached at `https://kubernetes.default.svc`.

The files to deliver are in `gitops/fleet`, folder `./apps/podinfo-staging`. The repository is `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Build a kubeconfig that signs in to `https://kubernetes.default.svc` as `flux-deployer`, with its token and the cluster's CA certificate from `flux-deployer-token`.
2. Store it in a Secret named `staging-kubeconfig` in `flux-system`, where a Flux `Kustomization` reads it.
3. Commit a Flux `Kustomization` named `podinfo-staging` in `flux-system`, in a file under `clusters/kind/`, that applies `./apps/podinfo-staging` through that kubeconfig.

## Constraints

- **Do not give `flux-deployer` any more rights.** No ClusterRoleBinding may name it, and it must still be unable to change other namespaces.
- Do not commit the kubeconfig or the token to Git.
- Do not apply the podinfo files yourself; Flux must apply them through the kubeconfig.

## Done when

- `staging-kubeconfig` holds a kubeconfig for `https://kubernetes.default.svc` whose token signs in as `staging-access/flux-deployer`.
- The `podinfo-staging` Kustomization is in Git, points at `staging-kubeconfig` and `./apps/podinfo-staging`, and is `Ready`.
- podinfo runs in `podinfo-staging`, and its Deployment and Service are in the `Kustomization`'s inventory.
- `flux-deployer` still cannot create ClusterRoles or Deployments in `podinfo`.
