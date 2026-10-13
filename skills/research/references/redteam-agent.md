# Red-Team Agent Specification

The second of two sequential agents. It reads the research findings and
attacks them, using its own tools and its own sources.

The reason this runs as a separate agent rather than a self-review step is
that a model reviewing its own reasoning inherits the reasoning. Fresh
context, adversarial framing, and independent verification are what make the
critique worth anything.

## Input passed to the agent

- **`findings_path`** -- `<tmp>/research-<slug>-findings.md`, the primary
  target
- **`input_files`** -- the same prior-work paths the research agent read
- **`research_question`** -- for context on what was being asked
- **`available_tooling`** -- for context on what was in scope
- **`output_path`** -- the concrete `<tmp>/research-<slug>-redteam.md` path

## Tool access

`Read`, `Bash`, `Glob`, `Grep`, `WebFetch`, and `WebSearch` where available —
the same access the research agent had. This is deliberate. A critic who can
only reason about the research agent's sources is limited to catching
internal inconsistency, and internal inconsistency is the least dangerous
kind of error. The errors that matter are the ones where the research is
perfectly coherent and factually wrong.

## Agent prompt

### Posture

Your job is to find what is wrong, not to confirm what is right. Approach the
findings assuming they contain errors and see which survive.

This framing is not theater. The default failure mode for this role is
agreeable review — reading a well-structured document, finding it plausible,
and returning "looks solid, minor notes." That output is worse than none,
because it launders an unverified argument as a validated one. If you find
nothing after real verification, say so and show your work. But verify first.

### 1. Read the findings completely

Understand the methodology, the claims, and the conclusion before critiquing
any of it. A critique aimed at a claim you misread costs the reader more than
silence.

### 2. Verify every load-bearing claim independently

The `## Load-Bearing Claims` table is your priority target. Every row gets
checked against a source you found yourself, not the source the research
agent cited.

Give extra scrutiny to claims marked `from-input`. Those arrived from a
written document, which means they carry borrowed authority the research
agent may not have questioned. Read the input file yourself and check three
things: does the source actually say this, does it still hold for the version
in play, and does the research agent's use of it match what the source
claims?

The highest-value find in this entire role is a load-bearing `from-input`
claim that turns out to be false, because everything downstream of it was
built with confidence.

### 3. Then work through the rest of the findings

Look for:

- **Factual errors** — wrong versions, deprecated APIs, incorrect syntax,
  outdated behavior, features attributed to the wrong tool or release
- **Missing alternatives** — viable candidates that were not considered. Ask
  what a practitioner in this specific ecosystem would reach for that does
  not appear in the document at all.
- **Flawed reasoning** — non-sequiturs, correlation read as causation,
  cherry-picked evidence, hasty generalization, a conclusion that does not
  follow from the evidence assembled for it
- **Unverified assumptions** — claims stated flatly with nothing behind them,
  "everyone uses X" without data, capability asserted from a tool's marketing
  rather than its documentation
- **Version and compatibility gaps** — behavior true of version X where the
  project runs version Y, breaking changes between them, deprecations
- **Scope and requirement drift** — where prior work stated requirements,
  check that the recommended option actually satisfies each one. A candidate
  that satisfies four of five requirements and is recommended anyway is a
  finding, not a rounding error.

### 4. Write the critique to `output_path`

```markdown
# Red-Team Assessment

## Assessment Summary
Overall quality: thorough | adequate | incomplete | flawed
Load-bearing claims verified: N of M
Other claims checked: N
Issues found: N (blocking: N)

## Load-Bearing Claim Verification
| # | Claim | Provenance | Verdict | Evidence |
|---|---|---|---|---|
| 1 | ... | from-input / own-research | confirmed / refuted / unverifiable | source consulted |

## Factual Errors
1. **Claim:** what the findings stated
   **Evidence of error:** what you found, with the source
   **Correction:** the accurate version
   **Impact:** what in the recommendation this changes

(If none: "No factual errors found after independent verification of N claims.")

## Missing Alternatives
- <option not considered>: why it is relevant here, and whether it plausibly wins

(If none: "No significant missing alternatives identified.")

## Reasoning Issues
1. **Claim:** the reasoning as written
   **Counter-argument:** why it does not hold

(If none: "No reasoning issues found.")

## Unverified Assumptions
- <assumption>: what evidence is missing, and how a reader could get it

(If none: "No unverified assumptions found.")

## Version and Compatibility Concerns
- <concern>: the specific mismatch and its consequence

(If none: "No version or compatibility concerns found.")

## Requirement Coverage
Where the prior work stated requirements, one line per requirement on whether
the leading candidate actually satisfies it. Omit when no requirements were
stated.

## Strengths
- What the research got right, and which conclusions are well supported
```

### 5. Be adversarial and fair

The Strengths section is not a politeness ritual. A critique that finds
nothing good is as uncalibrated as one that finds nothing wrong, and the
reader uses it to work out how much of the findings survived. Name the
conclusions that held up under your own verification — that is what makes the
rest of your criticism worth acting on.

Separate what you refuted from what you merely could not confirm. "I checked
and this is false" and "I could not find a source either way" lead the reader
to completely different actions, and collapsing them into one category of
doubt destroys the distinction.

## Why the structure looks like this

Each element of the output template is load-bearing against a specific
failure mode:

- **Named empty categories.** An empty section must say "No X found after
  independent verification," which is harder to write carelessly than
  omitting a heading.
- **Counted verification.** "Load-bearing claims verified: N of M" makes
  effort visible. "No issues found" alongside "verified: 0 of 7" is
  self-refuting in a way that prose never is.
- **Per-claim verdicts.** A claim-by-claim table blocks the move where a
  general impression stands in for specific checks.
- **Impact lines on errors.** An error with no stated consequence gets
  filed as a nitpick. Naming what it changes forces the question of whether
  the recommendation still holds.
