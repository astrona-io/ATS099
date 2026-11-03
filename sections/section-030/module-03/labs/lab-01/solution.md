# Solution: Promote Staging To Production

Work the task yourself first. Running `astrona submit -c sections/section-030/module-03/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: staging waits for its objects, production is in Git with `dependsOn`, and production runs, is in the inventory, and both accounts stay scoped.

## Step 1: Clone the repository

Start the port-forward in a second terminal:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Then clone with the user `gitops` and the password `gitops-password`:

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

## Step 2: Make staging Ready mean healthy

Open `clusters/kind/podinfo-staging.yaml` and add two lines under `spec`:

```yaml
  wait: true
  timeout: 3m
```

`wait: true` makes the Kustomization check every object it applied. The `timeout` bounds how long it waits.

## Step 3: Add the production Kustomization

Save this as `clusters/kind/podinfo-production.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo-production
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./apps/podinfo-production
  prune: true
  wait: true
  timeout: 5m
  kubeConfig:
    secretRef:
      name: production-kubeconfig
  dependsOn:
    - name: podinfo-staging
```

## Step 4: Push and reconcile

```sh
git add clusters/kind
git commit -m "Wait for staging, then deliver production"
git push
flux reconcile kustomization flux-system --with-source
```

## Step 5: Prove it

```sh
flux get kustomizations
kubectl -n podinfo-production get deployment,service
kubectl -n flux-system get kustomization podinfo-production -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}'
kubectl auth can-i create deployments -n podinfo-staging --as=system:serviceaccount:production-access:flux-deployer
```

Both Kustomizations are `Ready`, podinfo runs with three replicas in `podinfo-production`, the inventory lists the Deployment and the Service, and the last command answers `no`.

## Step 6: See the gate work

Break staging on purpose and watch production wait. Change the image tag in `apps/podinfo-staging/deployment.yaml` to one that does not exist, push, and run `flux get kustomizations`. Staging is not `Ready`, and a change to production waits. Fix the tag afterwards.

## Step 7: Submit

```sh
astrona submit -c sections/section-030/module-03/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `dependsOn` without `wait` on staging | Staging is `Ready` at once, so production does not wait for healthy pods |
| `kubectl apply -k apps/podinfo-production` | podinfo runs, but it is not in the inventory and Flux does not manage it |
| Use `staging-kubeconfig` for production | The staging account cannot change `podinfo-production`, and the apply is refused |
| Commit the kubeconfig next to the Kustomization | The token is in Git history for everyone who can read the repository |
