---
name: workitems
description: >
  Generates a linked Epic, Feature, and Story work item document set for Jira,
  Azure DevOps, or any tracker, in an Epic > Feature > Story > Task hierarchy.
  Maps a project to an Epic, each milestone to a Feature, and each milestone
  feature to a Story, with parent references and source-artifact traceability in
  every document. Use this whenever the user mentions writing a feature, epic, or
  story, filing or drafting work items, a Jira ticket or issue, an Azure DevOps or
  ADO work item, a backlog or backlog item, an epic breakdown, or asks to turn a
  plan, PRD, or milestone set into something a delivery team can pick up, even
  when they do not name a tracker or say the words "Epic", "Feature", or "Story".
---

# /workitems -- Epic, Feature, and Story Work Item Documents

Produces a linked three-level work item document set from the templates in
`assets/`. The templates are the contract: every document at a level has the same
sections in the same order, so a reader who knows one knows all of them, and so the
set stays diffable and reviewable over time.

The output is markdown. No tracker imports it directly. It is the authored source:
the field tables tell someone what to set, and the narrative sections are pasted or
linked. `references/field-mapping.md` maps every canonical field to its Azure
DevOps and Jira equivalent.

## Level mapping

Each level maps to one kind of project artifact. This mapping is what makes the set
traceable, and it is not negotiable per run.

| Level | Maps to | Source artifact |
|-------|---------|-----------------|
| Epic | The project | `prd.md`, `.project/<slug>/docs/ARCHITECTURE_AND_DESIGN.md`, `progress.txt` |
| Feature | A milestone | `.project/<slug>/milestones/<NN>-<name>/README.md` |
| Story | A `### Feature NN.N` section inside a milestone | that same README, one section |

Task level is not generated. Tasks appear as a checklist inside each Story
document, which is where they are decided during sprint planning.

Every document names its parent by ID and by relative path, and cites the source
artifact it came from. That is the `Traceability` section at the top of all three
templates, and it is filled first, not last.

## The bar these documents have to clear

A work item document exists so a delivery team can pick the work up without going
back to the author, and so someone reviewing it later can tell whether it was done.
Two failure modes destroy that, and both look fine at a glance:

**Invented content.** Filling `Business Value: 8` because the field was there is
worse than leaving it unknown, because a number that came from nowhere gets used by
prioritization models as though it came from somewhere. Anything not established by
a source artifact or by the user is written as `TBD -- owner: <name>` or omitted
with the section marked not applicable. Say what was not determined.

**Unverifiable acceptance criteria.** "Feature works correctly" cannot be judged
true or false, so it can never block a close. Each criterion names the thing checked
and the evidence that settles it. Prefer "the six SecretProviderClass objects exist
in the target namespace, confirmed by `kubectl get`" over "secrets are provisioned".
A criterion nobody can fail is not a criterion.

The rest of this skill is in service of those two.

## Step 1 -- Determine scope

The argument sets the scope. No argument means the whole set.

| Invocation | Generates |
|------------|-----------|
| `/workitems` | Epic, every Feature, every Story |
| `/workitems epic` | Epic only |
| `/workitems 03` | Feature 03 and its Stories |
| `/workitems 03.2` | Story 03.2 only |

Then find the source. If a `progress.txt` exists in the working directory, read it
and parse `# Project-ID: <slug>`. That gives `.project/<slug>/`. Read:

- `progress.txt` -- the milestone index with paths and feature counts, and gate
  state. This is the fastest way to enumerate the set.
- `prd.md` -- goals and scope. Commonly at the repository root, not under
  `.project/<slug>/`. Check both.
- `.project/<slug>/docs/ARCHITECTURE_AND_DESIGN.md` -- decisions, component
  inventory, tradeoffs. Feeds Technical Notes, Risks, and Constraints.
- `.project/<slug>/milestones/*/README.md` -- the Feature and Story source.
- `.project/<slug>/milestones/*/plans/*.md` -- if a plan exists for a target Story,
  it carries interface contracts and test commands that feed Test Notes.

If those artifacts do not exist, or the user is describing something new, interview
instead. Batch the questions. What is needed before a first draft is worth showing:

1. What is being delivered, and who it is for.
2. How the work breaks down. Without milestones there is no Feature layer, so ask
   what the major deliverables are and treat those as Features.
3. What is explicitly out of scope. Push on this one. It is the section authors skip
   and the section that prevents the most rework.
4. How anyone will know it worked. The measure, not the activity.
5. Target tracker and process template, if known.
6. Known dependencies, particularly on other teams.

Do not interview for fields the templates can carry as `TBD`. Dates, cost centers,
and flag names are cheap to add later and expensive to stall a draft over.

Interview mode does not fan out. The user is answering in the main thread and a
sub-agent cannot ask them.

## Step 2 -- Build the generation plan

Read `references/generation-plan.md`. It defines the identifier scheme, the output
layout, and the fan-out protocol.

Build the plan table before writing anything: every work item, its ID, its output
path, its parent ID, and its source artifact. IDs derive from source numbering,
never from invention: milestone `03` becomes `FEAT-03`, and `### Feature 03.2`
becomes `STORY-03.2`.

Present the table and confirm before proceeding. This is the only point where a
naming or scoping mistake is cheap to fix. After it, the plan is fixed input to
every agent.

Check the output directory for existing documents. If any target path already
exists, list what would be overwritten and ask before proceeding. Do not default to
overwrite: a work item document accumulates decisions after generation, and those
decisions live nowhere else.

Read `references/field-mapping.md` when the user names a target tracker. One thing
from that file changes what you tell the user and is worth raising here rather than
after generating: **Azure DevOps has a native Feature level; Jira does not.** Jira's
default hierarchy is Epic > Standard > Subtask. The Epic and the Stories land
natively, but the Feature layer needs an Advanced Roadmaps custom hierarchy level or
a renamed issue type. Surface this before generating a layer with nowhere to live.

## Step 3 -- Write the Epic

Sequential, on the main thread, before any Feature or Story.

Every Feature document cites the Epic by ID and path, so it has to exist. Writing it
first also forces the project-level scope and success measures to be settled before
they are referenced from five places.

Its `Child Features` table is filled from the plan table, not from the Feature
documents. It does not wait for them.

Guidance where the Epic template is easy to get wrong:

**Epic Hypothesis.** Business outcomes are what changes in the business or platform.
Leading indicators are observable before the Epic completes, which is the entire
point of naming them. If the Epic is purely architectural, set Value Area to
`Architectural` and write the hypothesis in terms of the capability it unblocks. Do
not invent an end user.

**MVP and Scope.** The MVP is the smallest increment that tests the hypothesis, and
its exit criteria decide persevere or pivot. An Epic whose MVP is "all of it" has no
MVP, and saying so is more useful than inventing a split.

**Sequencing.** Name what is parallelizable and what is strictly serial, and give
the constraint that forces the order. "Milestone 02 after 01" is a restatement;
"Milestone 02 needs the chart from 01 to exist before it can be referenced" is the
reason.

## Step 4 -- Generate the milestone subtrees

**Two or more milestones in scope: fan out.** One `general-purpose` sub-agent per
milestone, launched in a single message so they run concurrently. Each agent writes
one Feature document and all of that milestone's Story documents.

Per milestone and not per document, because a Feature's `Child Stories` table has to
agree exactly with the Story documents beneath it. One agent writing both sides
keeps them consistent. Split across agents, the table and the documents become two
independent guesses at the same decomposition.

Use the brief in `references/generation-plan.md` verbatim, filled in. It hands each
agent its fixed IDs, its exact output paths, its parent references, and its source
artifacts. No agent chooses a filename, an ID, or a parent.

**One milestone in scope, or Epic only, or a single Story: inline.** One agent is
not parallelism, it is overhead plus a context handoff.

Guidance where the Feature and Story templates are easy to get wrong:

**Feature acceptance criteria.** Feature-level, not a concatenation of the Stories.
The test: could every Story close and this criterion still be unmet? If not, it
belongs on a Story. Integration behavior, end-to-end outcomes, and measurable targets
belong here.

**Scope.** Out of scope carries more weight than in scope. Each exclusion says where
the work lands instead, or that it lands nowhere. "Not in this Feature" with no
destination is how work gets lost between Features.

**Child Stories.** Driven by the source sections, not by a target count. If a
milestone has two feature sections it gets two Stories. If a section is clearly two
Stories, say so in Open Questions rather than splitting it and breaking the ID
derivation.

**User Story.** The `As / I want / so that` form on infrastructure work often has a
system as the role, not a person. `As the Prefect worker` is a legitimate role. An
invented human persona is not.

**Dependencies.** Every row needs an owner and a needed-by date. A dependency with
neither is a note, not a dependency, and nobody will chase it. External dependencies
also set the `External Dependency` governance field.

**Non-Functional Requirements.** The `How it is verified` column is the point of the
table. A performance target with no verification method is a wish. Rows that
genuinely do not apply are marked `N/A` with a reason, not deleted, because a missing
Security row reads as an oversight and an `N/A -- no data leaves the cluster` reads
as a decision.

**Definition of Ready and Done.** The templates ship defaults. Replace the
`{{project-specific gate}}` lines with the team's real gates when they are known from
project artifacts or from the user; drop them when they are not.

**Open Questions.** Blocking questions are recorded, not resolved by guessing. This
section being empty on a first draft is unusual and worth questioning.

## Step 5 -- Verify

After a fan-out the main thread has not seen a single write. Check, do not assume.
The full check list is in `references/generation-plan.md`. In short:

1. Every planned file exists.
2. `grep -rl '{{' ` across the output directory returns nothing.
3. Every relative path in a `Traceability` section points at a file that exists.
4. Every `STORY-NN.N` in a Feature's `Child Stories` table has a Story document, and
   every Story document's parent is that Feature.
5. Each document's `##` headings match its template, in order.

A failure in 1, 3, or 4 is a broken set. Fix it before reporting. A failure in 2 or 5
is one document to regenerate.

## Step 6 -- Report

```
WORK ITEM SET: <project or milestone name>
WRITTEN TO: .project/<slug>/workitems/

GENERATED: 1 Epic, <n> Features, <n> Stories
SOURCE: <project artifacts at <path> | interview | both>
MODE: <parallel, N agents | inline>

VERIFICATION: <files, placeholders, parent refs, child tables, section parity -- pass or the failures>
TBD FIELDS: <count across the set>
SECTIONS OMITTED: <none, or file: section and reason>
OPEN QUESTIONS: <count> -- <highest-impact one>
CONFLICTS FOUND: <none, or what contradicts what>
TARGET TRACKER: <name, or not specified>
<tracker-specific caveat if any, e.g. the Jira Feature-level note>
```

Then offer a revision pass. Do not iterate unprompted.

## Conventions

- No em-dashes and no emojis in generated documents. Use `--`.
- Dates are absolute (`2026-07-30`), never relative (`next sprint`).
- Any claim traceable to a source cites it as `path:line` or a link. A number
  without a source is a liability in a document that feeds prioritization.
- Preserve each template's section order and heading levels. Consistency across
  documents is the reason the templates exist.
- IDs and paths come from the plan table. Nothing downstream of Step 2 invents one.
- This skill writes documents. It does not update `progress.txt`,
  `milestone-status.txt`, or any gate state, and it does not invoke another skill.

## Related

- `assets/epic-template.md`, `assets/feature-template.md`,
  `assets/story-template.md` -- the templates. Edit one to change the shape of every
  future document at that level; do not vary the shape per document.
- `references/generation-plan.md` -- identifier scheme, output layout, phase order,
  the sub-agent brief, and the verification checks.
- `references/field-mapping.md` -- canonical field to ADO and Jira mapping, fields
  that differ by level, state categories, link types, and where the narrative body
  goes in a tracker.
