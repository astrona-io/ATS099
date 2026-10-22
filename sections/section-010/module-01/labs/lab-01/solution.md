# Solution: Onboard A Locked-Down Tenant

Work the task yourself first. Running `astrona submit -c sections/section-010/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the lockdown patches are in Git, the controllers run with them while `flux-system` and `podinfo` stay `Ready`, the `team-a` Kustomization impersonates `team-a` and deploys podinfo into `team-a`, and a temporary `Kustomization` that impersonates `team-a` cannot create a ClusterRole.

## Step 1: Clone the platform repository

Start the port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Then clone the platform repository with the user `gitops` and the password `gitops-password`:

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

## Step 2: Lock the controllers down

Replace the content of `clusters/kind/flux-system/kustomization.yaml` with the resources bootstrap wrote plus four patches:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - gotk-components.yaml
  - gotk-sync.yaml
patches:
  - patch: |
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --no-cross-namespace-refs=true
    target:
      kind: Deployment
      name: "(kustomize-controller|helm-controller|notification-controller|image-reflector-controller|image-automation-controller)"
  - patch: |
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --no-remote-bases=true
    target:
      kind: Deployment
      name: "kustomize-controller"
  - patch: |
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --default-service-account=default
    target:
      kind: Deployment
      name: "(kustomize-controller|helm-controller)"
  - patch: |
      - op: add
        path: /spec/serviceAccountName
        value: kustomize-controller
    target:
      kind: Kustomization
      name: "flux-system"
```

## Step 3: Keep podinfo working under the lockdown

With `--default-service-account=default`, the `podinfo` Kustomization in `flux-system` would run as `flux-system/default` and lose every right. Replace `clusters/kind/podinfo.yaml` with this, which adds one line:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 5m
  serviceAccountName: kustomize-controller
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./apps/podinfo
  prune: true
  wait: true
  timeout: 3m
```

## Step 4: Onboard team-a

Save this as `tenants/team-a/rbac.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: team-a
  labels:
    toolkit.fluxcd.io/tenant: team-a
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: team-a
  namespace: team-a
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-a-reconciler
  namespace: team-a
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: team-a
    namespace: team-a
```

Save this as `tenants/team-a/sync.yaml`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: team-a
  namespace: team-a
spec:
  interval: 1m
  url: http://gitea.localtest.me:3000/gitops/team-a.git
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: team-a
  namespace: team-a
spec:
  interval: 5m
  serviceAccountName: team-a
  sourceRef:
    kind: GitRepository
    name: team-a
  path: ./app
  targetNamespace: team-a
  prune: true
```

Save this as `clusters/kind/tenants.yaml`, so Flux applies the `tenants` folder with the platform's rights:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: tenants
  namespace: flux-system
spec:
  interval: 5m
  serviceAccountName: kustomize-controller
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./tenants
  prune: true
```

## Step 5: Push and reconcile

Commit everything in one push, then make Flux apply it now:

```sh
git add clusters/kind tenants
git commit -m "Lock Flux down and onboard team-a"
git push
flux reconcile kustomization flux-system --with-source
```

The controllers restart with the new arguments. When they are back, reconcile once more and let the tenant's source fetch:

```sh
kubectl -n flux-system rollout status deployment/kustomize-controller
flux reconcile kustomization flux-system --with-source
flux reconcile kustomization team-a -n team-a --with-source
```

## Step 6: Prove it

Check the flags, the Flux objects and the tenant's workload:

```sh
kubectl -n flux-system get deployment kustomize-controller \
  -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}'
flux get kustomizations -A
kubectl -n team-a get deployment podinfo
kubectl auth can-i create clusterroles --as=system:serviceaccount:team-a:team-a
```

The arguments end with the three flags. `flux-system`, `podinfo`, `tenants` and `team-a` are all `Ready` `True`. podinfo runs in `team-a`, and the last command answers `no`.

## Step 7: Submit

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Bind `team-a` with a ClusterRoleBinding | The tenant can create ClusterRoles, and the grader's impersonation test creates one and fails |
| Leave `serviceAccountName` out of `team-a` | Under the lockdown it runs as `team-a/default`, which may do nothing, so `team-a` never becomes `Ready` |
| Set the flags with `kubectl edit deployment` | The next reconcile of `flux-system` puts the Deployment back to Git, and the Git check fails |
| Forget `serviceAccountName: kustomize-controller` on `podinfo` | `podinfo` turns `Ready` `False` with a "forbidden" message for `flux-system:default` |
| Put the tenant's `GitRepository` in `flux-system` | `--no-cross-namespace-refs=true` refuses the reference from `team-a` |
