# Overview: Receivers And Commit Status (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, starts an in-cluster Git server, bootstraps Flux from it, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The Flux command-line tool 2.9.6, and Flux bootstrapped from `gitops/fleet` at the path `clusters/kind`.
- Gitea, an in-cluster Git server, with the lab-only user `gitops` and the password `gitops-password`. The repository `gitops/fleet` holds `clusters/kind/podinfo.yaml` and `apps/podinfo/`.
- A tester pod in the namespace `gitea` that can send HTTP requests to services in the cluster.
- A webhook receiver in the namespace `monitoring` that logs every request it gets. It is not the Flux receiver.

To use `git` from your machine, start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal. If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

## Helpers

```sh
receiver_path() {
  kubectl -n flux-system get receiver "$1" -o jsonpath='{.status.webhookPath}'
}
call_receiver() {
  kubectl -n gitea exec deploy/tester -- curl -sS -i -X POST "http://webhook-receiver.flux-system$(receiver_path "$1")"
}
requested_at() {
  kubectl -n flux-system get gitrepository flux-system -o jsonpath='{.metadata.annotations.reconcile\.fluxcd\.io/requestedAt}'
}
```

## Practice tasks

- Create a token Secret and a `generic` Receiver, then run `call_receiver NAME` and compare `requested_at` before and after.
- Change the token in the Secret and read `receiver_path` again. The path changes.
- Send a POST to a made-up path and read the response and the log of notification-controller.
- Add a Receiver of type `github` with `events: [ping, push]`, and send a POST without the signature header. Read why it is rejected.
- Add a Provider of type `gitea` for the repository `gitops/fleet` with a token Secret, and an Alert for the Kustomization `podinfo`, and look at the commit status in Gitea.
