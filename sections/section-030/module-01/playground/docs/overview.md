# Overview: Deliver To Other Namespaces And Clusters (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, starts an in-cluster Git server, bootstraps Flux from it, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The Flux command-line tool 2.9.6, and Flux bootstrapped from `gitops/fleet` at the path `clusters/kind`, with podinfo in the namespace `podinfo`. The controllers run without the multi-tenancy lockdown, so cross-namespace references are allowed.
- Gitea, an in-cluster Git server, with the lab-only user `gitops` and the password `gitops-password`. The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`. It also holds `apps/podinfo-staging/`, podinfo without a Namespace object.
- The "remote cluster" side, which in this playground lives in the same cluster:

  | Object | What it is |
  | --- | --- |
  | ServiceAccount `flux-deployer` in `staging-access` | The account Flux uses on the "remote cluster" |
  | Secret `flux-deployer-token` in `staging-access` | A long-lived token and the CA certificate for that account |
  | Role `deployer` and RoleBinding in `podinfo-staging` | Lets `flux-deployer` change Deployments and Services in `podinfo-staging`, and nothing else |

To use `git` from your machine, start a port-forward in a second terminal and leave it running. If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

## Helpers

Paste these once in each new terminal. `can_deployer` asks Kubernetes whether `flux-deployer` may do something. `staging_inventory` lists what the Flux `Kustomization` `podinfo-staging` applied. `kubeconfig_in_secret` prints the kubeconfig stored in `staging-kubeconfig`.

```sh
can_deployer() {
  kubectl auth can-i "$@" --as=system:serviceaccount:staging-access:flux-deployer
}
staging_inventory() {
  kubectl -n flux-system get kustomization podinfo-staging \
    -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}'
}
kubeconfig_in_secret() {
  kubectl -n flux-system get secret staging-kubeconfig -o jsonpath='{.data.value}' | base64 --decode
}
```

Use them like this: `can_deployer create services -n podinfo-staging`, `staging_inventory`, `kubeconfig_in_secret`.

## Practice tasks

- Add a ConfigMap to `apps/podinfo-staging/` in Git and watch `podinfo-staging` fail with a "forbidden" message. Grant `configmaps` in the Role, and watch it recover. Then decide whether the grant belongs there.
- Store the kubeconfig under the key `config` instead of `value`, and fix the Flux `Kustomization` with `spec.kubeConfig.secretRef.key` instead of renaming the key.
- Change the server address in the kubeconfig to a port that does not answer and read the message in `flux get`.
- Delete `apps/podinfo-staging/service.yaml` from Git and check that Flux prunes the Service through the kubeconfig.
