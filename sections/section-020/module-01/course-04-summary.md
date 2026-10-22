# Summary

Flux works in the background, so a failure that nobody is told about can last for hours. This module made failures visible, one event at a time and as numbers over time.

## What you learned

Every Flux controller records Kubernetes events about the objects it reconciles. An event names the involved object and carries a severity of `info` or `error`, a reason such as `ReconciliationSucceeded`, and a message. `flux events` reads them. Kubernetes itself shows `info` as `Normal` and `error` as `Warning`.

notification-controller forwards events from two objects in `notification.toolkit.fluxcd.io/v1beta3`. A `Provider` says where to send: a type such as `generic`, `slack` or `msteams`, and an address. Chat webhook addresses and tokens are secrets, so they go in a Secret with the key `address` or `token`. A `generic` provider posts each event as JSON with `involvedObject`, `severity`, `reason`, `message`, `metadata`, `reportingController` and `timestamp`, plus a `Gotk-Component` header; `generic-hmac` adds a signature. An `Alert` says which events go to its `Provider`.

An `Alert` passes an event only when it matches every filter: an entry in `eventSources` (kind, name or `"*"`, and the `Alert`'s namespace unless another is named), the severity in `eventSeverity`, at least one pattern in `inclusionList` if there is one, and no pattern in `exclusionList`, which always wins. `eventSeverity` defaults to `info`, which forwards everything. `eventMetadata` adds key-value pairs to what is sent; `summary` is deprecated.

The controllers serve Prometheus metrics on port `8080` at `/metrics`. `gotk_reconcile_duration_seconds` is a histogram of reconcile times per object, and controller-runtime counters such as `controller_runtime_reconcile_total` count results. `gotk_resource_info` comes from kube-state-metrics, not from the controllers. `flux stats` is a quick preview summary. The key facts to remember are these:

- A Provider says where; an Alert says what.
- Set `eventSeverity: error` unless you really want every success.
- Prove an Alert with a failure that arrives and a recovery that does not.
- Break and repair through Git, so `flux-system` does not undo your test.

<!-- astrona:playground:destroy -->
