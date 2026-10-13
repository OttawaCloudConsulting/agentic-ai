# /research

**Source:** `skills/research/`
**Command:** `/research`
**Activation:** Manual only (`disable-model-invocation: true`) -- invoked via slash command. Not auto-triggered by conversational phrases.

## Purpose

Standalone adversarial technical research. Takes a free-text question, existing input files or directories, or both, then runs a sequential research agent followed by an independent red-team agent and writes a single markdown artifact. The red-team's Red-Team Assessment stands as an equal peer section to Findings -- never merged, summarized, or softened. The skill writes the Recommendation itself, since neither agent produces it.

`/research` is a standalone sibling of `/spike`. Same two-agent adversarial core, two deliberate differences:

- **Input flexibility.** Accepts free text, file paths, directories, or a mix. Given prior work (a problem statement, an options survey, a design proposal), the research agent treats it as evidence to validate rather than a survey to redo.
- **No project framework.** No `progress.txt`, no `.project/{slug}/`, no gates, no bootstrap. Runs in any repo at any time.

## When to Use

- Investigating technical feasibility or choosing between candidate approaches
- Stress-testing an existing survey, options document, or proposal
- Resolving a technical question that blocks a spec before `/create-spec`
- Research in a repo that is not under `/project` management

## When NOT to Use

- You want gate tracking and `progress.txt` integration (use `/spike`)
- Adversarial review of a finished artifact such as code, a PRD, or infrastructure (use `/red-team`)
- Complexity or YAGNI gating of a diff or plan (use `/over-engineering-review`)

## Non-Goals

The skill never reads, writes, or creates `progress.txt`, `milestone-status.txt`, or anything under `.project/`, **even when those files exist**. Lifecycle state lives entirely in the artifact's own `## Status` line. A "helpful" write-back would silently reintroduce the coupling this skill exists to avoid.

## Usage

```
/research                                            # prompts for question and tooling
/research Is Redis Streams a fit for our job queue?  # question only
/research docs/_working/auth-options/                # directory input, question derived
/research docs/rfc-014.md docs/rfc-015.md            # file inputs, question derived
/research docs/_working/auth/ which option scales?   # path is prior work, text is the question
```

Every whitespace-separated token that resolves to an existing path is an input; everything else is free text. A token that looks like a path but does not exist is an error, not free text.

## Behavior

### 1. Resolve the Input

Splits arguments into `research_question`, `input_files`, `available_tooling` (may be empty), and `artifact_path`. Reads input files **before** prompting so it can propose a sharp question instead of asking the user to retype one. When prior work names its own open question ("Carried Forward", "Open Question", "Next Phase"), that becomes the default proposal. Directory inputs are listed non-recursively and read within a roughly 100KB budget; over budget, it lists files with sizes and asks which matter rather than silently skipping.

### 2. Detect Mode and Confirm Once

Checks for an existing artifact at the derived path, and for directory or file inputs also globs `RESEARCH-*.md`. No match means new research; a match on the same question means follow-up mode; a match on a different question asks. Confirmation is a single `AskUserQuestion` (max 4 questions) covering only what is unresolved. If the invocation already pins down question, inputs, and destination, the prompt is skipped and the skill states what it inferred.

### 3. Research Agent

Spawns one sub-agent per `references/research-agent.md`. It writes `<tmp>/research-<slug>-findings.md` (slug-namespaced so concurrent runs never collide; `<tmp>` is the session scratchpad when available, else `/tmp`). The skill verifies a `## Load-Bearing Claims` section exists -- that section is the red-team's target. Missing file or section stops the run.

### 4. Red-Team Agent

Runs only after the research agent has finished writing -- agents are sequential, never concurrent. Reads the findings and the same input files, so it can check whether claims attributed to prior work are actually supported by that work. Writes `<tmp>/research-<slug>-redteam.md`.

### 5. Assemble the Artifact

Fills Question, Inputs, and Available Tooling from Step 1; Methodology and Findings from the research agent; Red-Team Assessment verbatim from the red-team agent. Writes the Recommendation: the pick, why it beats the runners-up, which red-team concerns survived, and what would change the call. Sets `## Status` to `open`, then deletes both temp files.

### 6. Follow-Up Mode

Re-runs both agents with the follow-up question and the existing artifact added to the inputs. Appends a dated entry to `## Follow-Up Log`; the original findings, red-team assessment, recommendation, and prior follow-ups are never modified. Afterwards offers Resolved, Follow-up, or Done. The skill never resolves an artifact on its own -- "settled" is a judgment about the user's confidence.

### 7. Completion Report

Reports artifact path, the recommendation in one or two lines, red-team concerns that survived, and follow-up count. Suggests next steps without invoking anything (no auto-dispatch).

## Artifacts

| Artifact | Path | Created By |
|----------|------|------------|
| Research artifact | Directory input: `<dir>/RESEARCH-<slug>.md`; file input only: `<parent of first file>/RESEARCH-<slug>.md`; free text only: `docs/_working/<slug>/RESEARCH-<slug>.md` | /research (new run or follow-up append) |

An explicit destination in the invocation always wins. Writing next to the prior work keeps problem statement, options survey, and adversarial read in one place.

The artifact has nine sections: Question, Inputs, Available Tooling, Methodology, Findings, Red-Team Assessment, Recommendation, Status, Follow-Up Log. Status is `open`, `resolved (YYYY-MM-DD)`, or `open (unvalidated)` when the red-team pass did not run.

## Error Handling

- **Input path does not exist:** Reports the exact path and asks whether to proceed on free text or correct it.
- **Research agent fails or writes nothing:** Stops. The red-team is not run against a missing or truncated file.
- **Red-team agent fails:** Offers a retry. If declined, writes the artifact stating plainly that no red-team pass was performed, with Status `open (unvalidated)`.
- **Artifact write fails:** Prints the assembled artifact so the work is not lost.
- **Interrupted session:** Re-invoking on the same input detects the artifact and offers follow-up mode.

## Skill Files

```
skills/research/
+-- SKILL.md                              # Flow controller (7 steps + error handling)
+-- references/
    +-- input-resolution.md               # Argument parsing, read budget, artifact path and slug rules
    +-- research-agent.md                 # Research sub-agent prompt and methodology spec
    +-- redteam-agent.md                  # Red-team sub-agent prompt and challenge spec
    +-- artifact-format.md                # Artifact template, Recommendation rules, follow-up entry format
```

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `/spike` | Gated sibling: same agent pair, but writes under `.project/{slug}/` and tracks state in `progress.txt` |
| `/red-team` | Reviews an existing artifact through parallel adversarial lenses; `/research` investigates a question |
| `/create-spec` | Run `/research` first when a spec depends on an unanswered technical question |
