# Admission Policy For Flux Objects

Controller flags protect the cluster from tenants who skip impersonation, but they only act when a controller reconciles an object. An **admission policy** acts earlier: the Kubernetes API server runs it when someone creates or updates an object, and it can reject the request before the object is stored. This part writes a policy that rejects a tenant's Flux `Kustomization` that does not name a ServiceAccount.

## Why add a policy when the flags exist

The flag `--default-service-account=default` makes an object without a ServiceAccount run as an account with no rights. The tenant's object is stored, then fails at the next reconciliation. A policy rejects the object when it is created, so the tenant sees the error at once, in `kubectl` or in the output of the platform's own Flux apply, and the broken object never exists.

A policy can also enforce rules that the flags cannot: every tenant `Kustomization` must have `prune: true`, or must use a `sourceRef` in its own namespace, or must set a `targetNamespace`.

## ValidatingAdmissionPolicy

**ValidatingAdmissionPolicy** is a Kubernetes API in the group `admissionregistration.k8s.io/v1` that runs a rule written in the Common Expression Language (CEL) inside the API server. It is generally available from Kubernetes 1.30. It needs no extra webhook or controller. Two objects work together: the policy defines what to check, and a **ValidatingAdmissionPolicyBinding** says where it applies and what to do on a failure.

Save the policy as `infrastructure/policies/flux-service-account.yaml`:

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
```

`matchConstraints` selects the requests: creating or updating Flux `Kustomization` objects of the group `kustomize.toolkit.fluxcd.io`. Each entry under `validations` has a CEL `expression` that must be true. The `message` is what the user sees on a rejection. In `expression`, `object` is the object in the request.

## The binding

A policy does nothing until a binding connects it. The binding restricts the policy to tenant namespaces by label, so the platform's own `Kustomization` objects in `flux-system` are not affected:

```yaml
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

`validationActions: ["Deny"]` makes a failure reject the request. The value `Warn` returns a warning but allows the request, and `Audit` only records it. The selector uses the label `toolkit.fluxcd.io/tenant`, which `flux create tenant` puts on every tenant namespace.

## Apply it from Git and test it

Put both objects in a folder the platform applies, commit, push and reconcile:

```sh
git add infrastructure/policies
git commit -m "Reject tenant Kustomizations without a ServiceAccount"
git push
flux reconcile kustomization flux-system --with-source
```

The platform repository also needs a Flux `Kustomization` in `flux-system`, for example `clusters/kind/policies.yaml`, with `path: ./infrastructure/policies`, `prune: true` and `serviceAccountName: kustomize-controller`. Then test with a server-side dry run, which sends the request through admission without storing the object. Save a `Kustomization` without `serviceAccountName` as `no-sa.yaml` with the namespace `team-a` and run:

```sh
kubectl apply --dry-run=server -f no-sa.yaml
```

The command fails with an error that contains your `message`. Add `serviceAccountName: team-a` to the file and run the command again. This time it succeeds.

## What the policy does not stop

A policy checks that the field is set. It does not check that the value is the right account, so a tenant could write `serviceAccountName: kustomize-controller`. That ServiceAccount does not exist in the tenant namespace, so the apply would fail, but a tenant namespace could contain an account with more rights than intended. Add a second rule that compares the value with the namespace, for example `object.spec.serviceAccountName == object.metadata.namespace` when the naming convention allows it.

## Common pitfalls

> [!WARNING]
> - **Writing a policy without a binding.** Nothing is enforced.
> - **Binding to all namespaces.** The platform's own `Kustomization` objects fail unless they match the rule.
> - **Using `failurePolicy: Fail` with a mistake in the expression.** Requests for the matched objects are rejected until you fix it.
> - **Running on Kubernetes before 1.30.** The v1 API is not available. Check `kubectl version`.
