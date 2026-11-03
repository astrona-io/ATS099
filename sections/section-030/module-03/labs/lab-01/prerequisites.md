# Prerequisites

Before starting this lab you should be able to:

- Write a Flux Kustomization with spec.kubeConfig and spec.dependsOn.
- Explain the difference between applied and healthy.
- Commit and push a file to a Git repository.

## What the environment gives you

The environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- The Flux command-line tool 2.9.6 on your PATH.
- An in-cluster Git server, Gitea, with the lab-only user `gitops` and the password `gitops-password`. The repository address is `http://gitea.localtest.me:3000/gitops/fleet.git`. A real Git server uses HTTPS or SSH; plain HTTP is for this lab only.
- Flux bootstrapped from gitops/fleet. podinfo runs in podinfo-staging through the Kustomization podinfo-staging, which has no health check. The folder apps/podinfo-production and the Secret production-kubeconfig exist, and nothing delivers production yet.

To use `git` from your machine, start a port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If `git` cannot resolve `gitea.localtest.me`, your router blocks DNS answers that point at `127.0.0.1`. Add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

## Working rules

- Everything is graded on the **final state** of the cluster and of the Git repositories. Leave your work in place.
- Change Git, not the cluster, unless the task says otherwise. Flux puts back what Git says.
- `kubectl`, `flux`, `git` and `curl` are available.
