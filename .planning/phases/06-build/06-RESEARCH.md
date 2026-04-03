# Phase 6: /build - Research

**Researched:** 2026-04-03
**Domain:** Claude Code skill implementation -- feature builder with sub-feature execution, state tracking, codebase assessment refresh, test gating, and deviation recording
**Confidence:** HIGH

## Summary

Phase 6 implements the `/build` skill, the first skill in the pipeline that performs actual code implementation. It consumes Gate 4-approved feature plans and executes sub-features in order, leaving the codebase committable after each. Unlike prior skills (which produce documents and update state), `/build` writes code, refreshes the codebase assessment, tracks architectural deviations, runs test commands, and updates BOTH `milestone-status.txt` AND `progress.txt` -- making it the most write-heavy skill in the suite.

The skill follows the established pattern: a SKILL.md flow controller (~150-200 lines) loading reference files from `references/` and templates from `assets/`. The complexity lives in the reference files, not the SKILL.md. Key reference files needed: build execution spec, codebase assessment refresh spec, deviation recording spec, and a copy of progress-format.md.

**Primary recommendation:** Structure /build as a flow controller SKILL.md with 3-4 reference files. The largest reference file will be the build execution spec covering sub-feature loop, commit protocol, test execution, failure handling, and state file updates. Keep the codebase assessment refresh as a separate reference file since it involves sub-agent spawning (parallels Gate 0's sub-agent pattern in `/define`).

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Auto-resume -- each `/build` invocation reads the feature plan, finds the first unchecked `[ ]` sub-feature, and continues from there. One invocation can complete multiple sub-features until context fills or feature completes.
- **D-02:** State-file handoff on context limits -- mark completed sub-features `[x]` in the feature plan, commit, update `milestone-status.txt`. Next `/build` invocation auto-resumes from the first unchecked item. The plan checklist IS the continuity mechanism.
- **D-03:** Commit per sub-feature -- each completed sub-feature gets its own commit. Matches BUILD-03's "committable state" requirement. Clean git history, easy to bisect.
- **D-04:** Checklist recap after each sub-feature -- after completing each sub-feature, show the full checklist with `[x]` marks and announce what's next. Keeps the user oriented within the session.
- **D-05:** Incremental git-diff update -- check git history since last assessment date. Read only changed/new files. Update the Recent Changes section and any affected sections. Fast and focused, preserves existing assessment structure.
- **D-06:** Refresh timing -- refresh `docs/codebase-assessment.md` BEFORE reading the feature plan. Ensures implementation decisions are grounded in current codebase state.
- **D-07:** Standalone commit for assessment refresh -- commit the updated assessment before starting implementation. Clean separation between "understood the codebase" and "started building".
- **D-08:** Test runs at feature completion only -- run the feature's test command once after all sub-features are done. Per BUILD-05, test pass gates feature completion. Sub-features are validated by committable state, not test runs.
- **D-09:** Hard stop with diagnosis on test failure -- stop implementation, show the test output, diagnose the failure, and present options: fix and re-run, update test command (BUILD-06), or exit for user to investigate. No automatic retry loop.
- **D-10:** Test command update via inline failure handling -- when tests fail, one of the options is "Update test command". User provides corrected command, `/build` writes it to the feature plan, re-runs. Natural flow within the failure handling UX, no separate proactive step.
- **D-11:** Claude detects + user confirms -- when `/build`'s implementation diverges from what the plan or architecture doc specified, Claude flags it: "This deviates from the plan because X. Record as deviation?" User confirms or dismisses.
- **D-12:** Structured 4-field entry per DESIGN.md -- each deviation records: what changed, what was originally planned, why the change was necessary, and impact on other components. Enough for `/design` refresh mode to consolidate intelligently.
- **D-13:** Write deviations immediately when detected -- write the deviation entry to the feature plan as soon as it's confirmed. Gets committed with the sub-feature that caused it. Deviation is never lost even if session ends unexpectedly.

### Claude's Discretion
- Exact sub-agent prompt for incremental codebase assessment refresh
- How to detect which files changed since last assessment (git log strategy)
- Commit message format for sub-feature commits
- How to detect deviations from the architecture doc (comparison heuristics)
- Internal session progress tracking approach
- How to handle edge cases when plan has ambiguous sub-feature boundaries

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BUILD-01 | Validate Gate 4-approved plan exists before implementation | Prerequisite check pattern from /plan (PLAN-02), /milestone (MIL-01); read milestone-status.txt for `[~] planned, awaiting build` status |
| BUILD-02 | Refresh `docs/codebase-assessment.md` at feature start | Gate 0 sub-agent pattern from `/define`; incremental refresh via git-diff per D-05; standalone commit per D-07 |
| BUILD-03 | Implement sub-features in order; each leaves codebase committable | D-01 auto-resume, D-03 commit per sub-feature; feature plan checklist format from template |
| BUILD-04 | Mark each completed sub-feature `[x]` in feature plan | Feature plan template Sub-Features section; Edit tool to update checklist markers |
| BUILD-05 | Run test command on completion; only mark complete on pass (exit 0) | DD-12 test execution spec; D-08 test at feature completion only; Bash tool for command execution |
| BUILD-06 | Support test command update mid-build | D-10 inline failure handling; Edit tool to update Test Command field in feature plan |
| BUILD-07 | Record architectural deviations in feature plan | D-11 detection + confirmation, D-12 structured 4-field entry, D-13 immediate write |
| BUILD-08 | Update milestone-status.txt on sub-feature and feature completion | Progress-format.md Sub-features count; status transitions `[~]` -> `[x]`; write-ordering STATE-04 |
| BUILD-09 | Update progress.txt milestone summary on feature completion | Progress-format.md milestone summary line; increment feature count; mark milestone `[x]` when last feature completes |

</phase_requirements>

## Standard Stack

This is a Claude Code skill -- no npm packages or external libraries. The "stack" is the file structure and conventions of the skill system.

### Core
| Component | Pattern | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SKILL.md | Flow controller, ~150-200 lines | Entry point, step-by-step orchestration | All 4 existing skills use this pattern |
| references/ | Detailed spec files | Gate/execution logic too long for SKILL.md | /plan, /milestone, /design all use this |
| assets/ | Templates | Reusable file templates | /plan uses for feature-plan-template.md |
| progress-format.md | Own copy per skill | State file format spec | D-04 decision: no cross-directory reads |

### Supporting
| Component | Pattern | Purpose | When to Use |
|-----------|---------|---------|-------------|
| Sub-agent (Agent tool) | Spawned for codebase scan | Incremental assessment refresh | At feature start (BUILD-02, D-05) |
| AskUserQuestion | Interactive prompts | User choices (2-4 options, max 12-char headers) | Test failure handling, deviation confirmation |
| Edit tool | File modifications | Update checklist markers, plan content, state files | After each sub-feature completion |
| Bash tool | Command execution | Test command execution, git operations | Test runs, git log for assessment refresh |

## Architecture Patterns

### Recommended Skill Structure
```
skills/project/build/
├── SKILL.md                     # Flow controller (~180 lines)
├── references/
│   ├── build-execution.md       # Sub-feature loop, commit, state updates
│   ├── codebase-refresh.md      # Incremental assessment refresh spec
│   ├── deviation-recording.md   # Deviation detection and recording spec
│   └── progress-format.md       # Own copy (no cross-directory reads)
└── assets/
    └── (none anticipated)       # /build consumes existing templates, doesn't produce new ones
```

### Pattern 1: Flow Controller SKILL.md
**What:** SKILL.md defines steps, rules, prerequisites, error handling. Each step references a file in `references/` for detailed logic.
**When to use:** Always -- this is the established pattern for all skills.
**Example structure:**
```
Step 1 -- Validate Prerequisites and Detect State
Step 2 -- Refresh Codebase Assessment (D-05, D-06, D-07)
Step 3 -- Load Feature Plan and Begin Build (D-01)
Step 4 -- Sub-Feature Execution Loop (D-03, D-04)
Step 5 -- Feature Completion (D-08, BUILD-05)
Step 6 -- Completion Report
```

### Pattern 2: Sub-Feature Execution Loop
**What:** The core build loop. For each unchecked sub-feature: implement, commit, mark `[x]` in plan, update milestone-status.txt sub-feature count, show checklist recap, continue to next.
**When to use:** Step 4 of the flow -- the heart of /build.
**Key details:**
- Auto-resume from first `[ ]` sub-feature (D-01)
- One commit per sub-feature (D-03)
- Checklist recap after each (D-04)
- Deviation detection during implementation (D-11, D-13)
- State-file handoff enables multi-session builds (D-02)

### Pattern 3: Dual State File Updates (BUILD-08 + BUILD-09)
**What:** /build is the FIRST skill that writes to BOTH `milestone-status.txt` AND `progress.txt`. Write ordering: milestone-status.txt FIRST (STATE-04).
**When to use:** On feature completion (all sub-features done + test passes).
**Update sequence:**
1. Update `milestone-status.txt`: feature marker `[~]` -> `[x]`, sub-features count to N/N
2. Update `progress.txt`: increment feature count in milestone summary line
3. If last feature in milestone: mark milestone `[x]` in both files

### Pattern 4: Incremental Codebase Assessment Refresh
**What:** Sub-agent spawned to check git history since last assessment, read changed/new files, update relevant sections of `docs/codebase-assessment.md`.
**When to use:** At feature start, BEFORE reading the feature plan (D-06).
**Key details:**
- Git log strategy: `git log --since="<last-assessment-date>" --name-only` to find changed files
- Read only changed/new files (not full re-scan)
- Update Recent Changes section and any affected sections
- Standalone commit before implementation begins (D-07)
- Parallels Gate 0 sub-agent pattern but narrower scope

### Anti-Patterns to Avoid
- **Writing to progress.txt without writing milestone-status.txt first** -- violates STATE-04 write ordering
- **Running tests per sub-feature** -- D-08 specifies tests at feature completion only
- **Auto-retrying failed tests** -- D-09 requires hard stop with diagnosis
- **Skipping codebase assessment refresh** -- D-06 requires refresh BEFORE reading feature plan
- **Reading feature plan before assessment refresh** -- D-06 ordering is deliberate
- **Omitting checklist recap** -- D-04 requires full checklist display after each sub-feature
- **Auto-recording deviations without user confirmation** -- D-11 requires user confirms

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| State file format | Custom format parsing | Follow progress-format.md exactly | Consistency with all other skills; 4 canonical markers only |
| Sub-feature tracking | Separate tracking mechanism | Feature plan checklist (the plan IS the tracking) | D-02: the plan checklist IS the continuity mechanism |
| Session resumption | Custom resume state file | Auto-resume from first `[ ]` in feature plan | D-01: plan checklist provides all needed state |
| Codebase scanning | Full re-scan every time | Incremental git-diff refresh | D-05: read only changed/new files since last assessment |

**Key insight:** The feature plan template already has the Sub-Features checklist, Architectural Deviations section, and Test Command field. /build writes INTO these existing structures rather than creating parallel tracking.

## Common Pitfalls

### Pitfall 1: Write-Ordering Violation on Feature Completion
**What goes wrong:** Writing progress.txt before milestone-status.txt, then crash leaves inconsistent state.
**Why it happens:** Feature completion updates both files; natural impulse is to write the "summary" first.
**How to avoid:** Explicit write order in the reference file: milestone-status.txt FIRST, then progress.txt (STATE-04).
**Warning signs:** Any code path that touches progress.txt without having already written milestone-status.txt.

### Pitfall 2: Milestone Completion Edge Case
**What goes wrong:** /build completes the last feature in a milestone but doesn't update the milestone marker from `[~]` to `[x]` in progress.txt.
**Why it happens:** Most feature completions only increment the count. The "is this the last feature?" check is easy to forget.
**How to avoid:** After every feature completion, check: does completed count == total count? If yes, mark milestone `[x]`.
**Warning signs:** Milestone stuck at `[~]` with all features at `[x]`.

### Pitfall 3: Assessment Refresh Date Detection
**What goes wrong:** Can't determine when the last assessment was done, leading to either a full re-scan (wasteful) or skipped refresh (stale data).
**Why it happens:** The assessment file doesn't have a standardized date header.
**How to avoid:** Use git log to find the last commit that modified `docs/codebase-assessment.md`. Alternatively, check if the assessment file has a date in its content. Fall back to checking all recent commits if no date found.
**Warning signs:** Sub-agent reading hundreds of files instead of the targeted few that changed.

### Pitfall 4: Deviation Detection False Positives
**What goes wrong:** Flagging every minor implementation choice as a "deviation" from the architecture doc.
**Why it happens:** Architecture docs describe intent, not exact code. Most implementation details aren't deviations.
**How to avoid:** A deviation is when the implementation CONTRADICTS what the plan or architecture doc specifies -- not when it adds implementation detail the plan didn't specify. Only flag when the actual approach differs from the documented approach.
**Warning signs:** More than 1-2 deviations per feature suggests over-detection.

### Pitfall 5: Test Command Execution Without Safety
**What goes wrong:** Test command runs destructive operations, hangs indefinitely, or produces ambiguous exit codes.
**Why it happens:** Test commands are user-provided strings executed via Bash tool.
**How to avoid:** Execute with a reasonable timeout. Check exit code 0 for pass, non-zero for fail. Show full output on failure per D-09.
**Warning signs:** Test commands that include `rm`, `docker`, or deployment operations.

### Pitfall 6: SKILL.md Exceeding Line Budget
**What goes wrong:** Trying to put too much detail in SKILL.md, exceeding the ~200-line soft limit.
**Why it happens:** /build has the most complex execution flow of any skill.
**How to avoid:** SKILL.md is a flow controller. All detailed logic goes in reference files. Steps should say "Read references/build-execution.md and follow the Sub-Feature Loop section" -- not inline the loop logic.
**Warning signs:** SKILL.md approaching 250+ lines.

## Code Examples

### Sub-Feature Status Update in Feature Plan
```markdown
## Sub-Features

- [x] **SF-1: Create database schema** -- Tables, indices, constraints
- [x] **SF-2: Implement data access layer** -- CRUD operations, connection pooling
- [ ] **SF-3: Add API endpoints** -- REST routes, validation, error handling
- [ ] **SF-4: Integration tests** -- End-to-end validation
```
After SF-3 completion, Edit tool changes `[ ]` to `[x]` on the SF-3 line.

### milestone-status.txt Update on Sub-Feature Completion
```
[~] Feature 01.2: Session Management
    Plan: milestones/01-core-auth/plans/session-management.md
    Sub-features: 2/4 complete
    Notes: Started 2026-04-03.
```
After completing SF-3: `Sub-features: 3/4 complete`

### milestone-status.txt Update on Feature Completion
```
[x] Feature 01.2: Session Management
    Plan: milestones/01-core-auth/plans/session-management.md
    Sub-features: 4/4 complete
    Notes: Started 2026-04-03. Completed 2026-04-04.
```

### progress.txt Update on Feature Completion
```
[~] Milestone 01: Core Auth              milestones/01-core-auth/   2/3 features complete
```
After feature completion: `3/3 features complete` and if last feature: `[x] Milestone 01: Core Auth`

### Architectural Deviation Entry (4-field format per D-12)
```markdown
## Architectural Deviations

### Deviation 1: Switched from JWT to session cookies
- **What changed:** Authentication uses server-side sessions with cookies instead of stateless JWT tokens
- **Originally planned:** JWT-based authentication per ARCHITECTURE_AND_DESIGN.md Design Decision DD-3
- **Why necessary:** JWT refresh token rotation added significant complexity; session cookies simpler for single-server deployment
- **Impact:** Session storage requires server-side state; affects horizontal scaling strategy in future milestones
```

### Test Failure Handling UX
```
TEST FAILED: milestones/01-core-auth/plans/session-management.md

Command: bash tests/test-session.sh
Exit code: 1

Output:
[full test output here]

DIAGNOSIS: Test expects JWT format in Authorization header, but implementation uses session cookies.

Options:
- Fix       -- Fix the code to match test expectations
- Update    -- Provide a corrected test command
- Exit      -- Stop here; investigate manually
```

### Checklist Recap After Sub-Feature (D-04)
```
SUB-FEATURE COMPLETE: SF-2: Implement data access layer

## Sub-Features
- [x] **SF-1: Create database schema**
- [x] **SF-2: Implement data access layer**
- [ ] **SF-3: Add API endpoints**
- [ ] **SF-4: Integration tests**

NEXT: SF-3: Add API endpoints
```

### Git Log for Assessment Refresh Date Detection
```bash
git log -1 --format="%ai" -- docs/codebase-assessment.md
```
Returns the date of the last commit that touched the assessment file. Then:
```bash
git log --since="2026-03-15" --name-only --format="" | sort -u
```
Returns all files changed since that date.

### Commit Message Format for Sub-Features (Claude's Discretion)
```
feat(<feature-slug>): SF-N <sub-feature-name>

Implements <brief description of what was done>.
```
Example:
```
feat(session-management): SF-2 implement data access layer

Adds CRUD operations for session storage with connection pooling.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Monolithic build sessions | Sub-feature decomposition with auto-resume | DD-1 (project design) | Enables multi-session builds within context limits |
| Manual state tracking | Plan checklist IS the continuity mechanism | D-02 | No separate resume state needed |
| Full codebase re-scan | Incremental git-diff refresh | D-05 | Faster, more focused assessment updates |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual validation -- Claude Code skills are prompt-based, no unit test framework |
| Config file | none |
| Quick run command | Manual: invoke `/build` on a test project with a Gate 4-approved plan |
| Full suite command | Manual: complete feature build cycle end-to-end |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BUILD-01 | Declines without Gate 4-approved plan | manual | Invoke `/build` with no planned features | N/A |
| BUILD-02 | Refreshes codebase assessment at feature start | manual | Invoke `/build`, verify assessment commit appears first | N/A |
| BUILD-03 | Sub-features leave codebase committable | manual | Check git log after each sub-feature commit | N/A |
| BUILD-04 | Marks sub-features `[x]` in plan | manual | Read feature plan after sub-feature completion | N/A |
| BUILD-05 | Test pass gates feature completion | manual | Invoke with failing test command, verify hard stop | N/A |
| BUILD-06 | Supports test command update | manual | Trigger test failure, select Update option | N/A |
| BUILD-07 | Records architectural deviations | manual | Implement code that deviates, verify 4-field entry in plan | N/A |
| BUILD-08 | Updates milestone-status.txt | manual | Complete sub-feature, verify count increment | N/A |
| BUILD-09 | Updates progress.txt on feature completion | manual | Complete all sub-features + test, verify progress.txt | N/A |

### Sampling Rate
- **Per task commit:** Manual review of skill files against requirements
- **Per wave merge:** End-to-end /build invocation on test project
- **Phase gate:** All 9 BUILD requirements verified through manual test

### Wave 0 Gaps
None -- Claude Code skills do not have automated test infrastructure. Validation is through manual invocation and requirement verification against the skill files.

## Open Questions

1. **Assessment refresh date extraction**
   - What we know: git log can find last commit date for `docs/codebase-assessment.md`
   - What's unclear: What if the assessment was never committed (only written in-session)? Edge case on first /build invocation after /define.
   - Recommendation: Use git log as primary. Fall back to "scan all commits in last 7 days" if no prior assessment commit found. This is Claude's discretion per CONTEXT.md.

2. **Sub-feature boundary ambiguity**
   - What we know: Feature plans define sub-features, but some may have unclear boundaries.
   - What's unclear: How to handle when a sub-feature's scope turns out to be different than planned.
   - Recommendation: Implement what makes sense, note the deviation if significant. This is Claude's discretion per CONTEXT.md.

3. **Milestone completion notification to /project**
   - What we know: /build marks milestone `[x]` in progress.txt when last feature completes (BUILD-09).
   - What's unclear: Does /build also need to close Gate 3? DESIGN.md says Gate 3 closure is `/project`'s responsibility.
   - Recommendation: /build writes `[x]` on the milestone summary line only. Gate 3 closure remains /project's domain. This aligns with DD-3 (orchestrator responsibilities).

## Project Constraints (from CLAUDE.md)

- Use `<br/>` for line breaks inside Mermaid node labels (not `\n`)
- No other actionable directives from CLAUDE.md affect this phase

## Sources

### Primary (HIGH confidence)
- `skills/project/DESIGN.md` -- DD-1 through DD-14, milestone-status.txt format (line 915-960), progress.txt format (line 865-913), feature plan lifecycle
- `skills/project/plan/SKILL.md` -- Flow controller pattern (160 lines), reference loading, state reading
- `skills/project/plan/references/gate-4-plan.md` -- Gate 4 spec defining the feature plan structure /build consumes
- `skills/project/plan/assets/feature-plan-template.md` -- Feature plan template with Sub-Features checklist format
- `skills/project/plan/references/progress-format.md` -- State file format spec with write-ordering contract
- `skills/project/define/references/gate-0-codebase.md` -- Gate 0 sub-agent pattern for codebase assessment
- `skills/project/milestone/SKILL.md` -- Write-to-both-files pattern, dual state file updates
- `.planning/phases/06-build/06-CONTEXT.md` -- All locked decisions D-01 through D-13
- `.planning/REQUIREMENTS.md` -- BUILD-01 through BUILD-09 acceptance criteria

### Secondary (MEDIUM confidence)
- Commit message format recommendation (convention-based, not documented in design)
- Deviation detection heuristics (Claude's discretion area)

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- directly follows established 5-phase skill pattern
- Architecture: HIGH -- SKILL.md + references/ structure proven across 4 skills
- Pitfalls: HIGH -- derived from DESIGN.md contracts (STATE-04, DD-12) and prior skill patterns
- Code examples: HIGH -- derived from progress-format.md and feature-plan-template.md

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (stable -- skill patterns well established)
