# Solution: Tune kustomize-controller Through Git

Work the task yourself first. Running `astrona submit -c sections/section-040/module-03/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the live arguments, the live memory limit, and that both come from a patch in Git.

## Step 1: Clone the repository and read the file

Start the port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
cat clusters/kind/flux-system/kustomization.yaml
```

The user is `gitops` and the password is `gitops-password`. The file lists `gotk-components.yaml` and `gotk-sync.yaml` under `resources`.

## Step 2: Add the patches

Append this to `clusters/kind/flux-system/kustomization.yaml`:

```yaml
patches:
  - patch: |
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --concurrent=8
    target:
      kind: Deployment
      name: kustomize-controller
  - patch: |
      - op: add
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: 2Gi
    target:
      kind: Deployment
      name: kustomize-controller
```

## Step 3: Check the build on your machine

```sh
kubectl kustomize clusters/kind/flux-system | grep -n -E 'concurrent|memory'
```

The output must show `--concurrent=8` and `memory: 2Gi` for `kustomize-controller`. A patch with a wrong path is an error here, before it reaches the cluster.

## Step 4: Commit, push and reconcile

```sh
git add clusters/kind/flux-system/kustomization.yaml
git commit -m "Tune kustomize-controller: concurrency 8, memory limit 2Gi"
git push
flux reconcile kustomization flux-system --with-source
kubectl -n flux-system rollout status deployment/kustomize-controller
```

The controller restarts because its Deployment changed. The reconcile command can report an error while the pod is replaced; wait for the rollout and run `flux get kustomization flux-system`.

## Step 5: Check the live values

```sh
kubectl -n flux-system get deployment kustomize-controller \
  -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}{.spec.template.spec.containers[0].resources.limits.memory}{"\n"}'
```

## Step 6: Submit

```sh
astrona submit -c sections/section-040/module-03/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `kubectl edit deployment kustomize-controller` | The Kustomization `flux-system` sets it back at its next reconcile |
| Edit `gotk-components.yaml` | The next `flux bootstrap` writes the file again and the change is lost |
| Add `--concurrent=8` to every controller | Only `kustomize-controller` has the problem, and the check for the others fails |
| Add a second `--concurrent` argument by hand | The argument appears twice, and the check for exactly one fails |
