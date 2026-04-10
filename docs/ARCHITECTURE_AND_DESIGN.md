# Architecture and Design: architecture-doc

<!-- Source PRD: ../prd.md -->
<!-- Target skill location: skills/architecture-doc/ -->

## Design Decisions

| # | Decision | Rationale | Tradeoff | Alternatives Considered |
|---|----------|-----------|----------|-------------------------|
| 1 | Implement as a SKILL.md orchestrator under `skills/architecture-doc/`, following the `skills/project/design/` file layout (SKILL.md + references/ + optional assets/). | Aligns with the house pattern for non-trivial skills in this repo; enables the review loop, sub-agent spawning, and partial-approval flow to reuse existing conventions reviewers are already familiar with. | Couples the skill to the conventions of `skills/project/design/`. If that pattern changes, this skill will need to follow. | (a) Single-file command under `.claude/commands/` — rejected because multi-sub-agent orchestration and partial-approval loops do not fit the single-file command model (feedback memory: single-file workflows go in commands/, not skills/). (b) Standalone CLI — rejected as overscope for a Claude Code workflow. |
| 2 | Two sub-agents: one scan sub-agent and one synthesis sub-agent, spawned sequentially via the Agent tool. | Context isolation for both the expensive codebase scan and the synthesis pass. Keeps the main orchestrator context small so the review loop can run cleanly afterwards. Matches the sub-agent spawning pattern the user chose in PRD Round 2. | Two sub-agent spawns add latency and make the hand-off contract (findings file schema) a load-bearing interface. | (a) Single scan sub-agent with synthesis inline in the orchestrator — rejected because synthesis consumes the full findings file and the template, which bloats the main context and poisons the review loop. (b) No sub-agents — rejected for context bloat on even medium-sized repos. |
| 3 | Create mode and Audit mode share the scan sub-agent and its findings schema; only the synthesis sub-agent diverges. | Maximum reuse of the most expensive step. Both modes need the same factual picture of the code; the difference is purely in how that picture is projected onto the target document. | Audit mode cannot use a narrower, diff-focused scan to save time; it pays full-scan cost even when the existing doc is mostly accurate. | (a) Separate scan heuristics per mode — rejected because Audit mode still needs to see the full architecture to spot contradictions. (b) Audit as post-processor over Create — rejected because it would silently produce a whole new doc and then diff, which is wasteful and confusing. |
| 4 | Scan heuristics are **read from** `skills/project/design/references/gate-2-design.md` at runtime — not copied, not inlined, not extracted to a shared location. | Single source of truth. Any improvement to the `/design` scan heuristics automatically benefits `/architecture-doc`. No drift, no duplication. | Couples `/architecture-doc` to the internal structure of `skills/project/design/references/gate-2-design.md`. If that file is renamed or restructured, this skill breaks. | (a) Copy into own `references/` — rejected for drift risk. (b) Extract to a new shared location — rejected because it requires modifying `/design`, a stable and approved skill, for the benefit of a new skill. Revisit if a third consumer appears. (c) Inline in SKILL.md — rejected for bloat. |
| 5 | Architecture template is **read from** `skills/project/design/assets/architecture-template.md` at runtime. Not vendored into `skills/architecture-doc/assets/`. | Same rationale as Decision #4: single source of truth, no drift. The canonical template is already the authoritative shape for every architecture doc in the repo. | Same coupling risk as #4. | (a) Vendor a copy — rejected for drift. (b) Template override via CLI arg — dropped during Round 3; not worth the surface area. |
| 6 | Runtime scratch files (scan findings, run log) live under `<target_path>/docs/.architecture-doc/` — inside the target repo, in a hidden subdirectory of `docs/`. | User-selected during Round 3. Keeps scratch co-located with the output doc for easy inspection if a run goes wrong. Hidden directory signals "not for commit". Removed at end of run so it does not persist. | Risk of accidental commit if the user forgets to add `docs/.architecture-doc/` to `.gitignore`. Risk of colliding with a user-authored `docs/.architecture-doc/` (extremely unlikely). | (a) `/tmp/architecture-doc-scan-findings.md` — rejected because it makes post-mortem debugging harder (separate location). (b) `.claude/scratch/` — rejected because it puts runtime state inside the skill-config tree. (c) `skills/architecture-doc/.state/` — rejected because it couples runtime state to the skill's source directory. |
| 7 | Preflight validation (empty directory, binary-only directory, monorepo) runs in the scan sub-agent's orientation pass, **before** the main file selection. | Keeps the orchestrator thin. The scan agent already runs `ls -R` for orientation; adding three cheap checks to that pass is nearly free. Early termination prevents wasted synthesis work on un-scannable targets. | The scan agent has to know how to gracefully abort and surface the right error message to the orchestrator. This becomes part of the findings-file contract. | (a) Orchestrator-side preflight using Bash — rejected because it duplicates the `ls -R` pass. (b) No preflight, let synthesis handle empty findings — rejected because it produces low-quality output instead of aborting cleanly. |
| 8 | Secret handling is **read-but-redact**: scan sub-agent may open files matching known secret patterns, but every write (findings file, run log, output doc) passes through a secrets regex pass that strips common token / key patterns. | Needed so the synthesis can still document "the app consumes `DATABASE_URL` and `JWT_SECRET` env vars" without writing the actual values. Strict skip-only policy would lose useful architectural context. | Regex-based redaction is not airtight. A non-standard secret format could slip through. | (a) Skip secret-bearing files entirely — rejected because it loses architectural context about what env vars the app consumes. (b) Redact without reading — contradictory. (c) Skip AND redact — not needed; redacting on write is sufficient for this risk profile. |
| 9 | Path boundary enforcement: the orchestrator resolves `target_path` to an absolute path and validates every path passed to the scan sub-agent against that prefix. Symlinks are never followed. | Contains the scan to the directory the user asked about. Prevents a surprising scan of unrelated files via a symlink into a sibling project or a user's home directory. | Forces the orchestrator to resolve and validate each path before Agent spawning, which is extra defensive code. Legitimate symlinks (e.g. monorepo workspace links) are invisible to the scan. | (a) Trust the sub-agent to stay in scope — rejected because sub-agents do not enforce path boundaries. (b) Allow symlink following — rejected for unexpected scope explosion risk. |
| 10 | The skill enables natural-language invocation (`disable-model-invocation: false`) in the SKILL.md frontmatter. | Matches the PRD goal of responding to phrases like "document this architecture" and "there's no design doc, create one". The target user is Claude operating over a fresh repo and deciding whether to run it proactively. | Departs from the `/design` precedent, which sets `disable-model-invocation: true`. Risk of surprise invocations if the SKILL.md description is too broad. | (a) Slash-only (matches `/design`) — rejected because it defeats the purpose of a skill that wants to fire automatically when Claude notices missing architecture docs. |
| 11 | Audit-mode contradictions surface as a **top-of-doc "Audit Findings" block** prepended to `docs/ARCHITECTURE_AND_DESIGN.md`. Users delete the block when resolved. | Single artifact. Reviewers see audit findings inline with the content they pertain to. No sibling file to keep in sync. The block is visually distinct and obviously ephemeral. | Modifies the authoritative document even though the findings may not represent accepted changes yet. Risk of the block being committed and confusing future readers. | (a) Separate `docs/ARCHITECTURE_AUDIT_FINDINGS.md` — rejected because it creates a sibling file the user must track and clean up. (b) Inline Markdown comments — rejected because they are invisible in rendered output. |
| 12 | MCP capability probe is performed in the orchestrator by introspecting the list of tools whose names carry the `mcp__` prefix in the current session. No probe sub-agent. | This is how MCP tools actually surface to Claude Code — as names in the tool list. No extra sub-agent spawn needed. Cheapest possible probe. | Couples the skill to the current naming convention (`mcp__<server>__<tool>`). If that convention changes, the probe breaks. | (a) Probe sub-agent — rejected for unnecessary spawn cost. (b) Known-name list with trial calls — rejected for fragility. (c) Defer to implementation time — rejected because it leaves a gap in the design that reviewers will immediately ask about. |
| 13 | The produce-then-review loop (Approve / Revise / Partial with six-section multiSelect) runs in the **orchestrator context**, not in the synthesis sub-agent. | Matches the `/design` pattern exactly. Sub-agent produces the artifact; the orchestrator — which has the AskUserQuestion tool and the full conversation surface — handles the interactive review. | The orchestrator has to re-read the produced doc into its context to perform the review, which costs tokens. Acceptable. | (a) Review loop inside synthesis sub-agent — rejected because sub-agents have limited interactive surface and nested AskUserQuestion is awkward. |
| 14 | The scan sub-agent receives a tool allowlist: `Read`, `Glob`, `Grep`, `Bash` (for `ls -R` and `git log` only), plus any MCP tools discovered by the probe. No `Write`, `Edit`, `Agent`, or network tools. | Constrains the scan to read-only operations against the target tree. Prevents the scan agent from accidentally modifying code or spawning its own sub-agents. | The scan agent cannot write its findings file using its own tool — it must return structured text that the orchestrator writes. Alternative: allow a single narrow `Write` on the scratch path. | (a) Allow `Write` on the scratch path only — accepted as a sub-decision of this one; the orchestrator's spawn prompt restricts Write to the scratch path. (b) Allow full tool access — rejected for attack surface. |
| 15 | Synthesis sub-agent receives `Read`, `Write` (for Create mode only), `Edit` (for Audit mode only), `Glob`, `Grep`. No Bash, no Agent, no network. | Minimum required for each mode. Create mode writes a new file once; Audit mode only edits the existing file. | Two slightly different sub-agent tool allowlists for the two modes. Trivial. | (a) Same allowlist for both modes — simpler but weakens the Audit-mode guarantee that existing content cannot be replaced wholesale. |
| 16 | The orchestrator caps the scan at 30 files by default, with no user override. | PRD Round 3 rejected a max-files config option. 30 matches the `/design` skill's scan ceiling. | A user with a very small repo (e.g. 5 files) still pays scan agent spawn cost; a user with a very large repo cannot opt in to a deeper scan. Acceptable given the PRD's minimalism bias. | (a) Expose `--max-files` flag — rejected in PRD Round 3. (b) Lower ceiling (e.g. 15) — rejected because architecture synthesis needs breadth. |
| 17 | MCP-enriched features (Mermaid diagram embedding, language-server-assisted file selection) are **opt-in per run**: when the relevant MCP is detected, the orchestrator asks the user via `AskUserQuestion` whether to enable the enrichment. Mermaid node labels MUST use `<br/>` for line breaks (per `CLAUDE.md`); literal `\n` renders as text and corrupts diagrams. | Keeps enrichments from silently changing the output shape between runs. User sees the choice each time. Avoids the "skill behaves differently in different sessions" trap. | Adds one AskUserQuestion prompt per enrichment per run. Mild friction. | (a) Auto-enable any detected MCP — rejected because Mermaid diagrams are a material change to the output shape and should be user-consented. (b) Never auto-use MCPs — rejected because it makes the Feature 2/Feature 8 design pointless. |
| 18 | Run log (`docs/.architecture-doc/run.log`) is **structured-text, append-only**, with one event per line in the form `<ISO8601> <level> <phase> <message>`. Phases are `preflight`, `probe`, `scan`, `synthesis`, `review`, `cleanup`. | Easy to tail during a long run. Easy to grep post-run. Matches how typical CLI tools log. No YAML / JSON overhead. | Not machine-parseable beyond grep. If we later want structured event analysis we would need to re-parse. Acceptable for an ephemeral ops log. | (a) YAML events — rejected as overkill. (b) Free-form Markdown — rejected as hard to grep. (c) No run log — rejected because debugging a failed run requires execution history. |
| 19 | Natural-language trigger surface is controlled by the SKILL.md `description` field. The description mentions "architecture document", "design doc", "reverse engineer architecture", "audit architecture doc", and similar phrases so that Claude routes matching requests to this skill. | Gives the model a deliberate trigger surface. Under-specifying would cause missed invocations; over-specifying would cause false positives. | Authoring this description well is non-trivial. Needs review during implementation against the `/design` skill's description to minimise routing ambiguity. | (a) Minimal description — rejected because model invocation routing would miss obvious cases. (b) Broad description — rejected because it would overlap with `/design` refresh mode. |
| 20 | The skill does **not** detect or defer when a `/project` flow is active (`progress.txt` present, Gate 2 approved). It always runs as asked. | PRD Round 1 explicitly chose this. The user is trusted to pick the right tool; `/design` refresh mode remains available for in-flow cases. | If a user accidentally runs `/architecture-doc` inside a project that already has an approved Gate 2, they might overwrite or duplicate work. Mitigated by Feature 1's existing-document detection prompt. | (a) Warn and suggest `/design` refresh — rejected in Round 1. (b) Hard block — rejected in Round 1. |

## Component Inventory

| Component | Responsibility | Interfaces |
|-----------|---------------|------------|
| `skills/architecture-doc/SKILL.md` | Orchestrator. Owns mode detection, MCP probe, path validation, sub-agent spawning, review loop, session summary, and scratch cleanup. | Reads: canonical template, canonical `gate-2-design.md`, existing `docs/ARCHITECTURE_AND_DESIGN.md` (if any). Writes: output doc (Create mode path via Write), scratch dir creation, scratch cleanup. Spawns: scan sub-agent, synthesis sub-agent. Calls: `AskUserQuestion`. |
| `skills/architecture-doc/references/scan-agent-prompt.md` | Scan sub-agent prompt template. Encodes tool allowlist, preflight checks, file-selection heuristics (pulled from canonical `gate-2-design.md`), findings-file schema, redaction rules, and path-boundary instructions. | Read by orchestrator when constructing the Agent spawn. Not executed directly. |
| `skills/architecture-doc/references/synthesis-agent-prompt.md` | Synthesis sub-agent prompt template. Contains two variants (Create and Audit) selected by the orchestrator based on Feature 1's mode decision. | Read by orchestrator when constructing the Agent spawn. Not executed directly. |
| `skills/architecture-doc/references/audit-mode.md` | Detailed Audit-mode rules: Edit-only discipline, append-only Design Decisions, top-of-doc "Audit Findings" block format, contradiction-handling policy. | Referenced by `synthesis-agent-prompt.md`. Read by orchestrator for review-loop messaging. |
| `skills/architecture-doc/references/mcp-probe.md` | MCP probe specification: how to enumerate `mcp__`-prefixed tools, categorisation rules (diagram / code-search / language-server / other), and opt-in prompt text for each category. | Read by orchestrator during the probe step. |
| Scan sub-agent (runtime) | Ephemeral sub-agent spawned via the Agent tool. Runs preflight, selects 15–30 files using the heuristics, writes findings. | Input: spawn prompt from the orchestrator, including `target_path` and detected MCP tool list. Output: `docs/.architecture-doc/findings.md`. |
| Synthesis sub-agent (runtime) | Ephemeral sub-agent spawned via the Agent tool. Reads findings, reads canonical template, writes (Create) or edits (Audit) the output doc. | Input: spawn prompt plus `findings.md`, canonical template path, and mode. Output: `docs/ARCHITECTURE_AND_DESIGN.md`. |
| `docs/.architecture-doc/findings.md` (runtime) | Scan sub-agent's structured findings file. Consumed by synthesis, cleaned up at end of run. | Produced by scan sub-agent. Consumed by synthesis sub-agent. |
| `docs/.architecture-doc/run.log` (runtime) | Append-only execution log with `<ISO8601> <level> <phase> <message>` entries. Cleaned up at end of run. | Written by orchestrator (phases: `preflight`, `probe`, `review`, `cleanup`) and by sub-agents via their prompt instructions. |

## Data Flow

1. **Invocation.** User types `/architecture-doc [target_path]` OR Claude routes a natural-language request to the skill via the SKILL.md description. `target_path` defaults to the current working directory.

2. **Path validation.** Orchestrator resolves `target_path` to an absolute canonical path (resolving any symlink in the path itself). If the path does not exist or is not a directory, abort with an error. The no-symlink-following rule (Decision #9) applies to scan-time enumeration, not to `target_path` resolution — a user invoking the skill from a symlinked project root is supported.

3. **MCP capability probe.** Orchestrator enumerates tools with `mcp__` prefix in its current session. Reads `references/mcp-probe.md` to categorise each tool. Records categories in an in-context variable used later for enrichment prompts. Writes one probe entry per detected category to `run.log`.

4. **Existing-document detection (Feature 1).** Orchestrator tests for `<target_path>/docs/ARCHITECTURE_AND_DESIGN.md`. If absent → enter **Create mode**. If present and plausibly Markdown → ask user (`AskUserQuestion`) to choose Create (Overwrite), Audit, or Abort. If present but unreadable or non-Markdown → offer only Overwrite or Abort.

5. **Scratch setup.** Orchestrator creates `<target_path>/docs/.architecture-doc/` and initialises `run.log` with a session-start entry.

6. **Scan sub-agent spawn (Feature 3).** Orchestrator reads the canonical `gate-2-design.md` scan-heuristic sections and embeds them in the scan sub-agent prompt constructed from `references/scan-agent-prompt.md`. Agent is spawned with the restricted tool allowlist plus discovered MCP tools. Agent runs:
   - Orientation pass: `ls -R` (first 2 levels), `git log --oneline -20`.
   - Preflight checks (Decision #7): empty directory → abort; binary-only → abort; monorepo → warn-and-suggest (continue only if orchestrator confirms with user).
   - File selection (15–30 files via heuristics).
   - Read each file, summarise to findings.
   - Existing-documentation harvest (Feature 4) — also runs in this phase.
   - Write `findings.md` with five heuristic sections plus **Existing Documentation**, all passed through the redaction regex pass.

7. **Synthesis sub-agent spawn (Feature 5 or 6).** Orchestrator reads the canonical architecture template and constructs the synthesis prompt from `references/synthesis-agent-prompt.md`, selecting the Create or Audit variant.
   - **Create mode:** agent writes `docs/ARCHITECTURE_AND_DESIGN.md` from scratch, populating all six required sections. Every Design Decision row cites ≥1 source file or existing doc; uncertain rows are marked `(inferred)`.
   - **Audit mode:** agent reads the existing doc in full, uses `Edit` to append new Design Decisions, prepends the "Audit Findings" block at the top with any contradictions found, and never removes entries that are not directly contradicted. Follows `references/audit-mode.md`.

8. **MCP enrichment (Feature 8, conditional).** If probe detected Mermaid-rendering MCP, orchestrator asks the user whether to embed generated diagrams; if yes, orchestrator calls the MCP tool and edits the output doc to include them. If a language-server MCP was detected, its usage happened already in step 6 (scan phase), not here.

9. **Produce-then-review loop (Feature 7).** Orchestrator reads the output doc, presents a summary and 2–4 tradeoff callouts. Calls `AskUserQuestion` with Approve / Revise / Partial.
   - **Revise:** ask what should change, apply edits in orchestrator context with `Edit`, loop back to summary.
   - **Partial:** multiSelect over the six canonical sections; for each unchecked section ask what should change and apply edits; loop back to summary.
   - **Approve:** exit loop.

10. **Cleanup.** Orchestrator writes a final `run.log` entry, then removes `<target_path>/docs/.architecture-doc/` entirely.

11. **Session summary.** Orchestrator prints a terminal summary: mode used, files scanned, decisions captured, components inventoried, MCP enrichments applied (if any), review iterations performed.

## File Organization

```text
skills/architecture-doc/
├── SKILL.md                              # Orchestrator — frontmatter + steps
└── references/
    ├── scan-agent-prompt.md              # Scan sub-agent prompt template
    ├── synthesis-agent-prompt.md         # Synthesis sub-agent prompt (Create + Audit variants)
    ├── audit-mode.md                     # Audit-mode discipline: Edit-only, append-only, Audit Findings block format
    └── mcp-probe.md                      # MCP probe specification and categorisation rules

# Runtime artifacts (created and removed per-invocation, not committed):
<target_path>/
├── docs/
│   ├── ARCHITECTURE_AND_DESIGN.md        # Output — the produced or updated doc
│   └── .architecture-doc/                # Scratch dir (cleaned up at end of run)
│       ├── findings.md                   # Scan sub-agent structured findings
│       └── run.log                       # Append-only execution log
```

No `assets/` directory is needed — the skill reads the canonical template from `skills/project/design/assets/architecture-template.md` at runtime (Decision #5).

## Deployment & Operations

**Distribution.** The skill ships as part of this repo under `skills/architecture-doc/`. Users acquire it by pulling the repo, matching the pattern of every other skill in the catalog (`nist-fedramp-assessment`, `red-team`, `create-prd`, etc.). No packaging step.

**Installation.** None beyond a repo pull. The skill is discovered by Claude Code automatically via the `skills/` directory convention.

**CI/CD.** The skill has no CI of its own. Existing repo-level checks (if any) apply to the files in `skills/architecture-doc/`.

**Invocation.** Two entry points:

1. Slash command: `/architecture-doc [target_path]`
2. Natural language: Claude routes matching requests to the skill via the SKILL.md `description` field (`disable-model-invocation: false`). Example phrases: "there is no architecture doc for this code, create one", "audit the architecture doc against the current code", "document the architecture of this directory".

**Observability.** Two surfaces:

1. **Terminal session summary** at end of run — mode, counts, enrichments, iterations. This is the primary user-facing observability.
2. **`docs/.architecture-doc/run.log`** — append-only per-run execution log in `<ISO8601> <level> <phase> <message>` format. Ephemeral — removed with the rest of `docs/.architecture-doc/` during cleanup. Available for inspection while a run is in progress (tail) or during post-mortem if the run is aborted before cleanup.

**No persistent telemetry, no metrics, no remote reporting.** The skill leaves no trace between runs beyond the produced `docs/ARCHITECTURE_AND_DESIGN.md`.

**Runtime dependencies.** The skill depends on two files that must exist at runtime in the same repo:

- `skills/project/design/assets/architecture-template.md` (canonical template — Decision #5)
- `skills/project/design/references/gate-2-design.md` (scan heuristics — Decision #4)

If either file is missing, the skill aborts with a specific error naming the missing file. No vendored fallback.

## Security Considerations

**Path boundary enforcement (Decision #9).** The orchestrator resolves `target_path` to an absolute canonical path at the start of the run. Every path subsequently passed to either sub-agent is validated against that prefix. Paths that resolve outside the tree — via `..`, symlinks, or absolute paths in agent prompts — are rejected at the orchestrator layer before the sub-agent sees them.

**No symlink following.** Neither sub-agent follows symlinks during enumeration. The scan agent's Glob and Read calls are constrained by the prompt to reject symlinked entries. This eliminates a class of path-traversal and secret-leak scenarios where a symlink points from inside the target tree to something outside it.

**Secret handling (Decision #8, read-but-redact).** The scan sub-agent may open files matching known secret patterns (`.env*`, `*.pem`, `*.key`, `credentials*`, `.aws/credentials`) to learn about the architectural role of those files — e.g. "the app consumes `DATABASE_URL` and `JWT_SECRET` env vars". But every write from the sub-agent (findings file, run log, output doc) is passed through a secrets regex pass that strips common token and key patterns before the write commits. Concretely: the orchestrator runs the regex pass on `findings.md` after the scan sub-agent returns, and on `ARCHITECTURE_AND_DESIGN.md` after the synthesis sub-agent returns, before the review loop begins.

**Tool allowlists.** Both sub-agents receive a minimum-viable tool allowlist (Decisions #14 and #15). Neither has network tools, Agent (no nested spawning), or write access to paths outside the scratch dir or the output doc.

**Output section discipline (Round 4 decision).** The Security Considerations section of the produced doc is populated **only** from evidence the scan observed — auth middleware, encryption libraries, cert handling, secrets management. No generic best-practices boilerplate. If nothing relevant was observed, the section is a single sentence stating so. This prevents the skill from producing a security section that looks authoritative but is actually generic hand-waving.

**No network egress.** The skill makes no network calls except via explicitly-opted-in MCP tools discovered during the probe phase. No silent telemetry, no remote template fetches, no version checks.

**Scratch cleanup.** The `docs/.architecture-doc/` directory is removed at the end of every run, whether the run succeeded, aborted, or was interrupted. Cleanup is the last orchestrator step and must run even if the review loop exits via an error. Users should add `docs/.architecture-doc/` to `.gitignore` to catch the case where cleanup is preempted (e.g. session killed mid-run).
