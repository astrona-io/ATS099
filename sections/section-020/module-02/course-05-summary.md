# Summary

Flux polls by default, so a push can wait for the next interval. A Receiver lets the sender call Flux instead, and a commit status lets Flux call the Git host with the result.

## What you learned

A `Receiver` in `notification.toolkit.fluxcd.io/v1` has a `spec.type`, a `spec.secretRef` to a Secret with the key `token`, and `spec.resources`, a list of Flux objects. A call to its path makes notification-controller set the annotation `reconcile.fluxcd.io/requestedAt` on each listed object, and the source reconciles. The call only asks for a check. It cannot change what is applied. Keep the `interval` on sources as a fallback for lost webhooks.

The path is in `status.webhookPath` and ends in a hash of the token, the name and the namespace of the Receiver. The Service `webhook-receiver` in `flux-system` listens on port `80` and is reachable only inside the cluster until you expose it. Expose the path prefix `/hook/` over HTTPS, use one token for each Receiver, and read the controller log to see why a call was rejected.

The type decides the check: `generic` relies on the secret path, `generic-hmac` verifies an HMAC signature in `X-Signature`, and the host types such as `github` and `gitlab` verify the host's own proof and use `spec.events` to ignore other events. Registry types exist for image and chart updates.

A Provider of a Git host type sets the commit status of the revision in a Kustomization's event. Use the repository address, a token for a service account, and an Alert that keeps the default severity `info` so that success turns the commit green.

The key facts to remember are these:

- A Receiver asks for a reconcile and never carries a revision.
- Prove a Receiver by watching `reconcile.fluxcd.io/requestedAt` change after a call.
- Prefer a type that checks a signature.
- A commit status needs `info` events, so do not filter to `error`.

<!-- astrona:playground:destroy -->
