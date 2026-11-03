# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Remote clusters

## Scenario

Flux on this cluster delivers podinfo to the staging cluster through the Secret `staging-kubeconfig` in `flux-system`. The kubeconfig in it holds the long-lived token of the ServiceAccount `flux-deployer`, which is stored in the Secret `flux-deployer-token` in `staging-access`. The security team asks you to rotate that token: the old one must stop working, and the delivery must not stop. In this lab the "staging cluster" is the same API server, reached at `https://kubernetes.default.svc`.

The ConfigMap `rotation-state` in `staging-access` holds a hash of the old token, so the grader can tell a new token from the old one. Do not change or delete it.

## Your task

1. Create a second token Secret named `flux-deployer-token-v2` in `staging-access` for the ServiceAccount `flux-deployer`.
2. Build a new kubeconfig that uses the new token and the same server and CA, and replace the key `value` of the Secret `staging-kubeconfig` in `flux-system`.
3. Make Flux reconcile `podinfo-staging` and confirm that it is `Ready`.
4. Delete the old token Secret `flux-deployer-token`.

## Constraints

- Do not widen the rights of `flux-deployer`. No ClusterRoleBinding may name it.
- Do not commit any token or kubeconfig to Git.
- Do not delete the old token before the new kubeconfig works. The delivery must not stop.

## Done when

- `staging-kubeconfig` holds a token that is not the old one, and that signs in as `staging-access/flux-deployer`.
- The Secret `flux-deployer-token` no longer exists, and `flux-deployer` has exactly one token Secret.
- The Kustomization `podinfo-staging` is `Ready` and reconciles with the new Secret, and podinfo runs in `podinfo-staging`.
- `flux-deployer` still cannot create ClusterRoles or Deployments in `podinfo`.
