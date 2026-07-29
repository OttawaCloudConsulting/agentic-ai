---
name: start-feature-auto
description: Automated feature implementation. Reads project context, writes a structured plan to progress.txt NOTES, then implements the feature without waiting for user confirmation. Only invoke when the user explicitly requests autonomous feature implementation. Do NOT use for review or planning only — use /start-feature for the interactive version with a human-in-the-loop checkpoint.
---

# /start-feature-auto — Automated Feature Implementation

Reads project context, persists a structured plan to `progress.txt`, then implements the feature
autonomously. All pre-work context is written to NOTES before implementation begins so the record
is complete regardless of outcome. After implementation, the completed change set is reviewed by
Codex; findings judged valid are refactored and re-tested before the feature is closed.

## Rules

- **Never skip reading progress.txt** — it is the source of truth for what to work on.
- **Never start a feature if another is `[~]`** — one feature at a time.
- **Write NOTES before implementing** — context must be persisted before any code changes.
- **Follow `docs/ARCHITECTURE_AND_DESIGN.md` for design decisions** — it is the authoritative
  spec; `prd.md` defines requirements and acceptance criteria.
- **Codex-review before closing** — after implementation, run a Codex review of the completed
  change set. Triage each finding yourself; refactor the ones you judge valid, then re-test.
  Reality is the arbiter — do not apply a finding you cannot confirm against the code, and do not
  close the feature on an unaddressed valid HIGH finding.
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

## Step 7 — Codex review of the completed change set

After implementation finishes and local tests/linters pass, review the work with Codex **before**
closing the feature. Codex is an independent engine — a second pass that catches what the
implementing context is blind to.

1. **Assemble the change set.** Collect the diff for the feature's changed files (e.g.
   `git --no-pager diff` for unstaged work, plus any new files). Capture the feature's acceptance
   criteria from `prd.md` / `docs/ARCHITECTURE_AND_DESIGN.md`.

2. **Write a review brief** to a scratchpad temp file: the change set (or the list of changed
   files for Codex to read directly), the acceptance criteria, and the instruction to return
   **severity-tagged** findings (`HIGH` / `MED` / `LOW`), each as `file:line — problem → fix`,
   plus a one-line verdict. Ask Codex to verify against the real source, not the diff alone.

3. **Run Codex** with the hardened wrapper — do NOT hand-roll `codex exec` (an open stdin hangs
   the process, and a review must never run in a writable sandbox):

   ```bash
   bash .claude/scripts/codex-review.sh --diff \
     -p "Acceptance criteria: <paste from brief>. Verify against the real source, not the diff alone."
   ```

   The wrapper reviews the working diff **plus untracked new files**, pipes the prompt on a closed
   stdin (no hang), enforces a timeout, runs `-s read-only`, and returns severity-tagged findings
   ending in `VERDICT: PASS` / `VERDICT: FAIL`. Exit 0 = PASS, 1 = FAIL, **2 = review failed
   (timeout / codex error) — treat as "no verdict", never infer PASS**. For a commit-range or very
   large review: `--commits <base>..HEAD -t 600`.

   Alternative: the `codex:codex-rescue` agent (harness-native; same independent engine).

4. **Triage every finding.** For each, decide and record:
   - **VALID** — real, in-scope, and confirmed against the code (correctness, security, a missed
     acceptance criterion, a second-order break).
   - **REJECTED** — false positive, out of scope for this feature, or pure style with no behavior
     change. Record a one-line reason.

   Do not auto-apply Codex output. A finding you cannot reproduce in the code is REJECTED with that
   noted. If unsure whether a finding is valid, re-read the implicated code before deciding.

## Step 8 — Refactor on valid findings (conditional)

- **No valid findings** (clean review, or only REJECTED findings): skip refactoring. Proceed to
  Step 9 and record the review outcome.
- **Valid findings exist:** address them using the same execution model recorded in NOTES (inline,
  sub-agent, or team). Stay within the feature's scope — do not expand it. Prioritize HIGH
  (correctness/security) over LOW (style). After refactoring:
  1. Re-run the available tests and linters; they must pass.
  2. Optionally re-run Codex **once** to confirm the valid findings are resolved (cap re-reviews at
     one to avoid loops). If a valid HIGH finding remains unresolved after the refactor pass, do
     **not** close — leave the feature `[~]` and report (see Error Handling).

Record the review + refactor outcome in NOTES (the `CODEX REVIEW` / `REFACTOR` fields in Step 9).

## Step 9 — Close the feature

After implementation, Codex review, and any refactoring are complete:

1. Append to the feature's NOTES block in `progress.txt`:

   ```
          CODE COMPLETE: [N files changed; tests: pass/fail; lint: pass/fail].
          CODEX REVIEW: [N findings — H/M/L counts; X valid, Y rejected (one-line reasons)].
          REFACTOR: [what changed to resolve valid findings; re-test result — or "none (review clean)"].
          Completed YYYY-MM-DD.
   ```

2. Change the feature status from `[~]` to `[x]`.

3. Report to the user:

```
COMPLETED: Feature X.Y — [Title]

SUMMARY: [From NOTES]
EXECUTION MODEL: [inline | sub-agent | team]
FILES CHANGED: [list]
CODEX REVIEW: [X valid / Y rejected; refactored: yes/no]
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
- **Codex unavailable or the review command fails:** Non-fatal. The implementation already passed
  local tests. Record `CODEX REVIEW: skipped (codex unavailable — <reason>)` in NOTES, flag it
  plainly in the report, and proceed to close. Do not block completion on review-tooling absence.
- **Valid HIGH finding unresolved after the refactor pass:** Do not mark `[x]`. Record the finding
  and the attempted fix in NOTES under `REFACTOR:`. Leave the feature `[~]` and report so the user
  can decide how to proceed.
- **Missing `docs/ARCHITECTURE_AND_DESIGN.md`:** Proceed using `prd.md` alone. Note the absence
  in NOTES.
