# Push And Pull Delivery

There are two ways to get a change onto a cluster. In push delivery, something outside the cluster runs `kubectl apply` or `helm upgrade` with a credential for the cluster. In pull delivery, something inside the cluster fetches the desired state and applies it. Flux is a pull tool. With `spec.kubeConfig` it can also apply to another cluster, which gives two layouts.

## One Flux in every cluster

Each cluster runs its own Flux, bootstrapped against the same or a different repository path. This is often called standalone mode.

- The credential for the cluster never leaves it. Flux needs read access to Git, and that is all.
- A broken or unreachable management plane does not stop a cluster from converging.
- You maintain and upgrade Flux once per cluster.
- Each cluster needs its own access to Git, and its own Secrets for decryption.

## One Flux that serves many clusters

A management cluster runs Flux, and the Kustomizations of the other clusters use `spec.kubeConfig`. This is often called hub and spoke.

- One place to see the state of every delivery.
- One Flux to upgrade, and one place that holds credentials for all clusters.
- The management cluster becomes critical. If it is lost or compromised, the attacker holds the kubeconfig of every cluster, and a lost cluster stops all deliveries.
- The controllers must reach the API server of every cluster, which may be difficult across networks.

## How to choose

| Question | Points to one Flux per cluster | Points to a management cluster |
| --- | --- | --- |
| Can the management cluster reach every API server? | No | Yes |
| Is the number of clusters large and changing? | No | Yes, with Cluster API |
| Is the blast radius of a credential store acceptable? | No | Yes, with narrow accounts |
| Must a cluster work alone when disconnected? | Yes | No |

Many teams mix them. A management cluster delivers the platform add-ons to the others, and each cluster runs its own Flux for the applications.

## What stays the same

The Kustomization, the sources, the health checks and the pruning behave the same in both layouts. The only difference is where the controllers run and whose credential they use. A repository organized for one layout is easy to move to the other.

## Common pitfalls

> [!WARNING]
> - **Giving the management cluster `cluster-admin` on every cluster.** One compromise reaches all of them. Use narrow accounts.
> - **Assuming a push credential in CI is safer.** It is a stored admin credential outside the cluster, usually with fewer controls.
> - **Running Flux in a cluster and also applying with `kubectl` from CI.** Two writers fight over the same objects.
> - **Forgetting the network.** A health check on a cluster that the management cluster cannot reach fails.
