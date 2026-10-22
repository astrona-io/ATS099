# What Git Holds And What It Does Not

A recovery plan starts with an inventory, not with commands. If you only find out during an outage that the Git credential lived in one Secret on the lost cluster, the outage gets longer. This part takes stock of the playground: what Git can rebuild on its own, what Flux needs from outside Git, and how to export what the cluster holds today.

## What Git rebuilds

Everything Flux applies comes from Git: the controllers themselves (`gotk-components.yaml`), the sync objects (`gotk-sync.yaml`), every Flux `Kustomization` and `GitRepository` under `clusters/kind`, and every application under `apps/`. If a new cluster runs `flux bootstrap` against the same repository and path, Flux applies all of it again, in the order its `dependsOn` fields set.

## What Git does not hold

Some objects never go in Git on purpose, because anyone who can read the repository could read them. Others are not configuration at all.

| Missing from Git | Example | Where it should come from |
| --- | --- | --- |
| The Git credential Flux reads with | The Secret `flux-system`: token, password or SSH key | `flux bootstrap` creates it again; keep the token or deploy key in a password manager or a secret store |
| Credentials for other sources | A Secret for a second private repository or a Helm registry | A secret store, or encrypted in Git (SOPS) with the key outside Git |
| kubeconfigs for remote clusters | A Secret such as `staging-kubeconfig` | Cluster API recreates `<cluster>-kubeconfig`; hand-made ones come from a secret store |
| The decryption key | The private key that decrypts SOPS-encrypted files | A secret store; restore it **before** Flux reconciles |
| Tenant Secrets | Database passwords a team created by hand | The team's secret store, or encrypted in Git |
| Data | PersistentVolumes, databases | Backups made with a backup tool; Flux never holds data |

The rule behind the table: Flux can only apply what it can read and decrypt. Every credential Flux needs to read or decrypt must be back before Flux needs it.

## Take stock of the playground

List the Secrets that Flux depends on right now. Each Flux source names its credential in `spec.secretRef`:

<!-- astrona:playground:renew -->

```sh
kubectl -n flux-system get secrets
kubectl get gitrepositories -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" uses secret "}{.spec.secretRef.name}{"\n"}{end}'
```

The playground has one: the `GitRepository` `flux-system` uses the Secret `flux-system`, which holds the `gitops` username and password. Look at its keys, not its values:

```sh
kubectl -n flux-system get secret flux-system -o jsonpath='{.data}' | tr ',' '\n' | cut -d: -f1
```

The keys are `username` and `password`, because the cluster was bootstrapped with token authentication. A cluster bootstrapped over SSH holds `identity`, `identity.pub` and `known_hosts` instead.

## Export what Flux manages

The Flux command-line tool can export the Flux objects in the cluster as YAML. It is a quick way to compare the cluster with Git, and a record of what was running before a risky change:

```sh
flux export source git --all > flux-sources.yaml
flux export kustomization --all > flux-kustomizations.yaml
grep -c '^kind:' flux-sources.yaml flux-kustomizations.yaml
```

The two files hold the `GitRepository` and `Kustomization` objects of the `flux-system` namespace, without their status. `flux export` never prints the contents of Secrets; it only shows which Secret a source names. That is deliberate, and it is the reason the credentials need a home of their own.

You now know what Git rebuilds, what it cannot, and where each missing piece should come from. The question still open is the practical one: what actually happens to the running workloads when Flux is removed and brought back.

## Common pitfalls

> [!WARNING]
> - **Treating `flux export` as a backup.** It exports the Flux objects, which are already in Git. It never exports Secret values or data.
> - **Keeping the only copy of a credential in the cluster.** If the Secret `flux-system` is the only place the deploy key lives, losing the namespace loses the key.
> - **Restoring the decryption key after Flux starts.** Flux fails every Kustomization that holds encrypted files until the key is back.
> - **Forgetting data.** Flux recreates a PersistentVolumeClaim from Git, empty. Restore data from a backup tool.
