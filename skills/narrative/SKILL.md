---
name: narrative
description: >
  Write the session narrative: the prose record of what a work session did,
  what it found, and what it did not prove, filed into
  DailyReports/narratives/YYYYMMDD-slug.md. Not a summary and not a changelog.
  A short argued account where the title is the finding, every section earns
  its place, and wrong predictions and declined review findings are recorded
  rather than dropped. Use at the end of any work session, and whenever the
  user says "write the narrative", "write this up", "narrative for today",
  "record what we did", "document this session", or asks for source material
  for the daily report or speaking notes. Also use to reconstruct a narrative
  for a past session from its artifacts.
---

# Session narrative

## Never call the advisor tool

This skill runs without `advisor`. Do not call it at any point while writing a
narrative: not before drafting, not when deciding what a section is worth, and
not after filing. The narrative's own checks are the whole verification this
skill asks for. When the narrative is written and checked, say what was filed
and stop.

## What a narrative is

A narrative is the durable record of one work session, written for four
readers at once: yourself in six months, the daily report, upward status
conversations, and whoever picks the work up next. It is roughly 800 to 1500
words of prose, plus a bullet Summary and a commit list at the top that those
downstream readers lift directly.

It is not a summary of the session and not a changelog. The difference is that
a summary tells you what happened in order, while a narrative makes a claim and
supports it. Look at the titles already in the corpus:

- "The import check that looked like a re-record and was not"
- "three pod failures, three fixes, and a root cause that was never infrastructure"
- "Planning the proving runs, and learning that a passing log proves less than it looks like"

Each of those is an argument, and the sections underneath are the evidence. A
narrative titled "Feature 05.3 implementation" with sections called Overview,
Implementation, Testing and Next Steps has failed before it starts, because
those headings can be filled by anyone who read the diff and they carry no
finding.

The reason this matters practically: git already records what changed, and the
plan document already records what was intended. The only thing that exists
nowhere else is the reasoning: what surprised us, what we got wrong, what we
decided not to do and why, and how far the evidence actually reaches. If the
narrative does not carry that, it carries nothing.

## Where it goes

`DailyReports/narratives/YYYYMMDD-slug.md`, where the date is the session date
and the slug is a short kebab-case topic, for example
`20260901-import-closure-analyticsfeature.md`. The directory is workspace-local and
not inside a git repository, so filing a narrative produces no commit.

One narrative per session, not per feature. A day with four sessions gets four
files. A feature that spanned three sessions gets three, each making its own
point.

## Step 1: Read two recent narratives first

Before writing anything, read the two most recent files in
`DailyReports/narratives/`. The house style has moved over time and the corpus
is the specification, not this document. Reading the current end of it is how
you stay calibrated instead of reproducing whatever the style was when this
skill was written.

## Step 2: Gather the material

The primary source is this session's own conversation. Most of what makes a
narrative worth reading is conversational: how many review passes ran and what
each brief was, which findings were taken and which were declined and why, what
was put to the user as its own decision, what was predicted and turned out
false. None of that is in git.

Work from the transcript and use artifacts to verify and backfill. When the
session that did the work is not in context, reconstruct from artifacts alone,
and say plainly in the narrative which reasoning could not be recovered rather
than inventing it. See `references/artifact-sources.md` for where to look.

While gathering, collect the hard references as you go: file paths with line
numbers, exact counts, run IDs, percentages, byte and memory figures, commit
SHAs. A narrative without numbers reads as impressions. The corpus is precise
to a degree that lets a later reader re-check the claim: "peaked at 2543 MiB of
a 12288 limit", "seven modules and never reaches `jobs`", "eleven thousand
objects in total".

## Step 3: Find the through-line

Before drafting, answer one question: what did this session learn that could
not have been written down before it started?

That answer is the title, and it also decides what gets cut. Sessions do
produce this, even quiet ones. A planning session that found the milestone had
undercounted something has a through-line. A session where everything went
exactly to plan has one too, and it is usually narrower than expected: the
interesting thing is which specific assumption held under test.

If genuinely nothing was learned, say so in one sentence and write a short
narrative. A thin session honestly recorded is more useful than a thin session
inflated into five sections.

## Step 4: Write it

### The metadata block

Directly under the H1, before any section. The fields depend on what kind of
session it was, which is the one part of the shape that varies by content
rather than by taste.

A session that changed code:

```
**Date:** 2026-08-26
**Repo:** my-data-providers (branch feat/tool-migration), five commits, all pushed
**Milestone:** M04 now 4/4 -- 04.3 closed at fifteen of fifteen checks
**Also touched:** agents/investigations/, the 04.3 plan, milestone-status.txt (all workspace-local)
```

A session that did not:

```
**Date:** 2026-09-01
**Artifacts:** `.project/order-pipeline/milestones/05-job-orchestrator/` -- one plan, one Gate 4 review, `milestone-status.txt` updated
**Code changed:** none. No repository was touched. One disposable `ast` walk left at `scratch/closure_check.py`.
```

State `**Code changed:** none` explicitly when nothing was committed. A reader
scanning for what shipped needs that answered in the header, not inferred from
the absence of a repo line.

### Summary

A bullet list, directly after the metadata block and before any prose. Three to
six bullets, one per discrete piece of work, each stating what was done and the
outcome. This is the scan layer: a reader deciding whether to read the rest gets
their answer here, and the daily report's Today section lifts these bullets
almost unchanged, which is why they carry the same hard references the prose
does rather than being a table of contents.

```markdown
## Summary

- Pinned flow pods to on-demand capacity after four spot reclamations in one
  hour, which moved four deployment validators that assert `nodeSelector` by
  whole-dict equality.
- Dropped the deployment `concurrency_limit` that was relabelling a lease
  expiry as `exceeded timeout of 14400.0 second(s)`, and inverted the two
  validator assertions rather than deleting them.
```

Write these last, after the prose exists. Written first they become a plan, and
the narrative bends to fit them.

### Repository and commits

Immediately after the Summary. One line per commit, in the daily report's own
format so it transfers without reformatting:

```markdown
## Repository and commits

- my-data-providers | 3242d4d | pin provider flow pods to on-demand capacity
- my-data-providers | 974b759 | drop the decorative concurrency limit
```

When nothing was committed, say so and say why in one line, for example
"none. Planning session; the plan and review live under `.project/`." Silence
here reads as an omission rather than as a fact.

### What we did

The first prose section, always called that, following Summary and the commit
list. Two or three paragraphs that set up the rest: what the session set out to
do, what it turned out to be, and the shape of the surprise if there was one.

It is not a longer Summary. The bullets above say what happened; this says what
it meant and why the session went where it went. If a paragraph here could be
cut down to one of the bullets without loss, it is the wrong paragraph.

The strongest openings in the corpus name the gap between expectation and
outcome immediately. "Applied the remediation plan written the previous day,
then kept going when it turned out to be only two thirds right." That sentence
does the work of a paragraph.

### The middle

Freeform. Every heading is a specific assertion about this session, never a
generic label. The corpus shows the range: "Fix 2: the four-hour timeout that
was eight minutes", "The one place it is not the same", "The defect that nearly
shipped", "Four Codex passes, and the lens mattering more than the count".

A section earns its place when one of these is true:

- Something was discovered that contradicts what a written artifact says.
- A decision was made where the alternative was live and had to be argued down.
- A prediction was falsified. Record it as wrong rather than deleting it. The
  reason is that the wrong prediction usually shows the reader which of the
  session's other reasoning to distrust.
- A review found something real, or a review finding was declined. Both are
  worth recording; a declined finding recorded as a decision is much better
  than a declined finding that silently disappears.
- Something failed and the root cause was not where it appeared to be.

A section does not earn its place because a step happened. Writing tests,
running the build, opening a PR: these belong in `What we did` in a clause, not
in a heading of their own.

Prose paragraphs, not bullets. Bullets belong in Summary, the commit list and
the closing section, and occasionally in a genuine list of parallel items, but
the analysis itself needs sentences because the connective tissue between facts
is most of the value. A middle section that has turned into bullets has usually
stopped arguing and started listing. Where a paragraph opens on a claim, bold the claim sentence and let the
rest of the paragraph support it, which is the pattern the corpus uses when
several findings share one section.

### The close

Content-driven, and usually one of two:

`## What is not proven` when the session's claims outrun its evidence, which is
most sessions. This is the section that makes the rest trustworthy. Be exact
about the boundary: what was tested against what, what was executed against a
stand-in rather than the real thing, what has been asserted but never observed.
The corpus does this well: "The flow is proven correct. It is **not** proven at
production data volume, and the feature makes no claim that it is."

`## What's next` when there are concrete next steps with acceptance criteria,
or blockers sitting with other teams. Use bullets here. Note that the daily
report's Tomorrow section owns forward-looking planning, so this section is for
things a reader of this narrative specifically needs, not a general plan.

Both, one, or neither. Do not add an empty one for symmetry.

## House style

- No em-dash characters anywhere. The house substitute is `--`. This is a
  project documentation rule, not a preference.
- No emojis.
- Past tense, first person plural. "We" did the work.
- Backtick every path, identifier, flag, image tag and command.
- Numbers exact and unrounded where they were measured. "2543 MiB", not
  "about 2.5 GiB".
- Name the thing that went wrong plainly. The corpus does not soften failures,
  and its usefulness depends on that.

## Step 5: Check before filing

Run the checker, which catches the mechanical failures that have actually
occurred in this corpus:

```bash
python3 skills/narrative/scripts/check_narrative.py DailyReports/narratives/<file>.md
```

Run it from the workspace root. It reports em-dash characters, emojis, a
missing or malformed metadata block, a filename that breaks convention, a
missing `Summary`, `Repository and commits` or `What we did`, any section that
jumps ahead of `What we did`, and any cited repository path that does not
resolve.

The first run asks where this workspace's git repos live (the project root
itself, its first-level sub-directories, or another location such as a
bundled `git-repos/`) and remembers the answer in
`scripts/repo_config.json`. Delete that file to be asked again, for example
after moving to a new workspace layout.

The 21 narratives written before the Summary and commit list were adopted will
fail the structure checks. That is expected: they predate the shape, and the
checker is for the file you are about to file, not for the archive.

Then do the part a script cannot: re-check every file and line citation against
the source at the point of filing, not at the point of writing. Line numbers
rot between the two, and stale citations have already shipped in this project
for exactly that reason. Confirm each number in the narrative traces to
something you observed rather than something you assumed.

## Failure modes to avoid

The dominant one is chronology. A narrative that reads "first we did A, then B
revealed C, then we fixed D" is a transcript with headings. Reorganise around
the finding: lead with what turned out to be true, then show what established
it.

The second is completeness, and it is the one that actually bites. The existing
narratives run 873 to 1174 words of prose, and the richest of them covers three
pod failures, three fixes, a falsified plan instruction and a root cause in
1174. Reconstructions of that same session have come in at 1607 and 1817 words
without adding a single new fact; the excess was restatement. If you are past
1500, the question is not what else to include but which section a reader would
not need in order to trust the conclusion or pick the work up. `Summary` makes
this worse rather than better if you let it: the bullets and `What we did` say
the same thing at two lengths unless you keep the prose to what the bullets
cannot carry.

The third is hedging the negative. "There were some minor issues with the
initial approach" is worth nothing. "The hook was mutating the bucket class
even when a caller had explicitly asked it not to, which would have broken the
one deliberate escape hatch the design needs" is the same event, written so
someone can act on it.
