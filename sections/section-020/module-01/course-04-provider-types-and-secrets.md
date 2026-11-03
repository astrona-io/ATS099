# Provider Types And Their Secrets

A `generic` provider posts JSON to any URL, which is enough to learn the mechanism. In production, teams send events to the tools they already use: a chat room, an incident system, or the Git host. Each tool needs its own message format and its own credentials. This part lists the provider types you meet most often, shows where credentials go, and explains the two ways a provider can fail silently.

## One field selects the format

The `spec.type` field of a `Provider` selects the format and the protocol. The notification controller documents many types. Chat tools include `slack`, `discord`, `msteams`, `googlechat`, `matrix`, `telegram` and `rocket`. Incident and monitoring tools include `alertmanager`, `opsgenie`, `pagerduty`, `grafana`, `sentry` and `datadog`. Git hosts include `github`, `gitlab`, `gitea`, `bitbucket` and `azuredevops`, which set commit status instead of sending a message. The type `generic` posts JSON, and `generic-hmac` adds a signature header.

Read the list for your version in the Flux notification documentation, because types are added over time. The type is the first thing to check when a provider seems to send nothing: a Slack address with the type `generic` receives a payload that Slack does not understand.

## Where the address and token go

An address such as a Slack webhook URL is a secret, because anyone who holds it can post to your channel. Do not write it into the `Provider` in Git. Put it in a Kubernetes Secret and point `spec.secretRef` at it. The Secret keeps the address in the key `address`:

```sh
kubectl -n flux-system create secret generic slack-url \
  --from-literal=address=https://hooks.slack.com/services/EXAMPLE
```

The provider then names the Secret and leaves the address out:

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Provider
metadata:
  name: slack
  namespace: flux-system
spec:
  type: slack
  channel: platform-alerts
  secretRef:
    name: slack-url
```

Tokens for Git hosts go in the key `token`. For a secret that must live in Git, encrypt it with SOPS and let kustomize-controller decrypt it. The Secret must be in the same namespace as the `Provider`.

## Optional fields

A provider has a few fields that change the message without changing the format. `spec.channel` selects the channel or room where the type supports it. `spec.username` sets the sender name. `spec.proxy` sends the request through a proxy. `spec.certSecretRef` names a Secret with a CA certificate for a server that uses a private certificate authority. `spec.suspend: true` stops the provider from sending without deleting it.

## Check whether a provider works

A provider has a `Ready` condition. It tells you the configuration was accepted, such as a valid address or a Secret that exists. It does not tell you that messages arrive. Check both:

```sh
kubectl -n flux-system get providers
kubectl -n flux-system logs deploy/notification-controller --tail=20
```

The first command shows `READY` and a status message. The second shows the controller's log, where a failed delivery appears with the HTTP status the receiver returned. A `401` or `403` usually means a wrong token, and a `404` a wrong address.

## Two ways a provider fails silently

An Alert that names a `Provider` that does not exist is accepted by Kubernetes, but the Alert cannot deliver. Its status reports the missing provider. The second way is a namespace mismatch. An `Alert` finds its `Provider` in its own namespace, so a provider in another namespace is not found. Keep both in the same namespace, usually `flux-system`, unless you need a provider for one tenant.

## Common pitfalls

> [!WARNING]
> - **Putting a webhook URL in the Provider in Git.** Use `secretRef` with the key `address`.
> - **Using `generic` for a chat tool.** The tool rejects the payload. Use the matching type.
> - **Reading `Ready` as "messages arrive".** It checks only the configuration. Read the controller log.
> - **Keeping the Secret in another namespace.** It must be in the namespace of the Provider.
