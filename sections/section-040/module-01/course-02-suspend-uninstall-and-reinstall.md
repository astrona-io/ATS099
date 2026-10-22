# Suspend, Uninstall And Reinstall Flux

The fastest way to lose trust in GitOps is a recovery that deletes what it was meant to protect. This part shows that removing Flux and bringing it back leaves the running workloads alone, and how to prove it. It starts with the gentler tool, pausing Flux for maintenance, because a pause that is never ended is a common cause of a cluster that silently stops following Git.

## Pause Flux for maintenance

**Suspending** a Flux object stops its reconciliation: the controller leaves the object alone until it is resumed, and the cluster stops following Git for that object. During a maintenance window, for example a manual database migration, you can suspend every Flux `Kustomization` in a namespace at once:

<!-- astrona:playground:renew -->

```sh
flux suspend kustomization --all
flux get kustomizations
```

Both `flux-system` and `podinfo` show `SUSPENDED` `True`. Push a change to Git now and nothing happens, which is the point of the window. End it the same way:

```sh
flux resume kustomization --all
flux get kustomizations
```

`flux resume` also triggers a reconcile, so both objects catch up at once. There is a second way to suspend: set `suspend: true` in the object's file in Git. That is useful when a pause must be reviewed like any other change. The cost is that it lasts until someone removes it from Git, and `flux resume` cannot override it for long, because the next reconcile of `flux-system` applies `suspend: true` again.

## Remove Flux

Removing Flux is a real recovery step, for example when the Flux installation is broken beyond repair, or when you move a cluster to a new repository. Record the UID of the podinfo Deployment before you start, so you can prove later that it survived:

```sh
kubectl -n podinfo get deployment podinfo -o jsonpath='{.metadata.uid}{"\n"}'
```

Now uninstall Flux. `flux uninstall` removes the Flux controllers, their custom resource definitions (CRDs) and the Flux objects. It first removes the **finalizers** from the Flux objects, the markers that would make Kubernetes wait for a controller before deleting them, so that no `Kustomization` gets the chance to prune what it applied. `--keep-namespace` keeps the `flux-system` namespace, and so the Secrets in it:

```sh
flux uninstall --keep-namespace --silent
kubectl get crds | grep -c toolkit.fluxcd.io
kubectl -n podinfo get deployment podinfo
```

No Flux CRD is left, so `grep -c` counts zero. podinfo still runs. Nothing manages it now: a change in Git would not reach it, and a manual change would stay.

## Bring Flux back

Reinstall Flux the way it was installed: `flux bootstrap` against the same repository, branch and path. Make sure the port-forward to Gitea is running in your second terminal:

```sh
flux bootstrap git \
  --url=http://gitea.localtest.me:3000/gitops/fleet.git \
  --branch=main \
  --path=clusters/kind \
  --username=gitops \
  --password=gitops-password \
  --token-auth=true \
  --allow-insecure-http=true
```

Bootstrap installs the controllers from `clusters/kind/flux-system/gotk-components.yaml`, which is already in Git, applies the sync objects, and waits for the `flux-system` Kustomization. Because the repository already holds the bootstrap files, it commits nothing new. A real Git server uses HTTPS or SSH; plain HTTP is for this playground only.

Then prove that podinfo was adopted, not recreated:

```sh
flux get kustomizations
kubectl -n podinfo get deployment podinfo -o jsonpath='{.metadata.uid}{"\n"}'
kubectl -n flux-system get kustomization podinfo -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}'
```

Both Kustomizations are `Ready`. The UID is the same one you recorded, so the Deployment was never deleted. The inventory lists `podinfo_podinfo_apps_Deployment`: kustomize-controller applied the files from Git with server-side apply, found the objects already there, and took them back under its management.

You can now pause Flux safely, remove it without touching the workloads, and bring it back with proof that nothing was recreated. The question still open is the harder case, where more than Flux is gone.

## Common pitfalls

> [!WARNING]
> - **Forgetting a `suspend: true` in Git.** It outlives the maintenance window, and `flux resume` only lasts until the next `flux-system` reconcile. Remove it in Git.
> - **Deleting a Flux `Kustomization` instead of uninstalling.** Deleting it with `kubectl delete` runs its finalizer, and with `prune: true` it deletes everything it applied. `flux uninstall` removes the finalizers first.
> - **Bootstrapping with a different path or branch.** Flux then applies a different folder, and prunes nothing it does not know, but the cluster stops following the old one.
> - **Trusting "it looks the same".** Compare the UID; a recreated object looks the same and has a new one.

## Your mission: Reinstall Flux Without Touching The Workloads

You can now remove and reinstall Flux and prove the workloads were adopted. The graded lab gives you a cluster where Flux was uninstalled with its namespace kept and podinfo still runs, and asks you to bring Flux back from `gitops/fleet` so that it manages the same podinfo Deployment again.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-099-playground-040-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS099.git -c sections/section-040/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-099-lab-040-01
astrona start ats-099-playground-040-01
```
