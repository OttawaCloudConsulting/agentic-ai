---
name: spike
description: >
  Adversarial technical research with red-team validation. Spawns research
  and red-team sub-agents to investigate technical questions and produce
  structured spike artifacts. Supports follow-up research on existing spikes.
  Use when investigating technical feasibility, comparing approaches, or
  validating assumptions before committing to a plan.
disable-model-invocation: true
---

# /spike -- Adversarial Technical Research

Accepts a research question and available tooling list, spawns sequential
research and red-team agents, and produces a structured spike artifact at
`.project/{slug}/docs/spikes/<topic>.md`. Supports follow-up
research on existing spikes and lifecycle tracking in `progress.txt`.

## Rules

1. **Read fresh every time.** Read `progress.txt` from disk on every
   invocation -- never rely on conversation memory (STATE-03).
2. **Sequential agents per D-01.** Research agent completes first, then
   red-team agent reviews. Never run concurrently.
3. **Final artifact only per D-02.** Both agents run autonomously without
   user checkpoints. User sees the completed spike doc.
4. **Write-ordering contract.** When updating state files, follow STATE-04
   ordering.
5. **Interactive prompts.** Use `AskUserQuestion` for all user-facing
   choices (2-4 options, max 12-character headers).
6. **No auto-dispatch.** Tell the user what to run next after completion.
   Never auto-invoke another skill.

## Prerequisites

- Working directory is the project root (where `progress.txt` lives).
- `progress.txt` must exist. If not, instruct user to run `/project` first.
  Per D-06, requires a bootstrapped project.

## Step 1 -- Gather Input and Detect Mode

Read `progress.txt` from the project root. Find the line starting with
`# Project-ID:`, take the value after `:`, trim whitespace, and use it as
`{slug}`. Construct the artifact base path:
`.project/{slug}/`. All artifact reads and writes in this skill use
this base path. If the header is missing, report the error and tell the
user to run `/project` to re-bootstrap.

Gather the user's research question and available tooling list per
D-05/SPIKE-01. If the user provided these in their invocation message, use
them directly. If not provided, use `AskUserQuestion` to ask for:

- Research question (what technical question to investigate)
- Available tooling (libraries, tools, approaches to evaluate -- can be empty)

**Follow-up mode detection (SPIKE-05):**
Read `references/spike-format.md` for the Topic Slug Generation rules.
Generate the slug from the topic. Check if
`.project/{slug}/docs/spikes/{topic-slug}.md` exists on disk.

- If file exists: enter follow-up mode (Step 5).
- If file does not exist: enter new spike mode (Step 2).
- If slug collision (file exists but different question): use
  `AskUserQuestion` with options: **Follow-up** (append to existing spike)
  or **New spike** (user provides a different name).

## Step 2 -- Research Agent

Read `references/research-agent.md` for the complete research agent
specification.

Spawn a sub-agent using the `Agent` tool following the research agent spec.
Pass the research question and available tooling list to the agent prompt.
The agent writes findings to `${TMPDIR:-/tmp}/spike-<slug>-research-findings.md` — substitute the actual
spike `<slug>` (from Step 1) so concurrent spikes never collide on a shared temp file. Pass the
concrete slug-filled path to the agent.

After the agent completes, read `${TMPDIR:-/tmp}/spike-<slug>-research-findings.md` to verify
it was produced. If missing, report error and offer retry or manual input.

## Step 3 -- Red-Team Agent

Read `references/redteam-agent.md` for the complete red-team agent
specification.

Spawn a sub-agent using the `Agent` tool following the red-team agent spec.
The agent reads `${TMPDIR:-/tmp}/spike-<slug>-research-findings.md` (research output) and
writes critique to `${TMPDIR:-/tmp}/spike-<slug>-redteam-findings.md`.

After the agent completes, read `${TMPDIR:-/tmp}/spike-<slug>-redteam-findings.md` to verify
it was produced. If missing, report error and offer retry.

## Step 4 -- Assemble Spike Artifact

Read `references/spike-format.md` for the artifact template and assembly
instructions.

Follow the assembly instructions to:

1. Create `.project/{slug}/docs/spikes/` directory if it does not
   exist.
2. Build the spike artifact using the New Spike Template.
3. Populate sections from agent outputs: Methodology and Findings from
   research findings, Red-Team Assessment from red-team findings (per D-10:
   equal peer section, never merge or suppress).
4. Write the Recommendation section: state the recommended approach, why,
   remaining risks after red-team review (per D-11).
5. Set Status to `open`.
6. Set Follow-Up Log to `(no follow-ups yet)`.
7. Write the artifact to `.project/{slug}/docs/spikes/{topic-slug}.md`.

**Update progress.txt (SPIKE-04, D-07):**
Read `references/progress-format.md` for spike entry format. Add a `[ ]`
entry under `## Spikes` in `progress.txt`. If `(none yet)` placeholder
exists, replace it with the entry.
Format: `[ ] {Spike Name}  .project/{slug}/docs/spikes/{topic-slug}.md`

Proceed to Step 6 (Completion Report).

## Step 5 -- Follow-Up Mode (SPIKE-05)

Read `references/spike-format.md` for the Follow-Up Log Entry Format.

The user provides a follow-up question. Re-run the research and red-team
agents (Steps 2-3) with the follow-up question as the research question
and the same available tooling from the original spike.

After both agents complete:

1. Read the existing spike artifact from
   `.project/{slug}/docs/spikes/{topic-slug}.md`.
2. Append a new Follow-Up Log entry per the dated entry format (per D-08,
   D-12).
3. If `(no follow-ups yet)` placeholder exists, replace it with the entry.
4. Preserve all original content -- never overwrite findings, red-team
   assessment, or prior follow-ups.
5. Write the updated artifact back to
   `.project/{slug}/docs/spikes/{topic-slug}.md`.

**Offer resolution (SPIKE-06, D-07, D-08):**
Use `AskUserQuestion` with options: **Resolved** (mark spike resolved) /
**Follow-up** (continue with another question) / **Done** (leave open, end
session).

If "Resolved": Change `## Status` in the spike artifact from `open` to
`resolved`. Update `progress.txt` spike entry from `[ ]` to `[x]` with
`Resolved: YYYY-MM-DD` suffix.
If "Follow-up": Gather the new follow-up question, repeat Step 5.
If "Done": Leave spike open, proceed to completion report.

## Step 6 -- Completion Report

Display summary showing: spike name, artifact path
(`.project/{slug}/docs/spikes/{topic-slug}.md`), state update
(`progress.txt` entry added/updated), and next action suggestion (review
artifact or run `/project` for status).

If follow-ups were recorded, show count. If resolved, show resolution date.

## Error Handling

- **Missing progress.txt:** Do not proceed. Tell user to run `/project`
  first.
- **Research agent failure:** Report failure. Offer retry or manual research
  input (user provides findings directly).
- **Red-team agent failure:** Report failure. Offer retry or skip red-team
  (note in artifact that red-team was not performed).
- **Missing `.project/{slug}/docs/spikes/` directory:** Create it automatically.
- **Spike artifact write failure:** Report error, display artifact content
  so user can save manually.
- **Interrupted session:** User can re-invoke `/spike`. For new spikes, if
  artifact already written, detects as follow-up mode. For follow-ups in
  progress, user re-invokes and adds the follow-up.
