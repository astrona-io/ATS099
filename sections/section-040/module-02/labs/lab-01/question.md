# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** Disaster recovery

## Scenario

Two Secrets that are not in Git, `app-credentials` and `registry-auth`, lived in the namespace `podinfo`. Both are gone. Before the incident, someone ran an export of every Secret with the label `dr-backup=critical` and stored it in the ConfigMap `dr-backup` in the namespace `gitea`, under the key `secrets-backup.yaml`. It is the raw output of `kubectl get secrets -o yaml`, with the fields that the API server adds. The ConfigMap `dr-baseline` in the same namespace holds a hash of each password so that the grader can check the values. Do not change or delete either ConfigMap.

## Your task

1. Read the backup from the ConfigMap `dr-backup`.
2. Remove the fields that a new object must not carry, so that the file can be applied again.
3. Restore both Secrets into the namespace `podinfo` from the backup. Do not create new values.

## Constraints

- Do not commit the Secrets, or any file that holds them, to `gitops/fleet`.
- Do not create new passwords. The restored values must be the backed-up values.
- Do not change the Flux objects.

## Done when

- `app-credentials` and `registry-auth` exist in `podinfo` with the backed-up passwords.
- Both Secrets keep the label `dr-backup=critical` and carry no Flux ownership labels.
- No Secret manifest is in `gitops/fleet`, and the Kustomizations `flux-system` and `podinfo` are `Ready`.
