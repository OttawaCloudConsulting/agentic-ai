# Phase 3: /design (Gate 2) - Research

**Researched:** 2026-04-02
**Domain:** Claude Code skill authoring -- architecture generation, sub-agent scanning, gate review UX, refresh mode
**Confidence:** HIGH

## Summary

Phase 3 builds a `/design` skill that produces `docs/ARCHITECTURE_AND_DESIGN.md` from an approved PRD and optional codebase assessment. The skill follows the exact same structural pattern as the `/define` skill from Phase 2: a SKILL.md flow controller (~150-200 lines) that loads external reference files at the step that needs them, with templates in `assets/` and gate specifications in `references/`.

The key technical challenges are: (1) the architecture sub-agent prompt and file selection heuristics -- this agent must scan through an architecture lens (component boundaries, data flow, interfaces) rather than Gate 0's convention-focused lens; (2) the refresh mode which must scan feature plan files for Architectural Deviations sections and present per-deviation consolidation; (3) the tradeoff callout UX that highlights 2-4 key design decisions before the approval checklist.

**Primary recommendation:** Follow the `/define` skill structure exactly -- directory layout, reference loading pattern, review checklist template, progress format copy. The only novel work is the architecture agent prompt, the architecture template, the refresh mode reference, and the Gate 2-specific review flow.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Reference file pattern -- SKILL.md as flow controller (~150 lines) loading external reference files. Consistent with Phase 2's `/define` approach.
- **D-02:** Directory structure: `skills/project/design/` with `references/` (gate-2-design.md, refresh-mode.md, progress-format.md, review-checklist-template.md) and `assets/` (architecture-template.md).
- **D-03:** Own copy of `progress-format.md` -- no cross-directory reads between skills (carries forward Phase 2 D-04).
- **D-04:** `architecture-template.md` matches DESIGN.md exactly -- 6 sections: Design Decisions (numbered table with decision/rationale/tradeoff/alternatives columns), Component Inventory, Data Flow, File Organization, Deployment & Operations, Security Considerations.
- **D-05:** Agent-based deep codebase scan -- spawn a sub-agent that reads 15-30 files through an architecture lens (component boundaries, data flow patterns, interface contracts, tech choices). Synthesize agent findings + PRD into the architecture doc.
- **D-06:** Always spawn the architecture agent, even on greenfield projects where `docs/codebase-assessment.md` doesn't exist. Scan whatever exists (boilerplate, configs, dependencies) to inform architecture decisions.
- **D-07:** Primary inputs always read: `prd.md`, `docs/codebase-assessment.md` (if exists), `progress.txt` (for gate validation).
- **D-08:** Section-by-section partial approval -- same pattern as Gate 1 PRD. Present full doc, then multiSelect checklist of 6 sections. User checks approved sections; unchecked get focused revision with "What should change?" prompt.
- **D-09:** Tradeoff callouts -- after presenting the full doc, call out 2-4 design decisions with the most significant tradeoffs before the approval checklist. Draws attention without forcing a separate review round.
- **D-10:** Produce-then-review pattern -- Claude produces full artifact, presents it, offers Approve/Revise. Revision happens in-session without restart (carries forward Phase 2 D-06).
- **D-11:** Review checklists auto-generated, all items must be `[x]` or `[-]` (N/A with reason) before gate approval is recorded (carries forward Phase 2 D-07).
- **D-12:** Per-deviation review -- scan all `milestones/*/plans/*.md` for Architectural Deviations sections. Present each deviation with its original design decision and reason for change. User confirms which deviations to consolidate via multiSelect.
- **D-13:** After consolidation, present updated `ARCHITECTURE_AND_DESIGN.md` for approval using the same section-by-section review flow.
- **D-14:** When zero deviations found, report "No architectural deviations found. Architecture doc is current." and exit cleanly. No revision offer.

### Claude's Discretion
- Architecture agent prompt and file selection heuristics (architecture-focused, not convention-focused like Gate 0)
- Exact phrasing of gate approval prompts and tradeoff callouts
- How to handle edge cases in greenfield agent scanning (minimal files available)
- Progress.txt write format and recording details
- Review checklist item generation from architecture doc contents
- How to detect which design decisions are "key tradeoffs" worth calling out

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DES-01 | `/design` validates Gate 1 is approved in `progress.txt` before proceeding; reports missing prerequisite and declines if not met | Progress format spec provides gate entry format; SKILL.md Step 1 reads progress.txt and checks Gate 1 status |
| DES-02 | `/design` reads `prd.md` and `docs/codebase-assessment.md` (if exists) as primary inputs | D-07 locks input file list; gate-2-design.md reference specifies read order |
| DES-03 | `/design` produces `docs/ARCHITECTURE_AND_DESIGN.md` with 6 required sections | D-04 locks template; DESIGN.md section spec provides authoritative section list |
| DES-04 | `/design` produces `docs/reviews/gate-2-review.md` checklist | DD-13 provides static checklist items; review-checklist-template.md provides format |
| DES-05 | `/design` presents architecture for review focused on feasibility, tech fit, completeness; highlights key tradeoffs | D-08 (partial approval), D-09 (tradeoff callouts), DD-8 (Gate 2 review framing) |
| DES-06 | `/design` supports in-session revision before approval | D-10 (produce-then-review), D-08 (section-by-section partial approval) |
| DES-07 | `/design` records Gate 2 approval in `progress.txt` | Progress format spec: `[x] Gate 2: Design Review  Approved: <date>  docs/ARCHITECTURE_AND_DESIGN.md` |
| DES-08 | `/design` in refresh mode consolidates accumulated architectural deviations from feature plans | D-12, D-13, D-14 lock refresh mode flow; refresh-mode.md reference file |
</phase_requirements>

## Standard Stack

This is a Markdown-only project -- no application code, no package dependencies. The "stack" is Claude Code skill authoring patterns.

### Core
| Component | Pattern | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SKILL.md | Flow controller with numbered steps | Entry point for `/design` command | Established pattern from `/define` and `/project` skills |
| references/ | External spec files loaded at step that needs them | Gate spec, refresh spec, progress format, checklist template | Keeps SKILL.md under 200 lines; each reference is self-contained |
| assets/ | Template files for output documents | `architecture-template.md` for the ARCHITECTURE_AND_DESIGN.md structure | Matches `/define`'s `prd-template.md` pattern |

### Supporting
| Component | Pattern | Purpose | When to Use |
|-----------|---------|---------|-------------|
| Agent tool | Sub-agent spawn for codebase scanning | Architecture-focused deep scan (15-30 files) | Always -- even on greenfield projects (D-06) |
| AskUserQuestion | Interactive prompts with 2-4 options | Gate approval, revision requests, tradeoff confirmations | All user-facing decision points |
| multiSelect | Section checklist for partial approval | 6-section approval for architecture doc | Partial approval and refresh mode deviation selection |

## Architecture Patterns

### Recommended Directory Structure
```
skills/project/design/
├── SKILL.md                              # Flow controller (~150 lines)
├── references/
│   ├── gate-2-design.md                  # Complete Gate 2 specification
│   ├── refresh-mode.md                   # Refresh mode specification
│   ├── progress-format.md                # Verbatim copy from define/references/
│   └── review-checklist-template.md      # Gate 2-specific checklist template
└── assets/
    └── architecture-template.md          # Template matching DESIGN.md 6-section spec
```

### Pattern 1: SKILL.md Flow Controller
**What:** SKILL.md contains numbered steps with clear action verbs. Each step loads exactly the reference file it needs. No reference is loaded upfront -- lazy loading preserves context budget.
**When to use:** Always -- this is the established pattern.
**Example from `/define`:**
```markdown
## Step 2 -- Gate 0: Codebase Assessment

Read `references/gate-0-codebase.md` for the complete Gate 0 specification.

Follow the gate-0-codebase specification to:
1. Spawn a sub-agent to scan the codebase (20-40 files).
2. Synthesize findings into `docs/codebase-assessment.md`.
...
```

**For `/design`, the equivalent:**
```markdown
## Step 2 -- Architecture Generation

Read `references/gate-2-design.md` for the complete Gate 2 specification.

Follow the gate-2-design specification to:
1. Read `prd.md` and `docs/codebase-assessment.md` (if exists).
2. Spawn architecture sub-agent to scan 15-30 files.
3. Synthesize findings + PRD into `docs/ARCHITECTURE_AND_DESIGN.md`.
...
```

### Pattern 2: Sub-Agent for Codebase Scanning
**What:** Spawn a sub-agent with restricted tools (Read, Bash for ls/git, Glob) to perform a focused scan, writing findings to a temp scratch file. The orchestrator then synthesizes the findings into the final document.
**When to use:** Architecture generation step (always, per D-06).
**Key difference from Gate 0:** The architecture agent reads 15-30 files (vs Gate 0's 20-40) and focuses on:
- Component boundaries and module organization
- Data flow patterns (how data moves between components)
- Interface contracts (function signatures, API shapes, event formats)
- Technology choices and their implications
- Configuration patterns
Gate 0's agent focuses on conventions (naming, style, testing patterns). The architecture agent focuses on structure and decisions.

### Pattern 3: Produce-Then-Review Cycle
**What:** Generate the complete artifact, present it to the user, offer Approve/Revise/Partial Approve. Rejection means in-session revision, not restart.
**When to use:** After architecture doc generation (normal mode) and after refresh consolidation.
**Flow:**
1. Present full document summary
2. Call out 2-4 key tradeoff decisions (D-09) -- brief highlight before the checklist
3. AskUserQuestion: Approve / Revise / Partial Approve
4. If Partial Approve: multiSelect with 6 architecture sections, focused revision on unchecked sections
5. If Revise: ask what needs changing, apply edits, re-present
6. If Approve: proceed to checklist validation

### Pattern 4: Refresh Mode (Deviation Consolidation)
**What:** Scan `milestones/*/plans/*.md` for Architectural Deviations sections. Present each deviation individually with original design decision context. User confirms via multiSelect which to consolidate.
**When to use:** When user invokes `/design` and `docs/ARCHITECTURE_AND_DESIGN.md` already exists and Gate 2 is already approved.
**Flow:**
1. Detect refresh mode (Gate 2 already approved + architecture doc exists)
2. Read all feature plan files, extract Architectural Deviations sections
3. If zero deviations: report "No architectural deviations found. Architecture doc is current." and exit (D-14)
4. For each deviation: show original decision + reason for change
5. multiSelect: user picks which deviations to consolidate
6. Apply selected deviations to `docs/ARCHITECTURE_AND_DESIGN.md`
7. Present updated doc using same section-by-section review (D-13)
8. Update gate entry date in `progress.txt`

### Anti-Patterns to Avoid
- **Loading all references upfront:** Wastes context budget. Load each reference at the step that needs it.
- **Combining normal and refresh mode in the same flow:** These are separate code paths with different inputs and different UX. Detect mode first, then branch cleanly.
- **Auto-advancing past gate approval:** Never proceed without explicit user approval. Present summary, wait for Approve/Revise.
- **Dumping raw agent scan to user:** The agent writes to a scratch file. The SKILL.md orchestrator synthesizes findings into the structured template, then presents the clean document.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Progress file format | Custom format parsing | Copy `progress-format.md` verbatim from `/define` | Format is already specified; deviating creates inconsistency |
| Review checklist structure | New checklist format | Follow `review-checklist-template.md` pattern from `/define` | Established 2-tier format (static + auto-generated items) |
| Architecture doc sections | Custom section layout | Use DESIGN.md section spec verbatim (6 sections) | DD-4 locks the exact sections; deviation would break downstream consumers |
| Gate state validation | Custom progress.txt parsing logic | Follow the same pattern `/define` uses for Gate 0 check | Proven pattern; four canonical markers only |

## Common Pitfalls

### Pitfall 1: Architecture Agent Scanning Greenfield Projects
**What goes wrong:** Agent finds almost nothing to scan in a greenfield project (maybe just README, .gitignore, a config file). Returns minimal/empty findings. The SKILL.md then generates a hollow architecture doc.
**Why it happens:** D-06 says always spawn the agent, even on greenfield. But greenfield has almost no files.
**How to avoid:** The architecture doc for greenfield projects is driven primarily by the PRD, not by the scan. The agent scan provides whatever exists (configs, dependency files, boilerplate). The synthesis step must lean heavily on PRD goals, non-goals, and risk assessment to propose architecture. The reference file should explicitly describe this greenfield handling.
**Warning signs:** Architecture doc sections that say "to be determined" or repeat PRD content verbatim.

### Pitfall 2: Refresh Mode Detection vs Normal Mode
**What goes wrong:** The skill runs normal architecture generation when it should be in refresh mode, or vice versa.
**Why it happens:** Detection logic isn't clear. Multiple states are possible: Gate 2 never run, Gate 2 approved but no deviations, Gate 2 approved with deviations.
**How to avoid:** SKILL.md Step 1 must explicitly check:
- Gate 1 approved? No -> decline with prerequisite message (DES-01)
- Gate 2 already approved AND `docs/ARCHITECTURE_AND_DESIGN.md` exists? -> refresh mode
- Gate 2 not yet approved? -> normal mode
**Warning signs:** Overwriting an existing architecture doc without scanning for deviations first.

### Pitfall 3: Tradeoff Detection Heuristics
**What goes wrong:** Claude calls out trivial decisions as "key tradeoffs" or misses the genuinely significant ones.
**Why it happens:** No mechanical rule can determine which decisions have the most impact. This is Claude's discretion.
**How to avoid:** Provide heuristic guidance in the gate-2-design.md reference: look for decisions where (a) the alternatives are genuinely viable, (b) the tradeoff affects multiple components or long-term evolution, (c) reversal would be expensive. Cap at 2-4 callouts to avoid decision fatigue.
**Warning signs:** Every decision flagged as a tradeoff, or zero flagged.

### Pitfall 4: Review Checklist Template Divergence
**What goes wrong:** The Gate 2 review checklist uses a different format than Gates 0/WB/1.
**Why it happens:** Creating a new template from scratch rather than following the established pattern.
**How to avoid:** The review-checklist-template.md for `/design` should use the exact same structure as `/define`'s template -- file header format, static items section, auto-generated items prefix `[Auto]`, completion rules. The only difference is the static items are Gate 2-specific (from DD-13).
**Warning signs:** Missing `[Auto]` prefix on content-specific items, different header format, different completion rules.

### Pitfall 5: Refresh Mode Glob Pattern
**What goes wrong:** Missing deviation entries in feature plans because the glob pattern doesn't match all plan file locations.
**Why it happens:** Feature plans live at `milestones/*/plans/*.md` but the pattern might not account for all milestone naming.
**How to avoid:** Use `milestones/*/plans/*.md` as the glob. Read each file and search for the "Architectural Deviations" section (or heading). Handle the case where the section exists but is empty ("Empty if the feature was built as designed" per DESIGN.md).
**Warning signs:** Reporting zero deviations when feature plans have documented deviations.

## Code Examples

### SKILL.md Frontmatter Pattern
```yaml
---
name: design
description: >
  Architecture and design specification from an approved PRD, with in-session
  revision before gate approval. Supports refresh mode to consolidate
  architectural deviations. Use when designing architecture, creating design
  doc, reviewing technical choices, or refreshing architecture after
  implementation deviations. Phrases like "design the architecture", "create
  design doc", "refresh architecture" are good triggers.
disable-model-invocation: true
---
```

### Gate 1 Prerequisite Check Pattern (from /define analog)
```markdown
## Step 1 -- Detect Mode and State

Read `progress.txt` from the project root.

**Prerequisite check (DES-01):**
If Gate 1 is not `[x]` approved in `progress.txt`, inform the user:
"Gate 1 (Scope Review) must be approved before running /design. Run /define
to complete the PRD first."
Do not proceed. End the session.

**Refresh mode detection (DES-08):**
Check ALL of the following:
- Gate 2 is `[x]` approved in `progress.txt`
- `docs/ARCHITECTURE_AND_DESIGN.md` exists on disk

If ALL true: jump to Step 4 (Refresh Mode).

**Normal mode:**
If Gate 2 is not yet approved: proceed to Step 2 (Architecture Generation).
```

### Architecture Template Structure (from DESIGN.md spec)
```markdown
# Architecture and Design: [Project Title]

## Design Decisions

| # | Decision | Rationale | Tradeoff | Alternatives Considered |
|---|----------|-----------|----------|-------------------------|
| 1 | | | | |

## Component Inventory

| Component | Responsibility | Interfaces |
|-----------|---------------|------------|
| | | |

## Data Flow

[Description of how data moves through the system]

## File Organization

```
[Target directory structure]
```

## Deployment & Operations

[How the system is deployed, monitored, operated]

## Security Considerations

[Auth, access control, data handling]
```

### Gate 2 Static Checklist Items (from DD-13)
```markdown
# Gate 2 Review -- Design Review

**Artifact:** docs/ARCHITECTURE_AND_DESIGN.md
**Status:** [ ] Pending
**Reviewer(s):**
**Date:**

## Checklist

- [ ] Are the design decisions sound? Are tradeoffs acceptable?
- [ ] Is the component inventory complete?
- [ ] Does the data flow match your understanding of the system?
- [ ] Are there security considerations missing?
```

### Progress.txt Gate 2 Entry Format
```
[x] Gate 2: Design Review  Approved: 2026-04-02  docs/ARCHITECTURE_AND_DESIGN.md
```

## File Inventory

All files that must be created in this phase:

| File | Purpose | Size Estimate | Source/Pattern |
|------|---------|---------------|----------------|
| `skills/project/design/SKILL.md` | Flow controller entry point | ~150 lines | Modeled on `skills/project/define/SKILL.md` |
| `skills/project/design/references/gate-2-design.md` | Complete Gate 2 spec (agent scan, synthesis, review) | ~150 lines | Modeled on `define/references/gate-0-codebase.md` + `gate-1-prd.md` |
| `skills/project/design/references/refresh-mode.md` | Refresh mode spec (deviation scan, consolidation, review) | ~80 lines | New -- no direct analog |
| `skills/project/design/references/progress-format.md` | Progress file format (verbatim copy) | ~188 lines | Exact copy of `define/references/progress-format.md` |
| `skills/project/design/references/review-checklist-template.md` | Gate 2 review checklist template | ~60 lines | Modeled on `define/references/review-checklist-template.md` |
| `skills/project/design/assets/architecture-template.md` | Template for ARCHITECTURE_AND_DESIGN.md | ~50 lines | Based on DESIGN.md section spec |
| `docs/skills/design.md` | Detail doc for the /design skill | ~80 lines | Modeled on `docs/skills/define.md` |
| `docs/SKILLS.md` (edit) | Add Design row to catalog | 1 line addition | Insert after Define row |

## Project Constraints (from CLAUDE.md)

- Use `<br/>` for line breaks inside Mermaid diagram node labels (not `\n`)
- `disable-model-invocation: true` is mandatory in SKILL.md frontmatter
- All content is Markdown -- no application code
- Scripts invoked with explicit interpreter (`bash script.sh`, never `./script.sh`)
- Never set executable bit on script files
- Documentation requirements: component + detail doc + catalog entry
- Markdown linting via `bash cicd/lint-markdown.sh`

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual validation (Markdown skill files -- no automated test framework) |
| Config file | None -- skills are validated by invocation |
| Quick run command | `bash cicd/lint-markdown.sh` (markdown lint only) |
| Full suite command | `bash cicd/lint-markdown.sh` + manual skill invocation |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DES-01 | Gate 1 prerequisite check | manual | Invoke `/design` without Gate 1 approved | N/A |
| DES-02 | Reads prd.md and codebase-assessment.md | manual | Invoke `/design` with both files present | N/A |
| DES-03 | Produces ARCHITECTURE_AND_DESIGN.md with 6 sections | manual | Check file exists with all sections | N/A |
| DES-04 | Produces gate-2-review.md checklist | manual | Check file exists with static + auto items | N/A |
| DES-05 | Presents architecture with tradeoff callouts | manual | Observe UX during invocation | N/A |
| DES-06 | In-session revision before approval | manual | Select Revise during review | N/A |
| DES-07 | Records Gate 2 approval in progress.txt | manual | Check progress.txt after approval | N/A |
| DES-08 | Refresh mode consolidates deviations | manual | Invoke `/design` with existing architecture doc + deviation data | N/A |

### Sampling Rate
- **Per task commit:** `bash cicd/lint-markdown.sh` (validates Markdown formatting)
- **Per wave merge:** Lint + manual review of file structure consistency
- **Phase gate:** Full lint + manual invocation test of `/design` normal mode and refresh mode

### Wave 0 Gaps
- None -- this is a Markdown-only skill. The lint script is the only automated validation. Manual testing is the primary validation strategy for skill behavior.

## Sources

### Primary (HIGH confidence)
- `skills/project/DESIGN.md` -- DD-7, DD-8, DD-13, Gate 2 artifact spec, architecture doc section spec
- `skills/project/define/SKILL.md` -- Flow controller pattern (197 lines, direct structural model)
- `skills/project/define/references/gate-0-codebase.md` -- Sub-agent scanning pattern
- `skills/project/define/references/gate-1-prd.md` -- Interview, review, partial approval, revision mode patterns
- `skills/project/define/references/review-checklist-template.md` -- Checklist format (header, static items, auto items, completion rules)
- `skills/project/define/references/progress-format.md` -- Progress file format spec (to be copied)
- `skills/project/define/assets/prd-template.md` -- Template asset pattern
- `.planning/REQUIREMENTS.md` -- DES-01 through DES-08
- `.planning/codebase/CONVENTIONS.md` -- Frontmatter rules, naming, documentation requirements
- `.planning/codebase/STRUCTURE.md` -- Directory layout, skill bundle structure

### Secondary (MEDIUM confidence)
- None needed -- all findings are from authoritative project sources

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- directly follows established `/define` pattern with project-internal sources
- Architecture: HIGH -- directory structure, reference files, and flow are locked decisions from CONTEXT.md
- Pitfalls: HIGH -- derived from direct analysis of predecessor skill code and DESIGN.md constraints

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (stable -- Markdown skill patterns unlikely to change)
