# Claude Code Toolkit

Battle-tested helper scripts and tool hooks for Claude Code sessions: file-based
commits that can never break on quoting, a hardened Codex review wrapper, quiet
command execution, gated-workflow state digests, and deterministic markdown
hygiene. Extracted from a production GitOps repository after several weeks of
live use.

## Quick start

```bash
bash scripts/claude-toolkit/install.sh <target-repo-path>

# optionally pin the integration base branch for branch-sync.sh:
bash scripts/claude-toolkit/install.sh --base-branch develop <target-repo-path>
```

Restart Claude Code in the target repo afterwards.

## What gets installed

| Item | Destination | Effect |
|---|---|---|
| `gcommit` | `.claude/scripts/` | Commit via message file (`git commit -F`) — quoting can never break |
| `branch-sync.sh` | `.claude/scripts/` | Reset a feature branch onto the integration base after a squash-merge |
| `codex-review.sh` | `.claude/scripts/` | Hardened Codex review wrapper: closed stdin, timeout, read-only sandbox, `VERDICT: PASS/FAIL` |
| `run-quiet.sh` | `.claude/scripts/` | Run any command, log fully to `$TMPDIR`, print only a summary |
| `state-status.sh` | `.claude/scripts/` | ~15-line digest of gated-workflow state files + `--check-buildable` gate |
| `check.sh` | `.claude/scripts/` | Self-test harness for every script and hook in this toolkit |
| `hooks/block-heredoc-commit.js` | `.claude/hooks/` | PreToolUse/Bash — denies `git commit` with heredoc or multi-line `-m`, steers to gcommit |
| `hooks/lint-md-on-edit.js` | `.claude/hooks/` | PostToolUse/Edit\|Write — auto-fixes edited markdown via `markdownlint-cli2` |
| Hook wiring | `.claude/settings.json` | jq-merged, versioned markers (`# cc-toolkit-heredoc-block v1`, `# cc-toolkit-lint-md v1`); idempotent; migrates pre-existing unmarked entries |
| Guidance block | `CLAUDE.md` | Sentinel-guarded (`<!-- BEGIN CLAUDE-TOOLKIT -->`) Git/commit + review rules |
| `.cc-base-branch` | repo root | Only with `--base-branch`, only if the file is absent — never overwritten |

Everything is invoked with `bash <script>`; the installer never sets an
executable bit.

## Script reference

| Script | Invocation | Notes |
|---|---|---|
| gcommit | `bash .claude/scripts/gcommit "subject"` or pipe a full message on stdin | Also accepts a message-file path as the argument |
| branch-sync.sh | `bash .claude/scripts/branch-sync.sh [feature-branch]` | Base branch: `$CC_BASE_BRANCH` → `.cc-base-branch` → origin HEAD. Interactive confirm; refuses a dirty tree |
| codex-review.sh | `bash .claude/scripts/codex-review.sh --diff \| --staged \| --commits A..B \| FILE...` | Exit 0 = PASS, 1 = FAIL, **2 = no verdict (timeout/error) — never treat as PASS** |
| run-quiet.sh | `bash .claude/scripts/run-quiet.sh <cmd> [args...]` | Preserves the command's exit code |
| state-status.sh | `bash .claude/scripts/state-status.sh [root]` / `--check-buildable SLUG [root]` | Layout override: `CC_MILESTONE_GLOB` |
| check.sh | `bash .claude/scripts/check.sh` (installed) / `bash scripts/claude-toolkit/check.sh` (bundle) | Runs syntax + fixture tests for the whole toolkit |

## Dependencies

| Dependency | Needed by | Installer behavior |
|---|---|---|
| `jq` | installer, codex-review.sh, check.sh | **Hard prerequisite** |
| `node` | both hooks, check.sh | **Hard prerequisite** |
| `markdownlint-cli2` | lint-md-on-edit hook | Warn only — the hook calls the **bare binary** (no `npx` fallback, by design: a PostToolUse hook must be fast and silent). Absent = silent no-op |
| `codex` CLI | codex-review.sh | Warn only |
| GNU `timeout` / `gtimeout` | codex-review.sh | macOS: `brew install coreutils` |

## Consumer notes

- **Consumers with hand-written Git/commit guidance in `CLAUDE.md`** should
  dedupe it against the installed sentinel block — the installer appends, it
  does not replace hand-written sections.
- **`assets/eslint.config.mjs`** is not auto-installed. Copy it to the consumer
  repo root only if that repo's pre-commit runs `npx eslint` and the repo has no
  eslint config (the new `.claude/hooks/*.js` files would otherwise break the
  hook). It would clobber an existing eslint setup — hence manual.
- The skills/commands in this library reference these scripts at their installed
  paths (`bash .claude/scripts/...`), assuming the repo root as working
  directory.

## Self-test

```bash
bash scripts/claude-toolkit/check.sh     # bundle layout
bash .claude/scripts/check.sh            # installed layout
bats tests/installer-claude-toolkit.bats # installer behavior
```
