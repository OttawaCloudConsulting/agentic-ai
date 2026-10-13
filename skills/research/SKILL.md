---
name: research
description: >
  Adversarial technical research with independent red-team validation.
  Takes a free-text question, one or more input files or directories, or
  both, then runs a sequential research -> red-team agent pair and writes a
  research artifact whose Red-Team Assessment stands as an equal peer to its
  Findings. Use when investigating technical feasibility, choosing between
  candidate approaches, or stress-testing a survey, options doc, or proposal
  that already exists. Standalone: never reads or writes progress.txt and
  needs no /project bootstrap.
disable-model-invocation: true
---

# /research -- Adversarial Technical Research (standalone)

Investigate a technical question, then have an independent agent try to tear
the answer apart. The output is a single markdown artifact you can read,
argue with, and carry into a design phase.

This is a standalone sibling of `/spike`. Same two-agent adversarial core,
two deliberate differences:

- **Input flexibility.** Accepts free text, file paths, directories, or a
  mix. When given prior work (a problem statement, an options survey, a
  design proposal), the research agent treats it as evidence to validate
  rather than a survey to redo.
- **No project framework.** No `progress.txt`, no `.project/{slug}/`, no
  gates, no bootstrap prerequisite. Run it in any repo, at any time.

## Non-goals

This skill never reads, writes, or creates `progress.txt`, `milestone-status.txt`,
or anything under `.project/`, **even when those files exist**. Lifecycle state
lives entirely in the artifact's own `## Status` line. Keep it that way — the
whole point of this skill is that it works in a repo with no initiative
scaffolding, and a "helpful" write-back would silently reintroduce that
coupling.

If you want gate tracking and `progress.txt` integration, use `/spike` instead.

## Rules

1. **Sequential agents, never concurrent.** The research agent finishes and
   writes its file before the red-team agent starts. The red-team agent's
   value comes from critiquing a finished argument; running them in parallel
   turns the second one into a duplicate researcher.
2. **Both agents run autonomously.** No mid-flight user checkpoints. The user
   sees one confirmation up front and the completed artifact at the end.
3. **Red-team output is never merged, summarized, or softened.** It is a
   peer section, not feedback folded into the findings. A reader must be able
   to see exactly where research and critique disagree.
4. **One confirmation prompt, maximum.** Use a single `AskUserQuestion` call
   with everything you need to resolve at once (max 4 questions, headers
   <=12 characters). If the invocation already pins down question, inputs,
   and destination, skip the prompt entirely and say what you inferred.
5. **No auto-dispatch.** When finished, tell the user what to run next.
   Never chain into another skill on your own.

## Step 1 -- Resolve the input

Read `references/input-resolution.md` for the full parsing rules, the
directory read budget, and the artifact path derivation table.

In short, split the invocation arguments into:

- **`research_question`** -- free-text question, if present
- **`input_files`** -- existing paths (files or directories), if present
- **`available_tooling`** -- named tools/libraries/approaches to evaluate,
  which may be empty
- **`artifact_path`** -- where the artifact will be written, derived from
  the inputs

Read the input files before prompting the user. Reading them is what lets
you propose a sharp question instead of asking the user to restate one they
already wrote down. When prior work already names its own open question
(a "Carried Forward", "Open Question", or "Next Phase" section is a strong
signal), propose that as the default rather than inventing a new one.

## Step 2 -- Detect mode, then confirm once

Check whether an artifact already exists at the derived `artifact_path`
(and, for directory inputs, whether any sibling `RESEARCH-*.md` exists).

- No artifact found -> **new research mode** (Step 3).
- Artifact found for the same question -> **follow-up mode** (Step 6).
- Artifact found but the question differs -> ask which the user wants.

Then confirm with a single `AskUserQuestion`, bundling only what is
genuinely unresolved. Typical questions:

- The research question, when the input files support more than one reading
  (offer the sharpest one first, marked Recommended)
- The artifact destination, when the derivation rules produced a guess
  rather than a clear answer
- Follow-up versus new, on a path collision

Skip any question you can answer from the invocation. A confirmation prompt
that asks about things the user already specified reads as not having looked.

## Step 3 -- Research agent

Read `references/research-agent.md` for the complete specification.

Spawn one sub-agent with the `Agent` tool following that spec. Pass it the
research question, the available tooling list, and the **full paths** of the
input files with instructions to read them as prior work.

The agent writes to `<tmp>/research-<slug>-findings.md`. Substitute the real
slug so two concurrent runs never collide, and pass the agent the completed
path, not the template. For `<tmp>`, use this session's scratchpad directory
when the environment provides one; otherwise `/tmp`.

After it completes, read the findings file to confirm it exists and contains
a `## Load-Bearing Claims` section. That section is what the red-team agent
is aimed at — without it, the critique has no target. If the file is missing
or the section is absent, stop and report rather than proceeding with a
degraded input.

## Step 4 -- Red-team agent

Read `references/redteam-agent.md` for the complete specification.

Spawn a second sub-agent following that spec. It reads
`<tmp>/research-<slug>-findings.md` and writes
`<tmp>/research-<slug>-redteam.md`.

Pass it the same input file paths. It needs them to check whether claims the
research agent attributed to prior work are actually supported by that prior
work — a claim inherited uncritically from an input document is a common and
high-consequence failure, because it arrives wearing the authority of a
written source.

After it completes, read the critique file to confirm it exists.

## Step 5 -- Assemble the artifact

Read `references/artifact-format.md` for the template and assembly rules.

1. Create the parent directory of `artifact_path` if needed.
2. Fill Question, Inputs, and Available Tooling from what you resolved in
   Step 1.
3. Fill Methodology and Findings from the research agent's output.
4. Fill Red-Team Assessment from the red-team agent's output, verbatim.
5. Write the Recommendation yourself. This is the one section neither agent
   produces, and it is the reason the artifact is worth reading: a clear
   pick, why it wins over the runners-up, which red-team concerns survived
   unresolved, and what would make you revisit the call.
6. Set `## Status` to `open` and `## Follow-Up Log` to `(no follow-ups yet)`.
7. Write the artifact, then delete the two temp files.

## Step 6 -- Follow-up mode

Read `references/artifact-format.md` for the follow-up entry format.

Take the user's follow-up question, then run Steps 3 and 4 again with it as
the research question, the same tooling list, and the existing artifact added
to the input files so both agents see what was already concluded.

Append a dated follow-up entry to the `## Follow-Up Log`. Preserve everything
already in the artifact — original findings, red-team assessment, prior
follow-ups, and the original recommendation all stay exactly as written. The
audit trail is the point; a follow-up that quietly rewrites an earlier
conclusion destroys the record of what was believed when.

Then offer resolution with `AskUserQuestion`:

- **Resolved** -- change the `## Status` line from `open` to
  `resolved (YYYY-MM-DD)`
- **Follow-up** -- take another question, repeat Step 6
- **Done** -- leave it open and stop

Never resolve a research artifact on your own. Whether a question is settled
is a judgment about the user's confidence, not about how thorough the
research looked.

## Step 7 -- Completion report

Report: artifact path, the recommendation in one or two lines, the red-team
concerns that survived into the Recommendation, and follow-up count if any.

Then state what the user may want next — reviewing the artifact, running a
follow-up, or moving to design — without invoking anything.

## Error handling

- **Input path does not exist:** report the exact path that failed, then ask
  whether to proceed on free text alone or correct the path. Do not silently
  drop a path the user named.
- **Research agent fails or writes nothing:** stop. Report the failure and
  offer a retry, or let the user supply findings directly. Do not run the
  red-team agent against a missing or truncated file — critique of nothing
  reads as validation.
- **Red-team agent fails:** offer a retry. If the user declines, write the
  artifact with the Red-Team Assessment section stating plainly that no
  red-team pass was performed, and mark `## Status` `open (unvalidated)`.
  An artifact that looks validated but was not is worse than no artifact.
- **Directory input too large:** see the read budget in
  `references/input-resolution.md`; list what you found and ask which files
  matter rather than reading everything.
- **Artifact write fails:** report the error and print the assembled artifact
  so the work is not lost.
- **Interrupted session:** re-invoking `/research` on the same input detects
  the existing artifact and offers follow-up mode.
