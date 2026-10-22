# Applying To Another Cluster With kubeConfig

One Flux installation can deliver to many clusters. The management cluster runs Flux, and each target cluster only needs an account Flux can use. This part builds the credentials for that account into a kubeconfig, hands the kubeconfig to a Flux `Kustomization`, and proves that podinfo reached the "remote cluster" through it, with no more rights than it needs.

## What Flux needs from the other cluster

kustomize-controller talks to another cluster the same way `kubectl` does: with a **kubeconfig**. A kubeconfig is a YAML file with four parts. A **cluster** entry holds the API server address and the certificate authority (CA) that signed its certificate. A **user** entry holds the credentials, here a ServiceAccount token. A **context** joins one cluster and one user, and `current-context` picks the context to use.

On the remote side, the account should hold only what Flux must change there. In the playground that is the ServiceAccount `flux-deployer` in `staging-access`, with the Role `deployer` in `podinfo-staging`: Deployments and Services, in that namespace, nothing else. Check the rights first, as the account:

<!-- astrona:playground:renew -->

```sh
kubectl auth can-i create deployments -n podinfo-staging --as=system:serviceaccount:staging-access:flux-deployer
kubectl auth can-i create deployments -n podinfo --as=system:serviceaccount:staging-access:flux-deployer
```

The first answer is `yes` and the second is `no`. Whatever Flux does with this kubeconfig, it can only change `podinfo-staging`.

## Build the kubeconfig

The Secret `flux-deployer-token` holds a long-lived token and the cluster's CA certificate; Kubernetes filled both in when the Secret was created. Read the two values:

```sh
TOKEN="$(kubectl -n staging-access get secret flux-deployer-token -o jsonpath='{.data.token}' | base64 --decode)"
CA_DATA="$(kubectl -n staging-access get secret flux-deployer-token -o jsonpath='{.data.ca\.crt}')"
echo "$CA_DATA" | head -c 40; echo
echo "$TOKEN" | head -c 40; echo
```

`CA_DATA` stays Base64-encoded, because a kubeconfig takes the CA in that form. `TOKEN` is decoded, because a kubeconfig takes the token as plain text. Save this as `staging.kubeconfig`, and replace `<CA_DATA>` and `<TOKEN>` with the full values of `echo "$CA_DATA"` and `echo "$TOKEN"`:

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

The address `https://kubernetes.default.svc` only works inside the cluster, which is where kustomize-controller runs; on your machine it does not resolve. On a real remote cluster this is its public API address.

A kubeconfig holds a credential, so it never goes in Git. Store it in a Secret in `flux-system`, under the key `value`, which is where Flux looks by default:

```sh
kubectl -n flux-system create secret generic staging-kubeconfig --from-file=value=staging.kubeconfig
```

## Deliver through it

Now the Flux object, which does go in Git. Pull your clone of `fleet` (clone it first if you have none), then save this as `fleet/clusters/kind/podinfo-staging.yaml`:

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

The source and the build stay on the management cluster: source-controller fetches, kustomize-controller builds. Only the apply goes through the kubeconfig. `./apps/podinfo-staging` has no Namespace object on purpose, because `flux-deployer` may not create namespaces; on a real remote cluster the namespace is created when the cluster is set up. Commit, push and reconcile:

```sh
cd fleet
git add clusters/kind/podinfo-staging.yaml
git commit -m "Deliver podinfo to staging through a kubeconfig"
git push
flux reconcile kustomization flux-system --with-source
```

Then check the result:

```sh
flux get kustomization podinfo-staging
kubectl -n podinfo-staging get deployment,service
kubectl -n flux-system get kustomization podinfo-staging -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}'
```

The `Kustomization` is `Ready`. podinfo runs in `podinfo-staging`. The **inventory**, the list of objects a `Kustomization` applied and will prune, holds `podinfo-staging_podinfo_apps_Deployment` and `podinfo-staging_podinfo__Service`. If the kubeconfig were wrong, the status would name the problem: a missing Secret key, an address that does not answer, or a "forbidden" from the remote API server.

You can now deliver to another cluster with a kubeconfig whose account has exactly the rights it needs. The question still open is scale: building a kubeconfig by hand works for one cluster, not for fifty that come and go.

## Common pitfalls

> [!WARNING]
> - **Committing the kubeconfig.** It holds a token. Store it in a Secret, never in Git.
> - **Using the wrong key.** Flux reads `value` or `value.yaml` unless `spec.kubeConfig.secretRef.key` names another one.
> - **Giving the remote account `cluster-admin` to make it work.** Find which object was refused and grant that kind, in that namespace.
> - **Putting a Namespace object in a folder the remote account applies.** An account limited to one namespace cannot create namespaces; the apply fails.

## Your mission: Deliver podinfo Through A Scoped kubeconfig

You can now build a kubeconfig for a narrowly scoped account and deliver through it. The graded lab gives you a cluster with `flux-deployer` and its token, and asks you to build the kubeconfig, store it in `staging-kubeconfig`, and commit a Flux `Kustomization` that delivers `./apps/podinfo-staging` through it, without giving the account any more rights.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-099-playground-030-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS099.git -c sections/section-030/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-099-lab-030-01
astrona start ats-099-playground-030-01
```
