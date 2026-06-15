# Architecture and Design: Defensive Protocol v2 — Enforcement Layer

> Authoritative design reference. PRD: `prd.md`. Source analysis: `scratch/defensive-protocol-v2-enhancement-analysis.md`. Red-team report: `docs/red-team/defensive-protocol-v2-enhancement-analysis-01/CONSOLIDATED-REPORT.md`. All Claude Code hook mechanics verified against the live hooks reference (`https://code.claude.com/docs/en/hooks.md`) on 2026-06-15.

## Overview

The Defensive Protocol v2 rule trio is loaded into every session as passive context and is reliably routed around by the model's completion bias. This project adds a **deterministic enforcement layer** that makes the highest-value rules fire at the moment they matter, using Claude Code hooks as the trigger mechanism. The layer has five parts: (1) a `PreToolUse` gate that pauses destructive commands and hard-blocks `chmod +x`; (2) a `PostToolUseFailure` reminder that injects the failure protocol when a tool actually fails; (3) rule-text edits that convert un-trackable action counts into event triggers and add a CLAUDE.md "Active Rules" pointer; (4) an idempotent installer; and (5) a documentation cleanup. The entire hook track is gated behind a **feasibility spike** that must empirically prove a hook changes model behavior before any hook is built — because the enforcement-effectiveness premise is the one thing the source analysis could not verify on paper.

The design's load-bearing constraint, verified against live docs: **`additionalContext` is a reminder Claude reads on the *next* model request — it cannot pause an action.** Only `permissionDecision` (`ask`/`deny`) and `exit 2` stop a `PreToolUse` action before it runs. Likewise, **`PostToolUse` fires on success only**; failures route to the dedicated `PostToolUseFailure` event. The earlier draft of the analysis got both wrong; this architecture is built on the corrected mechanics.

## Component Diagram

```
┌──────────────────────────── consumer repo / .claude ─────────────────────────────┐
│                                                                                    │
│  settings.json ── hooks ───────────────────────────────────────────────────────┐  │
│   PreToolUse  matcher=Bash   if=Bash(rm*),Bash(git push --force*),Bash(git      │  │
│                              reset --hard*),Bash(git rebase*),Bash(git branch    │  │
│                              -D*),Bash(*DROP*),Bash(*drop*),Bash(*migrate*)      │  │
│                              → permissionDecision:"ask"   (PAUSE, user confirm)  │  │
│   PreToolUse  matcher=Bash   if=Bash(chmod*) → jq parse → exit 2 (HARD BLOCK)    │  │
│   PreToolUse  matcher=Edit|Write|mcp__.*     → additionalContext (REMIND)        │  │
│   PostToolUseFailure         → additionalContext  FAILED/THEORY/PROPOSE          │  │
│  ───────────────────────────────────────────────────────────────────────────────┘ │
│        │ reads (on stop / next request)                                            │
│        ▼                                                                            │
│  rules/{anti-slop,epistemology,session-management}.md   (== .claude/rules, byte ID)│
│  CLAUDE.md  ── "Active Rules" sentinel block + agents/ path convention             │
│  agents/{investigations,memory}/   (installer mkdir -p)                            │
└────────────────────────────────────────────────────────────────────────────────────┘
            ▲ installed by scripts/defensive-protocol/install.sh  (jq merge, markers,
            │ CLAUDE.md sentinel, prereq hard-fail, mkdir, atomic temp write)
   ┌────────┴──────────────────────────────────────────────────────┐
   │ FEATURE 2 SPIKE — temp/ disposable repo, claude -p headless,   │
   │ 5-trial quick gate. GO ⇒ build hooks. KILL ⇒ stop + redesign.  │
   └────────────────────────────────────────────────────────────────┘
```

## Data Flow

**High-risk Bash command (e.g. `rm -fr build/`):**

1. Model issues a `Bash` tool call. Claude Code evaluates `PreToolUse` hooks.
2. The `if` permission-rule condition (`Bash(rm*)`) matches → the hook runs.
3. Hook emits `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"…state DOING/EXPECT/IF MISMATCH"}}`.
4. Claude Code surfaces a confirm prompt **before** the command runs. The model cannot batch past it.
5. The reason text + the loaded `epistemology` rule prompt the prediction; the user confirms or denies.

**`chmod +x` (hard block):**

1. `PreToolUse` `if=Bash(chmod*)` matches → hook parses the command with `jq` from stdin.
2. If the command sets an executable bit (symbolic `+x`/`u+x`/`+rx` or numeric odd-exec mode), the hook writes guidance to stderr and `exit 2`.
3. Claude Code blocks the tool call; stderr is shown to the model (anti-slop Script Safety).

**Tool failure (e.g. a failing test command):**

1. The Bash tool runs and exits non-zero. Claude Code fires `PostToolUseFailure` (NOT `PostToolUse`).
2. Hook reads `error`/`tool_name`/`tool_input`, emits `additionalContext` with the two-tier FAILED/THEORY/PROPOSE reminder.
3. The model reads it on the next request — appropriate, since the failure has already happened and the protocol is "stop and report," not "prevent."

**Native-tool overwrite (`Write` to an uncommitted file):** `PreToolUse matcher=Edit|Write|mcp__.*` injects a reminder (advisory only in v1 — a precise low-false-positive block condition is deferred).

## Component Inventory

| # | Component | Type / Technology | Purpose |
|---|-----------|-------------------|---------|
| 1 | High-risk Bash gate | `PreToolUse` hook, jq, `if` rules | Pause destructive commands (`ask`) |
| 2 | chmod hard-block | `PreToolUse` hook, jq, `exit 2` | Block executable-bit changes |
| 3 | Native-tool reminder | `PreToolUse` hook, `Edit\|Write\|mcp__.*` | Advisory on overwrite/delete |
| 4 | Failure reminder | `PostToolUseFailure` hook, jq | Inject FAILED/THEORY/PROPOSE |
| 5 | Rule trio (edited) | Markdown (`rules/`, `.claude/rules/`) | Behavioral text, count→event |
| 6 | CLAUDE.md Active-Rules block | Markdown + sentinel | Salience pointer + path convention |
| 7 | State dirs | `agents/{investigations,memory}/` | Homes for investigation/checkpoint/handoff |
| 8 | Installer | `scripts/defensive-protocol/install.sh` (bash + jq) | Idempotent wiring into consumer repo |
| 9 | Mechanical test suite | `bats-core` | Deterministic hook + installer tests |
| 10 | Behavioral eval harness | `claude -p` headless + transcript parser | Probabilistic fire-rate measurement |
| 11 | Spike harness | `temp/` repo + bash | GO/NO-GO feasibility proof |

## Security Model

### Access Control

Hooks run local shell with the user's privileges. The gate **reduces** risk (it cannot escalate). `permissionDecision: "ask"` routes through Claude Code's existing permission UI; the hook does not bypass it.

### Edge Protection

The `chmod +x` hard-block (`exit 2`) is the only deny-by-default control, deliberately narrow (anti-slop Script Safety is unambiguous; destructive commands use `ask` to avoid blocking legitimate work).

### Audit and Logging

Spike and eval transcripts are archived under `agents/investigations/`. Hook decisions are visible in the Claude Code transcript. No secrets are read or written by any hook.

### Input Handling (hook payloads)

Hooks parse untrusted tool-input JSON from stdin with `jq` (no `eval` of command strings). The command string is **matched**, never executed, by the hook. `jq` failure is fail-loud, never swallowed.

## File Organization

```
project-root/
├── prd.md                                   # requirements
├── docs/
│   ├── ARCHITECTURE_AND_DESIGN.md           # this file
│   └── red-team/…                            # red-team report (source)
├── scratch/
│   └── defensive-protocol-v2-enhancement-analysis.md   # source analysis
├── rules/                                   # canonical rule sources (edited in F3.3)
│   └── defensive-protocol-v2-*.md
├── .claude/
│   ├── rules/defensive-protocol-v2-*.md     # installed copies (byte-identical)
│   └── settings.json                         # hooks merged here (F3.1/3.2)
├── scripts/defensive-protocol/
│   ├── install.sh                            # idempotent installer (F4.1)
│   ├── hooks/                                # hook command scripts (jq)
│   │   ├── high-risk-gate.sh
│   │   ├── chmod-block.sh
│   │   └── failure-reminder.sh
│   ├── test.sh                               # local one-command test entry point (F6.1)
│   └── eval/                                 # behavioral eval harness (F6.1)
│       ├── run-trials.sh                     # claude -p headless, N trials
│       └── score-transcript.* 
├── tests/                                    # bats suites (F6.1)
│   ├── hooks.bats
│   └── installer.bats
├── temp/                                     # disposable spike repo (gitignored)
└── agents/{investigations,memory}/          # state homes (installer mkdir)
```

## Configuration

### Required

| Parameter | Type | Validation | Description |
|-----------|------|------------|-------------|
| target repo path | path arg | must be a dir containing/creating `.claude/` | consumer repo to install into |

### Optional — Behavior

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `--state-path` | enum | `agents` | `agents` (installer mkdir) or `scratch` |
| `--gate` | enum | `ask` | `ask` (confirm destructive) or `deny` (block); `chmod +x` always `exit 2` |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| merged hook entries | JSON in `.claude/settings.json` | PreToolUse + PostToolUseFailure |
| CLAUDE.md block | sentinel-wrapped markdown | Active-Rules pointer + paths |
| `agents/{investigations,memory}/` | dirs | state homes |
| `agents/investigations/spike-hook-enforcement.md` | markdown | spike transcripts + verdict |
| test report | stdout | bats results + eval fire-rates |

## Matcher Coverage Table (F3.1)

Commands caught by the `PreToolUse` Bash gate vs. known advisory-only misses.

### Caught (hard-blocked or ask-gated)

| Command form | Gate | Script |
|---|---|---|
| `chmod +x`, `chmod u+x`, `chmod a+x`, `chmod g+x`, `chmod +rx`, `chmod +X` | exit 2 | `chmod-block.sh` |
| `chmod 755`, `chmod 700`, `chmod 711`, any numeric mode with odd octal digit | exit 2 | `chmod-block.sh` |
| `rm -rf`, `rm -fr`, `rm -rRfF` (any combo up to 4 chars) | ask | `high-risk-gate.sh` |
| `rm -r -f`, `rm -f -r` (separate flags) | ask | `high-risk-gate.sh` |
| `git push --force`, `git push -f` | ask | `high-risk-gate.sh` |
| `git push --delete` | ask | `high-risk-gate.sh` |
| `git push origin +refspec` (any arg starting with `+`) | ask | `high-risk-gate.sh` |
| `git reset --hard` | ask | `high-risk-gate.sh` |
| `git rebase` (any form) | ask | `high-risk-gate.sh` |
| `git branch -D` (force delete) | ask | `high-risk-gate.sh` |
| `git commit --amend` | ask | `high-risk-gate.sh` |
| `DROP …` / `drop …` (case-insensitive; inside quotes too) | ask | `high-risk-gate.sh` |
| `migrate` / `db:migrate` / `rake … migrate` | ask | `high-risk-gate.sh` |
| `Write`/`Edit`/`mcp__.*` tool calls | reminder (`additionalContext`) | `pre-write.sh` |

### Advisory-only (not caught — documented coverage boundary)

| Command form | Why not caught |
|---|---|
| `rm file.txt` (no recursive/force flags) | Non-recursive single-file rm is not high-risk |
| `alias del='rm -rf'; del dir/` | Alias expansion not visible in the command string |
| `CMD="rm -rf"; $CMD dir/` | Env-indirected commands not visible |
| `base64 -d <<< '...' \| bash` | Obfuscated execution; no matcher can catch |
| `chmod` via Python/Node `os.chmod()` | Not a Bash tool call |
| `git push --force-with-lease` | Safer variant; not gated (has built-in protection) |

## Design Decisions

| # | Decision | Rationale | Alternatives considered |
|---|----------|-----------|-------------------------|
| 1 | Gate high-risk actions with `permissionDecision: "ask"`, not `additionalContext` | Verified: `additionalContext` is read on the *next* model request — it cannot pause a pre-action. `ask` forces a confirm before execution. | `additionalContext` reminder (rejected: post-action); `deny` (rejected as default: too much friction for legitimate work) |
| 2 | Hard-block `chmod +x` with `exit 2`, not `ask` | anti-slop Script Safety is unambiguous; `exit 2` blocks `PreToolUse` and shows stderr to the model. The only deny-by-default control. | `ask` (rejected: the rule is absolute, not a judgment call) |
| 3 | Use the `PostToolUseFailure` event for the failure reminder | Verified: `PostToolUse` fires on success only; failures route to `PostToolUseFailure`, which carries the `error` field. | `PostToolUse` (rejected — original analysis error; never fires on failure) |
| 4 | Prefer the hook `if` permission-rule syntax (`Bash(rm *)`) over in-command `case`-globs | Live docs define a Bash-matching table for subcommands/`$()`/backticks; `case`-globs tested as missing `rm -fr`, `git push +main`, lowercase `drop`, `chmod u+x`. | ad-hoc `case` substring globs (rejected: proven coverage holes) |
| 5 | Standardize hooks on `jq`; no python3 at runtime | Installer already needs `jq`; the existing UserPromptSubmit hook uses `jq`. One runtime dependency; removes the python3-absent silent-no-op risk. | python3 (rejected: second dep, and the prior sketch's `2>/dev/null\|\|true` silently disabled enforcement) |
| 6 | Feasibility spike is a hard GO/NO-GO gate (Feature 2), before any hook build | The enforcement-effectiveness premise is unproven on paper (red-team Finding 4). A 5-trial spike converts the central risk to evidence cheaply. | build-then-validate (rejected: risks full build on a false premise) |
| 7 | Spike = 5-trial quick gate; strict ≥90%/20-trial bar deferred to the F6.1 eval | Two-stage: cheap go/no-go first, statistical acceptance later. Avoids paying 20-trial cost before knowing the mechanism wires up at all. | single-pass smoke (weaker); 20-trial spike (slower, premature) |
| 8 | Behavioral acceptance is probabilistic (≥90% consult/pause over ≥20 trials; hard-blocks 100%), not a binary assert | LLM behavior is non-deterministic; a binary unit test would be flaky or false. Fire-rate is the honest metric. | binary pass/fail (rejected: misrepresents non-determinism) |
| 9 | `exit 2` hard-blocks must fire 100% at every tier (spike + eval) | Deterministic shell logic; anything below 100% is a bug, not variance. | thresholded like the behavioral signal (rejected: deterministic control) |
| 10 | State files live under `agents/{investigations,memory}/`, created by `mkdir -p` in the installer | Matches the `/handoff`,`/catchup` command-doc conventions; the dirs do not exist today (red-team Finding 9), so the installer must create them. | `scratch/` only (simpler but diverges from commands); assume-exists (rejected: failed writes) |
| 11 | Drive the behavioral eval with `claude -p` headless + a transcript parser | Automatable to ≥20 trials/scenario; transcript JSONL gives objective gate-fire / rule-consult signals. | manual review (rejected: subjective, slow); keyword heuristic (kept as a fallback scorer) |
| 12 | Spike runs in a `temp/` disposable repo inside this project | Isolated, nothing pollutes tracked files; `temp/` already exists and is gitignored; transcripts archived back to `agents/investigations/`. | git worktree (more setup); committed fixtures (nested-repo maintenance) |
| 13 | Native-tool (`Write`/`Edit`/MCP) coverage ships as reminder-only in v1 | A precise, low-false-positive *block* condition for "overwrite of an uncommitted file" is undesigned; reminder closes the worst blind spot without false positives. Hard-gate deferred. | hard-gate now (rejected: false-positive risk undesigned); ignore (rejected: largest blind spot) |
| 14 | Installer idempotency via versioned hook markers + a CLAUDE.md begin/end sentinel | Re-runs must not duplicate; the agent-delegation installer already proves the marker+jq-merge pattern. CLAUDE.md needs its own sentinel (second idempotency surface). | blind append (rejected: duplicates on re-run) |
| 15 | Installer is fail-loud on missing `jq` / invalid settings JSON | A silent no-op of the safety layer is the exact failure anti-slop forbids ("silent fallbacks convert hard failures into silent corruption"). | `\|\| true` swallow (rejected: silently disables enforcement) |
| 16 | Count-based cadences rewritten to event triggers in the rule text | The "every N actions" cadence assumes a self-count the model is unlikely to track; events ("after an untested edit", "after a failed call") are self-evident. No counter hook in v1. | counter hook (deferred: concurrency/session-id/reset complexity, verified) |
| 17 | Documentation cleanup (F5.1) is independent of the spike gate | The doc fixes are high-confidence, observed-on-disk facts; they need no enforcement proof and can proceed in parallel. | bundle behind the gate (rejected: needlessly blocks safe work) |
| 18 | Mechanical suite is local-only in v1 (`bash scripts/defensive-protocol/test.sh`); CI parked | User decision; suite is written CI-ready (non-zero exit) so a GitHub Action is a later drop-in. | CI now (deferred); no entry point (rejected: undiscoverable) |
| 19 | Scripts are invoked via interpreter (`bash …`), never `chmod +x` | The project's own anti-slop Script Safety rule; the layer must not violate the rule it enforces. | `+x` scripts (rejected: dogfooding violation) |

## Deployment Workflow (phased — gated)

```
Phase 0  F1  Architecture doc (this file)
Phase 1  F2  SPIKE in temp/ → GO ───────────────┐  (KILL → stop, update F1, consult user)
                                                 ▼
Phase 2  F3.1 high-risk gate   F3.2 failure reminder   F3.3 rule text + CLAUDE.md block
Phase 3  F4.1 installer (mkdir agents/, jq merge, markers, sentinel, prereq check)
Phase 4  F5.1 documentation cleanup            (parallel-safe — not gated by the spike)
Phase 5  F6.1 test suite (bats) + behavioral eval (claude -p, ≥20 trials, ≥90%)
Phase 6  End-to-end: fresh-repo install → trigger scenarios → confirm → idempotent re-install
```

## Dependency Graph

```
F1 architecture
 └── F2 spike (GO) ── gates ──▶ F3.1, F3.2, F3.3
                                   └── F4.1 installer ── depends on ── F3.1/3.2/3.3
                                          └── F6.1 tests/eval ── depends on ── F3.*, F4.1, F2 scenarios
F5.1 docs cleanup  (independent — no spike dependency)
```

## Testing and Validation (design)

- **Tier 0 — Spike (F2, completed):** the F2 feasibility spike used a disposable `temp/` repo (`git init`, wire candidate hooks, 5 trials/scenario via `claude -p`) to prove the gate fired before the full build. Verdict was GO; the spike driver and its candidate hooks (`spike.sh`, `pre-bash.sh`, `post-failure.sh`) were removed post-GO as dead scaffolding — results archived to `agents/investigations/spike-hook-enforcement.md`. Superseded by the production hooks below.
- **Tier 1 — Mechanical (bats):** `tests/hooks.bats` feeds sample stdin payloads per high-risk command, asserts emitted `permissionDecision`/`exit 2`/`additionalContext`; negative tests for documented misses; success-payload test asserts no failure-reminder. `tests/installer.bats` asserts twice-run empty diff and loud exit on missing `jq`/invalid JSON. Rule-sync test: `diff rules/ .claude/rules/`.
- **Tier 2 — Behavioral (eval):** `scripts/defensive-protocol/eval/run-trials.sh` drives ≥20 `claude -p` trials/scenario; `score-transcript` extracts gate-fire / DOING-EXPECT / FAILED-THEORY-PROPOSE signals; reports per-scenario fire-rate vs. ≥90% (hard-blocks 100%).
- **Tier 3 — End-to-end:** fresh repo, one `install.sh`, trigger each scenario once, confirm via transcript, re-install → empty diff.
- **Entry point:** `bash scripts/defensive-protocol/test.sh` runs Tier 1 (+ Tier 3 smoke); Tier 2 documented and run on demand (cost).

## Out of Scope

| Item | Rationale |
|------|-----------|
| Forcing the model to emit prediction text | Hooks stop/block actions; they cannot compel model output (verified). Prediction stays advisory. |
| Catching obfuscated destructive commands | No matcher can (aliases, `base64\|sh`). Coverage boundary published, not hidden. |
| Action-counter hook | Concurrency/session/reset complexity; events used instead. Future enhancement. |
| Native-tool hard-block | Undesigned low-false-positive condition; reminder-only in v1. |
| `kiro/` steering cleanup | Separate subsystem; follow-up sweep. |
| CI wiring | Local-only by decision; suite is CI-ready. |
| Windows / non-POSIX | jq + POSIX shell; macOS/Linux consumers. |
