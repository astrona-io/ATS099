#!/usr/bin/env bash
# PASS when no RoleBinding in team-a uses cluster-admin and team-a cannot update ResourceQuotas.
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

refs="$(kubectl -n team-a get rolebinding -o jsonpath='{range .items[*]}{.roleRef.name}{"\n"}{end}' 2>/dev/null)"
if printf '%s\n' "$refs" | grep -qx 'cluster-admin'; then
  echo "FAIL: a RoleBinding in team-a still refers to cluster-admin."
  exit 1
fi
if ! printf '%s\n' "$refs" | grep -qx 'admin'; then
  echo "FAIL: no RoleBinding in team-a refers to the ClusterRole admin."
  exit 1
fi
answer="$(kubectl auth can-i update resourcequotas -n team-a --as=system:serviceaccount:team-a:team-a 2>/dev/null || true)"
if [ "$answer" != "no" ]; then
  echo "FAIL: the ServiceAccount team-a can still update ResourceQuotas in team-a."
  exit 1
fi
crb="$(kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .subjects[*]}{.namespace}/{.name}{" "}{end}{"\n"}{end}' | grep ' team-a/team-a' || true)"
if [ -n "$crb" ]; then
  echo "FAIL: a ClusterRoleBinding names the ServiceAccount team-a: $crb"
  exit 1
fi
echo "PASS: team-a holds the admin role in its namespace only and cannot change quotas."
exit 0
