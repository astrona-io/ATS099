# Backing Up What Git Does Not Hold

Git holds the manifests. It does not hold the Secrets that the cluster needs and that must never be in Git in plain text: the credential Flux uses to read Git, passwords for applications, the key that decrypts encrypted files, and credentials for other clusters. If the cluster is lost, those are lost with it, unless someone backed them up. This module is about taking that backup, protecting it, and restoring from it in the right order.

The module has four parts. **What To Back Up And What To Leave** sorts every item into "in Git", "recreate from a source" and "back up". **Exporting Secrets And Flux Objects Safely** shows how to export objects as manifests that can be applied again, and how to protect the file. **Keys For Encrypted Secrets** covers the decryption key for SOPS and the key of Sealed Secrets, which are the most important items to back up. **Restoring And Checking A Backup** sets out the restore order and how to test a backup before you need it; a graded lab follows it.

## Learning objectives

After this module you can:

- Sort the things a cluster needs into those in Git, those that can be recreated, and those that must be backed up.
- Export a Secret as a manifest that can be applied again, and remove the fields that a new object must not carry.
- Say why a backup of Secrets must be encrypted and stored outside the cluster.
- Name the decryption key that a SOPS setup needs and the key of a Sealed Secrets controller, and say why losing them is serious.
- Restore Secrets before Flux needs them, and check that the restored data is the data that was backed up.
- Run a restore test on a throwaway cluster.

## Before you start

You need Kubernetes Secrets, `kubectl get -o yaml` and a Flux `Kustomization`. The previous module in this section showed what Git does not hold.

Your playground is a single-node `kind` cluster with Flux 2.9.6 bootstrapped from `gitops/fleet` at the path `clusters/kind`, on an in-cluster Git server called Gitea. podinfo runs in the namespace `podinfo`. Two Secrets, `app-credentials` and `registry-auth`, exist in `podinfo` and are not in Git.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git`, user `gitops`, password `gitops-password` (lab-only). To use `git` from your machine, start this port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If `git` says it cannot resolve `gitea.localtest.me`, add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
