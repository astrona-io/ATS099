# What A Receiver Is

A Flux source asks for changes on a timer. A GitRepository with `interval: 5m` runs `git ls-remote` every five minutes and fetches when the commit changed. Between two runs, a push waits.

A `Receiver` reverses the direction. notification-controller opens an HTTP endpoint. When a Git host, a registry or your CI system calls it, the controller asks the named Flux objects to reconcile now. The call carries no instructions beyond "check again", so a wrong or forged call cannot make Flux apply anything that is not in Git. At worst it causes an extra fetch.

## Polling and receivers together

A Receiver does not replace the interval. The interval stays as the fallback when a webhook is lost, because a webhook is sent once and not retried by every host. A common setting is a Receiver together with a long interval such as `1h`, which gives fast updates and few requests.

Use a Receiver when you need a change to roll out within seconds, or when many sources poll the same host and you want fewer requests. Skip it when a delay of a few minutes is fine, because a Receiver needs a public or routable address and a secret to maintain.

## The object

A Receiver is in `notification.toolkit.fluxcd.io/v1`:

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1
kind: Receiver
metadata:
  name: fleet
  namespace: flux-system
spec:
  type: generic
  secretRef:
    name: receiver-token
  resources:
    - apiVersion: source.toolkit.fluxcd.io/v1
      kind: GitRepository
      name: flux-system
```

- `spec.type` selects how the controller checks the request. The types are covered in a later part.
- `spec.secretRef` names a Secret with the key `token`. The token is a shared secret between the sender and the controller.
- `spec.resources` lists the Flux objects to reconcile. Each entry has `apiVersion`, `kind` and `name`, and the namespace of the Receiver unless it names another. The name `"*"` with a `matchLabels` selector selects several objects.
- `spec.interval` is how often the controller checks the Receiver itself, not how often it fetches sources.

## What the controller does with a call

For a request that arrives on the Receiver's path, the controller checks the request against the type, finds the listed objects, and sets the annotation `reconcile.fluxcd.io/requestedAt` on each one to the current time. The source controller sees the new value and reconciles the object. It is the same annotation that `flux reconcile` sets.

You can see the effect on the object:

```sh
kubectl -n flux-system get gitrepository flux-system \
  -o jsonpath='{.metadata.annotations.reconcile\.fluxcd\.io/requestedAt}'
```

A change of the value after a call proves that the Receiver worked. A reconcile of a source that finds no new commit changes the annotation but fetches nothing new.

## Receivers that reach a chain of objects

Reconciling the GitRepository is enough to roll out a change, because a Kustomization that uses the source reconciles when the source has a new revision. List a Kustomization in `resources` only to force it to reconcile without a new revision.

## Check that the Receiver is ready

```sh
kubectl -n flux-system get receivers
```

The columns show `READY` and a message. A Receiver is not ready when the Secret is missing or has no `token` key. The message names the problem.

## Common pitfalls

> [!WARNING]
> - **Removing the interval from the sources.** A lost webhook then leaves the cluster behind with no fallback.
> - **Listing objects in the wrong namespace.** An entry without `namespace` means the Receiver's own namespace.
> - **Expecting the call to carry a revision.** The Receiver only asks for a reconcile. The source fetches the latest revision of the branch it follows.
> - **Using the Receiver as a deploy button for a branch Flux does not follow.** It cannot change which branch or tag is applied.
