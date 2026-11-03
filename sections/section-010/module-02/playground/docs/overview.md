# Overview: Guardrails And Secrets For Tenants (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, starts an in-cluster Git server, bootstraps Flux from it, onboards the tenant `team-a`, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- The Flux command-line tool 2.9.6, and Flux bootstrapped from `gitops/fleet` at the path `clusters/kind`. The controllers run without lockdown flags.
- Gitea, an in-cluster Git server, with the lab-only user `gitops` and the password `gitops-password`:

  | Repository | What it holds |
  | --- | --- |
  | `gitops/fleet` | The platform repository: `tenants/team-a/` (Namespace, ServiceAccount, RoleBinding to `cluster-admin`, `GitRepository`, `Kustomization`), `clusters/kind/tenants.yaml` and the platform's podinfo |
  | `gitops/team-a` | The tenant repository, public: `app/` and `escalate/` |

To use `git` from your machine, start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal. If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

## Helpers

```sh
can_tenant() {
  kubectl auth can-i "$@" --as=system:serviceaccount:team-a:team-a
}
show_guardrails() {
  kubectl -n team-a get rolebinding,resourcequota,limitrange,networkpolicy
}
```

## Practice tasks

- Run `can_tenant update resourcequotas -n team-a`, switch the binding to `admin` by renaming it, and run it again.
- Edit `roleRef` in place instead of renaming, push, and read the error on the `tenants` Kustomization.
- Add a ResourceQuota with `requests.cpu` and no LimitRange, then scale podinfo up and read the events.
- Add `default-deny-ingress`, then start a pod in another namespace and try to reach the podinfo Service.
- Run `flux create tenant team-b --with-namespace=team-b --cluster-role=admin --export` and compare the output with `rbac.yaml`.
- Create an age key with `age-keygen` and a Secret `sops-age` in `team-a`, then add `spec.decryption` to the tenant Kustomization.
