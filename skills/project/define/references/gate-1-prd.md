# Gate 1: Scope Review (PRD)

Conducts a structured interview and produces a Product Requirements Document (`prd.md`).

Gate 1 is the most complex gate in the `/define` skill. It covers the full PRD lifecycle: context loading, multi-round interview, document production, partial approval, checklist validation, gate approval recording, and revision mode for existing PRDs.

## Context Refresh (DEF-16)

At the start of Gate 1, silently re-read context files from disk to mitigate context rot (by this point, Gate 0 and Gate WB conversations may have scrolled out of the context window).

1. **Read `docs/codebase-assessment.md`** from disk (if it exists). Do NOT recap or summarize the assessment to the user -- use it internally as context for the interview.
2. **Read `docs/working-backwards.md`** from disk (if it exists and Gate WB was approved). Use as context for the interview -- the WB narrative informs better questions and answers, but does NOT auto-populate PRD sections (D-14). The full interview still runs.

This silent re-read is critical: without it, the PRD interview proceeds without codebase awareness, producing a document that ignores existing patterns and constraints.

## Interview Rounds (DEF-10)

Conduct a multi-round interview using `AskUserQuestion`. One round at a time -- never dump all questions at once. 2-4 questions per round. After each round, update `prd.md` and show the user what was added.

Adapt questions to the project type -- not all rounds apply to every project. If Gate WB was used, reference WB content where relevant to ground questions in the customer narrative, but do not skip questions (D-14).

### Round 1 -- Scope and Boundaries

- What is explicitly out of scope? (non-goals)
- Are there constraints on environments, platforms, or deployment targets?
- Are there compliance or security requirements?
- What existing systems or services does this integrate with?

Maps to PRD sections: Goals, Non-Goals, External Dependencies

### Round 2 -- Inputs and Outputs

- What does the consumer or caller configure? (parameters, configuration, inputs)
- What needs to be exposed or returned? (outputs, endpoints, connection strings)
- Are there required vs. optional inputs?
- What validation rules should inputs have?

Maps to PRD sections: Configuration, Outputs

### Round 3 -- Security

- What is the encryption strategy (at rest, in transit)?
- What access control model applies?
- Are there edge protection or traffic filtering requirements?
- What security headers or policies are needed?

Maps to PRD sections: Risk Assessment (security entries); may surface new External Dependencies

### Round 4 -- Operational Concerns

- Is logging needed? (access logs, audit trails)
- What monitoring/alerting is expected?
- What is the deployment workflow?
- Are there cost considerations or constraints?

Maps to PRD sections: Risk Assessment (operational entries), Future Enhancements

### Round 5 -- Milestone Scoping

- What are the major deliverable milestones? (each should map to a customer-visible outcome per DD-1)
- What is the expected ordering of milestones?
- Are there cross-milestone dependencies?
- What is the minimum viable first milestone?

Maps to PRD sections: Milestones (captures initial scoping intent; detailed breakdown happens in `/milestone` after Gate 3)

**Interview rules:**

- One round at a time -- present 2-4 questions per round via `AskUserQuestion`
- After each round, use the Edit tool to update `prd.md` and show the user what was added
- Adapt questions to the project type -- skip irrelevant questions, add follow-ups as needed
- If the user wants to skip a round, allow it and note the skip in `prd.md` as a comment

## PRD Production (DEF-11)

### Initial Seed

Before starting interview rounds, gather the initial project concept:

- What are you building? (1-2 sentence description)
- What is the technology stack?
- What is the primary goal / problem being solved?

Read `assets/prd-template.md` for the document structure. Use the Write tool to create `prd.md` populated with the seed answers. Read the file back and confirm Summary and Goals sections are populated. Tell the user what was written and proceed to the interview rounds.

### Iterative Updates

After each interview round, use the Edit tool to update `prd.md` with new information. Show the user what was added before proceeding to the next round.

### Quality Bar

- Specific, testable language in all sections -- no vague descriptions
- Clear configuration tables with types and descriptions
- Non-Goals table includes rationale for each exclusion
- Risk Assessment entries include concrete mitigations, not "TBD"
- Milestones section stays as "(to be defined)" -- populated later by `/milestone`

## Review Phase

After all interview rounds are complete, enter the produce-then-review cycle (D-06):

1. Present a summary of the complete PRD to the user (section overview, key decisions, notable risks)
2. Use `AskUserQuestion` with options: **Approve** / **Revise** / **Partial Approve**
3. If **Revise**: ask what needs changing, apply edits with the Edit tool, re-present the updated PRD (D-08)
4. If **Partial Approve**: proceed to Partial Approval flow below
5. If **Approve**: proceed to Checklist Validation

## Partial Approval (DEF-12)

When the user selects Partial Approve, or approves with reservations about specific sections:

Present a section checklist using multiSelect listing each PRD section:

- [ ] Summary
- [ ] Goals
- [ ] Non-Goals
- [ ] External Dependencies
- [ ] Milestones
- [ ] Configuration
- [ ] Outputs
- [ ] Risk Assessment
- [ ] Future Enhancements

The user checks the sections they approve. Unchecked sections enter focused revision:

1. For each unchecked section, ask: "What should change in [Section Name]?"
2. Apply the requested changes using the Edit tool
3. Re-present only the revised section for confirmation
4. Repeat until the user approves the section or defers it

When all sections are checked (approved) or the user does a full Approve, proceed to Checklist Validation.

## Checklist Validation (DEF-04, DEF-06)

1. Read `references/review-checklist-template.md` for the Gate 1 checklist structure
2. Generate `docs/reviews/gate-1-review.md` using the Gate 1 section from the template
3. Add content-specific `[Auto]` items based on actual PRD content (e.g., verify specific assumptions, confirm specific non-goals are intentional, validate specific risks have mitigations)
4. Claude pre-checks `[x]` items that can be verified from the PRD content
5. Present remaining unchecked items to the user for resolution
6. ALL items must be `[x]` (verified) or `[-]` (N/A with reason) before gate approval can be recorded

## Gate Approval (DEF-13)

Once all checklist items are resolved:

1. Read `references/progress-format.md` for the exact gate entry format
2. Update Gate 1 line in `progress.txt` to: `[x] Gate 1: Scope Review  Approved: <YYYY-MM-DD>  prd.md`
3. Confirm to the user that Gate 1 is approved and the PRD is finalized

## Revision Mode (DEF-15)

Revision mode is triggered when `/define` detects an existing `prd.md` AND the user signals revision intent. This skips Gates 0 and WB entirely -- goes straight to Gate 1 revision.

### Entry Conditions

- `prd.md` exists on disk
- User message signals revision intent (e.g., "requirements changed", "update the PRD", "revise scope")

### Revision Flow

1. **Read existing `prd.md`** from disk
2. **Context refresh**: Read `docs/codebase-assessment.md` from disk if it exists (same DEF-16 silent re-read -- no recap to user)
3. **Ask the user**: "What changed?" -- open-ended question about what prompted the revision. Let the user describe the changes in their own words.
4. **Focused interview**: Conduct a targeted interview on ONLY the affected sections. Do not re-run the full 5-round interview. Ask clarifying questions specific to the changed areas.
5. **Update `prd.md`**: Apply revisions using the Edit tool. Show the user each change before and after.
6. **Review cycle**: Present the updated PRD for review using the same produce-then-review cycle (Approve / Revise / Partial Approve). Partial approval works the same as in the initial flow.

### Downstream Impact Surfacing (DD-6)

After PRD revision is approved, surface downstream impacts. Do NOT automatically reset any downstream artifacts -- the user decides what needs re-review.

7. **List affected downstream artifacts** that MAY need re-review:
   - `docs/ARCHITECTURE_AND_DESIGN.md` (if exists) -- design may be invalidated by scope changes
   - `milestones/*/README.md` (if any exist) -- milestone breakdown may need updating
   - `milestones/*/plans/*.md` (if any exist) -- implementation plans may be affected
8. **Present this list to the user** and ask which (if any) need re-review
9. **Do NOT automatically reset** any downstream artifact status -- no automatic cascade (DD-6)
10. **Record Gate 1 re-approval** in `progress.txt` with updated date: `[x] Gate 1: Scope Review  Approved: <YYYY-MM-DD>  prd.md`
