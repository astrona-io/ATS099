# Overview: Governing Tenants With Repositories And Policy (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, starts an in-cluster Git server, bootstraps Flux from it, onboards the tenant `team-a`, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster, version 1.30 or later. `kubectl` is already pointed at it.
- The Flux command-line tool 2.9.6, and Flux bootstrapped from `gitops/fleet` at the path `clusters/kind`. The controllers run without lockdown flags.
- Gitea, an in-cluster Git server, with the lab-only user `gitops` and the password `gitops-password`:

  | Repository | What it holds |
  | --- | --- |
  | `gitops/fleet` | The platform repository: `tenants/team-a/`, `clusters/kind/tenants.yaml` and the platform's podinfo |
  | `gitops/team-a` | The tenant repository, public: `app/` and `escalate/` |

To use `git` from your machine, start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal. If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

## Helpers

```sh
probe() {
  # probe [serviceAccountName]: server-side dry run of a tenant Kustomization.
  kubectl apply --dry-run=server -f - <<YAML
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: probe
  namespace: team-a
spec:
  interval: 5m
  ${1:+serviceAccountName: $1}
  sourceRef:
    kind: GitRepository
    name: team-a
  path: ./app
YAML
}
```

## Practice tasks

- Run `probe` and `probe team-a` before you add any policy, and note that both succeed.
- Add the policy and the binding from Git, then run both again.
- Change `validationActions` to `Warn` and read the warning in the `kubectl` output.
- Add a second rule that requires `prune: true`, and test it with a probe.
- Run `flux tree kustomization team-a -n team-a` and `flux trace deployment podinfo -n team-a`.
- Run `kubectl auth can-i --list -n team-a --as=system:serviceaccount:team-a:team-a`.
