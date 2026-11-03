# Fleets, Environments And Promotion

Delivering to one remote cluster is a start. A team usually has several: development, staging and production, perhaps in more than one region. This module is about how to organize the repository for several environments, how to make a change reach production only after staging accepts it, and how to operate many clusters from one terminal.

The module has four parts. **Push And Pull Delivery** compares one Flux per cluster with one Flux that serves many. **Environments As Folders And Overlays** shows how to keep the differences between environments small and visible. **Promotion Order With dependsOn And Health** makes production wait for staging; a graded lab follows it. **Operating A Fleet** covers the commands for working across clusters.

## Learning objectives

After this module you can:

- Compare a Flux instance in every cluster with one management cluster that delivers to many.
- Organize a repository with a shared base and one overlay or folder per environment.
- Use `postBuild.substitute` and `substituteFrom` for values that differ per environment.
- Make a production Kustomization wait for a staging Kustomization with `dependsOn` and a health check.
- Use `flux --context`, `flux tree` and `flux diff` to inspect more than one cluster.

## Before you start

You need the previous module in this section: a kubeconfig Secret, a remote account with a Role, and a `Kustomization` with `spec.kubeConfig`.

Your playground is a single-node `kind` cluster with Flux 2.9.6 bootstrapped from `gitops/fleet` at the path `clusters/kind`, on an in-cluster Git server called Gitea. It plays three clusters: the management cluster, and a "staging" and a "production" cluster that are the same API server reached at `https://kubernetes.default.svc` with the tokens of two ServiceAccounts.

| What | Where |
| --- | --- |
| `apps/podinfo-staging/` | The staging folder in `gitops/fleet` |
| `apps/podinfo-production/` | The production folder in `gitops/fleet` |
| `flux-deployer` in `staging-access` | The staging account, limited to `podinfo-staging` |
| `flux-deployer` in `production-access` | The production account, limited to `podinfo-production` |

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). To use `git` from your machine, start this port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If `git` says it cannot resolve `gitea.localtest.me`, add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
