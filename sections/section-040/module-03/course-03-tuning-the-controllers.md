# Tuning The Controllers

The defaults suit a small cluster. A cluster with many objects, large repositories or slow remote clusters may need more concurrency, more memory, or both. Tuning is a change to the controller Deployments, and, like every change, it goes through Git.

## Where the patch goes

The file `clusters/kind/flux-system/kustomization.yaml` lists the generated files. Add a `patches` section to it. Kustomize applies the patches to the controller Deployments when the Kustomization `flux-system` builds the folder. Bootstrap does not remove your patches when it runs again.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - gotk-components.yaml
  - gotk-sync.yaml
patches:
  - patch: |
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --concurrent=8
    target:
      kind: Deployment
      name: kustomize-controller
```

The patch is a JSON 6902 patch. The path `/spec/template/spec/containers/0/args/-` appends one argument to the list. The target selects the Deployment.

## Concurrency

`--concurrent` sets how many objects a controller reconciles at the same time. The default is 4 for most controllers. A higher value helps when many objects wait for a slot, and it costs CPU, memory, and load on the API server and the Git host. Raise it in steps and measure.

Related settings:

- `--kube-api-qps` and `--kube-api-burst` limit the rate of calls to the Kubernetes API. More concurrency can hit these limits first.
- `--requeue-dependency` sets how long a Kustomization waits before it checks a dependency again.
- `--log-level` sets log detail. Use `debug` for a short investigation, not permanently.

## Resource limits

The controller Deployments have CPU and memory requests and limits. Read the current values in `gotk-components.yaml` before you change them. A controller that uses more memory than its limit is killed by Kubernetes and restarted. Raise the limit with a second patch:

```yaml
  - patch: |
      - op: add
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: 2Gi
    target:
      kind: Deployment
      name: kustomize-controller
```

With `add`, an existing value is replaced. The path needs its parent, so this works when the Deployment already has `resources.limits`, which the Flux manifests have.

Raise a limit together with the request when the controller always needs that much, so that the scheduler places it on a node that has the memory.

## Apply it through Git

1. Edit `kustomization.yaml` in the repository and commit.
2. `flux reconcile kustomization flux-system --with-source`.
3. The Deployment changes, so the pod restarts. Wait with `kubectl -n flux-system rollout status deployment/kustomize-controller`.
4. Check the live values:

```sh
kubectl -n flux-system get deployment kustomize-controller \
  -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}{.spec.template.spec.containers[0].resources.limits.memory}{"\n"}'
```

A patch that does not match its target is an error in the build, and the Kustomization `flux-system` reports it. A patch with a typo in the path can stop Flux from updating itself. Check the kustomize build on your machine first: `kubectl kustomize clusters/kind/flux-system` prints the result.

## When to tune and when to split

If one controller is slow because of a few huge objects, more concurrency does not help. Look first at what is large: a repository with many files, a Kustomization with thousands of objects, a Helm chart that takes a long time to render. Splitting one big Kustomization into several that run at the same time often helps more than a flag.

## Common pitfalls

> [!WARNING]
> - **Changing the Deployment with `kubectl`.** The next reconcile reverts it.
> - **A patch with the wrong path.** The Kustomization `flux-system` fails to build.
> - **Raising concurrency without measuring.** You move the bottleneck to the API server or the Git host.
> - **Setting a limit below real use.** The controller is killed and restarts again and again.
