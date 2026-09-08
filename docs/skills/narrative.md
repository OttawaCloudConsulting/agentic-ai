# Narrative

**Source:** `skills/narrative/`
**Command:** `/narrative`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "write the narrative", "write this up", "narrative for today", "record what we did", "document this session")

## Description

Writes the session narrative: the prose record of what a work session did, what it found, and what it did not prove, filed into `DailyReports/narratives/YYYYMMDD-slug.md`. Not a summary and not a changelog — a short argued account where the title is the finding, every section earns its place, and wrong predictions and declined review findings are recorded rather than dropped. Also used to reconstruct a narrative for a past session from its artifacts when the working session is not in context.

This skill does not call the `advisor` tool. The narrative's own structure checks and the manual re-check step are the whole verification it asks for.

## Usage

```
/narrative
```

One narrative per session, not per feature. A day with four sessions produces four files; a feature spanning three sessions produces three, each making its own point.

## Workflow

### Step 1 — Read two recent narratives

Reads the two most recent files in `DailyReports/narratives/` before drafting anything. The corpus is the specification for house style, not the skill document — reading the current end of it keeps a new narrative calibrated to how the style has already moved.

### Step 2 — Gather the material

Works primarily from this session's own conversation: review passes and their briefs, findings taken versus declined and why, decisions put to the user, predictions that turned out false. None of that is recoverable from git alone. Uses artifacts to verify and backfill, per `references/artifact-sources.md`. When the working session is not in context, reconstructs from artifacts alone and says plainly which reasoning could not be recovered.

Collects hard references while gathering: file paths with line numbers, exact counts, run IDs, percentages, byte/memory figures, commit SHAs.

### Step 3 — Find the through-line

Answers one question before drafting: what did this session learn that could not have been written down before it started? That answer becomes the title and decides what gets cut. A session where nothing was learned still gets a narrative — one sentence saying so, kept short rather than inflated.

### Step 4 — Write it

Fixed shape, in order:

| Section | Content |
|---|---|
| Metadata block | Directly under the H1: `Date`, plus either `Repo`/`Milestone`/`Also touched` (code-changing session) or `Artifacts`/`Code changed: none` (non-code session) |
| Summary | Bullet list, three to six items, one per discrete piece of work — written last, after the prose exists |
| Repository and commits | One line per commit in the daily report's own format, or "none" with a one-line reason |
| What we did | First prose section, always titled that — sets up what the session turned out to be, not a longer Summary |
| The middle | Freeform, specific headings only — a section earns its place by contradicting a written artifact, arguing down a live alternative, recording a falsified prediction, recording a review finding taken or declined, or finding a root cause elsewhere than it appeared |
| The close | `What is not proven` (evidence boundary) and/or `What's next` (concrete next steps this narrative's reader needs) — both, one, or neither; never added for symmetry |

House style: no em-dash characters (use `--`), no emojis, past tense/first person plural, every path and identifier backticked, numbers exact and unrounded, failures named plainly.

### Step 5 — Check before filing

```bash
python3 skills/narrative/scripts/check_narrative.py DailyReports/narratives/<file>.md
```

Run from the workspace root. Catches em-dash characters, emojis, a missing/malformed metadata block, a filename off convention, a missing `Summary`/`Repository and commits`/`What we did`, out-of-order sections, and cited repository paths that do not resolve. First run asks where the workspace's git repos live and caches the answer in `scripts/repo_config.json` (delete to re-prompt). The 21 pre-adoption narratives are expected to fail the structure checks; the checker targets the file being filed, not the archive.

Then, manually, re-checks every file and line citation against the source at filing time, since line numbers rot between writing and filing and the script cannot catch that.

## Output

| Output | Description |
|---|---|
| `DailyReports/narratives/YYYYMMDD-slug.md` | The filed narrative (workspace-local, not inside a git repo — filing produces no commit) |
| Checker report | Pass/fail against the structural and style rules in `scripts/check_narrative.py` |

## When to Use

- End of any work session, to produce the durable reasoning record git and the plan document don't capture
- Source material for the daily report or speaking notes
- Reconstructing a narrative for a past session from its artifacts when the original session isn't in context

## When Not to Use

- As a changelog or step-by-step transcript — that's what git history and `What we did` in one clause are for, not a section of their own
- To pad a quiet session into forced sections — a thin session honestly recorded (one sentence) beats an inflated one
- With the `advisor` tool — this skill explicitly runs without it

## Related Skills and Artifacts

- **`references/artifact-sources.md`** — where to look when the working session isn't in context and the narrative must be reconstructed from artifacts alone.
- **`scripts/check_narrative.py`** — the structural/style checker run in Step 5; also maintains `scripts/repo_config.json` (repo-location cache).
- **`DailyReports/narratives/`** — the corpus this skill both reads (Step 1, for calibration) and writes to; workspace-local, outside any git repo.
