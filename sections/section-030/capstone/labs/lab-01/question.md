# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** Remote clusters

## Scenario

The Flux `Kustomization` `podinfo-staging` in `flux-system` is supposed to deliver `./apps/podinfo-staging` to the staging cluster through the kubeconfig in the Secret `staging-kubeconfig`. It was set up weeks ago and has never been `Ready`. On the staging side, Flux signs in as the ServiceAccount `flux-deployer` in `staging-access`, which has a Role named `deployer` in `podinfo-staging`. In this capstone the "staging cluster" is the same API server, reached at `https://kubernetes.default.svc`.

The repository is `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only).

## Your task

1. Find every reason `podinfo-staging` cannot deliver. Read its status and events, the Secret and the Role. There is more than one.
2. Fix them so that podinfo, with its Deployment and its Service, is applied through the kubeconfig.

## Constraints

- **Keep `flux-deployer` limited to `podinfo-staging`.** Grant only what the delivered objects need. No ClusterRoleBinding may name it.
- Keep delivering through `staging-kubeconfig`. Do not remove `spec.kubeConfig`.
- Do not commit the kubeconfig to Git.

## Done when

- `staging-kubeconfig` holds, under the key the `Kustomization` reads, a kubeconfig for `https://kubernetes.default.svc` whose token signs in as `flux-deployer`.
- `podinfo-staging` is `Ready` and still points at `staging-kubeconfig`.
- podinfo runs in `podinfo-staging`, and its Deployment and Service are in the `Kustomization`'s inventory.
- `flux-deployer` still cannot create ClusterRoles or Deployments in `podinfo`.
