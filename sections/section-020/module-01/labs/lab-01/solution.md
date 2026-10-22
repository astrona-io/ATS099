# Solution: Alert A Webhook When podinfo Fails

Work the task yourself first. Running `astrona submit -c sections/section-020/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the `Provider` and the `Alert` are in Git under `clusters/kind/`, they are set up as asked, and a real podinfo failure reaches the receiver as an `error` while the recovery sends no `info` event.

## Step 1: Clone the repository

Start the port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

In your first terminal, clone with the user `gitops` and the password `gitops-password`:

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

## Step 2: Write the Provider and the Alert

Save this as `clusters/kind/alerts.yaml`:

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Provider
metadata:
  name: webhook
  namespace: flux-system
spec:
  type: generic
  address: http://webhook-receiver.monitoring/flux
---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: podinfo-errors
  namespace: flux-system
spec:
  providerRef:
    name: webhook
  eventSeverity: error
  eventSources:
    - kind: Kustomization
      name: podinfo
```

`eventSeverity: error` is the line that keeps successes out. Without it, the default `info` forwards every event.

## Step 3: Push and apply

```sh
git add clusters/kind/alerts.yaml
git commit -m "Send podinfo errors to the webhook receiver"
git push
flux reconcile kustomization flux-system --with-source
kubectl -n flux-system get providers,alerts
```

`webhook` and `podinfo-errors` are listed.

## Step 4: Prove it

Break podinfo through Git: change `path: ./apps/podinfo` to `path: ./apps/podinfo-missing` in `clusters/kind/podinfo.yaml`, then push and reconcile:

```sh
git commit -am "Break podinfo on purpose"
git push
flux reconcile kustomization flux-system --with-source
flux reconcile kustomization podinfo
kubectl -n monitoring logs deploy/webhook-receiver --since=2m
```

The log holds one `POST` with `severity` `error` for the `Kustomization` `podinfo`. Repair it, and check that the recovery sends nothing:

```sh
git revert --no-edit HEAD
git push
flux reconcile kustomization flux-system --with-source
flux reconcile kustomization podinfo
kubectl -n monitoring logs deploy/webhook-receiver --since=1m
```

podinfo is `Ready` again, and no new request arrived.

## Step 5: Submit

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Leave `eventSeverity` out | It defaults to `info`; the grader sees `info` events from the recovery and fails |
| `name: "*"` for every Kustomization | It works for podinfo, but forwards errors nobody asked for; the spec check expects `podinfo` |
| `kubectl apply` the objects | They work until the next `flux-system` reconcile, and the Git check fails |
| An `https://` address | The receiver only listens on plain HTTP, port 80 of its Service |
