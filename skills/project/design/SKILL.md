---
name: design
description: >
  Architecture and design specification from an approved PRD, with in-session
  revision before gate approval. Supports refresh mode to consolidate
  architectural deviations. Use when designing architecture, creating design
  doc, reviewing technical choices, or refreshing architecture after
  implementation deviations. Phrases like "design the architecture", "create
  design doc", "refresh architecture" are good triggers.
disable-model-invocation: true
---

# /design -- Architecture and Design (Gate 2)

Produces `docs/ARCHITECTURE_AND_DESIGN.md` from an approved PRD and optional
codebase assessment, with in-session revision before gate approval. Supports
refresh mode to consolidate accumulated architectural deviations from feature
plans.

## Rules

- **Read fresh every time.** Read `progress.txt` from disk on every invocation --
  never rely on conversation memory or cached values (STATE-03).
- **Produce-then-review at every gate.** Produce the full artifact, present it,
  offer Approve / Revise / Partial. Rejection = revision request (D-10).
- **All checklist items must be resolved.** Every review checklist item must be
  `[x]` or `[-]` (N/A with reason) before recording gate approval (D-11).
- **Write-ordering contract.** When writing to state files, follow STATE-04
  ordering. For `/design`, only `progress.txt` is modified (gate entry).
- **Interactive prompts.** Use `AskUserQuestion` for all user-facing choices
  (2-4 options, max 12-character headers).
- **No auto-dispatch.** Tell the user what to run next after completion. Never
  auto-invoke another skill.

## Prerequisites

- Working directory is the project root (where `progress.txt` lives).
- `progress.txt` must exist. If it does not, instruct the user to run `/project`
  first to bootstrap project state.
- Gate 1 must be `[x]` approved in `progress.txt` (DES-01).

## Step 1 -- Detect Mode and State

Read `progress.txt` from the project root.

**Prerequisite check (DES-01):**
If Gate 1 is not `[x]` approved in `progress.txt`, inform the user:
"Gate 1 (Scope Review) must be approved before running /design. Run /define to
complete the PRD first."
Do not proceed. End the session.

**Refresh mode detection (DES-08):**
Check ALL of the following:
- Gate 2 is `[x]` approved in `progress.txt`
- `docs/ARCHITECTURE_AND_DESIGN.md` exists on disk

If ALL true: jump to Step 4 (Refresh Mode).

**Already-approved detection (no refresh intent):**
If Gate 2 is `[x]` approved AND `docs/ARCHITECTURE_AND_DESIGN.md` exists AND
the user's message does NOT signal refresh intent (keywords: "refresh", "update
architecture", "consolidate deviations", "sync deviations"):
Inform the user Gate 2 is already approved. Use `AskUserQuestion` with options:
**Refresh** (enters refresh mode) or **Status** (suggests running `/project`).

**Normal mode:**
If Gate 2 is not yet approved: proceed to Step 2 (Architecture Generation).
Before generating, Step 2 checks whether `docs/ARCHITECTURE_AND_DESIGN.md`
already exists on disk and integrates into it rather than overwriting (see
references/gate-2-design.md for details).

## Step 2 -- Architecture Generation

Read `references/gate-2-design.md` for the complete Gate 2 specification.

Follow the gate-2-design specification to:
1. Read `prd.md` and `docs/codebase-assessment.md` (if exists) (DES-02).
2. Spawn architecture sub-agent to scan 15-30 files (D-05, D-06).
3. Synthesize findings + PRD into `docs/ARCHITECTURE_AND_DESIGN.md` using
   `assets/architecture-template.md` (DES-03).
4. Present tradeoff callouts for 2-4 key decisions (D-09).
5. Enter produce-then-review cycle with section-by-section partial approval
   (DES-05, DES-06, D-08).
6. Generate and validate review checklist `docs/reviews/gate-2-review.md`
   (DES-04, D-11).
7. Record Gate 2 approval in `progress.txt` (DES-07).

Proceed to Step 3.

## Step 3 -- Completion Report

Display summary of what was produced:

```
DESIGN COMPLETE: [Project Title]

ARTIFACTS CREATED:
- docs/ARCHITECTURE_AND_DESIGN.md (Gate 2)

REVIEW CHECKLISTS:
- docs/reviews/gate-2-review.md

NEXT: Run /project to see updated status, then /milestone for Gate 3.
```

## Step 4 -- Refresh Mode

Read `references/refresh-mode.md` for the complete refresh mode specification.

Follow the refresh-mode specification to:
1. Scan `milestones/*/plans/*.md` for Architectural Deviations sections.
2. If zero deviations found: report "No architectural deviations found.
   Architecture doc is current." and exit (D-14).
3. Present each deviation with original design decision context (D-12).
4. User selects which deviations to consolidate via multiSelect.
5. Apply selected deviations to `docs/ARCHITECTURE_AND_DESIGN.md` (D-13).
6. Present updated doc for section-by-section review.
7. Update Gate 2 date in `progress.txt`.

Display refresh completion summary:

```
DESIGN REFRESHED: [Project Title]

DEVIATIONS CONSOLIDATED: N of M
ARTIFACTS UPDATED:
- docs/ARCHITECTURE_AND_DESIGN.md (refreshed)

NEXT: Run /project to see updated status.
```

## Error Handling

- **Missing progress.txt:** Do not proceed. Tell the user to run `/project` first
  to bootstrap project state.
- **Gate 1 not approved:** Do not proceed. Tell the user to run `/define` first
  (DES-01).
- **Gate 2 already approved without refresh intent:** Inform the user, offer
  Refresh or Status check.
- **Agent scan failure:** Report failure, offer manual architecture input (user
  describes system) or retry.
- **Existing architecture doc found (Gate 2 not approved):** The document is
  preserved and new content is integrated. If the existing document is
  unreadable, empty, non-text/binary, or does not resemble Markdown, inform
  the user that it cannot be used as the existing architecture document and
  offer: **Overwrite** (start fresh) or **Abort** (user fixes manually).
- **Missing prd.md:** This should not happen if Gate 1 is approved. Report
  inconsistency -- Gate 1 is marked approved but `prd.md` is missing. Suggest
  running `/project` to check state.
- **Interrupted session:** User can re-invoke `/design`. Skill re-reads
  `progress.txt` and resumes from appropriate state.
