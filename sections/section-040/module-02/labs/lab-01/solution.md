# Solution: Restore Secrets From An Exported Backup

Work the task yourself first. Running `astrona submit -c sections/section-040/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the restored values match the backup, the labels are kept and Flux does not own the Secrets, and nothing secret was committed.

## Step 1: Read the backup

```sh
kubectl -n gitea get configmap dr-backup -o jsonpath='{.data.secrets-backup\.yaml}' > secrets-backup.yaml
```

Open the file. It is a `List` with two Secrets. Each item has `metadata.uid`, `metadata.resourceVersion` and `metadata.creationTimestamp`.

## Step 2: Remove the instance fields

```sh
grep -v -E '^    (uid|resourceVersion|creationTimestamp):' secrets-backup.yaml > secrets-clean.yaml
```

The four spaces match the fields of the items and leave the list's own `metadata` alone. Read `secrets-clean.yaml` and check that the three fields are gone from both items.

## Step 3: Apply it

```sh
kubectl apply -f secrets-clean.yaml
kubectl -n podinfo get secrets -l dr-backup=critical
```

Both Secrets are listed. If you apply the raw file instead, the create is refused because of the `resourceVersion`.

## Step 4: Check the values and delete the files

```sh
kubectl -n podinfo get secret app-credentials -o jsonpath='{.data.password}' | sha256sum
kubectl -n gitea get configmap dr-baseline -o jsonpath='{.data.app-credentials-sha256}'
```

The two hashes are equal. On macOS, use `shasum -a 256`. Then delete the plain text files, because they hold passwords:

```sh
rm secrets-backup.yaml secrets-clean.yaml
```

## Step 5: Submit

```sh
astrona submit -c sections/section-040/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Create new Secrets with `kubectl create secret` | The passwords are new, so the hash check fails |
| Apply the raw export | The create is rejected because of `resourceVersion` |
| Commit the Secrets to `gitops/fleet` so Flux restores them | Passwords sit in Git history in plain text, and the Git check fails |
