# Scripts Reference

Scripts are repo tooling bundles — shell scripts and supporting assets that perform automated workflows. Unlike commands and skills, scripts are not drop-in Claude Code content; they are copied into a repository's `scripts/` directory and invoked directly from the shell.

For Claude Code commands (slash-command markdown files), see [COMMANDS.md](COMMANDS.md).
For Claude Code skills (SKILL.md bundles), see [SKILLS.md](SKILLS.md).

## Quick Reference

| Script Bundle | Purpose | Details |
|---|---|---|
| Benchmark | Measure whether a skill produces better output than a baseline or previous version; issue a scored promotion verdict | [View](scripts/benchmark/README.md) |
| Agent Delegation | Install the `agent-delegation` rule and its `UserPromptSubmit` hook into a target Claude Code project | [View](scripts/agent-delegation/README.md) |
| Defensive Protocol v2 | Install the Defensive Protocol v2 rules (anti-slop/epistemology/session-management trio + over-engineering gate) plus the hooks that enforce them (chmod hard-block, destructive-command gate, overwrite reminder, failure reminder, over-engineering pre-build reminder) into a target project | [View](scripts/defensive-protocol/README.md) |

## How Scripts Work

- Script bundles live in `scripts/<name>/` at the repository root
- Consumers copy the entire bundle to `scripts/<name>/` in their target repository
- Each bundle contains shell scripts plus a `README.md` entry point
- Scripts are invoked directly with an explicit interpreter — never via `./` or executable bit:

```bash
bash scripts/<name>/<script>.sh [flags]
```

### Bundle Structure

```
scripts/<name>/
├── README.md          ← entry point: quick start, modes, link to docs/
├── *.sh               ← shell scripts (portable, bash 4+)
└── docs/              ← detailed documentation (setup, lifecycle, reference, rubric)
    ├── README.md
    ├── SETUP.md
    ├── LIFECYCLE-GUIDE.md
    ├── USER-GUIDE.md
    ├── REFERENCE.md
    └── RUBRIC-GUIDE.md
```

## Benchmark

Validates and compares Claude Code skills using a scored rubric. Runs a skill definition against three standardised test briefs, scores outputs across seven dimensions (max 63 points), and produces a `decision.md` with a threshold-based verdict.

**Scripts:** `run-benchmark.sh`, `run-variance.sh`
**Documentation:** [scripts/benchmark/README.md](scripts/benchmark/README.md)

### Modes at a Glance

| Mode | Use when |
|------|----------|
| Baseline | New skill — does it improve on the unguided model? |
| Git main comparison | Revised skill on a branch — compare against the last committed version |
| Champion vs. Challenger | Compare any two explicit skill files |

### Verdicts at a Glance

| Verdict | Meaning |
|---------|---------|
| `PROMOTE` | Skill clears the threshold above the unguided baseline |
| `NO VALUE` | No measurable improvement over the unguided model |
| `REJECT` | Unguided model outperforms the skill |
| `SWITCH RECOMMENDED` | Challenger meaningfully beats the current version |
| `NO CHANGE` | Delta below threshold — insufficient evidence to switch |
| `CHAMPION CONFIRMED` | Current version outperforms the challenger |

For full documentation — setup, lifecycle, flags, scoring, and rubric customisation — see [docs/scripts/benchmark/](scripts/benchmark/).

## Agent Delegation

Installs the companion `agent-delegation` rule (`rules/agent-delegation.md`) into a target Claude Code project, along with the `UserPromptSubmit` hook that makes the delegation matrix consulted reliably. Without the hook, the rule is passive context — the hook fires deterministically when the user's prompt matches bulk-work keywords and injects a one-line reminder before the agent picks its first tool.

**Scripts:** `install.sh`
**Documentation:** [scripts/agent-delegation/README.md](scripts/agent-delegation/README.md)
**Companion rule:** [docs/rules/agent-delegation.md](rules/agent-delegation.md)

### Effects on the Target

| Path | Result |
|------|--------|
| `<target>/.claude/rules/agent-delegation.md` | Copied (added \| updated \| unchanged) |
| `<target>/.claude/settings.json` | Hook merged (added \| already installed); existing keys preserved; created with `{}` if missing |

The installer is idempotent — re-running does not duplicate the hook. Idempotency is keyed off the marker `# agent-delegation-hook v1` on the first line of the hook command. Bump the marker (`v1` → `v2`) in `install.sh` to force a re-install when changing keywords or reminder text.

## Defensive Protocol v2

Installs the Defensive Protocol v2 rules (`rules/defensive-protocol-v2-{anti-slop,epistemology,session-management,over-engineering}.md`) into a target project **along with the hooks that enforce them**. The rules alone are self-applied behavioral guidance; the hooks make the high-risk guardrails deterministic — they fire before the agent acts, regardless of whether the rule text was consulted.

**Scripts:** `install.sh`, `test.sh`, `eval/run-trials.sh`, `eval/score-transcript.sh`
**Documentation:** [scripts/defensive-protocol/README.md](scripts/defensive-protocol/README.md)
**Companion rules:** [docs/rules/defensive-protocol-v2-anti-slop.md](rules/defensive-protocol-v2-anti-slop.md), [epistemology](rules/defensive-protocol-v2-epistemology.md), [session-management](rules/defensive-protocol-v2-session-management.md), [over-engineering](rules/defensive-protocol-v2-over-engineering.md)

### Effects on the Target

| Path | Result |
|------|--------|
| `<target>/.claude/rules/defensive-protocol-v2-*.md` | Four rule files copied (added \| updated \| unchanged) |
| `<target>/scripts/defensive-protocol/hooks/*.sh` | Five hook scripts copied |
| `<target>/.claude/settings.json` | Five hook entries merged; existing keys preserved; created with `{}` if missing |
| `<target>/CLAUDE.md` | Active-Rules sentinel block appended (created if missing) |
| `<target>/agents/{investigations,memory}/` | State directories created |

### Hooks Installed

| Hook | Event / Matcher | Behavior |
|------|-----------------|----------|
| `chmod-block.sh` | `PreToolUse` / `Bash` | Hard-block (`exit 2`) on `chmod +x` and exec-bit modes |
| `high-risk-gate.sh` | `PreToolUse` / `Bash` | `permissionDecision: ask` on `rm -rf`, force push, `reset --hard`, `rebase`, `branch -D`, `commit --amend`, `DROP`, `migrate` |
| `pre-write.sh` | `PreToolUse` / `Edit\|Write\|mcp__.*` | Advisory overwrite/delete reminder (does not block) |
| `failure-reminder.sh` | `PostToolUseFailure` | Two-tier `FAILED/THEORY/PROPOSE` reminder |
| `over-engineering-reminder.sh` | `UserPromptSubmit` / `*` | Injects the 3-clause discriminator reminder on build/implement intent keywords (`implement`, `build`, `develop`, `add a`, `write a`); reminds only, does not detect |

The installer is idempotent — re-running produces an empty diff (verified by `tests/installer.bats` and `tests/installer-over-engineering.bats`). Hook merges are keyed off versioned markers (`# dp2-chmod-block v1`, etc.); the CLAUDE.md block is keyed off the `<!-- BEGIN DEFENSIVE-PROTOCOL-V2 -->` sentinel. Bump a marker suffix (`v1` → `v2`) in `install.sh` to force re-installation.

Requires `jq` (installer + hooks) and, for the test suite, `bats-core`. Verify an install with `bash scripts/defensive-protocol/test.sh`.
