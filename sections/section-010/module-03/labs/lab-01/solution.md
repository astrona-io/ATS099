# Solution: Reject Flux Kustomizations Without A ServiceAccount

Work the task yourself first. Running `astrona submit -c sections/section-010/module-03/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the policy and the binding exist with the right content, the policy rejects a `Kustomization` without a ServiceAccount in `team-a` and accepts one with it, the files and the `policies` Kustomization come from Git, and the platform and the tenant stay `Ready`.

## Step 1: Clone the platform repository

Start the port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Use the user `gitops` and the password `gitops-password`. If `git` cannot resolve `gitea.localtest.me`, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

## Step 2: Write the policy and the binding

Save this as `infrastructure/policies/flux-service-account.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: flux-tenant-service-account
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: ["kustomize.toolkit.fluxcd.io"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["kustomizations"]
  validations:
    - expression: "has(object.spec.serviceAccountName) && object.spec.serviceAccountName != ''"
      message: "A Flux Kustomization in a tenant namespace must set spec.serviceAccountName."
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: flux-tenant-service-account
spec:
  policyName: flux-tenant-service-account
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchExpressions:
        - key: toolkit.fluxcd.io/tenant
          operator: Exists
```

## Step 3: Apply the folder with a Flux Kustomization

Save this as `clusters/kind/policies.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: policies
  namespace: flux-system
spec:
  interval: 5m
  serviceAccountName: kustomize-controller
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./infrastructure/policies
  prune: true
```

The folder has no `kustomization.yaml`, so Flux builds one from the YAML files in it.

## Step 4: Commit, push and reconcile

```sh
git add infrastructure/policies clusters/kind/policies.yaml
git commit -m "Reject tenant Kustomizations without a ServiceAccount"
git push
flux reconcile kustomization flux-system --with-source
flux reconcile kustomization policies --with-source
```

Run `astrona submit -c sections/section-010/module-03/labs/lab-01` now.

## Step 5: Test the policy yourself

Save this as `no-sa.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: no-sa
  namespace: team-a
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: team-a
  path: ./app
  targetNamespace: team-a
```

```sh
kubectl apply --dry-run=server -f no-sa.yaml
```

The command fails with your message. Add `serviceAccountName: team-a` under `spec`, run it again, and it succeeds. The policy needs a few seconds to become active after it is created.

## If something is wrong

- **The dry run succeeds without a ServiceAccount.** The binding has no effect yet, or it does not match. Check `kubectl get validatingadmissionpolicybinding flux-tenant-service-account -o yaml` and the namespace label.
- **The `policies` Kustomization is `False`.** Run `flux get kustomization policies` and read the message. A YAML error in the file is the usual cause.
- **The cluster rejects the policy.** ValidatingAdmissionPolicy at `v1` needs Kubernetes 1.30 or later. Check `kubectl version`.
