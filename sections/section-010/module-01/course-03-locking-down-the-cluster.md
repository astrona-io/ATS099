# Locking Down The Cluster For Tenants

Impersonation protects the cluster only when it is used. A tenant who writes a Flux `Kustomization` without `serviceAccountName` gets kustomize-controller's own rights, which are `cluster-admin`. A tenant who points a `Kustomization` at a source in another namespace can read files that are not theirs. This part closes those holes with a few controller flags, the **lockdown**, added through Git. It also shows the one change the lockdown forces on the platform's own objects.

## The three holes and their flags

Each hole has its own flag. A **flag** here is a command-line argument of a Flux controller, set on its Deployment. The Flux documentation gives one set of flags for multi-tenancy, and they work together:

| Flag | Controllers | What it closes |
| --- | --- | --- |
| `--default-service-account=default` | kustomize-controller, helm-controller | An object without `spec.serviceAccountName` impersonates the ServiceAccount `default` in its own namespace, which has no rights, instead of using the controller's `cluster-admin` |
| `--no-cross-namespace-refs=true` | kustomize-, helm-, notification-, image-reflector- and image-automation-controller | An object may only reference sources and other objects in its own namespace, so a tenant cannot read the platform's `GitRepository` |
| `--no-remote-bases=true` | kustomize-controller | A Kustomize file `kustomization.yaml` may not pull bases from a remote URL, so every file Flux applies comes from a Flux source |

The default ServiceAccount rule has a side effect on the platform itself. The `flux-system`, `podinfo` and `tenants` Kustomizations live in `flux-system`. Once the flag is on, any of them without `serviceAccountName` runs as `flux-system/default` and loses every right. The documented lockdown therefore also sets `serviceAccountName: kustomize-controller` on the `flux-system` Kustomization, and every other platform `Kustomization` must name it too.

## Add the lockdown in Git

The controllers' Deployments come from `clusters/kind/flux-system/gotk-components.yaml`, which `flux bootstrap` writes and rewrites on every upgrade. Do not edit that file. Change the Kustomize file next to it, `clusters/kind/flux-system/kustomization.yaml`, which bootstrap leaves alone after the first run, and add **patches**. A patch is a change that Kustomize applies to the objects it builds, selected by kind and name. Pull first, then replace the content of `fleet/clusters/kind/flux-system/kustomization.yaml` with this:

<!-- astrona:playground:renew -->

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
        value: --no-cross-namespace-refs=true
    target:
      kind: Deployment
      name: "(kustomize-controller|helm-controller|notification-controller|image-reflector-controller|image-automation-controller)"
  - patch: |
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --no-remote-bases=true
    target:
      kind: Deployment
      name: "kustomize-controller"
  - patch: |
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --default-service-account=default
    target:
      kind: Deployment
      name: "(kustomize-controller|helm-controller)"
  - patch: |
      - op: add
        path: /spec/serviceAccountName
        value: kustomize-controller
    target:
      kind: Kustomization
      name: "flux-system"
```

Each patch is a JSON patch that adds one argument at the end of the first container's `args` list. The target names are regular expressions, so one patch covers several controllers. The image controllers are not installed in the playground; a target that matches nothing is simply skipped.

The playground's `podinfo` Kustomization has no `serviceAccountName` yet. Add the line `serviceAccountName: kustomize-controller` under `spec:` in `fleet/clusters/kind/podinfo.yaml`, in the same commit. The `tenants` Kustomization already names it. Commit, push and reconcile:

```sh
cd fleet
git add clusters/kind/flux-system/kustomization.yaml clusters/kind/podinfo.yaml
git commit -m "Lock Flux down for tenants"
git push
flux reconcile kustomization flux-system --with-source
```

The `flux-system` Kustomization applies the patched Deployments, and Kubernetes restarts kustomize-controller, helm-controller and notification-controller with the new arguments. Check that the flags are live:

```sh
kubectl -n flux-system get deployment kustomize-controller \
  -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}'
flux get kustomizations -A
```

The argument list ends with the three flags. After the restart, `flux get` shows every Kustomization `Ready` again, including `podinfo`. If `podinfo` shows a "forbidden" message for the ServiceAccount `flux-system:default`, its `serviceAccountName` line is missing or misspelled.

## See the lockdown work

Try the first hole on purpose: a tenant Flux `Kustomization` that does not name a ServiceAccount. Save this as `kustomization-team-a-noaccount.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: team-a-noaccount
  namespace: team-a
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: team-a
  path: ./app
  targetNamespace: team-a
  prune: false
```

Apply it, check it, and remove it:

```sh
kubectl apply -f kustomization-team-a-noaccount.yaml
flux get kustomization team-a-noaccount -n team-a
kubectl delete -f kustomization-team-a-noaccount.yaml
```

`flux get` shows `Ready` `False`, and the message names the ServiceAccount `team-a:default` as the account that was refused. Before the lockdown, the same object would have applied as `cluster-admin`. With the flag, forgetting the field fails safe.

You can now lock the controllers down through Git, keep the platform's own objects working under the lockdown, and show that a tenant object without a ServiceAccount is refused. The question left for the lab is doing all of it at once, on a fresh cluster.

## Common pitfalls

> [!WARNING]
> - **Editing `gotk-components.yaml`.** `flux bootstrap` rewrites it on every upgrade, and your change disappears. Patch it from `clusters/kind/flux-system/kustomization.yaml`.
> - **Forgetting the platform's own Kustomizations.** Under `--default-service-account=default`, every Flux `Kustomization` in `flux-system` without `serviceAccountName: kustomize-controller` stops working.
> - **Setting the flags with `kubectl edit`.** The next reconcile of `flux-system` puts the Deployment back to what Git says. Change Git.
> - **Turning the lockdown off to make a tenant work.** A tenant that is refused needs its own ServiceAccount and RoleBinding fixed, not more rights for the controller.

## Your mission: Onboard A Locked-Down Tenant

You can now lock Flux down for tenants and onboard a tenant that Flux applies with the tenant's own rights. The graded lab gives you a fresh cluster where Flux runs without a lockdown and `team-a` is not onboarded, and asks you to do both through Git, keep the platform's `podinfo` running, and leave `team-a` unable to create cluster-wide objects.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-099-playground-010-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS099.git -c sections/section-010/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-099-lab-010-01
astrona start ats-099-playground-010-01
```
