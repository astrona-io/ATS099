# Solution: Deliver podinfo Through A Scoped kubeconfig

Work the task yourself first. Running `astrona submit -c sections/section-030/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the kubeconfig signs in as `flux-deployer`, the `podinfo-staging` Kustomization is in Git and `Ready`, podinfo was applied through it, and `flux-deployer` has no extra rights.

## Step 1: Read the account's token and the CA

```sh
TOKEN="$(kubectl -n staging-access get secret flux-deployer-token -o jsonpath='{.data.token}' | base64 --decode)"
CA_DATA="$(kubectl -n staging-access get secret flux-deployer-token -o jsonpath='{.data.ca\.crt}')"
echo "$CA_DATA"
echo "$TOKEN"
```

## Step 2: Write the kubeconfig

Save this as `staging.kubeconfig`, with `<CA_DATA>` and `<TOKEN>` replaced by the two values above:

```yaml
apiVersion: v1
kind: Config
clusters:
  - name: staging
    cluster:
      server: https://kubernetes.default.svc
      certificate-authority-data: <CA_DATA>
users:
  - name: flux-deployer
    user:
      token: <TOKEN>
contexts:
  - name: staging
    context:
      cluster: staging
      user: flux-deployer
      namespace: podinfo-staging
current-context: staging
```

## Step 3: Store it in a Secret

Flux reads the key `value` by default:

```sh
kubectl -n flux-system create secret generic staging-kubeconfig --from-file=value=staging.kubeconfig
```

## Step 4: Commit the Flux Kustomization

Start the port-forward in a second terminal:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

In your first terminal, clone with the user `gitops` and the password `gitops-password`:

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Save this as `clusters/kind/podinfo-staging.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo-staging
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./apps/podinfo-staging
  prune: true
  kubeConfig:
    secretRef:
      name: staging-kubeconfig
```

Push it and reconcile:

```sh
git add clusters/kind/podinfo-staging.yaml
git commit -m "Deliver podinfo to staging through a kubeconfig"
git push
flux reconcile kustomization flux-system --with-source
```

## Step 5: Prove it

```sh
flux get kustomization podinfo-staging
kubectl -n podinfo-staging get deployment,service
kubectl -n flux-system get kustomization podinfo-staging -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}'
kubectl auth can-i create clusterroles --as=system:serviceaccount:staging-access:flux-deployer
```

The `Kustomization` is `Ready`, podinfo runs, the inventory lists the Deployment and the Service, and the last command answers `no`.

## Step 6: Submit

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Use your own kubeconfig in the Secret | It signs in as you, not as `flux-deployer`; the grader checks who the token is |
| Bind `flux-deployer` to `cluster-admin` | It works, and the scope check fails |
| `kubectl apply -k apps/podinfo-staging` yourself | podinfo runs, but it is not in the inventory, so Flux neither manages nor prunes it |
| Commit the kubeconfig next to the `Kustomization` | The token is now in Git history for everyone who can read the repository |
