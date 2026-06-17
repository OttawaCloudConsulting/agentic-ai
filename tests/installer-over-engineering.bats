#!/usr/bin/env bats
# tests/installer-over-engineering.bats — Feature 3 installer idempotency tests
# Run: bats tests/installer-over-engineering.bats  (from project root)
# Requires: bats-core, jq

INSTALLER="$BATS_TEST_DIRNAME/../scripts/defensive-protocol/install.sh"

setup() {
  TARGET="$(mktemp -d)"
}

teardown() {
  rm -rf "$TARGET"
}

# ── Fresh install ─────────────────────────────────────────────────────────────

@test "over-engineering rule copied to .claude/rules/ on fresh install" {
  bash "$INSTALLER" "$TARGET"
  [ -f "$TARGET/.claude/rules/defensive-protocol-v2-over-engineering.md" ]
}

@test "over-engineering hook script copied to scripts/defensive-protocol/hooks/" {
  bash "$INSTALLER" "$TARGET"
  [ -f "$TARGET/scripts/defensive-protocol/hooks/over-engineering-reminder.sh" ]
}

@test "over-engineering hook marker present in settings.json after fresh install" {
  bash "$INSTALLER" "$TARGET"
  local settings="$TARGET/.claude/settings.json"
  jq -e '[.. | objects | .command? // empty | select(type=="string" and contains("dp2-oe-reminder"))] | length > 0' \
    "$settings" >/dev/null
}

@test "over-engineering CLAUDE.md sentinel block present after fresh install" {
  bash "$INSTALLER" "$TARGET"
  grep -qF '<!-- BEGIN DP2-OVER-ENGINEERING -->' "$TARGET/CLAUDE.md"
  grep -qF '<!-- END DP2-OVER-ENGINEERING -->'   "$TARGET/CLAUDE.md"
}

@test "settings.json remains valid JSON after over-engineering hook merge" {
  bash "$INSTALLER" "$TARGET"
  jq empty "$TARGET/.claude/settings.json"
}

# ── Idempotency ───────────────────────────────────────────────────────────────

@test "idempotent — second run does not duplicate over-engineering hook marker" {
  bash "$INSTALLER" "$TARGET"
  bash "$INSTALLER" "$TARGET"
  local settings="$TARGET/.claude/settings.json"
  local count
  count="$(jq '[.. | objects | .command? // empty | select(type=="string" and contains("dp2-oe-reminder"))] | length' "$settings")"
  [ "$count" -eq 1 ]
}

@test "idempotent — second run does not duplicate over-engineering CLAUDE.md sentinel" {
  bash "$INSTALLER" "$TARGET"
  bash "$INSTALLER" "$TARGET"
  local count
  count="$(grep -cF '<!-- BEGIN DP2-OVER-ENGINEERING -->' "$TARGET/CLAUDE.md")"
  [ "$count" -eq 1 ]
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
