# Reading Status Conditions

Every Flux object carries a list of **conditions** in its status. A condition has a type, a status of `True`, `False` or `Unknown`, a reason and a message. `flux get` shows the most important one. To find out what is wrong, you need to know all of them.

## Ready

`Ready` is the main condition. `True` means the last reconcile of the current spec finished with success. `False` means it failed, and the message says why. `Unknown` means a reconcile is in progress or has not started.

For a Kustomization, `Ready` `True` means the manifests were built and applied, and the health checks passed. For a GitRepository, `Ready` `True` means an artifact for the latest revision exists.

## Reconciling

`Reconciling` is `True` while the controller works on a change or retries a failure that is not final. It appears next to `Ready` `Unknown`. A `Reconciling` condition that stays `True` for a long time with the reason `ProgressingWithRetry` means the controller tries again and again. The message holds the last error.

## Stalled

`Stalled` is `True` when the controller has stopped trying because retrying cannot help, for example when the spec is invalid. Stalled objects wait for a change in Git or in the spec. If you see `Stalled`, fix the cause, because waiting will not help.

## Healthy

A Kustomization sets `Healthy` when it has health checks, either `wait: true` or a `healthChecks` list. `Healthy` `True` means all the checked resources are ready. `Healthy` `False` with the reason `HealthCheckFailed` means at least one is not. `Ready` is only `True` when `Healthy` is `True` as well.

A HelmRelease has similar conditions: `Ready`, `Reconciling` and `Stalled`, and `Remediated` when a failed upgrade was rolled back.

## Other fields of the status

- `observedGeneration` is the generation of the spec that the controller last handled. When it is lower than `metadata.generation`, the controller has not seen the latest change.
- `lastAppliedRevision` is the revision that is running. `lastAttemptedRevision` is the revision the controller tried last. If they differ, the last attempt failed and the old revision still runs.
- `inventory` lists the objects that the Kustomization applied, which is what pruning uses.

## Commands

```sh
flux get kustomizations -A
flux get all -A --status-selector ready=false
kubectl -n flux-system get kustomization podinfo -o jsonpath='{.status.conditions}'
kubectl -n flux-system wait kustomization/podinfo --for=condition=Healthy --timeout=2m
```

The second command lists only the objects that are not ready, in every namespace, and is the fastest way to see the state of a cluster. The last command blocks until the condition is `True` and fails after the timeout, which is useful in scripts and CI.

## Which condition for which question

| Question | Look at |
| --- | --- |
| Did the last reconcile work? | `Ready` |
| Is Flux still working on it? | `Reconciling` |
| Will it recover without a change? | `Stalled` |
| Is the application running? | `Healthy` |
| Which commit is running? | `lastAppliedRevision` |

## Common pitfalls

> [!WARNING]
> - **Reading only the `READY` column.** It hides whether the problem is the build, the apply or the health check.
> - **Ignoring `lastAttemptedRevision`.** A `Ready` `False` object can still run an older, working revision.
> - **Waiting for `Ready` on a suspended object.** A suspended object does not reconcile, so it never changes.
> - **Treating `Unknown` as failure.** It also means in progress. Wait for one interval first.
