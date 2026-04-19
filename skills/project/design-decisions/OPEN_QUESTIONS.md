# Project Skill — Open Questions

> Unresolved design questions that need decisions before implementation.
> Each question references the design decisions it affects in [DESIGN.md](../DESIGN.md).

## ~~OQ-1: State file format~~ — RESOLVED

**Decision:** Plain text (`progress.txt`), extending existing conventions.

**Rationale:** Text wins on human editability (UR-2), model write safety (UR-4, UR-5), token
efficiency (NFR-2), and backward compatibility (NFR-1). YAML's structured key-path precision
does not outweigh the continuous corruption risk from indentation-sensitive writes by the model.

**Analysis:** See [progress-file/](progress-file/) — REQUIREMENTS.md, CASE_FOR_YAML.md,
CASE_FOR_TEXT.md, TEXT_vs_YAML_REPORT.md.

**Affected:** DD-5 updated, artifact details and schema in DESIGN.md updated.

---

## ~~OQ-2: Relationship to existing `create-prd` users~~ — RESOLVED

**Decision:** Coexist. `create-prd` remains untouched as a standalone skill. A new `/define`
skill is forked from `create-prd` and refined for the milestone-based, gate-driven pipeline.

**Rationale:** `create-prd` serves users who want a traditional monolithic PRD without the full
orchestrated workflow. The `/define` skill adapts its interview process and output format for
the pipeline context (codebase assessment, Working Backwards, milestone-scoped features).

**Affected:** DD-4 revised — now seven components (one skill per gate, plus `/spike`, `/build`, and the `/project` router).

---

## ~~OQ-3: Feature granularity within milestones~~ — RESOLVED

**Decision:** Three-level hierarchy with concrete sizing constraints:

- **Milestone** — deployable increment of user-visible value, 2–5 features
- **Feature** — testable, reviewable unit mapping to a PR boundary. Requires: passing test
  command, documentation, CI/CD pass (if used). PR is suggested, not required to proceed.
- **Sub-Feature (Task)** — committable change within a single `/build` session. Sized to fit
  within 60% of a 200k-token model (~120k tokens). Larger models provide buffer, not a larger
  sizing target.

Testing: planned during `/plan-feature` (Gate 4), executed during `/build`. Feature plan includes a
`Test Command:` field (single command, pass/fail). Agent generates initial tests; users are
expected to review and adjust. No separate testing phase or skill.

Sub-features tracked as a checklist in the feature plan, not separate artifact files.

**Affected:** DD-1 rewritten as "Three-level work hierarchy." DD-12 added for testing approach.
Feature plan artifact updated with Sub-Features checklist, Test Command, and Documentation
sections.

---

## ~~OQ-4: Direct phase skill invocation~~ — RESOLVED

**Decision:** No. `/project` is the only entry point. Phase skills are not invoked directly.

Users can skip optional stages *within* the orchestration (e.g., skip Working Backwards at
Gate WB), but they cannot bypass the orchestrator to run `/define`, `/design`, `/milestone`,
`/plan-feature`, or `/build` independently. This ensures gate integrity — no phase runs without the
orchestrator confirming preconditions are met.

**Affected:** DD-3 tradeoff updated to reflect mandatory orchestrator entry.

---

## ~~OQ-5: Codebase assessment freshness~~ — RESOLVED

**Decision:** Three refresh triggers:

1. **Project start** — full assessment at Gate 0 (existing behavior)
2. **Each new feature** — `/build` refreshes the assessment automatically when starting a new
   feature, catching changes from prior features, external contributions, or code changes
   after context clearing
3. **On-demand** — user can request a refresh at any time to safeguard against untracked
   external changes

Milestone boundaries do not trigger a refresh — working within a milestone does not
significantly change the codebase relative to the feature-level refresh cadence.

**Affected:** `docs/codebase-assessment.md` lifecycle updated in DESIGN.md.

---

## ~~OQ-6: PRD growth across milestones~~ — RESOLVED

**Decision:** The PRD does not grow. It is a fixed-size strategic document containing project-level
goals, non-goals, risk assessment, and 1–2 sentence summaries per milestone. All milestone detail
(features, acceptance criteria, ordering, sizing) lives in the milestone's own README file
(`milestones/<NN>-<name>/README.md`).

No archiving is needed. Completed milestones get a `[COMPLETE]` marker on their summary line
in the PRD. The milestone directory is already self-contained.

**Affected:** `prd.md` artifact updated — Features section replaced with Milestones summary
section. Milestone README artifact updated to own feature-level detail including acceptance
criteria.

---

## ~~OQ-7: Offline review workflow~~ — RESOLVED

**Decision:** Yes. Each gate produces a structured review checklist (4–6 items) specific to
that gate's concerns. The checklist guides offline reviewers on what to evaluate, ensuring
consistent feedback across sessions and reviewers.

**Affected:** DD-13 added to DESIGN.md with per-gate checklists.

---

## ~~OQ-8: Multi-user coordination~~ — RESOLVED

**Decision:** Out of scope. Multi-user coordination is handled by business processes and
standard git workflows. The skill does not implement conflict resolution or locking mechanisms
for the state file.

**Affected:** None — no design changes needed.
