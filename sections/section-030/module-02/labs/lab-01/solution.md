# Solution: Rotate The Token In A kubeconfig Secret

Work the task yourself first. Running `astrona submit -c sections/section-030/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the kubeconfig holds a new valid token for `flux-deployer`, the old token Secret is gone, and the delivery still works with the account unchanged.

## Step 1: Keep a copy of the old token

You need it only to prove the rotation at the end. Do not print it.

```sh
OLD_TOKEN="$(kubectl -n staging-access get secret flux-deployer-token -o jsonpath='{.data.token}' | base64 --decode)"
```

## Step 2: Create the second token

A Secret of type `kubernetes.io/service-account-token` with the annotation for the ServiceAccount gets a token from Kubernetes:

```sh
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: flux-deployer-token-v2
  namespace: staging-access
  annotations:
    kubernetes.io/service-account.name: flux-deployer
type: kubernetes.io/service-account-token
YAML
kubectl -n staging-access get secret flux-deployer-token-v2 -o jsonpath='{.data.token}' | wc -c
```

The last command must print a number larger than 0 before you go on.

## Step 3: Build and store the new kubeconfig

```sh
TOKEN="$(kubectl -n staging-access get secret flux-deployer-token-v2 -o jsonpath='{.data.token}' | base64 --decode)"
CA_DATA="$(kubectl -n staging-access get secret flux-deployer-token-v2 -o jsonpath='{.data.ca\.crt}')"
cat > staging.kubeconfig <<YAML
apiVersion: v1
kind: Config
clusters:
  - name: staging
    cluster:
      server: https://kubernetes.default.svc
      certificate-authority-data: ${CA_DATA}
users:
  - name: flux-deployer
    user:
      token: ${TOKEN}
contexts:
  - name: staging
    context:
      cluster: staging
      user: flux-deployer
      namespace: podinfo-staging
current-context: staging
YAML
kubectl -n flux-system create secret generic staging-kubeconfig \
  --from-file=value=staging.kubeconfig --dry-run=client -o yaml | kubectl apply -f -
rm staging.kubeconfig
```

## Step 4: Check the delivery with the new token

```sh
flux reconcile kustomization podinfo-staging -n flux-system
flux get kustomization podinfo-staging
```

The Kustomization must be `Ready` before you delete anything.

## Step 5: Delete the old token

```sh
kubectl -n staging-access delete secret flux-deployer-token
```

## Step 6: Prove the old token is dead

```sh
kubectl create -o jsonpath='{.status.authenticated}' -f - <<EOF
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: ${OLD_TOKEN}
EOF
```

The answer is empty or `false`. Then reconcile again and confirm that the delivery still works:

```sh
flux reconcile kustomization podinfo-staging -n flux-system
```

## Step 7: Submit

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Delete `flux-deployer-token` first | The delivery fails until the new kubeconfig is in place |
| Keep the old Secret "for a while" | The old token still works, so the rotation protects nothing |
| Put the new token in a new Secret name | The Kustomization points at `staging-kubeconfig` and keeps using the old token |
| Bind `flux-deployer` to `cluster-admin` to be safe | The scope check fails |
