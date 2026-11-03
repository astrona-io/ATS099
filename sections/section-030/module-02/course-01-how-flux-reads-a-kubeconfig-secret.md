# How Flux Reads A Kubeconfig Secret

Flux does not run `kubectl`. kustomize-controller reads the Secret itself, builds a client from it, and uses that client for the apply, the health checks and the pruning. Knowing the rules for reading it prevents most of the failures that look like a bad credential.

## Where the Secret is

`spec.kubeConfig.secretRef.name` names a Secret in the namespace of the Kustomization. There is no field for another namespace. This is by design, as one tenant must not be able to name another tenant's credential.

## Which key is read

The controller reads the key `value`. If there is no `value`, it reads `value.yaml`. The field `spec.kubeConfig.secretRef.key` selects another key. A Secret made with `--from-file=staging.kubeconfig` has the key `staging.kubeconfig`, and the controller does not find it unless `key` names it. Cluster API writes its Secrets with the key `value`, so they work without `key`.

```yaml
spec:
  kubeConfig:
    secretRef:
      name: staging-kubeconfig
      key: staging.kubeconfig
```

## HelmRelease too

A HelmRelease has the same field. Its helm-controller applies the chart to the remote cluster through the kubeconfig. The release record is stored on the remote cluster, in the namespace `spec.storageNamespace`, and the HelmRelease object itself stays on the management cluster. The same Secret rules apply.

## What a kubeconfig may contain

A kubeconfig can hold a token, a client certificate, and also commands. A user entry can run a program to get a token (`exec`) or use an `auth-provider`. Letting a Secret run a program in the controller pod would let anyone who can create a Secret and a Kustomization run code with the controller's rights. For this reason the controllers refuse such kubeconfigs by default.

Two flags change this, and both are set on kustomize-controller and helm-controller:

- `--insecure-kubeconfig-exec` allows kubeconfigs with `exec` or `auth-provider`.
- `--insecure-kubeconfig-tls` allows kubeconfigs that skip TLS verification or point at a certificate by file path.

Do not set them on a shared platform. For cloud clusters, prefer a token from the cloud's workload identity, or a ServiceAccount token that you rotate yourself. Flux also has a `provider` field and a `configMapRef` under `spec.kubeConfig` for cloud provider authentication; read the current Flux documentation for the supported providers, because they are still changing.

## What the controller does with the file

The controller reads the Secret on each reconcile. A change to the Secret takes effect at the next reconcile, with no restart. This is what makes rotation possible without downtime: update the Secret, and the next apply uses the new token.

It also means a typo in the Secret breaks the next reconcile. Check a new kubeconfig by hand before you replace the working one.

## Where to keep the source of the Secret

The Secret is not in plain Git. There are three common places for the source:

- A secrets manager, with an operator that creates the Secret in the cluster.
- A SOPS-encrypted file in Git, decrypted by kustomize-controller of the management cluster. The decryption key stays on the management cluster.
- Cluster API, which creates and renews its own Secrets.

Keep the number of people who can read the Secret small. Anyone who can read it has the remote account's rights.

## Common pitfalls

> [!WARNING]
> - **Creating the Secret with `--from-file=<name>.kubeconfig`.** The key is then not `value`. Use `--from-file=value=<file>` or set `key`.
> - **Putting the Secret in another namespace than the Kustomization.** The controller looks only in its own.
> - **Enabling `--insecure-kubeconfig-exec` to make one cluster work.** The flag applies to every Kustomization.
> - **Replacing the Secret with an untested file.** The next reconcile fails and the delivery stops.
