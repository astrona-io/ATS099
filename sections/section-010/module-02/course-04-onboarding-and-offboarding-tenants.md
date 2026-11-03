# Onboarding And Offboarding Many Tenants

One tenant is a handful of files. Twenty tenants are twenty handfuls, and the platform team will make mistakes if each one is written by hand. This part shows how to generate a tenant, how to keep every tenant in the same folder shape, and how to remove a tenant without leaving objects behind.

## Generate a tenant with flux create tenant

The command `flux create tenant` writes the Namespace, the ServiceAccount and the RoleBinding of a tenant. It prints them instead of applying them when you add `--export`:

```sh
flux create tenant team-b --with-namespace=team-b --export > tenants/team-b/rbac.yaml
```

Create the folder `tenants/team-b` first. The command labels the objects with `toolkit.fluxcd.io/tenant: team-b`, and it binds the ServiceAccount to `cluster-admin` by default. The `--cluster-role` flag selects another ClusterRole:

```sh
flux create tenant team-b --with-namespace=team-b --cluster-role=admin --export > tenants/team-b/rbac.yaml
```

The label is more than decoration. It lets you find every object of a tenant with `kubectl get all -A -l toolkit.fluxcd.io/tenant=team-b` and lets an admission rule or a policy select the tenant namespaces.

## One folder shape for every tenant

Keep one folder per tenant in the platform repository, with the same files in each. A common shape is a base that holds what every tenant gets, and one overlay per tenant that adds its name, quota size and repository address:

```text
tenants/
  base/
    kustomization.yaml
    rbac.yaml
    quota.yaml
    network-policy.yaml
    sync.yaml
  team-a/
    kustomization.yaml
    patch.yaml
  team-b/
    kustomization.yaml
    patch.yaml
```

The base holds the shared objects with a placeholder name. Each tenant folder has a `kustomization.yaml` that lists `../base`, sets the namespace and patches what differs. With this shape, a new tenant is one new folder of two small files, and a change to the guardrails is one change in the base that reaches every tenant at the next reconciliation.

Build the result locally before you push, so you see what Flux will apply:

```sh
kustomize build tenants/team-b
```

The command prints every object. Read the namespaces and the ServiceAccount names in it. A wrong name here becomes a refused tenant later.

## Offboard a tenant

To remove a tenant, delete its folder from the platform repository and push. The platform `tenants` `Kustomization` has `prune: true`, so Flux deletes the objects that were in the folder: the Namespace, the ServiceAccount, the RoleBinding, the `GitRepository` and the tenant's Flux `Kustomization`.

Deleting the Namespace deletes everything inside it, including the workloads, because Kubernetes removes the contents of a namespace with it. The tenant's Flux `Kustomization` also has `prune: true`, so it removes its own objects when it is deleted, and it does so as the tenant's ServiceAccount. Read the order carefully: if the ServiceAccount or its RoleBinding disappears before the tenant's `Kustomization` finishes pruning, the final cleanup is refused.

## Prune in the right order

Flux deletes pruned objects through the finalizer of the Flux `Kustomization`. The tenant's `Kustomization` is in the namespace that is being deleted, and its ServiceAccount is in the same namespace. When everything is deleted at once, the finalizer can wait on a ServiceAccount that no longer exists, and the namespace stays in `Terminating`.

Avoid this by offboarding in two commits. In the first commit, delete only the tenant's `sync.yaml` and push. Flux then removes the tenant's `GitRepository` and `Kustomization`, and the tenant's `Kustomization` prunes its own objects while the ServiceAccount still exists. Wait until `flux get kustomizations -n team-b` shows nothing. In the second commit, delete the rest of the folder. Check each step:

```sh
flux get kustomizations -A
kubectl get namespace team-b
```

The first command no longer lists a `team-b` object after the first commit. The second command shows `NotFound` after the second one.

## Keep the tenant's data when that is required

A tenant may want its persistent data after the application is removed. Pruning the namespace deletes PersistentVolumeClaims, and the volume follows according to its reclaim policy. Before you offboard, check the policy of the volumes and take a backup first. Marking an object with the annotation `kustomize.toolkit.fluxcd.io/prune: disabled` makes Flux leave it alone when it would otherwise delete it.

## Common pitfalls

> [!WARNING]
> - **Deleting the RoleBinding before the tenant's `Kustomization` is gone.** Pruning then fails and the namespace sticks in `Terminating`.
> - **Copying a tenant folder and forgetting to change a name.** Two tenants with the same ServiceAccount name in different namespaces are fine, but two Flux objects with the same name in the same namespace are not.
> - **Pushing without `kustomize build`.** A wrong namespace in a patch is found only after the push.
> - **Offboarding without checking the volumes.** The data follows the namespace.
