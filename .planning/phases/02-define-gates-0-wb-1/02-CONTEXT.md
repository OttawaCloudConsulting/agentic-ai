# Phase 2: /define (Gates 0/WB/1) - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Single-session skill that produces codebase assessment (Gate 0), optional Working Backwards doc (Gate WB), and an approved PRD (Gate 1). Runs as one continuous conversation — user does not leave between gates. Supports revision mode for existing PRDs. This phase delivers one complete, invokable skill at `skills/project/define/SKILL.md`.

</domain>

<decisions>
## Implementation Decisions

### SKILL.md decomposition
- **D-01:** Per-gate reference files — `gate-0-codebase.md`, `gate-wb-working-backwards.md`, `gate-1-prd.md` each contain the full spec for that gate. SKILL.md (~300 lines) handles flow and reads the relevant reference at each gate start.
- **D-02:** `review-checklist-template.md` as a shared reference for all 3 gates' review checklists.
- **D-03:** `assets/prd-template.md` for the PRD output structure.
- **D-04:** Each skill gets its own copy of shared references (e.g., `progress-format.md`) — no cross-directory reads between skills.
- **D-05:** `/define` lives at `skills/project/define/` — nested under the project suite, not top-level.

### Gate flow UX
- **D-06:** Produce-then-review pattern at each gate — Claude produces the full artifact, presents it, then offers Approve / Revise. Revision happens in-session without restart.
- **D-07:** Review checklists are auto-generated from artifact contents. Claude pre-checks items it can verify; user reviews and resolves remaining items. All items must be `[x]` or `[-]` (N/A with reason) before gate approval is recorded (DEF-06).
- **D-08:** Rejection = revision request. Claude asks what's wrong, fixes it, re-presents. No explicit abort — user can simply stop the conversation.
- **D-09:** Gate 1 partial approval uses a section checklist (multiSelect). User checks approved sections, unchecked ones get focused revision. Claude asks what should change in unchecked sections.

### Codebase assessment (Gate 0)
- **D-10:** Agent-based deep scan — spawn a sub-agent that reads 20-40 files and returns structured findings. `/define` synthesizes into `docs/codebase-assessment.md`.
- **D-11:** Greenfield detection via heuristics: no src/app/lib directories, no dependency manifests (package.json, pyproject.toml, Cargo.toml, go.mod), fewer than 5 non-config files, only README + license + gitignore. All must be true to skip Gate 0.
- **D-12:** At Gate 1, silently re-read `docs/codebase-assessment.md` from disk (DEF-16) — no recap shown to user, used internally for PRD interview context.

### PRD interview design (Gate 1)
- **D-13:** Fork `create-prd`'s `references/interview-guide.md` and adapt: remove architecture questions (moved to `/design`), add milestone-scoping guidance (DD-1), add revision-mode interview flow, keep Scope/Security/Operational rounds.
- **D-14:** When Gate WB was used, Working Backwards doc is read as context only — does not auto-populate PRD sections. Full interview still runs, just better informed by the WB narrative.
- **D-15:** Revision mode uses diff-focused interview: read existing `prd.md`, ask "What changed?", interview only affected sections, surface list of downstream artifacts that may need re-review (do not auto-reset per DD-6).

### Claude's Discretion
- Exact codebase scan agent prompt and file selection heuristics
- Assessment section ordering and formatting
- PRD interview pacing (questions per round)
- Exact phrasing of gate approval prompts
- How to handle edge cases in greenfield detection (e.g., monorepo with sparse content)
- Progress.txt write format and recording details

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design decisions
- `skills/project/DESIGN.md` — All 13 design decisions (DD-1 through DD-13); authoritative source for gate behavior, state formats, artifact paths
- `skills/project/DESIGN.md` §DD-2 — `/define` session scope: Gates 0, WB, 1 as single continuous session
- `skills/project/DESIGN.md` §DD-6 — No automatic cascade reset on PRD revision
- `skills/project/DESIGN.md` §DD-7 — Gate review behaviors and rules
- `skills/project/DESIGN.md` §DD-11 — Gate WB optional stage, Pending state behavior
- `skills/project/DESIGN.md` §DD-12 — Test command planned in `/plan`, executed in `/build`

### Requirements
- `.planning/REQUIREMENTS.md` §Define — DEF-01 through DEF-16

### Predecessor skill (fork source)
- `skills/create-prd/SKILL.md` — SKILL.md structure pattern (frontmatter, steps, AskUserQuestion usage)
- `skills/create-prd/references/interview-guide.md` — Interview question bank to fork and adapt for Gate 1

### State file formats
- `skills/project/references/progress-format.md` — Progress.txt format spec (to be copied into define/references/)

### Existing /project skill (reference pattern)
- `skills/project/SKILL.md` — Reference for how SKILL.md loads external specs at appropriate steps
- `skills/project/references/` — Pattern for references/ directory organization

### Codebase conventions
- `.planning/codebase/CONVENTIONS.md` — SKILL.md frontmatter, naming patterns, documentation requirements
- `.planning/codebase/STRUCTURE.md` — Directory layout, skill bundle structure, key locations

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/create-prd/SKILL.md` — Fork source for Gate 1 interview flow; 5-round interview structure with `AskUserQuestion`
- `skills/create-prd/references/interview-guide.md` — Question bank covering Scope, Components, I/O, Security, Operational
- `skills/create-prd/assets/prd-template.md` — PRD template to adapt (remove architecture sections, add milestone-scoping)
- `skills/project/SKILL.md` — Reference for how to structure a multi-step SKILL.md with external reference loading
- `skills/project/references/progress-format.md` — Progress.txt format spec (copy into define/references/)

### Established Patterns
- Skills are markdown-only prompt files — no compiled code
- SKILL.md uses numbered steps with clear action verbs
- `AskUserQuestion` for interactive prompts (2-4 options, max 12-char headers)
- `disable-model-invocation: true` mandatory in frontmatter
- Reference loading: SKILL.md reads external spec files at the step that needs them (not all upfront)
- Documentation requirement: SKILL.md + detail doc + catalog entry per skill

### Integration Points
- `progress.txt` at project root — `/define` writes gate approvals here (Gate 0, WB, 1)
- `docs/codebase-assessment.md` — produced by Gate 0, consumed by Gate 1 (re-read) and later by `/design`
- `docs/working-backwards.md` — produced by Gate WB (optional), consumed by Gate 1 as context
- `prd.md` at project root — produced by Gate 1, consumed by `/design` and `/milestone`
- `docs/reviews/gate-{0,wb,1}-review.md` — review checklists per gate

</code_context>

<specifics>
## Specific Ideas

- Directory structure: `skills/project/define/` with self-contained `references/` and `assets/`
- Per-gate reference files map 1:1 with gates — easy to find and maintain
- create-prd's interview is the starting point — proven question bank, adapted not rewritten
- Greenfield detection is heuristic-based and conservative — all conditions must be true to skip Gate 0

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-define-gates-0-wb-1*
*Context gathered: 2026-04-02*
