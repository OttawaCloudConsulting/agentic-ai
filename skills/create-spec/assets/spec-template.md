# Spec: [Title]

<!--
Seeded from: [~/.claude/plans/<file>.md | this conversation]

Identifier convention: requirements are numbered (1, 2, 3a...), decisions are D<n>, risks are
R<n>. These IDs are reused verbatim in prd.md, docs/ARCHITECTURE_AND_DESIGN.md, and
progress.txt. Do not renumber them.
-->

## Context

<!-- What exists now, and why it is inadequate. Name the files, systems, and behaviours
involved. A reader who has not been in the discussion should be able to start here.

State verified facts with what verified them — a command, a file and line, an observation and
its date. Anything you believe but have not checked belongs in Open assumptions, not here. -->

[Current state]

[Why it is inadequate]

## Requirements

<!-- Numbered, testable, one line each. Every acceptance criterion below traces back to one of
these numbers. Sub-letter a requirement that has distinct parts (4a, 4b) so criteria can cite
the part rather than the whole.

"Fast", "reliable", and "clean" are not requirements. "Responds within 500ms at p95" is. -->

1. [Requirement]
2. [Requirement]
3. [Requirement]

<!-- Split functional from non-functional only when there is enough of each to justify it. -->

## Out of scope

<!-- Transcribes directly into the PRD's Non-Goals table. Every exclusion carries a reason —
"deferred", "handled elsewhere", "explicitly rejected, see D<n>". An exclusion without a
rationale gets re-litigated later. -->

| Item | Rationale |
|------|-----------|
| [Excluded item] | [Why excluded or deferred] |

## Approach

<!-- The chosen design, in prose. What gets built or changed, and how the pieces fit.

Alternatives get one line each and a reason they lost. If the alternatives need a table, a
scoring matrix, or their own document, this work has outgrown /create-spec — use /project. -->

[Design]

**Decisions**

| ID | Decision | Rejected alternative | Why |
|----|----------|---------------------|-----|
| D1 | [What was decided] | [What was not chosen] | [Reason] |

## Interface contracts

<!-- The light pipeline has no Gate 4, so this is the only place contracts are captured before
code. Include, for each interface: function/method signatures, data shapes (types/schemas),
event formats, configuration, failure semantics, and implementation constraints.

Failure semantics are the part most often skipped and most often the source of the bug. State
what happens on timeout, on malformed input, and on partial success. -->

### [Interface name]

- **Shape:** [signature, schema, or event format]
- **Configuration:** [parameters, defaults, where they come from]
- **Failure semantics:** [behaviour on error, timeout, partial success — fail open or closed]
- **Constraints:** [anything the implementation must or must not do]

## Acceptance criteria

<!-- Testable, and traceable. Every requirement number appears at least once in this table. -->

| # | Criterion | Requirement | How verified |
|---|-----------|-------------|--------------|
| 1 | [Observable outcome] | 1, 2 | [Command, check, or observation] |

## Risks

<!-- Same shape as the PRD's Risk Assessment table, so it transcribes without rework. -->

| ID | Risk | Mitigation |
|----|------|-----------|
| R1 | [What could go wrong] | [What reduces it, or "accepted"] |

## Open assumptions

<!-- What is still unconfirmed. Each entry is a question with a stated default, so work can
proceed if it stays unanswered. /create-prd raises these again in Round 5.

An empty section is a real answer — write "None." rather than deleting the heading. -->

| Assumption | Assumed because | Impact if wrong |
|------------|-----------------|-----------------|
| [What is being assumed] | [Basis for assuming it] | [What breaks] |

## External dependencies

<!-- Include only when the work is blocked on or coupled to something outside it. Delete
otherwise. -->

| Dependency | Owner | Status |
|------------|-------|--------|
| [What is needed] | [Who provides it] | [Available / pending / blocked] |

## References

<!-- Source documents, prior plans, research artifacts, upstream docs, and any /red-team pass
run against this spec. Paths and URLs, not descriptions. -->

- [path or URL]
