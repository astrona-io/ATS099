# Kubeconfig Secrets, Tokens And Remote Rights

A kubeconfig in a Secret is a credential for another cluster, kept on the cluster that runs Flux. It is used every few minutes for as long as the delivery exists. This module is about running that arrangement for a long time: how the Secret is read, how the token inside it is renewed, how few rights the remote account needs, and what deleting or pruning means on the other cluster.

The module has four parts. **How Flux Reads A Kubeconfig Secret** covers the keys, the namespace and the security flags. **Token Lifetime And Rotation** covers long-lived and short-lived tokens and replacing a token without a gap; a graded lab follows it. **Scoping The Remote Account** covers the rights Flux needs, and how to check them. **Remote Health Checks And Pruning** covers what `wait`, health checks and `prune` do on the other cluster.

## Learning objectives

After this module you can:

- Say which key and which namespace Flux reads a kubeconfig from.
- Explain what `--insecure-kubeconfig-exec` and `--insecure-kubeconfig-tls` change.
- Compare a long-lived ServiceAccount token with a short-lived token from the TokenRequest API.
- Rotate the token in a kubeconfig Secret and show that the old token no longer works.
- Write the Role that a remote account needs for one application, and test it with `kubectl auth can-i`.
- Explain what happens to remote objects when a Kustomization with `prune` is changed or deleted.

## Before you start

You need the idea of a kubeconfig, a ServiceAccount token, and a Flux `Kustomization` with `spec.kubeConfig`.

Your playground is a single-node `kind` cluster with Flux 2.9.6 bootstrapped from `gitops/fleet` at the path `clusters/kind`, on an in-cluster Git server called Gitea. The playground plays two clusters. The "remote cluster" is the same API server, reached at `https://kubernetes.default.svc` with the token of a ServiceAccount that has narrow rights.

| What | Where |
| --- | --- |
| `gitops/fleet` | The platform repository. `apps/podinfo-staging/` holds podinfo for staging, with no Namespace object |
| `flux-deployer` | A ServiceAccount in `staging-access`, the account Flux uses on the "remote cluster" |
| `flux-deployer-token` | A Secret in `staging-access` with a long-lived token and the cluster's certificate authority |
| `deployer` | A Role in `podinfo-staging` for Deployments and Services |

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). To use `git` from your machine, start this port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If `git` says it cannot resolve `gitea.localtest.me`, add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
