# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Multi-tenancy

## Scenario

The platform team runs Flux from the repository `gitops/fleet`, path `clusters/kind`. The tenant `team-a` is already onboarded: its Namespace, ServiceAccount and RoleBinding are in the folder `tenants/team-a` of `gitops/fleet`, and its Flux `Kustomization` deploys podinfo from the public repository `gitops/team-a`.

The security review found two problems. The RoleBinding gives `team-a` the ClusterRole `cluster-admin` in its namespace, so the tenant can change or delete any limit the platform sets. And the namespace has no quota and no network policy.

Both repositories are at `http://gitea.localtest.me:3000/gitops/<name>.git`, user `gitops`, password `gitops-password` (lab-only). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

All changes go through Git, in `gitops/fleet`, folder `tenants/team-a`:

1. Give the ServiceAccount `team-a` the ClusterRole `admin` in the namespace `team-a` through a RoleBinding named `team-a-admin`, and remove the RoleBinding to `cluster-admin`.
2. Add a ResourceQuota named `team-a-quota` in `team-a` that allows at most 10 pods.
3. Add a NetworkPolicy named `default-deny-ingress` in `team-a` that selects every pod and blocks all incoming traffic.

## Constraints

- **Do not create a ClusterRoleBinding** for `team-a`.
- Do not change the cluster with `kubectl`. Flux puts back what Git says.
- The tenant must keep deploying: its Flux `Kustomization` stays `Ready`.

## Done when

- No RoleBinding in `team-a` refers to `cluster-admin`, and the ServiceAccount `team-a` can no longer update ResourceQuotas in its namespace.
- The quota and the network policy exist in `team-a`.
- The `team-a` Kustomization is `Ready` and podinfo runs in `team-a`.
