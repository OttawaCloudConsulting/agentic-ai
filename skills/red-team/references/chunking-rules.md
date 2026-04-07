# Smart Chunking Rules

When the resolved artifact exceeds **1500 lines**, the orchestrator splits it into
logical sections before distributing to agents. This file defines the splitting
strategies and section assignment rules.

## Threshold

- **1500 lines** across all resolved files (sum of line counts for multi-file artifacts).
- If the artifact is ≤ 1500 lines, skip chunking entirely.

## Splitting Strategies

Split by artifact type (from Step 2 classification). Always prefer logical boundaries
over fixed line counts.

### Code

Split at **top-level declarations** — functions, classes, modules, or exported blocks.

1. Scan for top-level function/method definitions, class declarations, and module blocks.
2. Each declaration (with its body) becomes one section.
3. File-level imports, constants, and type declarations form a "preamble" section included
   in every agent's assignment (they need context on types and imports).
4. If a single declaration exceeds 500 lines, split it further at method boundaries
   (for classes) or logical blocks (for long functions).

### Architecture / Design

Split at **top-level headings** (`##` in Markdown).

1. Each `##` heading and its content (up to the next `##`) becomes one section.
2. The document title (`#`) and any introductory content before the first `##` form a
   "preamble" section included in every agent's assignment.
3. If a single section exceeds 500 lines, split at `###` sub-headings.

### PRD / Proposal

Split at **top-level headings** (`##` in Markdown), same as Architecture / Design.

### Infrastructure

Split at **resource or module boundaries**.

1. **Terraform:** Each `resource`, `module`, or `data` block becomes one section.
   `provider`, `variable`, `output`, and `locals` blocks form a "preamble" section.
2. **CDK:** Split at construct definitions (classes extending `Construct` or `Stack`).
3. **CloudFormation:** Split at top-level resource keys under `Resources:`.
4. If a single resource/module exceeds 500 lines, split at nested block boundaries.

### Other / Unknown

Split at **fixed line intervals** of 400 lines with 50-line overlap between sections.
Overlap prevents findings from being lost at section boundaries.

## Section Identifiers

Every section gets a stable identifier for traceability:

```
§{name}:{start-line}-{end-line}
```

- **name:** Derived from the section's logical label — function name, class name, heading
  text (kebab-cased), or resource name. For fixed-interval splits, use `chunk-N`.
- **start-line / end-line:** 1-based line numbers in the original artifact.
- **Multi-file:** Prefix with filename: `§{filename}:{name}:{start-line}-{end-line}`

Examples:
- `§authenticate-user:45-120` — a function named `authenticateUser` at lines 45-120
- `§design-decisions:88-145` — a `## Design Decisions` heading at lines 88-145
- `§auth-api.py:UserAuth:12-95` — class `UserAuth` in `auth-api.py`

## Preamble Sections

Most splitting strategies produce a "preamble" — imports, type declarations, introductory
content, or shared configuration. The preamble is:

- Included in **every** agent's assignment (not counted as a separate section).
- Not assigned a standalone identifier — it provides context, not review scope.
- Kept as compact as possible (if the preamble alone exceeds 200 lines, summarize it
  and include only the summary).

## Section Assignment

Each agent receives **all sections** by default. When the total section count exceeds 6,
distribute sections across agents to keep each agent's input manageable:

### Distribution Rules

1. **All agents get the preamble** (always).
2. **All agents get sections flagged as high-risk** — entry points, authentication,
   error handling, public APIs, executive summary, security-related sections.
3. **Remaining sections distributed round-robin** across agents, ensuring each section
   is assigned to at least one agent.
4. **Overlap:** Each agent also receives the sections immediately adjacent to its assigned
   sections (±1) so boundary issues are not missed. Adjacent sections are marked as
   context-only — agents should not generate primary findings for context-only sections
   but may reference them as evidence.

### Lens-Aware Assignment

When sections have clear relevance to specific lenses, prefer assigning them accordingly:

| Section Content | Preferred Lens |
|-----------------|---------------|
| Authentication, authorization, input validation, crypto | Security |
| Requirements, constraints, stated assumptions, dependencies | Assumptions |
| Error handling, edge cases, missing features, test coverage | Completeness |
| Abstractions, coupling, naming, patterns, extensibility | Design |

This is a preference, not a hard rule. Every section must be assigned to at least one agent.

## Edge Cases

- **Single-file artifact at exactly 1500 lines:** Not chunked (threshold is "exceeds").
- **Multi-file artifact where each file is small but total exceeds 1500:** Chunk with
  file boundaries as the primary split points. Each file becomes one or more sections.
- **Binary or non-text content mixed in:** Skip binary files, note them in the summary.
- **Artifact with no logical boundaries** (e.g., minified code): Fall back to fixed-interval
  splitting with 400-line chunks and 50-line overlap.
