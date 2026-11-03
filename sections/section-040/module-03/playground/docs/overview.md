# Overview: Upgrading And Tuning Flux (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, starts an in-cluster Git server, bootstraps Flux from it, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The Flux command-line tool 2.9.6, and Flux bootstrapped from `gitops/fleet` at the path `clusters/kind`, with podinfo in the namespace `podinfo`.
- Gitea, an in-cluster Git server, with the lab-only user `gitops` and the password `gitops-password`. The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`. Flux's own manifests are in `clusters/kind/flux-system/`.

To use `git` from your machine, start a port-forward in a second terminal and leave it running. If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

## Helpers

Paste these once in each new terminal. `km_args` prints the arguments of kustomize-controller. `km_limits` prints its resource limits. `flux_pods` lists the controller pods with their restart counts.

```sh
km_args() {
  kubectl -n flux-system get deployment kustomize-controller -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}'
}
km_limits() {
  kubectl -n flux-system get deployment kustomize-controller -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
}
flux_pods() {
  kubectl -n flux-system get pods
}
```

## Practice tasks

- Run `flux version`, `flux version --client` and `flux check`. Read what each reports.
- Run `flux install --export` and compare the result with `clusters/kind/flux-system/gotk-components.yaml` in the repository.
- Edit the Deployment `kustomize-controller` with `kubectl edit`, run `flux reconcile kustomization flux-system`, and watch the change disappear.
- Add a patch for `--concurrent=8` to `clusters/kind/flux-system/kustomization.yaml`, check it with `kubectl kustomize clusters/kind/flux-system`, push it, and watch the pod restart.
- Push a patch with a wrong path and read the error in `flux get kustomization flux-system`. Then fix it in Git.
- Read the metrics: `kubectl -n flux-system port-forward deploy/kustomize-controller 8080:8080`, then `curl -s localhost:8080/metrics | grep gotk_reconcile_duration`.
- Run `flux logs --all-namespaces --level=error --since=1h`.
