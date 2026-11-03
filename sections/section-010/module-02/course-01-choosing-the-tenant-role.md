# Choosing The Role Of A Tenant

Every tenant needs a role that lets its ServiceAccount deploy applications into its namespace. The easy choice is the built-in ClusterRole `cluster-admin`, bound with a RoleBinding. It works, and it is what the Flux examples use, but it gives the tenant more than it needs. This part compares three choices and shows how to change a RoleBinding that is already in use.

## What a RoleBinding to a ClusterRole means

A RoleBinding grants the rules of a role inside one namespace. When it names a ClusterRole, Kubernetes takes the rules of that ClusterRole and applies them only in the namespace of the RoleBinding. A RoleBinding to `cluster-admin` therefore gives the tenant every verb on every namespaced resource in its namespace, and nothing in other namespaces or at cluster scope.

Every verb includes the objects the platform wants to protect. The tenant ServiceAccount may then update or delete the ResourceQuota, the LimitRange and the NetworkPolicy of its own namespace. It may also create Roles and RoleBindings, and so grant its own pods rights up to the level of `cluster-admin` inside the namespace.

## The built-in admin ClusterRole

Kubernetes ships the ClusterRole `admin` for the person who administers one namespace. It allows reading and writing most namespaced objects: Deployments, Services, ConfigMaps, Secrets, Jobs, Ingresses, NetworkPolicies, Roles and RoleBindings. It allows only reading of ResourceQuota and the namespace object itself. You can read the exact rules from the cluster instead of relying on this text:

```sh
kubectl get clusterrole admin -o yaml
```

Read the `rules` list and look for `resourcequotas`. The entry that mentions it has only the verbs `get`, `list` and `watch`. The tenant can see its quota but cannot change it. Because the rules of `admin` are aggregated from labelled ClusterRoles, the list can grow when you install a custom resource definition that adds its own aggregation label.

## Compare what each role allows

You can ask Kubernetes directly. `kubectl auth can-i` with `--as` evaluates a request as the tenant ServiceAccount:

```sh
kubectl auth can-i update resourcequotas -n team-a \
  --as=system:serviceaccount:team-a:team-a
kubectl auth can-i create deployments -n team-a \
  --as=system:serviceaccount:team-a:team-a
```

With the RoleBinding to `cluster-admin` in the playground, both answers are `yes`. After you switch the binding to `admin`, the first answer is `no` and the second stays `yes`. That difference is the whole reason to use `admin`.

## A custom Role for a narrow tenant

Some tenants need less than `admin`. A Role lists exactly the resources and verbs, for example Deployments, Services and ConfigMaps in the apps API group and the core group:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: team-a-deployer
  namespace: team-a
rules:
  - apiGroups: ["", "apps"]
    resources: ["deployments", "services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

A tenant that uses Helm also needs `secrets`, because helm-controller stores each release in a Secret. A narrow Role is safer, but it needs maintenance every time the tenant uses a new kind of object. Many platform teams start with `admin` and move to a custom Role only for tenants that need it.

## Change a RoleBinding that is in use

The `roleRef` of a RoleBinding is immutable. Kubernetes refuses an update that changes it. If you edit `roleRef.name` in Git from `cluster-admin` to `admin` and keep the same object name, kustomize-controller reports a failed apply with a message that the `roleRef` cannot change.

The clean fix is to rename the RoleBinding. Give the new binding a new name in the platform repository, and remove the old one from the same folder. Because the `tenants` Flux `Kustomization` has `prune: true`, Flux creates the new binding and deletes the old one in the same reconciliation:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-a-admin
  namespace: team-a
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
  - kind: ServiceAccount
    name: team-a
    namespace: team-a
```

There is a short window in which the tenant has both bindings, then only the new one. The other option, `spec.force: true` on the Flux `Kustomization`, makes Flux delete and recreate an object whose update is refused. It also recreates every other object that fails an update, so rename the binding instead for a change like this.

## Check that the change took effect

After Flux applies the change, confirm the old binding is gone and the tenant lost the right:

```sh
kubectl -n team-a get rolebinding
kubectl auth can-i update resourcequotas -n team-a --as=system:serviceaccount:team-a:team-a
```

The list shows only `team-a-admin`, and the second command answers `no`. The tenant keeps the ability to deploy, which the tenant's own `Kustomization` still proves with a `Ready` `True` status.

## Common pitfalls

> [!WARNING]
> - **Editing `roleRef` in place.** The field is immutable. Rename the binding and let pruning remove the old one.
> - **Using a ClusterRoleBinding for a tenant.** It grants the rules in every namespace. Always use a RoleBinding.
> - **Trusting a quota the tenant can edit.** With `cluster-admin` in its namespace the tenant can remove the quota.
> - **Forgetting `secrets` in a custom Role.** Helm releases fail to install without it.
