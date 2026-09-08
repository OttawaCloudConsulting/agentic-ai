# Artifact sources

Where to look when verifying a narrative, and where to reconstruct one from
when the session that did the work is not in context.

Paths are relative to the workspace root -- wherever `check_narrative.py` is
run from. See "Where the repos are" in the skill's own scripts for how that
root is configured.

## The session's own paper trail

| Source | What it gives you |
|---|---|
| `.project/<initiative>/milestones/<NN-name>/plans/` | The feature plan the session worked from: sub-features, interface contracts, test commands, acceptance criteria. Struck-through text marks a plan instruction that was corrected mid-build, which is usually worth a section. |
| `.project/<initiative>/milestones/<NN-name>/reviews/` | Gate reviews for the milestone. |
| `.project/<initiative>/milestones/<NN-name>/milestone-status.txt` | Current feature counts, deviations, and the notes that do not fit the README. Sharpenings recorded here rather than in the README are frequently the finding a planning session produced. |
| `.project/<initiative>/milestones/<NN-name>/README.md` | What the milestone claimed before the session ran. Diffing intent against outcome is the fastest route to a through-line. |
| `.project/<initiative>/docs/reviews/` | Project-level gate reviews and stored Codex review output. |
| `agents/investigations/` | Root-cause investigations. A session with one of these almost always has its narrative through-line inside it. |
| `agents/memory/handoff.md` | Written when a session ended at a decision point. States what was in progress and why it stopped. |
| `progress.txt` | Current position and NOTES written before a build. |
| `scratch/` | Disposable analysis. Worth naming in the metadata block when a script was left behind, so a reader knows it exists and knows it is disposable. |

Adjust `<initiative>` and the milestone naming to whatever this workspace
actually uses; the table names the kind of artifact, not a fixed path.

## Code

Repo locations are workspace-specific and not hardcoded into this skill.
`check_narrative.py` discovers them itself (project root as a single repo,
first-level sub-directories of the root, or another configured location such
as a bundled `git-repos/`) and remembers the choice in
`scripts/repo_config.json`. Use the same locations here: for each repo,
`git log --oneline`, `git status` and `git log --stat` over the session's
date range give the commit count, whether the work is pushed, and the files
touched. Both facts belong in the metadata block: a reader needs to know
whether the work exists anywhere but this machine.

Note that the workspace root itself may not be a git repository, so anything
under `.project/`, `agents/`, `DailyReports/`, `docs/` or `scratch/` at that
root produces no commit. That is why narratives about planning sessions carry
`**Code changed:** none` rather than a repo line.

The skill's own directory (wherever it's installed, e.g. `.claude/skills/` or
`skills/`) is also workspace-local. A session that changed a skill records it
under `**Also touched:**`.

## Run evidence

Live proving runs, rightsizing runs and their logs are the hardest numbers a
narrative can carry, and also the ones most often misremembered. Prefer the
recorded artifact over recollection: run IDs, exit codes, peak memory figures,
page and record counts, and the S3 prefixes written. The evidence check output
from a deployment validator gives the check count in the form the milestone
uses.

## What artifacts cannot give you

Reconstruction from artifacts alone loses the reasoning layer: how many review
passes ran and with what brief, which findings were taken and which declined,
what was put to the user as a separate decision, and what was predicted and
turned out false. Those are the parts of a narrative that carry the most value,
so when reconstructing, say in the narrative which of them could not be
recovered. An honest gap is better than a plausible invention, because a later
reader has no way to tell the two apart.
