# Recover A Cluster From Git

"Everything is in Git" is the sentence people say about GitOps, and it is almost true. Git holds every manifest Flux applies. It does not hold the credential Flux uses to read Git, the kubeconfigs for other clusters, the keys that decrypt secrets, or the data in volumes. A recovery that forgets them stalls halfway, with Flux running and nothing able to fetch.

This module practises recovery while nothing is at stake. Flux itself is cheap to remove and to bring back, because it only manages objects; the workloads keep running without it. Keep one sentence in mind: **reinstalling Flux adopts what is running; it does not recreate it.**

The module has three parts. **What Git Holds And What It Does Not** takes stock of everything Flux needs that Git cannot give it. **Suspend, Uninstall And Reinstall Flux** pauses Flux, removes it, puts it back with `flux bootstrap`, and proves the workloads were adopted; a graded lab follows it. **Rebuilding A Lost Cluster** sets out the order for the worst case, a cluster that is gone.

## Learning objectives

After this module you can:

- List what Git holds and what it does not, and where each missing piece should come from.
- Pause and resume every Flux `Kustomization`, and explain why a suspend committed to Git stays.
- Explain what `flux uninstall` removes and leaves, and what `--keep-namespace` changes.
- Reinstall Flux with `flux bootstrap` from the same repository and path.
- Prove that a workload was adopted by comparing its UID and reading the `Kustomization`'s inventory.
- Put the steps of a full cluster rebuild in the right order.

## Before you start

You need Flux basics: `flux bootstrap`, a `GitRepository`, a Flux `Kustomization`, `flux get` and `flux reconcile`. You need `git` on your machine. Every Kubernetes object has a **UID**, a unique ID that the API server gives it when it is created; a deleted and recreated object gets a new UID, so the UID tells you whether an object survived.

Your playground is a single-node `kind` cluster. Flux 2.9.6 is already bootstrapped from `gitops/fleet` at the path `clusters/kind`, on an in-cluster Git server called Gitea, and the Flux `Kustomization` `podinfo` deploys podinfo into the namespace `podinfo`.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). To use `git` and `flux bootstrap` from your machine, start this port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If your machine cannot resolve `gitea.localtest.me`, add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`. A real Git server uses HTTPS or SSH; plain HTTP is for this playground only.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
