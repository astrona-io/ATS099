# Environments As Folders And Overlays

Staging and production run the same application with a few different values: the number of replicas, a hostname, a resource size, an image tag. The repository layout should make those differences small and easy to read in a diff.

## A folder per environment

The simplest layout has one folder per environment, each with complete manifests:

```text
apps/
  podinfo-staging/
  podinfo-production/
clusters/
  kind/
    podinfo-staging.yaml
    podinfo-production.yaml
```

It is easy to read and has no indirection. The cost is copying: a change to the application must be made in each folder, and the folders can drift apart without anyone deciding it.

## A base and overlays

Kustomize keeps one base and a small overlay for each environment:

```text
apps/
  podinfo/
    base/
      deployment.yaml
      service.yaml
      kustomization.yaml
    staging/
      kustomization.yaml
    production/
      kustomization.yaml
```

An overlay names the base and lists only what differs:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base
namespace: podinfo-production
patches:
  - target:
      kind: Deployment
      name: podinfo
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
```

The Flux `Kustomization` for production then sets `path: ./apps/podinfo/production`. Review a change to the base once, and it applies to both environments.

## Values from the cluster side

Some values are not application manifests: a domain name, a cluster name, a region. Flux can substitute them at build time from the Kustomization:

```yaml
spec:
  postBuild:
    substitute:
      cluster_env: production
    substituteFrom:
      - kind: ConfigMap
        name: cluster-vars
```

Manifests then use `${cluster_env}` or `${cluster_env:=staging}` for a value with a default. `substituteFrom` reads a ConfigMap or a Secret in the namespace of the Kustomization on the management cluster, because the build happens there.

Substitution replaces every `${...}` in the files. A shell script inside a ConfigMap that uses `${HOME}` is changed too. Escape a literal one as `$${HOME}`, or disable it with the label or annotation `kustomize.toolkit.fluxcd.io/substitute: disabled` on that object.

## One repository or several

One repository for all environments gives one place to review and one history. It also means the same people can change production and staging, unless branch protection and code owners limit it. Separate repositories give separate access rules at the cost of more repositories to keep in step. Choose from who must be allowed to change production, not from habit.

## Branches or folders

A branch per environment looks natural and causes trouble: merging between branches carries unwanted differences, and a diff between environments is a diff between branches. A folder per environment keeps all environments visible on one branch. Prefer folders.

## Common pitfalls

> [!WARNING]
> - **Copying folders and letting them drift.** Use a base once the folders share most content.
> - **Overlays that patch many fields.** If the overlay is nearly the whole file, the environments are not the same application.
> - **Putting Secrets in `substitute`.** The values end up in the Kustomization object. Use `substituteFrom` with a Secret.
> - **A branch per environment.** Merges carry differences nobody meant to move.
