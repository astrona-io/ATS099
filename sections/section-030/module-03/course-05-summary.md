# Summary

This module covered how to run several environments from one repository, how to make production wait for staging, and how to work across clusters.

## What you learned

Push delivery applies from outside a cluster with a stored credential. Pull delivery fetches from inside. Flux can run in every cluster, or on a management cluster that applies to others through `spec.kubeConfig`. The second layout gives one place to look and one Flux to upgrade, and it makes the management cluster and its stored credentials critical. Choose from network reach, the number of clusters, and the blast radius of a credential store.

Environments should differ in small, visible ways. A folder per environment is the simplest. A base with an overlay per environment avoids copying. Values that belong to the cluster side go in `postBuild.substitute` or `substituteFrom`, and Secrets go in a Secret. Use folders and not branches for environments.

`spec.dependsOn` makes a Kustomization wait until another is `Ready`. For promotion, set `wait: true` or health checks on the first, so that `Ready` means the application runs. `dependsOn` is about state and not time, and it does not undo anything. Promotion by version gives each environment its own source or tag, and the change of the tag is the promotion.

`flux --context` selects a cluster. `flux get kustomizations -A` shows every delivery, `flux tree` shows what one owns, `flux diff kustomization` previews a change, and `flux trace` finds what applied an object. `flux suspend` pauses an environment and must not be forgotten.

The key facts to remember are these:

- A management cluster that delivers to many holds credentials for many.
- Production should `dependsOn` a staging Kustomization that has health checks.
- Prefer folders and overlays to branches.
- The Kustomizations live on the management cluster, not on the remote one.

<!-- astrona:playground:destroy -->
