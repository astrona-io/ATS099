# Guardrails And Secrets For Tenants

Impersonation decides what a tenant's Flux objects may create. It does not decide how much a tenant may use, what the tenant's pods may talk to, or who can read the tenant's secrets. A shared cluster needs those limits as well, and Kubernetes already has the objects for them: ResourceQuota, LimitRange, NetworkPolicy and Secrets with encryption. The platform team writes them into the tenant's namespace through the platform repository.

The key point of this module is a mistake that is easy to make. If the tenant's RoleBinding points at the ClusterRole `cluster-admin`, the tenant can edit or delete its own quota and its own network policy, because `cluster-admin` allows every verb on every resource in the namespace. The guardrails only count when the tenant's role does not allow changing them.

The module has four parts. **Choosing The Role Of A Tenant** compares `cluster-admin`, `admin` and a custom Role, and shows which one protects a quota. **Quotas And Limits Per Tenant** adds a ResourceQuota and a LimitRange to the tenant namespace. **Network Isolation And Tenant Secrets** adds a default-deny NetworkPolicy and gives each tenant its own decryption key for SOPS. **Onboarding And Offboarding Many Tenants** turns the pattern into a repeatable folder structure and removes a tenant cleanly. A graded lab follows the second part.

## Learning objectives

After this module you can:

- Explain what the ClusterRoles `cluster-admin` and `admin` allow inside a namespace, and why `admin` is the better tenant role.
- Replace a tenant's RoleBinding through Git without hitting the immutable `roleRef` field.
- Write a ResourceQuota and a LimitRange for a tenant namespace.
- Write a default-deny NetworkPolicy and an allow rule for one tenant.
- Give a tenant its own SOPS decryption Secret and reference it from the tenant's `Kustomization`.
- Offboard a tenant so that its namespace and workloads are removed by pruning.

## Before you start

You need the module on impersonation: the platform repository holds the tenant's Namespace, ServiceAccount and RoleBinding, and the tenant's Flux `Kustomization` sets `spec.serviceAccountName`. You also need basic Kubernetes objects: ResourceQuota, NetworkPolicy and Secret.

Your playground is a single-node `kind` cluster. Flux 2.9.6 is bootstrapped from the repository `gitops/fleet` at the path `clusters/kind`, on an in-cluster Git server called Gitea. The tenant `team-a` is already onboarded through the folder `tenants/team-a` in the platform repository, with a RoleBinding to `cluster-admin`. The tenant repository `gitops/team-a` is public and deploys podinfo from `./app`.

Both repositories live at `http://gitea.localtest.me:3000/gitops/<name>.git`, with the lab-only user `gitops` and the password `gitops-password`. To use `git` from your machine, start this port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If `git` cannot resolve `gitea.localtest.me`, add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`. A real Git server uses HTTPS or SSH; plain HTTP is for this playground only.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
