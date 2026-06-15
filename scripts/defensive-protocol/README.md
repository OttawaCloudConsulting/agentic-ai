# Defensive Protocol v2 — Enforcement Layer

Installs the Defensive Protocol v2 rule trio **and** the Claude Code hooks that enforce it into a
target project. The rules alone are self-applied behavioral guidance; the hooks make the
high-risk guardrails deterministic — `chmod +x` is hard-blocked, destructive Bash commands pause
for confirmation, native-tool overwrites get an advisory reminder, and tool failures inject a
STOP/FAILED reminder.

## Quick Start

```bash
bash scripts/defensive-protocol/install.sh <target-repo-path>
```

Restart Claude Code in the target repo afterwards so the rules and hooks load.

## Prerequisites

`jq` — required by both the installer and the hook scripts. The installer hard-fails loudly if it
is absent (Design Decision #15). `bats-core` is required only to run the test suite.

```bash
brew install jq          # macOS
sudo apt-get install jq  # Debian/Ubuntu
```

## What It Installs

| Path in target | Result |
|---|---|
| `.claude/rules/defensive-protocol-v2-{anti-slop,epistemology,session-management}.md` | Rule trio copied (added \| updated \| unchanged) |
| `scripts/defensive-protocol/hooks/*.sh` | Four hook scripts copied |
| `.claude/settings.json` | Four hook entries merged via `jq` (existing keys preserved; created as `{}` if missing) |
| `CLAUDE.md` | Active-Rules sentinel block appended (created if missing) |
| `agents/investigations/`, `agents/memory/` | State directories created |

## Hooks

| Hook | Event / Matcher | Behavior |
|---|---|---|
| `chmod-block.sh` | `PreToolUse` / `Bash` | **Hard-block (`exit 2`)** on `chmod +x`, `u+x`, `+rx`, numeric exec bits, and symbolic assignment modes that set exec (e.g. `u=rwx`, `a=rx`). Redirects to `bash script.sh`. |
| `high-risk-gate.sh` | `PreToolUse` / `Bash` | **`permissionDecision: ask`** on `rm -rf`, `git push --force`/`-f`, `git reset --hard`, `git rebase`, `git branch -D`, `git commit --amend`, `DROP` (case-insensitive), `migrate`. |
| `pre-write.sh` | `PreToolUse` / `Edit\|Write\|mcp__.*` | Advisory overwrite/delete reminder (`additionalContext`). Does not block. |
| `failure-reminder.sh` | `PostToolUseFailure` | Two-tier reminder: STOP one-liner for short errors, full `FAILED/THEORY/PROPOSE` template for substantive ones (≥80 chars). |

## Idempotency

Re-running the installer produces no changes — verified by `tests/installer.bats`. Hook merges are
keyed off versioned markers (`# dp2-chmod-block v1`, etc.) on the first line of each hook command;
the CLAUDE.md block is keyed off the `<!-- BEGIN DEFENSIVE-PROTOCOL-V2 -->` sentinel. Bump a marker
suffix (`v1` → `v2`) in `install.sh` to force re-installation after changing hook behavior.

## Testing

```bash
# Tier 1 — mechanical (bats hook tests + installer tests + rule-sync diff)
bash scripts/defensive-protocol/test.sh

# Tier 2 — behavioral eval (headless `claude -p`, ≥20 trials/scenario; run on demand — costs sessions)
bash scripts/defensive-protocol/eval/run-trials.sh [--trials N]
```

Tier 1 requires `bats-core` and `jq`. Tier 2 additionally requires the `claude` CLI and `git`, and
writes its report to `agents/investigations/eval-results.md`.

## Bundle Contents

```
scripts/defensive-protocol/
├── README.md            ← this file
├── install.sh           ← idempotent installer (F4.1)
├── test.sh              ← Tier 1 mechanical test entry point (F6.1)
├── hooks/
│   ├── chmod-block.sh
│   ├── high-risk-gate.sh
│   ├── pre-write.sh
│   └── failure-reminder.sh
└── eval/                ← Tier 2 behavioral eval harness (F6.1)
    ├── run-trials.sh
    └── score-transcript.sh
```

## Script Safety

Every script in this bundle is invoked with an explicit interpreter (`bash script.sh`) and never
carries the executable bit (Design Decision #19). The `chmod-block.sh` hook enforces this for the
whole target project.

## See Also

- Rule descriptions: [`docs/rules/defensive-protocol-v2-anti-slop.md`](../../docs/rules/defensive-protocol-v2-anti-slop.md), [`epistemology`](../../docs/rules/defensive-protocol-v2-epistemology.md), [`session-management`](../../docs/rules/defensive-protocol-v2-session-management.md)
- Design spec: [`docs/ARCHITECTURE_AND_DESIGN.md`](../../docs/ARCHITECTURE_AND_DESIGN.md)
- Scripts index: [`docs/SCRIPTS.md`](../../docs/SCRIPTS.md)
