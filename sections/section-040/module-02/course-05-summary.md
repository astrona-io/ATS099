# Summary

Git holds the manifests but not the Secrets that must stay out of it. This module covered what to back up, how to export it, the keys for encrypted files, and how to restore and test.

## What you learned

Sort every item into three groups: in Git, recreate from a source, and back up. The backup holds the credential Flux uses to read Git, other repository credentials, kubeconfig Secrets, decryption keys and Secrets made by hand. Data in volumes needs its own backup. Flux marks what it applies with labels, so Secrets without those labels were created some other way.

A raw export carries `uid`, `resourceVersion` and `creationTimestamp`, and a create with a `resourceVersion` is rejected. Remove the instance fields, read the cleaned file, and select Secrets by a label. `flux export` prints Flux objects that can be applied again, and a difference from Git is a change that only the cluster holds. A file of Secrets is as sensitive as the Secrets: encrypt it, keep it outside the cluster and outside the repository Flux reads, limit access, and set a retention.

With SOPS, kustomize-controller reads the decryption key from the Secret named in `spec.decryption.secretRef`, and without it every file that uses the key fails. A new key cannot open old files. The Sealed Secrets controller keeps its keys as Secrets with the label `sealedsecrets.bitnami.com/sealed-secrets-key`, and a backup must hold all of them. Keep keys in more than one place and never next to the encrypted files.

Restore in this order: cluster and namespaces, the Secrets Flux needs to start, `flux bootstrap` with the same repository, branch and path, the application Secrets, and then checks. Compare hashes of values and not only names. A restore test on a throwaway cluster shows what the backup is missing.

The key facts to remember are these:

- Back up what only the cluster holds, and nothing more.
- Remove instance fields before you apply an export.
- The decryption key is the most important item in the backup.
- Restore the Secrets Flux needs before you bootstrap, and test the restore.

<!-- astrona:playground:destroy -->
