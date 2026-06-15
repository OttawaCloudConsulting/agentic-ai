#!/usr/bin/env bash
# Production PostToolUseFailure hook — two-tier FAILED/THEORY/PROPOSE reminder.
# Design Decision #3: PostToolUseFailure fires on failures only; PostToolUse = success only.
# Two tiers: short errors (<80 chars) get a one-liner; substantive errors get the full template.

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // "unknown"')
ERR=$(printf '%s' "$INPUT" | jq -r '.error // ""')

# No error field = success payload (PostToolUse, not PostToolUseFailure) — emit nothing
[ -z "$ERR" ] && exit 0

if [ "${#ERR}" -lt 80 ]; then
  REMINDER="STOP — ${TOOL} failed: ${ERR}. State THEORY before retrying. (anti-slop Failure Response)"
else
  REMINDER="FAILED: ${TOOL}
ERROR: ${ERR}
THEORY: [state why this happened]
PROPOSE: [action] expecting [outcome]
Proceed? (defensive-protocol-v2-anti-slop)"
fi

jq -cn --arg ctx "$REMINDER" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUseFailure","additionalContext":$ctx}}'
exit 0
