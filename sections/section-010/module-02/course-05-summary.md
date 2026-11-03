# Summary

Impersonation limits what a tenant's files may create. Guardrails limit how much a tenant may use and what it may reach, and they only hold when the tenant cannot change them.

The role of the tenant decides that. A RoleBinding to `cluster-admin` allows every verb on every namespaced resource, so the tenant could delete its own quota or network policy. The built-in ClusterRole `admin` allows deploying workloads, Secrets and NetworkPolicies but only reads ResourceQuota, which makes it a better default. A custom Role is narrower still and must include `secrets` for Helm. The `roleRef` of a RoleBinding is immutable, so a change of role means a new binding name, and pruning removes the old binding.

A ResourceQuota caps the total of pods, Services and compute requests and limits in one namespace, and a LimitRange gives containers default requests and limits so pods are accepted under a compute quota. A default-deny NetworkPolicy blocks all incoming traffic to the namespace until allow rules name what must work, and it only has an effect when the cluster's network plugin enforces NetworkPolicy. Each tenant gets its own SOPS decryption Secret in its own namespace, referenced by `spec.decryption.secretRef`, so one tenant cannot decrypt another's files.

At scale, every tenant has the same folder shape in the platform repository, generated with `flux create tenant --export` or built from a shared Kustomize base. Offboarding removes the tenant's Flux objects first, while its ServiceAccount still exists, and the rest of the folder second. The key facts to remember are these:

- Bind tenants to `admin` or a custom Role, not `cluster-admin`, when the platform sets limits.
- Rename a RoleBinding to change its role.
- One decryption key per tenant, in the tenant's namespace.
- Remove a tenant's Flux objects before its ServiceAccount.

<!-- astrona:playground:destroy -->
