# Monitoring Flux With Prometheus

Status conditions show the state now. Prometheus keeps the history, which answers questions like how long reconciles take, how many fail, and since when something is stuck. Flux does not ship a monitoring stack. It exposes metrics, and you add Prometheus and Grafana.

## What Flux exposes

Each controller serves metrics on port `8080`, at `/metrics`, in a port named `http-prom`. Two groups matter:

- `gotk_reconcile_duration_seconds` is a histogram of how long reconciles take, per object kind. The count of its observations shows how often objects reconcile.
- `controller_runtime_reconcile_total` and `controller_runtime_reconcile_errors_total` count reconciles and errors per controller.

The metric `gotk_resource_info` is not exported by the controllers. It comes from kube-state-metrics, configured to read the Flux custom resources, and it has one series per object with labels such as `ready`, `suspended`, `customresource_kind`, `exported_namespace` and `name`. This is the metric to use for "which objects are not ready".

## Collect them

The usual way is the kube-prometheus-stack Helm chart, installed through a HelmRelease. Add a `PodMonitor` in `flux-system` that selects the Flux controller pods and scrapes the `http-prom` port:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: flux-system
  namespace: flux-system
spec:
  namespaceSelector:
    matchNames:
      - flux-system
  selector:
    matchExpressions:
      - key: app
        operator: In
        values:
          - helm-controller
          - source-controller
          - kustomize-controller
          - notification-controller
  podMetricsEndpoints:
    - port: http-prom
      relabelings:
        - sourceLabels: [__meta_kubernetes_pod_phase]
          action: keep
          regex: Running
```

The Flux project publishes a monitoring example repository with this PodMonitor, a kube-state-metrics configuration for `gotk_resource_info`, and Grafana dashboards. Start from it instead of writing the configuration from nothing, and pin it to a commit.

## Rules that matter

Alert on the state, not on every metric. Three rules cover most needs.

An object that is not ready for some time:

```yaml
- alert: FluxObjectNotReady
  expr: gotk_resource_info{ready="False"} == 1
  for: 15m
  labels:
    severity: warning
  annotations:
    summary: "{{ $labels.customresource_kind }} {{ $labels.exported_namespace }}/{{ $labels.name }} is not ready"
```

An object that was left suspended:

```yaml
- alert: FluxObjectSuspended
  expr: gotk_resource_info{suspended="true"} == 1
  for: 24h
  labels:
    severity: info
```

A controller that stopped reconciling:

```yaml
- alert: FluxControllerIdle
  expr: sum by (pod) (rate(gotk_reconcile_duration_seconds_count[10m])) == 0
  for: 30m
  labels:
    severity: critical
```

The `for` clause is the delay before the alert fires. Set it above the longest healthy rollout, or the alert fires during normal deployments.

## Alerts and metrics together

Events and metrics cover different failures. An Alert tells you about a failure when it happens, but it depends on notification-controller being up and on the provider working. A Prometheus rule fires even when notification-controller is down, because it uses the metrics of the other controllers. Use both, and send them to different channels or at least check that each can fire.

## Cost and retention

The number of series grows with the number of Flux objects. Keep the retention long enough for a weekend, and drop labels you do not use. The metric names are stable, but check them against the version of Flux you run, because controllers can add or rename metrics between releases.

## Common pitfalls

> [!WARNING]
> - **Looking for `gotk_resource_info` on the controllers.** It comes from kube-state-metrics.
> - **Scraping a port that is not named `http-prom`.** The PodMonitor finds no target.
> - **A `for` shorter than a rollout.** The rule fires on every deployment.
> - **Alerting only through notification-controller.** If it is down, nothing is sent.
