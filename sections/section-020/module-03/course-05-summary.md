# Summary

A cluster managed by Flux is healthy when the sources are fetched, the Kustomizations and HelmReleases are applied, and the applications they deploy run. This module showed how Flux reports each of those, and how to watch it over time.

## What you learned

Every Flux object has conditions. `Ready` says the last reconcile worked. `Reconciling` says Flux is working or retrying. `Stalled` says retrying cannot help until the spec changes. `Healthy` appears on a Kustomization with health checks and says the checked objects are ready, and `Ready` is only `True` when it is. `lastAppliedRevision` is the revision that runs, and `lastAttemptedRevision` is the one tried last. `flux get all -A --status-selector ready=false` lists everything that needs attention, and `kubectl wait --for=condition=Healthy` waits in scripts.

`spec.wait: true` waits for every applied object. `spec.healthChecks` waits for a chosen list and is ignored when `wait` is true. `spec.timeout` limits the wait and defaults to the interval. `spec.retryInterval` sets the delay of a retry after a failure and defaults to the interval, so set it short when the interval is long. A Kustomization with `dependsOn` starts only when the dependency is `Ready`, health checks included.

The controllers export `gotk_reconcile_duration_seconds` and controller-runtime counters on port `8080`, named `http-prom`. `gotk_resource_info` comes from kube-state-metrics. A PodMonitor collects the controller metrics. Useful rules cover objects that are not ready, objects that stay suspended, and a controller that stopped reconciling. Prometheus rules still fire when notification-controller is down, so use alerts and rules together.

Daily operation uses `flux check`, `flux get all -A --status-selector`, `flux tree`, `flux trace`, `flux events`, `flux logs`, `flux stats` and `flux diff`.

The key facts to remember are these:

- Read `Healthy` and `Ready` together, and `lastAppliedRevision` for what runs.
- Use `wait: true` or `healthChecks`, not both.
- Set `timeout` above the rollout time and `retryInterval` below the interval.
- Monitor with metrics as well as with alerts.

<!-- astrona:playground:destroy -->
