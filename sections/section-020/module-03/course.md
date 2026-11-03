# Health, Metrics And Monitoring

An alert tells you that something failed. This module is about knowing, at any time, whether the cluster is healthy: what Flux itself reports, how Flux decides that an application is healthy, and what to put on a dashboard and in a Prometheus rule.

The module has four parts. **Reading Status Conditions** explains `Ready`, `Reconciling`, `Stalled` and `Healthy`. **Health Checks And Timeouts** covers `wait`, `healthChecks`, `timeout` and `retryInterval`, and a graded lab follows it. **Monitoring Flux With Prometheus** covers the PodMonitor, the metrics and the alert rules. **A Daily Operating Checklist** collects the commands an operator runs.

## Learning objectives

After this module you can:

- Read the conditions of a Flux object and say which one answers which question.
- Use `flux get` with `--status-selector` and `kubectl wait` to find and wait for state.
- Choose between `wait: true` and an explicit `healthChecks` list.
- Set `timeout` and `retryInterval` so that a failed rollout is reported at the right time.
- Describe a Prometheus setup for Flux, and write a rule for a failing or suspended object.
- Run `flux check`, `flux stats` and `flux tree` as part of regular operation.

## Before you start

You need a Flux `Kustomization`, `flux get`, and the idea of a Kubernetes Deployment rollout. Knowing how alerts work helps but is not required.

Your playground is a single-node `kind` cluster with Flux 2.9.6 bootstrapped from `gitops/fleet` at the path `clusters/kind`, on an in-cluster Git server called Gitea. podinfo runs in the namespace `podinfo`, applied by the Kustomization `podinfo`, which currently uses `wait: true`.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). To use `git` from your machine, start this port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If `git` says it cannot resolve `gitea.localtest.me`, add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
