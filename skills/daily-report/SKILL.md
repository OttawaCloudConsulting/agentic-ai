---
name: daily-report
description: >
  Write the daily status report into DailyReports/YYYYMMDD.txt, built from
  that day's session narratives, the git commits in this workspace's
  writable repositories, and the project artifacts under .project/. Defaults
  to today's date; given a past date (or context describing an earlier day)
  it reconstructs that day's report instead, from artifacts alone where no
  narrative exists. Four sections: Date, Today, Commits, WorkItems,
  Tomorrow. Translates every workspace-local planning identifier (milestone
  numbers, feature numbers, gate numbers, sub-feature markers) into
  descriptive text a reader outside this workspace can follow. Use whenever
  the user says "daily report", "write the report", "write up today", "EOD
  report", "status report", "what did I do today", or names a specific past
  date to report on, and use it as well when a session is wrapping up and a
  report for the day does not exist yet.
---

# Daily report

## Never call the advisor tool

This skill runs without `advisor`. Do not call it at any point while writing a
report: not before drafting, not when choosing what to cut, and not after
filing. The checker in Step 5 plus the manual citation pass are the whole
verification this skill asks for. When the report is written and checked, say
what was filed and stop.

## What the daily report is

A daily report is the one artifact from this project that leaves the
workspace. Its readers are a manager, a delivery lead and whoever tracks the
work item, and none of them have `.project/`, the milestone READMEs or
the feature plans. That single fact drives most of what follows: anything the
report cannot be understood without has to be inside the report.

It answers three questions for the day. What was done and how it was proved,
what landed in git, and what comes next with the check that will show it is
done. It is not a diary, and it is not a changelog either -- the `Commits`
section carries the changelog, so the `Today` bullets can spend their words on
the reasoning the commit subjects cannot hold.

The report is a derived document. Sessions produce narratives, git records
commits, `.project/` records intent; the report reads those and compresses.
Writing one should almost never require you to work out what happened, only to
decide what a reader outside the project needs from it.

## Where it goes

`DailyReports/YYYYMMDD.txt`, one file per work day, plain text. The directory
is workspace-local and not inside a git repository, so filing a report
produces no commit.

There is a template at `skills/daily-report/assets/daily-report-template.txt`.
It defines the sections and their order; read it, and treat it as binding on
structure.

## Step 1: Take format from the corpus, nothing else

Read the two most recent files in `DailyReports/` before writing, for the
shape of the sections and the voice of the prose. If none exist yet, skip
this step and take format from Step 4 and the template alone.

**Do not calibrate length or depth on them.** A corpus can accumulate reports
written before the length budget in Step 4 existed, running well over it. An
older report is not a standard that was met and is not being brought into
line; it is simply history. The budget in Step 4 is the standard, and it wins
against anything the corpus shows.

Language is the same story. Older reports in the corpus may still carry the
planning vernacular this skill exists to remove -- a raw milestone or feature
number, a gate number, a local finding reference. No file is precedent for
reintroducing an identifier, and Step 3 decides the question rather than the
corpus.

So: format from the corpus, length from Step 4, language from Step 3.

## Step 2: Gather the material

Run the collector, which does the mechanical part. With no argument it
targets today; pass a date to build or reconstruct an earlier day's report:

```bash
python3 skills/daily-report/scripts/collect_day.py            # today
python3 skills/daily-report/scripts/collect_day.py 2026-08-27 # a specific past day
```

Run it from the workspace root. The first run asks where this workspace's git
repos live (the project root itself, its first-level sub-directories, or
another location such as a bundled `git-repos/`) and remembers the answer in
`scripts/repo_config.json`. Delete that file to be asked again.

It prints the day's commits across this workspace's writable repositories with
their pushed state, the narratives filed for that date, commits from the two
following days (so a fix left uncommitted at day end is not silently lost),
and the previous report's `Tomorrow` section.

Then read, in this order:

1. **The day's narratives**, `DailyReports/narratives/YYYYMMDD-*.md`. These
   are the primary source. Each narrative's `Summary` bullets were written to
   be lifted into `Today`, and its `What is not proven` and `What's next`
   sections feed `Tomorrow`. Lift the substance, but never the wording of an
   identifier: narrative metadata blocks carry `**Milestone:** M04 now 4/4`
   and titles carry `Feature 04.3`, and those are exactly what has to go.
2. **The previous day's report**, for its `Tomorrow` section. Anything
   promised there is either done today, still open, or dropped, and each of
   those three is a fact the report owes the reader. Unpushed commits and
   blockers sitting with other teams recur across days in this corpus, and
   they recur because they were carried forward deliberately.
3. **The session transcript**, when the work happened in this session. It
   carries what no artifact does: review passes and what they found, findings
   declined and why, predictions that turned out wrong.
4. **`.project/<initiative>/`**, as a decoder rather than a source. When a
   narrative says "M04 4/4", the milestone README is where you find out what
   M04 actually is, which is what the report says instead.

`references/source-map.md` has the full table of where each kind of material
lives, including run evidence and investigations.

**When there are no narratives for the date**, reconstruct from commits,
`.project/`, `agents/investigations/` and `progress.txt`, and say in the
report where the record is thin rather than inventing reasoning to fill it.
If git shows nothing at all for the day across every repo, the report says
exactly that, with the check that established it, rather than leaving the
`Commits` section blank.

## Step 3: Strip the workspace-local vernacular

This is the requirement that distinguishes a good report from a leaked
planning document, so run it as a deliberate pass rather than trusting
yourself to have avoided it while drafting.

The test for any identifier is one question: **could a reader who has never
seen this workspace resolve it?**

- `M04`, `Milestone 02`, `Feature 04.3`, `SF-2`, `Gate 3`, `FL-1`, `EC-10`,
  `A3` -- resolvable only against `.project/`. Replace with what the thing
  actually is.
- A tracker ID like `PROJ-33`, a commit SHA, a cluster or environment name, an
  S3 bucket or prefix, a versioned image tag, a `path/to/file.py:39` line
  reference, a measured figure like `2543 MiB` -- resolvable by anyone with
  access to the systems. Keep every one of them. Stripping these is the
  opposite failure and costs the report its reproducibility.

The replacement is descriptive, not a paraphrase of the number. It names the
work:

| Local | In the report |
|---|---|
| Feature 04.3 | the payments retry queue, the last job in this batch |
| M04 now 4/4 | this closes out the four ingestion pipeline jobs |
| the M03 regression gate | the checkout regression guard |
| Gate 4 approval on the 05.2 plan | sign-off on the implementation plan for the notification service wrappers |
| five sub-features, SF-1 through SF-5 | five commits, one per adapter package |
| the FL-1 note about a Postgres wipe | the earlier finding that an ephemeral Postgres wipe erases registrations |

Two details that trip this up:

- **The `Commits` section is verbatim.** Real commit subjects contain
  `SF-1`, and rewriting them would break the link between the report and git.
  The vernacular rule applies to prose: `Today`, `Tomorrow`, and any
  explanatory line in `Commits` that is not a commit.
- **Sequence numbers are usually load-bearing and the labels are not.** "Five
  commits, SF-1 through SF-5" becomes "five commits, one per provider
  package": the count stays because it is a fact about the day, the markers go
  because they mean nothing outside the plan.

## Step 4: Write the four sections

### Date

`Date: YYYY-MM-DD`, matching the filename.

### Today

One `- ` bullet per discrete piece of work, no nesting. Not one per narrative
and not one per commit: a day with one narrative and fourteen commits can
carry six bullets, because the unit is a piece of work a reader would name.

Each bullet opens on a past-tense verb and states what was achieved. Usually
one sentence, 20 to 30 words. `Today` as a whole targets 150 to 200 words and
should not pass 220, however heavy the day: seven pieces of work means seven
short bullets, not seven long ones. When in doubt, cut -- shorter has never
been the complaint.

That budget is the hard part of this skill, because every instinct pushes the
other way. It works because the report is not the record. The narratives hold
the reasoning, the evidence and the citations, and they are linked from the
same directory; a reader who wants the depth has it. What the report owes is
the answer to "what moved today", readable in a minute by someone who will
never open a narrative.

**Keep identifiers, drop volumetrics.** A number that names a thing earns its
place: an environment name, a versioned image tag, a package or module name, a
version like `v1`, a date like `2026-07-13`. A number that measures the size of the
output does not: line counts, file counts, insertion counts, byte sizes, run
tallies, how many checks passed, how many deployments the server now carries.
"Six flow modules and six deployment entries" is the work; "237 to 276 lines,
twelve files, 4210 insertions" is the diff, and git already has it.

**State the outcome, not the apparatus.** "Registered against the live server"
is the claim a reader needs. How it was proved -- the
mutation testing, the read-back property counts, the before-and-after
snapshots, the empty frozen-surface diff -- is narrative material. Naming the
apparatus in the report doubles the length and adds nothing the reader can act
on, because they were never going to audit it from here.

Three things do earn their words, and they are why the reports get read:

- **A defect found, especially one found by running rather than reading.**
  Describe it well enough to be understood, up to about 60 words. This is the
  one place the budget bends, and only one or two bullets a day should use it.
- **A prediction that turned out wrong.** State that it was falsified and what
  is true instead. It tells the reader which of the day's other reasoning to
  distrust.
- **A check that could not be closed**, with what blocks it, and the boundary
  between proven and inferred where the day's claims outrun the evidence.

What does not earn a bullet: how the work was done. Review passes and their
finding counts, planning sequence, process corrections, tooling that only
served the day's own workflow. That material is real and belongs in the
narrative; in the report it displaces delivery. A decision is reportable, the
argument that produced it is not -- though when a decision was reversed or is
counter-intuitive, one clause of why keeps a reader from having to ask.

A light day is one or two bullets and the template's 110-word target holds.

### Commits

One line per commit, chronological, in the format the template sets:

```
- my-service | 3242d4d | fix(worker): pin flow pods to on-demand capacity
```

Short SHA, commit subject unedited. Take these from the collector rather than
retyping them.

A day with no commits says so and says why: "No commits. Design and planning
artifacts only", "Consolidation, analysis and documentation day. The outcomes
record lives in the workspace docs tree, which is not a git repository." A
blank section reads as an omission; an explained zero reads as a fact, and
planning days are real days.

Commits that belong to the day's work but landed later get stated with their
date and SHA. Commits still local only get flagged here or, more usefully, as
a `Tomorrow` bullet.

### WorkItems

The tracker's work items the day's effort books to, one per `- ` bullet, for
example `- PROJ-33`. The template marks this required.

Establish it from the day's own material rather than copying the last
report's or assuming a default. Check what the day's narratives and
`.project/` artifacts actually reference -- a workspace may track more than
one active ID, and old artifacts sometimes cite a stream whose directory no
longer resolves. List every ID the day's work genuinely books to, and if you
cannot establish one, say so in the section rather than inventing an ID.

### Tomorrow

One `- ` bullet per next step, each with `  - ` sub-bullets giving the
acceptance criteria: the check that must go green, the number that must agree,
the artifact that must exist. A next step with no criterion is a wish, and the
sub-bullet is what makes tomorrow's report writable.

Also belongs here:

- **Blockers sitting with other teams**, named concretely: which grant, which
  quota, which account, and what it blocks. These recur across days until they
  clear, and repeating one is correct, not lazy.
- **Unpushed commits and pending cleanup**, by SHA.
- **Deferred decisions**, recorded as deferred with the open question stated.
  A decision the day chose not to make is information.

Target around 80 words. This section is forward-looking and owns the planning
that `Today` does not.

## Step 5: Check before filing

```bash
python3 skills/daily-report/scripts/check_report.py DailyReports/20260827.txt
```

It reports missing or out-of-order sections, a `Date:` field disagreeing with
the filename, malformed commit lines, em-dashes, emojis, a missing or
malformed `WorkItems` entry, any workspace-local identifier that survived into
prose, and a `Today` section or bullet running past its budget.

Older archive files can fail it by design if they predate the vernacular or
length standards this checker enforces. The checker is for the file you are
about to file, not for the corpus. The length findings are warnings rather
than errors, so a dense day can go over deliberately -- but read them before
deciding to, since the usual cause is the narrative's depth leaking into the
report.

Then do the part the script cannot. Re-check every file and line citation
against source at the point of filing rather than the point of writing, since
line numbers move under an active branch and stale citations have shipped in
this project for exactly that reason. Confirm each number traces to something
observed. Confirm the previous day's `Tomorrow` bullets are each accounted
for.

## House style

- No em-dash characters. No emojis. This is a project documentation rule.
- Plain past tense, no first person, no headings inside sections.
- Numbers exact and unrounded where they were measured.
- Name failures plainly. The corpus does not soften them and its usefulness
  upward depends on that.

## Failure modes to avoid

**Leaking the plan.** The dominant one, and it happens most often through
inheritance: a narrative title, a milestone status line or a plan heading gets
carried across intact. Run Step 3 against the draft, not against your memory
of writing it.

**Over-translating.** Replacing a versioned image tag with "the current
image" makes the report unreproducible. The rule removes identifiers a reader
cannot resolve, not identifiers that look technical.

**Reporting the workings.** The most common inflation, and it arrives on good
days rather than bad ones. A day with seven narratives offers seven sessions'
worth of reasoning, evidence and review history, all of it interesting, none
of it the report's job. The test on any clause: would the reader do something
differently if it were absent? Line counts, proof apparatus and review
sequences almost never pass it.

**Padding a thin day.** A planning day with no commits, honestly reported in
two bullets, is a better artifact than the same day inflated to look busy. The
reader is tracking a project, not counting bullets.

**Dropping the claim with the workings.** Compression has a floor. A bullet
that names a decision without its outcome, or reports a reversal with no hint
of why, sends the reader to ask a question the report should have answered.
Cut the argument, keep the conclusion and one clause of reason.
