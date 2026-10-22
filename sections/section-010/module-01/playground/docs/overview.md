# Overview: Onboard Tenants With Impersonation (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, starts an in-cluster Git server, bootstraps Flux from it, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The Flux command-line tool 2.9.6, and Flux bootstrapped from `gitops/fleet` at the path `clusters/kind`. The Flux controllers run without any lockdown flags.
- Gitea, an in-cluster Git server, with the lab-only user `gitops` and the password `gitops-password`:

  | Repository | What it holds |
  | --- | --- |
  | `gitops/fleet` | The platform repository: `apps/podinfo/`, `clusters/kind/podinfo.yaml` and the `flux-system/` folder written by bootstrap |
  | `gitops/team-a` | The tenant repository, public: `app/` (podinfo, with no namespace in the files) and `escalate/` (a ClusterRole no tenant may create) |

- The platform's podinfo, running in the namespace `podinfo`.

Every repository is at `http://gitea.localtest.me:3000/gitops/<name>.git`. To use `git` from your machine, start a port-forward in a second terminal and leave it running. If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

## Helpers

Paste these once in each new terminal. `show_flux` lists every Flux `Kustomization` and `GitRepository` in every namespace. `can_tenant` asks Kubernetes whether the ServiceAccount `team-a/team-a` may do something, for example `can_tenant create clusterroles`. `controller_args` prints the arguments of one Flux controller.

```sh
show_flux() {
  flux get sources git -A
  flux get kustomizations -A
}
can_tenant() {
  kubectl auth can-i "$@" --as=system:serviceaccount:team-a:team-a
}
controller_args() {
  kubectl -n flux-system get deployment "$1" -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}'
}
```

Use them like this: `show_flux`, `can_tenant create deployments -n team-a`, `controller_args kustomize-controller`.

## Practice tasks

- Run `flux create tenant team-b --with-namespace=team-b --export` and compare it with the `rbac.yaml` you would write by hand.
- Onboard `team-a`, then run `can_tenant create deployments -n podinfo` and explain the answer.
- Before you add the lockdown, apply a tenant Flux `Kustomization` without `serviceAccountName` that points at `./escalate`, and see whether the ClusterRole appears. Delete the ClusterRole and the test object afterwards, then add the lockdown and try again.
- After the lockdown, point a test `Kustomization` in `team-a` at the `GitRepository` `flux-system` in `flux-system` (set `sourceRef.namespace`) and read the message `flux get` shows.
- Remove `serviceAccountName` from `clusters/kind/podinfo.yaml` under the lockdown, push, and watch which account the "forbidden" message names. Put it back.
