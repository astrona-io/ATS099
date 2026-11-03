# Upgrading Flux Through Git

For a cluster that was bootstrapped, the upgrade is the same command as the install, run with a newer CLI. The change arrives as a commit that you can read.

## Before the upgrade

1. Read the release notes of every version between yours and the target. Look for removed APIs, changed defaults and new required fields.
2. Run `flux check` and keep the output. Fix anything that is already failing.
3. Make sure Git is the truth. If a Kustomization is suspended or an object was changed by hand, decide that first.
4. Try the upgrade on a cluster that is not production.

## Update the CLI

Install the target version of the `flux` command-line tool by the method you used to install it, for example your package manager or the install script, then check the result with `flux version --client`.

## Run bootstrap again

```sh
flux bootstrap git --url=<repository URL> --branch=main --path=clusters/kind
```

Use the same URL, branch, path, authentication flags and component list as the first time. Bootstrap is safe to run again. It compares the manifests with what is in the repository and commits only what changed, which is normally `gotk-components.yaml`. Pull the repository and read the commit:

```sh
git pull
git log -1 --stat
git diff HEAD~1 -- clusters/kind/flux-system/
```

The diff shows the new image tags and any changes to the Deployments and CRDs. Your patches in `kustomization.yaml` are kept, because bootstrap does not overwrite a `kustomization.yaml` that already exists in the folder. Check that this is true on your version before you rely on it, by reading the diff.

## Let Flux apply it

Flux's own Kustomization applies the commit at its next interval, or at once with:

```sh
flux reconcile kustomization flux-system --with-source
flux check
```

The controllers restart one after the other as their Deployments change. A short pause in reconciling is normal. Watch with `kubectl -n flux-system get pods`.

## After the upgrade

- Run `flux check`, then `flux get all -A`, and compare with the output from before.
- Look for objects that are no longer `Ready` and read their messages. A new version may reject a field that an older one ignored.
- Read the controller logs for warnings about deprecated fields.

## Roll back

A failed upgrade is undone with Git. Revert the commit that changed `gotk-components.yaml`:

```sh
git revert <commit>
git push
```

Flux applies the old manifests. This works while the Kustomization `flux-system` can still run. If a controller is stuck so badly that it cannot apply anything, apply the old manifests by hand once:

```sh
kubectl apply -f clusters/kind/flux-system/gotk-components.yaml
```

A rollback of the controllers does not undo changes that the new version made to stored objects. Custom resource definitions may keep new versions. Read the release notes for a note on a downgrade before you rely on one.

## Automating the upgrade

Some teams let a dependency tool open a pull request that updates `gotk-components.yaml`, and merge it after review. This keeps the upgrade a normal commit and makes the history show when each version arrived. The rules are the same: read the diff, run `flux check`, keep a way back.

## Common pitfalls

> [!WARNING]
> - **Skipping many versions at once.** Read the notes of each, and go one step at a time if notes disagree.
> - **Changing the bootstrap flags.** Use the original ones.
> - **Not reading the commit.** The diff is the review.
> - **Upgrading production first.** Rehearse on a cluster you can lose.
