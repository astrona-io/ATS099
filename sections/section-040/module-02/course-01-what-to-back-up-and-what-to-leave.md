# What To Back Up And What To Leave

A backup has a cost. Every item in it is a thing that must be protected, tested and kept current. The aim is a short list of items that really cannot come from anywhere else.

## Three groups

Go through everything that exists in the cluster and put it in one of three groups.

| Group | Meaning | Examples |
| --- | --- | --- |
| In Git | The manifests describe it, and Flux applies it | Deployments, Services, Flux `Kustomization` and `HelmRelease` objects |
| Recreate from a source | Another system owns it and can produce it again | Certificates from an issuer, a database password held in a secret store, images in a registry |
| Back up | Only the cluster holds it | A Secret created by hand, a decryption key, a credential for another cluster |

Things in the second group still need a plan. If a secret store holds a password, the credential that lets the cluster read the store is itself in the third group.

## The usual items to back up

- **The credential Flux uses to read Git.** A deploy key or a token in a Secret in `flux-system`. `flux bootstrap` can create a new one, but then you must also register it with the Git host.
- **Credentials for other Git repositories.** A `GitRepository` with `spec.secretRef` points at a Secret. The Secret is not in the repository it protects.
- **Kubeconfig Secrets** for remote clusters.
- **The decryption key** for encrypted files in Git: the SOPS key, or the key of the Sealed Secrets controller.
- **Secrets created by hand** for an application. These are the ones people forget.
- **Persistent data.** Volumes and databases need their own backup tool. A Secret backup does not cover them, and neither does Flux.

## Find the Secrets that Git does not describe

Flux marks what it applies. An object it applied has labels such as `kustomize.toolkit.fluxcd.io/name`. A Secret without those labels was created some other way. List them:

```sh
kubectl get secrets -A -l '!kustomize.toolkit.fluxcd.io/name' \
  -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.type
```

The list also contains Secrets that Kubernetes or a controller creates, such as service account tokens and Helm release records. Read it with that in mind and mark the ones a person created.

## Keep a list of the list

Write down, for each item to back up: what it is, which namespace, who owns it, how often it changes, and where the backup goes. A backup of a Secret that changes weekly and is taken once a year is a trap. The list is also what a restore test is checked against.

## Common pitfalls

> [!WARNING]
> - **Assuming everything is in Git.** The credential Flux needs to read Git is not.
> - **Backing up everything.** A large unreviewed backup of every Secret spreads credentials far.
> - **No owner.** A Secret that nobody owns is never rotated and never restored.
> - **Forgetting the data.** Flux restores objects, not the content of volumes.
