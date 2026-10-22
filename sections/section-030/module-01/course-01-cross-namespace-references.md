# Cross-Namespace References

A Flux source costs work: source-controller fetches it on every interval and stores an artifact. When three teams need the same repository, three `GitRepository` objects fetch it three times. A reference across namespaces lets them share one. This part shows such a reference working, then explains why a shared platform usually forbids it.

## One source, used from another namespace

A Flux `Kustomization` names its source in `spec.sourceRef`. Without `namespace`, Flux looks for the source in the `Kustomization`'s own namespace. With `namespace`, it looks there instead. The same field exists on other Flux objects: a `HelmRelease` can use a chart from another namespace, an `Alert` can watch objects in another namespace, and `dependsOn` can name a `Kustomization` elsewhere.

Try it. Create a namespace for a team that has no source of its own, then give it a Flux `Kustomization` that uses the platform's `GitRepository` `flux-system`. Create the namespaces first:

<!-- astrona:playground:renew -->

```sh
kubectl create namespace web-team
kubectl create namespace web-preview
```

Then save this as `kustomization-web-preview.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: web-preview
  namespace: web-team
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  path: ./apps/podinfo-staging
  targetNamespace: web-preview
  prune: true
```

This test object is applied by hand on purpose, so you can delete it at the end. Apply it:

```sh
kubectl apply -f kustomization-web-preview.yaml
```

Then check the result:

```sh
flux get kustomization web-preview -n web-team
kubectl -n web-preview get deployment,service
```

The `Kustomization` is `Ready`, and podinfo runs in `web-preview`. kustomize-controller fetched the artifact of the `GitRepository` in `flux-system`, built `./apps/podinfo-staging`, and applied it into the target namespace. No new fetch happened: the artifact was already there.

## Why platforms forbid it

The same reference that saves a fetch also reads files that are not the team's. The `GitRepository` `flux-system` holds the whole platform repository: every cluster's configuration, every tenant's RBAC, every path. A team that can point at it can apply any folder of it. Under the default settings that would happen with kustomize-controller's own rights, which are `cluster-admin`.

That is why the multi-tenancy lockdown sets `--no-cross-namespace-refs=true` on the controllers that follow references. With the flag on, a `sourceRef`, `dependsOn` or `eventSources` entry with another namespace is refused, and the object reports that the reference crosses namespaces. Each team then gets its own `GitRepository` in its own namespace, pointing only at its own repository. The cost is one more fetch per team, which is small next to what it protects.

| Setup | Cross-namespace references | Who uses it |
| --- | --- | --- |
| One team owns the cluster | Allowed (the default) | Small clusters, the platform's own objects |
| Several tenants share the cluster | Forbidden with `--no-cross-namespace-refs=true` | Shared platforms |

Clean up the test objects, so they do not stay in the cluster without being in Git:

```sh
kubectl delete -f kustomization-web-preview.yaml
kubectl delete namespace web-preview web-team
```

You now know how to point a Flux object at a source in another namespace, and why a shared platform turns that off. The question still open is the bigger reach: applying not to another namespace, but to another cluster.

## Common pitfalls

> [!WARNING]
> - **Expecting `namespace` to be implied.** Without `sourceRef.namespace`, Flux only looks in the object's own namespace.
> - **Sharing the `flux-system` source with tenants.** It holds the whole platform repository. Give each tenant its own `GitRepository`.
> - **Forgetting that the lockdown covers more than sources.** `--no-cross-namespace-refs=true` also refuses `dependsOn` and `Alert` event sources in other namespaces.
> - **Leaving hand-applied test objects behind.** Anything not in Git drifts from what the platform repository says. Delete it, or commit it.
