# Auditing What Tenants Run

Rules are only useful when you can check that they hold. A platform team needs to answer questions such as: what does `team-a` deploy, which Git commit is it on, and which objects did Flux create on its behalf. Flux has commands for each question, and Kubernetes labels tie the answers together.

## List every Flux object

Start with the objects that drive the cluster. `flux get all -A` lists sources, Kustomizations and Helm releases in all namespaces with their state and revision:

```sh
flux get all -A
```

Look at the `REVISION` column. It shows the Git commit or chart version each object last applied. A tenant whose revision does not move is stuck, and one whose revision moves too often may have a bad interval or a loop in its repository.

## Follow one object to its resources

`flux tree` prints the objects that a Flux `Kustomization` created, as a tree:

```sh
flux tree kustomization team-a -n team-a
```

The tree starts at the `Kustomization`, then lists its Deployments, Services and the other objects from its inventory. Use it to see what a tenant really owns.

The reverse question is "which Flux object manages this Deployment?". `flux trace` answers it:

```sh
flux trace deployment podinfo -n team-a
```

The output names the `Kustomization` that applied the Deployment, its source, the revision and the last reconciliation. Use it when a resource looks wrong and you need to know where its definition lives.

## Labels that identify tenants

Every object that Flux applies from a `Kustomization` carries the labels `kustomize.toolkit.fluxcd.io/name` and `kustomize.toolkit.fluxcd.io/namespace`. These show which Flux object owns it. The label `toolkit.fluxcd.io/tenant`, set on the tenant namespace by `flux create tenant`, marks the tenant itself:

```sh
kubectl get namespaces -l toolkit.fluxcd.io/tenant
kubectl get all -A -l kustomize.toolkit.fluxcd.io/name=team-a
```

The first command lists tenant namespaces. The second lists the objects the `team-a` `Kustomization` created, in all namespaces. If it shows an object outside the tenant namespace, something is wrong with `targetNamespace`.

## Check what the tenant account can do

Impersonation limits a tenant to the rights of its ServiceAccount, so audit those rights. `kubectl auth can-i --list` prints every verb and resource that the account may use in a namespace:

```sh
kubectl auth can-i --list -n team-a --as=system:serviceaccount:team-a:team-a
```

Read the list for entries you did not intend, such as a wildcard on all resources. Run it again after a role change to confirm the change worked. For rights outside the namespace, run it with `-n default` and check cluster-scoped resources one at a time with `can-i`.

## Find tenant objects that bypass the rules

Run a few queries on a schedule or in a pipeline. They show the objects that break the rules you set:

```sh
kubectl get kustomizations -A -o jsonpath='{range .items[?(@.spec.serviceAccountName=="")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'
kubectl get clusterrolebindings -o wide
```

The first command lists Flux `Kustomization` objects with no ServiceAccount, found by an empty field. A `Kustomization` that omits the field entirely does not match, so use an admission policy as the main control and this query as a second look. The second command lists ClusterRoleBindings, where you check that no tenant account appears.

## Common pitfalls

> [!WARNING]
> - **Auditing only Flux objects.** The rights are in RBAC objects, which Flux objects only reference.
> - **Reading `flux trace` for an object Flux does not manage.** It reports that no Flux object owns it.
> - **Trusting labels from a tenant repository.** A tenant can write any label in its files, so audit with the owner labels Flux sets.
> - **Running audits once.** Run them after every change to roles and policies.
