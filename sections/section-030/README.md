# Section 030: Cross-Namespace References And Remote Clusters

So far every Flux object read a source in its own namespace and applied to its own cluster. Real platforms stretch both edges. A team may want to reuse a source the platform already fetches, and a platform team often runs Flux on one management cluster that delivers to many others.

This section covers both edges. A Flux object can reference a source in another namespace, unless the platform forbids it. A Flux `Kustomization` can apply to another cluster through a **kubeconfig** stored in a Secret, with an account on that cluster that holds only the rights it needs. Cluster API, which creates clusters from Kubernetes objects, writes exactly such a Secret for every cluster it builds.

**Topic covered:** Remote clusters

## What you will learn

- Cross-namespace references with `sourceRef.namespace`, and what `--no-cross-namespace-refs` changes.
- What a kubeconfig holds: a cluster address, a certificate authority, a user with a token, and a context.
- Building a kubeconfig for a ServiceAccount that may change one namespace only, and storing it under the key `value`.
- `spec.kubeConfig.secretRef` on a Flux `Kustomization`, and how to read whether it applied through the kubeconfig.
- How Cluster API's `<cluster>-kubeconfig` Secrets let one Flux installation deliver to a fleet of clusters.
- Reading a failing remote apply stage by stage, and which Flux references never cross a namespace.
- Which key of a kubeconfig Secret Flux reads, what `--insecure-kubeconfig-exec` and `--insecure-kubeconfig-tls` allow, and how to rotate a token with no gap.
- The rights a remote account needs, and what health checks, pruning and deletion do on the other cluster.
- One Flux per cluster compared with a management cluster, environments as folders and overlays, and promotion with `dependsOn`.

## The learning path

The section has three modules. Each has a landing page, short parts, a graded lab right after the part it tests, and a summary. Each module has its own playground, a cluster where Flux runs and a ServiceAccount `flux-deployer` stands in for an account on another cluster. The landing page of a module starts its playground for you.

### 1. Deliver To Other Namespaces And Clusters

1. Cross-Namespace References
2. Applying To Another Cluster With kubeConfig, followed by the lab **Deliver podinfo Through A Scoped kubeconfig**
3. Cluster API And Fleets Of Clusters
4. Reading A Failing Remote Apply
5. Cross-Namespace Rules For Other Kinds
6. Summary

### 2. Kubeconfig Secrets, Tokens And Remote Rights

1. How Flux Reads A Kubeconfig Secret
2. Token Lifetime And Rotation, followed by the lab **Rotate The Token In A kubeconfig Secret**
3. Scoping The Remote Account
4. Remote Health Checks And Pruning
5. Summary

### 3. Fleets, Environments And Promotion

1. Push And Pull Delivery
2. Environments As Folders And Overlays
3. Promotion Order With dependsOn And Health, followed by the lab **Promote Staging To Production**
4. Operating A Fleet
5. Summary

## Section capstone: Repair A Broken Remote Cluster Connection

The capstone is one graded scenario. A Flux `Kustomization` is meant to deliver podinfo to the staging cluster through a kubeconfig, and it has never worked. There are three independent faults between the Flux object and the remote API server. You must find them from the object's status, fix them without giving the remote account more than it needs, and prove that every podinfo object was applied through the kubeconfig. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS099.git -c sections/section-030/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-099-capstone-030
```
