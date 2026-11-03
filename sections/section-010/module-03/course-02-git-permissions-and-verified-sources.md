# Git Permissions And Verified Sources

Flux applies what Git says. Whoever can push to the branch Flux watches can therefore change the cluster. Protecting the cluster means protecting the branch. This part covers the controls on the Git server, and then the controls that Flux itself offers: a check of commit signatures on a `GitRepository` and of artifact signatures on an `OCIRepository`.

## Controls on the Git server

Most Git hosts let you protect a branch. For the branch that Flux reads, usually `main`, set these rules. Require pull requests, so that a change cannot be pushed directly. Require at least one approval from someone other than the author. Block force pushes, because a force push can rewrite history under Flux. Require status checks, such as a build of the Kustomize output, to pass before a merge.

A file such as `CODEOWNERS` lets you assign reviewers to paths. For the platform repository, the folder `tenants/team-a` can require approval from the platform team and the `team-a` leads. How the file is read depends on the Git host, so check its documentation.

Give Flux a read-only credential. Flux needs to fetch, not push, unless you use image update automation. A deploy key with read access, or a read-only token, limits the damage if the credential leaks. Create it with the Flux CLI:

```sh
flux create secret git team-a-auth \
  --url=ssh://git@git.example.com/team-a/app \
  --namespace=team-a
```

The command generates an SSH key pair, creates the Secret in the cluster and prints the public key. Add that public key to the repository as a read-only deploy key. The Secret must be in the namespace of the `GitRepository` that references it.

## Verify commit signatures

A `GitRepository` can check that the newest commit is signed by a key you trust. Source-controller then refuses to produce an artifact from an unsigned or wrongly signed commit. The field is `spec.verify`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: team-a
  namespace: team-a
spec:
  interval: 1m
  url: ssh://git@git.example.com/team-a/app
  ref:
    branch: main
  secretRef:
    name: team-a-auth
  verify:
    mode: HEAD
    secretRef:
      name: team-a-signers
```

The `mode` selects what is checked: `HEAD` checks the latest commit of the branch, `Tag` checks the tag, and `TagAndHEAD` checks both. The Secret `team-a-signers` holds the public keys of the people allowed to sign, as files that end in `.pub`. The keys are OpenPGP public keys exported with `gpg --armor --export`.

When the check fails, the `GitRepository` becomes `Ready` `False` with a message about verification, and no new artifact is produced. The old artifact stays in place, so what already runs keeps running and the failed revision is never applied.

## Verify OCI artifacts

When a tenant ships its manifests as an OCI artifact, an `OCIRepository` can verify a cosign signature. The `verify` block names the provider and, for a key-based signature, the Secret with the public key:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: team-a
  namespace: team-a
spec:
  interval: 5m
  url: oci://registry.example.com/team-a/app
  ref:
    tag: latest
  verify:
    provider: cosign
    secretRef:
      name: cosign-public-key
```

The Secret `cosign-public-key` holds the key under a name that ends in `.pub`. Keyless signing with an identity match is also available through `matchOIDCIdentity`. Read the current field names in the Flux documentation before you use it.

## What verification does not cover

A verified source proves who made the commit or the artifact. It does not prove that the content is safe, so the other controls still apply: review, impersonation and policy. A signature check also only covers the source that has the `verify` block, so put it on every tenant source in the platform repository's `sync.yaml` that you want protected.

## Check a source from the command line

`flux get sources git -A` shows the state of every `GitRepository`. A verification failure shows up there:

```sh
flux get sources git -A
kubectl -n team-a describe gitrepository team-a
```

The `describe` output has a `Conditions` list. Look at the condition of type `SourceVerified`, which reports whether the check passed.

## Common pitfalls

> [!WARNING]
> - **Giving Flux a write credential it does not need.** A leaked read-only key cannot change the repository.
> - **Verifying a branch that nobody signs on.** Flux then stops all updates from that source.
> - **Putting the public-keys Secret in the wrong namespace.** It must be in the namespace of the source.
> - **Reading a signature as a security review.** It only proves who produced the content.
