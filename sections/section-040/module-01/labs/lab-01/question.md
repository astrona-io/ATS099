# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Disaster recovery

## Scenario

During an upgrade attempt, someone ran `flux uninstall --keep-namespace` on this cluster. The Flux controllers, CRDs and objects are gone; the `flux-system` namespace is still there. podinfo still runs in the namespace `podinfo`, but nothing manages it: a change in Git no longer reaches it.

Flux was bootstrapped from `http://gitea.localtest.me:3000/gitops/fleet.git`, branch `main`, path `clusters/kind`, with token authentication (user `gitops`, password `gitops-password`, lab-only). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you run anything that talks to Git from your machine.

## Your task

1. Bring Flux back on this cluster from the same repository, branch and path.
2. Make sure Flux manages the running podinfo Deployment again.

## Constraints

- **Do not delete, scale to zero or recreate podinfo.** The running Deployment must be adopted, not replaced. The grader compares its UID with the UID it had before Flux was removed.
- Do not change the repository's contents.
- Do not delete the ConfigMap `dr-baseline` in the namespace `gitea`; the grader reads the old UID from it.

## Done when

- `flux check` passes.
- The `flux-system` `GitRepository` points at `http://gitea.localtest.me:3000/gitops/fleet.git`, the `flux-system` Kustomization syncs `./clusters/kind`, and both `flux-system` and `podinfo` are `Ready`.
- The podinfo Deployment has the same UID as before, and it is in the inventory of the `podinfo` Kustomization.
