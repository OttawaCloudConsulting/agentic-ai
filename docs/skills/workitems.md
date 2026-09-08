# Work Items

**Source:** `skills/workitems/`
**Command:** `/workitems`
**Activation:** Manual — invoked via slash command or trigger phrase matching (writing a feature, epic, or story; filing or drafting work items; a Jira ticket or issue; an Azure DevOps or ADO work item; a backlog or backlog item; an epic breakdown; turning a plan, PRD, or milestone set into something a delivery team can pick up — even without the words "Epic", "Feature", or "Story")

## Description

Produces a linked three-level work item document set — Epic, Feature, Story — from the templates in `assets/`. Maps a project to an Epic, each milestone to a Feature, and each `### Feature NN.N` section inside a milestone README to a Story. Every document carries a `Traceability` section naming its parent by ID and relative path and citing the source artifact it came from.

Output is markdown, not a tracker import. It's the authored source: field tables tell someone what to set in Jira or Azure DevOps, narrative sections are pasted or linked. `references/field-mapping.md` maps every canonical field to its ADO and Jira equivalent, including the hierarchy gap — Azure DevOps has a native Feature level, Jira does not.

Two failure modes the templates and workflow are built against: invented content (an unfounded `Business Value: 8` is worse than `TBD -- owner: <name>`, because a number from nowhere gets used by prioritization models as though it came from somewhere) and unverifiable acceptance criteria ("secrets are provisioned" cannot be judged true or false; "the six SecretProviderClass objects exist in the target namespace, confirmed by `kubectl get`" can).

## Usage

```
/workitems          # Epic, every Feature, every Story
/workitems epic      # Epic only
/workitems 03        # Feature 03 and its Stories
/workitems 03.2      # Story 03.2 only
```

## Workflow

### Step 1 — Determine scope

The argument sets scope (table above). Then locates the source: if `progress.txt` exists in the working directory, parses `# Project-ID: <slug>` to find `.project/<slug>/`, and reads `progress.txt` (milestone index, gate state), `prd.md` (goals and scope), `.project/<slug>/docs/ARCHITECTURE_AND_DESIGN.md` (decisions, tradeoffs), and each milestone `README.md` (Feature and Story source).

If those artifacts don't exist, or the user is describing something new, interviews instead — batched questions covering what's being delivered, how the work breaks down into Features, what's explicitly out of scope, how success will be known, target tracker, and known dependencies. Interview mode does not fan out; the user answers in the main thread.

### Step 2 — Build the generation plan

Reads `references/generation-plan.md` for the identifier scheme (`EPIC-01`, `FEAT-<NN>`, `STORY-<NN>.<N>`, all derived from source numbering, never invented), output layout, and fan-out protocol. Builds and presents the plan table — every work item, ID, output path, parent ID, source artifact — for user confirmation before writing anything. Checks the output directory for existing documents and asks before overwriting.

If a target tracker is named, reads `references/field-mapping.md` and surfaces the Jira Feature-level gap before generating a layer with nowhere to live.

### Step 3 — Write the Epic

Sequential, main thread, before any Feature or Story — every Feature document cites the Epic by ID and path, so it has to exist first. Its `Child Features` table is filled from the plan table, not from the Feature documents.

### Step 4 — Generate the milestone subtrees

Two or more milestones in scope: fans out one `general-purpose` sub-agent per milestone (not per document), launched in a single message. Each agent writes one Feature document and all of that milestone's Story documents from the brief in `references/generation-plan.md`, using fixed IDs, output paths, parent references, and source artifacts — no agent chooses a filename, ID, or parent.

One milestone in scope, Epic only, or a single Story: runs inline: one agent is overhead, not parallelism.

### Step 5 — Verify

After a fan-out the main thread hasn't seen a single write. Checks: every planned file exists; `grep -rl '{{'` across the output directory returns nothing; every relative path in a `Traceability` section resolves; every `STORY-NN.N` in a Feature's `Child Stories` table has a matching Story document with that Feature as parent; each document's `##` headings match its template in order. A failure in file existence, path resolution, or child-table agreement is a broken set, fixed before reporting; a placeholder or heading-order failure is a single document regenerated.

### Step 6 — Report

Emits a fixed-format receipt: what was generated, where, source mode, fan-out mode, verification result, TBD field count, omitted sections, open questions, conflicts found, target tracker and any tracker-specific caveat. Then offers a revision pass — does not iterate unprompted.

## Output

| Output | Description |
|---|---|
| `.project/<slug>/workitems/epic-01-<project-slug>.md` | The Epic document |
| `.project/<slug>/workitems/features/feature-<NN>-<milestone-slug>.md` | One per milestone in scope |
| `.project/<slug>/workitems/stories/story-<NN>-<N>-<story-slug>.md` | One per `### Feature NN.N` section in scope |

## When to Use

- Turning an approved PRD, architecture document, and milestone set into a work item document set a delivery team can pick up without going back to the author
- Filing or drafting Epics, Features, Stories, or ADO/Jira-shaped work items from project artifacts or from a fresh interview
- Producing a document set that stays diffable and traceable — every document names its parent and source artifact

## When Not to Use

- To import directly into a tracker — this skill writes markdown source, not API calls; a human still creates the tracker items from it
- To regenerate over a hand-edited document set without checking first — Step 2 asks before overwriting because a work item document accumulates decisions after generation that live nowhere else
- To update `progress.txt`, `milestone-status.txt`, or any gate state — this skill only writes documents and does not invoke another skill

## Related Skills and Artifacts

- **`assets/epic-template.md`, `assets/feature-template.md`, `assets/story-template.md`** — the templates; the contract every generated document follows section-for-section.
- **`references/generation-plan.md`** — identifier scheme, output layout, phase order, the sub-agent brief, and the verification checks.
- **`references/field-mapping.md`** — canonical field to Azure DevOps and Jira mapping, including the Feature-level hierarchy gap in Jira.
- **[Milestone](milestone.md)** (`/milestone`) — produces the `milestones/*/README.md` files this skill reads as Feature and Story source.
- **[Design](design.md)** (`/design`) — produces `ARCHITECTURE_AND_DESIGN.md`, read for Technical Notes, Risks, and Constraints.
