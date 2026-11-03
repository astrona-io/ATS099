#!/usr/bin/env bash
# PASS when the policy and the binding exist, the binding denies and selects tenant namespaces by label.
set -uo pipefail
# grep -q stops reading at the first match; under pipefail the command
# writing into the pipe then fails with SIGPIPE and a match looks like a
# failure. This wrapper reads all input instead and keeps grep's exit status.
grep() {
  local arg quiet=0 args=()
  for arg in "$@"; do
    case "$arg" in
      --quiet|--silent) quiet=1 ;;
      --*) args+=("$arg") ;;
      -*q*) quiet=1; [ "$arg" = "-q" ] || args+=("${arg//q/}") ;;
      *) args+=("$arg") ;;
    esac
  done
  if [ "$quiet" = 1 ]; then command grep "${args[@]}" >/dev/null; else command grep "$@"; fi
}

if ! kubectl get validatingadmissionpolicy flux-tenant-service-account >/dev/null 2>&1; then
  echo "FAIL: there is no ValidatingAdmissionPolicy flux-tenant-service-account."
  exit 1
fi
res="$(kubectl get validatingadmissionpolicy flux-tenant-service-account -o jsonpath='{.spec.matchConstraints.resourceRules[*].resources[*]}')"
grp="$(kubectl get validatingadmissionpolicy flux-tenant-service-account -o jsonpath='{.spec.matchConstraints.resourceRules[*].apiGroups[*]}')"
if [ "$res" != "kustomizations" ] || [ "$grp" != "kustomize.toolkit.fluxcd.io" ]; then
  echo "FAIL: the policy must match resource 'kustomizations' in group 'kustomize.toolkit.fluxcd.io' (found '$res' in '$grp')."
  exit 1
fi
if ! kubectl get validatingadmissionpolicybinding flux-tenant-service-account >/dev/null 2>&1; then
  echo "FAIL: there is no ValidatingAdmissionPolicyBinding flux-tenant-service-account."
  exit 1
fi
policy="$(kubectl get validatingadmissionpolicybinding flux-tenant-service-account -o jsonpath='{.spec.policyName}')"
actions="$(kubectl get validatingadmissionpolicybinding flux-tenant-service-account -o jsonpath='{.spec.validationActions[*]}')"
selector="$(kubectl get validatingadmissionpolicybinding flux-tenant-service-account -o jsonpath='{.spec.matchResources.namespaceSelector}')"
if [ "$policy" != "flux-tenant-service-account" ]; then
  echo "FAIL: the binding refers to policy '$policy'."
  exit 1
fi
if [ "$actions" != "Deny" ]; then
  echo "FAIL: the binding must use the single action Deny (found '$actions')."
  exit 1
fi
if ! printf '%s' "$selector" | grep -q 'toolkit.fluxcd.io/tenant'; then
  echo "FAIL: the binding must select namespaces by the label toolkit.fluxcd.io/tenant."
  exit 1
fi
echo "PASS: the policy and the binding exist and are scoped to tenant namespaces."
exit 0
