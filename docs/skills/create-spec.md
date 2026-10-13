# Create Spec

**Source:** `skills/create-spec/`
**Command:** `/create-spec`
**Activation:** Manual only (`disable-model-invocation: true`) — invoked via slash command. Not auto-triggered by conversational phrases.

## Description

Captures requirements, scope, and interface contracts in a single root-level `spec.md`, before a PRD is written. It sits between a settled discussion (or a plan-mode plan) and `/create-prd`: the spec is a promotion of decisions already made, not a re-derivation of them. When a plan-mode plan exists in `~/.claude/plans/`, the skill offers to seed from it and maps the plan's sections across verbatim. `/create-prd` then reads `spec.md` and runs its interview in confirmation-only mode.

Pipeline: discuss → plan mode → **`/create-spec`** → `/create-prd` → `/start-feature`.

The skill writes one file and nothing else. It never writes `prd.md`, `progress.txt`, or `milestone-status.txt`, and it does not design past the spec — no implementation steps, commit sequences, or task breakdowns.

## Bundle Contents

| File | Purpose |
|---|---|
| `SKILL.md` | Skill definition with 5-step workflow (Step 0–4), plan-to-spec section mapping, identifier convention, and escalation rules |
| `assets/spec-template.md` | `spec.md` scaffold — Context, Requirements, Out of scope, Approach (with Decisions table), Interface contracts, Acceptance criteria, Risks, Open assumptions, External dependencies, References |

## Usage

```
/create-spec
```

No arguments. Run from the project root, or from the subdirectory where the project will live.

## Workflow

### Step 0 — Find a seed

Lists recent plans in `~/.claude/plans/` and matches on content, not filename (plan filenames are generated and do not name the initiative). Ignores `*-agent-*.md` subagent scratch files. If a plausible plan is found, shows its path and H1 and asks whether to seed from it; otherwise seeds from the conversation and says so.

Plan sections map across as follows:

| Plan section | `spec.md` section |
|---|---|
| Context | Context |
| Locked decisions / Decisions taken | Approach |
| Verified facts / Corrections | Context, with verification noted inline |
| Sources of truth | References |
| Deliverables | Requirements, Interface contracts |
| Out of scope | Out of scope |
| Verification | Acceptance criteria |
| Risks | Risks |
| Open items / Open questions | Open assumptions |

Execution sections — phase and commit sequences, step lists, rollback procedures, go/no-go gates, file-by-file change lists — are deliberately not carried across. They are `/create-prd` and `/start-feature` output.

### Step 1 — Draft

Reads `assets/spec-template.md` and writes `spec.md`. Fills every section there is material for and deletes the rest (an empty heading reads as an answered question), stating which sections were dropped and why.

### Step 2 — Close the gaps

Reviews the draft for gaps that make a spec unusable downstream and resolves each through `AskUserQuestion`, 2–4 questions at a time:

- A requirement that is not testable ("fast", "reliable")
- An acceptance criterion tracing to no requirement, or a requirement with no criterion
- An interface named without its contract (signature, data shape, failure behaviour)
- A decision recorded without its rejected alternative
- A statement of fact with no source

Answers are never invented. Anything the user cannot settle now goes to `Open assumptions`.

### Step 3 — Optional red-team

Offers `/red-team` against `spec.md` before handoff. Worth it for irreversible work, security or data concerns, or a contested approach; skipped for small reversible changes. Accepted findings are applied and the pass is noted in `References`.

### Step 4 — Report

Reports the title, seed source, counts (requirements, out-of-scope items, interface contracts, acceptance criteria, risks, open assumptions), one line per open assumption, and a pointer to `/create-prd`.

## Output

| Artifact | Location | Contents |
|---|---|---|
| Specification | `spec.md` (working directory root) | Context, numbered Requirements, Out of scope, Approach with Decisions, Interface contracts, Acceptance criteria, Risks, Open assumptions, External dependencies, References |

## Identifier Convention

Assigned in the spec, reused downstream, never renumbered:

| Kind | Format | Example |
|---|---|---|
| Requirement | plain integer, sub-lettered when a requirement has parts | `3`, `4a` |
| Decision | `D<n>` | `D7` |
| Risk | `R<n>` | `R2` |

Deliverable IDs (`S<n>`) and tiered test IDs (`T<tier>.<n>`) belong to `/project`. Their appearance in a spec signals the work has outgrown this skill.

## Rules

- **One file.** `spec.md` at the working directory root. No new directories or companion documents.
- **Promote, do not re-derive.** Settled plan decisions are carried across verbatim.
- **Facts and decisions are distinct.** Verified facts cite what verified them; unresolved items go in `Open assumptions`.
- **Number the requirements.** Downstream documents cite them by number.
- **Do not design past the spec.**

## Escalation

If the spec grows past one file — a separate options analysis, a decision register with its own lifecycle, tiered test plans, milestone grouping — the skill stops and tells the user the work is `/project`-shaped rather than growing `spec.md` to compensate.

## Error Handling

- **No plan found:** Seeds from the conversation. Not an error.
- **Plan stale or contradicted:** Shows the conflict and asks which stands; does not silently prefer either.
- **Missing `assets/spec-template.md`:** Tells the user and builds the document from the Step 1 section list, stating that no template was used.
- **User skips a section:** Allowed. The heading is deleted and the omission named in the report.
- **Interrupted:** `spec.md` is written in Step 1, so partial work survives. Re-invocation detects the file and offers to continue from Step 2.

## When to Use

- A discussion or plan-mode plan has concluded and requirements need a durable home before `/create-prd`
- Phrases like "write the spec", "capture requirements before the PRD", "promote this plan"

## When Not to Use

- Structured multi-milestone work — use `/project`
- Answering a bounded technical question — use `/research` or `/spike`
- Designing architecture from an approved PRD — use `/design`
- When the working directory's `progress.txt` contains `## Gates` / `## Milestones` — that repo is under `/project` management. The skill stops; continue with `/project`, or run from a dedicated subdirectory
- When `prd.md` already exists — a spec written after the PRD inverts the pipeline. The skill says so and asks for confirmation before continuing

## Related Skills

- **create-prd** — the next step; reads `spec.md` and runs its interview in confirmation-only mode
- **research** — use first when the spec depends on an unanswered technical question
- **red-team** — optional adversarial pass over `spec.md` before handoff
- **project** — where work goes when it outgrows a single spec file
