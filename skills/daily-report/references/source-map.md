# Source map

Where the material for a daily report comes from, and what each source can and
cannot tell you. Paths are relative to the workspace root -- wherever
`collect_day.py` is run from.

## Order of precedence

1. `DailyReports/narratives/YYYYMMDD-*.md` -- the day's reasoning.
2. Git across this workspace's writable repositories -- what actually landed.
3. The previous `DailyReports/YYYYMMDD.txt` -- what the day owed.
4. `.project/<initiative>/` -- the decoder for local names.

A conflict between a narrative and git is resolved toward git for what
changed, and toward the narrative for why. A narrative claiming a commit that
does not exist means the work was left uncommitted; that is a reportable fact,
not an error to smooth over.

## Narratives

| Section of the narrative | Feeds |
|---|---|
| `Summary` bullets | `Today`, close to one bullet each, after the vernacular pass |
| `Repository and commits` | cross-check against the collector's git output |
| `What we did` and the middle sections | the mechanism and root-cause clauses inside `Today` bullets |
| `What is not proven` | the honesty clauses in `Today`, and often a `Tomorrow` bullet |
| `What's next` | `Tomorrow`, with the acceptance criteria kept |
| metadata block | pushed state, what was touched outside git, and `**Code changed:** none` |

The metadata block and the title are also where milestone and feature numbers
enter, so they are the highest-risk lines to lift verbatim.

## Git

Repo locations are workspace-specific and not hardcoded into this skill.
`scripts/collect_day.py` discovers them itself (project root as a single
repo, first-level sub-directories of the root, or another configured location
such as a bundled `git-repos/`) and remembers the choice in
`scripts/repo_config.json`.

`collect_day.py` queries every discovered repo with an explicit time window
and reports pushed state per commit. Use it rather than hand-rolling `git
log`: a bare `--since=DATE` boundary has already produced the wrong day's
commits in this workspace.

The workspace root is not a git repository. Anything under `.project/`,
`agents/`, `DailyReports/`, `docs/`, `scratch/` or `.claude/` produces no
commit, which is why documentation and planning days legitimately report zero.

## Project artifacts

| Source | What it gives you |
|---|---|
| `.project/<initiative>/milestones/<NN-name>/README.md` | What a milestone number means in words. The primary decoder for `Today`. |
| `.../milestones/<NN-name>/milestone-status.txt` | Feature counts, deviations, sharpenings. Tells you whether a piece of work closed a batch. |
| `.../milestones/<NN-name>/plans/` | The feature plan: what a feature number refers to, its acceptance criteria, its test command. Struck-through text marks an instruction corrected mid-build. |
| `.../docs/reviews/` and `.../milestones/<NN>/reviews/` | Review passes and their findings, when the session is not in context. |
| `agents/investigations/` | Root-cause work. A day with one of these usually has its sharpest `Today` bullet inside it. |
| `agents/memory/handoff.md` | Why a session stopped, and what was in progress. Feeds `Tomorrow`. |
| `progress.txt` | Position and pre-build notes. |
| `docs/<TRACKER-ID>_*/` | The work item streams. This is where a `WorkItems` ID is established. |
| Outcome records outside git, e.g. under `docs/` | Real work with no commits, for example a rightsizing or capacity record. |

## Run evidence

Live proving runs and rightsizing runs are the hardest numbers a report can
carry and the most often misremembered. Prefer the recorded artifact to
recollection: run IDs, check tallies in the form the validator emits, peak
memory against the limit, page and record counts, and the S3 prefixes written.

## What no artifact gives you

Review pass counts and their briefs, which findings were declined and why,
what was put to the user as a decision, and what was predicted and turned out
false. These live in the session transcript. When reconstructing a past day
without it, say in the report that the reasoning layer could not be recovered
rather than producing a plausible version of it -- a later reader cannot tell
the two apart.
