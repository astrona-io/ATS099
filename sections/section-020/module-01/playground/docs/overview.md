# Overview: Send Flux Events To Webhooks And Chat (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, starts an in-cluster Git server, bootstraps Flux from it, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The Flux command-line tool 2.9.6, and Flux bootstrapped from `gitops/fleet` at the path `clusters/kind`. The Flux `Kustomization` `podinfo` deploys podinfo into the namespace `podinfo`.
- Gitea, an in-cluster Git server, with the lab-only user `gitops` and the password `gitops-password`. The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`.
- **No `Provider` and no `Alert`.** Flux records events, but sends them nowhere yet.
- `webhook-receiver` in the namespace `monitoring`, at `http://webhook-receiver.monitoring`. It answers every request and writes the request, with its body, to its log.

To use `git` from your machine, start a port-forward in a second terminal and leave it running. If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

## Helpers

Paste these once in each new terminal. `received` prints what the webhook receiver got in the last few minutes (default 5). `podinfo_events` lists the events of the `podinfo` Kustomization. `alerting` lists every `Provider` and `Alert`.

```sh
received() {
  kubectl -n monitoring logs deploy/webhook-receiver --since="${1:-5}m"
}
podinfo_events() {
  flux events --for Kustomization/podinfo -n flux-system
}
alerting() {
  kubectl get providers,alerts -A
}
```

Use them like this: `received`, `received 1`, `podinfo_events`, `alerting`.

## Practice tasks

- Send every event of every Flux object to the receiver with one `Alert`, push a change, and count how many requests arrive for one commit.
- Add a second `Alert` for the `GitRepository` `flux-system`, then break the source with a wrong branch in Git and read the error event.
- Add an `exclusionList` entry that drops one kind of message, and prove it with `received`.
- Add `eventMetadata` with your name and find it in the payload.
- Forward port `8080` of source-controller and read `gotk_reconcile_duration_seconds_count` for the `GitRepository` `flux-system`.
