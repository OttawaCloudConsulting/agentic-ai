# Claude Toolkit — Reference

Per-script reference for the `scripts/claude-toolkit/` bundle. For the quick start and install effects, see the bundle entry point at `scripts/claude-toolkit/README.md`; for the index of all script bundles, see [SCRIPTS.md](../../SCRIPTS.md).

All scripts are invoked with an explicit interpreter (`bash <script>`) — nothing in this bundle is ever executable. Installed paths below assume the target repo root as working directory.

## install.sh

```bash
bash scripts/claude-toolkit/install.sh [--base-branch NAME] [--no-skills] <target-repo-path>
```

| Aspect | Detail |
|---|---|
| Copies | Six scripts → `<target>/.claude/scripts/`; two hooks → `<target>/.claude/hooks/`; the gated project suite → `<target>/.claude/skills/` (flattened, see below) |
| `--no-skills` | Skip the skill suite; install scripts and hooks only |
| settings.json | jq-merges two hook entries with versioned markers; migrates pre-existing unmarked entries invoking the same hook scripts |
| CLAUDE.md | Appends the `<!-- BEGIN CLAUDE-TOOLKIT -->` sentinel block; hard-fails on a malformed (unpaired) sentinel |
| `--base-branch NAME` | Writes `<target>/.cc-base-branch` only if the file is absent; a differing existing file is warned about and left unchanged |
| Hard prerequisites | `jq`, `node` |
| Warn-only | `markdownlint-cli2`, `codex` CLI |
| Does **not** install | Commands or rules — copy those with `cp` (see [COMMANDS.md](../../COMMANDS.md#consuming-commands), [RULES.md](../../RULES.md)) |

### Skill layout (flattened)

Claude Code scans `.claude/skills/` one level deep and derives each slash command from the
**directory name**; for project skills the `name:` frontmatter only sets the display label. The
library's authoring nesting is flattened on install:

| Source | Installed | Command |
|---|---|---|
| `skills/project/SKILL.md` + `references/` | `.claude/skills/project/` | `/project` |
| `skills/project/build/` | `.claude/skills/build/` | `/build` |
| `skills/project/define/` | `.claude/skills/define/` | `/define` |
| `skills/project/design/` | `.claude/skills/design/` | `/design` |
| `skills/project/milestone/` | `.claude/skills/milestone/` | `/milestone` |
| `skills/project/plan-feature/` | `.claude/skills/plan-feature/` | `/plan-feature` |
| `skills/project/spike/` | `.claude/skills/spike/` | `/spike` |

The orchestrator directory receives no copy of the sub-skills. Skill copies are an overlay —
consumer-added files survive an upgrade and nothing is deleted, so a stale file from an older
version is not pruned (remove the directory by hand for a clean reinstall).

`/start-feature-auto` is a command, not a skill: copy it separately, and note it requires the
installed `codex-review.sh`.

## gcommit

Commit via message file only — writes the message to `$GIT_DIR/CLAUDE_COMMIT_MSG` and runs `git commit -F`, so shell quoting can never break a commit.

```bash
bash .claude/scripts/gcommit "subject line"        # subject as argument
bash .claude/scripts/gcommit path/to/message.txt   # argument that is a file = message file
printf 'subject\n\nbody\n' | bash .claude/scripts/gcommit   # full message on stdin
```

Companion to the `block-heredoc-commit` hook, which denies heredoc / multi-line `-m` commits and steers here.

## branch-sync.sh

Resets a feature branch onto the integration base after a squash-merge (`git reset --hard origin/<base>`). Interactive `y/N` confirm; refuses a dirty working tree; refuses to run while checked out on the base branch.

```bash
bash .claude/scripts/branch-sync.sh [feature-branch]
```

Base-branch resolution order:

1. `$CC_BASE_BRANCH` environment variable
2. `.cc-base-branch` file at the repo top level (first line)
3. The origin HEAD branch (`git remote show origin`)

## codex-review.sh

Hardened wrapper for Codex code review: closed stdin (an open stdin hangs `codex exec`), enforced timeout, `-s read-only` sandbox, and a machine-readable final `VERDICT: PASS` / `VERDICT: FAIL` line.

```bash
bash .claude/scripts/codex-review.sh --diff              # working diff + untracked files
bash .claude/scripts/codex-review.sh --staged            # staged changes
bash .claude/scripts/codex-review.sh --commits A..B      # commit range
bash .claude/scripts/codex-review.sh FILE [FILE...]      # explicit files
# optional: -p "extra prompt/acceptance criteria", -t <seconds> timeout
```

| Exit code | Meaning |
|---|---|
| 0 | `VERDICT: PASS` |
| 1 | `VERDICT: FAIL` — findings to triage |
| 2 | Review failed (timeout, codex error, no verdict) — **never treat as PASS** |

Dependencies: `git`, `jq`, `codex` CLI, GNU `timeout`/`gtimeout` (macOS: `brew install coreutils`).

## run-quiet.sh

Runs any command, keeps the full log in `$TMPDIR`, and prints only a summary: `OK` + warnings + last 5 lines on success, `FAIL` + matched error lines + last 40 on failure. Preserves the command's exit code.

```bash
bash .claude/scripts/run-quiet.sh npm test
bash .claude/scripts/run-quiet.sh terraform plan
```

## state-status.sh

~15-line digest of the gated-workflow state files (`progress.txt` + `milestone-status.txt`) — Gates, Milestones, per-milestone features, awaiting-build items — replacing full re-reads of five documents. Also provides the buildable gate used by `/build`.

```bash
bash .claude/scripts/state-status.sh [repo-root]                        # digest
bash .claude/scripts/state-status.sh --check-buildable "Feature NN.M"   # exit 0 iff buildable
```

- A feature is buildable iff its header is `[~]` **and** its block contains the literal phrase `planned, awaiting build`.
- Milestone files are discovered in both the flat (`milestones/*/milestone-status.txt`) and namespaced (`.project/*/milestones/*/milestone-status.txt`) layouts.
- `CC_MILESTONE_GLOB` (space-separated globs, evaluated from the repo root) overrides discovery.

## check.sh

Self-test harness for the whole toolkit: `bash -n` on every shell script, `node --check` on the hooks, jq verdict-parsing fixtures for codex-review, state-status fixtures in both layouts, heredoc-hook deny/allow fixtures, run-quiet exit-code tests, and branch-sync base-resolution tests.

```bash
bash scripts/claude-toolkit/check.sh   # bundle layout (this repository)
bash .claude/scripts/check.sh          # installed layout (consumer repository)
```

Exit 0 iff every fixture passes. The installer behavior itself is covered separately by `tests/installer-claude-toolkit.bats`.

## Hooks

### block-heredoc-commit.js — `PreToolUse` / `Bash`

Parses the proposed Bash command; if it is a `git commit` using a heredoc or an `-m` argument containing a newline, returns `permissionDecision: deny` with guidance to use `gcommit` / `git commit -F`. Unparseable input never blocks (fails open). Timeout 5s.

### lint-md-on-edit.js — `PostToolUse` / `Edit|Write`

When the edited file ends in `.md`/`.markdown`, runs `markdownlint-cli2 --fix` on it (path resolved absolute to guard against leading-`-` filenames). Silent and non-blocking; a missing `markdownlint-cli2` binary is a silent no-op — the hook calls the bare binary with no `npx` fallback by design (a PostToolUse hook must be fast and silent). Timeout 15s.

## Environment variables

| Variable | Used by | Effect |
|---|---|---|
| `CC_BASE_BRANCH` | branch-sync.sh | Overrides base-branch resolution (highest precedence) |
| `CC_MILESTONE_GLOB` | state-status.sh | Overrides milestone-status file discovery globs |
| `TMPDIR` | run-quiet.sh, check.sh | Log/fixture location (defaults to `/tmp`) |
