# PRD: Rules Template Corrective Actions

## Summary
Targeted fixes to three rules templates in `rules/` based on a validation review. Each rule was assessed for whether it achieves its stated intent when loaded as always-on context in a Claude Code session. Three rules need corrective action; three passed clean (kubernetes, cdk, terraform).

## Goals
- Eliminate contradictions between related rules files
- Make the defensive protocol portable across any project (no hardcoded paths)
- Balance stringent anti-slop guardrails with practical efficiency
- Decouple defensive protocols from CLAUDE.md — each rule file must be self-contained

## Architecture
Content changes to existing markdown files in `rules/`, plus three new files for the defensive protocol v2 split. Original defensive-protocol.md is preserved alongside.

### Files Modified
- `rules/crossplane-best-practices.md` — renamed to `rules/crossplane-v1-best-practices.md`

### Files Created
- `rules/defensive-protocol-v2-anti-slop.md`
- `rules/defensive-protocol-v2-epistemology.md`
- `rules/defensive-protocol-v2-session-management.md`

### Files Preserved (no changes)
- `rules/crossplane-v2-best-practices.md`
- `rules/kubernetes-best-practices.md`
- `rules/cdk-best-practices.md`
- `rules/terraform-best-practices.md`
- `rules/defensive-protocol.md` (original v1, kept as reference)

## Non-Goals
- Rewriting rules that passed review (kubernetes, cdk, terraform)
- Changing the rules content model or directory structure
- Converting any rules to skills
- Modifying crossplane-v2-best-practices.md context footprint (accepted as-is)

---

## Feature 1: Rename Crossplane v1 Rules File

**Problem:** `crossplane-best-practices.md` contains v1-specific statements (e.g., "XRs are cluster-scoped") that contradict `crossplane-v2-best-practices.md`. Consumers may load the wrong file.

**Fix:** Rename `crossplane-best-practices.md` to `crossplane-v1-best-practices.md`.

**Acceptance Criteria:**
- File renamed from `crossplane-best-practices.md` to `crossplane-v1-best-practices.md`
- Title inside the file updated to "Crossplane v1 Best Practices"
- Description updated to clarify this targets Crossplane v1 projects
- No content changes beyond title/description — the v1 content is correct for v1
- Verify no other files in the repo reference the old filename

---

## Feature 2: Defensive Protocol v2 — Anti-Slop Discipline

**Problem:** The original defensive-protocol.md interleaves critical guardrails with heavy process, making it likely Claude selectively ignores parts — including the most important ones.

**Fix:** Extract the core anti-slop guardrails into a focused, front-loaded rule file.

**Content sourced from original sections:**
- Core Principle (reality as arbiter)
- Failure Response (stop, report, wait)
- Confusion Response (stop, identify, log)
- Evidence Standards (belief vs verified)
- Verification Cadence — the action count and "when to verify" (contextual: 3 risky / 5 routine). Note: the checkpoint *mechanism* (what to write, how to verify) lives in session-management.
- Error Handling (let it crash)
- Autonomy Boundaries (autonomy check)
- Contradiction Handling
- Pushing Back
- Stop/Undo/Revert Commands
- Claude-Specific Guidance
- Second-Order Effects

**Design Decisions:**
- Verification cadence: 3 actions for unfamiliar/risky work, 5 for established patterns
- Generic path references only — no `agents/memory/` hardcoded paths
- Confusion Response logging: "write to a scratch file" not "append to agents/memory/corrections.md"
- Self-contained — must not assume any CLAUDE.md content exists
- This file carries the "teeth" of the guardrail — it should be the one consumers adopt if they only pick one

**Acceptance Criteria:**
- File created at `rules/defensive-protocol-v2-anti-slop.md`
- No YAML frontmatter (rules format)
- All listed sections adapted and included
- No hardcoded file paths — use generic references
- Verification cadence uses contextual 3/5 model
- Self-contained: works without the other two v2 files or any CLAUDE.md

---

## Feature 3: Defensive Protocol v2 — Epistemology

**Problem:** The prediction protocol and investigation methodology are valuable but create overhead when applied to every action. Needs tiered application.

**Fix:** Extract epistemological framework into its own rule with a tiered prediction protocol.

**Content sourced from original sections:**
- Prediction Protocol (tiered: light for routine, full for high-risk)
- Investigation Protocol (separate facts from theories, competing hypotheses)
- Root Cause Analysis (immediate, systemic, root)
- Chesterton's Fence (understand before changing)
- Abstraction Timing (3 examples before abstracting)
- Codebase Navigation (CLAUDE.md > README > code)

**Design Decisions:**
- Tiered prediction protocol:
  - Routine actions: one-liner stating intent ("Reading config to check X")
  - High-risk actions (destructive, irreversible, ambiguous): full DOING/EXPECT/IF MATCH/IF MISMATCH format
  - Define what qualifies as "high-risk" explicitly
- Investigation protocol: generic path references ("create a scratch investigation file") not `agents/investigations/[topic].md`
- Self-contained — works independently of the anti-slop and session-management files

**Acceptance Criteria:**
- File created at `rules/defensive-protocol-v2-epistemology.md`
- No YAML frontmatter (rules format)
- Prediction protocol clearly defines two tiers with examples
- "High-risk" actions explicitly enumerated (not left vague)
- Investigation protocol uses generic file references
- Self-contained: works without the other two v2 files

---

## Feature 4: Defensive Protocol v2 — Session Management

**Problem:** Checkpoint, handoff, and context window management instructions reference hardcoded paths that most consumer projects won't have.

**Fix:** Extract session state management into its own rule with portable path references.

**Content sourced from original sections:**
- Verification Cadence — the checkpoint *mechanism* (what to write at a checkpoint, how to verify). Note: the action count trigger (3/5) lives in anti-slop.
- Context Window Management (every ~10 actions checkpoint)
- Handoff Protocol (state of work, blockers, open questions)
- Irreversible Actions (extra caution list)

**Design Decisions:**
- All file references generic: "write current state to a checkpoint file" not `agents/memory/checkpoint.md`
- Handoff protocol: describe the information to capture, not where to put it
- Context window section: keep the degradation signals list (sloppy output, uncertain goals, repeated work) — these are highly actionable
- Self-contained — works independently of the other two v2 files

**Acceptance Criteria:**
- File created at `rules/defensive-protocol-v2-session-management.md`
- No YAML frontmatter (rules format)
- Zero hardcoded file paths
- Handoff protocol captures all five information categories from original
- Context window degradation signals preserved
- Self-contained: works without the other two v2 files

---

## Input Variables
None — these are static content files.

## Outputs
- 1 renamed file
- 3 new rule files
- 0 deleted files
