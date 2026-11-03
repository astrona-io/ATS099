# Reading The State Of A Broken Flux Installation

Before you recover anything, find out what is actually broken. Flux can be damaged in four different ways, and each needs a different fix: the controllers are missing or crashing, the custom resource definitions are missing, the sources cannot fetch, or the objects are present and failing. A short triage tells which one it is, in a few commands.

## Step 1: Are the controllers and CRDs there

```sh
flux check
kubectl -n flux-system get deployments,pods
kubectl get crds | grep fluxcd.io
```

`flux check` tests that the cluster meets the prerequisites, that each controller Deployment is ready, and that the custom resource definitions exist. It exits with a non-zero status when something is wrong, so it also works in a script. Before an installation, `flux check --pre` tests only the prerequisites, such as the Kubernetes version.

If a controller is crash looping, read its log:

```sh
kubectl -n flux-system logs deploy/kustomize-controller --previous
flux logs --level=error --all-namespaces --since=30m
```

`flux logs` reads the logs of all controllers and can filter by level and age.

## Step 2: Are the sources fetching

```sh
flux get sources all -A
```

A source that is not `Ready` blocks every Kustomization that uses it. Typical causes are a missing credential Secret, a wrong URL, and a branch that no longer exists. The message in the table is the first thing to read.

## Step 3: Are the Kustomizations applying

```sh
flux get kustomizations -A
flux get helmreleases -A
```

A Kustomization with the message "dependency not ready" is not broken itself. Follow `dependsOn` back to the first one that is not `Ready`, and start there.

## Step 4: What is still running

Flux failing does not stop workloads. Check the workloads separately from Flux:

```sh
kubectl get deployments -A
kubectl get pods -A --field-selector=status.phase!=Running
```

If the workloads are healthy, the incident is about delivery and not about service, and you have time to be careful.

## When flux-system will not delete

If someone removed the controllers first and then the namespace, the Flux objects keep their finalizer and nothing is left to remove it. The namespace stays in `Terminating`:

```sh
kubectl get namespace flux-system -o jsonpath='{.status.conditions[*].message}{"\n"}'
```

The message names the objects that block the delete. A finalizer can be removed by hand with a patch that sets `metadata.finalizers` to `null`. This skips the cleanup that the finalizer protects. For a Kustomization with `prune: true`, the objects it applied stay in the cluster, and nothing owns them afterwards. Do this only when you accept that. `flux uninstall` avoids the situation, because it removes the finalizers before it removes the controllers.

## Write down what you find

Record the output of the four steps before you change anything. The record shows the starting point, and it is the first thing a second engineer asks for.

## Common pitfalls

> [!WARNING]
> - **Reinstalling Flux before reading the state.** A missing credential or a wrong path survives the reinstall and fails again.
> - **Reading only `flux get kustomizations`.** The cause is often in a source or in a controller log.
> - **Removing finalizers to "clean up".** The objects they protect are left without an owner.
> - **Assuming workloads are down.** Check them; they usually are not.
