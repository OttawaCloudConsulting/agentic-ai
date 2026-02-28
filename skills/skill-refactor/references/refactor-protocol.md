# Refactor Review Protocol

Full protocol for the Refactor Review stage. Claude follows this when executing the skill-refactor workflow.

---

## Stage Overview

After building the initial skill, launch two parallel sub-agents to review it from different perspectives. Compile their feedback into a temp directory for user review. Gate all changes behind explicit user approval.

```
Launch in parallel:
  ├── Critique Agent  → temp/<skill-name>/critique/feedback.md
  └── Red-team Agent  → temp/<skill-name>/red-team/feedback.md

Compile:
  └── temp/<skill-name>/refactor/review-summary.md

Present to user → Approval Gate (AskUserQuestion)

If approved:
  AskUserQuestion → collect requirements
  Refactor Agent  → apply changes
  Log to         → temp/<skill-name>/refactor/decisions.md
```

---

## Temp Directory Structure

Create this structure before launching sub-agents:

```
temp/
└── <skill-name>/
    ├── critique/
    │   └── feedback.md
    ├── red-team/
    │   └── feedback.md
    └── refactor/
        ├── review-summary.md
        └── decisions.md
```

Use the actual skill name (kebab-case) as the directory name.

---

## Sub-agent 1: Critique Agent

**Purpose:** Evaluate the skill against this project's own internal quality standards.

**Prompt template:**

```
You are reviewing a newly created skill for quality against the skill-creator's internal standards.

Skill to review:
- SKILL.md: [full content]
- File list: [list all files and their sizes]

Evaluate against these criteria:

CONCISENESS
- Does each line justify its token cost?
- Are there verbose explanations where examples would be clearer?
- Is there duplicated content between SKILL.md and reference files?

DEGREES OF FREEDOM
- Are high-freedom tasks (multiple valid approaches) left open?
- Are low-freedom tasks (fragile, exact sequence required) locked down with scripts or specific steps?
- Is the specificity level appropriate for the task's fragility?

PROGRESSIVE DISCLOSURE
- Is SKILL.md under 500 lines?
- Are reference files linked with explicit "when to read" guidance?
- Is any content inlined in SKILL.md that belongs in references/?
- Are reference files one level deep?

STRUCTURE
- Does the frontmatter have name and description?
- Is the name kebab-case?
- Are there any forbidden files (README.md, CHANGELOG.md, etc.)?
- Are unused directories included?

DESCRIPTION QUALITY
- Does the description explain WHAT the skill does?
- Does it explain WHEN to use it (trigger conditions)?
- Does it include specific phrases a user would say?

OUTPUT FORMAT:
Write to temp/<skill-name>/critique/feedback.md using this structure:

# Critique Feedback: <skill-name>

## Strengths
- [list what is done well]

## Issues Found
### Critical
- [issue]: [explanation and recommendation]

### Should-Fix
- [issue]: [explanation and recommendation]

### Nice-to-Have
- [issue]: [explanation and recommendation]

## Summary
[2-3 sentence overall assessment]
```

---

## Sub-agent 2: Red-team Agent

**Purpose:** Evaluate the skill against Anthropic's official best practices.

**Prompt template:**

```
You are red-teaming a newly created skill against Anthropic's official skill best practices.

First, read the best practices reference:
references/anthropic-best-practices.md

Then review the skill:
- SKILL.md: [full content]
- File list: [list all files and their sizes]

Work through every section of the best practices reference and check the skill against each criterion. Do not skip sections.

For each gap or issue found, record:
- Which criterion was violated
- What was found in the skill
- Recommended fix
- Severity (Critical / Should-fix / Nice-to-have)

Pay particular attention to:
1. Trigger quality — will this skill auto-trigger reliably?
2. Description completeness — WHAT + WHEN, no XML, under 1024 chars
3. Progressive disclosure — is the three-tier system implemented correctly?
4. Instruction actionability — are steps specific enough to follow without guessing?
5. Error handling — what happens when things go wrong?

OUTPUT FORMAT:
Write to temp/<skill-name>/red-team/feedback.md using this structure:

# Red-team Feedback: <skill-name>

## Criteria Checked
[list each section of best practices reference reviewed]

## Gaps Found

### Critical
- **[criterion]**: [what was found] → [recommended fix]

### Should-Fix
- **[criterion]**: [what was found] → [recommended fix]

### Nice-to-Have
- **[criterion]**: [what was found] → [recommended fix]

## Triggering Risk Assessment
- Under-trigger risk: [low/medium/high] — [reason]
- Over-trigger risk: [low/medium/high] — [reason]

## Summary
[2-3 sentence overall assessment]
```

---

## Compile: Review Summary

After both agents complete, compile their outputs into a single review document.

**Write to `temp/<skill-name>/refactor/review-summary.md`:**

```markdown
# Skill Review: <skill-name>
Generated: <date>

## Critique Summary
[pull Strengths and Issues from critique/feedback.md]

## Best Practices Gaps
[pull Gaps Found from red-team/feedback.md]

## Triggering Risk
[pull Triggering Risk Assessment from red-team/feedback.md]

## Recommended Changes

### Critical (must fix)
[combined critical items from both agents, deduplicated]

### Should-Fix (recommended)
[combined should-fix items, deduplicated]

### Nice-to-Have (optional)
[combined nice-to-have items, deduplicated]

## Files Reviewed
[list skill files and line counts]
```

Present this file path to the user and tell them to review it before approving.

---

## Approval Gate

After presenting the review summary, ask the user for approval before making any changes.

Ask the user directly:

```
Question: "The refactor review is complete. Review temp/<skill-name>/refactor/review-summary.md.
Would you like to proceed with refactoring the skill?"

Options:
  - "Yes, proceed with refactor" — continues to requirements gathering
  - "No, keep the skill as-is" — skips refactor, proceed to Iterate
  - "I need more time to review" — stop here, user will re-invoke later
```

If the user declines or needs more time: record the decision in `decisions.md` and proceed to Step 5 (Iterate) without changes.

---

## Requirements Gathering (Post-Approval)

After approval, gather specific requirements before refactoring.

Ask the user up to 3 questions:

**Question 1 — Change scope:**

```
"Which categories of changes do you want to apply?"
Options (multi-select):
  - All critical issues
  - All should-fix issues
  - Nice-to-have improvements
  - Only changes I specify below
```

**Question 2 — New requirements:**

```
"Any new requirements or direction changes for the skill?"
Options:
  - No changes — apply selected fixes only
  - [free text via Other option]
```

**Question 3 — Refactor depth (only ask if scope is unclear):**

```
"How much should the refactor change?"
Options:
  - Targeted — fix selected issues, preserve everything else
  - Full rewrite — rebuild SKILL.md with all improvements applied
```

Record all answers in `temp/<skill-name>/refactor/decisions.md`.

---

## Sub-agent 3: Refactor Agent

**Purpose:** Apply the approved changes to the skill files.

**Prompt template:**

```
You are applying approved refactor changes to a skill.

Context:
- Skill directory: [path]
- Approved changes: [list from decisions.md]
- New requirements: [from decisions.md]
- Refactor depth: [targeted / full rewrite]

Files to work with:
[list all skill files with content]

Instructions:
1. Apply only the approved changes. Do not make unrequested changes.
2. For targeted refactors: preserve all sections not flagged for change.
3. For full rewrites: rebuild SKILL.md from scratch incorporating all approved changes and new requirements.
4. Keep SKILL.md under 500 lines — move content to references/ if needed.
5. Do not create new files unless explicitly required to fix a gap.
6. Do not delete existing reference files unless the gap requires it.

After applying changes, output a summary:
- What was changed and why
- What was preserved and why
- Any tradeoffs made
- Remaining open items (nice-to-have items not applied)

Write this summary as ## Implementation Notes in temp/<skill-name>/refactor/decisions.md.
```

---

## Decisions Log Template

**`temp/<skill-name>/refactor/decisions.md`:**

```markdown
# Refactor Decisions: <skill-name>
Generated: <date>

## Approval
- User approved refactor: [yes / no / deferred]
- Date: <date>

## Selected Changes
[from AskUserQuestion — which categories and specific items]

## New Requirements
[from AskUserQuestion — any new direction or constraints]

## Refactor Scope
[targeted / full rewrite]

## Implementation Notes
[populated by Refactor Agent after execution]
- Changed: [list]
- Preserved: [list with reasons]
- Tradeoffs: [any made]
- Remaining: [items deferred]
```
