# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** Multi-tenancy

## Scenario

The cluster runs Flux from `gitops/fleet`, path `clusters/kind`, with the multi-tenancy lockdown switched on. Two tenants are onboarded from the platform repository's `tenants/` folder. `team-a` deploys its podinfo without trouble. `team-b` was onboarded in a hurry from the tenant repository `gitops/team-b` (public, folder `./app`), and its Flux `Kustomization` never becomes `Ready`.

The repositories are at `http://gitea.localtest.me:3000/gitops/<name>.git`, user `gitops`, password `gitops-password` (lab-only). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Find every reason the `team-b` Kustomization in the namespace `team-b` is refused. Use `flux get`, `flux events` and the objects in `tenants/team-b/`. There is more than one.
2. Fix them in Git, in `tenants/team-b/`, so that podinfo runs in the namespace `team-b`.

## Constraints

- **Keep the lockdown.** Do not remove or weaken any controller flag, and do not change `clusters/kind/flux-system/kustomization.yaml`.
- **Do not grant `team-b` any right outside its namespace.** No ClusterRoleBinding may name the ServiceAccount `team-b`.
- `team-b`'s Flux `Kustomization` must impersonate the ServiceAccount `team-b` and use a source in its own namespace.
- Leave `team-a` working as it is.

## Done when

- The controllers still run with the lockdown flags, and the patches are still in Git.
- The `team-b` Kustomization impersonates `team-b`, uses a source in `team-b`, is `Ready`, and podinfo runs in `team-b`.
- A Flux `Kustomization` that impersonates `team-b` cannot create the ClusterRole in `./escalate`.
- `team-a` is still `Ready` and its podinfo still runs.
