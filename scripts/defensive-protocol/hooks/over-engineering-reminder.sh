#!/usr/bin/env bash
# UserPromptSubmit hook: over-engineering pre-build reminder (Feature 3)
# Injects 3-clause discriminator reminder on build/implement intent.
# Prompt text is data, never code: matched via grep only, never evaluated.
# Covered keywords: implement, build, develop, "add a", "write a"

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Boundary is [^[:alpha:]] (not just whitespace) so punctuation-terminated keywords
# fire too — "implement:", "build.", "develop?". Matches high-risk-gate.sh convention.
if printf '%s' "$PROMPT" | grep -Eqi \
  '(^|[^[:alpha:]])(implement|build|develop)(s|ed|ing)?([^[:alpha:]]|$)|(^|[^[:alpha:]])add a([^[:alpha:]]|$)|(^|[^[:alpha:]])write a([^[:alpha:]]|$)'; then
  printf 'Before building: run the 3-clause discriminator; default minimal; justify every addition.\n'
fi

exit 0
