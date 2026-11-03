# A Daily Operating Checklist

This part collects what an operator of a Flux cluster runs regularly. Each item is a real command and says what to expect, so the checks can become a script or a runbook.

## 1. Check the installation

```sh
flux check
```

The command checks the cluster, the version of Kubernetes, and the Flux controllers and CRDs. It exits with an error when a controller is missing or not ready. Run it after every upgrade of Kubernetes or Flux, and `flux check --pre` before a first install or an upgrade to test the prerequisites.

## 2. List everything that is not ready

```sh
flux get all -A --status-selector ready=false
```

You expect no rows. A row names the kind, the namespace, and the message. Start with the oldest object, because a failed dependency makes dependent objects fail as well.

## 3. List what is suspended

```sh
flux get kustomizations -A
flux get helmreleases -A
flux get sources git -A
```

The column `SUSPENDED` shows `True` for each suspended object. Suspended objects are often forgotten after a test or an incident. Each one needs an owner and a reason. Resume with `flux resume kustomization NAME`.

## 4. Follow an object to what it runs

```sh
flux tree kustomization flux-system
flux trace deployment podinfo -n podinfo
```

`flux tree` shows what a Kustomization created. `flux trace` goes the other way, from a resource to the Kustomization, the source and the revision that manage it.

## 5. Read recent errors

```sh
flux events -A
flux logs --level=error --all-namespaces --since=1h
```

Events show what happened to each object. Logs show the controller's side. Read both after a failure.

## 6. Get the numbers

```sh
flux stats -A
```

The command is a preview command, so its output may change. It prints the number of objects of each kind, how many are ready, failing, and suspended, and the storage used by sources. A rise in the number of failing objects, or in storage, is a reason to look closer. The command is a quick summary; the dashboards give the history.

## 7. Check what changed

```sh
flux diff kustomization podinfo --path ./apps/podinfo
```

The command compares a local directory with what runs in the cluster. Use it before a merge, in CI, to see the effect of a change. It needs read access to the cluster.

## 8. Watch the controllers

```sh
kubectl -n flux-system top pods
kubectl -n flux-system get pods
```

A controller that restarts or reaches its memory limit stops reconciling. Raise its limits through a patch in Git. Watch the storage of source-controller too, because it keeps the artifacts of every source on its volume.

## 9. Upgrade on a schedule

Upgrade Flux when a new minor version appears, one minor version at a time. Read the release notes for removed APIs, run `flux check --pre`, update through Git, and run `flux check` again. Flux supports the latest minor versions of its own releases, so staying behind means missing security fixes.

## Make it a runbook

Put items 1 to 3 into a daily job or a dashboard. Put items 4 to 6 into the response to an alert. Put items 7 to 9 into the change process. An operator who finds the same problem twice should add a check or an alert for it.

## Common pitfalls

> [!WARNING]
> - **Suspending an object and not telling anyone.** Add an owner and a ticket, and alert on long suspensions.
> - **Reading `flux get kustomizations` only.** Sources and Helm objects fail separately. Use `flux get all -A`.
> - **Skipping minor versions in an upgrade.** Upgrade one at a time and read each set of notes.
> - **Fixing a failure with `kubectl` only.** Flux restores the old state. Fix it in Git.
