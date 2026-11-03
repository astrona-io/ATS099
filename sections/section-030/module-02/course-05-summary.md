# Summary

A kubeconfig Secret is a long-lived credential for another cluster. This module covered how Flux reads it, how to renew it, how little the account needs, and what the Kustomization does on the other cluster.

## What you learned

kustomize-controller reads the Secret named in `spec.kubeConfig.secretRef.name` in its own namespace, from the key `value`, then `value.yaml`, or the key set in `secretRef.key`. It reads the Secret at every reconcile, so a change takes effect with no restart. Kubeconfigs with `exec` or `auth-provider` are refused unless `--insecure-kubeconfig-exec` is set, and kubeconfigs that skip TLS verification are refused unless `--insecure-kubeconfig-tls` is set. Do not set them on a shared platform. HelmRelease has the same field.

A Secret of type `kubernetes.io/service-account-token` gives a token with no expiry. `kubectl create token --duration` gives a token that expires and must be renewed. To rotate with no gap, create the new token, build and test a new kubeconfig, replace the key in the Secret, reconcile, and delete the old token. A TokenReview shows whether the old token is still valid.

The account should hold the verbs `get`, `list`, `watch`, `create`, `update`, `patch` and `delete` on the kinds in the folder, in one namespace. Namespaces and cluster-scoped kinds need a separate account. `kubectl auth can-i --list --as` shows what an account can do.

Health checks, pruning and deletion all run on the remote cluster with that account. A missing `list` or `watch` breaks the health check, and a missing `delete` breaks the prune. Deleting a Kustomization with `prune: true` removes the remote objects unless `spec.deletionPolicy` is `Orphan`, and a missing kubeconfig blocks the cleanup. The annotation `kustomize.toolkit.fluxcd.io/prune: disabled` protects an object.

The key facts to remember are these:

- The kubeconfig Secret is in the Kustomization's namespace, under the key `value`.
- Rotate by replacing the key, then delete the old token.
- Grant the verbs and kinds the folder needs, and nothing else.
- Deleting a pruning Kustomization deletes what it applied, unless `deletionPolicy` says otherwise.

<!-- astrona:playground:destroy -->
