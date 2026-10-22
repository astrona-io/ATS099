#!/usr/bin/env bash
# PASS when Provider webhook posts to the receiver and Alert podinfo-errors forwards only errors from Kustomization podinfo.
set -uo pipefail

TYPE="$(kubectl -n flux-system get provider webhook -o jsonpath='{.spec.type}' 2>/dev/null)"
ADDRESS="$(kubectl -n flux-system get provider webhook -o jsonpath='{.spec.address}' 2>/dev/null)"
if [ "$TYPE" != "generic" ] || ! printf '%s' "$ADDRESS" | grep -q 'webhook-receiver.monitoring'; then
  echo "FAIL: Provider webhook in flux-system must be type generic and post to webhook-receiver.monitoring (type '$TYPE', address '$ADDRESS')."
  exit 1
fi
PROVIDER_REF="$(kubectl -n flux-system get alert podinfo-errors -o jsonpath='{.spec.providerRef.name}' 2>/dev/null)"
SEVERITY="$(kubectl -n flux-system get alert podinfo-errors -o jsonpath='{.spec.eventSeverity}' 2>/dev/null)"
SOURCES="$(kubectl -n flux-system get alert podinfo-errors -o jsonpath='{range .spec.eventSources[*]}{.kind}/{.name}/{.namespace}{" "}{end}' 2>/dev/null)"
if [ "$PROVIDER_REF" != "webhook" ]; then
  echo "FAIL: Alert podinfo-errors must use the Provider webhook (it uses '$PROVIDER_REF')."
  exit 1
fi
if [ "$SEVERITY" != "error" ]; then
  echo "FAIL: Alert podinfo-errors must forward only errors (eventSeverity is '${SEVERITY:-info}')."
  exit 1
fi
if ! printf '%s' "$SOURCES" | grep -qE '(^| )Kustomization/podinfo/(flux-system)?( |$)'; then
  echo "FAIL: Alert podinfo-errors must watch the Kustomization podinfo in flux-system (sources: $SOURCES)."
  exit 1
fi
echo "PASS: the Provider and the Alert are set up as asked."
exit 0
