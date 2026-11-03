# Quotas And Limits Per Tenant

A tenant that cannot create a ClusterRole can still harm its neighbours. A Deployment with a thousand replicas, or one pod that asks for all the memory of a node, slows down every other tenant. Kubernetes limits this with two namespaced objects, ResourceQuota and LimitRange. The platform team puts both in the tenant's folder of the platform repository, so the tenant gets the limits together with the namespace.

## ResourceQuota

A **ResourceQuota** sets a hard cap on the total amount of resources in one namespace. It can count objects, such as pods, Services and Secrets, and it can add up compute requests and limits, such as `requests.cpu` and `limits.memory`. When a request would go over the cap, the API server refuses to create the object.

Save this as `tenants/team-a/quota.yaml` in the platform repository:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a-quota
  namespace: team-a
spec:
  hard:
    pods: "10"
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "4"
    limits.memory: 4Gi
    services: "5"
```

The quota counts every pod in `team-a`, including pods that Flux itself creates for the tenant. Quota on `requests.cpu` and `limits.cpu` has a side effect: every pod must then declare those values, or the API server rejects it. The next object solves that.

## LimitRange

A **LimitRange** sets default requests and limits for containers that name none, and it sets a minimum and maximum per container. With a default in place, the tenant's pods are accepted by the quota even when the tenant's manifests do not name resources:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: team-a-defaults
  namespace: team-a
spec:
  limits:
    - type: Container
      default:
        cpu: 500m
        memory: 256Mi
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      max:
        cpu: "1"
        memory: 1Gi
```

The `default` block is the limit a container gets when it sets none, and `defaultRequest` is the request. `max` rejects any container that asks for more than one CPU or 1 GiB of memory. The LimitRange applies to pods created after it exists. It does not change pods that already run.

## Put both objects in Git and apply them

Add `quota.yaml` and `limits.yaml` to the folder `tenants/team-a` of the platform repository. The platform `tenants` Kustomization applies the whole folder, so no new Flux object is needed. Commit and push, then make Flux apply it now:

```sh
git add tenants/team-a
git commit -m "Add a quota and default limits for team-a"
git push
flux reconcile kustomization tenants --with-source
```

Then read the result back from the cluster:

```sh
kubectl -n team-a describe resourcequota team-a-quota
kubectl -n team-a get limitrange team-a-defaults
```

`describe` prints a table with `Used` and `Hard` for each resource. The tenant's podinfo already counts against `pods`, `requests.cpu` and the rest. If the LimitRange was created after the podinfo pods, the pods keep their old values until they restart.

## Quota only counts for a tenant who cannot remove it

A quota in the namespace protects the cluster only if the tenant's ServiceAccount cannot delete it. With a RoleBinding to `cluster-admin`, the tenant could delete `team-a-quota` from its own repository, or by a Flux object that applies a delete. Bind the tenant to the ClusterRole `admin`, which allows reading a quota but not changing it, or to a custom Role that omits `resourcequotas` and `limitranges`.

Check it the same way as for any right:

```sh
kubectl auth can-i delete resourcequotas -n team-a --as=system:serviceaccount:team-a:team-a
```

The answer must be `no`. If it is `yes`, the tenant's role is still too wide.

## What happens when the quota is full

When a Deployment asks for more pods than the quota allows, the Deployment is created, but its ReplicaSet cannot create the extra pods. The Flux `Kustomization` then reports `Ready` `True` when it has no health checks, because Flux applied the objects. It reports `False` with a timeout when `spec.wait: true` or a health check waits for the Deployment. Look at the ReplicaSet events to see the quota message:

```sh
kubectl -n team-a get events --sort-by=.lastTimestamp
```

The event text says that the pod was forbidden because it exceeded quota, and lists the used and the requested amounts.

## Common pitfalls

> [!WARNING]
> - **Setting a compute quota without a LimitRange.** Pods that declare no requests are rejected and the tenant cannot tell why.
> - **Expecting the LimitRange to change running pods.** It applies at creation time only.
> - **Leaving the tenant able to delete the quota.** Check `kubectl auth can-i delete resourcequotas` as the tenant account.
> - **Reading Flux `Ready` as "all replicas run".** Without `wait: true` Flux only reports that the objects were applied.
