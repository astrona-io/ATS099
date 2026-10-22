# Solution: Bring Flux Back After A Lost flux-system Namespace

Work the task yourself first. Running `astrona submit -c sections/section-040/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: `flux check` passes, `flux-system` syncs the right repository and path, the private source is back with `private-settings` adopted, and podinfo is resumed through Git with its Deployment adopted.

## Step 1: Take stock

```sh
kubectl get namespace flux-system
kubectl -n podinfo get deployment podinfo -o jsonpath='{.metadata.uid}{"\n"}'
kubectl -n podinfo get configmap private-settings -o jsonpath='{.metadata.uid}{"\n"}'
```

The namespace `flux-system` does not exist. Both workloads run; note their UIDs.

## Step 2: Bring Flux back

Start the port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Bootstrap with the same repository, branch and path:

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

Bootstrap recreates the namespace and the Secret `flux-system`, and `flux-system` applies everything under `clusters/kind`, including the `private-config` source and the suspended `podinfo` Kustomization.

## Step 3: Read what is still wrong

```sh
flux get sources git
flux get kustomizations
```

The `GitRepository` `private-config` is not `Ready`: its Secret `private-config-auth` does not exist, because Secrets are not in Git and the namespace that held it was deleted. The `podinfo` Kustomization shows `SUSPENDED` `True`, and `private-config`, which depends on `podinfo`, waits for it.

## Step 4: Restore the credential Git does not hold

```sh
flux create secret git private-config-auth \
  --url=http://gitea.localtest.me:3000/gitops/private-config.git \
  --username=gitops \
  --password=gitops-password
flux reconcile source git private-config
```

The source becomes `Ready`.

## Step 5: End the maintenance window in Git

Clone the platform repository and look at the podinfo file:

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
cat clusters/kind/podinfo.yaml
```

Delete the line `suspend: true` from `clusters/kind/podinfo.yaml`, then push and reconcile:

```sh
git commit -am "End the podinfo maintenance window"
git push
flux reconcile kustomization flux-system --with-source
flux reconcile kustomization podinfo
flux reconcile kustomization private-config
```

## Step 6: Prove it

```sh
flux check
flux get kustomizations
kubectl -n podinfo get deployment podinfo -o jsonpath='{.metadata.uid}{"\n"}'
kubectl -n podinfo get configmap private-settings -o jsonpath='{.metadata.uid}{"\n"}'
```

Everything is `Ready` and not suspended, and both UIDs match Step 1.

## Step 7: Submit

```sh
astrona submit -c sections/section-040/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `flux resume kustomization podinfo` only | The next `flux-system` reconcile applies `suspend: true` from Git again |
| Remove `secretRef` from the private source | The repository is private; the fetch fails without credentials |
| Delete podinfo so Flux "starts clean" | It comes back with a new UID, and the grader fails the adoption check |
| Commit the Secret `private-config-auth` to Git | Anyone who can read the repository now holds the credential |
