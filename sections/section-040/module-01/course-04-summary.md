# Summary

GitOps keeps the desired state of a cluster in Git, and recovery is where that promise is tested. This module practised recovery: what Git can and cannot give back, how to pause and remove Flux safely, and the order for rebuilding a cluster.

## What you learned

Git holds every manifest Flux applies, including Flux's own controllers and sync objects. It does not hold the Git credential in the Secret `flux-system`, the credentials of other sources, kubeconfigs for remote clusters, the keys that decrypt encrypted files, Secrets that teams created by hand, or data in volumes. Each of those needs a home outside the cluster, such as a password manager or a secret store, and must be back before Flux needs it. `flux export` records the Flux objects, never Secret values.

`flux suspend kustomization --all` pauses every Flux `Kustomization` in a namespace and `flux resume` ends the pause and reconciles. A `suspend: true` committed to Git lasts until someone removes it from Git, because `flux-system` applies it again. `flux uninstall` removes the controllers, the CRDs and the Flux objects, removes their finalizers first so nothing is pruned, and leaves the workloads running; `--keep-namespace` keeps `flux-system` and its Secrets. Running `flux bootstrap` again with the same repository, branch and path brings Flux back, and kustomize-controller adopts the running objects with server-side apply. The same UID and an entry in the inventory prove an object was adopted, not recreated.

Rebuilding a lost cluster follows one rule: credentials and keys first, then bootstrap, then let sources fetch and `dependsOn` order the rest, then restore data, then verify. On a new cluster every object is created fresh, objects that only lived outside Git are gone, and a forgotten suspend in Git is applied again. The key facts to remember are these:

- Git rebuilds objects, not credentials and not data.
- `flux uninstall` leaves workloads; deleting a `Kustomization` with `prune: true` does not.
- Bootstrap again with the same repository, branch and path.
- Prove recovery with UIDs and inventories, and practise it before you need it.

<!-- astrona:playground:destroy -->
