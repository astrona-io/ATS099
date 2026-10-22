# Section 020: Alerting And Monitoring

Flux works in the background. It fetches, builds and applies without anyone watching, which is the point. It also means that a broken commit, a lost credential or a source that cannot be fetched can go unnoticed for hours, while the cluster quietly stops following Git.

This section makes failures visible. Every Flux controller records **events** about the objects it reconciles. notification-controller can forward those events to chat tools and webhooks, through two objects: a **Provider** that says where to send, and an **Alert** that says what to send. The controllers also export **metrics** for Prometheus, which show how often and how long reconciliations run.

**Topic covered:** Alerting and monitoring

## What you will learn

- What a Flux event holds: the object, a severity of `info` or `error`, a reason and a message.
- Writing a `Provider` for a generic webhook, and how Slack and Microsoft Teams providers differ.
- Writing an `Alert` that selects events by object, by severity and by message, with `exclusionList` winning over `inclusionList`.
- Reading the payload a generic provider posts, in the log of a webhook receiver.
- The metrics every controller exports on port `8080`, such as `gotk_reconcile_duration_seconds`, and which metrics come from kube-state-metrics instead.

## The learning path

The section has one module. It has a landing page, three short parts, a graded lab right after the part it tests, and a summary. The module has its own playground, a cluster where Flux runs podinfo and a webhook receiver waits in the namespace `monitoring`. The landing page starts the playground for you.

### 1. Send Flux Events To Webhooks And Chat

1. Events, Providers And Alerts
2. Choosing Which Events Become Alerts, followed by the lab **Alert A Webhook When podinfo Fails**
3. Metrics And flux stats
4. Summary

## Section capstone: Find Why No Alert Arrives

The capstone is one graded scenario. A `Provider` and an `Alert` were committed to Git weeks ago, and nobody has received a single alert since. There are three independent faults between the event and the receiver. You must find them from the configuration and the receiver's log, fix them in Git, and prove that both a source failure and a Kustomization failure arrive. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS099.git -c sections/section-020/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-099-capstone-020
```
