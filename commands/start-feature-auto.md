---
name: start-feature-auto
description: Automated feature implementation. Reads project context, writes a structured plan to progress.txt NOTES, then implements the feature without waiting for user confirmation. Only invoke when the user explicitly requests autonomous feature implementation. Do NOT use for review or planning only — use /start-feature for the interactive version with a human-in-the-loop checkpoint.
---

# /start-feature-auto — Automated Feature Implementation

Reads project context, persists a structured plan to `progress.txt`, then implements the feature
autonomously. All pre-work context is written to NOTES before implementation begins so the record
is complete regardless of outcome.

## Rules

- **Never skip reading progress.txt** — it is the source of truth for what to work on.
- **Never start a feature if another is `[~]`** — one feature at a time.
- **Write NOTES before implementing** — context must be persisted before any code changes.
- **Follow `docs/ARCHITECTURE_AND_DESIGN.md` for design decisions** — it is the authoritative
  spec; `prd.md` defines requirements and acceptance criteria.
- **Close the feature on completion** — update NOTES with the completion record and mark `[x]`.

## Step 1 — Read progress.txt

If `progress.txt` does not exist, stop and tell the user to run `/create-prd` first.

Read `progress.txt` and identify:

- Any feature currently marked `[~]` (in progress) — if found, resume that feature
- The next feature marked `[ ]` (pending) — if no `[~]` exists

If all features are marked `[x]`, report that all planned features are complete and stop.

**Resuming a `[~]` feature:** Read the NOTES field. If a NOTES entry already exists with
`FILES IDENTIFIED`, `KEY DECISIONS`, and `EXECUTION` fields, the pre-work is done — skip any
steps that re-determine the execution model and proceed directly to Step 6 (Implement), using
the recorded `EXECUTION` value without modifying it. Otherwise proceed through all steps.

## Step 2 — Read requirements

If `prd.md` does not exist, stop and tell the user to run `/create-prd` first.

Read `prd.md` and locate the section for the identified feature. Then read
`docs/ARCHITECTURE_AND_DESIGN.md` if it exists, and extract any Design Decisions, Component
Inventory entries, File Organization details, and Deployment Workflow steps relevant to this
feature.

Extract from both documents:

- What needs to be built
- Acceptance criteria
- Any dependencies on other features
- Relevant design decisions and component details

## Step 3 — Scan the codebase

Use Glob and Grep to identify files likely to be created or modified for this feature. Base the
search on component names, file paths, and naming patterns from `docs/ARCHITECTURE_AND_DESIGN.md`
(File Organization section) and the feature's acceptance criteria.

For greenfield features where no matching files exist yet, list the files that will be created
based on the architecture doc's File Organization section.

## Step 4 — Write NOTES entry

Mark the feature `[~]` and write the following NOTES block to `progress.txt` before any
implementation begins:

```
NOTES: Started YYYY-MM-DD.
       SUMMARY: [1-2 sentence description of what this feature builds and why].
       FILES IDENTIFIED: [comma-separated list from codebase scan]
       KEY DECISIONS: [#N summary; #M summary — from docs/ARCHITECTURE_AND_DESIGN.md]
       DEPENDENCIES: [feature and external deps; "None" if absent]
       EXECUTION: [TBD — filled by Step 5]
```

If resuming a `[~]` feature with an incomplete NOTES block, append only the missing fields.

## Step 5 — Assess complexity and route

Based on the codebase scan and requirements, determine the execution model:

| Signal | Execution model |
|---|---|
| 1–3 files, single component, straightforward criteria | **Inline** — proceed directly |
| 4–8 files, self-contained concern, or unfamiliar codebase area | **Sub-agent** — single isolated agent in a worktree |
| Multiple independent components with no shared state between work streams | **Team** — one agent per work stream, results merged |

Update the `EXECUTION:` field in NOTES with the chosen model and a one-line rationale before
proceeding.

## Step 6 — Implement

Execute using the model recorded in NOTES:

**Inline:** Implement directly. Follow the architecture doc, write code, run any available tests
or linters.

**Sub-agent:** Launch a single Agent with `isolation: "worktree"`. Pass the full feature context
(requirements, acceptance criteria, relevant design decisions, files to create/modify). The agent
implements, runs tests, and returns. Apply the result.

**Team:** Launch one Agent per independent work stream in parallel, each with `isolation: "worktree"`.
Each agent receives only its own scope. After all agents return, merge results and resolve any
conflicts.

## Step 7 — Close the feature

After implementation is complete:

1. Append to the feature's NOTES block in `progress.txt`:

```
       CODE COMPLETE: [N files changed; tests: pass/fail; lint: pass/fail].
       Completed YYYY-MM-DD.
```

2. Change the feature status from `[~]` to `[x]`.

3. Report to the user:

```
COMPLETED: Feature X.Y — [Title]

SUMMARY: [From NOTES]
EXECUTION MODEL: [inline | sub-agent | team]
FILES CHANGED: [list]
NEXT FEATURE: Feature X.Z — [Title] (run /start-feature-auto to continue)
```

## Error Handling

- **Missing `progress.txt` or `prd.md`:** Stop immediately. Tell the user to run `/create-prd`
  first.
- **Feature has a blocker dependency:** If a required preceding feature is not `[x]`, stop.
  Report which feature must be completed first.
- **Sub-agent or team agent fails:** Record the failure in NOTES. Leave the feature as `[~]`.
  Report the failure with enough detail for the user to decide how to proceed.
- **Implementation does not satisfy acceptance criteria:** Do not mark `[x]`. Record what is
  missing in NOTES under `CODE COMPLETE:`. Leave as `[~]` and report to the user.
- **Missing `docs/ARCHITECTURE_AND_DESIGN.md`:** Proceed using `prd.md` alone. Note the absence
  in NOTES.
