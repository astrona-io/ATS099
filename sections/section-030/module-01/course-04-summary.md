# Summary

A Flux `Kustomization` reads a source in its own namespace and applies to its own cluster, unless you tell it otherwise. This module changed both defaults, and showed when each change is safe.

## What you learned

`sourceRef.namespace` lets a Flux object use a source in another namespace, so several teams can share one fetch. On a shared platform that same reference lets a team read and apply folders that are not theirs, with the controller's rights. The lockdown flag `--no-cross-namespace-refs=true` refuses such references, together with `dependsOn` and `Alert` event sources in other namespaces, and each tenant gets its own `GitRepository` instead.

`spec.kubeConfig.secretRef` makes kustomize-controller apply to another cluster. Fetching and building stay on the cluster that runs Flux; only the apply goes through the kubeconfig. A kubeconfig has a cluster entry with the API server address and its certificate authority, a user entry with the credentials, and a context that joins them. It holds a credential, so it lives in a Secret, never in Git, under the key `value` or `value.yaml` unless `secretRef.key` names another one. The account in the kubeconfig decides what Flux may change on the remote cluster, so it should hold only the kinds and namespaces Flux must change. The `Kustomization`'s inventory shows what it applied.

A fleet of clusters runs Flux in one of two layouts: standalone, with Flux on every cluster and a folder per cluster, or hub and spoke, with one management cluster delivering through a kubeconfig Secret per cluster. Cluster API writes a `<cluster>-kubeconfig` Secret, key `value`, for every cluster it creates, in the `Cluster`'s namespace, so a Flux `Kustomization` in that namespace can deliver to the new cluster as soon as it exists. The key facts to remember are these:

- Cross-namespace references are on by default and off under the lockdown.
- The kubeconfig decides where Flux applies; the account in it decides what Flux may change.
- A kubeconfig is a Secret, not a file in Git.
- An account limited to one namespace cannot create that namespace.

<!-- astrona:playground:destroy -->
