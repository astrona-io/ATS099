# Reading Events And Logs Of The Controllers

An alert reaches a channel and says that something failed. Somebody must then find out why. The details are in two places that every Flux operator should read without a search: the Kubernetes events that Flux records, and the logs of the controllers. This part shows the commands for both and how to tell which one answers a given question.

## Events

Each Flux controller records a Kubernetes event whenever it reconciles an object. The event has a type (`Normal` for success, `Warning` for failure), a reason, a message and the object it concerns. Kubernetes keeps events for a short time, about an hour by default, so read them soon after a failure. The command `flux events` lists them for Flux objects:

```sh
flux events -A
flux events --for Kustomization/podinfo -n flux-system
```

The first command lists events for all Flux objects in all namespaces, and the second limits the list to one object. Events carry the revision that was applied or attempted, which tells you which commit a failure belongs to.

## Controller logs

A controller logs more than it records as events. It logs every reconciliation, including retries and the reasons it chose not to act. The `flux logs` command reads the logs of the Flux controllers and filters them by object:

```sh
flux logs --level=error --all-namespaces
flux logs --kind=Kustomization --name=podinfo --namespace=flux-system --since=15m
```

The first command shows only errors from all controllers. The second shows what the controllers logged about one object in the last fifteen minutes. Each log line is JSON in the cluster, and `flux logs` prints it in a readable form.

You can read the same logs with `kubectl`, which also lets you follow a controller live:

```sh
kubectl -n flux-system logs deploy/kustomize-controller --tail=50
kubectl -n flux-system logs deploy/kustomize-controller -f
```

## Which source answers which question

Use events to find out what happened to one object, in order. Use controller logs to find out why a controller acted or did not act, and to see errors that have no event, such as a failed attempt to start. Use the object's status for the current state. The three agree when everything is healthy and differ when something is stuck, which is when you need them.

A common case: a Kustomization is `Ready` `False` with the message "dependency not ready". The status names the dependency. The events show nothing new, because the controller did not try to apply. The log shows the retry on each interval. Reading all three tells you the problem is upstream, in the dependency.

## Increase the detail when you need it

The controllers log at the info level by default. For a hard problem you can raise the level by adding the argument `--log-level=debug` to a controller. Change it through Git, with a patch in `clusters/<name>/flux-system/kustomization.yaml`, and remove it when you are done. Debug logs are large, and they can contain details of requests.

## Common pitfalls

> [!WARNING]
> - **Reading events an hour late.** They are gone. Forward them with an Alert so a copy exists.
> - **Reading only one controller.** A Kustomization failure may start in source-controller. Use `flux logs` without `--kind` first.
> - **Editing the controller Deployment by hand to set debug.** Flux restores it from Git. Patch it in Git.
> - **Leaving debug logging on.** It fills the logs and the disk.
