# Deliver To Other Namespaces And Clusters

A Flux `Kustomization` has two hidden defaults: it reads a source in its own namespace, and it applies to the cluster it runs in. Both are fine for one team on one cluster. Neither fits a platform that serves many teams across a staging cluster, a production cluster and a cluster per region.

Flux can change both defaults. `sourceRef.namespace` points at a source in another namespace. `spec.kubeConfig.secretRef` points at a Secret that holds a **kubeconfig**, the file that tells a Kubernetes client which API server to call and with which credentials, so kustomize-controller applies to that other cluster instead. Keep one sentence in mind: **the kubeconfig decides where Flux applies, and the account in it decides what Flux may change there.**

The module has three parts. **Cross-Namespace References** shows a `Kustomization` using a source from another namespace, and when a platform should forbid it. **Applying To Another Cluster With kubeConfig** builds a kubeconfig for an account with narrow rights and delivers podinfo through it; a graded lab follows it. **Cluster API And Fleets Of Clusters** shows how the same mechanism scales to clusters created on demand.

## Learning objectives

After this module you can:

- Reference a source in another namespace, and say what `--no-cross-namespace-refs=true` changes.
- Explain the four parts of a kubeconfig: cluster, user, context and current context.
- Build a kubeconfig for a ServiceAccount token and store it in a Secret under the key `value`.
- Make a Flux `Kustomization` apply through `spec.kubeConfig.secretRef`.
- Prove that objects were applied through the kubeconfig, and that the remote account cannot do more than it should.
- Explain how Cluster API's `<cluster>-kubeconfig` Secrets fit a Flux fleet.

## Before you start

You need Kubernetes RBAC (ServiceAccounts, Roles, RoleBindings) and Flux basics: a `GitRepository`, a Flux `Kustomization`, `flux get` and `flux reconcile`. You need `git` on your machine.

Your playground is a single-node `kind` cluster. Flux 2.9.6 is already bootstrapped from `gitops/fleet` at the path `clusters/kind`, on an in-cluster Git server called Gitea. A second cluster would cost more memory than a laptop has, so the playground plays both roles. The "remote cluster" is the same API server, reached at `https://kubernetes.default.svc` with the token of a ServiceAccount that has narrow rights. A real remote cluster has its own address and its own credentials; everything else works the same.

| What | Where |
| --- | --- |
| `gitops/fleet` | The platform repository. `apps/podinfo-staging/` holds podinfo for staging, with no Namespace object |
| `flux-deployer` | A ServiceAccount in `staging-access`, the account Flux uses on the "remote cluster" |
| `flux-deployer-token` | A Secret in `staging-access` with a long-lived token and the cluster's certificate authority for `flux-deployer` |
| `deployer` | A Role in `podinfo-staging` that lets `flux-deployer` change Deployments and Services there, and nothing else |

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). To use `git` from your machine, start this port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If `git` says it cannot resolve `gitea.localtest.me`, add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`. A real Git server uses HTTPS or SSH; plain HTTP is for this playground only.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
