# Phase 01: Project Router - Research

**Researched:** 2026-04-02
**Domain:** Markdown-based skill authoring for Claude Code (prompt engineering, not application code)
**Confidence:** HIGH

## Summary

Phase 01 delivers a single invokable skill (`/project`) that bootstraps `progress.txt` on first run and acts as a read-only router on every subsequent invocation. The skill reads project state from disk, validates artifact existence and milestone consistency, reports status, and tells the user what to do next. It never modifies state after the initial bootstrap.

This is a markdown-only deliverable. The "code" is a `SKILL.md` prompt file following the established pattern in `skills/create-prd/SKILL.md`. There are no compiled languages, no dependencies to install, no runtime to configure. The complexity is in the prompt engineering: correctly parsing two plain-text state file formats (`progress.txt` and `milestone-status.txt`), implementing conditional routing logic across multiple project states, and handling edge cases (missing artifacts, divergent state, Gate WB pending).

**Primary recommendation:** Follow the `create-prd` SKILL.md structure exactly (frontmatter with `disable-model-invocation: true`, numbered steps, `AskUserQuestion` for interactive prompts). The skill needs a `references/` subdirectory for the progress file format specification and routing logic tables, keeping the main SKILL.md under the 500-line practical limit.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Status report format is structured summary with clean sections -- gates as a checklist with dates, active milestone with per-feature status, one-line summaries for completed/upcoming milestones
- **D-02:** Show ALL spikes (both open and resolved) in a dedicated Spikes section
- **D-03:** Routing UX is a prioritized menu -- one recommended next action highlighted, with 2-3 context-sensitive valid alternatives listed below
- **D-04:** "Also available" options are context-sensitive -- only show actions valid for the current project state
- **D-05:** Detect re-planning intent from natural language keywords (e.g., "goals changed", "re-plan", "revise PRD") and route to the appropriate skill in revision mode
- **D-06:** Warnings appear inline, directly after the gate or milestone entry they affect (not collected in a separate section)
- **D-07:** Severity-based blocking -- missing artifact warnings are informational only (don't block routing), but consistency divergence between `progress.txt` and `milestone-status.txt` blocks routing until the user acknowledges
- **D-08:** When no `working-backwards.md` exists and customer outcome is unclear, offer Gate WB with a brief explanation (2-3 sentences on Working Backwards value) plus three options: Yes, Skip, Defer
- **D-09:** When Gate WB is Pending on re-invocation, show a gentle reminder at the top of the report but still display the full status report. Do not hard-block -- differs from strict PROJ-07 reading; the pending decision is highlighted but does not suppress status output

### Claude's Discretion

- Bootstrap `progress.txt` format and exact content (following the format defined in DESIGN.md)
- Exact phrasing of routing recommendations
- How to detect greenfield vs brownfield for Gate WB offer logic
- Internal implementation of state parsing

### Deferred Ideas (OUT OF SCOPE)

None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROJ-01 | Bootstrap `progress.txt` with gate entries and no milestones on first run | DESIGN.md DD-3 bootstrap exception defines exact format; progress-file/ artifacts define format spec |
| PROJ-02 | Read `progress.txt` and `milestone-status.txt`, report current state | DESIGN.md DD-3 defines two-tier state; indicative format examples in DD-3 provide parsing patterns |
| PROJ-03 | Route user to correct next skill via plain-language instruction | DESIGN.md DD-4 gate table defines the full routing graph; D-03/D-04 define UX |
| PROJ-04 | Validate artifact paths alongside approved gates exist on disk | DESIGN.md DD-3 artifact validation clause; artifact inventory table maps gates to paths |
| PROJ-05 | Validate consistency between `progress.txt` milestone summary and `milestone-status.txt` | DESIGN.md DD-3 consistency validation clause and DD-5 sync contract |
| PROJ-06 | Offer Gate WB when no `working-backwards.md` exists and customer outcome unclear | DESIGN.md DD-11 activation logic; D-08 defines the three-option UX |
| PROJ-07 | Detect Gate WB Pending and re-prompt before reporting status | DESIGN.md DD-11 pending state behavior; D-09 overrides strict reading -- show reminder, don't hard-block |
| PROJ-08 | Route to `/define` in revision mode when user signals goals changed | DESIGN.md DD-6 PRD revision; D-05 natural language detection |
| PROJ-09 | Route to `/milestone` in revision mode when user initiates re-planning | DESIGN.md DD-6 milestone re-planning; D-05 natural language detection |
| PROJ-10 | Remain strictly read-only after bootstrap | DESIGN.md DD-3 core principle |
| STATE-01 | `progress.txt` uses plain-text checkbox notation | progress-file/ format decision; DESIGN.md indicative format |
| STATE-02 | `milestone-status.txt` uses plain-text checkbox notation | DESIGN.md milestone-status.txt indicative format |
| STATE-03 | All skills read state files fresh on entry | DESIGN.md DD-3 rationale (no conversation memory) |
| STATE-04 | Write `milestone-status.txt` before `progress.txt` when both need updates | DESIGN.md sync contract -- note: `/project` only writes at bootstrap, so STATE-04 is a constraint for future skills; `/project` must document this contract |

</phase_requirements>

## Standard Stack

This project has no compiled code, no package dependencies, and no runtime beyond Claude Code itself. The "stack" is markdown files.

### Core

| Component | Format | Purpose | Why Standard |
|-----------|--------|---------|--------------|
| SKILL.md | Markdown with YAML frontmatter | Skill entry point and workflow definition | Established pattern across all 9 existing skills |
| references/*.md | Markdown | Supporting docs loaded on demand by SKILL.md | Keeps SKILL.md under 500 lines; pattern used by `create-prd` |
| progress.txt | Plain text with checkbox notation | Project state file created at bootstrap | Format decided in skills/project/progress-file/ analysis |
| AskUserQuestion | Claude Code built-in tool | Interactive user prompts | Repo convention; 2-4 options, max 12-char headers |

### Supporting

| Component | Format | Purpose | When to Use |
|-----------|--------|---------|-------------|
| docs/skills/project.md | Markdown | Detail documentation for the skill | Required by CONVENTIONS.md for every new skill |
| docs/SKILLS.md | Markdown | Catalog entry | Required by CONVENTIONS.md; add one row |

### Not Needed

| Thing | Why Not |
|-------|---------|
| npm/pip/any package manager | No code to install; this is prompt engineering |
| Test framework | No executable code; validation is manual invocation |
| Build tools | Nothing to compile |
| Database | State is plain text files |

## Architecture Patterns

### Project Structure (new files to create)

```
skills/project/
  SKILL.md                      # Main skill file (frontmatter + workflow steps)
  references/
    progress-format.md          # progress.txt format specification
    routing-logic.md            # State -> next action routing tables
    status-report-format.md     # Output format specification for status display
docs/
  skills/project.md             # Detail documentation
docs/SKILLS.md                  # (edit) Add catalog entry
```

### Pattern 1: Step-Based Skill Workflow

**What:** Skills use numbered `## Step N: Name` sections with clear action verbs. Each step completes a discrete action and shows work to the user before proceeding.

**When to use:** All skills in this repo.

**Example (from create-prd/SKILL.md):**
```markdown
## Step 1 -- Detect Project State

Read `progress.txt` from the project root. If the file does not exist, proceed to Step 2
(Bootstrap). If the file exists, proceed to Step 3 (Status Report).
```

### Pattern 2: Conditional Branching in Skills

**What:** Skills branch based on file existence or content. The branching logic is expressed as prose instructions to the LLM, not as code.

**When to use:** When the skill must handle multiple project states (bootstrap vs. existing, greenfield vs. brownfield).

**Example:**
```markdown
If `progress.txt` does not exist:
  - This is a new project. Proceed to Step 2 (Bootstrap).

If `progress.txt` exists:
  - Read the file. Proceed to Step 3 (Status Report).
```

### Pattern 3: Reference File Loading

**What:** SKILL.md instructs the LLM to `Read` a reference file at a specific step, keeping the main file concise while providing detailed specifications on demand.

**When to use:** When a step requires detailed format specs, lookup tables, or lengthy instructions that would bloat SKILL.md.

**Example (from create-prd/SKILL.md):**
```markdown
## Step 2 -- PRD Deep Dive Interview

Read `references/interview-guide.md` for the full question bank.
```

### Pattern 4: State Validation Before Action

**What:** Read all relevant state files at the beginning of the skill invocation, validate consistency, and surface warnings before performing any routing logic.

**When to use:** For `/project` specifically -- it must validate state integrity on every invocation.

### Anti-Patterns to Avoid

- **Monolithic SKILL.md:** Do not put format specifications, routing tables, and all prompts in a single file. Use `references/` to keep SKILL.md focused on workflow.
- **Implicit state assumptions:** Never assume conversation memory. Always read files fresh (STATE-03).
- **Auto-dispatching:** `/project` tells the user what to run; it does not invoke other skills. The user starts a new conversation (DD-2).
- **Writing state after bootstrap:** `/project` is read-only after creating `progress.txt` (PROJ-10, DD-3).
- **Hard-blocking on Gate WB Pending:** D-09 overrides the strict PROJ-07 reading. Show a reminder but display the full status report.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Interactive prompts | Custom prompt formatting | `AskUserQuestion` with 2-4 options | Repo convention; consistent UX across skills |
| File format spec | Inline prose in SKILL.md | Dedicated `references/progress-format.md` | Keeps SKILL.md under 500 lines; reusable by future skills |
| Gate-to-artifact mapping | Inline table in routing logic | Reference table in `references/routing-logic.md` | Single source of truth for the routing graph |

**Key insight:** The entire deliverable is prompt engineering. The "don't hand-roll" principle applies to prompt structure, not code libraries. The main risk is putting too much detail in SKILL.md and exceeding the practical 500-line limit.

## Common Pitfalls

### Pitfall 1: SKILL.md Size Explosion

**What goes wrong:** All routing logic, format specs, validation rules, and status display formatting are crammed into SKILL.md, exceeding 500 lines and degrading LLM instruction-following.
**Why it happens:** Natural tendency to keep everything in one file for simplicity.
**How to avoid:** Use `references/` subdirectory. SKILL.md contains the workflow skeleton; references contain the detailed specs. The STATE.md blockers section already flags this as a known risk.
**Warning signs:** SKILL.md exceeds 300 lines before routing logic is complete.

### Pitfall 2: Ambiguous Routing State Machine

**What goes wrong:** The routing logic has gaps -- project states that don't map to a clear "next action" recommendation, or states where multiple recommendations compete without priority.
**Why it happens:** The routing graph has many states: no gates approved, some gates approved, milestones in various states, spikes open/resolved, Gate WB pending/skipped/approved.
**How to avoid:** Build a complete state -> action routing table in `references/routing-logic.md`. Every possible combination of gate states, milestone states, and spike states must map to exactly one recommended action. Test the table by walking through scenarios mentally.
**Warning signs:** The routing table has "it depends" entries or blank cells.

### Pitfall 3: Inconsistent Status Notation

**What goes wrong:** The skill uses `[x]`, `[~]`, `[ ]`, `[-]` inconsistently -- e.g., using `[in-progress]` for milestone headers (bracket tag) vs. `[~]` for gate checkboxes, creating parsing confusion.
**Why it happens:** The TEXT_vs_YAML_REPORT.md specifically identified this as a risk -- two status notation systems coexisting.
**How to avoid:** Define one canonical notation in `references/progress-format.md` and use it consistently. The DESIGN.md indicative format uses `[x]`, `[~]`, `[ ]`, `[-]` uniformly. Stick with that.
**Warning signs:** The progress.txt template uses different status markers for gates vs. milestones.

### Pitfall 4: Gate WB Logic Complexity

**What goes wrong:** The Gate WB offer/pending logic becomes a nested if-else tree that is hard for the LLM to follow reliably.
**Why it happens:** Gate WB has four states (not offered, offered-pending, approved, skipped) interacting with greenfield/brownfield detection and the presence/absence of `working-backwards.md`.
**How to avoid:** Separate Gate WB handling into its own clearly labeled step with a decision table, not nested prose conditionals. Express as: "Check Gate WB state in progress.txt. If `[ ] Pending`, do X. If `[-] Skipped`, do Y. If `[x] Approved`, do Z. If no Gate WB line exists, evaluate whether to offer."
**Warning signs:** The Gate WB logic requires reading more than once to understand.

### Pitfall 5: Milestone Consistency Validation False Positives

**What goes wrong:** The consistency check between `progress.txt` milestone summary and `milestone-status.txt` fires false warnings because of formatting differences (e.g., "2/3 features complete" vs counting actual checkboxes).
**Why it happens:** The milestone summary in `progress.txt` is a stored rollup value, not computed. If `/build` updates `milestone-status.txt` but crashes before updating `progress.txt`, they diverge legitimately.
**How to avoid:** The consistency check should compare the actual feature completion count in `milestone-status.txt` against the stored count in `progress.txt`. Define exactly what "consistent" means in the reference docs.
**Warning signs:** The validation logic uses string matching instead of semantic comparison.

### Pitfall 6: D-09 vs PROJ-07 Contradiction

**What goes wrong:** The implementer follows PROJ-07 literally ("re-prompts user for a decision before reporting any further status") and hard-blocks the status report when Gate WB is Pending.
**Why it happens:** D-09 in CONTEXT.md explicitly overrides the strict PROJ-07 reading, but if the implementer reads REQUIREMENTS.md without CONTEXT.md, they'll implement hard-blocking.
**How to avoid:** SKILL.md must clearly state the D-09 behavior: show a gentle reminder at the top, then display the full status report. The CONTEXT.md decision takes precedence over the literal requirement text.
**Warning signs:** The skill suppresses the status report when Gate WB is Pending.

## Code Examples

Since this project is markdown-only, "code examples" are SKILL.md patterns and progress.txt format examples.

### SKILL.md Frontmatter Pattern

```yaml
---
name: project
description: >
  Project orchestrator. Bootstraps progress.txt on first run, reports project
  state, and routes to the next skill on every subsequent invocation. Use when
  starting a new project, checking project status, or deciding what to do next.
  Phrases like "where am I", "project status", "what's next" are good triggers.
disable-model-invocation: true
---
```

### Bootstrap progress.txt Format (from DESIGN.md indicative example)

```
# Progress: <Project Name>
# Created: <ISO date>
# Status: [ ] pending  [~] in progress  [x] complete  [-] skipped

## Gates

[ ] Gate 0: Codebase Alignment
[ ] Gate WB: Working Backwards
[ ] Gate 1: Scope Review
[ ] Gate 2: Design Review
[ ] Gate 3: Milestone Review

## Milestones

(none yet)

## Spikes

(none yet)
```

### Status Report Output Format (D-01 structured summary)

```
PROJECT STATUS: <Project Name>

GATES:
  [x] Gate 0: Codebase Alignment    Approved: 2026-03-15  docs/codebase-assessment.md
  [-] Gate WB: Working Backwards    Skipped
  [x] Gate 1: Scope Review          Approved: 2026-03-16  prd.md
  [x] Gate 2: Design Review         Approved: 2026-03-17  docs/ARCHITECTURE_AND_DESIGN.md
  [~] Gate 3: Milestone Review      In progress

ACTIVE MILESTONE: 01 - Core Auth (2/3 features complete)
  [x] Feature 01.1: User Registration     Complete
  [x] Feature 01.2: Session Management    Complete
  [~] Feature 01.3: Password Reset        In progress

UPCOMING:
  [ ] Milestone 02: Dashboard  (0/2 features complete)

SPIKES:
  [x] WebSocket Auth Compatibility    Resolved 2026-03-17
  [ ] SQLite to Postgres Migration    Open

RECOMMENDED: Run `/plan` to create the implementation plan for Feature 01.3: Password Reset
Also available:
  - `/spike` -- research a technical question
  - `/milestone` -- define the next milestone
```

### Routing Decision Table (key excerpt)

```
| State | Recommended Action | Alternatives |
|-------|-------------------|--------------|
| No progress.txt | Bootstrap (internal) | -- |
| No gates approved | Run `/define` | -- |
| Gate WB Pending | Resolve Gate WB decision | `/define` (continue) |
| Gate 0 approved, no Gate 1 | Run `/define` (continue) | -- |
| Gate 1 approved, no Gate 2 | Run `/design` | `/spike` |
| Gate 2 approved, no milestones | Run `/milestone` | `/spike` |
| Milestone(s) defined, features unplanned | Run `/plan` for next feature | `/spike`, `/milestone` |
| Feature planned, not built | Run `/build` for planned feature | `/plan` (next feature), `/spike` |
| All features complete in milestone | Run `/milestone` (next) or celebrate | `/design` (refresh) |
| User says "goals changed" | Run `/define` in revision mode | -- |
| User says "re-plan milestone" | Run `/milestone` in revision mode | -- |
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `create-prd` monolithic PRD | Milestone-scoped pipeline with gates | This project (2026-04) | `/project` is the new entry point; `create-prd` remains untouched |
| YAML progress files | Plain text with checkbox notation | Design phase (2026-04) | 53% fewer tokens; safer for LLM write-back |
| Single conversation for entire workflow | Phase-isolated skills with clean context | This project (2026-04) | `/project` routes between separate conversations |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual invocation + markdown linting |
| Config file | `.markdownlint.jsonc` (existing) |
| Quick run command | `bash cicd/lint-markdown.sh` |
| Full suite command | `bash cicd/lint-markdown.sh` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROJ-01 | Bootstrap creates valid progress.txt | manual | Invoke `/project` in empty dir, inspect output | N/A |
| PROJ-02 | Reads state and reports status | manual | Invoke `/project` with populated progress.txt | N/A |
| PROJ-03 | Routes to correct next skill | manual | Invoke `/project` at various pipeline stages | N/A |
| PROJ-04 | Warns on missing artifact paths | manual | Delete a gate artifact, invoke `/project` | N/A |
| PROJ-05 | Warns on milestone consistency divergence | manual | Edit milestone-status.txt to diverge, invoke | N/A |
| PROJ-06 | Offers Gate WB appropriately | manual | Invoke `/project` with no working-backwards.md | N/A |
| PROJ-07/D-09 | Gate WB Pending reminder (not hard-block) | manual | Set Gate WB to Pending, invoke `/project` | N/A |
| PROJ-08 | Routes to /define revision on keywords | manual | Say "goals changed" during /project session | N/A |
| PROJ-09 | Routes to /milestone revision on keywords | manual | Say "re-plan" during /project session | N/A |
| PROJ-10 | Read-only after bootstrap | manual | Inspect file writes during /project invocation | N/A |
| STATE-01 | progress.txt uses checkbox notation | manual | Inspect bootstrapped progress.txt | N/A |
| STATE-02 | milestone-status.txt uses checkbox notation | manual | Inspect existing milestone-status.txt parsing | N/A |
| STATE-03 | Reads state fresh on entry | manual | Verify SKILL.md reads files at start | N/A |
| STATE-04 | Write ordering contract documented | manual | Verify SKILL.md/references document the contract | N/A |
| ALL | Markdown lint passes | unit | `bash cicd/lint-markdown.sh` | Exists |

### Sampling Rate

- **Per task commit:** `bash cicd/lint-markdown.sh` (validates all markdown files)
- **Per wave merge:** Manual invocation of `/project` against test scenarios
- **Phase gate:** All 5 success criteria from phase description verified by manual invocation

### Wave 0 Gaps

- No automated test infrastructure is possible for prompt-based skills; validation is manual invocation against scenarios
- Markdown linting exists and covers syntactic correctness of all new `.md` files
- Consider creating a `tests/scenarios/` directory with sample `progress.txt` files representing different project states, for manual testing reference (not automated)

## Open Questions

1. **Exact progress.txt bootstrap content for greenfield vs brownfield**
   - What we know: DD-3 says Gate 0 is skipped for greenfield; DD-10 defines greenfield detection
   - What's unclear: Should bootstrapped progress.txt for greenfield projects omit Gate 0 entirely, or include it as `[-] Skipped`?
   - Recommendation: Include as `[-] Skipped` for consistency -- every progress.txt has the same gate structure. This is Claude's discretion per CONTEXT.md.

2. **Gate 3 representation in progress.txt**
   - What we know: TEXT_vs_YAML_REPORT.md identified milestone status duplication risk (Gate 3 in Gates section AND milestone header)
   - What's unclear: The recommended resolution was to not duplicate -- but the DESIGN.md indicative format shows Gate 3 in the Gates section
   - Recommendation: Follow the DESIGN.md indicative format (Gate 3 as a single line in Gates section, milestone headers in Milestones section with their own status). The consistency validation (PROJ-05) catches divergence.

3. **500-line SKILL.md budget allocation**
   - What we know: STATE.md blockers section flags this risk; the routing logic and format specs are substantial
   - What's unclear: Exact line count breakdown between SKILL.md and references
   - Recommendation: SKILL.md should be ~200-300 lines (workflow steps + key rules), with 2-3 reference files totaling ~300-500 lines for format specs and routing tables

## Sources

### Primary (HIGH confidence)

- `skills/project/DESIGN.md` -- DD-1 through DD-14, artifact inventory, format examples (authoritative design source)
- `skills/project/progress-file/` -- Format decision artifacts (TEXT_vs_YAML_REPORT.md, REQUIREMENTS.md)
- `skills/create-prd/SKILL.md` -- Reference pattern for skill structure (145 lines, 7 steps)
- `.planning/phases/01-project-router/01-CONTEXT.md` -- User decisions D-01 through D-09
- `.planning/REQUIREMENTS.md` -- PROJ-01 through PROJ-10, STATE-01 through STATE-04
- `.planning/codebase/CONVENTIONS.md` -- Skill file conventions, naming patterns, documentation requirements
- `.planning/codebase/STRUCTURE.md` -- Directory layout, skill bundle structure, key locations

### Secondary (MEDIUM confidence)

- `.planning/STATE.md` -- Blockers and open questions about shared references and 500-line limits

### Tertiary (LOW confidence)

- None -- all findings sourced from project artifacts

## Project Constraints (from CLAUDE.md)

- Use `<br/>` for line breaks in Mermaid diagram node labels (not `\n`)
- No other actionable directives in CLAUDE.md; behavioral rules are in `.claude/rules/`

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- this is a markdown-only repo with established patterns across 9 existing skills
- Architecture: HIGH -- DESIGN.md provides complete specifications; CONTEXT.md resolves all ambiguities
- Pitfalls: HIGH -- identified from format analysis report, STATE.md blockers, and CONTEXT.md decision overrides

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (stable domain; no external dependencies that change)
