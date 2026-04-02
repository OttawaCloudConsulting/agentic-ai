# Domain Pitfalls

**Domain:** Gate-based AI-assisted development pipeline (Claude Code skills)
**Researched:** 2026-04-02
**Sources:** DESIGN.md (skills/project/DESIGN.md), create-prd SKILL.md, create-prd assets/progress-template.txt, GSD workflow references

---

## Patterns to Replicate from Existing Skills

### What Works Well in `create-prd`

**One-question-at-a-time discipline**
`create-prd` enforces "one round at a time, never dump all questions at once." This is explicitly in the rules section. The pipeline skills should carry this forward — especially in `/define`'s interview phase and `/plan`'s sub-feature scoping discussion. Information overload at any gate leads to rubber-stamp approvals.

**Show-work-after-each-step rule**
After every file write, `create-prd` tells the user what was added or changed. This prevents the model from silently producing a large artifact and surprising the user with a "done." Each skill in the pipeline should narrate writes: "I've added the codebase-assessment.md with these sections: [X, Y, Z]. What did I miss?"

**Confirm-before-overwriting rule**
`create-prd` checks for existing output files and requires confirmation before overwriting. This must be replicated in every pipeline skill — particularly `/define` (revising a PRD), `/milestone` (re-planning), and `/design` (refreshing the architecture doc). Silent overwrites destroy prior approved artifacts without leaving a recovery point.

**Read-back-and-confirm after writes**
`create-prd` reads each file back after writing to verify the content landed correctly. This catches partial writes, encoding issues, and template substitution failures. All pipeline skills should do this for state files (progress.txt, milestone-status.txt) since those are load-bearing.

**Structured error handling for missing templates**
`create-prd` has an explicit rule: if an `assets/` file is missing, do not silently fail — notify the user which file is missing and construct from scratch, stating no template was used. Pipeline skills should do the same for their read-inputs: if `prd.md` is missing when `/design` runs, stop and report rather than inventing content.

**Cross-reference enforcement**
`create-prd` requires component names, parameter names, and feature numbers to match exactly across all documents. This pattern is even more critical in the pipeline because artifacts flow across skills and sessions. A feature slug that drifts between `milestone-status.txt` and the plan file breaks `/build`'s ability to locate the correct plan.

---

## Patterns to Avoid

### Anti-pattern: Implicit gate approval

`create-prd` doesn't have gates — it proceeds when the user "indicates the PRD is comprehensive." This works for a single-skill flow but is a bug in an orchestrated pipeline. DD-7 is explicit: "No implicit approval. Moving to the next phase requires an explicit 'approved' or equivalent." If a skill infers approval from silence (user didn't complain, so we proceed), the gate integrity collapses.

**Why it happens:** Models optimize for completion. After presenting an artifact, the natural continuation is to move on. The skill must actively resist this and ask for an explicit signal.

**Prevention:** Every gate ends with a direct question — "Shall I record this gate as approved in progress.txt?" — and waits for an explicit yes. Never advance on a user response that is about content (e.g., "looks good for section 2 but fix section 3").

### Anti-pattern: Treating review as a final dump

If a skill produces a large artifact and then presents a wall of review questions, the user will skim. The gate review works because it is phase-specific (DD-8) and short (4–6 checklist items). Expanding the checklist, adding generic questions, or producing the checklist before the user has had time to read the artifact undermines this entirely.

**Prevention:** Checklists must remain short and gate-specific. Do not add "general quality" questions to the checklist.

### Anti-pattern: Skills that write to state files they don't own

The design is explicit about write targets per skill (DD-4 table). `/project` is read-only after bootstrap. `/build` owns milestone-status.txt updates. `/milestone` owns initial milestone-status.txt creation. Cross-writing (e.g., `/plan` updating the project-level `progress.txt` gates) creates race conditions in re-planning and makes state inconsistent in ways that are hard to diagnose.

**Prevention:** Each skill's write targets are fixed. Any cross-skill write should be treated as a design defect, not a convenience.

### Anti-pattern: Monolithic session interviews

`create-prd` works well as a single session but the pipeline specifically solves context rot. A skill that tries to gather all information in one long exchange before writing anything will have degraded output quality by the time it writes. The rule from `create-prd` — "show work after each step" — is a forcing function against this.

---

## State File Failure Modes and Mitigations

### Failure Mode 1: Two-tier divergence

**What goes wrong:** The milestone summary line in `progress.txt` reads "2/3 features complete" but `milestone-status.txt` shows all 3 complete (or vice versa). This happens when a `/build` session completes the last feature, updates `milestone-status.txt`, but fails (crash, context loss, session clear) before updating the project-level `progress.txt`. Or a user manually edits one file but not the other.

**Consequence:** `/project` shows the wrong status. User may re-run `/build` on a completed feature, or skip a milestone that isn't actually done.

**Prevention:** The sync write must be atomic-ish — `/build` updates `milestone-status.txt` first (the source of truth per DD-5), then updates `progress.txt`. If the second write fails, the inconsistency is detectable at `/project` validation. The first write is never lost.

**Recovery:** `/project` validates consistency on every read and warns on divergence (DD-3). Recovery path: re-read `milestone-status.txt`, recompute the rollup, prompt the user to confirm, then update `progress.txt`. Never auto-correct silently.

**Detection signal:** `/project` emits a warning block:
```
WARNING: Milestone 01 summary diverges.
  progress.txt says: 2/3 features complete
  milestone-status.txt says: 3/3 features complete
Action required: confirm the correct status before proceeding.
```

### Failure Mode 2: Partially written state file

**What goes wrong:** A skill begins updating `progress.txt` and the session is interrupted mid-write. The file ends up with a partial gate approval block, a malformed milestone summary line, or a truncated spike entry.

**Consequence:** Next `/project` invocation fails to parse the file or reads a corrupted status.

**Prevention:** Skills write state updates as append operations (new lines) or complete replacements of known sections — never in-place edits that leave the file in an intermediate state if interrupted. The plain-text format (chosen over YAML precisely for format tolerance) helps here: a broken line is visible and human-correctable.

**Recovery:** Git is the primary recovery mechanism (DD-5). The user can `git diff progress.txt` to see what changed and `git restore progress.txt` to revert if the write was corrupted. This is why version control of all planning artifacts is not optional — it is the crash recovery mechanism.

### Failure Mode 3: Gate approved but no timestamp

**What goes wrong:** A skill writes the gate approval marker `[x] Gate 1: Scope Review` but omits the `Approved:` timestamp, or writes a timestamp in a non-standard format. `/project` parses the file and either misreads the status or fails to display the audit trail.

**Prevention:** Gate approval writes must use a fixed template with mandatory timestamp. The skill should never ask the model to "write an appropriate timestamp" — it should call the date programmatically and embed it.

**Recovery:** Manual edit to add the missing timestamp. Unlikely to cascade, but the audit trail is lost.

### Failure Mode 4: Stale artifact path in progress.txt

**What goes wrong:** `progress.txt` records `Gate 1: Scope Review ... prd.md` but the file was moved, renamed, or deleted by the user. `/project`'s artifact validation check reports the file missing.

**Prevention:** Artifact paths in `progress.txt` are always project-root-relative. Skills never record absolute paths. The naming convention (DD-artifacts section) must be followed strictly — slugs are derived at creation time and do not change.

**Recovery:** DD-3 is explicit: `/project` warns but does not block. The user decides whether to restore the file or proceed. The correct response is not to auto-remove the reference from `progress.txt` — that destroys the audit trail. Instead, prompt: "Gate 1 artifact prd.md not found. Restore it from git history, or confirm you want to regenerate it via /define in revision mode?"

### Failure Mode 5: milestone-status.txt missing but milestone directory exists

**What goes wrong:** A `/milestone` run was interrupted after creating the directory and README but before creating `milestone-status.txt`. Or the user deleted the file.

**Consequence:** `/plan` and `/build` cannot find the state file. They may create a new one from scratch, losing any progress tracked in the original.

**Prevention and Recovery:** The DESIGN.md documents the recovery path: recreate from the milestone README's feature list (which is the authoritative feature source at Gate 3). Feature plans on disk provide plan paths. Git history provides approximate completion status. Skills must detect the missing file, warn the user, and offer to reconstruct before proceeding.

---

## Context Rot Detection and Handling

### What context rot looks like in a pipeline skill

Context rot is the core problem the pipeline is designed to prevent. But it can still occur within a skill session if:
- The session spans too many back-and-forth exchanges before writing artifacts
- The user redirects mid-interview multiple times
- The skill re-reads large files repeatedly as context grows
- A `/build` session spans many sub-features without a clean break

**Early warning signs (within a session):**
1. The model starts qualifying its outputs ("this might be slightly different from what we discussed...")
2. Previously established decisions stop appearing in artifact drafts
3. The model asks for information it was already given
4. Artifact quality degrades between sections of the same document (early sections are detailed, later sections are vague)
5. The model begins hedging on technical choices that were explicitly approved

### How `/build` should detect and handle context rot

**Token budget awareness:** `/build` runs in its own context-isolated session (DD-2). The sub-feature sizing constraint (60% of 200k context = ~120k tokens) is the primary safeguard. `/build` should track context usage and flag when approaching the boundary rather than continuing until it fails.

**Explicit handoff when approaching limits:** When the context budget is ~80% consumed in a `/build` session, the skill should:
1. Complete the current sub-feature (leave the codebase in a committable state)
2. Update `milestone-status.txt` with current sub-feature status
3. Produce a brief "session summary" note in the feature plan's NOTES field capturing where it left off
4. Tell the user: "Context budget at ~80%. Current sub-feature complete. Recommend starting a fresh `/build` session for the next sub-feature."

**Do not try to finish one more sub-feature.** This is where context rot happens — pushing past the budget to avoid "stopping short."

**What to write at session end:** The feature plan and milestone-status.txt are the context-transfer mechanism. The session summary note should record:
- Last completed sub-feature
- Files changed and their state
- Any deviations from the plan discovered so far
- What the next sub-feature needs to know

This is cheaper than carrying conversational context and more reliable.

### How `/define` is especially vulnerable

`/define` spans Gates 0, WB, and 1 in a single session (DD-2 exception). This is justified by tight coupling between codebase understanding and PRD creation — but it means `/define` is the most context-intensive skill in the pipeline.

**Risk:** If the Gate 0 codebase scan is thorough (large codebase, many files read), the session may be token-heavy before the interview even begins. By Gate 1's final PRD draft, the early codebase findings may be effectively out of context.

**Mitigation:** `/define` must write the codebase assessment artifact immediately after Gate 0 approval — not hold findings in memory until the PRD is done. The written artifact then acts as the durable context carrier. When Gate 1 PRD writing begins, `/define` re-reads the written artifact rather than relying on in-session memory.

---

## Gate Approval UX Anti-Patterns

### Anti-pattern: The approval ceremony

A gate feels heavyweight when the skill does any of the following:
- Presents the full artifact followed by a review checklist followed by clarifying questions followed by a summary followed by "shall we proceed?"
- Requires the user to respond to every checklist item individually
- Asks the user to type a specific magic phrase to proceed
- Shows the artifact, then the checklist, then reformats both into a "summary for approval"
- Blocks on review until the user explicitly resolves items they clearly don't care about

**What the design says:** "Gates are lightweight — the skill presents a summary and asks for approval, not a ceremony. A confident user can approve in one line." (DD-7)

**What makes a gate feel lightweight:**
- Present a summary (not the full artifact) at the gate — 3-5 bullet points of what was decided
- Show the checklist as a reference, not a questionnaire the user must answer item-by-item
- Ask a single question: "Does this look right? Approve to proceed, or tell me what to change."
- Accept "approved" / "looks good" / "yes" without requiring more
- If the user provides partial feedback ("section 2 is wrong"), revise and re-ask — don't force a formal re-review of sections they already accepted

**The minimal viable gate approval flow:**
```
Gate 1 complete. Here's what we're building:
- Goal: [one sentence]
- Out of scope: [key non-goals]
- Milestones: [3 milestone titles]
- Key risks: [1-2 risks]

Full PRD is in prd.md. Review checklist in docs/reviews/gate-1-review.md.

Approve? (or tell me what to change)
```

### Anti-pattern: Unresolved checklist items blocking approval of non-contentious artifacts

The checklist completeness rule (DD-7 rule 6, DD-13) exists to prevent rubber-stamp approvals. But if the skill enforces it mechanically — refusing to proceed until every checkbox is `[x]` or `[-]` — it becomes a bureaucratic hurdle for obvious approvals.

**The problem:** A user who reviews the artifact offline and marks the checklist is well-served. A user who approves in-session and says "looks good, ship it" should not be forced to go into the review file and check boxes.

**Recommendation:** When the user approves explicitly in-session, the skill marks the checklist as complete on their behalf, records who approved and when, and proceeds. The checklist is not an interactive form — it is a record. Force-interactive checklist completion is gate ceremony.

### Anti-pattern: Gate WB pending state left ambiguous

Gate WB has a `[ ] Pending — offered, awaiting decision` state that persists if the session ends before the user decides. If the skill does not re-prompt on next invocation, the pipeline can stall silently — the user runs `/project`, sees "Gate WB: Pending," and doesn't know what to do.

**Prevention:** When `/project` or `/define` detects a pending Gate WB, the first action must be to resolve it before any other status reporting: "Gate WB was offered in a previous session but not resolved. Do you want to do Working Backwards before writing the PRD, or skip it?"

### Anti-pattern: Partial approval treated as full approval

DD-7 rule 4 supports partial approval ("features 1-3 look good, rethink feature 4"). But a skill that records gate approval after receiving partial feedback — even if the user said "mostly good" — undermines the gate.

**Prevention:** Gate approval is only recorded when the user approves the artifact in its current state. If feedback is given, the skill revises and re-presents. The gate approval question is asked again after each revision, not assumed from "that's better."

---

## Re-planning Failure Scenarios and Recoveries

### Scenario 1: Re-planning invalidates in-progress features

**What goes wrong:** Milestone re-planning begins while Feature 01.2 is `[~] in progress`. The re-planning changes the requirements in ways that affect Feature 01.2's approach. The skill resets Feature 01.3 to `planned` status (it was unaffected) but the user and skill disagree about whether 01.2's in-progress work is still valid.

**Consequence:** Half-written code in the codebase that may not align with the new plan.

**Recovery path:** Before resetting any feature status, `/milestone` in revision mode must identify and surface all features in `[~] in progress` or `[x] complete` status. For each:
- Complete features: confirm whether the completed work is still valid, or if the scope change means it must be re-done
- In-progress features: the user must decide — abandon current work and restart, or continue with the existing code and adapt the plan

The skill cannot make this decision autonomously. It presents the list, the user decides, then status resets happen.

**Detection signal:** Before any reset, `/milestone` outputs:
```
Re-planning scope change affects these features:
[~] Feature 01.2: Session Management — IN PROGRESS (code exists)
[ ] Feature 01.3: Password Reset — not started

For in-progress Feature 01.2: should I reset it to planned (discarding current implementation approach) or preserve it as is?
```

### Scenario 2: PRD revision with no downstream cascade

**What goes wrong:** The user initiates a PRD revision (DD-6 PRD revision path). `/define` updates `prd.md`. But the architecture doc, milestone READMEs, and feature plans still reflect the old PRD. No automatic cascade reset is enforced. The user proceeds to `/build` without noticing that the feature plan they're following was written against the old PRD.

**Consequence:** Implementation diverges from the revised requirements. The divergence is discovered only in code review or QA.

**Prevention:** This is the most dangerous re-planning scenario because the gap is invisible. After a PRD revision, `/project` must prominently surface the staleness risk:
```
PRD revised on 2026-03-25.
Downstream artifacts written before this date may be stale:
  docs/ARCHITECTURE_AND_DESIGN.md — Gate 2 approved 2026-03-17
  milestones/01-core-auth/README.md — Gate 3 approved 2026-03-18
  milestones/01-core-auth/plans/user-registration.md — Gate 4 approved 2026-03-19

Review these artifacts before proceeding. Run /design, /milestone, or /plan to refresh any that are affected.
```

The user decides what to refresh; the pipeline does not auto-reset. But the warning must be prominent and specific, not buried in status output.

### Scenario 3: Scope creep during milestone re-planning

**What goes wrong:** The user initiates milestone re-planning because one feature turned out to be larger than expected. `/milestone` revision mode asks what changed. The user starts adding new features to the milestone. The milestone grows from 3 features to 6. The milestone summary line in `prd.md` and `progress.txt` is updated, but the milestone is no longer sized per DD-1 (2-5 features).

**Prevention:** `/milestone` in revision mode should check the resulting feature count against the 2-5 feature guideline and warn if it exceeds the range. It does not block, but it surfaces the risk: "Milestone now has 6 features. DD-1 recommends 2-5 per milestone for context window fit. Consider splitting into two milestones."

### Scenario 4: Re-planning creates a plan path that conflicts with an existing file

**What goes wrong:** Feature 01.2 is re-planned and its scope changes significantly. The old plan file is `milestones/01-core-auth/plans/session-management.md`. The user wants to rename the feature. The new slug would be `milestones/01-core-auth/plans/session-and-token-management.md`. The old file still exists. `/plan` creates the new file; the old file lingers. `milestone-status.txt` may still reference the old path.

**Prevention:** When `/plan` writes a new plan for a re-planned feature, it checks whether the old plan path in `milestone-status.txt` still exists. If yes, it warns and asks: "Old plan file session-management.md still exists. Delete it, archive it, or keep both?"

---

## Missing Artifact Scenarios and Recovery Paths

### Missing: `progress.txt` (project-level state)

**Scenario:** User deletes it, git stash/checkout loses it, or `/project` bootstrap failed mid-write.

**Recovery:** `/project` bootstrap is re-runnable. If gate review files exist under `docs/reviews/`, the approvals can be inferred. If milestone directories exist, the milestone summary lines can be reconstructed. `/project` should offer: "progress.txt not found. Attempt to reconstruct from existing artifacts? (I'll read review files and milestone directories.)"

Never silently create a blank `progress.txt` — this would lose all gate approval history.

### Missing: `prd.md` (Gate 1 artifact)

**Scenario:** Deleted or corrupted. Downstream skills (`/design`, `/milestone`, `/plan`) all read it.

**Who detects it:** `/project` artifact validation on every read. Also detected when any downstream skill tries to open it.

**Recovery:** Only `/define` can produce `prd.md`. `/project` routes to `/define` in revision mode (even for a blank output, the re-interview produces valid content). If `docs/working-backwards.md` exists (Gate WB), it provides much of the content. If Gate 1 review checklist exists, it records what was approved — useful context for reconstruction.

**What not to do:** Do not allow downstream skills to proceed with a missing `prd.md` by generating a placeholder from memory. The PRD is load-bearing for architecture and milestone planning.

### Missing: `docs/ARCHITECTURE_AND_DESIGN.md` (Gate 2 artifact)

**Scenario:** Deleted after Gate 2 was approved. `/milestone` and `/build` both read it.

**Recovery:** Route to `/design` in revision mode. If `prd.md` exists (Gate 1 artifact), `/design` can regenerate the architecture doc from it. The original Gate 2 review checklist (`docs/reviews/gate-2-review.md`) records what was decided — `/design` should read it during regeneration to restore approved decisions rather than re-interviewing from scratch.

### Missing: `docs/codebase-assessment.md` (Gate 0 artifact)

**Scenario:** Deleted. `/build` reads it at the start of each feature to track codebase drift.

**Recovery:** This is lower severity than prd.md or architecture doc — the codebase itself is the source. `/build` can regenerate it by re-scanning the codebase. However, the user corrections recorded in "Patterns to Deviate From" (populated during Gate 0 review) are lost. The skill should warn: "codebase-assessment.md not found. I can regenerate it from the codebase, but any patterns you marked for deviation in Gate 0 will need to be re-confirmed."

### Missing: `milestones/<NN>-<name>/README.md` (Gate 3 artifact)

**Scenario:** Deleted. `milestone-status.txt` references it as the feature authority.

**Recovery:** Route to `/milestone` in revision mode. The feature entries in `milestone-status.txt` preserve feature names and status, providing the skeleton for regeneration. Feature plans under `plans/` provide detailed acceptance criteria. The skill can reconstruct the README from these without a full re-planning session.

**What not to do:** Do not proceed with `/plan` or `/build` when the milestone README is missing — it is the Gate 3 acceptance criteria authority. Plans that proceed without it may not match what was approved.

### Missing: `milestones/<NN>-<name>/plans/<feature>.md` (Gate 4 artifact)

**Scenario:** Deleted after Gate 4 was approved and before `/build` runs.

**Recovery:** Route to `/plan` to regenerate. The milestone README provides the feature's acceptance criteria. The Gate 4 review checklist (`milestones/<NN>-<name>/reviews/gate-4-<feature>-review.md`) records what approach was approved. `/plan` regeneration reads both and produces a plan consistent with the prior approval. The user re-approves (a short confirmation, not a full re-review, since they've seen it before).

**Important:** `/build` must not be allowed to run without a valid plan file. "I'll work from memory" is not acceptable — the plan file is the session-to-session context transfer mechanism.

### Missing: `milestones/<NN>-<name>/milestone-status.txt`

**Scenario:** Deleted or never created (interrupted `/milestone` run).

**Recovery:** Documented in DESIGN.md: recreate from the milestone README's feature list. Feature plans on disk provide plan paths. Git log provides approximate completion dates. The user confirms the reconstructed status before it is written.

**Skills affected:** `/plan` (reads to check feature status), `/build` (reads and writes feature/sub-feature status).

### Missing: A gate review checklist file

**Scenario:** `docs/reviews/gate-1-review.md` deleted. The gate is already approved in `progress.txt`.

**Recovery:** This is the lowest severity missing-artifact scenario. Review files are records of past decisions, not required inputs for future phases. The only case where a missing review file causes a problem is if another session needs to validate checklist completeness for a re-approval.

**Recovery:** If re-approval is needed, regenerate the checklist from the gate's standard items (they are fixed per gate) and mark all items approved with the original approval date from `progress.txt`. The review quality is reduced (no reviewer comments), but the gate record is restored.

### Missing: `docs/spikes/<topic>.md`

**Scenario:** A spike artifact is deleted but `progress.txt` records it as `[x] resolved`.

**Recovery:** If the spike was resolved and its findings incorporated into a plan (referenced in the plan's Dependencies or Approach section), the findings are effectively preserved. The spike artifact is a reference document, not a required gate input. The recovery path is: re-run `/spike` if the question is still open, or treat it as resolved if the plan already incorporates the findings. Update `progress.txt` status accordingly.

---

## Phase-Specific Warnings

| Phase / Topic | Likely Pitfall | Mitigation |
|---|---|---|
| `/define` Gate 0 on large codebase | Token-heavy codebase scan leaves little context for PRD interview | Write codebase-assessment.md immediately after Gate 0 approval; re-read from file at Gate 1 |
| `/define` Gate WB pending state | Session ends before WB decision is made; pipeline stalls on next invocation | Detect pending state and re-prompt before any other action on next invocation |
| `/define` in revision mode | Downstream artifacts silently stale after PRD revision | After any PRD write, `/project` must surface staleness warning with specific artifact paths and dates |
| `/design` architecture doc | Produces technically correct but PRD-inconsistent design | Enforce cross-reference check: every component in architecture doc maps to a feature or dependency in prd.md |
| `/milestone` sizing | Milestone grows past 5 features during revision | Warn on count > 5; suggest split; do not block |
| `/milestone` feature slugs | Slug derived from title at creation — title revision creates drift | Slugs are immutable after creation; title changes update README only, not directory or plan paths |
| `/plan` sub-feature sizing | Sub-features sized too large to fit in a single `/build` session | Each sub-feature must have a single committable outcome; if it requires the next sub-feature to avoid broken build, it is too small |
| `/build` context budget | Pushing past 80% context budget to finish "one more" sub-feature | Stop at sub-feature boundary when budget is ~80%; write session summary; instruct user to start fresh session |
| `/build` state file update on session crash | `/build` crashes between milestone-status.txt update and progress.txt update | Always write milestone-status.txt first (source of truth); treat progress.txt as derived/recoverable |
| `/spike` agent token usage | Research agent runs autonomously; token spend is less predictable | User controls scope and tooling; red-team pass is fixed-cost; research agent should summarize findings before starting new sub-investigations |
| Re-planning while feature in progress | In-progress code may be invalidated by re-plan without explicit decision | Surface all in-progress/complete features before any status reset; require explicit user decision for each |
| Gate checklist completeness | Skill refuses to proceed until user manually checks boxes, creating ceremony | In-session explicit approval should let skill mark checklist complete on user's behalf |

---

## Sources

- `skills/project/DESIGN.md` — DD-1 through DD-14, artifact inventory, open questions (verified directly)
- `skills/create-prd/SKILL.md` — existing skill patterns, rules, error handling (verified directly)
- `skills/create-prd/assets/progress-template.txt` — existing progress file format (verified directly)
- `.claude/get-shit-done/references/checkpoints.md` — GSD checkpoint patterns for comparison (verified directly)
- Confidence: HIGH for all findings (based on primary source documents)
