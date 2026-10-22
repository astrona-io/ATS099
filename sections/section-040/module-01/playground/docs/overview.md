# Overview: Recover A Cluster From Git (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, starts an in-cluster Git server, bootstraps Flux from it, and then waits. There is no task, no `astrona submit` and no pass or fail. Remove Flux, bring it back, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The Flux command-line tool 2.9.6, and Flux bootstrapped from `gitops/fleet` at the path `clusters/kind`, with token authentication. The Flux `Kustomization` `podinfo` deploys podinfo into the namespace `podinfo`.
- Gitea, an in-cluster Git server, with the lab-only user `gitops` and the password `gitops-password`. The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`.

To use `git` and `flux bootstrap` from your machine, start a port-forward in a second terminal and leave it running. If your machine cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

## Helpers

Paste these once in each new terminal. `podinfo_uid` prints the UID of the podinfo Deployment. `podinfo_inventory` lists what the Flux `Kustomization` `podinfo` applied. `rebootstrap` runs `flux bootstrap git` with the playground's repository, branch, path and lab-only credentials.

```sh
podinfo_uid() {
  kubectl -n podinfo get deployment podinfo -o jsonpath='{.metadata.uid}{"\n"}'
}
podinfo_inventory() {
  kubectl -n flux-system get kustomization podinfo -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}'
}
rebootstrap() {
  flux bootstrap git --url=http://gitea.localtest.me:3000/gitops/fleet.git \
    --branch=main --path=clusters/kind --username=gitops --password=gitops-password \
    --token-auth=true --allow-insecure-http=true --silent
}
```

Use them like this: `podinfo_uid`, `podinfo_inventory`, `rebootstrap`.

## Practice tasks

- Uninstall Flux **without** `--keep-namespace`, check which Secrets disappeared, and bring Flux back with `rebootstrap`.
- Commit `suspend: true` to `clusters/kind/podinfo.yaml`, run `flux resume kustomization podinfo`, then `flux reconcile kustomization flux-system --with-source`, and watch the suspend come back.
- Delete the Flux `Kustomization` `podinfo` with `kubectl delete` (not `flux uninstall`) and watch what happens to the podinfo Deployment. Then let `flux-system` bring it back, and compare the UID.
- Run `flux export kustomization --all` before and after a reinstall and compare the two files.
