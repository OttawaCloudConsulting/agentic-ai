#!/usr/bin/env bash
# run-quiet.sh — run any command; keep the full log on disk, print only what matters.
# Purpose: stop 1,600-test suites and terraform/kubectl dumps from landing verbatim
# in Claude's context. Exit code of the wrapped command is preserved.
#
# Usage: run-quiet.sh <command> [args...]
#   e.g. run-quiet.sh npm test
#        run-quiet.sh terraform plan -no-color
set -uo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: run-quiet.sh <command> [args...]" >&2
  exit 64
fi

# NOTE: BSD/macOS mktemp requires the XXXXXX at the END of the template.
LOG="$(mktemp "${TMPDIR:-/tmp}/run-quiet.XXXXXX")"
"$@" > "$LOG" 2>&1
RC=$?

if [[ $RC -eq 0 ]]; then
  echo "OK rc=0: $*"
  WARNS="$(grep -nE 'WARN|Warning|warning:|deprecat|skipped|flaky' "$LOG" | head -n 20 || true)"
  if [[ -n "$WARNS" ]]; then
    echo "--- warnings (first 20) ---"
    printf '%s\n' "$WARNS"
  fi
  echo "--- last 5 lines ---"
  tail -n 5 "$LOG"
else
  echo "FAIL rc=$RC: $*"
  echo "--- failure matches (first 40) ---"
  grep -nE 'FAIL|✕|✗|✘|Error:|error TS[0-9]+|AssertionError|Traceback|panic:|FATAL' "$LOG" | head -n 40
  echo "--- last 40 lines ---"
  tail -n 40 "$LOG"
  echo "--- full log: $LOG ---"
fi
exit $RC
