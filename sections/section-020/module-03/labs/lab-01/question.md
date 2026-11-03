# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Health checks

## Scenario

Flux runs from the repository `gitops/fleet`, path `clusters/kind`. The Kustomization `podinfo` in `clusters/kind/podinfo.yaml` uses `wait: true`, so it waits for every object it applies, with a timeout of `3m`. It has no `retryInterval`, so after a failure it waits a full `interval` before it tries again.

The team wants to wait only for the one object that decides whether the application works, to report a failed rollout after 2 minutes, and to retry every minute.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

Change the Kustomization `podinfo` in `clusters/kind/podinfo.yaml` of `gitops/fleet`:

1. Replace `wait: true` with an explicit health check on the Deployment `podinfo` in the namespace `podinfo`. `wait` must not be `true`.
2. Set `timeout` to `2m`.
3. Set `retryInterval` to `1m`.

## Constraints

- Do not change the cluster with `kubectl`. Flux puts back what Git says.
- Keep `prune: true` and the path `./apps/podinfo`.

## Done when

- The Kustomization `podinfo` has a health check for the Deployment `podinfo` in `podinfo`, `timeout` `2m`, `retryInterval` `1m`, and `wait` is not `true`.
- The conditions `Ready` and `Healthy` of the Kustomization are `True`.
- The change is in `clusters/kind/podinfo.yaml` in `gitops/fleet`.
