# Restoring And Checking A Backup

A backup that was never restored is a hope. This part sets out the order of a restore and the checks that tell you it worked.

## The order

1. **Create the cluster** and the namespaces the Secrets live in. A Secret cannot be created in a namespace that does not exist.
2. **Restore the Secrets Flux needs to start,** in `flux-system`: the credential to read Git, and the decryption key if the repository uses encrypted files.
3. **Bootstrap Flux** with the same repository, branch and path.
4. **Restore the application Secrets** that are not in Git, before the workloads need them. A Deployment that refers to a missing Secret stays in a waiting state, and starts when the Secret appears.
5. **Check** that every Flux object is `Ready` and the workloads run.

Namespaces that Flux itself creates are made when it applies them. A Secret restore that runs earlier needs the namespace first. If that is a problem, create the namespace by hand and let Flux adopt it later.

## Apply a clean backup

```sh
kubectl apply -f secrets-backup.yaml
```

`kubectl apply` works for a file that holds a `List` of objects. If the file is encrypted, decrypt it to standard input and pipe it, so the plain text never lands on disk:

```sh
age --decrypt -i key.txt secrets-backup.yaml.age | kubectl apply -f -
```

## Check the data, not only the name

An object with the right name can have the wrong content. Compare a hash of the value with a hash taken at backup time:

```sh
kubectl -n podinfo get secret app-credentials -o jsonpath='{.data.password}' | sha256sum
```

Store the hash with the backup record. A match means the value is the one that was saved, and the value never has to be printed on a screen. On macOS, `shasum -a 256` replaces `sha256sum`.

## Check that Flux did not take it over

A restored Secret that is not in Git must stay out of Flux's control. Check that it has no `kustomize.toolkit.fluxcd.io/name` label after the restore. If a Kustomization has `prune: true` and later applies an object with the same name from Git, the object becomes Flux's and is deleted when it leaves Git.

## Run a restore test

Do this on a throwaway cluster, on a schedule and after each large change:

1. Create a new cluster.
2. Follow the written restore steps, using only the backup and the written list.
3. Compare hashes for every item on the list of what to back up.
4. Check that all Flux objects are `Ready` and the workloads work.
5. Write down what was missing, and add it to the backup.

The most valuable result of a test is a missing item. It is cheaper to find it in a test than in an incident.

## Common pitfalls

> [!WARNING]
> - **Restoring after Flux has started failing.** Restore the credential first, so Flux starts clean.
> - **A restore into a namespace that does not exist yet.** Create it first.
> - **Checking names only.** Compare hashes.
> - **A backup that no one has decrypted this year.** The key may be lost or the tool may have changed.
