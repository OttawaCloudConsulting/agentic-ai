# Codebase Assessment Refresh Specification

Incremental refresh of `.project/<slug>/docs/codebase-assessment.md` before feature
implementation begins. An executor reading only this file can run the complete
refresh flow. `<slug>` is the value derived from the `# Project-ID:` header in
`progress.txt` (established in Step 1 of `SKILL.md`).

## Timing (D-06, D-07)

This refresh runs BEFORE reading the feature plan. The execution order is:

1. Refresh codebase assessment (this spec)
2. Commit the refreshed assessment (standalone commit)
3. Load the feature plan and begin the build loop

This ordering ensures implementation decisions are grounded in the current
codebase state rather than a stale assessment.

## Incremental Refresh Strategy (D-05, BUILD-02)

### Detect Last Assessment Date

Find when the assessment was last updated:

```bash
git log -1 --format="%ai" -- .project/<slug>/docs/codebase-assessment.md
```

This returns the date of the most recent commit that modified the assessment
file.

**If no commit found** (first `/build` invocation after `/define`, or the
assessment was written but never committed): fall back to scanning commits from
the last 7 days:

```bash
git log --since="7 days ago" --name-only --format="" | sort -u
```

### Find Changed Files

Using the last assessment date, find all files that changed since then:

```bash
git log --since="<last-assessment-date>" --name-only --format="" | sort -u
```

This produces a deduplicated list of file paths that were modified, added, or
deleted since the last assessment update.

### Skip If Current

If no files have changed since the last assessment:

> "Codebase assessment is current (no changes since \<date\>)."

Skip the refresh entirely. Do not spawn a sub-agent. Do not create a commit.
Proceed directly to loading the feature plan.

## Engine Marker Lookup (GEM-08)

When files have changed, read the engine marker from the assessment front matter
before spawning any sub-agent. Read the file fresh from disk each refresh (STATE-03):

```bash
grep -m1 '<!-- scan-engine:' .project/<slug>/docs/codebase-assessment.md
```

Extract the value: `gemini` or `claude`. If the marker is absent or unreadable,
default to `claude`.

If the user explicitly requests a different engine, update the marker on the first
line of `.project/<slug>/docs/codebase-assessment.md` and use the new value.

**`claude` (or marker absent):** Proceed to [Claude Sub-Agent Refresh](#claude-sub-agent-refresh) below.

**`gemini`:** Proceed to [Gemini Delta Scan](#gemini-delta-scan-gem-04) below.
On any failure, fall back silently to the Claude sub-agent. Never re-prompt —
the persisted marker is the engine choice.

## Gemini Delta Scan (GEM-04)

When the engine marker is `gemini` and files have changed, run an incremental
delta scan via Gemini. On any failure, fall back silently to
[Claude Sub-Agent Refresh](#claude-sub-agent-refresh). Never re-prompt — the
persisted marker is the engine choice.

### Optional Liveness Probe (GEM-05)

> **Disabled by default.** Failure is detected from the real delta scan call.
> Enable only when `-m <model-id>` is pinned.

When a model is pinned, the probe can optionally run before the delta scan:

```bash
gemini -m <model-id> -p "ok" --approval-mode plan --skip-trust -o json 2>/dev/null \
  | jq -e '.response' >/dev/null
```

**Probe failure:** Fall back silently to
[Claude Sub-Agent Refresh](#claude-sub-agent-refresh).

### Prepare the Delta Prompt

Collect two inputs:

1. **Changed files list** — the deduplicated paths from the git log above (one
   path per line).
2. **Current assessment content** — the full text of
   `.project/<slug>/docs/codebase-assessment.md`.

Construct the prompt by substituting both inputs into the template below:

```
You are performing an incremental update to a codebase assessment.

CHANGED FILES (since last assessment):
<changed-files-list — one path per line>

CURRENT ASSESSMENT:
<full text of codebase-assessment.md>

Instructions:
- Read ONLY the files listed in CHANGED FILES above. Do NOT perform a full
  codebase re-scan.
- Emit ONLY the delta: for each assessment section that the changed files
  affect, output the complete updated section content under its exact heading.
- Do NOT output sections that require no changes.
- Use ONLY the following exact section headings (byte-for-byte, including case):
    ## Project Overview
    ## File Organization
    ## Detected Patterns
    ## Dependency Graph
    ## Assumptions
    ## Patterns That May Need Change
    ## Open Questions
    ## Recent Changes
- `## Recent Changes` MUST appear in your output — changed files always affect
  this section. If you cannot produce it, output nothing at all.
- For `## Recent Changes`: add entries for the changed files, preserving prior
  entries that remain relevant.
- Cite file paths, line counts, and dependency versions. No vague statements.
- Return raw markdown only. Start with a valid `## ` heading from the list
  above. Do not wrap in code fences. Do not include preamble, explanation,
  summary, or postamble. Every top-level `## ` heading must be one of the
  headings listed above and nothing else.
- Output findings only — do not write files. You are read-only.
```

### Invocation

Run from the project root. Capture raw output and the exit code in separate steps to
prevent pipeline exit-code masking:

```bash
GEMINI_RAW=$(gemini -p "<delta-prompt>" --approval-mode plan --skip-trust -o json 2>/dev/null)
GEMINI_EXIT=$?
DELTA_FINDINGS=$(printf '%s' "$GEMINI_RAW" | jq -r '.response' 2>/dev/null)
```

When `-m <model-id>` is pinned, add it immediately after `gemini`:

```bash
GEMINI_RAW=$(gemini -m <model-id> -p "<delta-prompt>" --approval-mode plan --skip-trust -o json 2>/dev/null)
```

Capture `$DELTA_FINDINGS` as `<delta-findings>`. Check `$GEMINI_EXIT` and `$DELTA_FINDINGS` before proceeding (see Failure Conditions below).

### Failure Conditions → Fallback

Fall back silently to [Claude Sub-Agent Refresh](#claude-sub-agent-refresh) if
any of:

- `$GEMINI_EXIT` is non-zero (check before parsing — do not rely on the pipeline's `$?`).
- Gemini command times out or is interrupted.
- `$GEMINI_RAW` is empty.
- `jq` fails to parse `.response` from stdout (`$DELTA_FINDINGS` is empty or null).
- `$DELTA_FINDINGS` is empty or whitespace-only.
- `$DELTA_FINDINGS` contains none of the expected section headings.
- `## Recent Changes` is absent from the delta.
- Any top-level `## ` heading in the delta is not one of the expected headings
  (unrecognized or wrong case).

### Apply Delta

When `<delta-findings>` is valid, Claude (the parent skill, not a sub-agent)
applies the delta directly:

1. Read `.project/<slug>/docs/codebase-assessment.md` (current content).
2. For each top-level `## ` heading in `<delta-findings>` (matched
   byte-for-byte, including case and the `## ` prefix):
   - Locate the matching heading in the current assessment.
   - If the heading is not found in the current assessment, fall back silently
     to [Claude Sub-Agent Refresh](#claude-sub-agent-refresh) and abort the
     delta apply entirely.
   - A section spans from its `## ` heading up to (but not including) the next
     top-level `## ` heading or EOF. Nested `### ` and deeper headings are
     part of that section.
   - Replace the entire section (heading + content) with the corresponding
     section from `<delta-findings>`.
3. Sections absent from `<delta-findings>` are left untouched.
4. Write the updated assessment back to
   `.project/<slug>/docs/codebase-assessment.md`.

The engine marker in the front matter is preserved unchanged.

Proceed to [Standalone Commit](#standalone-commit-d-07) after the delta is
applied.

## Claude Sub-Agent Refresh (BUILD-02)

When files have changed and the engine is `claude` (or Gemini is absent or
failed), spawn a sub-agent using the `Agent` tool to perform the incremental
update. The sub-agent runs in its own context, keeping the parent skill's
context window clean for the build loop.

### Sub-Agent Instructions

Provide the sub-agent with:

1. The list of changed files (from the git log output above)
2. The feature name being built (for context)
3. The value of `<slug>` (the Project-ID from `progress.txt`)

Instruct the sub-agent to:

1. **Read `.project/<slug>/docs/codebase-assessment.md`** -- the current assessment content.

2. **Read only the changed/new files** identified above. Do NOT perform a full
   codebase re-scan. The goal is incremental update, not re-assessment.

3. **Update the assessment sections as needed:**
   - **Recent Changes** -- add new entries for the changes found. Preserve
     existing entries that are still relevant.
   - **File Organization** -- update if files were added, moved, or deleted.
   - **Detected Patterns** -- update if new patterns are introduced or existing
     patterns changed.
   - **Dependency Graph** -- update if dependencies were added, removed, or
     changed.
   - **Assumptions** -- remove any assumptions invalidated by the changes.
   - **Patterns That May Need Change** -- update if new anti-patterns were
     introduced or existing ones resolved.

4. **Preserve all existing assessment content** that remains accurate. The
   sub-agent updates sections, not rewrites the file. Sections unaffected by
   the changes should be left untouched.

5. **Write the updated assessment** back to `.project/<slug>/docs/codebase-assessment.md`
   using the Write tool.

### Sub-Agent Tool Access

The sub-agent uses: `Read`, `Write`, `Bash` (for `ls`, `git` commands), and
`Glob` tools.

## Engine Report

After the refresh completes (either engine), output one line. Do not prompt:

- Gemini delta applied (no fallback): `Scan via Gemini CLI`
- Claude sub-agent ran (or Gemini fell back): `Scan via Claude sub-agent`

**Marker semantics on fallback:** The engine marker in the assessment front matter is
**not updated** when Gemini falls back to Claude during a refresh. The marker persists
the user's engine preference from Gate 0 so the next `/build` retries Gemini. The
engine report line always reflects the actual engine used for the current refresh,
regardless of the marker value.

## Standalone Commit (D-07)

After the Gemini delta is applied or the Claude sub-agent completes, commit the updated assessment separately from
any implementation commits:

```
docs(assessment): refresh codebase assessment for <feature-name>
```

The commit covers `.project/<slug>/docs/codebase-assessment.md`.

This commit is made before loading the feature plan or writing any
implementation code. It provides a clean separation between "understood the
codebase" and "started building."

## Edge Cases

### Assessment File Does Not Exist

If `.project/<slug>/docs/codebase-assessment.md` does not exist on disk:

> "No codebase assessment found at `.project/<slug>/docs/codebase-assessment.md`. Run /define to create one."

This is a **warning, not a blocker**. `/build` can proceed without an
assessment, but the user should know their codebase assessment is missing. Skip
the refresh and proceed to loading the feature plan.

### Assessment File Exists But Was Never Committed

If the file exists on disk but `git log` returns no results (the file was
written in a previous session but never committed):

Fall back to the 7-day scan window:

```bash
git log --since="7 days ago" --name-only --format="" | sort -u
```

Use this file list for the sub-agent refresh. The assessment will be committed
as part of the standalone commit, establishing a commit history baseline for
future refreshes.

### No Changed Files in Scan Window

If the 7-day fallback scan also returns no changed files, the codebase has been
stable. Skip the refresh with the message:

> "Codebase assessment is current (no changes in the last 7 days)."

### Very Large Change Sets

If the changed file list exceeds 50 files, the assessment may need a more
substantial update. The sub-agent should still read only the changed files (not
the full codebase), but it may need to update more sections. No special handling
is required -- the sub-agent prompt already covers all assessment sections.
