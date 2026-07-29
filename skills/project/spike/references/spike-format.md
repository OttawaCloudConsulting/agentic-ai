# Spike Artifact Format

Defines the structure of spike artifacts produced at `.project/{project-slug}/docs/spikes/<topic>.md`. All spike artifacts use the same fixed section structure (D-09). The Red-Team Assessment is an EQUAL PEER section at the same level as Findings -- the two perspectives are never merged or suppressed (D-10). This ensures users see both the research and its independent critique as first-class information.

## Topic Slug Generation

Convert the spike topic to a filename-safe slug:

1. Convert to lowercase
2. Replace spaces with hyphens
3. Strip special characters (keep alphanumeric and hyphens only)
4. Trim leading and trailing hyphens
5. Collapse consecutive hyphens into a single hyphen

**Examples:**

| Topic | Slug | File Path |
|-------|------|-----------|
| WebSocket Auth Compatibility | websocket-auth-compatibility | .project/{project-slug}/docs/spikes/websocket-auth-compatibility.md |
| SQLite to Postgres Migration | sqlite-to-postgres-migration | .project/{project-slug}/docs/spikes/sqlite-to-postgres-migration.md |
| React 19 vs Svelte 5 | react-19-vs-svelte-5 | .project/{project-slug}/docs/spikes/react-19-vs-svelte-5.md |

This is consistent with milestone and feature slug patterns used elsewhere in the project.

## New Spike Template

The exact markdown template for a new spike artifact. All 8 sections are required:

```markdown
# Spike: <Topic Name>

## Question
<The specific technical question or hypothesis provided by the user>

## Available Tooling
<The tools/libraries/approaches the user listed for evaluation>

## Methodology
<What the research agent investigated and how -- methodology from research findings>

## Findings
<Research agent's discoveries, organized by sub-question or theme -- from ${TMPDIR:-/tmp}/spike-<slug>-research-findings.md>

## Red-Team Assessment
<Red-team agent's critique -- from ${TMPDIR:-/tmp}/spike-<slug>-redteam-findings.md. This is an EQUAL PEER section to Findings. Do not merge, summarize, or suppress any red-team concerns.>

## Recommendation
<Clear pick with rationale. States the recommended approach, why it is recommended, what risks remain after red-team review, and conditions under which the recommendation should be revisited.>

## Status
open

## Follow-Up Log
(no follow-ups yet)
```

**Section notes:**

- **Question** and **Available Tooling** are transcribed verbatim from user input (SPIKE-01).
- **Methodology** and **Findings** are populated from `${TMPDIR:-/tmp}/spike-<slug>-research-findings.md`.
- **Red-Team Assessment** is populated from `${TMPDIR:-/tmp}/spike-<slug>-redteam-findings.md`. Per D-10, this section is never edited, merged into Findings, or summarized. It stands as the red-team agent's independent output.
- **Recommendation** is synthesized by the parent SKILL.md after reading both agent outputs. Per D-11, it contains a clear pick with rationale, remaining risks, and revisitation conditions.
- **Status** starts as `open` for all new spikes.
- **Follow-Up Log** starts with the placeholder `(no follow-ups yet)`.

## Follow-Up Log Entry Format

Per D-08 and D-12, each follow-up appends a dated entry with full findings and red-team assessment. Follow-up entries preserve the complete audit trail -- original content is never modified.

Entry format:

```markdown
### Follow-Up: YYYY-MM-DD -- <Follow-up question>

#### Findings
<New research findings for this follow-up question>

#### Red-Team Assessment
<New red-team critique for this follow-up's findings>

#### Updated Recommendation
<Whether the original recommendation changes based on new information, and how>
```

**Append behavior:**

- If `(no follow-ups yet)` placeholder is present, replace it with the first follow-up entry.
- If previous follow-up entries exist, append the new entry after the last one.
- Never overwrite or modify existing follow-up entries.
- Never overwrite the original Findings, Red-Team Assessment, or Recommendation sections.

The follow-up's research and red-team agents run the same full flow as the initial spike -- the follow-up question is treated as a new research question with the existing spike as additional context.

## Assembly Instructions

How the parent SKILL.md assembles the final spike artifact from agent outputs:

1. **Create `.project/{project-slug}/docs/spikes/` directory** if it does not exist: `mkdir -p .project/{project-slug}/docs/spikes`

2. **Read `${TMPDIR:-/tmp}/spike-<slug>-research-findings.md`** for:
   - Methodology section content (from the research agent's Methodology section)
   - Findings section content (from the research agent's Findings Summary and Per-Tool Analysis)

3. **Read `${TMPDIR:-/tmp}/spike-<slug>-redteam-findings.md`** for:
   - Red-Team Assessment section content (use the full red-team output -- do not summarize or filter)

4. **Write the Recommendation section** by synthesizing both agent outputs:
   - State the recommended approach (the clear pick per D-11)
   - Incorporate red-team feedback -- acknowledge valid concerns and explain how they affect the recommendation
   - Note remaining risks that were not resolved by the red-team review
   - State conditions under which the recommendation should be revisited

5. **Set Status** to `open`

6. **Set Follow-Up Log** to `(no follow-ups yet)`

7. **Write the complete artifact** to `.project/{project-slug}/docs/spikes/<topic-slug>.md` using the New Spike Template

8. **Clean up temp files:** Remove `${TMPDIR:-/tmp}/spike-<slug>-research-findings.md` and `${TMPDIR:-/tmp}/spike-<slug>-redteam-findings.md`

## Resolution

Per D-07 and SPIKE-06, when the user signals that a spike is resolved:

1. **Update the spike artifact:** Change `## Status` from `open` to `resolved`

2. **Update progress.txt:** Change the spike entry from:

   ```
   [ ] Spike Name  .project/{project-slug}/docs/spikes/<topic>.md
   ```

   to:

   ```
   [x] Spike Name  .project/{project-slug}/docs/spikes/<topic>.md  Resolved: YYYY-MM-DD
   ```

   where `YYYY-MM-DD` is the current date.

3. Resolution is a user-initiated action -- the skill never auto-resolves a spike. After each follow-up, the skill offers the user an option to resolve (D-08).
