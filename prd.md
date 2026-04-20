# PRD: architecture-doc

<!-- Planning artifact for building the architecture-doc skill. -->
<!-- Target skill location: skills/architecture-doc/ -->

## Summary

A standalone, reusable Claude Code skill that produces and maintains
`docs/ARCHITECTURE_AND_DESIGN.md` for any codebase — whether the document
is missing (create mode) or already exists (audit / update mode). The skill
operates independently of the `/project → /define → /design` flow, closing
the documentation gap for code that was built outside standard patterns
(imported repos, prototypes, legacy subdirectories, ad-hoc scripts). Output
conforms to the canonical template at
`skills/project/design/assets/architecture-template.md`, and the skill
opportunistically uses any MCP servers present in the session to enrich
its scan and synthesis.

## Goals

- Generate `docs/ARCHITECTURE_AND_DESIGN.md` for codebases that do not have
  one, matching the quality bar and structure of documents produced by
  `skills/project/design/`.
- Audit and update an existing `docs/ARCHITECTURE_AND_DESIGN.md` when one is
  already present, preserving user-authored content and extending it with
  findings from the current code state.
- Run entirely standalone: no `prd.md`, no `progress.txt`, no gate state
  required; the skill is usable on any directory with source code.
- Use the canonical `architecture-template.md` (not a vendored copy) as the
  structural guide for every produced document.
- Align with the orchestration pattern in `skills/project/design/` — SKILL.md
  orchestrator, `assets/` for templates, `references/` for heuristics,
  sub-agents spawned via the Agent tool for context isolation.
- Auto-detect MCP servers at runtime and opportunistically use them to enrich
  the scan and synthesis; degrade gracefully when none are present.
- Be invokable as a slash command (`/architecture-doc`) and via natural-language
  triggers ("document this architecture", "there's no design doc, create one",
  "audit the architecture doc against the current code").

## Non-Goals

| Item | Rationale |
|------|-----------|
| Generating or modifying `prd.md` | `/create-prd` owns PRD authoring. This skill is architecture-only. |
| Progress / gate tracking integration | No `progress.txt`, no gate state, no `/start-feature` handoff. Standalone by design. |
| Editing source code | Documentation only. The skill never modifies source files, even if obvious issues surface during the scan. |
| Multi-repo or cross-submodule scans | Scope is the single working-directory tree. Scans do not cross repo boundaries or follow git submodules. |
| Blocking or warning when the `/project` flow is active | Skill always runs regardless of detected `progress.txt` / Gate 2 state; user is trusted to choose the right tool. |

## Architecture

The skill is a SKILL.md orchestrator that spawns two sub-agents (scan, then
synthesis) for context isolation, with a conditional MCP probe at startup
and a produce-then-review loop over the main orchestrator context. Create
and Audit modes share the scan pipeline and diverge only in the synthesis
sub-agent.

```
User invocation (slash or natural language)
        │
        ▼
┌──────────────────────────────┐
│  Orchestrator (SKILL.md)     │
│  - Existing-doc detection    │
│  - Mode selection            │
│  - MCP capability probe ◄──── conditional, no sub-agent
└─────────┬────────────────────┘
          │ spawns
          ▼
┌──────────────────────────────┐    reads    ┌─────────────────────────┐
│  Scan sub-agent              │────────────▶│  Codebase               │
│  (Read / Glob / Grep + MCP)  │             │  (source, config, docs) │
│  - Source architecture scan  │             └─────────────────────────┘
│  - Existing-doc harvesting   │ findings
└─────────┬────────────────────┘   file
          │
          ▼
┌──────────────────────────────┐
│  Synthesis sub-agent         │
│  ┌─ Create mode ─┐           │  template: skills/project/design/
│  │ Write new doc  │           │            assets/architecture-template.md
│  ├─ Audit mode ──┤           │
│  │ Edit existing  │           │
│  └────────────────┘           │
└─────────┬────────────────────┘
          │
          ▼
┌──────────────────────────────┐
│  Produce-then-review         │
│  - Tradeoff callouts         │
│  - Approve / Revise / Partial│
└─────────┬────────────────────┘
          │
          ▼
   docs/ARCHITECTURE_AND_DESIGN.md
```

## Features

### Feature 1: Existing-document detection and mode selection

Before any scanning, detect whether `docs/ARCHITECTURE_AND_DESIGN.md` already
exists and interactively choose between Create, Audit, or Abort modes.

**Acceptance Criteria:**

- Checks for `docs/ARCHITECTURE_AND_DESIGN.md` at the working-directory root
  before any other work.
- If absent, enters **Create mode** automatically.
- If present, presents an `AskUserQuestion` prompt with Create (Overwrite),
  Audit (update in place), Abort.
- If the existing file is unreadable, empty, or not plausibly Markdown,
  offers only Overwrite or Abort.

### Feature 2: MCP capability probe

At startup, detect which MCP servers are connected in the current session and
record which capabilities are available for enriching the scan and synthesis.

**Acceptance Criteria:**

- Probe runs in the orchestrator context by enumerating tool names carrying
  the `mcp__` prefix in the current session. No dedicated probe sub-agent.
- Detected tools are categorised (diagram rendering, code search, language
  server, repo intelligence, other) using the rules in
  `references/mcp-probe.md`.
- Detected categories are recorded in `docs/.architecture-doc/run.log`, not
  in the findings file (which is owned by the scan sub-agent).
- Degrades gracefully: if no MCP servers are present the skill still produces
  a full document using only Read/Bash/Glob/Grep.

### Feature 3: Architecture-focused codebase scan (scan sub-agent)

Spawn a sub-agent to read the codebase using the architecture heuristics from
`skills/project/design/references/gate-2-design.md`. Shared by both Create
and Audit modes.

**Acceptance Criteria:**

- Sub-agent is spawned via the Agent tool with tool access limited to Read,
  Glob, Grep, Bash (for `ls` / `git log` orientation only), and any
  enriching MCP tools detected by Feature 2.
- Sub-agent is constrained to read only paths inside `target_path`;
  orchestrator validates every path before passing it to the agent and
  rejects anything that resolves outside the tree. Symlinks are never
  followed during enumeration.
- Agent runs an orientation pass (`ls -R` first 2 levels, `git log --oneline -20`)
  before file selection.
- **Preflight checks** during orientation:
  - If `target_path` contains no source files, abort cleanly with a message
    and write nothing.
  - If `target_path` contains only binaries / images / non-text files,
    abort cleanly with a message and write nothing.
  - If a monorepo is detected (lerna, nx, turbo, multiple `package.json`,
    `go.mod`, or `Cargo.toml` at different depths), emit a warning,
    surface it to the orchestrator, and continue only after the
    orchestrator confirms with the user via `AskUserQuestion`.
- Agent selects and reads 15–30 files using the five heuristic categories
  from `gate-2-design.md` (Component Boundaries, Data Flow Patterns,
  Interface Contracts, Technology Choices, Infrastructure).
- Agent writes structured findings to `docs/.architecture-doc/findings.md`
  with the five heuristic sections plus an **Existing Documentation**
  section (populated by Feature 4).
- Scratch file and its parent `docs/.architecture-doc/` directory are
  cleaned up at end of run (success or abort).

### Feature 4: Existing-documentation harvesting

Always enumerate and summarise in-repo documentation during the scan so the
produced document augments rather than ignores prior writing. Runs
unconditionally in both Create and Audit modes.

**Acceptance Criteria:**

- Scan sub-agent enumerates `README*`, `docs/**/*.md`, `ADR*/**`, `RUNBOOK*`,
  diagram files (`.mmd`, `.drawio`, `.puml`), and other likely doc paths.
- Contents are summarised in the findings scratch file under
  **Existing Documentation**.
- Synthesis sub-agent cites the source file when a design decision,
  component, or flow is drawn from pre-existing documentation rather than
  inferred from code.

### Feature 5: Synthesis sub-agent — Create mode

Spawn a second sub-agent to synthesise scan findings into a fresh
`docs/ARCHITECTURE_AND_DESIGN.md`. Runs only when the user chose Create
(file absent or Overwrite).

**Acceptance Criteria:**

- Sub-agent is spawned via the Agent tool with tool access limited to
  `Read`, `Write` (restricted to the output doc path), `Glob`, `Grep`.
  No `Bash`, no `Edit`, no `Agent`, no network tools.
- Sub-agent reads the canonical template from
  `skills/project/design/assets/architecture-template.md` (not a vendored
  copy).
- Populates all six required sections: Design Decisions, Component
  Inventory, Data Flow, File Organization, Deployment & Operations,
  Security Considerations.
- **Security Considerations** is populated ONLY from evidence observed in
  the scan (auth middleware, encryption libraries, cert handling, secrets
  management). No generic best-practices boilerplate. If nothing relevant
  was observed, the section is a single sentence stating so.
- Design Decisions table targets 10–20 entries for substantial codebases;
  for small codebases, captures every non-obvious choice observable in the
  code.
- Every Design Decision row cites at least one source file path or existing
  doc; uncertain rows are marked `(inferred)`.
- Tradeoff and Alternatives columns are populated, not left blank.
- Creates `docs/` if it does not exist.

### Feature 6: Synthesis sub-agent — Audit mode

When the user chose Audit, spawn the synthesis sub-agent in update mode to
extend the existing doc in place, preserving user-authored content.

**Acceptance Criteria:**

- Sub-agent is spawned via the Agent tool with tool access limited to
  `Read`, `Edit` (restricted to the existing output doc path), `Glob`,
  `Grep`. No `Write`, no `Bash`, no `Agent`, no network tools.
- Sub-agent uses Edit (not Write) for all modifications.
- Adds new Design Decisions as appended rows rather than rewriting the
  table.
- Preserves user-authored prose, sections not in the canonical template,
  and formatting choices.
- Flags contradictions between the existing doc and the current code state
  in a clearly marked **Audit Findings** section at the top of the doc for
  the user to resolve. Does not silently overwrite contradicted content.
- Never removes existing entries that are not directly contradicted by new
  findings.

### Feature 7: Produce-then-review cycle

After the synthesis sub-agent produces or updates the document, return
control to the orchestrator for a review loop using the same
produce-then-review pattern as `/design`, with section-level partial
approval.

**Acceptance Criteria:**

- Presents a summary highlighting key decisions, component inventory, data
  flow, and security approach.
- Surfaces 2–4 tradeoff callouts chosen using the heuristic from
  `gate-2-design.md` (genuinely viable alternatives, multi-component impact,
  expensive reversal).
- Offers Approve / Revise / Partial via `AskUserQuestion`.
- On Partial, presents a multiSelect of the six canonical sections; for each
  unchecked section asks what should change and re-applies edits via the
  Edit tool in the orchestrator context.
- Loop terminates only when the user selects Approve.

### Feature 8: MCP-enriched synthesis (conditional)

When specific MCP servers are detected by Feature 2, use them to enrich the
produced document without making any of them required.

**Acceptance Criteria:**

- Enrichments are **opt-in per run**: when the probe detects a relevant MCP,
  the orchestrator asks the user via `AskUserQuestion` whether to enable the
  enrichment. No silent auto-enablement between runs.
- If a diagram-rendering MCP (e.g. `mermaid-mcp`) is present, offers to embed
  generated component and data-flow diagrams in the document. Per
  `CLAUDE.md`, Mermaid node labels use `<br/>` for line breaks.
- If a code-intelligence or language-server MCP is present and the user
  opts in, the scan sub-agent uses it to improve symbol and reference
  resolution during file selection.
- If no enriching MCPs are present, the document is produced unchanged from
  the baseline path — no degraded output, no placeholder diagrams, no
  opt-in prompts.

## Configuration

The skill is deliberately minimal in configuration surface — a single
optional positional argument.

### Required

| Parameter | Type | Description |
|-----------|------|-------------|
| _(none)_ | | The skill derives all required context from the current working directory and detected session state. |

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `target_path` | path (positional) | current working directory | Directory to scan and document. When invoked as `/architecture-doc path/to/subdir`, the skill treats that path as the project root for the scan and writes the doc to `<target_path>/docs/ARCHITECTURE_AND_DESIGN.md`. |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `docs/ARCHITECTURE_AND_DESIGN.md` | Markdown file (relative to `target_path`) | The produced or updated architecture document — the primary artifact. |
| Session summary | Terminal output | Final report: mode used (Create / Audit), files scanned, decisions captured, components inventoried, MCP enrichments applied, review iterations performed. |
| `docs/.architecture-doc/run.log` | Scratch log (ephemeral) | Per-run execution log written alongside `findings.md`. Captures sub-agent spawns, tool calls, preflight results, redactions performed, review loop iterations. Removed with the rest of `docs/.architecture-doc/` at end of run. |

## Risk Assessment

<!-- Extended in Rounds 2, 4, and 5 (Step 2). -->

| Risk | Mitigation |
|------|-----------|
| Hallucinated design decisions (decisions not actually present in code) | Synthesis sub-agent instructed that every Design Decision row must cite at least one file path or doc source. Uncertain rows are marked `(inferred)`. Produce-then-review step surfaces decisions for user validation before approval. |
| Leaking secrets into findings or produced doc | Scan sub-agent MAY read secret-bearing files (`.env*`, `*.pem`, `*.key`, `credentials*`, `.aws/credentials`, etc.) to understand what env vars and credentials the code consumes, but MUST redact the actual values before writing anything to findings or output. A secrets-regex pass (common token/key patterns) runs over the findings file and output doc before any write. |
| Path traversal or unexpected file access | Scan sub-agent is constrained to paths inside `target_path`. Orchestrator validates every path passed to the agent and rejects anything that resolves outside the tree. Symlinks are never followed during enumeration. |
| Scratch files left behind after session | Scratch findings (`findings.md`) and run log (`run.log`) are written to `docs/.architecture-doc/`; the entire directory is removed at end of run (success or abort). Users should add `docs/.architecture-doc/` to `.gitignore`. |

## External Dependencies

| Dependency | Owner | Status |
|------------|-------|--------|
| `skills/project/design/assets/architecture-template.md` | this repo | stable — canonical template, read in place; skill aborts with an explicit error if missing (no vendored fallback) |
| `skills/project/design/references/gate-2-design.md` | this repo | stable — source of scan heuristics, read in place; skill aborts with an explicit error if missing (no vendored fallback) |
| MCP servers (mermaid, language servers, code search, etc.) | user environment | optional — opportunistic enrichment only, per-run opt-in |

## Success Criteria

- Invoked on an undocumented directory, the skill produces a
  `docs/ARCHITECTURE_AND_DESIGN.md` that a second reviewer rates as accurate
  and complete without having read the code.
- Invoked on a directory where the doc already exists, the skill never
  overwrites it without explicit user consent, and the audit-mode update
  preserves all user-authored content that is not contradicted by the code.

## Future Enhancements

_None parked for this iteration. The skill scope is deliberately bounded to
Create and Audit modes over a single directory. Future additions (e.g.
`/project` flow handoff, ADR extraction, drift detection, per-language
specialisation) are not tracked here and would require a fresh PRD._
