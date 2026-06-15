#!/usr/bin/env bash
set -euo pipefail

# scripts/defensive-protocol/install.sh
# Idempotent installer for Defensive Protocol v2 enforcement layer.
#
# Installs into a target Claude Code project:
#   - Rule trio            -> <target>/.claude/rules/
#   - Hook scripts         -> <target>/scripts/defensive-protocol/hooks/
#   - Hook entries         -> <target>/.claude/settings.json  (jq-merged, versioned markers)
#   - Active-Rules block   -> <target>/CLAUDE.md              (sentinel-guarded)
#   - State dirs           -> <target>/agents/{investigations,memory}/
#
# Usage:
#   bash scripts/defensive-protocol/install.sh <target-repo-path>
#
# Prerequisites: jq  (hard-fails loudly if absent — Design Decision #15)
# Design Decisions: #14 (versioned markers + sentinel), #15 (fail-loud), #19 (no chmod +x)
# Idempotent: re-running produces no changes (verified by tests/installer.bats)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Prerequisites ─────────────────────────────────────────────────────────────

if ! command -v jq >/dev/null 2>&1; then
  printf 'ERROR: jq is required but not found in PATH.\n' >&2
  printf '       Hooks and installer both require jq (Design Decision #5, #15).\n' >&2
  printf '       macOS:  brew install jq\n' >&2
  printf '       Debian: sudo apt-get install jq\n' >&2
  printf '       Other:  https://stedolan.github.io/jq/download/\n' >&2
  exit 1
fi

# ── Arguments ─────────────────────────────────────────────────────────────────

if [[ $# -ne 1 ]]; then
  printf 'Usage: bash scripts/defensive-protocol/install.sh <target-repo-path>\n' >&2
  exit 1
fi

TARGET_INPUT="$1"
if [[ ! -d "$TARGET_INPUT" ]]; then
  printf 'ERROR: Target is not a directory: %s\n' "$TARGET_INPUT" >&2
  exit 1
fi

TARGET="$(cd "$TARGET_INPUT" && pwd)"
RULES_SRC="$REPO_ROOT/rules"
HOOKS_SRC="$REPO_ROOT/scripts/defensive-protocol/hooks"
CLAUDE_RULES_DST="$TARGET/.claude/rules"
HOOKS_DST="$TARGET/scripts/defensive-protocol/hooks"
SETTINGS="$TARGET/.claude/settings.json"
CLAUDE_MD="$TARGET/CLAUDE.md"

printf '==> Installing Defensive Protocol v2 into %s\n' "$TARGET"

# ── 1. Directories ────────────────────────────────────────────────────────────

mkdir -p "$CLAUDE_RULES_DST"
mkdir -p "$HOOKS_DST"
mkdir -p "$TARGET/.claude"
mkdir -p "$TARGET/agents/investigations"
mkdir -p "$TARGET/agents/memory"
printf '==> Dirs:  .claude/rules/  scripts/defensive-protocol/hooks/  agents/{investigations,memory}/\n'

# ── 2. File copy (rules + hook scripts) ──────────────────────────────────────

_copy_file() {
  local src="$1" dst="$2" label="$3"
  if [[ ! -f "$src" ]]; then
    printf 'ERROR: Source file missing: %s\n' "$src" >&2
    exit 1
  fi
  if [[ ! -f "$dst" ]]; then
    cp "$src" "$dst"
    printf '==> %-14s  added     %s\n' "$label" "$(basename "$dst")"
  elif cmp -s "$src" "$dst"; then
    printf '==> %-14s  unchanged %s\n' "$label" "$(basename "$dst")"
  else
    cp "$src" "$dst"
    printf '==> %-14s  updated   %s\n' "$label" "$(basename "$dst")"
  fi
}

_copy_file "$RULES_SRC/defensive-protocol-v2-anti-slop.md"          "$CLAUDE_RULES_DST/defensive-protocol-v2-anti-slop.md"          "Rule"
_copy_file "$RULES_SRC/defensive-protocol-v2-epistemology.md"       "$CLAUDE_RULES_DST/defensive-protocol-v2-epistemology.md"       "Rule"
_copy_file "$RULES_SRC/defensive-protocol-v2-session-management.md" "$CLAUDE_RULES_DST/defensive-protocol-v2-session-management.md" "Rule"

_copy_file "$HOOKS_SRC/chmod-block.sh"      "$HOOKS_DST/chmod-block.sh"      "Hook script"
_copy_file "$HOOKS_SRC/high-risk-gate.sh"   "$HOOKS_DST/high-risk-gate.sh"   "Hook script"
_copy_file "$HOOKS_SRC/failure-reminder.sh" "$HOOKS_DST/failure-reminder.sh" "Hook script"
_copy_file "$HOOKS_SRC/pre-write.sh"        "$HOOKS_DST/pre-write.sh"        "Hook script"

# ── 3. settings.json — validate / create ─────────────────────────────────────

if [[ ! -f "$SETTINGS" ]]; then
  printf '{}' > "$SETTINGS"
  printf '==> settings.json: created\n'
elif ! jq empty "$SETTINGS" >/dev/null 2>&1; then
  printf 'ERROR: %s is not valid JSON.\n' "$SETTINGS" >&2
  printf '       Fix or remove the file before re-running.\n' >&2
  exit 1
else
  printf '==> settings.json: valid JSON\n'
fi

# ── 4. Merge hook entries (idempotent, versioned markers) ─────────────────────
# Each hook embeds a marker as its first line. The idempotency check scans the
# full settings.json tree for that marker string — if found, the hook is already
# installed. Bump the version suffix (v1 -> v2) to force re-installation.
#
# Hook entries are added as standalone matcher entries rather than spliced into
# existing arrays, so each can be checked and added independently.

_hook_present() {
  local marker="$1"
  jq -e --arg m "$marker" \
    '[.. | objects | .command? // empty | select(type == "string" and contains($m))] | length > 0' \
    "$SETTINGS" >/dev/null 2>&1
}

_merge_hook() {
  local marker="$1" event="$2" matcher="$3" cmd="$4" label="$5"

  if _hook_present "$marker"; then
    printf '==> Hook  already installed: %s\n' "$label"
    return
  fi

  local TMP
  TMP="$(mktemp "$TARGET/.claude/settings.json.XXXXXX")"
  trap 'rm -f "$TMP"' EXIT

  jq --arg event "$event" --arg matcher "$matcher" --arg cmd "$cmd" '
    .hooks              = (.hooks // {}) |
    .hooks[$event]      = (.hooks[$event] // []) |
    .hooks[$event]     += [{ matcher: $matcher, hooks: [{ type: "command", command: $cmd, timeout: 5 }] }]
  ' "$SETTINGS" > "$TMP"
  mv "$TMP" "$SETTINGS"
  trap - EXIT

  printf '==> Hook  added: %s\n' "$label"
}

# PreToolUse / Bash: chmod hard-block
_merge_hook \
  "# dp2-chmod-block v1" \
  "PreToolUse" "Bash" \
  "# dp2-chmod-block v1
bash scripts/defensive-protocol/hooks/chmod-block.sh" \
  "chmod-block (PreToolUse/Bash)"

# PreToolUse / Bash: high-risk gate (ask)
_merge_hook \
  "# dp2-high-risk v1" \
  "PreToolUse" "Bash" \
  "# dp2-high-risk v1
bash scripts/defensive-protocol/hooks/high-risk-gate.sh" \
  "high-risk-gate (PreToolUse/Bash)"

# PreToolUse / Edit|Write|mcp__.*: overwrite reminder
_merge_hook \
  "# dp2-pre-write v1" \
  "PreToolUse" "Edit|Write|mcp__.*" \
  "# dp2-pre-write v1
bash scripts/defensive-protocol/hooks/pre-write.sh" \
  "pre-write (PreToolUse/Edit|Write|mcp__.*)"

# PostToolUseFailure: FAILED/THEORY/PROPOSE reminder
_merge_hook \
  "# dp2-failure v1" \
  "PostToolUseFailure" "" \
  "# dp2-failure v1
bash scripts/defensive-protocol/hooks/failure-reminder.sh" \
  "failure-reminder (PostToolUseFailure)"

# ── 5. CLAUDE.md — Active-Rules sentinel block ────────────────────────────────
# Idempotent: checks for BEGIN sentinel before writing.
# Block content matches this project's canonical CLAUDE.md block (Feature 3.3).

SENTINEL_BEGIN='<!-- BEGIN DEFENSIVE-PROTOCOL-V2 -->'

_claude_md_block() {
  cat << 'BLOCK_EOF'
<!-- BEGIN DEFENSIVE-PROTOCOL-V2 -->
## Active Rules — Defensive Protocol v2

Loaded rules: `.claude/rules/defensive-protocol-v2-anti-slop.md`, `.claude/rules/defensive-protocol-v2-epistemology.md`, `.claude/rules/defensive-protocol-v2-session-management.md`

### Hard Behaviors (enforced by hooks)

- **Destructive Bash commands** (`rm -rf`, `git push --force`, `git reset --hard`, `git rebase`, `git branch -D`, `git commit --amend`, `DROP`, `migrate`) — paused for user confirmation before execution.
- **`chmod +x` / executable-bit modes** — hard-blocked (`exit 2`). Always invoke scripts with `bash script.sh`, never `./script.sh`.
- **Write / Edit / MCP tool calls** — advisory reminder fires before any overwrite or delete.
- **Tool failures** — FAILED/THEORY/PROPOSE reminder injected after the failure.

### Soft Behaviors (rule text — self-applied)

- **Autonomy check** — before significant decisions, evaluate blast radius and reversibility; ask when wrong costs more than waiting.
- **Contradiction handling** — when instructions conflict, surface the conflict explicitly rather than silently picking one.
- **Pushing back** — state concern concretely, share missing information, propose alternative, defer to user.
- **Chesterton's Fence** — before removing or changing anything, articulate why it exists. Prove it's unused before touching.

### State File Paths

- Investigations: `agents/investigations/`
- Session memory / handoffs: `agents/memory/`
- Scratch / disposable analysis: `scratch/`
<!-- END DEFENSIVE-PROTOCOL-V2 -->
BLOCK_EOF
}

if [[ ! -f "$CLAUDE_MD" ]]; then
  _claude_md_block > "$CLAUDE_MD"
  printf '==> CLAUDE.md: created with Active-Rules block\n'
elif grep -qF "$SENTINEL_BEGIN" "$CLAUDE_MD"; then
  printf '==> CLAUDE.md: Active-Rules block already present\n'
else
  printf '\n' >> "$CLAUDE_MD"
  _claude_md_block >> "$CLAUDE_MD"
  printf '==> CLAUDE.md: Active-Rules block appended\n'
fi

# ── Done ──────────────────────────────────────────────────────────────────────

printf '\n'
printf '==> Defensive Protocol v2 installed into %s\n' "$TARGET"
printf '==> Restart Claude Code in the target repo to pick up changes.\n'
