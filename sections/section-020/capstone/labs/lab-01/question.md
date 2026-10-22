# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** Alerting

## Scenario

Weeks ago someone committed a `Provider` named `webhook` and an `Alert` named `flux-errors` to `gitops/fleet`, in `clusters/kind/alerts.yaml`. The on-call team's webhook receiver at `http://webhook-receiver.monitoring/flux` has not received a single request since, although the platform has had failures. The team wants errors from two objects: the `Kustomization` `podinfo` and the `GitRepository` `flux-system`, both in `flux-system`.

The repository is `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Find every reason no event reaches the receiver. Read the `Provider`, the `Alert` and the receiver's log. There is more than one.
2. Fix them in Git, in `clusters/kind/alerts.yaml`, so that errors from both objects reach the receiver.

## Constraints

- Keep the names `webhook` and `flux-errors`.
- Keep forwarding errors only: `eventSeverity` must stay `error`.
- No `exclusionList` pattern may drop ordinary error messages.

## Done when

- The `Provider` posts to the receiver, and the `Alert` watches the `Kustomization` `podinfo` and the `GitRepository` `flux-system` with severity `error`.
- When podinfo fails, an error event reaches the receiver. The grader breaks podinfo for a moment and repairs it.
- When the `flux-system` source fails, an error event reaches the receiver. The grader points the source at a missing branch for a moment and repairs it.
