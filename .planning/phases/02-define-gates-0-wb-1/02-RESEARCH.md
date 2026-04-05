# Phase 2: /define (Gates 0/WB/1) - Research

**Researched:** 2026-04-02
**Domain:** Markdown-only skill authoring (prompt engineering, no application code)
**Confidence:** HIGH

## Summary

Phase 2 delivers a single invokable skill at `skills/project/define/SKILL.md` that runs Gates 0, WB, and 1 as one continuous session. The skill is markdown-only (prompt instructions, not compiled code) and follows the established skill bundle pattern from Phase 1. The primary technical challenge is decomposing the workflow across a ~300-line SKILL.md and multiple reference files while keeping the per-gate logic self-contained and the flow between gates seamless.

The fork source is `skills/create-prd/` -- its SKILL.md structure, interview guide, and PRD template provide the foundation for Gate 1. Gates 0 and WB are net-new capabilities. The existing `/project` SKILL.md demonstrates the reference-loading pattern (read external spec files at the step that needs them) that `/define` must follow.

**Primary recommendation:** Build the skill as SKILL.md (~300 lines for flow control) plus 3 per-gate reference files, 1 shared review checklist template, 1 PRD template asset, and 1 progress-format reference copy. Fork create-prd's interview guide and PRD template as starting points for Gate 1, then adapt (remove architecture questions, add milestone-scoping, add revision-mode flow).

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Per-gate reference files -- `gate-0-codebase.md`, `gate-wb-working-backwards.md`, `gate-1-prd.md` each contain the full spec for that gate. SKILL.md (~300 lines) handles flow and reads the relevant reference at each gate start.
- **D-02:** `review-checklist-template.md` as a shared reference for all 3 gates' review checklists.
- **D-03:** `assets/prd-template.md` for the PRD output structure.
- **D-04:** Each skill gets its own copy of shared references (e.g., `progress-format.md`) -- no cross-directory reads between skills.
- **D-05:** `/define` lives at `skills/project/define/` -- nested under the project suite, not top-level.
- **D-06:** Produce-then-review pattern at each gate -- Claude produces the full artifact, presents it, then offers Approve / Revise. Revision happens in-session without restart.
- **D-07:** Review checklists are auto-generated from artifact contents. Claude pre-checks items it can verify; user reviews and resolves remaining items. All items must be `[x]` or `[-]` (N/A with reason) before gate approval is recorded (DEF-06).
- **D-08:** Rejection = revision request. Claude asks what's wrong, fixes it, re-presents. No explicit abort -- user can simply stop the conversation.
- **D-09:** Gate 1 partial approval uses a section checklist (multiSelect). User checks approved sections, unchecked ones get focused revision. Claude asks what should change in unchecked sections.
- **D-10:** Agent-based deep scan -- spawn a sub-agent that reads 20-40 files and returns structured findings. `/define` synthesizes into `docs/codebase-assessment.md`.
- **D-11:** Greenfield detection via heuristics: no src/app/lib directories, no dependency manifests (package.json, pyproject.toml, Cargo.toml, go.mod), fewer than 5 non-config files, only README + license + gitignore. All must be true to skip Gate 0.
- **D-12:** At Gate 1, silently re-read `docs/codebase-assessment.md` from disk (DEF-16) -- no recap shown to user, used internally for PRD interview context.
- **D-13:** Fork `create-prd`'s `references/interview-guide.md` and adapt: remove architecture questions (moved to `/design`), add milestone-scoping guidance (DD-1), add revision-mode interview flow, keep Scope/Security/Operational rounds.
- **D-14:** When Gate WB was used, Working Backwards doc is read as context only -- does not auto-populate PRD sections. Full interview still runs, just better informed by the WB narrative.
- **D-15:** Revision mode uses diff-focused interview: read existing `prd.md`, ask "What changed?", interview only affected sections, surface list of downstream artifacts that may need re-review (do not auto-reset per DD-6).

### Claude's Discretion
- Exact codebase scan agent prompt and file selection heuristics
- Assessment section ordering and formatting
- PRD interview pacing (questions per round)
- Exact phrasing of gate approval prompts
- How to handle edge cases in greenfield detection (e.g., monorepo with sparse content)
- Progress.txt write format and recording details

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEF-01 | Greenfield detection and Gate 0 skip | D-11 greenfield heuristics; SKILL.md Step 1 detection logic |
| DEF-02 | Codebase scan at Gate 0 | D-10 agent-based deep scan; gate-0-codebase.md reference file |
| DEF-03 | Produce `docs/codebase-assessment.md` | DD-10 assessment sections; gate-0-codebase.md defines output structure |
| DEF-04 | Gate review checklist at each gate | D-02 review-checklist-template.md; D-07 auto-generation pattern; DD-13 checklist structure |
| DEF-05 | Present Gate 0 findings and support correction | D-06 produce-then-review pattern; D-08 rejection = revision |
| DEF-06 | Validate all checklist items resolved before approval | D-07 completeness validation; DD-7 rule 6 |
| DEF-07 | Record Gate 0 approval in progress.txt | Progress-format.md gate entry format; D-04 local copy of format spec |
| DEF-08 | Offer Gate WB after Gate 0 | DD-11 optional WB stage; SKILL.md flow control between gates |
| DEF-09 | Produce `docs/working-backwards.md` | gate-wb-working-backwards.md reference defines PR/FAQ structure |
| DEF-10 | PRD interview at Gate 1 using WB as input | D-13 forked interview guide; D-14 WB as context only |
| DEF-11 | Produce `prd.md` with required sections | D-03 prd-template.md asset; DD-1 milestone-scoping |
| DEF-12 | Partial Gate 1 approval | D-09 section checklist multiSelect pattern |
| DEF-13 | Record Gate 1 approval in progress.txt | Progress-format.md gate entry format |
| DEF-14 | Run Gates 0/WB/1 as single continuous session | SKILL.md flow structure; DD-2 session scope exception |
| DEF-15 | Revision mode for existing PRD | D-15 diff-focused interview; DD-6 no cascade reset |
| DEF-16 | Re-read codebase-assessment.md at Gate 1 | D-12 silent re-read from disk for context rot mitigation |

</phase_requirements>

## Standard Stack

This phase produces markdown prompt files only -- there is no application code, no npm packages, no compiled artifacts.

### Core Artifacts to Create

| File | Purpose | Source/Pattern |
|------|---------|----------------|
| `skills/project/define/SKILL.md` | Entry point -- flow control across 3 gates (~300 lines) | Fork pattern from `skills/project/SKILL.md` |
| `skills/project/define/references/gate-0-codebase.md` | Gate 0 full spec -- scan logic, assessment structure, review pattern | Net-new; DD-10, DD-13 inform content |
| `skills/project/define/references/gate-wb-working-backwards.md` | Gate WB full spec -- PR/FAQ structure, interview, review | Net-new; DD-11 informs content |
| `skills/project/define/references/gate-1-prd.md` | Gate 1 full spec -- interview rounds, PRD production, revision mode | Fork from `skills/create-prd/references/interview-guide.md` |
| `skills/project/define/references/review-checklist-template.md` | Shared review checklist structure for all 3 gates | DD-13 checklist format |
| `skills/project/define/references/progress-format.md` | Local copy of progress.txt format spec | Copy from `skills/project/references/progress-format.md` |
| `skills/project/define/assets/prd-template.md` | PRD output template (adapted) | Fork from `skills/create-prd/assets/prd-template.md` |
| `docs/skills/define.md` | Detail doc for /define | Pattern from `docs/skills/project.md` |
| `docs/SKILLS.md` | Catalog entry for /define | Add row to existing catalog |

### Fork Sources (verified on disk)

| Source | Path | Verified |
|--------|------|----------|
| create-prd SKILL.md | `skills/create-prd/SKILL.md` | Yes -- 154 lines, 7-step workflow |
| create-prd interview guide | `skills/create-prd/references/interview-guide.md` | Yes -- 82 lines, 5 PRD rounds + architecture areas |
| create-prd PRD template | `skills/create-prd/assets/prd-template.md` | Yes -- 100 lines, section structure |
| project SKILL.md | `skills/project/SKILL.md` | Yes -- 155 lines, reference-loading pattern |
| progress-format.md | `skills/project/references/progress-format.md` | Yes -- 187 lines, format spec |

## Architecture Patterns

### Recommended Directory Structure

```
skills/project/define/
├── SKILL.md                          # ~300 lines -- flow control, gate transitions
├── references/
│   ├── gate-0-codebase.md            # Gate 0 spec (scan, assessment, review)
│   ├── gate-wb-working-backwards.md  # Gate WB spec (PR/FAQ, review)
│   ├── gate-1-prd.md                 # Gate 1 spec (interview, PRD, revision mode)
│   ├── review-checklist-template.md  # Shared review checklist format
│   └── progress-format.md           # Local copy of progress.txt format
└── assets/
    └── prd-template.md              # Adapted PRD template
```

### Pattern 1: Reference-Loading Flow Control

**What:** SKILL.md contains only flow control logic (gate sequencing, greenfield detection, state transitions). Each gate's full specification lives in a reference file loaded at the step that starts that gate.

**When to use:** Always for `/define` -- the 500-line SKILL.md limit means the combined gate logic cannot fit in a single file.

**Example (from existing `/project` SKILL.md):**

```markdown
## Step 3 -- Read State

Read `references/routing-logic.md` for validation rules, then perform:
- Artifact validation (PROJ-04)...
- Consistency validation (PROJ-05)...
```

For `/define`, the pattern becomes:

```markdown
## Step 3 -- Gate 0: Codebase Assessment

Read `references/gate-0-codebase.md` for the complete Gate 0 specification.

Follow the gate-0-codebase specification to:
1. Spawn a sub-agent to scan the codebase (20-40 files)
2. Synthesize findings into `docs/codebase-assessment.md`
3. Present findings and enter produce-then-review cycle
4. Generate review checklist (`docs/reviews/gate-0-review.md`)
5. Validate checklist completeness before recording approval
```

### Pattern 2: Produce-Then-Review Cycle (per gate)

**What:** Each gate follows the same cycle: produce artifact -> present to user -> offer Approve/Revise -> on revision, ask what's wrong, fix, re-present -> on approval, generate review checklist, validate all items resolved, record in progress.txt.

**When to use:** At every gate (0, WB, 1).

**Structure in reference files:**

```markdown
## Production Phase
[How to produce the artifact]

## Review Phase
1. Present artifact summary to user
2. Use AskUserQuestion: Approve / Revise
3. If Revise: ask what needs changing, apply edits, re-present
4. If Approve: proceed to Checklist Validation

## Checklist Validation
1. Generate review checklist from review-checklist-template.md
2. Auto-check items Claude can verify
3. Present remaining items to user
4. All items must be [x] or [-] N/A with reason
5. Record gate approval in progress.txt
```

### Pattern 3: Agent-Based Codebase Scan (Gate 0)

**What:** Spawn a sub-agent with `Agent` tool to perform deep codebase scanning. The agent reads 20-40 files and writes structured findings to a temporary scratch file. The orchestrating SKILL.md reads the scratch file and synthesizes into the final assessment.

**When to use:** Gate 0 only (brownfield projects).

**Key considerations:**
- Agent prompt must specify file selection heuristics (entry points, config files, test files, key modules)
- Agent writes output directly to a file -- does not return content to SKILL.md (per CONVENTIONS.md agent pattern)
- Agent uses Read, Bash (for `ls`, `git log`), Glob tools
- SKILL.md reads agent output and synthesizes into `docs/codebase-assessment.md`

### Pattern 4: Revision Mode Detection

**What:** SKILL.md detects revision mode by checking whether `prd.md` already exists and whether the user's message signals revision intent. When in revision mode, skips to Gate 1 with the diff-focused interview flow from `gate-1-prd.md`.

**When to use:** When `/project` routes to `/define` in revision mode (PROJ-08).

### Anti-Patterns to Avoid

- **Inlining gate specs in SKILL.md:** Will exceed 500-line limit. Each gate must be in its own reference file.
- **Loading all references upfront:** Wastes context tokens. Load each reference only at the step that needs it (existing pattern from `/project`).
- **Auto-populating PRD from Working Backwards doc:** D-14 is explicit -- WB is context only, full interview still runs.
- **Auto-resetting downstream artifacts on revision:** DD-6 forbids automatic cascade. Surface affected list, let user decide.
- **Cross-directory reads:** D-04 requires `/define` to have its own copy of `progress-format.md`. Never read from `skills/project/references/`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Review checklist structure | Custom format per gate | `review-checklist-template.md` shared reference | DD-13 defines a consistent structure; all gates share the same format |
| Progress.txt write format | Ad-hoc gate entry formatting | `progress-format.md` local copy | Format is already specified with exact syntax; deviation causes parse failures |
| PRD sections | Custom section list | Fork of `assets/prd-template.md` | create-prd template is proven; adapt, don't reinvent |
| Interview question bank | Write from scratch | Fork of `references/interview-guide.md` | Existing 5-round structure covers Scope/Components/IO/Security/Operational |
| Greenfield detection | Complex detection logic | Heuristic checklist from D-11 | All conditions must be true; simple boolean AND |

## Common Pitfalls

### Pitfall 1: SKILL.md Line Count Overflow

**What goes wrong:** Attempting to inline gate logic in SKILL.md pushes it past 500 lines, causing context window waste and maintenance difficulty.
**Why it happens:** Natural tendency to put "all the logic" in the main file.
**How to avoid:** SKILL.md contains ONLY flow control (~300 lines): greenfield detection, gate sequencing, state transitions, revision mode detection. All gate-specific logic (scan prompts, interview rounds, artifact structure, review patterns) lives in per-gate reference files.
**Warning signs:** SKILL.md exceeding 350 lines during drafting.

### Pitfall 2: Gate WB State Machine Complexity

**What goes wrong:** Gate WB has 3 possible outcomes (Approved, Skipped, Pending) and the Pending state persists across sessions. Handling all transitions correctly is tricky.
**Why it happens:** Unlike Gates 0 and 1 which are binary (approve/revise), Gate WB has a third state.
**How to avoid:** SKILL.md flow must handle: (1) fresh session where Gate WB hasn't been offered, (2) resuming when Gate WB is Pending from a prior session, (3) Gate WB already resolved (approved or skipped). Read progress.txt at session start to determine which case applies. Gate WB must reach `[x]` or `[-]` before Gate 1 can begin (DD-11).
**Warning signs:** Gate 1 starting without Gate WB being resolved.

### Pitfall 3: Context Rot at Gate 1

**What goes wrong:** By the time the user reaches Gate 1, the codebase assessment from Gate 0 may have scrolled out of Claude's context window, leading to a PRD that ignores codebase findings.
**Why it happens:** Long Gate 0 and Gate WB conversations burn tokens before Gate 1 starts.
**How to avoid:** DEF-16 requires a silent re-read of `docs/codebase-assessment.md` from disk at Gate 1 start. The gate-1-prd.md reference must explicitly instruct this re-read before starting the interview.
**Warning signs:** PRD interview questions that ignore codebase context.

### Pitfall 4: Revision Mode Skipping Gate 0/WB

**What goes wrong:** Revision mode should skip directly to Gate 1 (diff-focused interview on the existing PRD), but the SKILL.md flow might try to re-run Gate 0 or Gate WB.
**Why it happens:** Linear step flow without conditional branching.
**How to avoid:** Revision mode detection at SKILL.md Step 1. When `prd.md` exists AND user signals revision, jump directly to Gate 1 revision flow (load gate-1-prd.md, use revision-specific interview section).
**Warning signs:** Revision mode re-scanning the codebase or re-offering Working Backwards.

### Pitfall 5: Review Checklist Auto-Generation Ambiguity

**What goes wrong:** D-07 says checklists are "auto-generated from artifact contents" -- but what does that mean concretely? If the instructions are vague, Claude generates inconsistent or shallow checklists.
**Why it happens:** The boundary between template-driven and content-driven checklist items is unclear.
**How to avoid:** `review-checklist-template.md` provides the static items per gate (from DD-13). The "auto-generation" means Claude adds artifact-specific items based on what was actually produced (e.g., specific assumptions to verify, specific patterns to confirm). The template provides the floor; content-specific items raise the ceiling.
**Warning signs:** Checklists that are identical regardless of artifact content.

### Pitfall 6: Partial Approval Scope Creep

**What goes wrong:** D-09 specifies section-level partial approval for Gate 1, but without clear section boundaries, the user can't meaningfully select which sections to approve.
**Why it happens:** PRD sections blur together; "Goals" and "Non-Goals" inform each other.
**How to avoid:** The multiSelect checklist must map to clearly delineated PRD sections: Summary, Goals, Non-Goals, External Dependencies, Milestones, Configuration, Outputs, Risk Assessment, Future Enhancements. Each section is independently approvalable.
**Warning signs:** User confusion about what "approving a section" means.

## Code Examples

### SKILL.md Flow Control Structure

```markdown
## Step 1 -- Detect Mode and State

Read `progress.txt` from the project root.

**Revision mode detection:**
- If `prd.md` exists AND user message signals revision intent → proceed to Step 6 (Revision Mode)

**Greenfield detection (DEF-01):**
[D-11 heuristics -- check src/app/lib dirs, manifests, file count, boilerplate-only]
- If ALL greenfield conditions met → skip Gate 0, proceed to Step 4 (Gate WB Offer)
- Otherwise → proceed to Step 2 (Gate 0)

**Gate WB resume detection:**
- If Gate WB is `[ ] Pending` in progress.txt → proceed to Step 4 (Gate WB Offer) with re-prompt

## Step 2 -- Gate 0: Codebase Assessment

Read `references/gate-0-codebase.md` for the complete Gate 0 specification.
[Follow gate spec: scan, produce, review, approve]
Record approval in progress.txt per `references/progress-format.md`.

## Step 3 -- Gate 0 Transition

Proceed to Step 4 (Gate WB Offer).

## Step 4 -- Gate WB: Working Backwards (Optional)

Read `references/gate-wb-working-backwards.md` for the complete Gate WB specification.
Use AskUserQuestion: Yes / Skip / Defer
[Handle each outcome per DD-11]

## Step 5 -- Gate 1: Scope Review

Read `references/gate-1-prd.md` for the complete Gate 1 specification.
Re-read `docs/codebase-assessment.md` from disk (DEF-16 -- silent, no recap to user).
If `docs/working-backwards.md` exists, read it as context (D-14).
[Follow gate spec: interview, produce, partial approval, review, approve]
Record approval in progress.txt.

## Step 6 -- Revision Mode

Read `references/gate-1-prd.md` for the revision mode specification.
Read existing `prd.md`.
Re-read `docs/codebase-assessment.md` from disk if it exists.
[Follow diff-focused interview: what changed, revise affected sections, surface downstream impacts]
```

### Gate Entry Write Format

```
[x] Gate 0: Codebase Alignment  Approved: 2026-04-02  docs/codebase-assessment.md
[-] Gate WB: Working Backwards  Skipped
[x] Gate 1: Scope Review  Approved: 2026-04-02  prd.md
```

### Review Checklist File Structure (DD-13)

```markdown
# Gate 0 Review -- Codebase Alignment

**Artifact:** docs/codebase-assessment.md
**Status:** [ ] Pending
**Reviewer(s):**
**Date:**

## Checklist

- [ ] Are the detected patterns accurate for the current codebase?
- [ ] Are there patterns listed as "carry forward" that should be changed?
- [ ] Are there existing patterns not detected that the model should follow?
- [ ] Are the open questions answerable? Provide answers.
- [ ] [Auto-generated: specific assumption from assessment]
- [ ] [Auto-generated: specific pattern to verify]

## Reviewer Comments

```

### PRD Template Adaptations (from create-prd)

Key changes from the `create-prd` PRD template:

1. **Remove:** `Architecture` section (moved to `/design`)
2. **Remove:** `Features` section with detailed acceptance criteria (replaced by milestone-scoped features)
3. **Add:** `Milestones` section (initially empty -- populated by `/milestone`)
4. **Keep:** Summary, Goals, Non-Goals, External Dependencies, Configuration, Outputs, Risk Assessment, Future Enhancements

### Interview Guide Adaptations (from create-prd)

Key changes from the `create-prd` interview guide:

1. **Remove:** Round 2 (Components and Architecture) -- moved to `/design`
2. **Keep:** Round 1 (Scope), Round 3 (Inputs/Outputs), Round 4 (Security), Round 5 (Operational)
3. **Add:** Milestone-scoping guidance (DD-1) -- "What are the major deliverable milestones?"
4. **Add:** Revision-mode interview section -- "What changed?", focused interview on affected sections
5. **Adjust:** Renumber rounds to reflect removals

## State of the Art

| Old Approach (create-prd) | New Approach (/define) | Why Changed |
|---------------------------|------------------------|-------------|
| Monolithic PRD with all features | Milestone-scoped PRD (features empty until `/milestone`) | DD-1: three-level hierarchy prevents context bloat |
| PRD + Architecture in same session | PRD only; architecture deferred to `/design` | DD-2: phase isolation prevents context rot |
| No codebase awareness | Gate 0 codebase scan before any planning | DD-10: prevents silent pattern propagation |
| No customer outcome validation | Optional Working Backwards (Gate WB) | DD-11: forces "what does the customer get?" first |
| No review checklists | Structured review checklist per gate | DD-13: ensures consistent, complete review |
| No partial approval | Section-level partial approval at Gate 1 | DD-7 rule 4: user approves parts, revises others |

## Open Questions

1. **Codebase scan agent prompt design**
   - What we know: Agent reads 20-40 files, writes structured findings to a file. File selection uses heuristics (entry points, config, tests, key modules).
   - What's unclear: Exact prompt wording, file selection algorithm, how to handle very large codebases (>1000 files), output structure of agent findings vs. final assessment structure.
   - Recommendation: Claude's discretion per CONTEXT.md. The planner should define the agent prompt structure but leave exact wording to implementation. Target: agent produces a structured JSON or markdown scratch file with sections matching the assessment output.

2. **Gate WB interview flow**
   - What we know: Produces Press Release, External FAQ, Internal FAQ. DD-11 describes the content.
   - What's unclear: How many interview rounds? What questions drive the PR/FAQ? Is there a template?
   - Recommendation: Design a 2-3 round interview: (1) Customer and problem, (2) Solution and experience, (3) Internal feasibility. No template file needed -- the gate-wb reference file can define the output structure inline since PR/FAQ is relatively short.

3. **Shared `references/progress-format.md` duplication strategy**
   - What we know: D-04 says each skill gets its own copy. STATE.md flagged this as an open question.
   - What's unclear: Whether to copy verbatim or extract only the sections `/define` needs.
   - Recommendation: Copy verbatim. The file is 187 lines and format correctness is critical. Partial copies risk format drift. The 187-line cost is acceptable when loaded only at the step that writes to progress.txt.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual validation (markdown-only skill, no compiled code) |
| Config file | none |
| Quick run command | `bash cicd/lint-markdown.sh` (markdown lint) |
| Full suite command | `bash cicd/lint-markdown.sh` + manual skill invocation test |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEF-01 | Greenfield detection skips Gate 0 | manual | Invoke `/define` in empty dir | N/A |
| DEF-02 | Codebase scan produces assessment | manual | Invoke `/define` in brownfield project | N/A |
| DEF-03 | Assessment file at `docs/codebase-assessment.md` | manual + lint | `bash cicd/lint-markdown.sh` on output | N/A |
| DEF-04 | Review checklist at each gate | manual | Check `docs/reviews/gate-{0,wb,1}-review.md` exists | N/A |
| DEF-05 | Gate 0 correction before approval | manual | Interactive test | N/A |
| DEF-06 | Checklist completeness blocks approval | manual | Interactive test | N/A |
| DEF-07 | Gate 0 approval in progress.txt | manual | Check progress.txt format | N/A |
| DEF-08 | Gate WB offer after Gate 0 | manual | Interactive test | N/A |
| DEF-09 | WB produces working-backwards.md | manual | Check file exists with PR/FAQ sections | N/A |
| DEF-10 | PRD interview uses WB as input | manual | Interactive test | N/A |
| DEF-11 | prd.md produced with required sections | manual + lint | `bash cicd/lint-markdown.sh` on output | N/A |
| DEF-12 | Partial Gate 1 approval | manual | Interactive test | N/A |
| DEF-13 | Gate 1 approval in progress.txt | manual | Check progress.txt format | N/A |
| DEF-14 | Single continuous session | manual | Full end-to-end test | N/A |
| DEF-15 | Revision mode diff-focused interview | manual | Invoke with existing prd.md | N/A |
| DEF-16 | Re-read assessment at Gate 1 | manual | Verify assessment used in PRD context | N/A |

### Sampling Rate
- **Per task commit:** `bash cicd/lint-markdown.sh` (validates markdown structure)
- **Per wave merge:** Lint + manual spot-check of SKILL.md step structure
- **Phase gate:** Full manual invocation test (greenfield + brownfield scenarios)

### Wave 0 Gaps
- None -- this is a markdown-only skill. No test framework setup needed. Validation is structural (lint) and behavioral (manual invocation).

## Sources

### Primary (HIGH confidence)
- `skills/project/DESIGN.md` -- DD-1 through DD-13 (all design decisions for the project skill suite)
- `skills/project/SKILL.md` -- Reference-loading pattern, step structure, AskUserQuestion usage
- `skills/create-prd/SKILL.md` -- Fork source for Gate 1 workflow (7-step structure)
- `skills/create-prd/references/interview-guide.md` -- 5-round interview question bank
- `skills/create-prd/assets/prd-template.md` -- PRD output template
- `skills/project/references/progress-format.md` -- Progress.txt format specification
- `.planning/codebase/CONVENTIONS.md` -- SKILL.md frontmatter, naming, documentation requirements
- `.planning/codebase/STRUCTURE.md` -- Directory layout, skill bundle structure

### Secondary (MEDIUM confidence)
- `.planning/phases/02-define-gates-0-wb-1/02-CONTEXT.md` -- User decisions D-01 through D-15

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all fork sources verified on disk, patterns established in Phase 1
- Architecture: HIGH -- directory structure and reference-loading pattern locked by user decisions
- Pitfalls: HIGH -- identified from concrete design constraints and established patterns

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (stable -- markdown-only, no external dependencies)
