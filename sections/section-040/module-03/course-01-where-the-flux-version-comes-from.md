# Where The Flux Version Comes From

Two things have a version: the `flux` command-line tool on your machine, and the controllers running in the cluster. They are installed separately and they can differ.

## Read both versions

```sh
flux version
```

With a cluster reachable, the command prints the version of the CLI and the version of each controller in the cluster. Without one, add `--client` to print only the CLI. A CLI that is newer than the controllers is normal right after you update your machine and before you upgrade the cluster. A mismatch of more than a few minor versions is something to fix: the CLI can write fields that old controllers do not know.

## What bootstrap installed

`flux bootstrap` writes three files into the path you gave, under a `flux-system` folder:

| File | What it holds |
| --- | --- |
| `gotk-components.yaml` | The CRDs and the Deployments of the controllers, at the version of the CLI that wrote it |
| `gotk-sync.yaml` | The `GitRepository` and `Kustomization` named `flux-system` |
| `kustomization.yaml` | A kustomize file that lists the other two, and where your patches go |

The Kustomization `flux-system` applies this folder, so Flux manages itself. The version in the cluster is whatever `gotk-components.yaml` says.

## Why not change the cluster by hand

If you edit a controller Deployment with `kubectl`, the Kustomization `flux-system` sees the difference at its next reconcile and sets the Deployment back to what Git says. The edit is gone. This is the right behaviour: Git is the truth. A change must be a commit.

## What flux check verifies

```sh
flux check
```

It reports on the Kubernetes version against what Flux supports, then on each controller that its Deployment is ready, and that the custom resource definitions exist. It exits with a non-zero status when something is wrong. Run it before and after every upgrade, and keep the output.

Before an installation, `flux check --pre` tests only the prerequisites.

## Preview what the CLI would install

```sh
flux install --export
```

prints the manifests that the installed CLI would apply, without touching the cluster. This is the same content that `flux bootstrap` writes to `gotk-components.yaml`. Compare it with the file in Git to see what an upgrade would change.

## Components you can choose

`flux bootstrap` installs the four default controllers: source, kustomize, helm and notification. Image automation controllers are optional and are added with `--components-extra`. Choose the same list every time you bootstrap, because a bootstrap with a shorter list removes the extra controllers from the manifests.

## Common pitfalls

> [!WARNING]
> - **Treating the CLI version as the cluster version.** Read both.
> - **Editing a controller with `kubectl`.** The next reconcile reverts it.
> - **Bootstrapping with a different component list.** Controllers disappear from the manifests.
> - **Upgrading without a `flux check` before.** You cannot tell what the upgrade broke.
