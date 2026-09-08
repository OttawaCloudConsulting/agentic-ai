# Daily Report

**Source:** `skills/daily-report/`
**Command:** `/daily-report`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "daily report", "write the report", "write up today", "EOD report", "status report", "what did I do today", or naming a specific past date to report on); also used when a session is wrapping up and no report exists yet for the day

## Description

Writes the daily status report into `DailyReports/YYYYMMDD.txt`, built from that day's session narratives, the git commits in the workspace's writable repositories, and the project artifacts under `.project/`. Defaults to today's date; given a past date it reconstructs that day's report instead, from artifacts alone where no narrative exists.

The report is the one artifact from the project that leaves the workspace — its readers (a manager, a delivery lead, whoever tracks the work item) have no access to `.project/`, milestone READMEs, or feature plans. Every workspace-local planning identifier (milestone numbers, feature numbers, gate numbers, sub-feature markers) is translated into descriptive text a reader outside the workspace can follow; tracker IDs, commit SHAs, environment names, and other identifiers resolvable outside the workspace are kept verbatim.

This skill does not call the `advisor` tool. The checker script plus a manual citation pass are the whole verification it asks for.

## Usage

```
/daily-report                # today
/daily-report 2026-08-27     # a specific past day
```

## Workflow

### Step 1 — Take format from the corpus, nothing else

Reads the two most recent files in `DailyReports/` for section shape and prose voice, if any exist. Does not calibrate length or vernacular on them — older reports may predate the current length budget or still carry raw planning identifiers; they're history, not precedent. Format comes from the corpus, length from Step 4, language from Step 3.

### Step 2 — Gather the material

Runs the collector, which does the mechanical part:

```bash
python3 skills/daily-report/scripts/collect_day.py            # today
python3 skills/daily-report/scripts/collect_day.py 2026-08-27 # a specific past day
```

Run from the workspace root. First run asks where the workspace's git repos live (project root, first-level sub-directories, or another location such as a bundled `git-repos/`) and caches the answer in `scripts/repo_config.json` (delete to re-prompt). Prints the day's commits with pushed state, narratives filed for the date, commits from the two following days (so a late-landing fix isn't lost), and the previous report's `Tomorrow` section.

Reads, in order: the day's narratives (`DailyReports/narratives/YYYYMMDD-*.md`, the primary source), the previous day's report (for its `Tomorrow` section), the session transcript when the work happened in-session, and `.project/<initiative>/` as a decoder for local identifiers. `references/source-map.md` has the full table of where each kind of material lives. When no narratives exist for the date, reconstructs from commits, `.project/`, `agents/investigations/`, and `progress.txt`, and says plainly where the record is thin rather than inventing reasoning.

### Step 3 — Strip the workspace-local vernacular

Runs as a deliberate pass over the draft, not trusted to have happened while writing. Test: could a reader who has never seen this workspace resolve the identifier? Milestone/feature/gate numbers and sub-feature or local finding markers get replaced with descriptive text naming the actual work — not a paraphrase of the number. Tracker IDs, commit SHAs, cluster/environment names, and measured figures are kept; stripping those costs the report its reproducibility. The `Commits` section is verbatim regardless — real commit subjects carry local markers and rewriting them breaks the link to git.

### Step 4 — Write the four sections

| Section | Content |
|---|---|
| `Date` | `Date: YYYY-MM-DD`, matching the filename |
| `Today` | One `- ` bullet per discrete piece of work (not per narrative or per commit); past-tense verb, usually one sentence. Target 150–200 words, hard ceiling 220. Keeps identifiers that name a thing, drops volumetrics (line/file/insertion counts). States the outcome, not the proof apparatus. A defect found by running, a falsified prediction, and a check that couldn't be closed each earn extra words; how the work was done does not. |
| `Commits` | One line per commit, chronological, `- {repo} \| <short sha> \| subject`, taken from the collector. A day with no commits states why. |
| `WorkItems` | One `- ` bullet per tracker work item (Jira, GitHub Issues, Linear, etc.) the day's effort books to, established from the day's own material — never copied from the previous report or assumed. |
| `Tomorrow` | One `- ` bullet per next step with nested `  - ` acceptance criteria. Also carries blockers sitting with other teams, unpushed commits by SHA, and deferred decisions. Target ~80 words. |

Template: `skills/daily-report/assets/daily-report-template.txt` — binding on structure.

House style: no em-dash characters, no emojis, plain past tense, no first person, numbers exact and unrounded, failures named plainly.

### Step 5 — Check before filing

```bash
python3 skills/daily-report/scripts/check_report.py DailyReports/20260827.txt
```

Catches missing/out-of-order sections, a `Date` field disagreeing with the filename, malformed commit lines, em-dashes, emojis, a missing/malformed `WorkItems` entry, workspace-local identifiers surviving into prose, and a `Today` section or bullet over budget (warnings, not errors — a dense day can go over deliberately). Older archive files can fail by design if they predate the current standards; the checker targets the file being filed, not the corpus.

Then, manually: re-checks every file and line citation against source at filing time (line numbers rot under an active branch), confirms each number traces to something observed, and confirms the previous day's `Tomorrow` bullets are each accounted for.

## Output

| Output | Description |
|---|---|
| `DailyReports/YYYYMMDD.txt` | The filed report (workspace-local, not inside a git repo — filing produces no commit) |
| Checker report | Pass/fail against the structural, vernacular, and length rules in `scripts/check_report.py` |

## When to Use

- End of a work day, to produce the single artifact that leaves the workspace for a manager, delivery lead, or tracker
- Reconstructing the report for an earlier date from commits and project artifacts alone, when no narrative or session context exists
- When a session is wrapping up and no report exists yet for the day

## When Not to Use

- As a diary or a changelog — the `Commits` section carries the changelog; `Today` spends its words on reasoning commit subjects can't hold
- To reproduce planning-document detail — milestone/feature/gate numbers and sub-feature markers get translated to descriptive text, not carried through
- With the `advisor` tool — this skill explicitly runs without it

## Related Skills and Artifacts

- **[Narrative](narrative.md)** (`/narrative`) — the primary source this skill reads from; a day's session narratives feed `Today` and `Tomorrow` directly.
- **`references/source-map.md`** — full table of where daily-report material lives (narratives, git, previous report, `.project/`, run evidence) and what each source can and can't tell you.
- **`scripts/collect_day.py`** — the material collector run in Step 2; also maintains `scripts/repo_config.json` (repo-location cache).
- **`scripts/check_report.py`** — the structural/vernacular/length checker run in Step 5.
- **`assets/daily-report-template.txt`** — the binding section template.
- **`DailyReports/`** — the corpus this skill both reads (Step 1, for calibration) and writes to; workspace-local, outside any git repo.
