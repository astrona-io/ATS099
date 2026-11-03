# Solution: Check The Health Of One Deployment

Work the task yourself first. Running `astrona submit -c sections/section-020/module-03/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the spec of the Kustomization, its conditions, and the file in Git.

## Step 1: Clone the repository

Start the port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Clone the repository with the user `gitops` and the password `gitops-password`:

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

## Step 2: Edit the Kustomization

Open `clusters/kind/podinfo.yaml` and make the `spec` look like this:

```yaml
spec:
  interval: 5m
  retryInterval: 1m
  timeout: 2m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./apps/podinfo
  prune: true
  wait: false
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: podinfo
      namespace: podinfo
```

The line `wait: true` is gone. When `wait` is true, Flux ignores `healthChecks`.

## Step 3: Commit, push and reconcile

```sh
git add clusters/kind/podinfo.yaml
git commit -m "Check only the podinfo Deployment, time out after 2m"
git push
flux reconcile kustomization flux-system --with-source
flux reconcile kustomization podinfo --with-source
```

Run `astrona submit -c sections/section-020/module-03/labs/lab-01` now.

## Step 4: Check it yourself

```sh
kubectl -n flux-system get kustomization podinfo -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
```

You expect `Ready=True` and `Healthy=True`.

## If something is wrong

- **`Healthy` is missing.** The Kustomization has no health check yet. Check that the commit reached Flux with `flux get kustomization flux-system`.
- **`Healthy` is `False`.** Read the message. The Deployment name or the namespace in `healthChecks` is probably wrong.
- **The old values stay.** The `flux-system` Kustomization may not have reconciled. Run `flux reconcile kustomization flux-system --with-source`.
