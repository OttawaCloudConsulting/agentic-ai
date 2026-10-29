# Pull Request Template

A working guide for writing pull request titles and bodies. Use the prompts that help explain the change; the categories do not make every prompt mandatory. Replace placeholders with actual information and omit inapplicable details. All examples below are fictional.

This structure is our synthesis of three sources, rather than a format prescribed by any one of them:

- Google Engineering Practices: [Writing good CL descriptions](https://google.github.io/eng-practices/review/developer/cl-descriptions.html) and [What to look for in a code review](https://google.github.io/eng-practices/review/reviewer/looking-for.html)
- [GitHub: How to write the perfect pull request](https://github.blog/developer-skills/github/how-to-write-the-perfect-pull-request/)
- [thoughtbot: Code Review guide](https://github.com/thoughtbot/guides/tree/main/code-review#having-your-code-reviewed)

The prompts for success criteria, expected versus observed results, and reproducible evidence apply these sources' broader principles; the sources do not prescribe these exact fields. GitHub explicitly recommends stating the feedback requested and when it is needed. Our prompt to disclose unverified areas also extends thoughtbot's guidance to reviewers about identifying untested suggestions.

## Template General Guidance

You are preparing a PR after completing development. Write for a human reviewer who has not seen your conversation, tool output, or working notes. Use your recent development context to find relevant facts, then select the information needed to understand the final change, assess the evidence, and identify decisions or actions.

- **Ground the description in the final work.** Check the actual changes and available validation results before drafting. Distinguish what this PR delivers from pre-existing behavior, related work, and future plans. Verify claims against the final implementation, especially when the approach changed during development.
- **Lead with the outcome.** Make the title specific and put the essential purpose and resulting behavior early in the body. Use plain language, explain unfamiliar abbreviations, and write each sentence so it makes sense without the development conversation.
- **Select meaningful reasoning.** Explain consequential decisions, constraints, and accepted tradeoffs. Include an earlier approach only when it explains a lasting limitation, important choice, or constraint a future maintainer needs to understand. Omit the chronology of attempts, corrections, conversations, and tool use.
- **Keep detail proportional to its value.** A section may need only one sentence. Avoid long introductions, exhaustive explanations, and padding to fill the template. Preserve information that affects correctness, compatibility, operation, or reviewer judgment even when it needs more explanation.
- **Give each fact one home.** Use Purpose for the need, Change for the outcome, Rationale for decisions, Evidence for verification, Implications for consequences, and References for supporting material. Cross-reference briefly where useful instead of repeating explanations.
- **Describe behavior and significant mechanisms.** Include files, functions, or implementation details when they clarify the outcome or direct review attention. Avoid an inventory of edits that the diff already shows.
- **Make claims assessable.** Connect important outcomes to relevant checks and observed results. Use measurements with meaningful conditions and comparisons where useful. Report uncertainty honestly; do not invent metrics, requirements, validation, or assurances such as "fully tested" or "no risk."
- **Keep evidence current and selective.** Identify what was checked and whether the results apply to the final version. Distinguish completed checks, planned checks, expected benefits, and unverified areas. Summarize findings and link useful records; avoid dumping raw logs, tool transcripts, or every intermediate test run. Mention earlier failures when they reveal a remaining limitation or affect confidence in the final result.
- **Make references usable.** Link material the intended reviewer can access, label it clearly, and explain what it establishes. Retain essential context in the body. Avoid relying on temporary local paths, session-only artifacts, or unexplained links as the sole evidence for a claim.
- **Direct attention where needed.** Ask a concrete review question when a decision or uncertainty needs judgment. Explain the relevant expertise and timing when useful. Separate an unresolved question from an established result.
- **Publish only the completed description.** Remove instructional text, placeholders, generic examples, and unused optional prompts. Omit empty optional sections unless repository conventions require them. Use short paragraphs or simple lists, with restrained headings and emphasis.

Before submitting, reread the title and body together. Confirm that they describe the same final change, that significant claims have an identifiable basis, and that limitations and review requests are easy to find. Remove duplication and development history that do not change a reader's understanding or decision.

## Title

Give readers a concise, specific summary that makes sense on its own.

Name the action and the behavior or component affected. Prefer a concrete outcome over vague phrases such as "Fix bug" or "Update code." An imperative verb such as "Preserve," "Add," or "Document" is a useful starting point. Keep the distinguishing information easy to scan, and update the title if the change evolves during review. Prefixes, issue identifiers, and length limits remain separate conventions to decide later.

**Template**

```markdown
[Action] [specific behavior or component] [distinguishing outcome, if useful]
```

**Generic examples (illustrative)**

```markdown
Preserve selected filters when retrying an export
Document how to recover an interrupted export
```

## Body

Explain the change for someone who has not followed its development. Connect the intended outcome to supporting evidence and remaining uncertainty, and keep the description accurate as review changes the implementation. Use numerical metrics where they help assess a claim; otherwise, describe an observable outcome. When a measurable target matters, state the target and its basis, such as a requirement or an existing baseline.

If you need feedback on a particular decision or unverified behavior, state the specific question in the relevant section. Explain what kind of feedback is needed, who has relevant expertise and why, and any timing or readiness context. A targeted review request helps direct attention while the body still explains the overall change.

### Purpose

Explain why the change is needed, who it affects, and what problem or opportunity motivates it.

Give readers enough context to understand the need without having participated in earlier conversations. Describe the current situation and its consequence for users, operators, or maintainers; for a new capability, explain the need it serves. Include relevant history or a requirement when it clarifies the motivation, and summarize the essential context alongside any supporting link. Keep implementation details and the resulting behavior in Change, and distinguish established facts from assumptions or reported experiences.

**Template**

```markdown
[Affected people or workflow] currently [experience a problem or lack a capability]
when [relevant situation or trigger]. This matters because [concrete consequence
or unmet need].

[Relevant history, requirement, or reason the change is needed now, if useful.]
[If the need rests on an assumption or report, identify that basis.]

Related context: [descriptive link, with the essential explanation retained above].
```

**Generic example (illustrative)**

```markdown
Support staff download filtered activity reports to investigate customer queries.
When a search returns no records, the download action currently produces no file
and gives no explanation. Staff cannot tell whether the report is empty or the
download failed, so they repeat the request or ask colleagues to investigate.

The reporting workflow needs a clear outcome for an empty result so staff can
finish these investigations without guessing whether the download succeeded.
```

### Change

Describe what becomes different when this change is introduced, so readers can understand the resulting behavior or capability.

Explain the outcome in terms meaningful to the people who use or maintain the affected system, including the previous behavior when comparison helps. Connect implementation details to that outcome instead of presenting a list of edited files, functions, or components. For visual changes, include labeled before-and-after screenshots or a recording when they make the difference easier to understand, with a short written explanation. Keep this account aligned with the final implementation; place reasons for the approach under Rationale and evidence of correctness under Evidence.

Make success observable: describe the expected result under relevant conditions, including important failure cases. Link an existing requirement when useful, retaining the essential expectation here. Put what was actually observed under Evidence so readers can compare the intention with the result.

**Template**

```markdown
[Describe the resulting behavior, capability, or internal change.]

Before: [Describe the previous behavior, if useful.]
After: [Describe what now happens, including conditions that affect it.]

Successful outcome: [What observable behavior establishes that the change
meets its purpose? Include relevant conditions or a justified numerical target.]

[Explain implementation details where they help readers understand the outcome.]

Visual comparison, if helpful:
[Link or embed labeled before-and-after images or a recording;
explain what readers should notice.]
```

**Generic example (illustrative)**

```markdown
Filtered exports now contain only the records shown by the active filters.

Before: Downloading an export included every record, even when the page
displayed a filtered list.
After: Downloading an export applies the same filters as the list.
With no filters selected, the export includes all records.

Successful outcome: With a fixed dataset, the exported record IDs exactly
match the IDs selected by the active filters, with no missing or extra records.
When no records match, the file contains column headings only.
```

### Rationale

Explain why the chosen approach makes sense, preserving the reasoning a reader cannot readily infer from the change itself.

Describe the meaningful decisions and the constraints that shaped them, giving enough context for someone unfamiliar with the earlier discussion. Mention alternatives when they clarify the choice, and make consequential tradeoffs or shortcomings explicit; an exhaustive history of rejected approaches is unnecessary. Link supporting design or repository documentation while keeping the essential reasoning here, and refresh this explanation if the approach changes during review.

**Template**

```markdown
We chose [approach] because [reason connected to the problem].
[Relevant constraint or existing behavior] shaped this decision by [effect].
We considered [meaningful alternative], but chose [approach] because [tradeoff].
This accepts [limitation or cost] in exchange for [benefit].
Further reasoning: [optional descriptive documentation link].

Review request, if needed: [Which decision or tradeoff needs assessment?
What feedback is needed, from whom and why, and at what stage?]
```

Use only the prompts that contribute useful reasoning; a straightforward change may need just one sentence.

**Generic example (illustrative)**

```markdown
We chose to generate large CSV downloads in a background job because users
need to leave the export page without losing their request. The existing
notification service provides a way to tell them when the file is ready.

We considered keeping the download request open, but that would leave users
dependent on an uninterrupted connection throughout generation. A background
job adds temporary file storage and cleanup responsibilities in exchange for
allowing the request to survive browser navigation. It also means the file
reflects data at generation time; request-time snapshots remain unsupported.

Review request: Before we finalize the approach, please ask a reporting
maintainer to assess whether generation-time data meets users' expectations
or whether preserving a request-time snapshot is necessary.
```

### Evidence

Explain what has actually been checked, what was observed, and what remains unverified.

Describe relevant checks already completed and their results, with enough detail about the data, environment, or conditions to make the evidence understandable. Include screenshots, recordings, measurements, or links to supporting results when they help, while retaining the essential findings in the body. State limitations plainly, distinguish planned checks and expected benefits from observed results, and update this account if the implementation changes during review.

Connect each significant claim to an appropriate check and compare the expected outcome with the observed result. A passing test count alone does not explain whether the intended behavior was checked. For performance claims, include relevant baseline and changed measurements under comparable conditions. Give reviewers enough detail to inspect the supporting material, repeat a check, or request a demonstration when that helps them assess the behavior.

**Template**

```markdown
- Completed checks: [What did you test, inspect, or demonstrate?]
- Conditions: [Relevant inputs, environment, dataset, and version tested.]
- Expected outcome: [Which intended behavior or claim did the check assess?]
- Observed result: [What actually happened, and how did it compare with the
  expectation? Include baseline and changed measurements when relevant.]
- Supporting evidence, if useful: [Links, screenshots, recordings, or measurements,
  with a brief explanation of what they establish.]
- How to verify, when useful: [Steps, test reference, or demonstration that lets
  a reviewer assess the result; retain essential findings in this body.]
- Unverified areas: [What has not been checked, and why?]
- Planned checks, if any: [Clearly identify checks not yet completed.]
- Review request, if needed: [Which uncertainty needs the reviewer's attention?]
```

**Generic example (illustrative)**

```markdown
Completed check: Compared a filtered CSV export with the records selected
by the same filters in a desktop browser, using a fixed 250-record sample.

Expected outcome: The selected filter matches 37 records. The CSV should
contain exactly those 37 record IDs, with no missing or extra records.

Observed result: The CSV contained the same 37 IDs. An additional check with
no matching records produced a file containing column headings only.

Supporting evidence: [Export check results](docs/validation/filtered-export.md)
records the sample, filter values, and compared IDs.

How to verify: Apply the recorded filters to the sample, download the CSV,
and compare its record IDs with the IDs selected by the filters.

Unverified areas: Concurrent edits and datasets above 250 records were not
checked. These results demonstrate behavior only under the stated conditions.

Planned check: Repeat the comparison while a record changes during export.
Review request: Confirm the intended behavior when records change between
viewing the list and requesting the download.
```

### Implications

Explain the consequences readers need to understand when adopting, deploying, operating, or recovering from this change.

Describe relevant effects on existing users, integrations, stored data, and dependent components, and any necessary action. Where sequence matters, explain prerequisites, migration or deployment order, and how recovery would work, including its limits. Identify meaningful risks, uncertainties, and known limitations with concrete explanations. Include applicable details, link to supporting documentation, and update this account if the implementation changes during review.

**Template**

```markdown
Existing users and integrations: [What changes, for whom, and what must they do?]
Dependencies and prerequisites: [Required versions, configuration, or coordinated changes.]
Migration and deployment: [Necessary data changes, ordering, and temporary effects.]
Risks and limitations: [What could go wrong, known uncertainty, and relevant mitigations.]
Recovery: [How to reverse or contain the change, and what recovery cannot undo.]
Supporting guidance: [Relevant documentation links, with the essential action summarized here.]
```

**Generic example (illustrative)**

```markdown
CSV downloads change the exported_at field from a date (2026-01-15) to a
UTC timestamp (2026-01-15T14:30:00Z). Consumers that accept only dates must
update their parser before the new exporter is deployed. Deploy readers
that accept both formats first.

The main risk is rejection of new downloads by an overlooked consumer.
Reverting the exporter restores the old format for subsequent downloads,
but files already downloaded retain timestamps. Keep the compatible readers
in place during recovery. See [CSV format guide](docs/csv-format.md) for
the field definition and parser examples.
```

### References

Help readers find supporting issues, decisions, and documentation while keeping the PR understandable on its own.

Link material that explains the need, supports a decision, or describes how to use or maintain the resulting behavior. Give each link a descriptive label and explain its relevance; distinguish background from documentation updated by this PR. Keep essential facts and decisions in the body in case linked resources become unavailable or require restricted access. Where practical, link to the relevant section and use a stable reference when the historical version matters.

**Template**

```markdown
- Related issue or requirement: [Descriptive title](link) — Identify the need it records.
- Design or decision: [Descriptive title](link) — Identify the decision or constraint relevant to this PR.
- Repository or product documentation: [Descriptive title](link) — Explain its relevance and whether this PR updates it.
- Validation record, if useful: [Descriptive title](link) — Identify the claim
  it supports; summarize the expected and observed results under Evidence.

Essential context from references: [Summarize what readers need if the linked
material is unavailable or inaccessible.]
```

**Generic example (illustrative)**

```markdown
- Related request: "Explain empty downloads" (issue #128) — Records reports
  that a download containing only column headings appears broken.
- Design decision: [Empty export behavior](docs/decisions/empty-exports.md) —
  Explains why the download remains available when no records match.
- User documentation: [Download results](docs/help/downloads.md#empty-results) —
  Updated by this PR to explain that an empty result produces a file
  containing column headings only.

The essential decision is captured above: empty results remain downloadable,
and the interface explains what the file contains.
```
