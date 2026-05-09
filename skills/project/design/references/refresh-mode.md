# Refresh Mode: Architectural Deviation Consolidation

Consolidates accumulated architectural deviations from feature plans back into `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md`. This reference contains the complete refresh mode specification -- an executor reading only this file can run the full refresh flow.

`{slug}` is read from the `# Project-ID: <slug>` header in `progress.txt` at session start. All artifact paths in this document use `.project/{slug}/` as the base path.

## Entry Condition

Refresh mode is entered when ALL of the following are true:

1. Gate 2 is `[x]` approved in `progress.txt`
2. `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md` exists on disk

SKILL.md detects this in Step 1 and jumps to the refresh step. If either condition is false, this is not refresh mode -- use gate-2-design.md for normal mode instead.

## Deviation Scan (D-12)

Scan all feature plan files for architectural deviations:

1. Use `Glob` to find all files matching `.project/{slug}/milestones/*/plans/*.md`.
2. Read each file and search for the `## Architectural Deviations` heading.
3. Extract non-empty deviation entries. A section exists but contains only placeholder text (e.g., "Empty if the feature was built as designed") counts as empty -- skip it.
4. For each non-empty deviation, also identify the original design decision it modifies by matching the decision number or description against the Design Decisions table in `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md`.

Collect all deviations with their source file, deviation description, and the original design decision they affect.

## Zero Deviations (D-14)

If no non-empty Architectural Deviations sections are found across all plan files:

- Report: "No architectural deviations found. Architecture doc is current."
- End the session. No revision offer. No further action.

This is the expected outcome when implementation matched the original design.

## Per-Deviation Review (D-12)

Present each deviation to the user individually, showing:

1. **Original design decision** from `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md` -- the decision number, the decision text, and the rationale
2. **Deviation description** from the feature plan -- what changed and why
3. **Reason for the change** -- the circumstances that forced the deviation (failed approach, new constraint, technology change)

After presenting all deviations, use `AskUserQuestion` with a multiSelect to let the user pick which deviations to consolidate into the architecture doc:

- [ ] Deviation 1: [brief description]
- [ ] Deviation 2: [brief description]
- ...

The user checks the deviations they want consolidated. Unchecked deviations are acknowledged but left as deviation records in the feature plans.

## Consolidation

Apply selected deviations to `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md`:

1. **Design Decisions table:** Update the affected decision rows with revised decision text, rationale, and tradeoff. If a deviation introduces an entirely new decision, add a new numbered row.
2. **Component Inventory:** Update if the deviation added, removed, or changed components.
3. **Data Flow:** Update if the deviation changed how data moves through the system.
4. **File Organization:** Update if the deviation changed the directory structure or file locations.
5. **Deployment & Operations:** Update if the deviation changed deployment, monitoring, or operational aspects.
6. **Security Considerations:** Update if the deviation affected authentication, authorization, or data handling.

Use the Edit tool for all updates to preserve the rest of the document.

## Review (D-13)

After consolidation, present the updated architecture document for approval using the same section-by-section review flow as normal mode:

1. Present a summary of the changes made to `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md`
2. Use `AskUserQuestion` with options: **Approve** / **Revise** / **Partial**
3. If **Partial:** multiSelect checklist of the 6 architecture sections. User checks approved sections. Unchecked sections get focused revision with "What should change in [Section Name]?" prompt. Re-present after revision.
4. If **Revise:** Ask what needs changing, apply edits, re-present.
5. If **Approve:** Proceed to gate update.

## Gate Update

Update the Gate 2 date in `progress.txt` to reflect the refresh:

1. Read `references/progress-format.md` for the exact gate entry format.
2. Update the Gate 2 line in `progress.txt` to:
   ```
   [x] Gate 2: Design Review  Approved: <YYYY-MM-DD>  .project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md
   ```
   where `<YYYY-MM-DD>` is the current date (reflecting the refresh date, not the original approval date).
3. Only `progress.txt` is updated -- no other state files are modified.
