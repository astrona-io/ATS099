# Exposing A Receiver Safely

A Receiver is an HTTP endpoint, and a Git host on the internet must be able to reach it. This part shows where the endpoint is, how its path is built, and how to expose it without opening more than needed.

## The Service

When Flux is installed, notification-controller has a Service named `webhook-receiver` in `flux-system`. It listens on port `80` and forwards to the controller's webhook port `9292`. The Service has type `ClusterIP`, so it is reachable only inside the cluster until you expose it. This is different from the lab receiver named `webhook-receiver` in the namespace `monitoring`, which only logs requests and has no relation to Flux.

```sh
kubectl -n flux-system get svc webhook-receiver
```

## The path

Each Receiver gets its own path, written to its status after the Receiver is ready:

```sh
kubectl -n flux-system get receiver fleet -o jsonpath='{.status.webhookPath}'
```

The path begins with `/hook/` and ends with a SHA-256 hash. The hash is computed from the token, the name and the namespace of the Receiver. Two consequences follow. The path cannot be guessed without the token. And when you change the token, the path changes, so the sender must be updated with the new path.

The full URL for a sender is the external address of the Service plus the path. From inside the cluster, a test call looks like this:

```sh
kubectl -n gitea exec deploy/tester -- \
  curl -fsS -X POST "http://webhook-receiver.flux-system$(kubectl -n flux-system get receiver fleet -o jsonpath='{.status.webhookPath}')"
```

The tester pod is in another namespace, so the Service name needs the namespace.

## The token Secret

Create the token Secret before the Receiver, or the Receiver reports it as not ready:

```sh
TOKEN=$(head -c 12 /dev/urandom | shasum | cut -d ' ' -f1)
kubectl -n flux-system create secret generic receiver-token --from-literal=token="$TOKEN"
```

Keep the token. The Git host needs it as the webhook secret. A token that is committed to Git as plain text defeats the purpose, so either create the Secret from the command line or commit it encrypted with SOPS.

## Expose the Service

Three common ways to give the Service an external address:

- An Ingress that sends a host name to `webhook-receiver` on port `80`. Limit it to the path prefix `/hook/` so that nothing else of the controller is reachable.
- A Service of type `LoadBalancer`, set up by a patch to the Flux installation in Git.
- A tunnel, for a cluster with no public address, such as a reverse proxy that the Git host can reach.

Use HTTPS. The path is a secret, and plain HTTP shows it to anyone on the route. Flux itself does not terminate TLS here, so the Ingress or the load balancer must.

## Limit what a call can do

The controller accepts only POST requests on a known path. Add the usual controls on top: a network policy that allows only the ingress controller to reach port `9292`, a rate limit on the Ingress, and a different token for every Receiver. If a token leaks, you rotate one Receiver and not all of them.

## Rotate a token

1. Replace the token in the Secret:

```sh
kubectl -n flux-system create secret generic receiver-token \
  --from-literal=token="$NEW_TOKEN" --dry-run=client -o yaml | kubectl apply -f -
```

2. Read the new `status.webhookPath` from the Receiver.
3. Update the webhook URL and secret on the Git host.

Between the first and the last step the old path stops working, so calls fail until the host is updated. Do the change in a quiet period, and keep the source interval as the fallback.

## Common pitfalls

> [!WARNING]
> - **Exposing the whole Service on a public Ingress.** Route only `/hook/`.
> - **Posting to the wrong Service name.** Use `webhook-receiver.flux-system`, not the lab receiver in `monitoring`.
> - **Sending to the Receiver path over HTTP on the internet.** The path acts as a credential.
> - **Reusing one token for every Receiver.** One leak then affects all of them.
