# Solution: Give A Tenant Fewer Rights And A Quota

Work the task yourself first. Running `astrona submit -c sections/section-010/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the tenant no longer holds `cluster-admin` and cannot change quotas, the quota and the network policy exist with the right content, the tenant still deploys, and the quota and policy are in Git.

## Step 1: Clone the platform repository

Start the port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Clone the repository with the user `gitops` and the password `gitops-password`:

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

## Step 2: Replace the RoleBinding

The `roleRef` of a RoleBinding cannot change, so do not edit it in place. In `tenants/team-a/rbac.yaml`, rename the RoleBinding to `team-a-admin` and point it at `admin`. The last object of the file becomes:

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

The Namespace and ServiceAccount objects in the same file stay as they are. Because the platform `tenants` Kustomization prunes, Flux creates `team-a-admin` and deletes `team-a-reconciler`.

## Step 3: Add the quota and the network policy

Save this as `tenants/team-a/quota.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a-quota
  namespace: team-a
spec:
  hard:
    pods: "10"
```

Save this as `tenants/team-a/network-policy.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: team-a
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

## Step 4: Commit, push and reconcile

```sh
git add tenants/team-a
git commit -m "Give team-a the admin role, a quota and a default-deny policy"
git push
flux reconcile kustomization flux-system --with-source
flux reconcile kustomization tenants --with-source
```

Run `astrona submit -c sections/section-010/module-02/labs/lab-01` now.

## Step 5: Check it yourself

```sh
kubectl -n team-a get rolebinding,resourcequota,networkpolicy
kubectl auth can-i update resourcequotas -n team-a --as=system:serviceaccount:team-a:team-a
flux get kustomizations -A
```

You expect one RoleBinding, `team-a-admin`, the quota and the policy, the answer `no`, and `Ready` `True` for `tenants` and `team-a`.

## If something is wrong

- **The `tenants` Kustomization is `False` and names `roleRef`.** You edited the old RoleBinding in place. Rename it as in step 2.
- **The answer is still `yes`.** The old binding is still there. Check that `prune` ran with `kubectl -n team-a get rolebinding`.
- **`team-a` is `False`.** Read `kubectl -n team-a describe kustomization team-a`. The new role `admin` still allows deploying, so the cause is usually a typo in a file you changed.
