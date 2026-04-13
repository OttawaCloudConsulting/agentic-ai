# /architecture-doc

**Source:** `skills/architecture-doc/`
**Command:** `/architecture-doc [target_path]`
**Activation:** Slash command **and** natural-language invocation. The skill sets `disable-model-invocation: false` (Decision #10) so phrases like "document this architecture", "there is no design doc, create one", or "audit the architecture doc against the current code" route to it automatically.

## Purpose

Standalone skill that produces or maintains `docs/ARCHITECTURE_AND_DESIGN.md` for any codebase, independent of the `/project → /define → /design` flow. Closes the documentation gap for code that was built outside the standard pattern -- imported repos, prototypes, legacy subdirectories, ad-hoc scripts -- without requiring `prd.md`, `progress.txt`, or any gate state. Output conforms to the canonical template at `skills/project/design/assets/architecture-template.md` (read in place; no vendored copy) and opportunistically uses any MCP servers detected in the session to enrich the scan and synthesis.

## When to Use

- A codebase has no architecture document and one is needed.
- An existing `docs/ARCHITECTURE_AND_DESIGN.md` has drifted from the current code and needs to be reconciled.
- The user asks to "document this architecture", "reverse-engineer the architecture", "create an architecture doc", or "audit the architecture doc against the current code".
- Operating on imported third-party code, a legacy subdirectory, or any tree that was never put through `/define → /design`.

## When NOT to Use

- A `/project` flow is active and Gate 2 is the right next step -- use `/design` instead. The skill does **not** detect or block on a `/project` flow (Decision #20); the user is trusted to pick the right tool.
- The PRD already exists and you want to design from it -- use `/design`.
- You want to refresh an architecture doc against accumulated implementation deviations from feature plans -- use `/design` refresh mode (which knows how to read `milestones/*/plans/*.md`).
- You want to modify source code, add tests, or change behaviour -- this skill is documentation-only and never edits source files.

## Behavior

### 1. Path validation and mode selection

Resolves the optional positional `target_path` argument (defaulting to the current working directory) to an absolute canonical path, then tests for `<target_path>/docs/ARCHITECTURE_AND_DESIGN.md`:

- **Absent** → enters **Create mode** silently, no prompt.
- **Present and plausibly Markdown** (readable UTF-8, non-empty, first non-blank line is an ATX heading) → asks the user via `AskUserQuestion` to choose **Create** (overwrite), **Audit** (update in place), or **Abort**.
- **Present but unreadable, empty, or non-Markdown** → offers only **Overwrite** or **Abort** (Audit is suppressed because the file cannot be reliably parsed).

Mode detection runs **before** the MCP probe, so an Abort exits the skill without paying any probe or scan cost.

### 2. MCP capability probe

Enumerates tools whose names begin with the `mcp__` prefix in the current session and categorises them via `references/mcp-probe.md` into `diagram`, `language_server`, `code_search`, `repo_intel`, and `other`. The probe runs in the orchestrator context with no probe sub-agent (Decision #12); the categories drive two later opt-in prompts (`language_server` for the scan, `diagram` for the produced doc). The skill degrades gracefully when no MCP servers are present -- no warning, no banner, no prompts.

### 3. Architecture-focused codebase scan

Spawns a scan sub-agent via the `Agent` tool with a restricted tool surface (`Read`, `Glob`, `Grep`, narrow `Bash` for `ls -R` and `git log --oneline -20`, plus any opted-in language-server MCP tools). The agent runs an orientation pass, then three preflight checks (empty / binary-only / monorepo), then selects 15-30 files using the five heuristic categories from `skills/project/design/references/gate-2-design.md` (Component Boundaries, Data Flow Patterns, Interface Contracts, Technology Choices, Infrastructure). Findings are written to `docs/.architecture-doc/findings.md`. The orchestrator runs a path-boundary post-validation against the findings file's `Files Cited` tail and a secrets-redaction pass before handing off to synthesis. Symlinks are never followed during scan-time enumeration (Decision #9).

### 4. Existing-documentation harvesting

The same scan sub-agent enumerates `README*`, `ARCHITECTURE*`, `DESIGN*`, `CONTRIBUTING*`, `CHANGELOG*`, `RUNBOOK*`, ADR directories, `docs/**/*.md|.mdx|.rst`, and diagram source files (`.mmd`, `.drawio`, `.puml`, `.plantuml`) under a separate 15-file budget that does not consume the architecture scan budget (Decision #21). Each doc gets a 1-3 sentence summary in the findings file under **Existing Documentation**, and synthesis cites source doc files when a Design Decision, Component, or Data Flow entry is drawn from existing documentation rather than from source code.

### 5. Synthesis

A second sub-agent reads the findings file and the canonical template, then produces the output document.

- **Create mode:** writes `docs/ARCHITECTURE_AND_DESIGN.md` from scratch via a single `Write` call. Populates all six required sections (Design Decisions, Component Inventory, Data Flow, File Organization, Deployment & Operations, Security Considerations). Every Design Decision row cites at least one source file or existing doc; uncertain rows are marked `(inferred)`. Tradeoff and Alternatives columns are never blank. Security Considerations is populated only from observed evidence -- no generic boilerplate.
- **Audit mode:** uses `Edit` (never `Write`) to update the existing doc in place. New Design Decisions are appended (never re-ordered). User-authored prose, formatting choices, and non-canonical sections are preserved. Contradictions with the current code state are surfaced in a top-of-doc **Audit Findings** block (Decision #11). Existing entries are never removed unless directly contradicted by new findings. Detailed rules live in `references/audit-mode.md`.

The orchestrator runs a second secrets-redaction pass over the produced or updated document and a soft-warn structural validation against the six canonical section headers.

### 6. MCP-enriched diagram embedding (conditional)

If a diagram-class MCP (e.g. Mermaid) is present in the session, the orchestrator asks the user via `AskUserQuestion` whether to embed component and data-flow diagrams in the produced doc. On opt-in, the orchestrator parses the Component Inventory and Data Flow sections **in-context** and inserts Mermaid blocks (`graph TD` and `flowchart LR`) via `Edit` -- it does not invoke the diagram MCP directly; the MCP's presence is the per-run permission trigger (Decision #22). Mermaid node labels use `<br/>` for line breaks per `CLAUDE.md` and Decision #17. Diagrams are regenerated automatically on every Revise pass and selectively on Partial passes that touched diagram-source sections, so the user always reviews fresh diagrams. If no diagram MCP is detected, no prompt is shown -- the baseline path is unchanged.

The scan-side enrichment opt-in (language-server intelligence during file selection) fires earlier, before the scan agent spawns, and is subject to the same per-run consent and baseline-unchanged rules.

### 7. Produce-then-review loop

After synthesis (and optional diagram enrichment), control returns to the orchestrator -- per Decision #13 the review loop runs in the orchestrator context, not in a sub-agent. Each iteration:

1. Re-reads the output doc and re-validates the six canonical section headers against the **current** state.
2. Parses the Design Decisions table and selects 2-4 tradeoff callouts using the three-clause heuristic from `gate-2-design.md` (viable alternatives, multi-component / long-term impact, expensive reversal).
3. Builds a five-section summary block (header / mode + counts / per-section bullets / tradeoff callouts / gaps) and prints it to the user.
4. Calls `AskUserQuestion` with **Approve** / **Revise** / **Partial**.
   - **Approve** exits the loop.
   - **Revise** asks for free-text changes and applies them via `Edit` calls in the orchestrator context.
   - **Partial** opens a `multiSelect` over the six canonical sections; the user **checks the sections that are approved**, and the orchestrator inverts the result to compute which sections need revision. Each unchecked section is revised in turn via free-text + `Edit`.
5. If diagrams were embedded and the edit pass touched Component Inventory or Data Flow, the orchestrator regenerates the affected Mermaid blocks before looping back to the next summary.

The loop terminates **only** on Approve. There is no iteration cap and no Abort branch in the prompt -- a user who wants to abandon the run uses `Ctrl+C` or tells the orchestrator to stop in free text.

### 8. Cleanup and session summary

Removes `<target_path>/docs/.architecture-doc/` entirely (the only filesystem state the skill leaves behind) and prints a fixed-shape session summary block to the terminal: outcome (`approved` or `aborted: <reason>`), mode, target path, output doc path, files scanned (architecture + documentation), synthesis counts (decisions / components in Create mode; new decisions / audit findings / contradictions in Audit mode), MCP enrichment results (`accepted` / `skipped` / `not_offered` for each side), diagrams embedded, and review iterations. The summary is mirrored as a single fixed-shape line into `run.log` immediately before the scratch dir is removed, so a post-mortem `grep cleanup summary` recovers the same data.

Cleanup runs on **every** code path that reached Step 4 or later -- happy-path Approve, preflight aborts, scan errors, synthesis errors, mid-loop output-missing failures. Early aborts in Step 1 (target_path invalid) and Step 2 (user Abort before any scratch state was created) exit cleanly without entering Step 10 because there is nothing to clean up.

## Modes

| Mode | When | Synthesis tool | Doc lifecycle |
|---|---|---|---|
| **Create** | `docs/ARCHITECTURE_AND_DESIGN.md` is absent, OR the user chose Overwrite from the Step 2 prompt | `Write` (single call, restricted to the output doc path) | Document is produced from scratch using the canonical template. |
| **Audit** | `docs/ARCHITECTURE_AND_DESIGN.md` exists and is plausibly Markdown, AND the user chose Audit | `Edit` only (never `Write`) | Existing document is extended in place. New Design Decisions appended; user content preserved; contradictions surfaced in a top-of-doc Audit Findings block. |

Both modes share the entire scan pipeline (scan sub-agent, preflight, file selection, harvesting, redaction, path-boundary validation). They diverge only in which synthesis prompt block is selected and which tool the synthesis agent is allowed to use.

## Configuration

| Parameter | Type | Default | Description |
|---|---|---|---|
| `target_path` | path (positional, optional) | current working directory | Directory to scan and document. Resolved to its absolute canonical form; symlinks **in `target_path` itself** are followed (a user invoking from a symlinked project root is supported), but symlinks encountered during scan-time enumeration are never followed. |

The skill is deliberately minimal in configuration surface -- there are no flags for max-files, template path, output path, or enrichment toggles. PRD Round 3 explicitly rejected adding any of these.

## Artifacts

| File | Type | Purpose |
|---|---|---|
| `<target_path>/docs/ARCHITECTURE_AND_DESIGN.md` | Markdown | The produced or updated architecture document -- the primary artifact. |
| `<target_path>/docs/.architecture-doc/findings.md` | Markdown | Scan sub-agent's structured findings file (5 heuristic sections + Existing Documentation + Files Cited tail). Created during the run; removed by Step 10. |
| `<target_path>/docs/.architecture-doc/run.log` | Text | Append-only execution log in `<ISO8601> <level> <phase> <message>` format (Decision #18). Phases: `preflight`, `probe`, `scan`, `synthesis`, `review`, `cleanup`. Created during the run; removed by Step 10. |
| Terminal session summary | stdout | Fixed-shape summary block printed at end of run. The primary user-facing observability surface. |

Users should add `docs/.architecture-doc/` to `.gitignore` to catch the case where cleanup is preempted (e.g. session killed mid-run).

## Skill Files

```
skills/architecture-doc/
├── SKILL.md                              # Orchestrator -- frontmatter + 10 steps
└── references/
    ├── scan-agent-prompt.md              # Scan sub-agent prompt template
    ├── synthesis-agent-prompt.md         # Synthesis sub-agent prompt (Create + Audit blocks)
    ├── audit-mode.md                     # Audit-mode discipline: Edit-only, append-only, Audit Findings format
    ├── mcp-probe.md                      # MCP probe specification + enrichment prompt copy
    └── redaction-patterns.md             # Canonical secrets-redaction pattern list (10 patterns)
```

No `assets/` directory -- the skill reads the canonical template from `skills/project/design/assets/architecture-template.md` at runtime (Decision #5). No vendored fallback: the skill aborts with an explicit error if the canonical template or `gate-2-design.md` is missing.

## Security Notes

- **Path-bounded scan** (Decision #9). Every path the scan sub-agent emits is post-validated against the resolved `target_path` prefix before synthesis runs. Symlinks are never followed during enumeration.
- **Read-but-redact secrets handling** (Decision #8). The scan sub-agent may open files matching known secret patterns (`.env*`, `*.pem`, `*.key`, `credentials*`) to learn what env vars and credentials the code consumes, but every write passes through a regex redaction pass over the canonical pattern list in `references/redaction-patterns.md`. Two redaction passes run (over `findings.md` after scan, and over the produced doc after synthesis); a third runs after diagram enrichment when applicable. Redaction hits are logged with pattern names so a post-mortem can identify what category of secret was caught.
- **Sub-agent tool allowlists** (Decisions #14, #15). Both sub-agents are spawned via the `general-purpose` `Agent` type with **prompt-level** tool restrictions (Claude Code's Agent tool does not expose per-spawn allowlists). The scan agent gets `Read` / `Glob` / `Grep` / narrow `Bash` / opted-in LS MCPs only; the synthesis agent gets `Read` / `Glob` / `Grep` plus exactly one of `Write` (Create) or `Edit` (Audit), restricted to the output doc path. Neither agent has network tools or `Agent` (no nested spawning).
- **No source-code modification.** The skill is documentation-only. Output is restricted to `docs/ARCHITECTURE_AND_DESIGN.md` and the ephemeral scratch directory `docs/.architecture-doc/`. Even if the scan surfaces obvious code issues, the skill never edits source files.
- **Output section discipline.** Security Considerations in the produced doc is populated **only** from evidence the scan observed. If nothing security-relevant was observed, the section is a single sentence stating so -- never generic best-practices boilerplate.

## Related Skills

| Skill | Relationship |
|---|---|
| `/design` | The standard `/project` flow's Gate 2 architecture skill. Reads the same canonical template (`skills/project/design/assets/architecture-template.md`) and the same scan heuristics (`skills/project/design/references/gate-2-design.md`) that `/architecture-doc` reads in place. Use `/design` when a PRD exists and Gate 2 is the right next step; use `/architecture-doc` when no PRD exists or you need to document an imported / legacy / standalone codebase. |
| `/project` | Project-flow orchestrator. `/architecture-doc` does **not** detect or defer to an active `/project` flow (Decision #20) -- the two are independent and the user picks. |
| `/create-prd` | Creates `prd.md` and `progress.txt` from scratch. `/architecture-doc` is the architecture-side counterpart for codebases that don't have (or don't need) a PRD. |
