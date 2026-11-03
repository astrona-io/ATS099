# Token Lifetime And Rotation

A token in a kubeconfig is a password that does not change unless you change it. How long it lives, and how you replace it, decide how much damage a leak can do.

## Long-lived tokens

A Secret of type `kubernetes.io/service-account-token`, with the annotation `kubernetes.io/service-account.name`, makes Kubernetes fill in a token for that ServiceAccount. The token has no expiry. It works until the Secret or the ServiceAccount is deleted. It is the simplest thing that works, and the playground uses it.

The risk is plain: a copy of the token works for years. Nobody notices a copy that was taken a year ago.

## Short-lived tokens

The TokenRequest API issues a token that expires. The command line tool uses it with `kubectl create token`:

```sh
kubectl -n staging-access create token flux-deployer --duration=24h
```

The token stops working after the duration. A Flux delivery that uses it needs a new token before then, so something must renew it: a job on the management side, or an operator that talks to the remote cluster. The renewal updates the Secret `staging-kubeconfig`, and the next reconcile uses it. A server can limit the maximum duration, so ask for less than the limit.

If the renewal job fails, the delivery fails when the token expires. Alert on a Kustomization that is not ready, so you find out before users do.

## A rotation that causes no gap

To replace a long-lived token, or a short-lived one before it expires, do the steps in this order:

1. Create the new token. For a long-lived one, create a second token Secret for the same ServiceAccount.
2. Build a new kubeconfig with the new token and check it by hand.
3. Replace the key in the kubeconfig Secret on the management cluster.
4. Reconcile the Kustomization and check that it is `Ready`.
5. Delete the old token. For a long-lived one, delete the old token Secret.

The old token must be gone at the end. If it stays, the rotation only adds a second valid credential. Deleting the token Secret invalidates its token, because the API server checks that the Secret still exists.

```sh
kubectl -n staging-access delete secret flux-deployer-token
```

## Show that the old token no longer works

Keep a copy of the old token in a shell variable before you delete it, and do not print it. Afterwards, ask the API server who the old token belongs to. The TokenReview API answers that question, and an invalid token comes back as not authenticated:

```sh
kubectl create -o jsonpath='{.status.authenticated}' -f - <<EOF
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: $OLD_TOKEN
EOF
```

The answer is empty or `false` for an invalid token, and `true` for a valid one. If you only need to compare tokens later, store a hash of the token and not the token.

## Cluster API and client certificates

The kubeconfig that Cluster API writes uses a client certificate and not a token. The certificate expires, and Cluster API renews it. The Secret changes when that happens, and Flux picks up the new content at the next reconcile. You do not rotate it by hand, but you should know that it is an administrator credential.

## Common pitfalls

> [!WARNING]
> - **Deleting the old token before the new kubeconfig works.** The delivery stops.
> - **Keeping the old token Secret "just in case".** The rotation then protects nothing.
> - **Short-lived tokens without a renewal job.** The delivery stops when the token expires.
> - **Printing tokens into a shared terminal log.** Store a hash if you need to compare.
