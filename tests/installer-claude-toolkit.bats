#!/usr/bin/env bats
# tests/installer-claude-toolkit.bats — claude-toolkit installer behavior tests
# Run: bats tests/installer-claude-toolkit.bats  (from project root)
# Requires: bats-core, jq, node

INSTALLER="$BATS_TEST_DIRNAME/../scripts/claude-toolkit/install.sh"

setup() {
  TARGET="$(mktemp -d)"
}

teardown() {
  rm -rf "$TARGET"
}

# ── Fresh install ─────────────────────────────────────────────────────────────

@test "scripts copied to .claude/scripts/ on fresh install" {
  bash "$INSTALLER" "$TARGET"
  [ -f "$TARGET/.claude/scripts/gcommit" ]
  [ -f "$TARGET/.claude/scripts/branch-sync.sh" ]
  [ -f "$TARGET/.claude/scripts/codex-review.sh" ]
  [ -f "$TARGET/.claude/scripts/run-quiet.sh" ]
  [ -f "$TARGET/.claude/scripts/state-status.sh" ]
  [ -f "$TARGET/.claude/scripts/check.sh" ]
}

@test "hooks copied to .claude/hooks/ on fresh install" {
  bash "$INSTALLER" "$TARGET"
  [ -f "$TARGET/.claude/hooks/block-heredoc-commit.js" ]
  [ -f "$TARGET/.claude/hooks/lint-md-on-edit.js" ]
}

@test "no executable bits set on installed files" {
  bash "$INSTALLER" "$TARGET"
  local f
  for f in "$TARGET/.claude/scripts/"* "$TARGET/.claude/hooks/"*; do
    [ ! -x "$f" ]
  done
}

@test "both hook markers present in settings.json after fresh install" {
  bash "$INSTALLER" "$TARGET"
  local settings="$TARGET/.claude/settings.json"
  jq -e '[.. | objects | .command? // empty | select(type=="string" and contains("cc-toolkit-heredoc-block"))] | length > 0' \
    "$settings" >/dev/null
  jq -e '[.. | objects | .command? // empty | select(type=="string" and contains("cc-toolkit-lint-md"))] | length > 0' \
    "$settings" >/dev/null
}

@test "settings.json remains valid JSON after merge" {
  bash "$INSTALLER" "$TARGET"
  jq empty "$TARGET/.claude/settings.json"
}

@test "heredoc hook entry has timeout 5 and a statusMessage" {
  bash "$INSTALLER" "$TARGET"
  local settings="$TARGET/.claude/settings.json"
  jq -e '[.hooks.PreToolUse[].hooks[] | select(.command | contains("cc-toolkit-heredoc-block"))
          | select(.timeout == 5 and (.statusMessage | length > 0))] | length == 1' \
    "$settings" >/dev/null
}

@test "lint-md hook entry has timeout 15 and a statusMessage" {
  bash "$INSTALLER" "$TARGET"
  local settings="$TARGET/.claude/settings.json"
  jq -e '[.hooks.PostToolUse[].hooks[] | select(.command | contains("cc-toolkit-lint-md"))
          | select(.timeout == 15 and (.statusMessage | length > 0))] | length == 1' \
    "$settings" >/dev/null
}

@test "pre-existing settings.json keys survive the merge" {
  mkdir -p "$TARGET/.claude"
  printf '{"model":"opus","permissions":{"allow":["Bash(ls:*)"]},"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo pre-existing"}]}]}}' \
    > "$TARGET/.claude/settings.json"
  bash "$INSTALLER" "$TARGET"
  local settings="$TARGET/.claude/settings.json"
  [ "$(jq -r '.model' "$settings")" = "opus" ]
  [ "$(jq -r '.permissions.allow[0]' "$settings")" = "Bash(ls:*)" ]
  jq -e '[.. | objects | .command? // empty | select(type=="string" and contains("echo pre-existing"))] | length == 1' \
    "$settings" >/dev/null
}

@test "migration — unmarked hand-wired hook entries are replaced, not duplicated" {
  # Seed the exact shape a consumer repo used before this installer existed:
  # both hooks wired by hand, no idempotency markers.
  mkdir -p "$TARGET/.claude"
  cat > "$TARGET/.claude/settings.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$CLAUDE_PROJECT_DIR/.claude/hooks/block-heredoc-commit.js\"",
            "timeout": 5,
            "statusMessage": "Checking commit style..."
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$CLAUDE_PROJECT_DIR/.claude/hooks/lint-md-on-edit.js\"",
            "timeout": 15,
            "statusMessage": "Formatting markdown..."
          }
        ]
      }
    ]
  }
}
EOF
  bash "$INSTALLER" "$TARGET"
  local settings="$TARGET/.claude/settings.json"
  # exactly one entry per hook script, and it carries the marker
  [ "$(jq '[.. | objects | .command? // empty | select(type=="string" and contains("block-heredoc-commit.js"))] | length' "$settings")" -eq 1 ]
  [ "$(jq '[.. | objects | .command? // empty | select(type=="string" and contains("lint-md-on-edit.js"))] | length' "$settings")" -eq 1 ]
  jq -e '[.. | objects | .command? // empty | select(type=="string" and contains("cc-toolkit-heredoc-block"))] | length == 1' \
    "$settings" >/dev/null
  jq -e '[.. | objects | .command? // empty | select(type=="string" and contains("cc-toolkit-lint-md"))] | length == 1' \
    "$settings" >/dev/null
}

# ── CLAUDE.md sentinel ────────────────────────────────────────────────────────

@test "CLAUDE.md sentinel pair present after fresh install" {
  bash "$INSTALLER" "$TARGET"
  grep -qF '<!-- BEGIN CLAUDE-TOOLKIT -->' "$TARGET/CLAUDE.md"
  grep -qF '<!-- END CLAUDE-TOOLKIT -->'   "$TARGET/CLAUDE.md"
}

@test "pre-existing CLAUDE.md content is appended to, not clobbered" {
  printf '# My Project\n\nHand-written guidance.\n' > "$TARGET/CLAUDE.md"
  bash "$INSTALLER" "$TARGET"
  grep -qF 'Hand-written guidance.' "$TARGET/CLAUDE.md"
  grep -qF '<!-- BEGIN CLAUDE-TOOLKIT -->' "$TARGET/CLAUDE.md"
}

@test "wrong-typed .hooks[event] fails with a clear error and leaves no temp files" {
  mkdir -p "$TARGET/.claude"
  printf '{"hooks":{"PreToolUse":{"bad":"hand-edit"}}}' > "$TARGET/.claude/settings.json"
  run bash "$INSTALLER" "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"array is required"* ]]
  # settings.json untouched, and no settings.json.XXXXXX left behind
  [ "$(jq -r '.hooks.PreToolUse.bad' "$TARGET/.claude/settings.json")" = "hand-edit" ]
  run bash -c "ls '$TARGET/.claude/' | grep -c 'settings\.json\.'"
  [ "$output" -eq 0 ]
}

@test "malformed sentinel (BEGIN without END) fails the install" {
  printf '# My Project\n\n<!-- BEGIN CLAUDE-TOOLKIT -->\npartial block, no end\n' > "$TARGET/CLAUDE.md"
  run bash "$INSTALLER" "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"malformed"* ]]
}

# ── .cc-base-branch semantics ─────────────────────────────────────────────────

@test "--base-branch writes .cc-base-branch when absent" {
  bash "$INSTALLER" --base-branch develop "$TARGET"
  [ -f "$TARGET/.cc-base-branch" ]
  [ "$(head -n1 "$TARGET/.cc-base-branch")" = "develop" ]
}

@test "without --base-branch no .cc-base-branch is written" {
  bash "$INSTALLER" "$TARGET"
  [ ! -f "$TARGET/.cc-base-branch" ]
}

@test "--base-branch leaves a pre-existing differing .cc-base-branch untouched" {
  printf 'main\n' > "$TARGET/.cc-base-branch"
  bash "$INSTALLER" --base-branch develop "$TARGET"
  [ "$(head -n1 "$TARGET/.cc-base-branch")" = "main" ]
}

# ── Idempotency ───────────────────────────────────────────────────────────────

@test "idempotent — second run does not duplicate hook markers" {
  bash "$INSTALLER" "$TARGET"
  bash "$INSTALLER" "$TARGET"
  local settings="$TARGET/.claude/settings.json"
  [ "$(jq '[.. | objects | .command? // empty | select(type=="string" and contains("cc-toolkit-heredoc-block"))] | length' "$settings")" -eq 1 ]
  [ "$(jq '[.. | objects | .command? // empty | select(type=="string" and contains("cc-toolkit-lint-md"))] | length' "$settings")" -eq 1 ]
}

@test "idempotent — second run does not duplicate CLAUDE.md sentinel" {
  bash "$INSTALLER" "$TARGET"
  bash "$INSTALLER" "$TARGET"
  [ "$(grep -cF '<!-- BEGIN CLAUDE-TOOLKIT -->' "$TARGET/CLAUDE.md")" -eq 1 ]
}

@test "idempotent — second run produces empty diff on settings.json and CLAUDE.md" {
  bash "$INSTALLER" "$TARGET"
  local snap
  snap="$(mktemp -d)"
  cp "$TARGET/.claude/settings.json" "$snap/settings.json"
  cp "$TARGET/CLAUDE.md"             "$snap/CLAUDE.md"

  bash "$INSTALLER" "$TARGET"

  diff "$snap/settings.json" "$TARGET/.claude/settings.json"
  diff "$snap/CLAUDE.md"     "$TARGET/CLAUDE.md"
  rm -rf "$snap"
}

# ── Bundle + installed self-test ──────────────────────────────────────────────

@test "bundle self-test (check.sh) passes in bundle layout" {
  # node is a hard prereq of the installer; check.sh needs it too — no skip.
  run bash "$BATS_TEST_DIRNAME/../scripts/claude-toolkit/check.sh"
  [ "$status" -eq 0 ]
}

@test "installed self-test (check.sh) passes in installed layout" {
  bash "$INSTALLER" "$TARGET"
  run bash "$TARGET/.claude/scripts/check.sh"
  [ "$status" -eq 0 ]
}
