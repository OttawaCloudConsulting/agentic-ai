#!/usr/bin/env bash
# Fixture stdio "server" for 02.3 SF-7's T29/T32 harness (tests/acceptance/verify-mcp-inventory.sh,
# Phases C-D). The gate (images/mcp-gate.js) inspects capability-declaration FILES only -- it never
# invokes a server -- so this script is never executed by the gate or by the harness. It exists so
# a fixture inventory entry's `artifact` field (Interface Contract 5) can name a real, checksummed
# file instead of a placeholder path, matching the shape a real stdio pack entry would carry.
set -euo pipefail
echo "mcp-fixture-stdio: fixture only, not a real MCP server" >&2
exit 0
