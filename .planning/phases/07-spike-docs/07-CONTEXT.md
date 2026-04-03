# Phase 7: /spike + Docs - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the `/spike` adversarial research skill and complete suite documentation for all 7 skills. `/spike` accepts a research question and tooling list, spawns sequential research and red-team agents, produces a structured spike artifact at `docs/spikes/<topic>.md`, and tracks spike lifecycle in `progress.txt`. Documentation ensures every skill has a detail doc, a SKILLS.md catalog row, and a SKILL.md with `disable-model-invocation: true`.

</domain>

<decisions>
## Implementation Decisions

### Research & red-team flow
- **D-01:** Sequential agent flow — research agent completes first, then red-team agent reviews findings. Ensures red-team has full research context to challenge.
- **D-02:** Final artifact only — both agents run autonomously without user checkpoints. User sees the completed spike doc and can request follow-up.
- **D-03:** Red-team has full tooling — web search, docs, codebase access. Can independently verify claims, find counter-evidence, check version compatibility.
- **D-04:** Comprehensive red-team scope — challenges factual errors, missing alternatives, flawed reasoning, unverified assumptions, version/compatibility issues. Per SPIKE-02 spec.

### Spike invocation UX
- **D-05:** Question + tooling list as inputs — per SPIKE-01, user provides the research question and lists available tooling/libraries to evaluate.
- **D-06:** Prerequisite: progress.txt must exist — requires bootstrapped project (Phase 1). Spikes can happen anytime in the pipeline lifecycle.
- **D-07:** State lifecycle: add `[ ]` entry on creation, mark `[x]` resolved on user signal — per SPIKE-04 and SPIKE-06.
- **D-08:** Follow-up mode re-runs research + red-team on the follow-up question, appends results to Follow-Up Log. Offers resolution after each follow-up. Per SPIKE-05.

### Spike artifact structure
- **D-09:** Fixed sections per SPIKE-03 — Question, Available Tooling, Methodology, Findings, Red-Team Assessment, Recommendation, Status (open/resolved), Follow-Up Log.
- **D-10:** Red-Team Assessment is an equal peer section at the same level as Findings — two perspectives are never merged or suppressed per success criteria.
- **D-11:** Recommendation contains a clear pick with rationale — states the recommended approach, why, and what risks remain after red-team review.
- **D-12:** Follow-Up Log uses dated entries with full findings + red-team assessment per entry. Complete audit trail.

### Documentation gap audit
- **D-13:** Create /spike docs from scratch + verify existing 6 skill docs — write `docs/skills/spike.md` detail doc and SKILLS.md catalog row. Audit existing docs for DOCS-01/02/03 compliance and fix gaps.
- **D-14:** `/project` router's SKILL.md already exists at `skills/project/SKILL.md`. Phase 7 creates `skills/project/spike/SKILL.md`. Verify all 7 have `disable-model-invocation: true` frontmatter.
- **D-15:** Spike detail doc follows same structure as other skill detail docs — Purpose, When to Use, When NOT to Use, Behavior, Artifacts, Skill Files, Related Skills.

### Claude's Discretion
- Research agent prompt design and methodology approach
- Red-team agent prompt design and challenge structure
- Exact sub-agent tooling configuration
- Topic slug generation for file naming (`docs/spikes/<topic>.md`)
- How to detect follow-up mode (existing spike file check, consistent with other skills)
- Spike section within `progress.txt` format details
- Internal session and agent orchestration approach
- How to handle edge cases (no tooling listed, ambiguous questions)
- Documentation audit verification approach and gap-filling strategy

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Spike requirements and design
- `skills/project/DESIGN.md` — Authoritative design decisions DD-1 through DD-13; spike section in progress.txt format
- `.planning/REQUIREMENTS.md` — SPIKE-01 through SPIKE-06 acceptance criteria, DOCS-01 through DOCS-03

### Prior skill implementations (pattern reference)
- `skills/project/build/SKILL.md` — Most recent skill; flow controller pattern, reference file loading
- `skills/project/build/references/` — Reference file organization pattern (build-execution, progress-format, etc.)
- `skills/project/design/SKILL.md` — Sub-agent spawning pattern (Gate 2 architecture scan); model for research/red-team agent spawning

### State file formats
- `skills/project/build/references/progress-format.md` — Progress.txt format spec (to be copied into spike/references/)

### Documentation patterns
- `docs/skills/build.md` — Most recent detail doc; follows Purpose/When to Use/Behavior/Artifacts/Skill Files/Related Skills pattern
- `docs/SKILLS.md` — Catalog table; /spike row to be added

### Existing skill SKILL.md files (for DOCS-03 audit)
- `skills/project/SKILL.md` — Router
- `skills/project/define/SKILL.md` — Define
- `skills/project/design/SKILL.md` — Design
- `skills/project/milestone/SKILL.md` — Milestone
- `skills/project/plan/SKILL.md` — Plan
- `skills/project/build/SKILL.md` — Build

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/project/build/SKILL.md` — Flow controller pattern (~144 lines) with reference file loading, prerequisite validation, state reading. Direct template for `/spike`'s SKILL.md.
- `skills/project/build/references/` — Reference file structure. `/spike` will follow the same decomposition with spike-specific references.
- `skills/project/design/SKILL.md` — Sub-agent spawn pattern for codebase analysis. Model for spawning research and red-team agents.
- `docs/skills/build.md` — Detail doc pattern. Template for `docs/skills/spike.md`.

### Established Patterns
- SKILL.md as flow controller (~150-200 lines) loading reference files from `references/` and templates from `assets/`
- Own copy of `progress-format.md` per skill — no cross-directory reads between skills
- `disable-model-invocation: true` mandatory in frontmatter
- Sub-agent spawning for analysis tasks (used in /define Gate 0, /design Gate 2, /plan Gate 4, /build codebase refresh)
- `AskUserQuestion` for interactive prompts (2-4 options, max 12-char headers)
- Detail docs follow consistent structure across all 6 existing skills
- Catalog row in `docs/SKILLS.md` per skill

### Integration Points
- Reads: `progress.txt` (prerequisite check, spike section), existing spike artifacts (follow-up mode)
- Writes: `docs/spikes/<topic>.md` (spike artifact), `progress.txt` (spike entries — add and resolve)
- `/spike` is the first skill that writes to the Spikes section of `progress.txt`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following the established skill patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 07-spike-docs*
*Context gathered: 2026-04-03*
