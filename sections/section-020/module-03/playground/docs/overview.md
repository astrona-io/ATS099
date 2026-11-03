# Overview: Health, Metrics And Monitoring (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, starts an in-cluster Git server, bootstraps Flux from it, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The Flux command-line tool 2.9.6, and Flux bootstrapped from `gitops/fleet` at the path `clusters/kind`.
- Gitea, an in-cluster Git server, with the lab-only user `gitops` and the password `gitops-password`. The repository `gitops/fleet` holds `clusters/kind/podinfo.yaml` and `apps/podinfo/`.
- podinfo in the namespace `podinfo`, applied by the Kustomization `podinfo` with `wait: true`.

To use `git` from your machine, start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal. If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

## Helpers

```sh
conditions() {
  kubectl -n flux-system get kustomization "$1" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason} {.message}{"\n"}{end}'
}
not_ready() {
  flux get all -A --status-selector ready=false
}
```

## Practice tasks

- Run `conditions podinfo` and read each condition.
- Set an image tag that does not exist in `apps/podinfo/deployment.yaml`, push it, and watch `conditions podinfo` until `Healthy` turns `False`. Then revert the commit.
- Set `timeout: 30s` and push a change that needs longer to roll out. Read the message.
- Remove `retryInterval`, break the image, and compare the time Flux takes to retry with and without it.
- Run `flux check`, `flux stats -A`, `flux tree kustomization flux-system` and `flux trace deployment podinfo -n podinfo`.
- Run `not_ready` while a change is broken.
