# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Alerting and receivers

## Scenario

Flux runs from the repository `gitops/fleet`, path `clusters/kind`. The GitRepository `flux-system` fetches on an interval, so a push can wait for minutes. The CI system of the team can send an HTTP POST, and it should make Flux fetch right away.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Create a Secret named `receiver-token` in the namespace `flux-system` with the key `token` and any value you choose. Create it with `kubectl`. Do not commit it.
2. Add a Receiver named `fleet-push` in `flux-system` to `gitops/fleet`, in the folder `clusters/kind`. It has the type `generic`, uses the Secret `receiver-token`, and asks the GitRepository `flux-system` to reconcile.
3. Send a POST to the Receiver from inside the cluster, to the Service `webhook-receiver` in `flux-system`, and see that the annotation `reconcile.fluxcd.io/requestedAt` of the GitRepository changes.

## Constraints

- The token must not be in Git.
- Do not use `flux reconcile` to prove the Receiver. The call must come through the Receiver path.

## Done when

- The Receiver `fleet-push` is `Ready` and has a `status.webhookPath`.
- The Receiver is in `clusters/kind` in `gitops/fleet`, and no token is in the repository.
- A POST to the path of the Receiver makes the annotation `reconcile.fluxcd.io/requestedAt` of the GitRepository `flux-system` change.
