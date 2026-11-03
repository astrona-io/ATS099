# Summary

A cluster shared by several teams needs a clear line between the people who own it and the people who use part of it. This module drew that line with Flux and Kubernetes role-based access control.

## What you learned

The platform administrator owns the cluster and the platform repository Flux was bootstrapped from. A tenant is a team with its own namespace and its own Git repository. The tenant's Namespace, ServiceAccount, RoleBinding, `GitRepository` and Flux `Kustomization` all live in the platform repository, because whoever controls the RoleBinding controls the rights. A RoleBinding to the ClusterRole `cluster-admin` gives the tenant every right inside its namespace and none outside it; a ClusterRoleBinding would give it the whole cluster. `flux create tenant --export` generates the first three objects, and it is a preview command.

Flux applies a tenant's files with the tenant's rights through impersonation. When a Flux `Kustomization` sets `spec.serviceAccountName`, kustomize-controller sends every object to the API server as that ServiceAccount, looked up in the `Kustomization`'s own namespace. Kubernetes then allows what the account may do and refuses the rest, and the refusal shows up as `Ready` `False` with a "forbidden" message. `targetNamespace` makes the platform, not the tenant's files, decide where the objects land.

Impersonation only protects the cluster when nobody can step around it. The lockdown adds controller flags through patches in `clusters/kind/flux-system/kustomization.yaml`, never in `gotk-components.yaml`. `--default-service-account=default` makes an object without a ServiceAccount run as the empty `default` account. `--no-cross-namespace-refs=true` keeps every object to sources in its own namespace. `--no-remote-bases=true` stops Kustomize from pulling files from a URL. Under the lockdown, every platform Flux `Kustomization` in `flux-system` must name `serviceAccountName: kustomize-controller`. The key facts to remember are these:

- Tenant objects belong in the platform repository; tenant workloads belong in the tenant repository.
- `spec.serviceAccountName` is resolved in the namespace of the Flux object.
- A RoleBinding scopes even `cluster-admin` to one namespace.
- Lock the controllers down in Git, before the first tenant arrives.

Helm-based tenants follow the same rule. A `HelmRelease` has its own `spec.serviceAccountName`, and helm-controller applies the chart as that account, so the account needs the right to write release Secrets in its namespace. The flag `--default-service-account=default` must be set on both kustomize-controller and helm-controller, or one of them still runs tenant objects with its own cluster-wide rights. source-controller and notification-controller write no tenant workloads and need no impersonation.

A refused tenant is diagnosed from its status. `flux get` shows the message, `kubectl describe` shows it in full, `flux events` and `flux logs` show what the controller did, and `kubectl auth can-i --as=system:serviceaccount:<namespace>:<name>` confirms the account's rights. The fix goes in Git, in the repository that owns the faulty object, and never weakens the lockdown.

<!-- astrona:playground:destroy -->
