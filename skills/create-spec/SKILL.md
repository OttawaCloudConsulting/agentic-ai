---
name: create-spec
description: >
  Capture requirements, scope, and interface contracts in a single root-level spec.md
  before writing a PRD. Seeds from an existing plan-mode plan when one exists, so the
  spec is a promotion of settled decisions rather than a re-derivation. Use when a
  discussion or plan has concluded and requirements need a durable home before
  /create-prd. Phrases like "write the spec", "create a spec", "capture requirements
  before the PRD", "promote this plan" are good triggers. Do NOT use for structured
  multi-milestone work (use /project), for answering a bounded technical question (use
  /research or /spike), or for designing architecture from an approved PRD (use /design).
disable-model-invocation: true
---

# /create-spec — Requirements Capture

Produce one file, `spec.md`, at the working directory root, alongside `prd.md` and
`progress.txt`. It is the input to `/create-prd`, which reads it and runs its interview in
confirmation-only mode instead of eliciting from scratch.

Pipeline: discuss → plan mode → **`/create-spec`** → `/create-prd` → `/start-feature`.

## Rules

- **One file.** `spec.md` at the working directory root. No new directories, no companion
  documents. This is the light pipeline; it stays flat.
- **Promote, do not re-derive.** If a plan already settled something, carry it across
  verbatim. Re-generating settled decisions from conversation loses fidelity.
- **Facts and decisions are distinct.** Anything verified goes in with what verified it.
  Anything unresolved goes in `Open assumptions`, never as a confident statement.
- **Number the requirements.** Downstream documents cite them by number.
- **Do not design past the spec.** No implementation steps, no commit sequences, no task
  breakdown. Those are `/create-prd` and `/start-feature` output.
- **Never write `prd.md`, `progress.txt`, or `milestone-status.txt`.**

## Escalation — when this skill is the wrong tool

If the spec is growing past one file — a separate options analysis, a decision register with
its own lifecycle, tiered test plans, milestone grouping — stop and tell the user the work is
`/project`-shaped. Say it plainly and name the skill (`/project`). Do not grow `spec.md` to
compensate.

## Prerequisites

- Working directory is the project root (or the subdirectory where the project will live).
- **Schema guard.** If `progress.txt` in the working directory contains `## Gates` or
  `## Milestones`, this repo is under `/project` management — **stop** and tell the user:
  either continue with `/project`, or run from a dedicated subdirectory. The light and gated
  workflows do not mix.
- If `spec.md` already exists, confirm with the user before overwriting. Offer to revise it
  in place instead.
- If `prd.md` already exists, say so — a spec written after the PRD inverts the pipeline.
  Confirm the user wants it anyway before continuing.

## Step 0 — Find a seed

Look for a plan-mode plan for this initiative in `~/.claude/plans/`. Use Bash:

```bash
ls -1t ~/.claude/plans/*.md 2>/dev/null | head -20
```

Plan filenames are generated and do not name the initiative, so match on content, not
filename. Grep for terms from the current discussion, then read the candidates' headings.
Ignore `*-agent-*.md` files — those are subagent scratch, not plans.

If a plausible plan is found, show the user its path and H1 and ask whether to seed from it.
If none is found or the user declines, seed from the conversation instead and say so.

Plan-mode plans are already spec-shaped. Map their sections across:

| Plan section | `spec.md` section |
|--------------|-------------------|
| Context | Context |
| Locked decisions / Decisions taken / Settled before writing | Approach |
| Verified facts / Corrections that shaped this plan | Context, with the verification noted inline |
| Sources of truth | References |
| Deliverables | Requirements, Interface contracts |
| Out of scope / Not in scope | Out of scope |
| Verification | Acceptance criteria |
| Risks / The standing hazard | Risks |
| Open items / Unresolved items / Open questions carried forward | Open assumptions |

Carry content across; do not paraphrase decisions into weaker language.

**Do not carry across** the plan's execution sections — phase and commit sequences, step
lists, rollback and recovery procedures, go/no-go gates, file-by-file change lists. Those are
`/create-prd` and `/start-feature` output. A plan that is mostly execution detail has little
spec in it; say so rather than padding `spec.md` with implementation steps.

## Step 1 — Draft

Read `assets/spec-template.md`. Use the Write tool to create `spec.md`.

Fill every section you have material for. Delete sections you do not — an empty heading reads
as an answered question. State which sections you dropped and why.

## Step 2 — Close the gaps

Review the draft for the gaps that make a spec unusable downstream, and resolve each with
`AskUserQuestion`, 2–4 questions at a time:

- A requirement that is not testable. "Fast" and "reliable" are not requirements.
- An acceptance criterion that traces to no requirement number, or a requirement with no
  acceptance criterion.
- An interface named without its contract — no signature, no data shape, no failure behaviour.
- A decision recorded without its rejected alternative.
- A statement of fact with no source. Either verify it, cite it, or move it to
  `Open assumptions`.

Do not invent answers. Anything the user cannot settle now belongs in `Open assumptions` —
`/create-prd` will raise it again in Round 5.

## Step 3 — Optional red-team

Offer, do not impose: "Run `/red-team` against `spec.md` before handing it to `/create-prd`?"

Worth it when the work is irreversible, touches security or data, or the approach was
contested. Skip it for small, reversible changes.

If the user accepts, apply the findings they agree with and note the pass in `References`.

## Step 4 — Report

```
SPEC COMPLETE: [Title]

WRITTEN: spec.md
SEEDED FROM: [~/.claude/plans/<file>.md | this conversation]

CONTENTS:
- [N] requirements
- [N] out-of-scope items
- [N] interface contracts
- [N] acceptance criteria
- [N] risks
- [N] open assumptions

OPEN ASSUMPTIONS:
  [one line each, or "None."]

Run /create-prd to turn this into prd.md, docs/ARCHITECTURE_AND_DESIGN.md, and progress.txt.
```

## Identifier convention

Assigned here, reused verbatim downstream, never renumbered:

| Kind | Format | Example |
|------|--------|---------|
| Requirement | plain integer, sub-lettered when a requirement has parts | `3`, `4a` |
| Decision | `D<n>` | `D7` |
| Risk | `R<n>` | `R2` |

Nothing else. Deliverable IDs (`S<n>`) and tiered test IDs (`T<tier>.<n>`) belong to
`/project`; using them here is a signal the work has outgrown this skill — see **Escalation**.

## Error Handling

- **No plan found:** Say so, then seed from the conversation. Not an error.
- **Plan found but stale or contradicted:** Show the conflict; ask which stands. Do not
  silently prefer either.
- **Missing `assets/spec-template.md`:** Do not silently fail. Tell the user, then build the
  document from the section list in Step 1 of this file. State that no template was used.
- **User wants to skip a section:** Allow it. Delete the heading rather than leaving it empty,
  and name the omission in the Step 4 report.
- **Interrupted:** `spec.md` is written in Step 1, so partial work survives. On re-invocation,
  detect the existing file and offer to continue from Step 2 rather than restarting.
