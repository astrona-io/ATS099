# Cross-Namespace Rules For Other Kinds

The first part of this module showed `sourceRef.namespace` on a Kustomization. Several other Flux fields can point at another namespace, and some cannot. A platform that sets the lockdown must know which is which.

## Fields that accept a namespace

- `spec.sourceRef.namespace` on a Kustomization.
- `spec.chart.spec.sourceRef.namespace` on a HelmRelease, for a HelmRepository, GitRepository or Bucket that is in another namespace. `spec.chartRef.namespace` does the same for an OCIRepository or HelmChart.
- `spec.dependsOn[].namespace`, on both Kustomization and HelmRelease.
- `spec.eventSources[].namespace` on an Alert.
- `spec.resources[].namespace` on a Receiver.
- `spec.providerRef` on an Alert does not take a namespace. The Provider must be in the Alert's namespace.

## Fields that never cross a namespace

References to Secrets and ConfigMaps are always in the namespace of the object that uses them. This covers `spec.decryption.secretRef`, `spec.kubeConfig.secretRef`, `spec.postBuild.substituteFrom`, a HelmRelease `spec.valuesFrom`, and `secretRef` on a source or a Provider. This is on purpose: it keeps one tenant from reading another tenant's Secret by name.

If a Secret must be used in two namespaces, create it in both. Tools exist that copy a Secret between namespaces, but the copy is then a second place to keep correct.

## What the flag changes

The flag `--no-cross-namespace-refs=true`, set on the controllers, makes a reference to another namespace an error for the fields in the first list. The object reports the refusal in its status and does not reconcile. It is a platform setting, set on kustomize-controller, helm-controller and notification-controller.

The flag does not stop a Kustomization from applying objects into other namespaces. That is stopped by impersonation with a ServiceAccount whose rights are limited to the tenant namespace.

## When a cross-namespace reference is the right choice

Inside the platform team's own namespaces, it saves requests. One GitRepository for the fleet repository in `flux-system` can be used by Kustomizations for infrastructure and for monitoring. Between a platform and a tenant, it usually is not right, because the tenant then reads a repository the platform owns, and the platform cannot see who reads it.

## Check what a cluster has

```sh
kubectl get kustomizations -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" -> "}{.spec.sourceRef.namespace}{"\n"}{end}'
```

Lines where the namespace after the arrow differs from the one before it are cross-namespace references. List them before you turn the flag on, and move each one to a source in its own namespace, or accept it for platform objects and keep the flag off.

## Common pitfalls

> [!WARNING]
> - **Expecting to reference a Secret in another namespace.** It is not allowed, with or without the flag.
> - **Turning the flag on without listing existing references.** Objects that use them stop reconciling.
> - **Believing the flag restricts what is applied.** It restricts references. Impersonation restricts what is applied.
> - **Putting a Provider in another namespace.** An Alert finds its Provider in its own namespace only.
