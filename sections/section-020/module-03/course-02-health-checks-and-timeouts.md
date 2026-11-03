# Health Checks And Timeouts

Applying a manifest means the API server accepted it. It does not mean the application works. A Deployment with a wrong image is applied without an error and then fails to start. Health checks make Flux wait for the result and report it.

## wait

`spec.wait: true` makes the Kustomization wait until every object it applied is ready. Flux judges readiness with the kstatus rules: a Deployment is ready when its rollout is complete, a Job when it has completed, a custom resource when its `Ready` condition is `True`. Objects that kstatus cannot judge count as ready as soon as they exist.

`wait: true` is simple and covers everything. Its cost is that one slow or broken object, even a minor one, holds up the whole Kustomization.

## healthChecks

`spec.healthChecks` lists the objects that matter:

```yaml
spec:
  wait: false
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: podinfo
      namespace: podinfo
```

Each entry names one object by `apiVersion`, `kind`, `name` and `namespace`. Only these are checked. When `wait: true` is set, `healthChecks` is ignored, because `wait` already covers every object, so use one or the other.

Choose `healthChecks` when a Kustomization applies many objects and only a few decide whether the application works. Choose `wait: true` when everything matters or the list is long.

## timeout

`spec.timeout` is how long Flux waits for the apply and for the health checks. When the time passes with an object still not ready, the reconcile fails with `HealthCheckFailed`. Without `timeout`, the value of `interval` is used. Set `timeout` to the time a healthy rollout needs, plus a margin. A value that is too short fails slow but healthy rollouts. A value that is too long delays the alert.

## retryInterval

After a failure, Flux tries again after `spec.retryInterval`, and not after `interval`. Without `retryInterval`, the retry waits for `interval`. A long `interval` with no `retryInterval` means a transient failure, such as an image that is not pushed yet, takes a full interval to recover. A short `retryInterval` such as `1m` recovers quickly without polling Git that often.

```yaml
spec:
  interval: 10m
  retryInterval: 1m
  timeout: 2m
  wait: false
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: podinfo
      namespace: podinfo
```

## Health checks and dependsOn

`spec.dependsOn` makes a Kustomization wait until another one is `Ready`. Because `Ready` includes the health checks, a dependent Kustomization starts only when the application it depends on works. Order the platform this way: namespaces and CRDs first, then controllers, then applications.

## HelmRelease

A HelmRelease uses Helm's own wait. `spec.install.remediation` and `spec.upgrade.remediation` set the number of retries and whether a failed upgrade is rolled back. The Kustomization health checks cover a HelmRelease as an object with a `Ready` condition.

## Check it

```sh
flux get kustomization podinfo
kubectl -n flux-system get kustomization podinfo -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
```

You expect `Healthy=True` after the rollout completes. To see a failure, push a change that breaks the image through Git, watch the Kustomization turn `Healthy=False` after the timeout, and revert the commit.

## Common pitfalls

> [!WARNING]
> - **Setting both `wait: true` and `healthChecks`.** The list is ignored.
> - **A `timeout` shorter than the rollout.** The Kustomization fails although the application starts.
> - **No `retryInterval` with a long `interval`.** Recovery from a transient failure is slow.
> - **Checking a Deployment that does not exist.** The reconcile waits until the timeout and fails.
