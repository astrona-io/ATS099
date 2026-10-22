# Onboard Tenants With Impersonation

Flux applies whatever its Git repositories hold. On a cluster that one team owns, that is exactly what you want. On a cluster that five teams share, it means that a mistake, or a bad commit, in any one team's repository can change any namespace, or create a ClusterRole that grants every permission.

The fix is not a new Flux feature but a Kubernetes one: role-based access control (RBAC). Flux can **impersonate** a ServiceAccount when it applies files, that is, act as that account so that Kubernetes checks every write against the account's permissions. Give each team, called a **tenant**, a ServiceAccount that may only change its own namespace, and tell Flux to impersonate it. Then the tenant's repository can hold anything, and Kubernetes refuses what the tenant may not do. Keep one sentence in mind: **Flux applies a tenant's files with the tenant's rights, never with its own.**

The module has three parts. **Platform Administrators, Tenants And Their Repositories** sets out who owns what, how the repositories are laid out, and what `flux create tenant` generates. **Impersonation With spec.serviceAccountName** onboards the tenant `team-a` and shows Kubernetes refusing a cluster-wide object. **Locking Down The Cluster For Tenants** closes the ways a tenant could step around impersonation, and is followed by a graded lab.

## Learning objectives

After this module you can:

- Describe the roles of the platform administrator and the tenant, and the layout of their repositories.
- Write a tenant's Namespace, ServiceAccount and RoleBinding, and say what `flux create tenant` generates.
- Make a Flux `Kustomization` impersonate a ServiceAccount with `spec.serviceAccountName`.
- Read a refusal from Kubernetes RBAC in a Flux object's status.
- Add the lockdown flags to the controllers through the `flux-system` Kustomize file in Git.
- Explain why the platform's own Flux `Kustomization` objects need `serviceAccountName: kustomize-controller` under the lockdown.

## Before you start

You need Kubernetes RBAC: ServiceAccounts, Roles, ClusterRoles, RoleBindings and ClusterRoleBindings. You need Flux basics: a `GitRepository` fetches a repository, a Flux `Kustomization` object applies one folder of it, and `flux bootstrap` makes Flux manage itself from Git. You also need `git` on your machine.

Your playground is a single-node `kind` cluster. Flux 2.9.6 is already bootstrapped from the repository `gitops/fleet` at the path `clusters/kind`, on an in-cluster Git server called Gitea. These are the pieces you work with:

| What | Where |
| --- | --- |
| `gitops/fleet` | The platform repository. Flux applies `clusters/kind` from it, including `clusters/kind/podinfo.yaml` |
| `gitops/team-a` | The tenant repository. `./app` deploys podinfo; `./escalate` holds a ClusterRole that no tenant may create |
| `podinfo` | The platform's demo application in the namespace `podinfo` |

Both repositories live at `http://gitea.localtest.me:3000/gitops/<name>.git`, with the lab-only user `gitops` and the password `gitops-password`. To use `git` from your machine, start this port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If `git` says it cannot resolve `gitea.localtest.me`, add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`. A real Git server uses HTTPS or SSH; plain HTTP is for this playground only.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
