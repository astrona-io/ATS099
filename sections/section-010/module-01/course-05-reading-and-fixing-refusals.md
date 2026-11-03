# Reading And Fixing A Refused Tenant

Sooner or later a tenant's Flux object stops being `Ready`, and the tenant asks the platform team why. A good answer comes from reading the object's status, not from guessing. This part gives a short routine that finds the cause of the most common refusals in a locked-down cluster and tells you where to fix each one.

## Start with the status

The first command is `flux get`, which prints the `Ready` condition and its message in one line per object. Use `-A` to see all namespaces, or `-n` for one:

```sh
flux get kustomizations -A
flux get helmreleases -A
```

A failing object shows `False` in the `READY` column and a message. Read the whole message. It usually names the exact object, the verb and the account that was refused. If the message is cut off, `kubectl describe` prints it in full, together with the recent events:

```sh
kubectl -n team-a describe kustomization team-a
```

The `Status` block shows the conditions and the last attempted revision. The `Events` block at the end lists what the controller reported, newest last.

## Match the message to a cause

Most refusals in a multi-tenant cluster fall into four groups. Each group has a recognisable message and a different owner for the fix.

The first group is RBAC. The message says that the user `system:serviceaccount:<namespace>:<name>` cannot perform a verb on a resource in a namespace or at cluster scope. The account is right and the Role is too small, or the tenant tried something it must not do. The platform team changes the Role or tells the tenant to remove the object.

The second group is a missing ServiceAccount. The message says that the ServiceAccount is not found. The name in `serviceAccountName` is wrong, or the ServiceAccount lives in a different namespace than the Flux object, or the platform repository has not created it yet.

The third group is a cross-namespace reference. With `--no-cross-namespace-refs=true`, the message says that a cross-namespace reference is blocked by the controller's policy. The tenant's `sourceRef` names a namespace other than its own, and the fix is to use a source in the tenant's namespace.

The fourth group is a remote base. With `--no-remote-bases=true`, Kustomize refuses a file that points at a URL, and the build fails before anything is applied. The fix is to copy the base into the tenant repository or into the platform repository.

## Ask Kubernetes what the account may do

For an RBAC refusal, confirm it independently of Flux. `kubectl auth can-i` evaluates a request as another account when you use `--as`:

```sh
kubectl auth can-i create deployments -n team-a --as=system:serviceaccount:team-a:team-a
kubectl auth can-i --list -n team-a --as=system:serviceaccount:team-a:team-a
```

The first command answers `yes` or `no`. The second lists every verb and resource the account may use in that namespace. Run the check as the account the Flux object names, not as the tenant's human users.

## Read the controller events and logs

The `flux events` command lists Kubernetes events for Flux objects, and `--for` limits the list to one object:

```sh
flux events --for Kustomization/team-a -n team-a
flux logs --kind=Kustomization --name=team-a --namespace=team-a --since=10m
```

The log lines carry the same message as the status, plus the revision that was attempted. When a Flux object is `Ready` `False` for a reason that is not in the message, the controller log is the next place to look.

## Reconcile after the fix

A fix in Git is picked up on the next interval. To skip the wait, ask Flux to fetch the source and apply it now:

```sh
flux reconcile kustomization team-a -n team-a --with-source
```

A fix that lives in the platform repository needs the platform `Kustomization` to run first. Reconcile `flux-system`, then the tenant object.

## Do not fix a refusal by weakening the cluster

Every group of refusals has a tempting shortcut: bind `cluster-admin` with a ClusterRoleBinding, allow cross-namespace references, or turn off the lockdown flag. Each one removes the protection for every tenant, not only for the one who asked. Fix the object that is wrong, in Git, and keep the lockdown.

## Common pitfalls

> [!WARNING]
> - **Testing as your own user.** Your account can do more than the tenant's. Always use `--as` with the ServiceAccount named in the Flux object.
> - **Cutting the message short.** The decisive part is often at the end of a long line. Use `kubectl describe` or `flux events`.
> - **Fixing the symptom in the cluster.** Flux restores what Git says. A manual edit disappears at the next reconciliation.
> - **Forgetting the platform repository.** The ServiceAccount, Role and RoleBinding of a tenant live there, so a missing right is often fixed there, not in the tenant repository.
