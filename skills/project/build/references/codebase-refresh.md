# Codebase Assessment Refresh Specification

Incremental refresh of `docs/codebase-assessment.md` before feature
implementation begins. An executor reading only this file can run the complete
refresh flow.

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
git log -1 --format="%ai" -- docs/codebase-assessment.md
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

## Sub-Agent Refresh (BUILD-02)

When files have changed, spawn a sub-agent using the `Agent` tool to perform the
incremental update. The sub-agent runs in its own context, keeping the parent
skill's context window clean for the build loop.

### Sub-Agent Instructions

Provide the sub-agent with:

1. The list of changed files (from the git log output above)
2. The feature name being built (for context)

Instruct the sub-agent to:

1. **Read `docs/codebase-assessment.md`** -- the current assessment content.

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
   - **Patterns to Deviate From** -- update if new anti-patterns were introduced
     or existing ones resolved.

4. **Preserve all existing assessment content** that remains accurate. The
   sub-agent updates sections, not rewrites the file. Sections unaffected by
   the changes should be left untouched.

5. **Write the updated assessment** back to `docs/codebase-assessment.md` using
   the Write tool.

### Sub-Agent Tool Access

The sub-agent uses: `Read`, `Write`, `Bash` (for `ls`, `git` commands), and
`Glob` tools.

## Standalone Commit (D-07)

After the sub-agent completes, commit the updated assessment separately from
any implementation commits:

```
docs(assessment): refresh codebase assessment for <feature-name>
```

This commit is made before loading the feature plan or writing any
implementation code. It provides a clean separation between "understood the
codebase" and "started building."

## Edge Cases

### Assessment File Does Not Exist

If `docs/codebase-assessment.md` does not exist on disk:

> "No codebase assessment found. Run /define to create one."

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
