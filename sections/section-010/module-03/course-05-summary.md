# Summary

A shared cluster is governed at three places: the Git server, the source controller and the Kubernetes API server. A rule at one place does not replace a rule at another.

The repository layout decides who can change what. A monorepo is simple but cannot separate tenants by permission. A platform repository plus one repository per tenant matches ownership to permissions. For environments, a folder per environment is easier to review than a branch per environment. Flux objects in the cluster folder decide what runs where, and `spec.dependsOn` makes the tenants wait for the policies and controllers they need.

On the Git server, protect the branch Flux reads with pull requests, approvals and blocked force pushes, and give Flux a read-only credential. Source-controller adds a second check: `spec.verify` on a `GitRepository` checks commit signatures in `HEAD`, `Tag` or `TagAndHEAD` mode, and on an `OCIRepository` it checks a cosign signature. A failed check leaves the old artifact in place and produces no new one.

At the API server, a ValidatingAdmissionPolicy and its binding reject a tenant Flux `Kustomization` that names no ServiceAccount at the moment it is created, instead of failing at the next reconciliation. The binding selects tenant namespaces by the label `toolkit.fluxcd.io/tenant`, and `validationActions` chooses between `Deny`, `Warn` and `Audit`. Auditing closes the loop: `flux get all -A`, `flux tree`, `flux trace`, owner labels and `kubectl auth can-i --list` show what each tenant runs and what its account may do. The key facts to remember are these:

- Match repository ownership to who may push.
- Protect the watched branch and verify signatures where it matters.
- Enforce rules at admission, not only in controller flags.
- Audit with the labels Flux sets, not labels a tenant writes.

<!-- astrona:playground:destroy -->
