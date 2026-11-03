# Scoping The Remote Account

The account in a kubeconfig decides what Flux can change on the other cluster. An account with `cluster-admin` makes the management cluster a single point of compromise for every cluster it serves. An account with the minimum rights limits the damage of a leaked credential to one application.

## Start from what is applied

The rights follow from the objects in the folder. For podinfo in this module, the folder holds a Deployment and a Service, so the account needs these verbs on those kinds, in one namespace:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployer
  namespace: podinfo-staging
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

Flux applies with server-side apply, so it needs `get`, `create` and `patch` on each kind, plus `list` and `watch` for the health checks and `delete` for pruning. Without `delete`, a removal from Git fails.

## What a Role cannot cover

- **Namespaces.** A namespace is a cluster-scoped kind. An account limited to one namespace cannot create it. Create the namespace when the cluster is set up, or give the account a ClusterRole that allows only `create` and `get` on namespaces.
- **CRDs and cluster-scoped kinds.** Installing a CRD or a ClusterRole needs a ClusterRole. Give that to a separate account with a separate Kustomization, used only for cluster add-ons, and keep the application account namespaced.
- **Objects the application creates by itself.** A controller that Flux installs creates its own objects with its own account. They do not need the Flux account's rights.

## Test the account

```sh
AS=system:serviceaccount:staging-access:flux-deployer
kubectl auth can-i create deployments -n podinfo-staging --as=$AS
kubectl auth can-i create deployments -n podinfo --as=$AS
kubectl auth can-i create clusterroles --as=$AS
kubectl auth can-i --list -n podinfo-staging --as=$AS
```

The first answer is `yes`. The other two are `no`. The last command lists everything the account can do in the namespace, which is the full list to review.

## Several accounts, several Kustomizations

Split the delivery by risk. One Kustomization and one account for the namespaces of the applications. Another Kustomization and another account for add-ons that need cluster rights. A leak of the first then cannot install a CRD.

## Add a guard on the remote cluster

The remote cluster can limit what the account does even inside its namespace, with a ResourceQuota, a LimitRange and an admission policy. These apply to a Flux account in the same way as to any user.

## Common pitfalls

> [!WARNING]
> - **`cluster-admin` "until it works".** It stays forever. Read the "forbidden" message and grant what it names.
> - **Forgetting `delete`.** The apply works and the prune fails.
> - **One account for add-ons and applications.** A leak then has the rights of both.
> - **Creating the namespace in the folder the account applies.** The apply is refused.
