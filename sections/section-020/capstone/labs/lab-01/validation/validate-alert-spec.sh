#!/usr/bin/env bash
# PASS when Provider webhook posts to the receiver and Alert flux-errors forwards only errors, from podinfo and the flux-system source, with no catch-all exclusion.
set -uo pipefail

ADDRESS="$(kubectl -n flux-system get provider webhook -o jsonpath='{.spec.address}' 2>/dev/null)"
if ! printf '%s' "$ADDRESS" | grep -q 'webhook-receiver.monitoring'; then
  echo "FAIL: Provider webhook posts to '$ADDRESS', not to the receiver in the namespace monitoring."
  exit 1
fi
SEVERITY="$(kubectl -n flux-system get alert flux-errors -o jsonpath='{.spec.eventSeverity}' 2>/dev/null)"
if [ "$SEVERITY" != "error" ]; then
  echo "FAIL: Alert flux-errors must still forward only errors (eventSeverity is '${SEVERITY:-info}')."
  exit 1
fi
SOURCES="$(kubectl -n flux-system get alert flux-errors -o jsonpath='{range .spec.eventSources[*]}{.kind}/{.name}/{.namespace}{" "}{end}' 2>/dev/null)"
printf '%s' "$SOURCES" | grep -qE '(^| )Kustomization/(podinfo|\*)/(flux-system)?( |$)' || {
  echo "FAIL: Alert flux-errors does not watch the Kustomization podinfo in flux-system (sources: $SOURCES)."; exit 1; }
printf '%s' "$SOURCES" | grep -qE '(^| )GitRepository/(flux-system|\*)/(flux-system)?( |$)' || {
  echo "FAIL: Alert flux-errors does not watch the GitRepository flux-system (sources: $SOURCES)."; exit 1; }
EXCLUSIONS="$(kubectl -n flux-system get alert flux-errors -o jsonpath='{range .spec.exclusionList[*]}{@}{"\n"}{end}' 2>/dev/null)"
for sample in "kustomization path not found" "failed to checkout and determine revision"; do
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    if printf '%s' "$sample" | grep -qE -- "$pattern"; then
      echo "FAIL: the exclusion pattern '$pattern' drops ordinary error messages such as '$sample'."
      exit 1
    fi
  done <<< "$EXCLUSIONS"
done
echo "PASS: the Provider and the Alert are set up to deliver Flux errors."
exit 0
