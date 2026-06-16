# PRD: Defensive Protocol v2 — Enforcement Layer

## Summary

Add a deterministic enforcement layer to the Defensive Protocol v2 rule trio (`anti-slop`, `epistemology`, `session-management`) so the rules actually fire mid-session instead of being passively loaded and routed around. The layer is built from Claude Code hooks (`PreToolUse` gating, `PostToolUseFailure` reminders), a CLAUDE.md "Active Rules" pointer, count→event rule rewrites, an idempotent installer, and a documentation cleanup — all gated behind a **feasibility spike** that must first prove a hook changes model behavior before any hook is built. Source of record: `scratch/defensive-protocol-v2-enhancement-analysis.md` (red-teamed; report at `docs/red-team/defensive-protocol-v2-enhancement-analysis-01/`).

## Goals

- Make the high-risk/irreversible-action protocol fire deterministically: a `PreToolUse` gate that **stops** the action (user confirm) before destructive commands, and a **hard block** (`exit 2`) for `chmod +x`.
- Make the failure protocol fire on actual failures via the correct `PostToolUseFailure` event (not `PostToolUse`, which is success-only).
- Convert un-trackable count-based cadences ("every N actions") into event triggers the model can self-notice.
- Give the rules' file-writing protocols (investigation/checkpoint/handoff) a real, created-to-exist home under `agents/`.
- Ship a single idempotent installer that wires hooks + rules + CLAUDE.md block into any consumer repo, with stated prerequisites and a fail-loud (never silent-no-op) posture.
- Clean up the documentation drift left by the v1 deletion and correct the path/claim errors the red-team surfaced.
- **Prove enforcement effectiveness before committing to it** — a spike with explicit kill criteria gates the whole hook track.
- Treat testing and validation as first-class: every feature carries mechanical test acceptance criteria, and a dedicated validation feature covers the behavioral (transcript-eval) layer.

## Non-Goals

| Item | Rationale |
|------|-----------|
| Forcing the model to *emit* the DOING/EXPECT prediction text | Verified: hooks can stop/block an action but cannot compel model output. The gate forces a pause; the prediction stays advisory in rule text. |
| Catching fully obfuscated destructive commands (aliases, `base64 \| sh`, env-indirected) | No matcher can. Coverage boundary is stated, not hidden. |
| Action-counter hook (hard cadence via temp-file counter) | Concurrency/session-id/reset complexity (verified: hooks run in parallel). Deferred to Future Enhancements; v1 uses event triggers instead. |
| Re-authoring the rule *content* / behavioral philosophy | Content is sound; this project adds mechanism, not new doctrine. |
| `kiro/` steering subtree cleanup | Separate subsystem; out of scope, flagged for a follow-up sweep. |
| Windows / non-POSIX shell support | Hooks are POSIX shell + jq/python3; consumers are macOS/Linux. |

## Architecture

```
                         consumer repo (.claude/)
  ┌─────────────────────────────────────────────────────────────────┐
  │  settings.json (hooks)                 rules/ (behavioral text)   │
  │  ┌───────────────────────────┐         ┌──────────────────────┐  │
  │  │ PreToolUse: Bash           │         │ anti-slop            │  │
  │  │   if Bash(rm*|git push…)   │──ask──▶ │ epistemology         │  │
  │  │   if Bash(chmod*)──exit2─▶ │ block   │ session-management   │  │
  │  │ PreToolUse: Edit|Write|mcp │         └──────────────────────┘  │
  │  │ PostToolUseFailure         │──reminder (FAILED/THEORY/PROPOSE) │
  │  └───────────────────────────┘                                   │
  │  CLAUDE.md  ── "Active Rules" pointer + agents/ path convention   │
  │  agents/{investigations,memory}/   (created by installer mkdir)   │
  └─────────────────────────────────────────────────────────────────┘
        ▲ installed idempotently by scripts/defensive-protocol/install.sh
        │   (jq merge + markers + CLAUDE.md sentinel + prereq check)
   ┌────┴───────────────────────────────────────────────┐
   │ FEATURE 2 SPIKE (GO/NO-GO) gates everything above   │
   │  proves a hook actually changes model behavior      │
   └─────────────────────────────────────────────────────┘
```

## Features

> Phased. **Feature 1** is the architecture doc. **Feature 2.1 (spike) is a hard GO/NO-GO gate** — no Phase 2+ hook work begins until it passes its kill criteria. Documentation cleanup (Feature 5.1) is independent and may proceed in parallel regardless of the spike outcome.

### Feature 1: Architecture and Design Document

Authoritative design reference in `docs/ARCHITECTURE_AND_DESIGN.md`: component inventory, hook contracts, data flow, design decisions (target 10–20), file organization, and the testing/validation strategy.

**Acceptance Criteria:**

- `docs/ARCHITECTURE_AND_DESIGN.md` exists with ≥10 design decisions, each with rationale.
- Every hook's exact event, matcher, `if` condition, output field (`permissionDecision`/`exit 2`/`additionalContext`), and interpreter is specified.
- Cross-references `scratch/defensive-protocol-v2-enhancement-analysis.md` finding IDs and the red-team report.

### Feature 2.1: Feasibility Spike — Hook Enforcement Proof (GO/NO-GO GATE)

Throwaway-repo proof that a wired hook deterministically changes model behavior before a risky action. This is the project's central de-risking step; the entire hook track is gated on it.

**Acceptance Criteria:**

- A disposable test repo wires the candidate `PreToolUse` gate (entries 1+2) and the `PostToolUseFailure` reminder.
- Scripted runs issue: `rm -fr <path>`, `git push --force`, `chmod u+x`, a deliberately failing Bash command, and a native `Write` overwrite of an uncommitted file.
- Transcripts are captured and archived under `agents/investigations/spike-hook-enforcement.md`.
- **Quick gate — 5 trials per scenario.** `permissionDecision: ask` pauses the destructive command before execution; `exit 2` blocks `chmod +x` (must fire **100%** even at the spike stage); `PostToolUseFailure` reminder appears after the failing command; the model visibly consults the rule (states DOING/EXPECT or STOP/REPORT) in the majority of the 5 runs.
- **GO** = mechanism wires up and fires as above across the 5-trial smoke. The strict statistical bar (≥90% over ≥20 trials) is **not** required here — it is deferred to the Feature 6.1 behavioral eval. The spike is a cheap go/no-go, not the final acceptance.
- **KILL criteria (any triggers STOP + redesign):** gate does not fire, model batches past the pause, `exit 2` block fails, or the `additionalContext`/event contract differs from the live docs. On kill, the architecture doc is updated and the user is consulted before proceeding.
- Findings (GO or KILL) recorded with the per-scenario fire-rate actually observed across the 5 trials.

### Feature 3.1: High-Risk PreToolUse Gate

`PreToolUse` hook(s): `permissionDecision: "ask"` on destructive Bash commands (via `if` permission-rule syntax), `exit 2` hard-block on `chmod +x` (symbolic + numeric executable bits), and a reminder on native `Write`/`Edit`/`mcp__.*` overwrite/delete. Stated coverage boundary for un-matchable commands.

**Acceptance Criteria:**

- Hook fires `ask` for: `rm -rf`/`rm -fr`/`rm -r -f`, `git push --force`/`-f`/refspec `+`, `git reset --hard`, `git rebase`, `git branch -D`, `git commit --amend`, `DROP`/`drop` (case-insensitive), `migrate`.
- `chmod +x`, `chmod u+x`, `chmod +rx`, and numeric exec-bit modes are hard-blocked (`exit 2`) with a stderr message pointing to `bash script.sh`.
- A `PreToolUse: Edit|Write|mcp__.*` entry injects an overwrite/delete reminder.
- Matcher coverage table in the architecture doc lists what is caught vs. explicitly advisory-only.
- **Tests:** a `bats` suite feeds sample JSON payloads for every command above and asserts the emitted decision; documented misses (e.g. obfuscated) are negative-test cases.

### Feature 3.2: PostToolUseFailure Reminder Hook

`PostToolUseFailure` hook injecting the two-tier FAILED/THEORY/PROPOSE reminder (one-liner for trivial/expected failures, full template otherwise) using the event's `error`/`tool_name`/`tool_input` fields.

**Acceptance Criteria:**

- Hook is registered on `PostToolUseFailure` (NOT `PostToolUse`).
- Emits `hookSpecificOutput.hookEventName: "PostToolUseFailure"` + `additionalContext` carrying the reminder.
- **Tests:** `bats` cases assert correct output for a failing-Bash payload and that no reminder fires on a *successful* tool payload routed to `PostToolUse`.

### Feature 3.3: Rule Text Updates + CLAUDE.md Active-Rules Block

Edit the three rule files: count→event reframe (verify-on-event, not "every N actions"); two-tier Failure Response; add native-tool overwrite triggers; add the `PreCompact`-aware framing for session-management. Add the CLAUDE.md "Active Rules" pointer block including the soft-rules reminder and the `agents/` path convention.

**Acceptance Criteria:**

- `anti-slop` Verification Cadence and `session-management` Context Window reworded to event triggers; no remaining "every N actions" count language.
- Failure Response is two-tier.
- CLAUDE.md block lists hard behaviors, soft behaviors (autonomy/contradiction/pushing-back/Chesterton), and the three `agents/`+`scratch/` paths.
- `rules/` and `.claude/rules/` copies remain byte-identical after edits (verified by diff).

### Feature 4.1: Idempotent Installer

`scripts/defensive-protocol/install.sh` — copies the trio, merges the hooks into `.claude/settings.json`, appends the CLAUDE.md block, and `mkdir -p agents/{investigations,memory}`, all idempotently and fail-loud.

**Acceptance Criteria:**

- Declares and checks the `jq` prerequisite and hard-fails loudly if absent (no silent `|| true`). Hooks are jq-only — no python3 at runtime.
- Uses versioned hook markers + a CLAUDE.md begin/end sentinel for idempotent re-runs.
- Rejects invalid `.claude/settings.json` before merging; writes atomically via temp file.
- Runs `mkdir -p agents/investigations agents/memory`.
- **Tests:** an idempotency test runs the installer twice and diffs the result (must be empty); a prereq-absence test asserts a loud non-zero exit, not a no-op.

### Feature 5.1: Documentation Cleanup

Resolve the v1-deletion drift and the red-team path/claim corrections (independent of the spike).

**Acceptance Criteria:**

- v1 **retired** (decision): `docs/RULES.md` v1 row + "Evolution" bullet removed; Evolution rewritten as "v2 is the current generation"; no broken `defensive-protocol.md` link remains.
- `docs/rules/defensive-protocol.md` removed or marked historical.
- Shebang contradiction fixed in `docs/rules/defensive-protocol-v2-anti-slop.md` to match the canonical rule.
- Command-doc paths corrected to the real three trees (`commands/`, `docs/commands/`, `.claude/rules/commands/`); `docs/rules/commands/` references removed.
- Banner added to each `docs/rules/*.md` distinguishing description vs. installable rule.
- `epistemology` and `session-management` description files content-checked against canonical sources; any drift fixed or explicitly noted.

### Feature 6.1: Test and Validation Suite (mechanical + behavioral)

Consolidated, runnable validation: the `bats` hook suite, installer idempotency/prereq tests, matcher-coverage tests, and a behavioral transcript-eval harness with a probabilistic acceptance bar.

**Acceptance Criteria:**

- `bats` suite (hooks + installer) runs green via an explicit interpreter (`bash …`, never `+x`).
- Matcher-coverage test enumerates the high-risk command set and asserts caught vs. advisory-only.
- Behavioral eval harness re-runs the spike scenarios over **≥20 trials per scenario** and reports the fire-rate; acceptance bar is **≥90%** consult/pause rate per scenario, with `exit 2` hard-blocks at **100%** (probabilistic, not binary).
- A documented **local one-command entry point** (`make test` or `bash scripts/defensive-protocol/test.sh`) runs the mechanical suite; the behavioral harness is documented and runnable on demand. **No CI wiring in v1** (local-only by decision; GitHub Action parked in Future Enhancements).
- Mechanical suite exits non-zero on any failure (CI-ready even though CI is not wired in v1).

## Configuration

### Required

| Parameter | Type | Description |
|-----------|------|-------------|
| target repo path | path arg to `install.sh` | Consumer repo to install the enforcement layer into |

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `--state-path` | enum | `agents` | `agents` (installer mkdir) or `scratch` (use existing dir) |
| `--gate` | enum | `ask` | `ask` (confirm destructive) vs `deny` (block); `chmod +x` is always `exit 2` |
| parser | (fixed) | `jq` | Hooks standardize on `jq` for payload parsing (consistency with the installer and the existing UserPromptSubmit hook); not user-configurable |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `.claude/settings.json` hook entries | JSON | Merged PreToolUse + PostToolUseFailure hooks |
| CLAUDE.md "Active Rules" block | Markdown | Sentinel-wrapped pointer + path convention |
| `agents/{investigations,memory}/` | dirs | Created state-file homes |
| spike transcripts | Markdown | `agents/investigations/spike-hook-enforcement.md` |
| test report | stdout / file | bats results + behavioral fire-rates |

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Enforcement effectiveness unproven (hooks may not change model behavior) | **Feature 2 spike gates the build** with kill criteria; behavioral eval (F6.1) measures fire-rate. |
| Hook JSON mechanism wrong for current Claude Code | Already re-verified against live hooks docs 2026-06-15; spike re-confirms on real runs; eval pins it. |
| Missing `jq` → silent no-op of safety layer | Fail-loud installer prereq check (F4.1); hooks are jq-only; no `\| true` swallowing. |
| Matcher misses destructive variants → false sense of safety | Use `if` permission-rule syntax + negative tests; publish coverage boundary table. |
| Gate friction / false positives frustrate users | `ask` not `deny` for destructive; `exit 2` only for unambiguous `chmod +x`; tune via gate-strength flag. |
| `agents/` paths don't exist → failed writes | Installer `mkdir -p`; CLAUDE.md documents the convention. |
| Revised analysis doc not re-red-teamed | Spike + tests are the empirical re-check; behavioral eval is the backstop. |
| Native-tool (Write/Edit) overwrite precise block condition undefined | v1 ships reminder-only on Write/Edit; hard-gate deferred until a low-false-positive condition is designed. |

## External Dependencies

| Dependency | Owner | Status |
|------------|-------|--------|
| Claude Code hooks API (event names, fields, `if` syntax) | Anthropic | Verified 2026-06-15 against live docs; re-pin in spike |
| `jq` | consumer machine | Required (hooks + installer); installer checks and hard-fails if absent |
| `bats-core` | dev | Required for the mechanical test suite |
| `python3` | dev | Dev-only — behavioral-eval transcript parser. NOT a hook runtime dependency |
| `claude` CLI (headless `-p`) | dev | Drives the behavioral eval trials |

## Success Criteria

- Spike (F2) returns GO from the 5-trial quick gate (hard-blocks 100%, majority consult), OR returns KILL and the project re-scopes deliberately.
- Behavioral eval (F6.1) meets ≥90% consult/pause over ≥20 trials per scenario, hard-blocks 100%.
- A fresh consumer repo, after one `install.sh` run, shows the gate pausing a destructive command and the failure reminder firing — demonstrated by captured transcript.
- Re-running `install.sh` produces an empty diff (idempotent).
- Mechanical test suite green via the local one-command entry point.
- Documentation cleanup leaves zero broken `defensive-protocol.md` references and zero `docs/rules/commands/` references.

## Testing and Validation Strategy

> First-class per request. Two tiers — mechanical (deterministic, CI) and behavioral (probabilistic, transcript-eval) — plus the spike gate.

**Tier 0 — Feasibility gate (Feature 2):** disposable-repo proof, **5-trial quick gate** per scenario, GO/KILL criteria; `exit 2` hard-blocks must fire 100% even here; archived transcripts. Precondition for all hook features. (Cheap go/no-go; the strict bar lives in Tier 2.)

**Tier 1 — Mechanical (deterministic, CI-able; Features 3–4, consolidated in 6.1):**
- `bats` hook unit tests: feed sample stdin JSON payloads, assert emitted `permissionDecision`/`exit 2`/`additionalContext` for each high-risk command and for failing vs. successful tool payloads.
- Matcher-coverage test: enumerate the high-risk command set; assert caught vs. advisory-only; negative tests for known misses.
- Installer idempotency test: run twice, diff must be empty.
- Installer prereq test: simulate missing `jq`/`python3`; assert loud non-zero exit (not no-op).
- Rule-sync test: `diff rules/ .claude/rules/` byte-identical after edits.

**Tier 2 — Behavioral (probabilistic; Feature 6.1):**
- Transcript-eval harness re-runs the spike scenarios over **≥20 trials/scenario**; reports per-scenario fire-rate (model paused / stated prediction / reported failure).
- Acceptance bar: **≥90%** consult/pause per scenario; `exit 2` hard-blocks **100%**. Treated as an eval, not a binary assert — the fire-rate is documented.

**Tier 3 — End-to-end:** fresh-repo install → trigger each scenario once → confirm via transcript; idempotent re-install. Runs from the local one-command entry point (no CI in v1).

## Future Enhancements

| Enhancement | Description |
|-------------|-------------|
| Action-counter hook | Hard verification cadence via `session_id`-keyed, locked counter with TTL cleanup — once concurrency design is proven. |
| Native-tool hard-gate | Block (not just remind) Write/Edit overwrite of uncommitted files, once a low-false-positive condition is defined. |
| `PreCompact` intent-reconfirm hook | Trigger the session-management intent re-confirmation write on compaction. |
| `kiro/` steering cleanup | Sweep the parallel steering subtree for v1 references. |
| CI wiring | GitHub Action running the mechanical suite on PR — deferred; v1 is local-only by decision. |
