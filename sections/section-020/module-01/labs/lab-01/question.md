# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Alerting

## Scenario

The platform runs podinfo through the Flux `Kustomization` `podinfo` in `flux-system`. Last week a bad commit broke it, and nobody noticed for a day. The on-call team has a webhook receiver at `http://webhook-receiver.monitoring/flux` and wants to hear about podinfo failures there, and only about failures.

The repository is `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

Commit to `gitops/fleet`, in a file under `clusters/kind/`:

1. A `Provider` named `webhook` in `flux-system`, of type `generic`, that posts to `http://webhook-receiver.monitoring/flux`.
2. An `Alert` named `podinfo-errors` in `flux-system` that uses `webhook` and forwards the events of the `Kustomization` `podinfo` in `flux-system`, with severity `error` only.

## Constraints

- Create the objects through Git, not with `kubectl apply`.
- Do not forward `info` events to the receiver.

## Done when

- The `Provider` and the `Alert` are in Git under `clusters/kind/` and in the cluster.
- When podinfo fails, an error event about it reaches the receiver. The grader breaks podinfo for a moment, checks the receiver's log, and repairs it.
- The recovery that follows sends no `info` event to the receiver.
