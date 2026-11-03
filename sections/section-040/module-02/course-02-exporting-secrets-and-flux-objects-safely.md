# Exporting Secrets And Flux Objects Safely

An export is only useful if it can be applied again on a new cluster. A raw `kubectl get -o yaml` output is a snapshot of one live object, and it carries fields that belong to that object only.

## What a raw export contains

```sh
kubectl -n podinfo get secret app-credentials -o yaml
```

The output has the data and also fields the API server added: `metadata.uid`, `metadata.resourceVersion` and `metadata.creationTimestamp`. A new object must not carry them. The API server rejects a create that has a `resourceVersion`, with the message "resourceVersion should not be set on objects to be created". The `uid` and the timestamp are replaced by the server, but they are noise in a backup, and a diff between two backups should show only real changes.

A Secret that was applied with `kubectl apply` also has the annotation `kubectl.kubernetes.io/last-applied-configuration`, which holds a copy of the data. Remove it from the backup too.

## A clean export

Export a selection of Secrets by label, then remove the instance fields. Here the labelled Secrets in one namespace are exported to a file and filtered with `grep`:

```sh
kubectl -n podinfo get secrets -l dr-backup=critical -o yaml \
  | grep -v -E '^    (uid|resourceVersion|creationTimestamp):' > secrets-backup.yaml
```

The pattern has four spaces because the fields of each item in a `List` are indented under `metadata`. The two spaces of the list's own `metadata.resourceVersion` are left alone. Open the file and read it before you rely on it. If you have a tool such as `yq` or `kubectl neat`, it does the same job with less risk of a pattern that misses; the principle is the same.

A label such as `dr-backup=critical` is the simplest way to say "this goes in the backup". The export command then needs no list of names, and a new Secret that carries the label is included without a change to the script.

## Export the Flux objects

Flux objects are in Git already, but an export shows the live state, including what was changed with `kubectl` and not committed:

```sh
flux export source git --all -A > sources.yaml
flux export kustomization --all -A > kustomizations.yaml
```

`flux export` prints manifests that can be applied again and leaves out the status. Compare the export with Git. A difference is a change that exists only in the cluster, and it will be lost in a rebuild.

## Protect the file

A file of Secrets in plain text is as sensitive as the Secrets. Treat it so:

- **Encrypt it before it leaves the machine.** Use the tool the organisation has chosen, such as `age`, `gpg` or SOPS.
- **Store it outside the cluster it backs up,** and outside the Git repository that Flux reads. Storing it in that repository would send plain text secrets to every reader and to the history.
- **Limit who can read it** and log who does.
- **Delete the plain text copy** when the encrypted one exists.
- **Set a retention.** Old backups hold old credentials that may have been rotated; decide how long you keep them.

## Do not run an export as a habit without a destination

The export is half a backup. The other half is a place to put it, a schedule, and a test that restores it. A shell history of `kubectl get -o yaml` commands is not a backup plan.

## Common pitfalls

> [!WARNING]
> - **Applying a raw export.** `resourceVersion` makes the create fail.
> - **A backup in the repository Flux reads.** Plain text secrets in Git history cannot be taken back.
> - **A filter that quietly misses.** Read the cleaned file once.
> - **Exporting once.** Credentials change; the backup must follow.
