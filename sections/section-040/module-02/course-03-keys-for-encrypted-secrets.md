# Keys For Encrypted Secrets

The usual way to keep a Secret in Git is to commit it encrypted. The encrypted file is safe to store. Without the key, it is also useless. The key is therefore the most important item in the backup.

## SOPS with age

With SOPS, Flux decrypts files in kustomize-controller. The Kustomization sets the provider and names a Secret that holds the private key:

```yaml
spec:
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

The Secret `sops-age` is in the namespace of the Kustomization. For an `age` key, the Secret has a key whose name ends in `.agekey`, for example `age.agekey`, and the content is the private key. The public key is not secret and is used to encrypt files.

The Secret is not in Git, by design. If the cluster is lost and the Secret is gone, Flux cannot decrypt the files. Every Kustomization that uses them fails, and the failure message names the decryption.

A new key cannot decrypt old files. To change the key you must re-encrypt every file with the new public key, commit them, and give the cluster the new private key. That is a planned job. It is not a recovery step.

## Sealed Secrets

The Sealed Secrets controller generates its own key pair and keeps the private key as a Secret in the namespace where it runs, labelled `sealedsecrets.bitnami.com/sealed-secrets-key`. The controller renews the key on a schedule and keeps the old ones, because old sealed files need them. A backup must hold every key Secret with that label, not only the newest.

```sh
kubectl -n kube-system get secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml
```

If you restore a cluster and the controller starts with no keys, it makes a new one, and the old sealed files cannot be opened. Restore the key Secrets before the controller starts, or restart the controller after you restore them.

## External secret stores

When secrets live in a store outside the cluster, the cluster holds only the credential to reach the store. The files in Git hold references. Back up the access credential, and make sure the store has its own backup. Losing the cluster then costs only the time to restore the credential.

## Where to keep the key

- **Not with the encrypted files.** A key next to its files protects nothing.
- **In at least two places** controlled by different people or systems, because one lost copy otherwise means a lost archive.
- **Offline or in a vault** with an access log.
- **With a written record** of which key matches which repository and path.

## Check that you hold the right key

A backup of the key is good only if it decrypts the files. Test it by decrypting one file with the backed-up key on a machine that has nothing else. For Flux, a restore test does the same job: apply the key Secret, reconcile, and read the Kustomization status.

## Common pitfalls

> [!WARNING]
> - **No copy of the private key.** The encrypted files in Git cannot be opened.
> - **Backing up only the newest Sealed Secrets key.** Older files need older keys.
> - **The key stored next to the encrypted files.** One leak opens everything.
> - **Rotating the key without re-encrypting.** New key, old files, no access.
