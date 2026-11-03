# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Operating Flux

## Scenario

The platform team reports that Flux is slow to apply changes: Kustomizations wait in a queue behind each other, and the log of `kustomize-controller` shows the controller was close to its memory limit. You decide to let the controller reconcile eight objects at a time and to give it more memory. Flux manages itself from `gitops/fleet`, in `clusters/kind/flux-system/`, so the change goes through Git.

## Your task

1. Add the argument `--concurrent=8` to the container of the Deployment `kustomize-controller`.
2. Set the memory limit of that container to `2Gi`.
3. Make both changes with patches in `clusters/kind/flux-system/kustomization.yaml` in the repository, and let Flux apply them.

## Constraints

- Do not edit `gotk-components.yaml` or `gotk-sync.yaml`.
- Do not change any other controller. Only `kustomize-controller` may change.
- Do not use `kubectl edit` or `kubectl patch` on the Deployment. A change made that way does not last.
- Keep `gotk-components.yaml` and `gotk-sync.yaml` in the `resources` list.

## Done when

- `kustomize-controller` runs with `--concurrent=8`, exactly once, after Flux has applied what is in Git.
- The memory limit of the `kustomize-controller` container is `2Gi`.
- The file in Git has a `patches` section with both changes, the Kustomization `flux-system` is `Ready`, and the other controllers are unchanged.
