# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Multi-tenancy

## Scenario

The platform team runs Flux from the repository `gitops/fleet`, path `clusters/kind`. The tenant `team-a` is onboarded: its namespace `team-a` carries the label `toolkit.fluxcd.io/tenant`, and its Flux `Kustomization` impersonates the ServiceAccount `team-a`.

The security review wants tenants to learn about a missing ServiceAccount when they create the object, not after the next reconciliation. A Flux `Kustomization` in a tenant namespace that names no ServiceAccount must be rejected by the Kubernetes API server.

Both repositories are at `http://gitea.localtest.me:3000/gitops/<name>.git`, user `gitops`, password `gitops-password` (lab-only). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

All changes go through Git, in `gitops/fleet`:

1. Add a ValidatingAdmissionPolicy named `flux-tenant-service-account` that matches `CREATE` and `UPDATE` of `kustomizations` in the group `kustomize.toolkit.fluxcd.io` (version `v1`), and rejects an object whose `spec.serviceAccountName` is missing or empty.
2. Add a ValidatingAdmissionPolicyBinding with the same name that denies (`Deny`) violations, in every namespace that has the label `toolkit.fluxcd.io/tenant`.
3. Add the files under `infrastructure/policies/` and a Flux `Kustomization` named `policies` in `flux-system` (file `clusters/kind/policies.yaml`) that applies that folder with `prune: true`.

## Constraints

- The binding must not match namespaces without the tenant label. The platform's own Flux objects in `flux-system` must keep working.
- Do not create the policy with `kubectl`. It must come from Git.
- The tenant `team-a` must stay `Ready`.

## Done when

- The policy and the binding exist, and the `policies` Kustomization is `Ready`.
- A server-side dry run of a `Kustomization` without a ServiceAccount in `team-a` is rejected, and the same object with `serviceAccountName: team-a` is accepted.
- The `flux-system` and `team-a` Kustomizations are `Ready`.
