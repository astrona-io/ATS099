# Impersonation In HelmReleases And Other Objects

A tenant does not only ship plain Kubernetes files. Many teams install applications as Helm charts, and Flux applies those through a second controller. If only one controller impersonates the tenant, the other one is a way around the rule. This part shows which Flux objects can impersonate a ServiceAccount, which cannot, and how to close the gap for the ones that can.

## Which controllers act on the cluster

Flux has several controllers, and only some of them write to the cluster on behalf of a tenant. **kustomize-controller** applies the files of a Flux `Kustomization`. **helm-controller** installs and upgrades the charts of a `HelmRelease`. Both send write requests to the Kubernetes API server, so both need a ServiceAccount that Kubernetes can check.

**source-controller** only downloads artifacts into its own storage and never writes tenant objects to the cluster. **notification-controller** sends events to outside systems. It creates no workloads. These two controllers therefore do not need impersonation for the tenant's workloads, although their objects still obey the namespace rules you set with the lockdown flags.

## Impersonation in a HelmRelease

A `HelmRelease` has the same field as a `Kustomization`: `spec.serviceAccountName`. helm-controller then runs the install and upgrade actions as that ServiceAccount, looked up in the namespace of the `HelmRelease`. Here is a tenant `HelmRelease` that installs the podinfo chart from a Helm repository in the tenant namespace:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: podinfo
  namespace: team-a
spec:
  interval: 1h
  url: https://stefanprodan.github.io/podinfo
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: podinfo
  namespace: team-a
spec:
  interval: 10m
  serviceAccountName: team-a
  chart:
    spec:
      chart: podinfo
      version: "6.x"
      sourceRef:
        kind: HelmRepository
        name: podinfo
```

With this object helm-controller renders the chart, then creates each resource as `team-a/team-a`. A chart that contains a ClusterRole fails the install, and the `HelmRelease` shows `Ready` `False` with a "forbidden" message from the API server. The `HelmRelease` is created in the namespace `team-a`, so the release also lives there. Use `spec.targetNamespace` only when the objects must go to another namespace that the ServiceAccount may write to.

## The default ServiceAccount flag covers both controllers

A tenant can still leave `serviceAccountName` out. The controller flag `--default-service-account` fixes this. When it is set to `default`, a Flux `Kustomization` or `HelmRelease` that names no ServiceAccount acts as the account `default` in its own namespace. That account has no rights unless somebody binds a role to it, so the apply fails instead of running with the controller's own rights.

The flag exists on both kustomize-controller and helm-controller, and you must set it on both. Setting it on only one leaves the other controller running tenant objects with its cluster-admin account. This is the single most common gap in a half-finished lockdown.

## Check the flags on the running controllers

You can read the arguments of each controller from its Deployment. This shows what is really running, not what you intended:

```sh
kubectl -n flux-system get deployment kustomize-controller \
  -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}'
kubectl -n flux-system get deployment helm-controller \
  -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}'
```

Each command prints a list of arguments. Look for `--default-service-account=default` in both lists. For kustomize-controller you also expect `--no-cross-namespace-refs=true` and `--no-remote-bases=true`. helm-controller takes `--no-cross-namespace-refs=true` as well.

## What the ServiceAccount of a HelmRelease needs

helm-controller stores the state of each release in a Helm release Secret in the namespace where the release lives. The tenant ServiceAccount must therefore be allowed to create and update Secrets there. A RoleBinding to the ClusterRole `admin` or `cluster-admin` in the tenant namespace includes that right. A narrower Role must list `secrets` among the resources, or the install fails on the first release Secret.

Helm hooks and tests create extra objects such as Jobs and Pods. They also run as the same ServiceAccount, so the Role needs those verbs too. A failed install caused by missing rights shows the exact verb and resource in the status message, and you add that one rule to the Role.

## Common pitfalls

> [!WARNING]
> - **Setting `--default-service-account` on kustomize-controller only.** `HelmRelease` objects without a ServiceAccount then still run as helm-controller's own account.
> - **Assuming source-controller needs a tenant account.** It does not. It writes only to its own artifact storage.
> - **Giving the tenant a Role without `secrets`.** helm-controller cannot store the release and every install fails.
> - **Putting the `HelmRepository` in another namespace.** With `--no-cross-namespace-refs=true` the chart's `sourceRef` must be in the namespace of the `HelmRelease`.
