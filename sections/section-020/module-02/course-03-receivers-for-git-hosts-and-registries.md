# Receivers For Git Hosts And Registries

The type of a Receiver decides how the controller checks that a call is genuine and what it reads from the request. Pick the type that matches the sender, because the sender's own signature is a stronger check than a path alone.

## generic

The type `generic` accepts any POST on the right path. The only secret is the path itself. Use it for your own scripts and CI jobs, and for senders that cannot sign a request. A call needs no body.

## generic-hmac

The type `generic-hmac` requires a signature header computed with the token as the key. The sender computes an HMAC-SHA256 over the request body and sends it in the header `X-Signature` in the form `sha256=<hex digest>`. The controller computes the same value and rejects the call when it differs. Use it when the sender can run a small script, because it protects against replayed paths and altered bodies.

## github, gitlab, bitbucket and gitea style senders

For the Git host types the controller checks the host's own proof, and reads which event arrived.

- `github` checks the `X-Hub-Signature-256` header, which GitHub computes with the webhook secret set in the repository. The token in the Secret must equal that webhook secret.
- `gitlab` compares the `X-Gitlab-Token` header with the token.
- `bitbucket` checks the `X-Hub-Signature` header the same way as GitHub does, with the shared secret.
- `gitea` and similar hosts that send a GitHub-compatible request can use the `github` type. Check the host's documentation for the header it sends.

For these types, `spec.events` lists the event names that count, such as `ping` and `push` for GitHub. A call with another event is accepted and ignored. Without `events`, the controller reacts to every event of that host, including events you do not care about, such as issue comments.

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1
kind: Receiver
metadata:
  name: github-fleet
  namespace: flux-system
spec:
  type: github
  events:
    - ping
    - push
  secretRef:
    name: receiver-token
  resources:
    - apiVersion: source.toolkit.fluxcd.io/v1
      kind: GitRepository
      name: flux-system
```

On GitHub, create a webhook with the payload URL, the content type `application/json` and the same secret. GitHub sends a `ping` event when you save it, which is why `ping` is in the list.

## Registry types

Registries tell Flux that a new image or chart exists. The types `dockerhub`, `harbor`, `quay`, `gcr`, `acr`, `nexus` and `cdevents` serve this. The resources are usually an `ImageRepository`, an `OCIRepository`, or a `HelmRepository` of type OCI. As with the Git hosts, the registry holds the token in its webhook settings. Some registry types, such as `gcr`, `acr` and `nexus`, check a field in the request instead of a signature, so read the Receiver documentation for the exact fields.

## Choose a type

| Sender | Type |
| --- | --- |
| Your CI job or script | `generic` or `generic-hmac` |
| GitHub, GitLab, Bitbucket | the host's own type |
| A registry | the registry's own type |

Prefer a type that checks a signature. Use `generic` only when nothing better exists.

## Test without the real sender

You can test a Receiver by hand. For `generic`, a POST to the path is enough. For a Git host type, send the headers that the host would send. If the controller rejects a call, its log says why:

```sh
kubectl -n flux-system logs deploy/notification-controller --tail=20
```

Look for lines that name the Receiver and the reason, such as a bad signature or an event that is not in the list.

## Common pitfalls

> [!WARNING]
> - **Leaving `events` empty for a Git host type.** Every event, including comments, triggers a reconcile.
> - **A token that differs from the webhook secret on the host.** The signature check fails and the host shows a failed delivery.
> - **Using `generic` for a public sender.** A leaked path then works for everyone.
> - **Forgetting the `ping` event.** The host shows its first delivery as failed because the controller ignored it.
