# Overview: Backing Up What Git Does Not Hold (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, starts an in-cluster Git server, bootstraps Flux from it, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The Flux command-line tool 2.9.6, and Flux bootstrapped from `gitops/fleet` at the path `clusters/kind`, with podinfo in the namespace `podinfo`.
- Gitea, an in-cluster Git server, with the lab-only user `gitops` and the password `gitops-password`. The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`.
- Two Secrets in `podinfo`, `app-credentials` and `registry-auth`, created by hand and labelled `dr-backup=critical`. They are not in Git.

To use `git` from your machine, start a port-forward in a second terminal and leave it running. If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

## Helpers

Paste these once in each new terminal. `export_secrets` writes a cleaned export of the labelled Secrets to a file. `secret_hash` prints a hash of one value without showing it.

```sh
export_secrets() {
  kubectl -n podinfo get secrets -l dr-backup=critical -o yaml \
    | grep -v -E '^    (uid|resourceVersion|creationTimestamp):' > "$1"
}
secret_hash() {
  kubectl -n podinfo get secret "$1" -o jsonpath='{.data.password}' | { sha256sum 2>/dev/null || shasum -a 256; } | cut -d' ' -f1
}
```

## Practice tasks

- List the Secrets in the cluster that Flux did not apply: `kubectl get secrets -A -l '!kustomize.toolkit.fluxcd.io/name'`. Mark the ones a person created.
- Run `kubectl -n podinfo get secrets -l dr-backup=critical -o yaml > raw.yaml`, delete one Secret, and apply `raw.yaml`. Read the error. Then use `export_secrets` and apply the cleaned file.
- Run `flux export kustomization --all -A` and compare it with the files in Git.
- Delete `app-credentials` and `registry-auth`, restore them from your cleaned file, and compare hashes with `secret_hash`.
- Create a Secret in `flux-system` with the label `dr-backup=critical`, and run `export_secrets` again. Decide whether it should be in the backup.
