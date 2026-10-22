# Solution: Repair A Broken Remote Cluster Connection

Work the task yourself first. Running `astrona submit -c sections/section-030/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the kubeconfig is under the right key and signs in as `flux-deployer`, the `Kustomization` is in Git and `Ready`, podinfo was applied through it, and `flux-deployer` has no extra rights.

## Step 1: Read the status

```sh
flux get kustomization podinfo-staging
flux events --for Kustomization/podinfo-staging -n flux-system
kubectl -n flux-system get secret staging-kubeconfig -o jsonpath='{.data}' | tr ',' '\n'
```

The message says the Secret `staging-kubeconfig` has no key `value` or `value.yaml`. The last command shows why: the kubeconfig is stored under the key `config`. That is the first fault, and it hides the others.

## Step 2: Read the kubeconfig

```sh
kubectl -n flux-system get secret staging-kubeconfig -o jsonpath='{.data.config}' | base64 --decode > staging.kubeconfig
grep server staging.kubeconfig
```

The server is `https://kubernetes.default.svc:8443`. The Kubernetes API Service listens on port `443`, so nothing answers there. That is the second fault. Fix the address in the file:

```sh
sed -i.bak 's|https://kubernetes.default.svc:8443|https://kubernetes.default.svc|' staging.kubeconfig
grep server staging.kubeconfig
```

## Step 3: Store it under the right key

Replace the Secret, with the fixed file under `value`:

```sh
kubectl -n flux-system create secret generic staging-kubeconfig \
  --from-file=value=staging.kubeconfig --dry-run=client -o yaml | kubectl apply -f -
flux reconcile kustomization podinfo-staging
flux get kustomization podinfo-staging
```

Setting `spec.kubeConfig.secretRef.key: config` in Git would also work; then you would keep the key and fix only the address. Either way, the next message is a "forbidden" for `services` in `podinfo-staging`, for the user `system:serviceaccount:staging-access:flux-deployer`. The Deployment applies; the Service does not. That is the third fault.

## Step 4: Grant exactly what is missing

```sh
kubectl -n podinfo-staging get role deployer -o yaml
kubectl auth can-i create services -n podinfo-staging --as=system:serviceaccount:staging-access:flux-deployer
```

The Role only covers `deployments`. Add one rule for `services`, in the same namespace:

```sh
kubectl -n podinfo-staging patch role deployer --type json \
  -p '[{"op":"add","path":"/rules/-","value":{"apiGroups":[""],"resources":["services"],"verbs":["get","list","watch","create","update","patch","delete"]}}]'
```

On a real remote cluster this Role lives with the staging team, so the change goes through them, often through their own repository.

## Step 5: Prove it

```sh
flux reconcile kustomization podinfo-staging
flux get kustomization podinfo-staging
kubectl -n podinfo-staging get deployment,service
kubectl -n flux-system get kustomization podinfo-staging -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}'
kubectl auth can-i create clusterroles --as=system:serviceaccount:staging-access:flux-deployer
```

The `Kustomization` is `Ready`, the inventory lists the Deployment and the Service, and the last command answers `no`.

## Step 6: Submit

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Bind `flux-deployer` to `cluster-admin` | Everything applies, and the scope check fails |
| Remove `spec.kubeConfig` | Flux applies with its own rights on its own cluster; the grader requires the kubeconfig |
| Put your own kubeconfig in the Secret | The token signs in as you, not as `flux-deployer` |
| Grant `"*"` resources in the Role | Flux works, but the account can change every kind in the namespace, including Secrets |
