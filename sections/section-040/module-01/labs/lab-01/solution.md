# Solution: Reinstall Flux Without Touching The Workloads

Work the task yourself first. Running `astrona submit -c sections/section-040/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: `flux check` passes, Flux syncs the same repository and path with `flux-system` and `podinfo` `Ready`, and the podinfo Deployment kept its UID and is in podinfo's inventory.

## Step 1: Confirm the starting state

```sh
kubectl get crds | grep -c toolkit.fluxcd.io
kubectl -n flux-system get all
kubectl -n podinfo get deployment podinfo -o jsonpath='{.metadata.uid}{"\n"}'
```

No Flux CRD is left and `flux-system` has no controllers, but podinfo runs. Note its UID.

## Step 2: Bootstrap again

Start the port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

In your first terminal, run bootstrap with the same repository, branch and path:

```sh
flux bootstrap git \
  --url=http://gitea.localtest.me:3000/gitops/fleet.git \
  --branch=main \
  --path=clusters/kind \
  --username=gitops \
  --password=gitops-password \
  --token-auth=true \
  --allow-insecure-http=true
```

Bootstrap installs the controllers from `clusters/kind/flux-system/gotk-components.yaml` in Git, writes the Secret `flux-system`, applies the sync objects and waits for `flux-system`. If `gitea.localtest.me` does not resolve on your machine, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

## Step 3: Prove the adoption

```sh
flux check
flux get kustomizations
kubectl -n podinfo get deployment podinfo -o jsonpath='{.metadata.uid}{"\n"}'
kubectl -n flux-system get kustomization podinfo -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}'
```

`flux check` passes, both Kustomizations are `Ready`, the UID is the one from Step 1, and the inventory lists `podinfo_podinfo_apps_Deployment`. If `podinfo` is not `Ready` yet, run `flux reconcile kustomization podinfo --with-source`.

## Step 4: Submit

```sh
astrona submit -c sections/section-040/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `kubectl delete deployment podinfo` so Flux "starts clean" | Flux creates it again with a new UID; the grader fails the adoption check |
| `flux install` instead of bootstrap | The controllers run, but nothing syncs `gitops/fleet` and podinfo is not managed |
| Bootstrap with `--path=clusters/kind-new` | Flux syncs a different folder; the path check fails and podinfo stays unmanaged |
