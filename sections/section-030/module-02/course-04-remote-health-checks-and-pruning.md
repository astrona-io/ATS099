# Remote Health Checks And Pruning

With `spec.kubeConfig` set, three things that a Kustomization does all happen on the other cluster: the health checks, the pruning, and the deletion of what it applied. The source and the build stay local. Because the effects are remote and the rights are narrow, each of the three has an edge case.

## Health checks

`spec.wait` and `spec.healthChecks` use the same client as the apply. The controller watches the objects on the remote cluster, so the account needs `get`, `list` and `watch` on them. A Role with only `create` and `patch` applies fine and then fails the health check with a message about forbidden.

A health check on a remote cluster reports the state of the remote objects, which is the point. A Kustomization that is `Ready` means the application runs there.

## Network

The controller must reach the remote API server and watch it for as long as the health check runs. A firewall that drops long connections can make health checks time out although the application is fine. Set `timeout` for the slowest rollout, and test the path from a pod in the Flux cluster.

## Pruning

With `prune: true`, objects that disappear from Git disappear from the remote cluster. The controller finds them in the Kustomization's inventory. Pruning needs `delete` on the kind for the remote account. When a prune is refused, the status shows forbidden and the object stays on the remote cluster.

Protect an object from pruning with the annotation `kustomize.toolkit.fluxcd.io/prune: disabled` in its manifest. Use it for objects that hold data, such as a PersistentVolumeClaim.

## Deleting the Kustomization

When a Kustomization with `prune: true` is deleted, the controller removes everything in its inventory from the remote cluster, using the kubeconfig. This is the correct behaviour for a decommission and a risk for a mistake. The field `spec.deletionPolicy` controls it. The default, `MirrorPrune`, deletes the objects when `prune` is true and keeps them when it is false. The value `Orphan` always keeps them, and `Delete` always removes them.

Two cases need care:

- **The kubeconfig is gone.** The cleanup cannot run, and the Kustomization stays in terminating. Restore the Secret, or set `deletionPolicy` to `Orphan` before the delete when you accept that remote objects stay behind.
- **A Kustomization moved to another folder.** If you delete it and recreate it, the objects can be deleted and recreated. To move a Kustomization without a gap, change `path`, and do not delete the object.

## Dependencies across clusters

`spec.dependsOn` works between Kustomizations on the management cluster. A Kustomization that delivers to a remote cluster can depend on another that delivers to the same or another remote cluster. `Ready` of the dependency includes its remote health checks, so a dependent delivery starts when the first application runs on its cluster.

## Common pitfalls

> [!WARNING]
> - **A Role without `list` and `watch`.** The health checks fail although the apply works.
> - **Deleting a Kustomization with `prune: true` to "move" it.** Remote objects are removed.
> - **Losing the kubeconfig Secret before decommissioning.** The finalizer cannot finish.
> - **Setting `timeout` shorter than a remote rollout.** The Kustomization fails while the application starts.
