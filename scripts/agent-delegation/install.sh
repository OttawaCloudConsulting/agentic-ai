#!/usr/bin/env bash
set -euo pipefail

# Install the agent-delegation rule and its UserPromptSubmit hook
# into a target Claude Code project.
#
# The hook injects a one-line reminder when the user's prompt matches
# bulk-work keywords, forcing the agent to consult the delegation matrix
# before its first tool call.
#
# Usage:
#   bash scripts/agent-delegation/install.sh <target-repo-path>
#
# Effects on the target:
#   - <target>/.claude/rules/agent-delegation.md      copied (added | updated | unchanged)
#   - <target>/.claude/settings.json                  hook merged (added | already installed)
#
# Idempotent: re-running does not duplicate the hook entry.
# Dependencies: jq

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/agent-delegation/install.sh <target-repo-path>" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed." >&2
  echo "       macOS:  brew install jq" >&2
  echo "       Debian: sudo apt install jq" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_INPUT="$1"

if [[ ! -d "$TARGET_INPUT" ]]; then
  echo "ERROR: Target is not a directory: $TARGET_INPUT" >&2
  exit 1
fi

TARGET="$(cd "$TARGET_INPUT" && pwd)"
RULE_SRC="$REPO_ROOT/rules/agent-delegation.md"
RULE_DST="$TARGET/.claude/rules/agent-delegation.md"
SETTINGS="$TARGET/.claude/settings.json"

if [[ ! -f "$RULE_SRC" ]]; then
  echo "ERROR: Source rule missing: $RULE_SRC" >&2
  exit 1
fi

echo "==> Installing agent-delegation rule into $TARGET"

# 1. Copy the rule file
mkdir -p "$TARGET/.claude/rules"
if [[ ! -f "$RULE_DST" ]]; then
  cp "$RULE_SRC" "$RULE_DST"
  RULE_STATE="added"
elif cmp -s "$RULE_SRC" "$RULE_DST"; then
  RULE_STATE="unchanged"
else
  cp "$RULE_SRC" "$RULE_DST"
  RULE_STATE="updated"
fi
echo "==> Rule file:   $RULE_STATE ($RULE_DST)"

# 2. Ensure settings.json exists and is valid JSON before any merge attempt.
#    Validating up front gives a clean error rather than a cryptic jq parse
#    failure halfway through, and lets us trust the file for subsequent reads.
if [[ ! -f "$SETTINGS" ]]; then
  echo '{}' > "$SETTINGS"
elif ! jq empty "$SETTINGS" >/dev/null 2>&1; then
  echo "ERROR: $SETTINGS is not valid JSON. Fix the file or remove it before re-running." >&2
  exit 1
fi

# 3. Hook command (literal — heredoc is single-quoted, no expansion).
#    First line must contain the marker used for idempotency. Bumping the
#    marker (v1 → v2) re-installs even if a v1 entry already exists.
#    To change the keyword set, edit the heredoc below and bump the marker.
HOOK_MARKER="agent-delegation-hook v1"
HOOK_COMMAND=$(cat <<'EOF'
# agent-delegation-hook v1
prompt=$(jq -r '.prompt' < /dev/stdin)
if printf '%s' "$prompt" | grep -Eqi 'audit|categorize|review all|find every|across the docs|enumerate|inventory|sweep'; then
  printf 'Reminder (agent-delegation rule): if this task involves bulk discovery (>5 reads, repo-wide grep, multi-file audit), state your delegation decision before the first tool call.\n'
fi
exit 0
EOF
)

# 4. Idempotency check: scan every .command string in the JSON for the marker.
if jq -e --arg marker "$HOOK_MARKER" \
     '[.. | objects | .command? // empty | select(type == "string" and contains($marker))] | length > 0' \
     "$SETTINGS" >/dev/null 2>&1; then
  HOOK_STATE="already installed"
else
  # Use mktemp + trap so a partial write or jq failure never leaves a stale
  # *.tmp behind in the consumer's .claude/ directory.
  TMP="$(mktemp "$TARGET/.claude/settings.json.XXXXXX")"
  trap 'rm -f "$TMP"' EXIT
  jq --arg cmd "$HOOK_COMMAND" '
    .hooks = (.hooks // {}) |
    .hooks.UserPromptSubmit = (.hooks.UserPromptSubmit // []) |
    .hooks.UserPromptSubmit += [{
      matcher: "*",
      hooks: [{
        type: "command",
        command: $cmd,
        timeout: 5
      }]
    }]
  ' "$SETTINGS" > "$TMP"
  mv "$TMP" "$SETTINGS"
  trap - EXIT
  HOOK_STATE="added"
fi
echo "==> Hook:        $HOOK_STATE ($SETTINGS)"

echo "==> Done. Restart Claude Code in $TARGET to pick up changes."
