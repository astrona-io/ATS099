# Network Isolation And Tenant Secrets

Two more things cross tenant borders if nobody stops them: network traffic and secret data. By default every pod in a cluster can send traffic to every other pod, and a Secret in Git is readable by everyone with access to the repository. This part adds a default-deny NetworkPolicy to the tenant namespace and gives each tenant its own SOPS key, so one tenant cannot decrypt another tenant's secrets.

## NetworkPolicy: deny first, allow what is needed

A **NetworkPolicy** is a Kubernetes object that selects pods and lists the traffic allowed to or from them. It only works when the cluster's network plugin enforces it. A cluster whose plugin ignores NetworkPolicy accepts the object and enforces nothing, so check what your cluster uses. Calico and Cilium enforce it. Check the documentation of the plugin in your own cluster before you rely on it.

A policy with an empty `podSelector` selects every pod in the namespace. When it lists the policy type `Ingress` and no `ingress` rules, it blocks all incoming traffic to those pods:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: team-a
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

Next, allow what must work. This policy lets pods of the same namespace reach each other:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: team-a
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector: {}
```

The empty `podSelector` under `from` matches every pod of the policy's own namespace. Both policies go in `tenants/team-a` of the platform repository, so the platform controls them. The tenant ServiceAccount must not be allowed to delete them, which again depends on its role.

## Flux traffic and the tenant namespace

Flux controllers run in `flux-system` and connect to the Kubernetes API server and to Git servers. They do not connect to tenant pods, so a deny rule on ingress in the tenant namespace does not stop them. The tenant's own pods are affected: a pod in another namespace that called a tenant Service is now blocked until an allow rule names it. Read the policies back and test the traffic you expect:

```sh
kubectl -n team-a get networkpolicy
kubectl -n team-a describe networkpolicy default-deny-ingress
```

## Secrets: one decryption key per tenant

Secrets must not sit in Git as plain text. Flux can decrypt Secrets that were encrypted with **SOPS**, a tool that encrypts the values of a YAML file with a key such as an age key. kustomize-controller decrypts them when it applies the `Kustomization`, using a key it reads from a Secret.

The field is `spec.decryption` of the Flux `Kustomization`. It names the provider and the Secret that holds the key. This tenant `Kustomization` uses its own key:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: team-a
  namespace: team-a
spec:
  interval: 5m
  serviceAccountName: team-a
  sourceRef:
    kind: GitRepository
    name: team-a
  path: ./app
  targetNamespace: team-a
  prune: true
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

The Secret `sops-age` must be in the namespace `team-a`, because the Flux object looks it up in its own namespace. It holds the private age key in a data key that ends in `.agekey`. Create one age key per tenant on the machine of the platform administrator:

```sh
age-keygen -o team-a.agekey
kubectl -n team-a create secret generic sops-age --from-file=team-a.agekey=team-a.agekey
```

`age-keygen` prints the public key to the terminal. The tenant uses that public key to encrypt its Secrets with `sops --encrypt --age <public-key>`. The tenant cannot read the private key through Flux, and a different tenant's key cannot decrypt these files.

## Why one key per tenant matters

If all tenants shared one decryption key, any tenant whose `Kustomization` is allowed to reference that Secret could read every other tenant's secrets by committing a manifest that prints them. With one key per tenant and `--no-cross-namespace-refs=true`, a `Kustomization` can only use the key in its own namespace. Keep the private key out of Git, and keep a copy in a safe place, because Flux cannot decrypt without it after a cluster is rebuilt.

## Common pitfalls

> [!WARNING]
> - **Writing a NetworkPolicy for a plugin that does not enforce it.** The object is accepted and does nothing.
> - **Committing the private age key.** Only the public key and the encrypted files belong in Git.
> - **Sharing one key across tenants.** Any tenant could then decrypt the others' files.
> - **Creating `sops-age` in the wrong namespace.** The `Kustomization` looks in its own namespace only.
