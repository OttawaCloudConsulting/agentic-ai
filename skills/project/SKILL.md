---
name: project
description: >
  Project orchestrator. Bootstraps progress.txt on first run, reports project state,
  and routes to the next skill on every subsequent invocation. Use when starting a
  new project, checking project status, or deciding what to do next. Phrases like
  "where am I", "project status", "what's next" are good triggers.
disable-model-invocation: true
---

# /project -- Project Orchestrator

Bootstraps project state on first run, reports status, and routes to the correct next
skill on every subsequent invocation. Read-only after bootstrap.

## Rules

- **Read fresh every time.** Read all state files from disk on every invocation -- never
  rely on conversation memory or cached values (STATE-03).
- **Read-only after bootstrap.** After the initial `progress.txt` creation, `/project`
  never modifies `progress.txt` or any other file (PROJ-10) -- two exceptions exist:
  bootstrap (Step 2) and Gate 3 closure (Step 5, when all milestones are complete).
- **Route, never dispatch.** Tell the user which skill to run next via plain-language
  instruction. Never auto-invoke or auto-dispatch another skill (DD-2).
- **Write-ordering contract for downstream skills.** When both `milestone-status.txt` and
  `progress.txt` need updates, write `milestone-status.txt` first -- source-of-truth-first
  ordering (STATE-04). This rule applies to `/build` and `/milestone`, not to `/project` or `/plan-feature`.
- **Interactive prompts.** Use `AskUserQuestion` for all user-facing choices (2-4 options,
  max 12-character option headers).

## Prerequisites

- Working directory is the project root (the directory where `progress.txt` lives or will
  be created).
- No other files or directories are required -- `/project` handles first-run detection
  automatically.

## Step 1 -- Detect Project State

Read `progress.txt` from the project root.

- If the file **does not exist**, proceed to Step 2 (Bootstrap).
- If the file **exists but is a *light* `progress.txt`** (inline `[ ] Feature X.Y` lines and no
  `## Gates` / `## Milestones` sections), it is owned by `/create-prd` + `/start-feature`, not the
  gated workflow. **Stop** and tell the user: this directory is under the light workflow — use
  `/start-feature` here, or run `/project` from a directory with no light `progress.txt`. Do not
  parse it as gated state and do not overwrite it.
- If the file **exists** with the gated schema (`## Gates` / `## Milestones`), proceed to Step 3
  (Read State).

## Step 2 -- Bootstrap

This is the ONLY time `/project` writes to disk.

1. Read `references/progress-format.md` for the exact bootstrap template, slug derivation
   rules, and format rules.
2. Detect greenfield vs brownfield:
   - **Greenfield:** project directory is empty or contains only boilerplate files (README,
     `.gitignore`, `package.json` with no `src/` directory). Use the greenfield variant --
     Gate 0 recorded as `[-] Gate 0: Codebase Alignment  Skipped (greenfield)` (per DD-10).
   - **Brownfield:** existing source code is present. Use the standard template -- Gate 0
     recorded as `[ ] Gate 0: Codebase Alignment`.
3. Determine the project name and slug:
   - Derive a candidate name from the working directory name.
   - Derive a candidate slug from that name using the slug derivation rules in
     `references/progress-format.md` (lowercase, hyphens, alphanumeric only).
   - Use `AskUserQuestion` to confirm or override the name before writing:
     - Present the derived name and slug as the default option.
     - Offer the user a chance to provide a custom name; the slug is always re-derived
       from the name — it is not set independently.
4. Use the Write tool to create `progress.txt` with the bootstrap template, replacing
   `<Project Name>` with the confirmed project name, `<slug>` with the confirmed slug,
   and `<ISO date>` with today's date (YYYY-MM-DD).
5. Read the file back and confirm it was created correctly.
6. Show the user the created file content.
7. Proceed to Step 3 (Read State) to display the initial status report.

## Step 3 -- Read State

Read `progress.txt` from disk (fresh read -- STATE-03). Parse:

- `# Project-ID: <slug>` header line -- derive the artifact base path: `.project/<slug>/`.
  All artifact reads and writes use this base path for the remainder of the invocation.
- All gate entries in the `## Gates` section (status marker, name, date, artifact path).
- All milestone summary lines in the `## Milestones` section (status, name, path, feature
  counts).
- All spike entries in the `## Spikes` section (status, name, path, resolution date).

For each milestone found, read its `milestone-status.txt` at
`.project/<slug>/milestones/<NN>-<name>/milestone-status.txt` (path derived from the
milestone summary line's directory path, resolved against the artifact base path).

Read `references/routing-logic.md` for validation rules, then perform:

- **Artifact validation (PROJ-04):** For each `[x]` gate, check that the artifact path
  listed on the gate entry line exists on disk. If missing, record an inline warning.
- **Consistency validation (PROJ-05):** For each milestone, compare the `N/M features
  complete` count in `progress.txt` against the actual `[x]` feature count in the
  corresponding `milestone-status.txt`. If they diverge, record a consistency warning.

Collect all warnings. Proceed to Step 4 (Status Report).

## Step 4 -- Status Report

Read `references/status-report-format.md` for the exact output format and structure.

Display the status report to the user following this order:

1. **Gate WB Pending reminder (conditional):** If Gate WB is `[ ] Pending`, show a gentle
   reminder at the top of the report per D-09. This does NOT suppress the rest of the
   report -- the full status display continues below the reminder.
2. **GATES:** Checklist of all gates with status, dates, artifact paths. Inline warnings
   (D-06) appear directly after the gate entry they affect.
3. **ACTIVE MILESTONE:** Expanded view with per-feature status from `milestone-status.txt`.
   Consistency divergence warnings appear inline after the milestone header.
4. **COMPLETED MILESTONES:** One-line summaries (shown only if any milestones are complete).
5. **UPCOMING MILESTONES:** One-line summaries (shown only if upcoming milestones exist).
6. **SPIKES:** All spikes -- both open and resolved (per D-02). Never remove resolved spikes.

If a consistency divergence is detected (D-07 blocking behavior): display the full status
report, but replace the RECOMMENDED section with a request for the user to acknowledge the
discrepancy before routing can proceed.

Proceed to Step 5 (Route).

## Step 5 -- Route

Read `references/routing-logic.md` for the complete routing table and re-planning keywords.

**Re-planning intent detection (D-05, PROJ-08, PROJ-09):** Check if the user's message
contains keywords signaling revision intent:

- PRD revision triggers: "goals changed", "revise PRD", "pivot", "change direction",
  "update requirements", "scope change" -- route to `/define` in revision mode.
- Milestone revision triggers: "re-plan", "revise milestone", "regroup features",
  "change milestone", "re-scope" -- route to `/milestone` in revision mode.

**Normal routing:** Determine the recommended next action based on the current project
state using the routing table. Display per D-03:

- One **RECOMMENDED** action, clearly highlighted.
- 2-3 **Also available** alternatives listed below (per D-04: only actions valid for the
  current project state).

**Gate WB offer (DD-11, D-08):** If Gate 0 is approved (`[x]`) or skipped (`[-]` greenfield),
no `.project/{slug}/docs/working-backwards.md` exists (where `{slug}` is the value parsed
from the `# Project-ID:` header), Gate WB has not been offered yet, and the customer
outcome is unclear -- offer Gate WB using `AskUserQuestion` with options:

- **Yes** -- proceed with Working Backwards exercise (routes to `/define`)
- **Skip** -- record Gate WB as skipped
- **Defer** -- record Gate WB as Pending for later decision

Include a 2-3 sentence explanation of the Working Backwards value proposition.

**Gate 3 closure offer (D-01 through D-05, PROJ-10):** If all milestones in `progress.txt`
are `[x]` complete AND Gate 3 is still `[~] In progress` -- offer Gate 3 closure using
`AskUserQuestion` with options:

- **Close Gate 3** -- write `[x] Gate 3: Milestone Review  Approved: <YYYY-MM-DD>  (closed by /project)`
  to `progress.txt` (replacing the `[~] In progress` line), where `<YYYY-MM-DD>` is today's date.
  Then continue to routing (the "All milestones complete" row will show "Project complete").
- **Leave open** -- skip the write. Continue to normal routing (the "All milestones complete"
  row will still show "Project complete").

Show a 1-line explanation before the prompt: "Gate 3 tracks milestone planning. Closing it
marks the milestone review phase officially complete."

After `AskUserQuestion` resolves (regardless of which option the user chose), continue to
normal routing table evaluation.

If the user chose **Close Gate 3**: use the Write tool to update the Gate 3 line in
`progress.txt`. Read the file first, replace `[~] Gate 3: Milestone Review             In progress`
with `[x] Gate 3: Milestone Review  Approved: <YYYY-MM-DD>  (closed by /project)`. Read the
file back and confirm the update was applied correctly before proceeding to routing.

## Error Handling

- **Malformed `progress.txt`:** If the file is missing required headers or has corrupted
  entries, report the issue to the user. Suggest checking git history for a clean version.
  Do not attempt to repair the file.
- **Missing `milestone-status.txt`:** If a milestone directory exists but its
  `milestone-status.txt` is missing, warn the user but continue -- the milestone may be
  partially created. Show the warning inline in the status report.
- **Ambiguous user intent:** If the user's request is unclear, use `AskUserQuestion` to
  ask for clarification rather than guessing the intended action.
- **Empty project (post-bootstrap):** When all gates are pending, no milestones exist, and
  no spikes exist, display the empty project report format from `references/status-report-format.md`.
  The only valid recommendation is to run `/define`.
- **Interrupted bootstrap:** If `/project` is re-invoked after a failed bootstrap attempt
  (e.g., `progress.txt` exists but is empty or incomplete), treat the file as malformed and
  report the issue rather than attempting a second bootstrap.
