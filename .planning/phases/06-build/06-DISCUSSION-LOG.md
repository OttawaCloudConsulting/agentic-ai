# Phase 6: /build - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-03
**Phase:** 06-build
**Areas discussed:** Sub-feature execution flow, Codebase assessment refresh, Test execution & failure handling, Deviation recording workflow

---

## Sub-feature execution flow

### Checklist handling across invocations

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-resume | Each /build invocation reads the feature plan, finds the first unchecked sub-feature, continues from there. One invocation can complete multiple sub-features. | ✓ |
| One sub-feature per invocation | Each /build call completes exactly one sub-feature, commits, updates state, exits. Maximum control but more overhead. | |
| Explicit targeting | /build takes optional sub-feature argument. Without it, auto-resumes. With it, jumps to specified sub-feature. | |

**User's choice:** Auto-resume (Recommended)

### Context window limit handling

| Option | Description | Selected |
|--------|-------------|----------|
| State-file handoff | Mark completed sub-features [x] in plan, commit, update milestone-status.txt. Next invocation auto-resumes. | ✓ |
| Explicit checkpoint file | Write checkpoint file with in-progress notes, partial work state, next steps. | |
| Just commit and stop | Commit whatever is done, mark completed sub-features. Plan checklist IS the handoff. | |

**User's choice:** State-file handoff (Recommended)

### Commit strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Commit per sub-feature | Each completed sub-feature gets its own commit. Clean git history, easy to bisect. | ✓ |
| Batch at end | Accumulate changes, commit once when feature completes or session ends. | |
| User decides per sub-feature | After each sub-feature, ask whether to commit now or continue. | |

**User's choice:** Commit per sub-feature (Recommended)

### In-session progress display

| Option | Description | Selected |
|--------|-------------|----------|
| Checklist recap after each sub-feature | Show full checklist with [x] marks and announce what's next. | ✓ |
| Minimal — just announce next | Brief "Sub-feature 3 done. Starting sub-feature 4: [name]". | |
| You decide | Claude picks verbosity based on context. | |

**User's choice:** Checklist recap after each sub-feature

---

## Codebase assessment refresh

### Refresh method

| Option | Description | Selected |
|--------|-------------|----------|
| Incremental git-diff update | Check git history since last assessment. Read only changed/new files. Update affected sections. | ✓ |
| Full re-scan via sub-agent | Spawn sub-agent to re-read 20-40 files. Completely fresh assessment. | |
| Hybrid | Default incremental, --full-refresh flag for full re-scan. | |

**User's choice:** Incremental git-diff update (Recommended)

### Refresh timing

| Option | Description | Selected |
|--------|-------------|----------|
| Before reading feature plan | Refresh first so assessment is current when implementation starts. | ✓ |
| After reading plan, before coding | Read plan first to know what areas matter, then targeted refresh. | |
| You decide | Claude picks timing based on feature being built. | |

**User's choice:** Before reading feature plan (Recommended)

### Commit strategy for refresh

| Option | Description | Selected |
|--------|-------------|----------|
| Standalone commit | Commit updated assessment before starting implementation. | ✓ |
| Bundle with first sub-feature | Include assessment update in first sub-feature's commit. | |
| You decide | Claude decides based on how much assessment changed. | |

**User's choice:** Standalone commit (Recommended)

---

## Test execution & failure handling

### Failure response

| Option | Description | Selected |
|--------|-------------|----------|
| Hard stop with diagnosis | Stop, show output, diagnose, present options: fix/re-run, update command, or exit. | ✓ |
| Auto-fix attempt then re-run | Diagnose and fix automatically, re-run. Hard stop on second failure. | |
| Just report and stop | Show output and stop. No diagnosis. | |

**User's choice:** Hard stop with diagnosis (Recommended)

### Test timing

| Option | Description | Selected |
|--------|-------------|----------|
| Feature completion only | Run test command once after all sub-features done. | ✓ |
| After each sub-feature | Run after every sub-feature to catch issues early. | |
| User-triggered | Offer to run tests at any point, user says when. | |

**User's choice:** Feature completion only (Recommended)

### Test command update flow

| Option | Description | Selected |
|--------|-------------|----------|
| Inline during failure handling | When tests fail, "Update test command" is one of the options. Natural flow. | ✓ |
| Proactive offer at feature start | Show planned test command at start, ask if still correct. | |
| You decide | Claude decides when to offer test command updates. | |

**User's choice:** Inline during failure handling (Recommended)

---

## Deviation recording workflow

### Detection method

| Option | Description | Selected |
|--------|-------------|----------|
| Claude detects + user confirms | Claude flags divergence from plan/architecture. User confirms or dismisses. | ✓ |
| User flags only | Claude implements silently. User catches deviations. | |
| Auto-record all deviations | Claude detects and records automatically without asking. | |

**User's choice:** Claude detects + user confirms (Recommended)

### Detail level

| Option | Description | Selected |
|--------|-------------|----------|
| Structured 4-field entry | What changed, what was planned, why changed, impact on other components. Per DESIGN.md. | ✓ |
| Brief one-liner | "Deviated from X to Y because Z". Quick capture. | |
| You decide | Claude decides detail level based on significance. | |

**User's choice:** Structured 4-field entry (Recommended)

### Write timing

| Option | Description | Selected |
|--------|-------------|----------|
| Immediately when detected | Write to plan as soon as confirmed. Committed with the causing sub-feature. | ✓ |
| Batched at feature completion | Accumulate in-session, write all at completion. | |
| You decide | Claude picks based on severity and session state. | |

**User's choice:** Immediately when detected (Recommended)

---

## Claude's Discretion

- Sub-agent prompt for incremental codebase assessment refresh
- Git log strategy for detecting changed files since last assessment
- Commit message format for sub-feature commits
- Deviation detection heuristics (comparing implementation to architecture doc)
- Internal session progress tracking
- Edge case handling for ambiguous sub-feature boundaries

## Deferred Ideas

None — discussion stayed within phase scope.
