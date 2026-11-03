# Commit Status From Flux

A Receiver brings a change in. A commit status sends the result back. When Flux has applied a commit, or failed to, the Git host can show a green check or a red cross on that commit, next to the author's name. A developer then sees the result where the work happened, without access to the cluster.

## How it works

The Git host types of `Provider` do not send a chat message. They call the host's API and set the status of one commit. The commit is the revision in the event. An `Alert` with a Kustomization as event source, and a Provider of type `github`, `gitlab`, `gitea`, `bitbucket` or `azuredevops`, is all that is needed.

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Provider
metadata:
  name: fleet-status
  namespace: flux-system
spec:
  type: gitea
  address: http://gitea-http.gitea:3000/gitops/fleet
  secretRef:
    name: gitea-token
---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: fleet-status
  namespace: flux-system
spec:
  providerRef:
    name: fleet-status
  eventSources:
    - kind: Kustomization
      name: podinfo
```

- `spec.address` is the address of the repository, not of the host.
- The Secret `gitea-token` holds a token with the key `token`. The token needs permission to write commit statuses on that repository.
- The Alert uses the default severity `info`, because a success must reach the host as well as a failure. This is the one case where forwarding `info` is the goal.

## What the status shows

The status has a state, a short description and the name of the Kustomization. The host shows success after a Kustomization applied the commit, and failure when the apply or the health check failed. A new commit gets a new status. A status refers to a commit and not to a branch, so an old commit keeps its last status.

The events must carry the revision of the commit. Events from Kustomizations do. An Alert whose event source is a source object, such as a GitRepository, has less to say, because a fetched commit says nothing about whether it was applied.

## Where the token comes from

Use a token that belongs to a service account and not to a person, with the narrowest scope that allows commit statuses. On GitHub that is a fine-grained token with the permission for commit statuses, or a GitHub App set in the Secret instead. Keep the Secret out of plain Git, and encrypt it with SOPS if it must be committed.

## Branch protection

Commit statuses become useful as a merge gate. If a repository requires the status of Flux before a merge, a change that fails in the cluster cannot reach the main branch. Note the limit: Flux sets the status after the commit reached the branch Flux follows, so it protects later branches, such as a staging branch that is merged into production, and not the first push.

## Debugging a missing status

- Read the Provider with `kubectl -n flux-system describe provider fleet-status`. A problem with the token or the address appears there.
- Read the log of notification-controller. A `401` or `403` points to the token. A `404` points to the address.
- Check that the Alert's event source is a Kustomization with a revision, and that the Alert and the Provider are in the same namespace.

## Common pitfalls

> [!WARNING]
> - **Putting the host address in `spec.address`.** It must be the repository address.
> - **Setting `eventSeverity: error`.** Only failures reach the host, and commits never turn green.
> - **A personal access token.** The status disappears when that person leaves. Use a service account.
> - **Expecting a status on the commit that was never applied.** The status appears only after Flux reconciled the Kustomization with that revision.
