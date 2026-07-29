#!/usr/bin/env bash
# shellcheck disable=SC2016
# The hook commands intentionally embed a literal $CLAUDE_PROJECT_DIR: it must
# reach settings.json unexpanded so Claude Code resolves it at hook runtime, not
# to this installer's environment at install time.
set -euo pipefail

# scripts/claude-toolkit/install.sh
# Idempotent installer for the Claude Code toolkit (scripts + hooks + project skills).
#
# Installs into a target Claude Code project:
#   - Helper scripts       -> <target>/.claude/scripts/
#   - Tool hooks (node)    -> <target>/.claude/hooks/
#   - Gated project suite  -> <target>/.claude/skills/        (flattened — see below)
#   - Hook entries         -> <target>/.claude/settings.json  (jq-merged, versioned markers)
#   - Git/review guidance  -> <target>/CLAUDE.md              (sentinel-guarded)
#   - Base branch pin      -> <target>/.cc-base-branch        (only with --base-branch, only if absent)
#
# Usage:
#   bash scripts/claude-toolkit/install.sh [--base-branch NAME] [--no-skills] <target-repo-path>
#
# Skill layout: this library nests the suite as skills/project/<sub>/ for
#   authoring, but Claude Code resolves a slash command from the skill
#   directory's own name. The orchestrator invokes its sub-skills as bare
#   commands (/build, /define, ...) and each SKILL.md declares a bare `name:`,
#   so the sub-skills are FLATTENED on install:
#     skills/project/SKILL.md + references/  ->  .claude/skills/project/
#     skills/project/build/                  ->  .claude/skills/build/
#     skills/project/define/                 ->  .claude/skills/define/   (etc.)
#   This matches the layout proven in the source consumer repo.
#
# Prerequisites (hard): jq, node  — the hooks are node scripts, so node is a hard
#   prereq here (a deliberate extension of the defensive-protocol installer idiom).
# Optional runtime deps (warn only): markdownlint-cli2 (lint-md-on-edit hook),
#   codex + GNU timeout (codex-review.sh).
# Idempotent: re-running produces no changes. Existing UNMARKED entries that
#   already invoke these hook scripts are migrated to the marker format instead
#   of being duplicated.
# Never sets the executable bit — invoke everything via `bash <script>`.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills/project"
# Sub-skills of the gated suite, flattened to top level on install.
PROJECT_SUBSKILLS=(build define design milestone plan-feature spike)

# ── Prerequisites ─────────────────────────────────────────────────────────────

if ! command -v jq >/dev/null 2>&1; then
  printf 'ERROR: jq is required but not found in PATH.\n' >&2
  printf '       macOS:  brew install jq\n' >&2
  printf '       Debian: sudo apt-get install jq\n' >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  printf 'ERROR: node is required but not found in PATH (the hooks are node scripts).\n' >&2
  printf '       macOS:  brew install node\n' >&2
  printf '       Other:  https://nodejs.org/\n' >&2
  exit 1
fi

command -v markdownlint-cli2 >/dev/null 2>&1 \
  || printf 'WARN: markdownlint-cli2 not found — the lint-md-on-edit hook will be a silent no-op until installed (npm i -g markdownlint-cli2).\n' >&2
command -v codex >/dev/null 2>&1 \
  || printf 'WARN: codex CLI not found — codex-review.sh will not run until installed.\n' >&2

# ── Arguments ─────────────────────────────────────────────────────────────────

USAGE='Usage: bash scripts/claude-toolkit/install.sh [--base-branch NAME] [--no-skills] <target-repo-path>'
BASE_BRANCH=""
TARGET_INPUT=""
WITH_SKILLS=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-branch)
      [[ $# -ge 2 ]] || { printf 'ERROR: --base-branch requires a value.\n' >&2; exit 1; }
      BASE_BRANCH="$2"; shift 2 ;;
    --no-skills)
      WITH_SKILLS=0; shift ;;
    -*)
      printf 'ERROR: Unknown option: %s\n' "$1" >&2
      printf '%s\n' "$USAGE" >&2
      exit 1 ;;
    *)
      if [[ -n "$TARGET_INPUT" ]]; then
        printf '%s\n' "$USAGE" >&2
        exit 1
      fi
      TARGET_INPUT="$1"; shift ;;
  esac
done

if [[ -z "$TARGET_INPUT" ]]; then
  printf '%s\n' "$USAGE" >&2
  exit 1
fi
if [[ ! -d "$TARGET_INPUT" ]]; then
  printf 'ERROR: Target is not a directory: %s\n' "$TARGET_INPUT" >&2
  exit 1
fi

TARGET="$(cd "$TARGET_INPUT" && pwd)"
SCRIPTS_DST="$TARGET/.claude/scripts"
HOOKS_DST="$TARGET/.claude/hooks"
SKILLS_DST="$TARGET/.claude/skills"
SETTINGS="$TARGET/.claude/settings.json"
CLAUDE_MD="$TARGET/CLAUDE.md"

# Skills ship from the library tree, so a bundle copied out on its own cannot
# install them. Degrade to scripts+hooks rather than failing the whole install.
if [[ "$WITH_SKILLS" -eq 1 && ! -d "$SKILLS_SRC" ]]; then
  printf 'WARN: %s not found — installing scripts and hooks only.\n' "$SKILLS_SRC" >&2
  printf '      (Run this installer from a full checkout of the library to get the project skills.)\n' >&2
  WITH_SKILLS=0
fi

printf '==> Installing Claude Code toolkit into %s\n' "$TARGET"

# Temp paths cleaned on any exit. Declared at file scope (not `local`) so the
# trap can still resolve them if a step fails mid-function — a `local` would be
# out of scope by trap time and, under `set -u`, the trap body itself would fail
# and leak the file. One trap, set once: a second `trap ... EXIT` would silently
# replace this one.
ORCH_TMP=""
_TMP_SETTINGS=""
trap 'rm -rf "${ORCH_TMP:-}"; rm -f "${_TMP_SETTINGS:-}"' EXIT

# ── 1. Directories ────────────────────────────────────────────────────────────

mkdir -p "$SCRIPTS_DST" "$HOOKS_DST"
if [[ "$WITH_SKILLS" -eq 1 ]]; then
  mkdir -p "$SKILLS_DST"
  printf '==> Dirs:  .claude/scripts/  .claude/hooks/  .claude/skills/\n'
else
  printf '==> Dirs:  .claude/scripts/  .claude/hooks/\n'
fi

# ── 2. File copy (scripts + hooks) ───────────────────────────────────────────

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

_copy_file "$SCRIPT_DIR/gcommit"         "$SCRIPTS_DST/gcommit"         "Script"
_copy_file "$SCRIPT_DIR/branch-sync.sh"  "$SCRIPTS_DST/branch-sync.sh"  "Script"
_copy_file "$SCRIPT_DIR/codex-review.sh" "$SCRIPTS_DST/codex-review.sh" "Script"
_copy_file "$SCRIPT_DIR/run-quiet.sh"    "$SCRIPTS_DST/run-quiet.sh"    "Script"
_copy_file "$SCRIPT_DIR/state-status.sh" "$SCRIPTS_DST/state-status.sh" "Script"
_copy_file "$SCRIPT_DIR/check.sh"        "$SCRIPTS_DST/check.sh"        "Script"

_copy_file "$SCRIPT_DIR/hooks/block-heredoc-commit.js" "$HOOKS_DST/block-heredoc-commit.js" "Hook"
_copy_file "$SCRIPT_DIR/hooks/lint-md-on-edit.js"      "$HOOKS_DST/lint-md-on-edit.js"      "Hook"

# ── 2b. Skill copy (gated project suite, flattened) ──────────────────────────
# Overlay copy, never a delete: files present in the target but absent upstream
# are left alone, so a consumer's local additions survive an upgrade. A stale
# file from an older version is therefore not pruned — remove the skill
# directory by hand for a clean reinstall.

_copy_skill_dir() {
  local src="$1" dst="$2" name="$3"
  if [[ ! -f "$src/SKILL.md" ]]; then
    printf 'ERROR: Not a skill bundle (no SKILL.md): %s\n' "$src" >&2
    exit 1
  fi

  if [[ ! -d "$dst" ]]; then
    mkdir -p "$dst"
    cp -R "$src/." "$dst/"
    printf '==> %-14s  added     %s\n' "Skill" "$name"
    return
  fi

  # Compare only the files this installer owns; extras in the target are ignored.
  if diff -rq "$src" "$dst" 2>/dev/null | grep -qv '^Only in '; then
    cp -R "$src/." "$dst/"
    printf '==> %-14s  updated   %s\n' "Skill" "$name"
  elif diff -rq "$src" "$dst" 2>/dev/null | grep -q "^Only in $src"; then
    cp -R "$src/." "$dst/"
    printf '==> %-14s  updated   %s\n' "Skill" "$name"
  else
    printf '==> %-14s  unchanged %s\n' "Skill" "$name"
  fi
}

if [[ "$WITH_SKILLS" -eq 1 ]]; then
  # Orchestrator: SKILL.md + its own resource dirs, WITHOUT the nested
  # sub-skills (those are installed flattened, below).
  ORCH_TMP="$(mktemp -d "${TMPDIR:-/tmp}/cc-toolkit-project.XXXXXX")"
  cp -R "$SKILLS_SRC/." "$ORCH_TMP/"
  for sub in "${PROJECT_SUBSKILLS[@]}"; do
    rm -rf "${ORCH_TMP:?}/$sub"
  done
  _copy_skill_dir "$ORCH_TMP" "$SKILLS_DST/project" "project"
  rm -rf "$ORCH_TMP"
  ORCH_TMP=""

  for sub in "${PROJECT_SUBSKILLS[@]}"; do
    if [[ ! -d "$SKILLS_SRC/$sub" ]]; then
      printf 'ERROR: Expected sub-skill missing from the library: %s\n' "$SKILLS_SRC/$sub" >&2
      exit 1
    fi
    _copy_skill_dir "$SKILLS_SRC/$sub" "$SKILLS_DST/$sub" "$sub"
  done
fi

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
# Each hook command embeds a marker as its first line; the idempotency check
# scans the full settings.json tree for that marker. Additionally, entries that
# invoke the same hook SCRIPT without a marker (hand-wired installs that predate
# this installer) are migrated: the old entry is removed and the marker-bearing
# entry added, so re-installation never duplicates a hook.

_hook_present() {
  local marker="$1"
  jq -e --arg m "$marker" \
    '[.. | objects | .command? // empty | select(type == "string" and contains($m))] | length > 0' \
    "$SETTINGS" >/dev/null 2>&1
}

_unmarked_present() {
  local script_name="$1" marker="$2"
  jq -e --arg s "$script_name" --arg m "$marker" \
    '[.. | objects | .command? // empty
      | select(type == "string" and contains($s) and (contains($m) | not))] | length > 0' \
    "$SETTINGS" >/dev/null 2>&1
}

# Guard against a hand-edited settings.json where .hooks or .hooks[$event] is not
# the expected type — jq would otherwise fail with an opaque "object and array
# cannot be added" message deep inside the merge.
_assert_hook_shape() {
  local event="$1"
  if ! jq -e '(.hooks // {}) | type == "object"' "$SETTINGS" >/dev/null 2>&1; then
    printf 'ERROR: %s has a ".hooks" key that is not an object.\n' "$SETTINGS" >&2
    printf '       Repair it (or remove the key) before re-running.\n' >&2
    exit 1
  fi
  if ! jq -e --arg e "$event" '(.hooks[$e] // []) | type == "array"' "$SETTINGS" >/dev/null 2>&1; then
    printf 'ERROR: %s has ".hooks.%s" set to a %s; an array is required.\n' \
      "$SETTINGS" "$event" \
      "$(jq -r --arg e "$event" '.hooks[$e] | type' "$SETTINGS" 2>/dev/null || echo 'value of unexpected type')" >&2
    printf '       Repair it (or remove the key) before re-running.\n' >&2
    exit 1
  fi
}

_merge_hook() {
  local marker="$1" event="$2" matcher="$3" cmd="$4" timeout="$5" status_msg="$6" script_name="$7" label="$8"

  if _hook_present "$marker"; then
    printf '==> Hook  already installed: %s\n' "$label"
    return
  fi

  _assert_hook_shape "$event"

  local TMP
  TMP="$(mktemp "$TARGET/.claude/settings.json.XXXXXX")"
  _TMP_SETTINGS="$TMP"

  if _unmarked_present "$script_name" "$marker"; then
    # Migrate: drop hand-wired entries that invoke the same hook script.
    jq --arg s "$script_name" '
      if .hooks then
        .hooks |= with_entries(
          .value |= [ .[]
            | .hooks = ((.hooks // []) | map(select((.command // "" | contains($s)) | not)))
            | select((.hooks | length) > 0) ]
        )
      else . end
    ' "$SETTINGS" > "$TMP"
    mv "$TMP" "$SETTINGS"
    TMP="$(mktemp "$TARGET/.claude/settings.json.XXXXXX")"
    _TMP_SETTINGS="$TMP"
    printf '==> Hook  migrated unmarked entry: %s\n' "$label"
  fi

  jq --arg event "$event" --arg matcher "$matcher" --arg cmd "$cmd" \
     --argjson timeout "$timeout" --arg msg "$status_msg" '
    .hooks              = (.hooks // {}) |
    .hooks[$event]      = (.hooks[$event] // []) |
    .hooks[$event]     += [{ matcher: $matcher,
                             hooks: [{ type: "command", command: $cmd,
                                       timeout: $timeout, statusMessage: $msg }] }]
  ' "$SETTINGS" > "$TMP"
  mv "$TMP" "$SETTINGS"
  _TMP_SETTINGS=""

  printf '==> Hook  added: %s\n' "$label"
}

# PreToolUse / Bash: deny heredoc & multi-line -m commits, steer to gcommit
_merge_hook \
  "# cc-toolkit-heredoc-block v1" \
  "PreToolUse" "Bash" \
  '# cc-toolkit-heredoc-block v1
node "$CLAUDE_PROJECT_DIR/.claude/hooks/block-heredoc-commit.js"' \
  5 "Checking commit style..." \
  "block-heredoc-commit.js" \
  "block-heredoc-commit (PreToolUse/Bash)"

# PostToolUse / Edit|Write: markdownlint --fix on edited markdown
_merge_hook \
  "# cc-toolkit-lint-md v1" \
  "PostToolUse" "Edit|Write" \
  '# cc-toolkit-lint-md v1
node "$CLAUDE_PROJECT_DIR/.claude/hooks/lint-md-on-edit.js"' \
  15 "Formatting markdown..." \
  "lint-md-on-edit.js" \
  "lint-md-on-edit (PostToolUse/Edit|Write)"

# ── 5. CLAUDE.md — toolkit guidance sentinel block ────────────────────────────

SENTINEL_BEGIN='<!-- BEGIN CLAUDE-TOOLKIT -->'
SENTINEL_END='<!-- END CLAUDE-TOOLKIT -->'

_claude_md_block() {
  cat << 'BLOCK_EOF'
<!-- BEGIN CLAUDE-TOOLKIT -->
## Git / Version Control (claude-toolkit)

- Commit via `bash .claude/scripts/gcommit "<subject>"` (or pipe a full message on
  stdin). Never use a heredoc or a multi-line `-m` — the `block-heredoc-commit`
  PreToolUse hook denies those and steers to gcommit.
- The integration base branch resolves in this order: `$CC_BASE_BRANCH` env var →
  `.cc-base-branch` file at the repo root → the origin HEAD branch.
- After a feature branch is squash-merged, run
  `bash .claude/scripts/branch-sync.sh` to reset it onto the base branch.

## Code review & Claude tooling (claude-toolkit)

- Codex reviews go through `bash .claude/scripts/codex-review.sh` (`--diff`,
  `--staged`, `--commits A..B`, or explicit files) — never hand-roll `codex exec`.
  Exit 0 = PASS, 1 = FAIL, 2 = review failed (timeout/error) — never treat 2 as PASS.
- Markdown edits are auto-fixed by the `lint-md-on-edit` PostToolUse hook
  (requires `markdownlint-cli2` on PATH; silent no-op otherwise).
- `bash .claude/scripts/run-quiet.sh <cmd>` runs a noisy command and prints only
  a summary; `bash .claude/scripts/state-status.sh` digests gated-workflow state.
- Self-test the toolkit with `bash .claude/scripts/check.sh`.
<!-- END CLAUDE-TOOLKIT -->
BLOCK_EOF
}

_has_begin=0; _has_end=0
if [[ -f "$CLAUDE_MD" ]]; then
  grep -qF "$SENTINEL_BEGIN" "$CLAUDE_MD" && _has_begin=1
  grep -qF "$SENTINEL_END"   "$CLAUDE_MD" && _has_end=1
fi

if [[ "$_has_begin" -ne "$_has_end" ]]; then
  printf 'ERROR: %s has a malformed CLAUDE-TOOLKIT sentinel block (BEGIN without END or vice versa).\n' "$CLAUDE_MD" >&2
  printf '       Repair or remove the partial block before re-running.\n' >&2
  exit 1
fi

if [[ ! -f "$CLAUDE_MD" ]]; then
  _claude_md_block > "$CLAUDE_MD"
  printf '==> CLAUDE.md: created with toolkit block\n'
elif [[ "$_has_begin" -eq 1 ]]; then
  printf '==> CLAUDE.md: toolkit block already present\n'
else
  printf '\n' >> "$CLAUDE_MD"
  _claude_md_block >> "$CLAUDE_MD"
  printf '==> CLAUDE.md: toolkit block appended\n'
fi

# ── 6. .cc-base-branch (opt-in, never overwrites) ─────────────────────────────

if [[ -n "$BASE_BRANCH" ]]; then
  CC_FILE="$TARGET/.cc-base-branch"
  if [[ ! -f "$CC_FILE" ]]; then
    printf '%s\n' "$BASE_BRANCH" > "$CC_FILE"
    printf '==> .cc-base-branch: added (%s)\n' "$BASE_BRANCH"
  else
    EXISTING="$(head -n1 "$CC_FILE" | tr -d '[:space:]')"
    if [[ "$EXISTING" == "$BASE_BRANCH" ]]; then
      printf '==> .cc-base-branch: unchanged (%s)\n' "$EXISTING"
    else
      printf 'WARN: .cc-base-branch already contains "%s" (requested "%s") — left unchanged.\n' \
        "$EXISTING" "$BASE_BRANCH" >&2
      printf '==> .cc-base-branch: unchanged (%s)\n' "$EXISTING"
    fi
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────

printf '\n'
printf '==> Claude Code toolkit installed into %s\n' "$TARGET"
printf '==> Restart Claude Code in the target repo to pick up changes.\n'
