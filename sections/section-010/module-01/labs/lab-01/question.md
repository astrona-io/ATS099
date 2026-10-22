# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Multi-tenancy

## Scenario

The platform team runs Flux from the repository `gitops/fleet`, path `clusters/kind`, and deploys its own `podinfo` from it. A new team, `team-a`, keeps its application in the public repository `gitops/team-a`, in the folder `./app`. The files in `./app` name no namespace.

Before `team-a` gets access, the security review asks for two things: the Flux controllers must be locked down for tenants, and `team-a` must be onboarded so that Flux applies its files with `team-a`'s own rights.

Both repositories are at `http://gitea.localtest.me:3000/gitops/<name>.git`, user `gitops`, password `gitops-password` (lab-only). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

All changes go through Git, in `gitops/fleet`:

1. Lock the controllers down in `clusters/kind/flux-system/kustomization.yaml`: `--no-cross-namespace-refs=true`, `--no-remote-bases=true` on kustomize-controller, `--default-service-account=default` on kustomize-controller and helm-controller, and `serviceAccountName: kustomize-controller` on the `flux-system` Kustomization.
2. Keep the platform's `podinfo` Kustomization working under the lockdown.
3. Onboard `team-a`: the namespace `team-a`, a ServiceAccount `team-a` in it, a RoleBinding that gives that ServiceAccount rights in `team-a` only, a `GitRepository` named `team-a` in `team-a` for the tenant repository, and a Flux `Kustomization` named `team-a` in `team-a` that applies `./app` into `team-a` as the ServiceAccount `team-a`.

## Constraints

- **Do not grant `team-a` any right outside its namespace.** No ClusterRoleBinding may name the ServiceAccount `team-a`.
- Do not change `gotk-components.yaml`, and do not edit the controllers with `kubectl`. The lockdown must come from Git.
- The tenant's `Kustomization` must use the tenant's own `GitRepository`, in `team-a`.

## Done when

- The lockdown patches are in Git, the controllers run with the flags, and the `flux-system` and `podinfo` Kustomizations are `Ready`.
- The `team-a` Kustomization impersonates `team-a`, is `Ready`, and podinfo runs in the namespace `team-a`.
- A Flux `Kustomization` that impersonates `team-a` cannot create the ClusterRole in `./escalate`. The grader tests this with its own temporary object.
