# Gate WB: Working Backwards (Optional)

An optional gate that produces a customer-outcome narrative before PRD creation. Working Backwards starts with the customer experience and works backward to the technical solution. This reference contains the complete Gate WB specification -- an executor reading only this file can run the full Gate WB flow.

## Gate WB Offer (DEF-08)

After Gate 0 is complete (or skipped for greenfield), offer Gate WB to the user.

Use `AskUserQuestion` with 3 options:

- **Yes** -- Proceed with the Working Backwards exercise
- **Skip** -- Record as skipped and proceed to Gate 1
- **Defer** -- Record as pending and proceed to Gate 1

Include this explanation with the prompt:

> Working Backwards starts with the customer experience and works backward to the technical solution. You write a mock press release describing what the customer gets, then FAQ sections that address external and internal questions. This ensures you are solving the right problem before defining scope.

### Handling Each Outcome

**If Yes:** Proceed to the Working Backwards Interview below.

**If Skip:** Record in progress.txt:
```
[-] Gate WB: Working Backwards  Skipped
```
Proceed to Gate 1 (read `references/gate-1-prd.md`).

**If Defer:** Record in progress.txt:
```
[ ] Gate WB: Working Backwards  Pending -- offered, awaiting decision
```
Proceed to Gate 1. Note: Gate WB must reach `[x]` or `[-]` before Gate 1 can complete (DD-11). If Gate WB is still Pending when Gate 1 review begins, the user will be prompted to resolve it.

## Working Backwards Interview

Conduct a 2-3 round interview to gather content for the Press Release and FAQ document.

### Round 1 -- Customer and Problem

Ask the user:

1. Who is the target customer?
2. What problem are they experiencing today?
3. How do they currently solve or work around this problem?
4. What is the measurable outcome they want?

### Round 2 -- Solution and Experience

Ask the user:

1. What does the solution look like from the customer's perspective?
2. What is the first thing the customer does with it?
3. What quote would the customer give about this solution?
4. What is the call-to-action (how do they get started)?

### Round 3 -- Internal Feasibility

Ask the user:

1. What are the biggest technical risks?
2. What existing systems does this depend on?
3. What is the expected timeline?
4. What would make this project fail?

**Interview guidance:** Each round uses `AskUserQuestion` with a free-text response. Adapt follow-up questions based on the user's answers. If the user's responses in Rounds 1-2 are thorough, Round 3 may be shortened or combined. The goal is to gather enough material to write a credible Press Release and FAQ -- not to exhaustively interview.

## Document Production (DEF-09)

Produce `docs/working-backwards.md` from the interview answers:

1. Create `docs/` directory if it does not exist: `mkdir -p docs`
2. Write `docs/working-backwards.md` with these required sections:

### Press Release

The customer-facing narrative with these elements:

- **Headline** -- one sentence describing what launched
- **Subheading** -- who benefits and how
- **Dateline** -- city and date
- **Problem paragraph** -- the problem customers face today
- **Solution paragraph** -- what the solution does
- **Customer experience paragraph** -- what it feels like to use the solution
- **Customer quote** -- a fictional quote from a satisfied customer
- **Call-to-action** -- how the customer gets started

### External FAQ

Questions a customer would ask about the solution. Include 5-8 questions with answers. Examples:

- How does this work?
- What does it cost?
- How is this different from {existing alternative}?
- When is it available?
- What do I need to get started?

### Internal FAQ

Questions the team would ask about feasibility, timeline, and risks. Include 5-8 questions with answers. Examples:

- What are the biggest technical risks?
- What dependencies does this have?
- What is the expected timeline?
- What would make this project fail?
- How will we measure success?
- What are the main cost drivers?

## Review Phase (DEF-05 equivalent for WB)

Present the Working Backwards document to the user using the produce-then-review cycle:

1. **Present the document** to the user. Highlight:
   - The press release narrative (is the customer outcome clear?)
   - Key FAQ answers (are they credible and consistent?)
   - Internal feasibility concerns (are risks addressed?)

2. **Use `AskUserQuestion`** with options:
   - **Approve** -- document captures the right customer outcome, proceed to checklist validation
   - **Revise** -- document needs corrections

3. **If Revise:** Ask the user what needs changing. Apply edits to `docs/working-backwards.md`. Re-present the updated document. Repeat until the user selects Approve.

4. **If Approve:** Proceed to Checklist Validation.

## Checklist Validation (DEF-04, DEF-06)

Generate and validate the review checklist:

1. Create `docs/reviews/` directory if needed: `mkdir -p docs/reviews`

2. Generate `docs/reviews/gate-wb-review.md` using the Gate WB section from `references/review-checklist-template.md`. Start with the file header:

   ```
   # Gate WB Review -- Working Backwards

   **Artifact:** docs/working-backwards.md
   **Status:** [ ] Pending
   **Reviewer(s):**
   **Date:**
   ```

3. Include the Gate WB static checklist items:
   - `[ ] Does the press release describe a clear customer outcome?`
   - `[ ] Is the problem statement accurate and specific?`
   - `[ ] Does the solution description match the intended scope?`
   - `[ ] Are the FAQ answers consistent with the press release?`
   - `[ ] Are internal feasibility concerns addressed in the Internal FAQ?`

4. Add content-specific `[Auto]` items based on actual document content. Examples:
   - `[ ] [Auto] Verify claim: "{specific claim from press release}"`
   - `[ ] [Auto] Validate feasibility: "{specific risk from internal FAQ}"`
   - `[ ] [Auto] Confirm scope alignment: "{specific feature mentioned}"`

5. **Claude pre-checks** items it can verify programmatically:
   - File `docs/working-backwards.md` exists
   - All required sections are present (Press Release, External FAQ, Internal FAQ)
   - Press release contains all required elements (headline, subheading, etc.)

6. **Present remaining unchecked items** to the user for resolution.

7. **All items must be `[x]` (verified) or `[-]` (N/A with reason)** before proceeding. No item may remain as `[ ]`.

8. Update the checklist `**Status:**` to `[x] Approved` with the current date.

## Gate Approval (DEF-08)

Record the gate approval in progress.txt:

1. Read `references/progress-format.md` for the exact gate entry format.

2. Update the Gate WB line in progress.txt from:
   ```
   [ ] Gate WB: Working Backwards
   ```
   to:
   ```
   [x] Gate WB: Working Backwards  Approved: <YYYY-MM-DD>  docs/working-backwards.md
   ```
   where `<YYYY-MM-DD>` is the current date.

3. Proceed to Gate 1 (read `references/gate-1-prd.md`).
