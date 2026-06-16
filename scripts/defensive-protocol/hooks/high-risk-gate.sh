#!/usr/bin/env bash
# PreToolUse hook: Bash — high-risk command gate (permissionDecision: ask)
# Feature 3.1. Production script.
# Covered: rm -rf/-fr/-r -f, git push --force/-f/+refspec, git reset --hard,
#          git rebase, git branch -D, git commit --amend, DROP (case-insensitive), migrate.
# Coverage boundary: obfuscated commands (aliases, env-indirection, base64|sh) are not caught.
# See docs/ARCHITECTURE_AND_DESIGN.md Design Decisions #1, #4.

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[ -z "$CMD" ] && exit 0

_ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"HIGH-RISK: %s. Stop. State DOING/EXPECT/IF-MISMATCH and wait for user confirmation (defensive-protocol-v2-epistemology)."}}\n' "$1"
  exit 0
}

# rm with recursive + force flags (combined or separate)
if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])rm[[:space:]]+-[rRfF]{1,4}([[:space:]]|$)' || \
   printf '%s' "$CMD" | grep -qE '(^|[[:space:]])rm[[:space:]]+-[rR][[:space:]]+-[fF]([[:space:]]|$)' || \
   printf '%s' "$CMD" | grep -qE '(^|[[:space:]])rm[[:space:]]+-[fF][[:space:]]+-[rR]([[:space:]]|$)'; then
  _ask "rm with recursive/force flags"
fi

# git push --force / -f / +refspec (any argument starting with +)
if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+push[[:space:]].*(--(force|delete)|-f([[:space:]]|$))' || \
   printf '%s' "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+push[[:space:]]([^[:space:]]+[[:space:]]+)*\+[^[:space:]]'; then
  _ask "git push with force/delete flag or +refspec"
fi

# git reset --hard
if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+reset[[:space:]]+--hard([[:space:]]|$)'; then
  _ask "git reset --hard"
fi

# git rebase
if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+rebase([[:space:]]|$)'; then
  _ask "git rebase"
fi

# git branch -D (force delete)
if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+branch[[:space:]]+-D([[:space:]]|$)'; then
  _ask "git branch -D (force delete)"
fi

# git commit --amend (anywhere in the argument list)
if printf '%s' "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+commit[[:space:]]' && \
   printf '%s' "$CMD" | grep -qE '(^|[[:space:]])--amend([[:space:]]|$)'; then
  _ask "git commit --amend (rewrites history)"
fi

# DROP (case-insensitive SQL keyword — may appear inside quotes or after operators)
if printf '%s' "$CMD" | grep -qiE '(^|[^[:alpha:]])drop[[:space:]]'; then
  _ask "DROP statement detected"
fi

# migrate (may appear as rake db:migrate, ./migrate, standalone, etc.)
if printf '%s' "$CMD" | grep -qiE '(^|[^[:alpha:]])migrate([^[:alpha:]]|$)'; then
  _ask "migrate command"
fi

exit 0
