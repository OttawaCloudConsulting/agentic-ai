#!/usr/bin/env bash
# PreToolUse hook: Bash — chmod executable-bit hard-block (exit 2)
# Feature 3.1. Production script. Blocks symbolic +x variants and numeric exec-bit modes.
# Anti-slop Script Safety: scripts must be invoked with explicit interpreter (bash script.sh).

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[ -z "$CMD" ] && exit 0

# Only relevant when chmod is invoked
printf '%s' "$CMD" | grep -qE '(^|[[:space:]])chmod[[:space:]]' || exit 0

# Symbolic exec-bit: +x, u+x, a+x, g+x, o+x, +rx, +X, etc.
if printf '%s' "$CMD" | grep -qE 'chmod[[:space:]].*(\+[rwxXsStT]*[xX]|[uago]+\+[rwxXsStT]*[xX])'; then
  printf 'BLOCKED: chmod +x (setting executable bit). Anti-slop Script Safety rule:\n  Do NOT set the executable bit. Use: bash script.sh\n' >&2
  exit 2
fi

# Symbolic assignment exec-bit: u=rwx, a=rx, ug=rx, o=x, etc.
# Match [ugoa]*=<perms> where <perms> contains x or X.
if printf '%s' "$CMD" | grep -qE 'chmod[[:space:]].*[ugoa]*=[rwxXsStT]*[xX][rwxXsStT]*'; then
  printf 'BLOCKED: chmod with assignment mode setting executable bit. Anti-slop Script Safety rule:\n  Do NOT set the executable bit. Use: bash script.sh\n' >&2
  exit 2
fi

# Numeric exec-bit: any octal permission digit that is odd (1,3,5,7 → has exec bit set).
# Matches 3- or 4-digit octal modes (e.g., 755, 0755, 700, 711) where at least one digit is odd.
if printf '%s' "$CMD" | grep -qE 'chmod[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*0?[0-7]*[13579][0-7]*([[:space:]]|$)'; then
  printf 'BLOCKED: chmod with numeric exec-bit mode. Anti-slop Script Safety rule:\n  Do NOT set the executable bit. Use: bash script.sh\n' >&2
  exit 2
fi

exit 0
