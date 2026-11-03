# Solution: Make Flux Fetch When A Webhook Arrives

Work the task yourself first. Running `astrona submit -c sections/section-020/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the Receiver has the right type, secret and resource and is ready, it is committed to Git without the token, and a POST to its path makes the GitRepository reconcile.

## Step 1: Create the token Secret

```sh
kubectl -n flux-system create secret generic receiver-token \
  --from-literal=token="$(head -c 12 /dev/urandom | shasum | cut -d ' ' -f1)"
```

The Secret lives only in the cluster. A token in Git would defeat the purpose.

## Step 2: Clone the repository

Start the port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Clone the repository with the user `gitops` and the password `gitops-password`:

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

## Step 3: Write the Receiver

Save this as `clusters/kind/receiver.yaml`:

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1
kind: Receiver
metadata:
  name: fleet-push
  namespace: flux-system
spec:
  type: generic
  secretRef:
    name: receiver-token
  resources:
    - apiVersion: source.toolkit.fluxcd.io/v1
      kind: GitRepository
      name: flux-system
```

## Step 4: Commit, push and reconcile

```sh
git add clusters/kind/receiver.yaml
git commit -m "Add a generic Receiver for the fleet repository"
git push
flux reconcile kustomization flux-system --with-source
kubectl -n flux-system wait receiver/fleet-push --for=condition=Ready --timeout=2m
```

Run `astrona submit -c sections/section-020/module-02/labs/lab-01` now.

## Step 5: Call the Receiver

Read the path and the current annotation:

```sh
kubectl -n flux-system get receiver fleet-push -o jsonpath='{.status.webhookPath}'
kubectl -n flux-system get gitrepository flux-system \
  -o jsonpath='{.metadata.annotations.reconcile\.fluxcd\.io/requestedAt}'
```

Send the POST from the tester pod:

```sh
kubectl -n gitea exec deploy/tester -- curl -fsS -X POST \
  "http://webhook-receiver.flux-system$(kubectl -n flux-system get receiver fleet-push -o jsonpath='{.status.webhookPath}')"
```

Read the annotation again. The value is a newer time.

## If something is wrong

- **The Receiver is not ready.** Read `kubectl -n flux-system describe receiver fleet-push`. A missing Secret or a Secret without the key `token` is the usual cause.
- **The POST returns an error.** Check the Service name and the namespace. The lab receiver in `monitoring` is not the Flux receiver.
- **The annotation does not change.** Read `kubectl -n flux-system logs deploy/notification-controller --tail=20`.
