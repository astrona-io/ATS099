# Question

Solve this question on: `terminal`

**Time:** about 40 minutes · **Topic:** Disaster recovery

## Scenario

This cluster ran Flux from `gitops/fleet`, path `clusters/kind`, with two sources: the platform repository, and a private repository `gitops/private-config` that holds the ConfigMap `private-settings` for podinfo. Last week the team paused podinfo for maintenance by committing a change to Git. Then someone ran `flux uninstall` without `--keep-namespace`. Flux, its objects and the whole `flux-system` namespace are gone, with every Secret in it. podinfo and `private-settings` still run, unmanaged.

The credentials for both repositories are in the team's password manager: user `gitops`, password `gitops-password` (lab-only), for `http://gitea.localtest.me:3000/gitops/fleet.git` and `http://gitea.localtest.me:3000/gitops/private-config.git`. The private source expects its credentials in a Secret named `private-config-auth` in `flux-system`. Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git` or bootstrap.

## Your task

1. Bring Flux back from `gitops/fleet`, branch `main`, path `clusters/kind`.
2. Restore what Git does not hold, so the private source can fetch again.
3. End the maintenance window, so Flux manages podinfo again.

## Constraints

- **Do not delete or recreate the running workloads.** The grader compares the UIDs of the podinfo Deployment and the ConfigMap `private-settings` with the UIDs they had before.
- End the maintenance window **in Git**. A `flux resume` alone does not count.
- Do not delete the ConfigMap `dr-baseline` in the namespace `gitea`.

## Done when

- `flux check` passes, and `flux-system` syncs `./clusters/kind` from `gitops/fleet` and is `Ready`.
- The `GitRepository` and the `Kustomization` `private-config` are `Ready`, and `private-settings` has its old UID.
- `clusters/kind/podinfo.yaml` in Git no longer suspends podinfo, the `podinfo` Kustomization is `Ready` and not suspended, and the podinfo Deployment has its old UID.
