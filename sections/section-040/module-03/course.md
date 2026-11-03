# Upgrading And Tuning Flux

Flux is software that runs on your cluster, so it needs upgrades and sometimes tuning. A bad upgrade stops delivery to every environment at once. A tuned controller that was never measured can make things worse. This module shows how to upgrade through Git, how to change controller settings through Git, and how to see whether the change helped.

The module has four parts. **Where The Flux Version Comes From** explains what is installed and what `flux version` and `flux check` report. **Upgrading Flux Through Git** covers the upgrade, the review of the change, and a rollback. **Tuning The Controllers** covers concurrency, resource limits and the patch that applies them; a graded lab follows it. **Watching The Controllers** covers logs, metrics and signs that a controller is short of resources.

## Learning objectives

After this module you can:

- Read the installed Flux version from the CLI and from the cluster, and say what `flux check` verifies.
- Explain why the components of a bootstrapped cluster are changed in Git and not with `kubectl`.
- Upgrade Flux by updating the CLI and running `flux bootstrap` again, and review the resulting commit.
- Plan a rollback of a failed upgrade.
- Change a controller flag and a resource limit with a patch in `kustomization.yaml`.
- Recognise a controller that is short of CPU or memory, and read the metrics that show it.

## Before you start

You need Flux basics, a Flux `Kustomization`, and a way to read Deployment arguments with `kubectl`. The module on the structure of a bootstrapped repository helps, but is not required.

Your playground is a single-node `kind` cluster with Flux 2.9.6 bootstrapped from `gitops/fleet` at the path `clusters/kind`, on an in-cluster Git server called Gitea. Flux's own manifests are in `clusters/kind/flux-system/` in that repository: `gotk-components.yaml`, `gotk-sync.yaml` and `kustomization.yaml`.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). To use `git` from your machine, start this port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If `git` says it cannot resolve `gitea.localtest.me`, add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
