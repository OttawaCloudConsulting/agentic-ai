# Artifact Format

The structure of the document `/research` produces, and how the skill
assembles it from the two agent outputs.

The artifact is the entire deliverable. Everything else — temp files, agent
transcripts — is scaffolding that gets thrown away. So the artifact has to
carry enough context that someone reading it in three months, with no memory
of the session, can tell what was asked, what was found, what was disputed,
and how much to trust the answer.

## Template

```markdown
# Research: <Topic Name>

## Question
<The question, verbatim as confirmed with the user.>

## Inputs
<Input files read, as repo-relative paths with a one-line note on what each
contributed. Write "(free text only — no input files)" when there were none.>

## Available Tooling
<Tools, libraries, or approaches evaluated. Write "(none specified)" when the
research was about approaches rather than a comparison. Mark anything you
inferred rather than were told.>

## Methodology
<From the research agent: sub-questions, evidence sought, sources consulted,
and what could not be checked.>

## Findings
<From the research agent: per-option analysis, comparison matrix, load-bearing
claims table, and findings summary.>

## Red-Team Assessment
<From the red-team agent, verbatim.>

## Recommendation
<Written by the skill. See below.>

## Status
open

## Follow-Up Log
(no follow-ups yet)
```

### Section notes

**Question** and **Available Tooling** are transcribed, not paraphrased. If
the user's phrasing was loose, that looseness is information about what they
actually wanted.

**Inputs** exists so a reader can tell inherited conclusions from fresh ones.
Prior work that was wrong explains a lot about a recommendation that aged
badly, and only this section makes that traceable.

**Red-Team Assessment** is reproduced whole. Do not merge it into Findings,
do not summarize it, do not soften a finding because you disagree. It is a
peer section, and the reader needs to see exactly where the two agents
diverged — that gap is often the most informative thing in the document. If
you think a red-team finding is wrong, argue with it in the Recommendation,
where your disagreement is visible as your own.

**Status** is `open`, `resolved (YYYY-MM-DD)`, or `open (unvalidated)` when
the red-team pass did not run.

## Writing the Recommendation

Neither agent produces this. The research agent argues one side, the
red-team agent attacks it, and the synthesis is the skill's own work — which
also makes it the section most likely to degrade into a summary of the two
above it. It should not summarize. It should decide.

Cover four things:

1. **The pick.** One option, named plainly. If the honest answer is
   conditional, state the condition as a decision the reader can actually
   make — "Option 3 if branch-push activation is required, Option 1 if a PR
   trigger is acceptable" is useful; "it depends on your needs" is not.
2. **Why it beats the runners-up.** Specifically the runners-up, not the
   options that were already ruled out. The reader's real question is why not
   the second-best thing.
3. **What survived the red-team.** Which concerns were resolved, which were
   not, and how the unresolved ones affect confidence. A recommendation that
   ignores a refuted load-bearing claim is not a recommendation.
4. **What would change your mind.** The condition under which this should be
   revisited: a version release, a failed proof-of-concept, a requirement
   that shifts. Research goes stale, and a recommendation that names its own
   expiry condition stays useful long after one that does not.

Where the red-team refuted a load-bearing claim, say so directly and follow
it through. Silently recommending the option whose foundation was just
knocked out is the specific failure this whole two-agent structure exists to
prevent.

## Follow-Up Log entry format

```markdown
### Follow-Up: YYYY-MM-DD -- <the follow-up question>

#### Findings
<Research agent output for this follow-up.>

#### Red-Team Assessment
<Red-team output for this follow-up.>

#### Updated Recommendation
<Whether the original recommendation changes, and how. State plainly when it
does not — "unchanged, and here is what the new evidence does to confidence"
is a real result.>
```

Append behavior:

- Replace `(no follow-ups yet)` with the first entry.
- Append later entries after the last one.
- Never modify an existing entry, the original Findings, the original
  Red-Team Assessment, or the original Recommendation.

The original recommendation stays in place even after a follow-up overturns
it. What was believed, and when, and on what evidence, is the record — and a
document that edits its own history to look consistently correct cannot be
used to tell whether its current answer is trustworthy either.

## Assembly

1. `mkdir -p` the artifact's parent directory.
2. Read `<tmp>/research-<slug>-findings.md` for Methodology and Findings.
3. Read `<tmp>/research-<slug>-redteam.md` for Red-Team Assessment, and
   carry it over whole.
4. Write the Recommendation per the four points above.
5. Set Status `open`, Follow-Up Log `(no follow-ups yet)`.
6. Write the artifact.
7. Delete both temp files.

## Resolution

Resolution is always the user's call — the skill never marks a question
settled on its own, because "settled" is a statement about the user's
confidence, not about how thorough the research looked.

When the user resolves it, change the Status line to
`resolved (YYYY-MM-DD)`. Nothing else in the artifact changes, and nothing
outside the artifact is touched.
