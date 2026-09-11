#!/usr/bin/env bash
# Exit-status wrapper for `agy` (R3.6). `agy` soft-denies unapproved tools
# and still exits 0, so callers must gate on the JSON `status` field instead
# of the process exit code. Usage: agy-run.sh <agy args, expected to include
# --output-format json>
#
# UNVERIFIED (docs/records/agent-verification.md): the exact JSON shape --
# field name and the values distinguishing success from a tool denial or
# failure -- has not been observed against a real invocation. 01.2 has no
# egress and no credentials wired (01.4 owns auth); confirm this against a
# live run before relying on it. Until then this fails closed: anything that
# is not recognizably a success status exits non-zero.
set -euo pipefail

output="$(agy "$@")"
printf '%s\n' "$output"

status="$(printf '%s' "$output" | jq -r '.status // empty' 2>/dev/null || true)"

case "$status" in
  success|ok|completed)
    exit 0
    ;;
  *)
    echo "agy-run: status=\"${status:-<unreadable>}\" -- treating as denial or failure" >&2
    exit 1
    ;;
esac
