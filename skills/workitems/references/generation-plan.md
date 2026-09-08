# Generation Plan: IDs, Layout, and Parallel Fan-Out

Read this before generating more than one document. It defines the identifier
scheme, the output layout, and the protocol for delegating milestone subtrees to
parallel sub-agents.

## Contents

- [Why the plan comes first](#why-the-plan-comes-first)
- [Identifier scheme](#identifier-scheme)
- [Output layout](#output-layout)
- [Phase order](#phase-order)
- [Fan-out granularity](#fan-out-granularity)
- [Sub-agent brief](#sub-agent-brief)
- [When not to fan out](#when-not-to-fan-out)
- [Verification](#verification)
- [Existing files](#existing-files)

## Why the plan comes first

Every document in the set names its parent by ID and by relative path. A Story
document written by one agent cites a Feature document written by that same agent,
and a Feature document cites an Epic document written before either. If identifiers
are chosen while drafting, parallel agents produce dangling references and the set
does not link up.

The fix is that identifiers and paths are computed from the source artifacts before
any drafting starts, and handed to every agent as fixed input. No agent invents an
ID, a filename, or a parent reference.

## Identifier scheme

Derived from source numbering. Deterministic, and stable across regeneration.

| Level | ID | Derived from |
|-------|-----|-------------|
| Epic | `EPIC-01` | One per project. The project slug in `.project/<slug>/` is the namespace |
| Feature | `FEAT-<NN>` | The milestone number: `milestones/03-deployment-configuration/` becomes `FEAT-03` |
| Story | `STORY-<NN>.<N>` | The section heading: `### Feature 03.2: Values Schema` becomes `STORY-03.2` |

Slugs for filenames:

- Epic slug: the project slug from `# Project-ID:` in `progress.txt`.
- Feature slug: the milestone directory name with its numeric prefix removed.
  `01-secret-delivery-chart` becomes `secret-delivery-chart`.
- Story slug: the section title, lowercased, non-alphanumerics collapsed to `-`.
  `### Feature 01.1: SecretProviderClass Template` becomes
  `secretproviderclass-template`.

If a source section is unnumbered, or two sections collide after slugging, stop and
report rather than guessing. A silently renumbered Story breaks the parent link in
the Feature document that cites it.

## Output layout

```
.project/<slug>/workitems/
  epic-01-<project-slug>.md
  features/
    feature-01-<milestone-slug>.md
    feature-02-<milestone-slug>.md
  stories/
    story-01-1-<story-slug>.md
    story-01-2-<story-slug>.md
    story-02-1-<story-slug>.md
```

Relative paths used in `Traceability` sections:

| From | To | Path |
|------|-----|------|
| Epic | Feature | `features/feature-NN-slug.md` |
| Feature | Epic | `../epic-01-slug.md` |
| Feature | Story | `../stories/story-NN-N-slug.md` |
| Story | Feature | `../features/feature-NN-slug.md` |
| Story | Epic | `../epic-01-slug.md` |

## Phase order

**Phase 1, sequential, main thread.** Read `progress.txt`, `prd.md`, the
architecture document, and every milestone `README.md`. Build the plan table: every
work item, its ID, its output path, its parent ID, and its source artifact path.
Present the table to the user for confirmation before writing anything.

**Phase 2, sequential, main thread.** Write the Epic document. It comes first
because every Feature document cites it, and because writing it forces the
project-level scope and success measures to be settled before they are referenced
five times. The Child Features table is filled from the plan, not from the Feature
documents, so it does not need them to exist.

**Phase 3, parallel, one sub-agent per milestone.** Each agent writes one Feature
document and all of that milestone's Story documents. See the brief below.

**Phase 4, sequential, main thread.** Verification. See below.

Phases 1 and 2 are not optional preamble. They are what makes phase 3 safe to
parallelize.

## Fan-out granularity

One agent per **milestone subtree**, not one per document.

A Feature document's `Child Stories` table must agree exactly with the Story
documents that milestone produces: same IDs, same titles, same sizes, same
dependency arrows. One agent holding the whole subtree keeps them consistent
because it writes both sides. Splitting Feature and Story generation across agents
means the child table and the Story documents are two independent guesses at the
same decomposition, and they diverge.

The secondary reason is input economy. Every Story in a milestone derives from the
same `README.md`. Per-document fan-out re-reads that file once per Story.

Use `general-purpose` as the agent type. These agents write files, so a read-only
agent type will not work.

## Sub-agent brief

Each agent gets exactly this, filled in. Nothing is left for the agent to decide
about naming, parentage, or layout.

```
Write the Feature and Story work item documents for Milestone <NN>: <name>.

TEMPLATES (read both, follow section order and heading levels exactly):
- Feature: <abs-path>/assets/feature-template.md
- Story:   <abs-path>/assets/story-template.md

FIELD MAPPING (read when a field needs tracker-specific values):
- <abs-path>/references/field-mapping.md

SOURCE ARTIFACTS (read all):
- <abs>/.project/<slug>/milestones/<NN>-<name>/README.md   -- primary source
- <abs>/.project/<slug>/docs/ARCHITECTURE_AND_DESIGN.md    -- decisions, tradeoffs
- <abs>/prd.md                                             -- goals and scope
- <abs>/.project/<slug>/workitems/epic-01-<slug>.md        -- parent Epic, already written
- <abs>/.project/<slug>/milestones/<NN>-<name>/plans/*.md  -- if present

WRITE EXACTLY THESE FILES. Do not create, rename, or omit any:
- FEAT-<NN> -> <abs>/.project/<slug>/workitems/features/feature-<NN>-<slug>.md
- STORY-<NN>.1 -> <abs>/.project/<slug>/workitems/stories/story-<NN>-1-<slug>.md
  source section: `### Feature <NN>.1: <title>`
- STORY-<NN>.2 -> ... (one line per Story, with its source section heading)

FIXED REFERENCES. Use these verbatim, do not derive your own:
- Parent Epic: EPIC-01 -- <epic-title>, path from a Feature doc: ../epic-01-<slug>.md
- Feature parent for every Story: FEAT-<NN> -- <feature-title>
- Path from a Story doc to the Feature doc: ../features/feature-<NN>-<slug>.md

RULES:
- The Feature document's Child Stories table lists every Story above, with the
  same IDs and titles. It is the index for the Story documents you write.
- Do not invent field values. Anything not established by a source artifact is
  `TBD -- owner: <name>` or the section is marked not applicable with a reason.
- Acceptance criteria must be verifiable: name the check and the evidence that
  settles it. The milestone README's existing acceptance criteria are the primary
  input for Story-level criteria.
- Feature-level acceptance criteria are not a concatenation of the Stories. Test:
  could every Story close and this criterion still be unmet? If not, it belongs on
  a Story.
- Cite sources as `path:line`.
- No em-dashes and no emojis. Use `--`.
- Dates are absolute (`2026-07-30`), never relative.
- Leave no `{{...}}` placeholders in the output.

RETURN a receipt only, no prose:
FILES: <path> (<n> TBD fields)   one line per file
OPEN QUESTIONS: <count> -- <one line each>
SECTIONS OMITTED: <file: section -- reason>, or none
CONFLICTS: anything in the source that contradicts another source, or none
```

The `CONFLICTS` line is the reason the receipt exists. An agent that finds the
milestone README contradicting the architecture document should surface it, not
silently pick one, and the main thread is the only place that can see two agents
reporting the same contradiction.

## When not to fan out

Run inline on the main thread when:

- The target is a single milestone subtree. One agent is not parallelism, it is
  overhead plus a context handoff.
- The target is the Epic alone, or a single Story.
- The source is an interview rather than project artifacts. The user is answering
  questions in the main thread; an agent cannot ask them.
- Fewer than two milestones have documents to generate.

## Verification

After the agents return, the main thread has not seen a single write. Check, do not
assume:

1. **Every planned file exists.** Compare the plan table against the directory.
2. **No leaked placeholders.** `grep -l '{{' ` across the output directory returns
   nothing.
3. **Parent references resolve.** Every relative path in a `Traceability` section
   points at a file that exists.
4. **Child tables match.** Every `STORY-NN.N` in a Feature's `Child Stories` table
   has a Story document, and every Story document's parent is that Feature.
5. **Section parity.** Each generated document has the same `##` headings, in the
   same order, as its template.

A failure in 1, 3, or 4 is a broken set and gets fixed before reporting. A failure
in 2 or 5 is a single document to regenerate.

## Existing files

Regenerating over a document set that has been hand-edited destroys the edits.
Before phase 2, check whether the output directory already holds documents.

If it does, list what would be overwritten and ask. Offer: overwrite all, skip
existing and write only what is missing, or write to a new directory. Do not
default to overwrite. A work item document accumulates decisions after generation,
and those decisions live nowhere else.
