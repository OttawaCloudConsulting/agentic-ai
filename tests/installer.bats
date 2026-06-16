#!/usr/bin/env bats
# tests/installer.bats — Feature 4.1 installer mechanical tests
# Run: bats tests/installer.bats  (from project root)
# Requires: bats-core, jq

INSTALLER="$BATS_TEST_DIRNAME/../scripts/defensive-protocol/install.sh"

setup() {
  TARGET="$(mktemp -d)"
}

teardown() {
  rm -rf "$TARGET"
}

# ── Prerequisite and argument validation ──────────────────────────────────────

@test "exits non-zero and prints ERROR when jq is absent from PATH" {
  command -v jq >/dev/null 2>&1 || skip "jq not found in test environment"

  # Simulate jq absence robustly: build a sandbox bin containing symlinks to
  # every tool the installer needs EXCEPT jq, then run with PATH=sandbox only.
  # Stripping jq's dir from the real PATH is unreliable — jq is often installed
  # in multiple PATH dirs (e.g. /opt/homebrew/bin AND /usr/bin), and those dirs
  # also hold coreutils the installer depends on.
  local sandbox="$BATS_TEST_TMPDIR/nojq-bin"
  mkdir -p "$sandbox"
  local tool path
  for tool in bash sh env mkdir cp mv cat cmp grep sed dirname basename mktemp rm; do
    path="$(command -v "$tool" 2>/dev/null)" && ln -sf "$path" "$sandbox/$tool"
  done

  run env -i PATH="$sandbox" HOME="$HOME" bash "$INSTALLER" "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "ERROR" ]] || [[ "$output" =~ "jq" ]]
}

@test "exits non-zero with no arguments" {
  run bash "$INSTALLER" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "exits non-zero for non-existent target directory" {
  run bash "$INSTALLER" "/tmp/dp2-nonexistent-$$" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" =~ "ERROR" ]]
}

@test "exits non-zero when settings.json contains invalid JSON" {
  mkdir -p "$TARGET/.claude"
  printf 'INVALID JSON }{{{' > "$TARGET/.claude/settings.json"
  run bash "$INSTALLER" "$TARGET" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" =~ "valid JSON" ]] || [[ "$output" =~ "ERROR" ]]
}

# ── Fresh install ─────────────────────────────────────────────────────────────

@test "succeeds (exit 0) on a fresh target directory" {
  run bash "$INSTALLER" "$TARGET" 2>&1
  [ "$status" -eq 0 ]
}

@test "copies rule trio to .claude/rules/" {
  bash "$INSTALLER" "$TARGET"
  [ -f "$TARGET/.claude/rules/defensive-protocol-v2-anti-slop.md" ]
  [ -f "$TARGET/.claude/rules/defensive-protocol-v2-epistemology.md" ]
  [ -f "$TARGET/.claude/rules/defensive-protocol-v2-session-management.md" ]
}

@test "copies hook scripts to scripts/defensive-protocol/hooks/" {
  bash "$INSTALLER" "$TARGET"
  [ -f "$TARGET/scripts/defensive-protocol/hooks/chmod-block.sh" ]
  [ -f "$TARGET/scripts/defensive-protocol/hooks/high-risk-gate.sh" ]
  [ -f "$TARGET/scripts/defensive-protocol/hooks/failure-reminder.sh" ]
  [ -f "$TARGET/scripts/defensive-protocol/hooks/pre-write.sh" ]
}

@test "creates agents/investigations and agents/memory directories" {
  bash "$INSTALLER" "$TARGET"
  [ -d "$TARGET/agents/investigations" ]
  [ -d "$TARGET/agents/memory" ]
}

@test "creates valid settings.json when none exists" {
  bash "$INSTALLER" "$TARGET"
  [ -f "$TARGET/.claude/settings.json" ]
  jq empty "$TARGET/.claude/settings.json"
}

@test "merges all four dp2 hook markers into settings.json" {
  bash "$INSTALLER" "$TARGET"
  local settings="$TARGET/.claude/settings.json"
  jq -e '[.. | objects | .command? // empty | select(type=="string" and contains("dp2-chmod-block"))]  | length > 0' "$settings" >/dev/null
  jq -e '[.. | objects | .command? // empty | select(type=="string" and contains("dp2-high-risk"))]    | length > 0' "$settings" >/dev/null
  jq -e '[.. | objects | .command? // empty | select(type=="string" and contains("dp2-pre-write"))]    | length > 0' "$settings" >/dev/null
  jq -e '[.. | objects | .command? // empty | select(type=="string" and contains("dp2-failure"))]      | length > 0' "$settings" >/dev/null
}

@test "settings.json remains valid JSON after hook merge" {
  bash "$INSTALLER" "$TARGET"
  jq empty "$TARGET/.claude/settings.json"
}

@test "settings.json preserves pre-existing content" {
  mkdir -p "$TARGET/.claude"
  printf '{"customKey":"customValue"}' > "$TARGET/.claude/settings.json"
  bash "$INSTALLER" "$TARGET"
  jq -e '.customKey == "customValue"' "$TARGET/.claude/settings.json" >/dev/null
}

@test "creates CLAUDE.md with Active-Rules sentinel block when none exists" {
  bash "$INSTALLER" "$TARGET"
  [ -f "$TARGET/CLAUDE.md" ]
  grep -qF '<!-- BEGIN DEFENSIVE-PROTOCOL-V2 -->' "$TARGET/CLAUDE.md"
  grep -qF '<!-- END DEFENSIVE-PROTOCOL-V2 -->'   "$TARGET/CLAUDE.md"
}

@test "appends Active-Rules block to existing CLAUDE.md without destroying content" {
  printf '# Existing content\n\nSome text.\n' > "$TARGET/CLAUDE.md"
  bash "$INSTALLER" "$TARGET"
  grep -qF '# Existing content'                   "$TARGET/CLAUDE.md"
  grep -qF '<!-- BEGIN DEFENSIVE-PROTOCOL-V2 -->' "$TARGET/CLAUDE.md"
}

# ── Idempotency ───────────────────────────────────────────────────────────────

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

@test "idempotent — second run does not duplicate hook entries" {
  bash "$INSTALLER" "$TARGET"
  bash "$INSTALLER" "$TARGET"

  local settings="$TARGET/.claude/settings.json"
  # Each dp2 marker must appear exactly once
  local count
  count="$(jq '[.. | objects | .command? // empty | select(type=="string" and contains("dp2-chmod-block"))] | length' "$settings")"
  [ "$count" -eq 1 ]

  count="$(jq '[.. | objects | .command? // empty | select(type=="string" and contains("dp2-high-risk"))] | length' "$settings")"
  [ "$count" -eq 1 ]

  count="$(jq '[.. | objects | .command? // empty | select(type=="string" and contains("dp2-pre-write"))] | length' "$settings")"
  [ "$count" -eq 1 ]

  count="$(jq '[.. | objects | .command? // empty | select(type=="string" and contains("dp2-failure"))] | length' "$settings")"
  [ "$count" -eq 1 ]
}

@test "idempotent — second run does not duplicate CLAUDE.md sentinel block" {
  bash "$INSTALLER" "$TARGET"
  bash "$INSTALLER" "$TARGET"

  local count
  count="$(grep -cF '<!-- BEGIN DEFENSIVE-PROTOCOL-V2 -->' "$TARGET/CLAUDE.md")"
  [ "$count" -eq 1 ]
}
