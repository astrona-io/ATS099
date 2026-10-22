# Solution: Find Why No Alert Arrives

Work the task yourself first. Running `astrona submit -c sections/section-020/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the alerting objects are in Git, they are set up to deliver errors from both objects without a catch-all exclusion, a podinfo failure arrives, and a source failure arrives.

## Step 1: Read what is there

```sh
kubectl -n flux-system get provider webhook -o yaml
kubectl -n flux-system get alert flux-errors -o yaml
kubectl -n monitoring logs deploy/webhook-receiver --tail=20
```

The receiver's log has no `POST` at all. The objects show three faults, each enough on its own to stop every alert:

- The `Provider`'s address is `http://webhook-receiver.monitor/flux`. The namespace is `monitoring`, so the name does not resolve.
- The `Alert` watches the `Kustomization` `podinfo` in the namespace `default`, where there is none, and does not watch the `GitRepository` at all.
- The `Alert` has `exclusionList: [".*"]`. That pattern matches every message, and `exclusionList` wins over everything else.

notification-controller's own log tells you about the first fault once an event gets that far:

```sh
kubectl -n flux-system logs deploy/notification-controller --tail=30
```

## Step 2: Fix the file

Start the port-forward in a second terminal, then clone and edit:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

In your first terminal:

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Replace `clusters/kind/alerts.yaml` with this:

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
  name: flux-errors
  namespace: flux-system
spec:
  providerRef:
    name: webhook
  eventSeverity: error
  eventSources:
    - kind: Kustomization
      name: podinfo
    - kind: GitRepository
      name: flux-system
```

Leaving out `namespace` in each event source means the `Alert`'s own namespace, `flux-system`, which is where both objects live.

## Step 3: Push and prove it

```sh
git commit -am "Deliver Flux errors to the webhook receiver"
git push
flux reconcile kustomization flux-system --with-source
```

Prove the `Kustomization` source with a broken path in Git, as in the module: change `path: ./apps/podinfo` to `path: ./apps/podinfo-missing` in `clusters/kind/podinfo.yaml`, push, reconcile `flux-system` and `podinfo`, read the receiver's log, then `git revert --no-edit HEAD` and push again.

Prove the source with a branch that does not exist. Pause `flux-system` first, so it does not put the branch back while you test:

```sh
flux suspend kustomization flux-system
kubectl -n flux-system patch gitrepository flux-system --type merge -p '{"spec":{"ref":{"branch":"missing"}}}'
flux reconcile source git flux-system
kubectl -n monitoring logs deploy/webhook-receiver --since=2m
```

The log holds a `POST` with `severity` `error` for the `GitRepository` `flux-system`. Put everything back:

```sh
kubectl -n flux-system patch gitrepository flux-system --type merge -p '{"spec":{"ref":{"branch":"main"}}}'
flux resume kustomization flux-system
```

## Step 4: Submit

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `eventSeverity: info` to "see something" | Every success floods the receiver; the grader requires `error` |
| Replace `".*"` with `".+"` | It still matches every message; the grader tests the patterns against ordinary errors |
| Fix only the address | Nothing arrives: the source is still the wrong namespace and the exclusion still drops everything |
| Edit the objects with `kubectl` | `flux-system` puts them back on the next reconcile |
