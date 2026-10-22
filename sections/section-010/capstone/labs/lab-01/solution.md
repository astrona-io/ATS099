# Solution: Repair A Tenant That Cannot Deploy

Work the task yourself first. Running `astrona submit -c sections/section-010/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks five things: the lockdown is still in Git, the controllers still run with it, `team-b` impersonates `team-b` from its own source and deploys podinfo, a `Kustomization` that impersonates `team-b` cannot create a ClusterRole, and `team-a` still works.

## Step 1: Read the refusal

Start with the status of every Flux object, then the events of the broken one:

```sh
flux get sources git -A
flux get kustomizations -A
flux events --for Kustomization/team-b -n team-b
```

`team-a` is `Ready`. `team-b` is `Ready` `False`. Its message says that the source reference crosses namespaces: the `Kustomization` in `team-b` points at a `GitRepository` in `flux-system`, and `--no-cross-namespace-refs=true` forbids that. This is the first fault, and it hides the others, because Flux stops before it applies anything.

## Step 2: Read the tenant's files

Clone the platform repository and read the tenant's folder:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

In your first terminal:

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
cat tenants/team-b/rbac.yaml tenants/team-b/source.yaml tenants/team-b/sync.yaml
```

Compare them with `tenants/team-a/`. Three things differ:

- `source.yaml` puts the `GitRepository` `team-b` in the namespace `flux-system`, and `sync.yaml` points at it with `sourceRef.namespace: flux-system`. The lockdown refuses that.
- `sync.yaml` sets no `serviceAccountName`. Under `--default-service-account=default` the `Kustomization` would run as `team-b/default`, which may do nothing.
- The RoleBinding in `rbac.yaml` names the ServiceAccount `team-b` in the namespace `team-a`. That account does not exist, so `team-b/team-b` gets no rights at all.

You can confirm the last one directly:

```sh
kubectl auth can-i create deployments -n team-b --as=system:serviceaccount:team-b:team-b
```

The answer is `no`.

## Step 3: Fix the tenant's files

Replace `tenants/team-b/rbac.yaml` with this; only the subject's namespace changes:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: team-b
  labels:
    toolkit.fluxcd.io/tenant: team-b
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: team-b
  namespace: team-b
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-b-reconciler
  namespace: team-b
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: team-b
    namespace: team-b
```

Replace `tenants/team-b/source.yaml` with this, which moves the source into the tenant's namespace:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: team-b
  namespace: team-b
spec:
  interval: 1m
  url: http://gitea.localtest.me:3000/gitops/team-b.git
  ref:
    branch: main
```

Replace `tenants/team-b/sync.yaml` with this, which names the ServiceAccount and drops the cross-namespace reference:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: team-b
  namespace: team-b
spec:
  interval: 5m
  serviceAccountName: team-b
  sourceRef:
    kind: GitRepository
    name: team-b
  path: ./app
  targetNamespace: team-b
  prune: true
```

The `tenants` Kustomization has `prune: true`, so the old `GitRepository` `team-b` in `flux-system` is deleted when it disappears from Git.

## Step 4: Push and prove it

```sh
git add tenants/team-b
git commit -m "Repair team-b: own source, own ServiceAccount, correct RoleBinding"
git push
flux reconcile kustomization flux-system --with-source
flux reconcile kustomization tenants
flux reconcile kustomization team-b -n team-b --with-source
```

Then check the result:

```sh
flux get kustomizations -A
kubectl -n team-b get deployment podinfo
kubectl auth can-i create clusterroles --as=system:serviceaccount:team-b:team-b
```

Every Kustomization is `Ready` `True`, podinfo runs in `team-b`, and the last command answers `no`.

## Step 5: Submit

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Remove `--no-cross-namespace-refs` | The source reference works, but the lockdown checks fail |
| Bind `team-b` with a ClusterRoleBinding | `team-b` deploys, but the grader's test creates the ClusterRole and fails |
| Set `serviceAccountName: kustomize-controller` on `team-b` | The ServiceAccount does not exist in `team-b`; and if it did, the tenant would run with platform rights |
| Fix only the first message | The next reconcile shows the next refusal. Read all three files, not only the first error |
