# Promotion Order With dependsOn And Health

Promotion means a change reaches production only after it has worked in staging. In a GitOps repository, one place to enforce that is the order in which Flux applies the environments.

## dependsOn

`spec.dependsOn` lists other Kustomizations that must be `Ready` before this one is applied:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo-production
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./apps/podinfo-production
  prune: true
  wait: true
  timeout: 5m
  kubeConfig:
    secretRef:
      name: production-kubeconfig
  dependsOn:
    - name: podinfo-staging
```

If `podinfo-staging` is not `Ready`, `podinfo-production` waits and reports the dependency as the reason. Both objects are on the management cluster. Each one applies to its own cluster through its own kubeconfig.

## Ready must mean healthy

`dependsOn` checks the Ready condition. A Kustomization with no health checks is `Ready` as soon as its manifests are applied, even if the pods never start. For promotion this is not enough. Set `wait: true` or a list of `healthChecks` on the staging Kustomization, so that `Ready` means the application runs.

## What dependsOn does not do

- It does not hold back a change in the same commit. If one commit changes staging and production, production waits for the staging apply to be `Ready`, then applies.
- It does not run tests. A staging application can be healthy and still wrong. Add a test job or an external check if you need one.
- It does not undo staging when production fails. Each Kustomization is independent once it has started.
- It does not cause a delay in time. If you want production to lag behind staging by a day, use a different mechanism, such as a separate tag or branch.

## Promotion by version

Another way is to give each environment its own version. Staging follows the latest tag, and production follows a pinned or an approved one:

```yaml
spec:
  ref:
    semver: ">=1.0.0 <2.0.0"
```

This field is in a `GitRepository` or an `OCIRepository`. Staging uses a source with a wide range, and production uses a source with an exact tag that a person changes after staging has been accepted. The change of that tag is the promotion, and it is a reviewed commit.

## A check that fails closed

When a dependency does not exist, is suspended, or is not `Ready`, the dependent waits. This is the safe direction. Do not set `dependsOn` to an object that you may delete; production would wait for it forever.

## Common pitfalls

> [!WARNING]
> - **`dependsOn` on a Kustomization with no health checks.** Production starts while staging pods crash.
> - **Expecting a time delay.** `dependsOn` is about state, not time.
> - **A circular dependency.** Both Kustomizations wait for each other, and neither starts.
> - **Setting production `timeout` shorter than a rollout.** The Kustomization fails and retries while the pods start.
