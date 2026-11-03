# Receivers And Commit Status

Flux polls Git on an interval. A source with `interval: 5m` can take up to five minutes to see a push, and a shorter interval costs requests on every source. A **Receiver** turns this around: the Git host or the registry calls Flux when something changes, and Flux fetches right away.

The other direction matters as well. A developer who pushes a commit wants to see on the commit whether Flux applied it. A Git host type of `Provider` sets that **commit status**.

This module covers both directions: events coming in through a Receiver, and results going out as a commit status.

The module has four parts. **What A Receiver Is** explains the object and its types. **Exposing A Receiver Safely** covers the address, the token and the Service. **Receivers For Git Hosts And Registries** covers the signature checks and the `events` filter. **Commit Status From Flux** sets the result of a reconciliation on the commit. A graded lab follows the second part.

## Learning objectives

After this module you can:

- Say when a Receiver replaces polling and when a long `interval` is enough.
- Write a Receiver with `spec.type`, `spec.secretRef` and `spec.resources`.
- Read `status.webhookPath` and build the URL a Git host calls.
- Explain which Service exposes receivers and why the path contains a hash.
- Choose between `generic`, `generic-hmac`, `github`, `gitlab` and the registry types.
- Set the commit status of a Kustomization with a Git host `Provider` and an `Alert`.

## Before you start

You need to know what a `Provider` and an `Alert` are, how to read `flux events`, and what a Flux `GitRepository` is. You need `kubectl`.

Your playground is a single-node `kind` cluster with Flux 2.9.6 bootstrapped from `gitops/fleet` at the path `clusters/kind`, on an in-cluster Git server called Gitea. podinfo runs in the namespace `podinfo`. The playground has no Receiver. A tester pod in the namespace `gitea` can send HTTP requests to services inside the cluster.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). To use `git` from your machine, start this port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If `git` says it cannot resolve `gitea.localtest.me`, add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
