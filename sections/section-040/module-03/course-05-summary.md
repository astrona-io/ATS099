# Summary

Flux is software with a version and settings. This module covered where the version comes from, how to upgrade through Git, how to tune the controllers with patches, and how to watch them.

## What you learned

The CLI and the controllers have separate versions, and `flux version` reports both. `flux bootstrap` writes `gotk-components.yaml`, `gotk-sync.yaml` and `kustomization.yaml` under `flux-system` in the repository, and the Kustomization `flux-system` applies them, so the cluster version is what Git says. An edit made with `kubectl` is reverted at the next reconcile. `flux check` verifies prerequisites, controller readiness and CRDs, and `flux install --export` previews the manifests of the installed CLI.

An upgrade is a newer CLI plus the same `flux bootstrap` command, with the same URL, branch, path, flags and component list. Read the release notes first, keep the `flux check` output, rehearse on another cluster, and read the commit that bootstrap makes. A rollback is a `git revert` of that commit. A downgrade of the controllers does not undo changes to stored objects.

Tuning is a patch in `kustomization.yaml` in the `flux-system` folder. `--concurrent` sets how many objects a controller reconciles at once, `--kube-api-qps` and `--kube-api-burst` limit API calls, and memory and CPU limits stop a controller being killed. Check the build with `kubectl kustomize` before you push, because a bad patch can stop Flux from updating itself.

Use `flux logs`, `flux events`, `flux get all -A`, `kubectl top`, the last state of the pod, and the metrics `gotk_reconcile_duration_seconds`, `workqueue_depth` and `gotk_resource_info`. Change one thing at a time, measure before and after, and alert on objects that stay not `Ready`.

The key facts to remember are these:

- Change Flux itself through Git, never with `kubectl`.
- Upgrade with the same bootstrap command and read the commit.
- Tune with a patch, one change at a time, with a baseline.
- `OOMKilled` and a deep work queue are the signs of too little room.

<!-- astrona:playground:destroy -->
