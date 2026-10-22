#!/usr/bin/env bash
# PASS when flux check reports the controllers and the CRDs as healthy.
set -uo pipefail

export PATH="/usr/local/bin:$HOME/.local/bin:$PATH"
if ! OUT="$(flux check 2>&1)"; then
  echo "FAIL: flux check reports a problem:"
  printf '%s\n' "$OUT"
  exit 1
fi
echo "PASS: flux check passes."
exit 0
