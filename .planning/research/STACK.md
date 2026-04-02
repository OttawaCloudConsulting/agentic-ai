# Technology Stack

**Project:** Project Skill Suite (`/project`, `/define`, `/design`, `/milestone`, `/plan`, `/build`, `/spike`)
**Researched:** 2026-04-02
**Sources:** Direct codebase inspection — `skills/`, `docs/`, `.claude/commands/`

---

## Summary

This project produces markdown prompt files (skills). There is no compiled code, no runtime, and
no package manager involved. The "stack" is a set of file conventions, naming patterns, structural
rules, and state-file schemas that the skills must follow to integrate correctly with the existing
repo and with each other.

---

## Skill File Conventions

### Structure

Every skill in this repo is a **directory** (not a single file) located at `skills/<name>/`.

```
skills/<name>/
├── SKILL.md          (required) — YAML frontmatter + skill body
├── assets/           (optional) — templates and boilerplate the skill writes to disk
│   └── *.md / *.txt
├── references/       (optional) — supporting docs loaded on-demand into context
│   └── *.md
├── scripts/          (optional) — executable shell scripts for deterministic tasks
│   └── *.sh
└── review/           (convention) — internal review artifacts, not consumed by Claude
    ├── PLAN.md
    ├── FEEDBACK.md
    └── BENCHMARK.md
```

Single-file workflows (no assets or references needed) live in `commands/` as `.md` files, not
in `skills/`. The skills vs. commands split is load-bearing — the repo's documentation and
consuming instructions (`cp -r skills/<name>/ <target>/.claude/skills/<name>/`) depend on it.

### Naming

- Directory name: **lowercase kebab-case** (e.g., `create-prd`, `occ-skill-creator`)
- The directory name becomes the slash command: `skills/create-prd/` → `/create-prd`
- `SKILL.md` is always uppercase — it is the entry point Claude reads
- Reference and asset files: lowercase kebab-case with `.md` extension
- Progress/state files: lowercase with `.txt` extension (e.g., `progress.txt`, `milestone-status.txt`)
- One exception: `docs/ARCHITECTURE_AND_DESIGN.md` is uppercase to signal it is a project-wide
  reference document, distinct from per-milestone artifacts

### SKILL.md Frontmatter

Required fields:

```yaml
---
name: skill-name               # kebab-case, max 64 characters, matches directory name
description: >-
  What the skill does. Include trigger phrases — this is the primary auto-invocation signal.
  Includes "when to use" and "when NOT to use" to prevent false triggers.
disable-model-invocation: true # Required for interactive or multi-step skills
---
```

Optional fields: `compatibility`, `license`.

**`disable-model-invocation: true` is mandatory** for all skills in this pipeline. Every skill in
this suite is interactive or stateful — auto-triggering on phrase match would corrupt state.

### SKILL.md Body Constraints

- **Hard limit: 500 lines.** Content beyond 500 lines must move to `references/`.
- No auxiliary docs (README, CHANGELOG, LICENSE, INSTALLATION_GUIDE). Only files an AI agent
  needs to execute the skill.
- Information lives in either `SKILL.md` or `references/` — never duplicated across both.
- Reference files are loaded on-demand; SKILL.md must include explicit read instructions (e.g.,
  "Read `references/interview-guide.md` for the full question bank").
- Use imperative/infinitive form throughout (e.g., "Read the file" not "You should read the file").

### Progressive Disclosure Pattern

Skills use three-tier context loading:

1. **Metadata** (`name` + `description`) — always in context (~100 words)
2. **SKILL.md body** — loaded when the skill triggers (<500 lines)
3. **Bundled resources** — loaded by explicit instruction when needed

This pattern is mandatory, not optional. All five skills in the new suite must follow it.

---

## Documentation Conventions

### Catalog Entry

Each skill gets a detail doc at `docs/skills/<name>.md`. This is required — see
`memory/feedback_docs_required.md` (new components must include catalog + detail doc updates).

The detail doc structure (from `docs/skills/create-prd.md`):

```markdown
# Skill Title

**Source:** `skills/<name>/`
**Command:** `/<name>`
**Activation:** Manual only (disable-model-invocation: true)

## Description
[What it does, how the workflow runs]

## Bundle Contents
[Table: File | Purpose]

## Usage
[Minimal invocation example]

## Workflow
[Step-by-step with quality bars where relevant]

## Output
[Table: Artifact | Location | Contents]

## Rules
[Bulleted operational constraints]

## Error Handling
[Named error conditions and responses]

## When to Use
## When Not to Use
## Related Skills
```

### Catalog Index

`docs/SKILLS.md` is the catalog index. It contains:
- A quick reference table: Skill | Command | Purpose | Details link
- How Skills Work section
- Skill Bundle Structure with canonical directory layout
- Consuming Skills instructions

**The new suite must add a row to this table** and update the consuming instructions with the
copy command for each new skill directory.

### Design Decisions Document

For non-trivial skills with significant design work, a `DESIGN.md` lives inside the skill
directory (e.g., `skills/project/DESIGN.md`). This is where architectural decisions are captured
with `### DD-N: Title` headings, rationale, and tradeoffs. It is a working document for skill
authors — not consumed by Claude at runtime.

Open questions during design live in `skills/<name>/design-decisions/OPEN_QUESTIONS.md` until
resolved, then are updated in-place with `~~strikethrough~~` and a decision record.

---

## State File Patterns

### Decision: Plain Text

The repo has an explicit, researched decision (documented in `skills/project/progress-file/`) to
use plain text for all state files. YAML was evaluated and rejected. The decision is final.

Key rationale: plain text wins on human editability (UR-2), model write safety (UR-4, UR-5),
token efficiency (NFR-2, ~53% more verbose in YAML for equivalent content), and backward
compatibility (NFR-1, checkbox notation is established).

### Project-Level: `progress.txt`

Lives at the project root. Owned by `/project` (read-only except bootstrap) and written by
phase skills. Format: plain text with labelled sections.

Checkbox notation (established, must be preserved):
- `[ ]` pending
- `[~]` in progress
- `[x]` complete
- `[-]` skipped

Structure:
- GATES section — one line per gate with checkbox, gate name, approval date
- ARTIFACTS section — cross-references to prd.md, docs/, milestones/
- Milestone entries — `## Milestone N: Name [status]` headers with feature summary lines
- SPIKES section — spike entries with status and artifact paths

**Token budget constraint:** `progress.txt` is loaded into context on every skill invocation.
It must be as concise as possible. Status changes must touch a single line (diff-friendly).

### Milestone-Level: `milestone-status.txt`

Lives at `milestones/<NN>-<name>/milestone-status.txt`. Owned by `/milestone` and `/build`.
Contains feature entries with plan paths, sub-feature checklists, and notes. Only read by
skills working on that specific milestone — intentional scope isolation.

### Artifact Cross-References

State files do not contain artifact content — they contain paths to artifact files. This is
the contract between the state layer and the document layer:

| State entry | Points to |
|-------------|-----------|
| Gate approval | `docs/reviews/gate-N-review.md` |
| PRD | `prd.md` |
| Architecture | `docs/ARCHITECTURE_AND_DESIGN.md` |
| Codebase assessment | `docs/codebase-assessment.md` |
| Working Backwards | `docs/working-backwards.md` |
| Milestone definition | `milestones/<NN>-<name>/README.md` |
| Feature plan | `milestones/<NN>-<name>/plans/<feature>.md` |
| Spike | `docs/spikes/<topic>.md` |

---

## Key Patterns from `create-prd` to Carry Forward into `/define`

`/define` is forked from `create-prd` (per `OPEN_QUESTIONS.md` OQ-2 resolution). These patterns
must carry forward:

### 1. Prerequisites Check

`create-prd` checks for existing output files and confirms with the user before overwriting.
`/define` must do the same, extended to all gate artifacts it produces (codebase assessment,
working-backwards, prd.md, gate review files).

### 2. Interrupted Session Recovery

`create-prd` detects existing files on re-invocation and offers to resume from the last
completed step. `/define` must detect gate state from `progress.txt` and offer resume from
the last approved or pending gate.

### 3. One Round at a Time

`create-prd` groups questions into rounds of 2-4, never dumping all questions at once.
This pattern is mandatory and carries forward to all interview phases in `/define`.

### 4. Show Work After Each Step

After each write, the skill tells the user what was added or changed before proceeding.
This is a core UX contract in `create-prd` and must be preserved in `/define`.

### 5. Template-First Writing

`create-prd` reads a template file before creating output artifacts. `/define` should follow
the same pattern: read the relevant asset template, then populate and write. Templates live
in `assets/`.

### 6. Asset Templates

`create-prd` uses:
- `assets/prd-template.md` — PRD scaffold
- `assets/architecture-template.md` — architecture doc scaffold
- `assets/progress-template.txt` — progress file scaffold

`/define` will use modified versions of these plus new templates for:
- `assets/codebase-assessment-template.md`
- `assets/working-backwards-template.md`
- Updated `assets/prd-template.md` (milestone-summary format, not feature-list format)
- Updated `assets/progress-template.txt` (gate-based format, not feature-list format)

### 7. Quality Bars

`create-prd` states explicit quality bars inline (e.g., "Target 10–20 Design Decisions for a
substantial architecture"). These must be preserved and extended — each gate in `/define` should
have an explicit quality bar stated in SKILL.md.

### 8. Cross-Reference Enforcement

`create-prd` has a dedicated cross-reference step (Step 4) verifying that component names,
parameter names, and feature titles match across documents. `/define` must enforce the same
consistency between `prd.md`, `docs/ARCHITECTURE_AND_DESIGN.md`, and the gate review files.

---

## Artifact Naming Conventions (from DESIGN.md DD-14 / Artifacts section)

These are resolved decisions from DESIGN.md — skills must implement exactly:

| Artifact | Path pattern | Notes |
|----------|-------------|-------|
| Codebase assessment | `docs/codebase-assessment.md` | lowercase, hyphenated |
| Working backwards | `docs/working-backwards.md` | lowercase, hyphenated |
| PRD | `prd.md` | project root, lowercase |
| Architecture | `docs/ARCHITECTURE_AND_DESIGN.md` | UPPERCASE — signals project-wide reference |
| Milestone dir | `milestones/<NN>-<name>/` | zero-padded two-digit sequence + kebab slug |
| Milestone README | `milestones/<NN>-<name>/README.md` | UPPERCASE |
| Milestone state | `milestones/<NN>-<name>/milestone-status.txt` | lowercase `.txt` |
| Feature plan | `milestones/<NN>-<name>/plans/<feature>.md` | kebab slug from feature title |
| Gate reviews (0–2) | `docs/reviews/gate-{0,wb,1,2}-review.md` | |
| Gate 3 review | `milestones/<NN>-<name>/reviews/gate-3-review.md` | |
| Gate 4 review | `milestones/<NN>-<name>/reviews/gate-4-<feature>-review.md` | |
| Spike | `docs/spikes/<topic>.md` | kebab slug from question topic |
| Project state | `progress.txt` | project root, lowercase `.txt` |

**General rules:**
- All names: lowercase kebab-case (hyphens, not underscores, not spaces)
- Names derived from titles at creation time; do not change if the title is later revised
- `.md` for documents, `.txt` for state/progress files
- UPPERCASE reserved for project-wide reference docs and milestone READMEs

---

## Constraints Governing the New Skills

1. **No compiled code.** Skills are Markdown prompt files. No Node, Python, or shell scripts
   unless they are self-contained utilities in `scripts/` (none are currently anticipated for
   this suite).

2. **SKILL.md under 500 lines.** Each of the seven skills must stay within this limit. Given
   the complexity of `/define` (three gates, codebase assessment, Working Backwards, PRD
   interview), this will require aggressive use of `references/` for interview guides, gate
   checklists, and templates.

3. **`disable-model-invocation: true` on all skills.** No auto-triggering. Users always invoke
   via `/project` (the orchestrator entry point) or directly by slash command.

4. **Files are the API.** Skills communicate exclusively through files. No in-memory handoffs,
   no cross-skill function calls, no shared conversation state.

5. **Progress file is append-friendly.** Skills write to `progress.txt` by appending or updating
   specific lines — never by rewriting the entire file. This is a write-safety constraint
   derived from the plain-text format decision.

6. **Gate approval is explicit.** No phase advances without the user typing an affirmative
   response. Skills must ask directly ("Approve Gate N to proceed?") — they do not infer
   approval from silence or continuation.

7. **Checklist completeness before gate approval.** Each gate's review checklist must have all
   items resolved (`[x]` or `[-]` with reason) before the skill records approval in
   `progress.txt`. This is validated by the skill, not assumed.

8. **`create-prd` is untouched.** The new `/define` is a fork — `create-prd` continues to
   exist as a standalone skill for the monolithic PRD workflow. No modifications to
   `skills/create-prd/`.

9. **Skill directory goes in `skills/project/` hierarchy or new top-level directories.** The
   `/project` router already occupies `skills/project/`. Each new skill (`define`, `design`,
   `milestone`, `plan`, `build`, `spike`) gets its own directory: `skills/define/`,
   `skills/design/`, etc.

10. **Documentation is required.** Each new skill needs a detail doc in `docs/skills/<name>.md`
    and a row in `docs/SKILLS.md`. This is a repo-level requirement (not optional).
