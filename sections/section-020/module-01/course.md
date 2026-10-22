# Send Flux Events To Webhooks And Chat

A Flux `Kustomization` that stops applying does not page anyone. Its `Ready` condition turns `False`, `flux get` shows the message, and the cluster drifts away from Git until someone happens to look. On a shared platform, the team that broke the commit is usually not the team that looks.

Flux already knows when something fails. Every controller records a Kubernetes **event** each time it reconciles an object, with a severity of `info` or `error`. notification-controller, one of the four default Flux controllers, can forward those events anywhere: a chat channel, an incident tool, or a plain webhook. You configure it with two objects. Keep one sentence in mind: **a Provider says where events go, and an Alert says which events go there.**

The module has three parts. **Events, Providers And Alerts** reads the events Flux records, sends them to a webhook receiver, and reads the payload that arrives. **Choosing Which Events Become Alerts** narrows an Alert to errors from one object, so people only get messages that need action; a graded lab follows it. **Metrics And flux stats** turns from single events to numbers over time: the Prometheus metrics the controllers export.

## Learning objectives

After this module you can:

- Read Flux events with `flux events` and say what severity, reason and message mean.
- Write a `generic` `Provider` and an `Alert` in Git, and show the Slack and Microsoft Teams variants.
- Read the JSON payload a generic provider posts.
- Select events with `eventSources`, `eventSeverity`, `inclusionList` and `exclusionList`.
- Explain why `info` events reach a receiver that should only get errors.
- Read `gotk_reconcile_duration_seconds` from a controller's `/metrics` endpoint, and say which Flux metrics come from kube-state-metrics.

## Before you start

You need Flux basics: a `GitRepository`, a Flux `Kustomization`, `flux get` and `flux reconcile`. You need `git` on your machine and `kubectl logs`.

Your playground is a single-node `kind` cluster. Flux 2.9.6 is already bootstrapped from `gitops/fleet` at the path `clusters/kind`, on an in-cluster Git server called Gitea. These are the pieces you work with:

| What | Where |
| --- | --- |
| `gitops/fleet` | The platform repository, with `clusters/kind/podinfo.yaml` for the demo application |
| `podinfo` | The demo application in the namespace `podinfo`, applied by the Flux `Kustomization` `podinfo` |
| `webhook-receiver` | An HTTP server in the namespace `monitoring`, at `http://webhook-receiver.monitoring`. It writes every request it receives, with the body, to its log |

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). To use `git` from your machine, start this port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If `git` says it cannot resolve `gitea.localtest.me`, add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`. A real Git server uses HTTPS or SSH; plain HTTP is for this playground only.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
