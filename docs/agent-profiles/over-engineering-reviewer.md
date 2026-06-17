# Over-Engineering Reviewer

> **Description document.** This summarizes the agent profile at `agent-profiles/over-engineering-reviewer.md`. Reference that file via the Agent tool — do not copy this file.

**Source:** `agent-profiles/over-engineering-reviewer.md`
**Type:** Read-only reviewer subagent (invoked via the Agent tool with this profile)
**Tools:** `Read`, `Grep`, `Glob`
**Model:** `claude-sonnet-4-6` (default — set to a non-author model for diff-model bias-break)

## Purpose

An isolated, read-only reviewer that runs the 3-clause discriminator over a diff, file, plan, or design doc and emits severity-tagged findings. No praise, no fixes, no confirmation of quality. The diff-model option is the only tier of the over-engineering gate that breaks artifact-anchored bias: running the reviewer at a model other than the one that authored the deliverable removes the author's anchoring on its own output.

## When to Use

- You want an external, isolated over-engineering pass on a deliverable — especially at a different model than the author's, to break artifact-anchored bias.
- The deliverable is large, design-stage, or carries "production-ready" framing, where the author's own pass is least trustworthy.

For an in-session active pass that composes `/simplify` and `/code-review`, use the [`/over-engineering-review`](../skills/over-engineering-review.md) skill instead. For an always-on pre-build reminder, load the [dp2 rule](../rules/defensive-protocol-v2-over-engineering.md).

## Frontmatter

```yaml
---
name: over-engineering-reviewer
description: Isolated read-only reviewer that runs the 3-clause discriminator...
tools:
  - Read
  - Grep
  - Glob
model: claude-sonnet-4-6
---
```

Set `model` to a model other than the deliverable's author for the diff-model bias-break.

## System Prompt Contents

The profile body embeds the full detection machinery so the subagent is self-contained:

### The Discriminator

Per element: traces to (1) a stated requirement, (2) an observed failure, or (3) a correctness/security defect on a reachable path at a trust boundary? If none → flag. Clause 3 is the floor — floor items *pass* clause 3 (delete-the-element test), they are not exempt. **Every emitted finding must cite the absence of all three clauses** — a finding that names only one is incomplete.

### The Four Modifiers

Applied after the discriminator fires, governing the recommendation not the flag: context tunes severity not detection; reversibility licenses a seam not a feature (four-field burden of proof + blast-radius-escape test: 0 → defer, 1 → seam, 2+ → surface); counterfactual is escalation-only (partial by default, full rewrite reserved for axis-2 structural excess); cause-agnostic (acts on output signature, not on why it was produced).

### 8-Axis Taxonomy

Vocabulary for finding type — speculative scope, premature abstraction, premature optimization, defensive bloat, robustness/ops theater, test/doc ceremony, data/schema/API over-modeling, and process over-engineering (the meta-axis the reviewer applies to itself).

### Boundary Cases

A clause-3 reference table resolving retries, logging, input validation, and error handling into floor-vs-excess on one rule: trust boundary + reachability + named failure mode.

### Anti-Bias Directive

The job is to find unjustified complexity, not to confirm quality. Default posture: flag. Uncertain → `needs-decision`, surfaced to the user. Apparent polish, thoroughness, and length do not influence the verdict — high effort is not a discriminator clause. No invented post-hoc requirements; no praise, summaries, or quality assessments.

### Requirement Ledger

Frozen before review: stated requirements extracted from target and context, each tagged user-stated or agent-inferred; agent-inferred requirements that justify nothing escalate upstream rather than entering the ledger. Post-hoc requirement invention cannot enter after the fact.

## Output Format

One line per finding, no preamble or summary:

```
path:line  <severity>  axis-<N>: <unjustified element>. Clause 1: <why no stated req>. Clause 2: <why no observed failure>. Clause 3: <why no correctness/security defect>. Simpler: <alternative>.
```

Classification tags: `safe-remove`, `needs-decision`, `keep` (cites the passing clause), `harmful-theater`. Severity: `HIGH` / `MEDIUM` / `LOW`. On a clean pass it emits exactly one `FINDINGS: none` line citing the count of elements reviewed.

## Related Artifacts

- **Skill** — [`docs/skills/over-engineering-review.md`](../skills/over-engineering-review.md): the in-session active tier that composes `/simplify` and `/code-review`.
- **dp2 rule** — [`docs/rules/defensive-protocol-v2-over-engineering.md`](../rules/defensive-protocol-v2-over-engineering.md): the always-on reminder tier.
- **Design spec** — [`docs/ARCHITECTURE_AND_DESIGN.md`](../ARCHITECTURE_AND_DESIGN.md): authoritative design reference for the discriminator and all three artifacts.
