# Watching The Controllers

You tune with evidence. Flux gives you logs, events, status and metrics for that.

## Logs

```sh
flux logs --all-namespaces --level=error --since=1h
flux logs --kind=Kustomization --name=podinfo --namespace=flux-system
```

`flux logs` reads the controller logs and filters them by level, age, object kind and name. Use the first form for a general look and the second to follow one object.

## Status and events

```sh
flux get all -A
flux events --for Kustomization/podinfo
```

Every Flux object has a `Ready` condition and a message. A pattern of "context deadline exceeded" or timeouts across many objects points to a slow dependency or an overloaded controller. A pattern limited to one object points to that object.

## Resource use

```sh
kubectl -n flux-system top pods
```

shows CPU and memory per pod when the metrics server is installed. To see whether a pod was killed for memory, read the last state:

```sh
kubectl -n flux-system get pod -l app=kustomize-controller \
  -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}{"\n"}'
```

The value `OOMKilled` means the container used more memory than its limit. A growing restart count with that reason says to raise the limit, or to find what makes the controller use so much.

## Metrics

Each controller serves Prometheus metrics on port 8080 at `/metrics`. Useful ones are:

- `gotk_reconcile_duration_seconds`: how long reconciles take, by kind.
- `gotk_resource_info`: one series per Flux object with its labels, used to count objects and to alert on `ready` being `False`.
- `workqueue_depth`: how many objects wait for a worker. A depth that stays above zero means the controller cannot keep up.
- `controller_runtime_reconcile_total`: how many reconciles ran and with which result.

A way to look without a monitoring stack is to forward the port and read the text:

```sh
kubectl -n flux-system port-forward deploy/kustomize-controller 8080:8080
curl -s localhost:8080/metrics | grep workqueue_depth
```

## A tuning loop

1. Write down the symptom, such as reconciles that take longer than the interval.
2. Take a baseline: duration, queue depth, CPU and memory.
3. Change one thing in Git.
4. Wait for several intervals and take the numbers again.
5. Keep the change if the numbers improved, and revert it if not.

One change at a time keeps the result readable. Keep the baseline and the result in the commit message.

## Alert on the things that matter

At minimum, alert when an object has been not `Ready` for longer than a few intervals, when a controller restarts repeatedly, and when the work queue stays deep. The notification controller can send alerts for Flux events to a chat system or an issue tracker.

## Common pitfalls

> [!WARNING]
> - **Tuning without a baseline.** You cannot tell if it helped.
> - **Changing several things at once.** You do not know which one worked.
> - **Leaving debug logs on.** Logs grow and hide the signal.
> - **No alert on stuck objects.** The first sign is a user report.
