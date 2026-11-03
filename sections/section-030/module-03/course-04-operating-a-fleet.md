# Operating A Fleet

With more than one cluster, most of the daily work is to see the state of all of them and to find the cause of a problem quickly. The Flux command line has what is needed.

## Contexts

Every `flux` command reads the kubeconfig as `kubectl` does, and the global flag `--context` selects the cluster:

```sh
flux --context management get kustomizations -A
flux --context staging get helmreleases -A
```

With the management layout, most objects are on the management cluster. The remote clusters hold only the applied objects, so `flux get` on a remote cluster shows nothing unless Flux also runs there.

## See the whole delivery

```sh
flux get kustomizations -A
flux tree kustomization podinfo-production
```

The first command lists every Kustomization with its Ready state and message. The second prints the objects in the inventory of one Kustomization. Check the objects themselves on the remote cluster with `kubectl --context`.

## Preview a change

```sh
flux diff kustomization podinfo-production --path ./apps/podinfo-production
```

It builds the local folder and compares it with the live objects, without applying. It is the check to run before a merge. It reads the Kustomization from the cluster you are connected to, so run it against the management cluster, and check the result of a remote delivery with the tools of the remote cluster.

## Find what changed an object

```sh
flux trace deployment podinfo -n podinfo-production
```

It follows the labels on an object back to the Kustomization and the source that applied it, and shows the revision. It looks for the Kustomization in the cluster you are connected to, so it fits objects applied to that cluster. For a remote delivery, read the labels with `kubectl --context staging get deployment podinfo -n podinfo-staging -o yaml` and look up the Kustomization on the management cluster.

## Pause one environment

```sh
flux suspend kustomization podinfo-production
flux resume kustomization podinfo-production
```

Suspending stops the reconcile and keeps the objects. Use it to freeze production during an incident. Make sure a suspended object is visible in your monitoring: `flux get kustomizations -A` shows a suspended column.

## Naming that scales

- Put the environment in the name of the Kustomization: `podinfo-staging`, `podinfo-production`.
- Put the cluster in the name of the kubeconfig Secret: `staging-kubeconfig`, `production-kubeconfig`.
- Keep one folder per cluster under `clusters/`, so one directory shows everything a cluster receives.

## Common pitfalls

> [!WARNING]
> - **Running a command against the wrong context.** Print `kubectl config current-context` first, or always use `--context`.
> - **Using `flux suspend` and forgetting it.** A frozen production drifts from Git for weeks.
> - **Expecting `flux get` on a remote cluster to show the delivery.** The Kustomization is on the management cluster.
> - **Previewing with `flux diff` against the wrong path.** The result looks clean but compares the wrong folder.
