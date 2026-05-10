# Revision Mode: Milestone Scope Change

Handles scope changes to an existing milestone by selectively resetting affected features while preserving completed work. This reference contains the complete revision mode specification -- an executor reading only this file can run the full revision flow.

## Entry Condition (D-10)

Revision mode is entered when the target milestone directory already exists on disk. SKILL.md auto-detects this in Step 1 by checking whether `.project/{slug}/milestones/<NN>-<name>/` is present.

If the target milestone directory does not exist, this is not revision mode -- use `references/gate-3-milestone.md` for normal mode (first invocation or subsequent invocation).

## Load Existing Artifacts (MIL-10, D-12)

Read the existing milestone artifacts from disk:

1. **Read `.project/{slug}/milestones/<NN>-<name>/README.md`** -- the existing milestone definition with goal, features, dependencies, ordering, sizing, and definition of done.
2. **Read `.project/{slug}/milestones/<NN>-<name>/milestone-status.txt`** -- the current feature statuses showing which features are complete, in progress, or pending.

Both files are required. If either is missing, report the error and stop.

## Feature Impact Assessment (MIL-11, MIL-12, D-11)

Present the feature checklist to the user using multiSelect, showing each feature with its current status:

```
Which features are affected by this scope change? Select all that apply.

- [x] Feature 01.1: User Registration (complete)
- [~] Feature 01.2: Session Management (in progress)
- [ ] Feature 01.3: Password Reset (pending)
```

**Selection rules:**

- Only features **explicitly selected** by the user are reset to `[ ]` pending (MIL-12)
- Completed features (`[x]`) that are **NOT selected** retain their `[x]` status -- they are preserved
- In-progress features (`[~]`) that are **NOT selected** retain their `[~]` status
- Pending features (`[ ]`) that are **NOT selected** remain at `[ ]`

This ensures completed work is never discarded unless the user explicitly marks it as affected by the scope change.

## Focused Revision (D-12)

After identifying affected features, perform a focused revision of the milestone:

1. **Ask "What changed?"** -- understand the nature of the scope change (new requirements, removed features, modified acceptance criteria, dependency changes, etc.)

2. **Load existing `.project/{slug}/milestones/<NN>-<name>/README.md`** content (already read in the Load step above).

3. **Revise only affected sections** -- do NOT discard and regenerate the entire README. Use the Edit tool to apply targeted changes:
   - If features were added: add new feature subsections with acceptance criteria
   - If features were removed: remove the feature subsections
   - If acceptance criteria changed: update the specific criteria
   - If dependencies changed: update the Dependencies section
   - If ordering rationale changed: update the Ordering section
   - If sizing changed: update the Sizing section
   - If the goal changed: update the Goal section

4. **Preserve unaffected content** -- sections and features not identified as affected remain exactly as they are.

## Artifact Updates (MIL-13)

After revising the README, update all related artifacts. Follow write-ordering (STATE-04): `milestone-status.txt` FIRST, then `progress.txt`, then `prd.md`.

### 1. Generate Fresh gate-3-review.md (D-13)

Generate a fresh `.project/{slug}/milestones/<NN>-<name>/reviews/gate-3-review.md` checklist using `references/review-checklist-template.md`. The prior review is no longer valid after a scope change -- a new review must be conducted against the revised milestone definition.

### 2. Update milestone-status.txt (Write First -- STATE-04)

Update `.project/{slug}/milestones/<NN>-<name>/milestone-status.txt`:

- **Reset selected features** to `[ ]` pending with `Plan: (not yet planned)` -- their previous plans are invalidated by the scope change
- **Preserve unselected features'** status and plan paths -- completed features keep `[x]`, in-progress features keep `[~]`, pending features keep `[ ]`
- If features were **added**, add new feature entries at `[ ]` pending with `Plan: (not yet planned)`
- If features were **removed**, remove those feature entries entirely
- Update the header `# Status:` line with the new feature count and completion count
- Follow the format from `references/progress-format.md` for milestone-status.txt structure

### 3. Update progress.txt (Write Second -- STATE-04)

Update the milestone summary line in the `## Milestones` section of `progress.txt`:

```
[ ] Milestone NN: Name  .project/{slug}/milestones/<NN>-<name>/  N/M features complete
```

Recalculate N (completed features) and M (total features) based on the updated `milestone-status.txt`.

### 4. Update prd.md (Write Third)

Update the `prd.md` Milestones section with a revised 1-2 sentence summary for this milestone. The summary should reflect the scope change so that the milestone plan in `prd.md` stays accurate.

Use the Edit tool to update only the line for the affected milestone -- do not touch other milestone summaries.

## Review

Present the revised milestone for user review using the same approval flow as normal mode:

1. **Present the revised milestone** -- highlight what changed, what was preserved, and what the new feature set looks like
2. **Focus review on Gate 3 concerns** (DD-8): feature grouping coherence, ordering, sizing realism, acceptance criteria specificity
3. **Use `AskUserQuestion`** with options:
   - **Approve** -- revision is accepted, proceed to checklist validation
   - **Revise** -- ask what needs further changes, apply edits, re-present
   - **Partial** -- multiSelect of README sections for section-by-section approval

4. **Checklist validation** -- follow the same process as normal mode (Section 8 of `references/gate-3-milestone.md`): Claude pre-checks what it can verify programmatically, presents remaining items to the user, all items must be `[x]` or `[-]` before the revision is considered approved.
