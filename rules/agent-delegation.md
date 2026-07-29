# Multi-Agent Delegation

> Delegate bulk discovery, repetitive generation, and repo-wide search to specialized sub-agents. The main thread (coordinator) keeps architectural ownership. State the delegation decision before the first tool call on any bulk task.

---

## Trigger Card

Maps to agents actually spawnable in this harness (the `Agent` tool's `subagent_type`,
plus `model` overrides). Names like Gemini/Sonnet/Haiku/Opus are NOT spawnable agent
types here — use the real agents below, and the `model` override for cost/depth tuning.

```text
Bulk discovery (read-only)             → Explore
Locate code / "where is X" (compressed)→ cavecrew-investigator
Multi-step search / research           → general-purpose
Architecture / planning                → Plan
1-2 file surgical edit                 → cavecrew-builder
Diff / branch review                   → cavecrew-reviewer
Terminal / scripting / second-opinion  → codex:codex-rescue
Cheap localized task                   → Agent + model: haiku
Deep reasoning / hard blocker          → Agent + model: opus
Default                                → main thread (me)
```

---

## Entry Condition

Before starting any task with more than five read-only tool calls, multi-file enumeration, or repo-wide search, state which agent should run it — including "me".

This is a forcing function. The matrix below is only consulted reliably when this condition fires.

---

## Philosophy

Use specialized agents deliberately to improve development speed, reduce cost, and preserve architectural consistency.

The primary coordinating agent should maintain overall project coherence, integration quality, and adherence to `CLAUDE.md` standards even when subtasks are delegated.

Delegation should optimize for:

- Context efficiency
- Faster iteration
- Reduced token usage
- Better specialization alignment
- Lower cognitive fragmentation

---

## Primary Coordinator (main thread)

The main thread is the default development and orchestration agent.

Responsibilities:

- Coordinate multi-step implementation work
- Maintain architectural consistency
- Enforce `CLAUDE.md` standards
- Integrate outputs from delegated agents
- Validate correctness before merge
- Handle nuanced reasoning and refactoring

Even when delegation occurs, the main thread remains responsible for:

- final integration
- consistency validation
- project-wide reasoning
- implementation cohesion

---

## Delegation Matrix

These are the real spawnable agents in this harness (`Agent` tool `subagent_type`). For
cost/depth tuning, pass a `model` override (`haiku`/`sonnet`/`opus`) on an `Agent` call
rather than treating the model name as an agent type.

| Agent | Delegate When... | Strengths | Weaknesses |
|-------|------------------|-----------|------------|
| **main thread (me)** | Default for feature development, refactoring, debugging, and coordinated multi-file changes | Holds architectural context; integrates delegated outputs | Consumes the primary context window on bulk work |
| **Explore** | Bulk read-only discovery, multi-file enumeration, "where is X defined / which files reference Y", initial codebase reconnaissance | Built-in subagent; preserves the main context window; quick / medium / very-thorough breadth | Read-only; reads excerpts not whole files; not for cross-file consistency checks |
| **cavecrew-investigator** | Locate code: "where is X defined", "what calls Y", "list uses of Z", map a directory | Read-only locator; caveman-compressed output (~60% fewer tokens back to main) | Refuses to suggest fixes; locate-only |
| **general-purpose** | Multi-step search/research, open-ended "find the thing" when first tries may miss, repo-wide dependency tracing | Full toolset; persistent multi-step reasoning | Heavier than Explore; validate output before merge |
| **Plan** | Architecture decisions, designing an implementation strategy before coding | Returns step-by-step plans, identifies critical files, weighs trade-offs | Read-only (cannot edit); planning only |
| **cavecrew-builder** | Surgical 1-2 file edit: typo fix, single-function rewrite, mechanical rename, comment removal | Bounded edits; caveman diff receipt | Hard-refuses 3+ file scope; not for new features/files |
| **cavecrew-reviewer** | Diff / branch / file review, PR audit | One line per finding, severity-tagged, no scope creep | Review only; skips pure formatting nits |
| **codex:codex-rescue** | Terminal/scripting workflows, second implementation/diagnosis pass, deeper root-cause, hand off a substantial coding task to Codex | Strong execution-oriented accuracy; independent engine for second opinion | External runtime; validate before merge |
| **Agent + `model: haiku`** | Cheap localized tasks: tests, docs, schema mappings, repetitive CRUD, log/output parsing | Fast, low-cost | Weak at deep architectural reasoning |
| **Agent + `model: opus`** | Unresolved failures, security design, hard debugging, core architecture | Maximum reasoning depth | Highest latency and cost |

**Plugin availability.** `cavecrew-*` agents come from the `caveman` plugin and
`codex:codex-rescue` from the `codex` plugin — neither ships with Claude Code. In a
harness without them, route those rows to the built-ins: `cavecrew-investigator` →
`Explore`, `cavecrew-builder` → `Agent + model: haiku` (or the main thread),
`cavecrew-reviewer` → `general-purpose`, `codex:codex-rescue` → `general-purpose`.
Check the available-agents list in your session before delegating to a plugin agent.

---

## Delegation Requirements

When delegating tasks:

- Provide explicit task scope
- Include architectural constraints
- Supply relevant interfaces, types, and assumptions
- Keep delegated tasks focused and bounded
- Request outputs in implementation-ready form
- Avoid open-ended rewrites without constraints

All delegated outputs should return to the coordinating agent for:

- validation
- reconciliation
- testing
- integration review

---

## Verification Policy

All delegated outputs must be:

1. Reviewed for architectural consistency
2. Validated against project conventions
3. Tested before merge
4. Reconciled with existing `CLAUDE.md` directives
5. Evaluated for unintended side effects

Do not merge delegated outputs without review.

---

## Parallel Delegation

When beneficial, use multiple specialized agents simultaneously.

Example workflow:

- **Explore** / **cavecrew-investigator** → in-session bulk reads, enumeration, code-locate
- **general-purpose** → repo-wide discovery and multi-step dependency tracing
- **Agent + `model: haiku`** → tests, docs, and repetitive support code
- **codex:codex-rescue** → scripts, tooling, transformations, terminal workflows
- **main thread (me)** → orchestration, implementation coordination, integration
- **Agent + `model: opus`** → escalation for unresolved architectural or reasoning issues

Parallel delegation should improve throughput without fragmenting architectural ownership.

---

## Trigger Phrase Routing

| Trigger Phrase | Delegate To | Purpose |
|---|---|---|
| "Generate exhaustive unit tests for..." | Agent + `model: haiku` | Fast low-cost test generation |
| "Update docs / comments / schema mappings..." | Agent + `model: haiku` | Repetitive maintenance tasks |
| "Find where X is defined..." | cavecrew-investigator | Compressed code-locate |
| "Enumerate files matching..." | Explore | Multi-file read-only enumeration |
| "Scan the repository for..." | general-purpose | Repository-wide discovery |
| "Trace all usages of..." | general-purpose | Multi-step dependency tracing |
| "Review this diff / PR..." | cavecrew-reviewer | Severity-tagged diff review |
| "Design the architecture for..." | Plan | Implementation strategy + critical files |
| "Investigate unresolved multi-system failures..." | Agent + `model: opus` | Advanced debugging escalation |
| "Second opinion / root-cause this..." | codex:codex-rescue | Independent diagnosis pass |
| "Refactor this subsystem safely..." | main thread (me) | Coordinated multi-file refactoring |
| "Implement production-ready feature..." | main thread (me) | Default execution path |
| "Write a shell script to..." | codex:codex-rescue | CLI and scripting workflows |
| "Surgical 1-2 file edit / rename..." | cavecrew-builder | Bounded format-preserving edit |

---

## Escalation Logic

1. Start on the **main thread (me)**
2. Use **Explore** / **cavecrew-investigator** for in-session bulk reads, search, code-locate
3. Delegate repetitive or localized tasks to **Agent + `model: haiku`**
4. Use **general-purpose** for repository-wide or multi-step discovery work
5. Use **codex:codex-rescue** for execution-heavy, tooling, or second-opinion workflows
6. Escalate to **Agent + `model: opus`** when:
   - blocked after multiple iterations
   - architectural uncertainty persists
   - debugging becomes non-deterministic
   - security or systems reasoning becomes critical

Escalation should be intentional, not automatic.

---

## Repository Discovery Guidance

Use **Explore** (or **cavecrew-investigator** for compressed locate-only output) when:

- searching the current repository in-session
- enumerating files by pattern
- locating where a symbol or string is defined
- preserving the main context window during reconnaissance

Use **general-purpose** when:

- the search is open-ended and the first few tries may miss
- tracing dependency chains across many files
- multi-step research that needs the full toolset, not just excerpts
- analyzing logs or long documents in a separate context

The split: Explore/cavecrew-investigator for fast in-session reads; general-purpose for open-ended multi-step discovery that needs persistence and the full toolset. Both are discovery agents — implementation generated from their analysis must be validated on the main thread (escalate to `model: opus` for hard calls) before merge.

---

## Avoid Delegation When

Do not delegate:

- Small edits solvable within current context
- Highly coupled changes requiring deep continuity
- Security-sensitive implementations without review
- Active merge-conflict areas
- Tasks where delegation overhead exceeds implementation effort

Excessive delegation increases fragmentation and integration cost.

---

## Operational Principles

- Prefer focused delegation over broad delegation
- Preserve architectural ownership within the coordinating agent
- Optimize for correctness over token savings
- Use specialized agents as force multipliers, not replacements
- Keep implementation responsibility centralized
- Minimize context fragmentation whenever possible

---

## Setup / Installation

**Why a hook is required.** This rule is only consulted before action when the harness forces consultation. Loaded into context but not actively triggered, the matrix is passive — the agent's default-to-action bias routes around it and starts running tools without first stating a delegation decision. A `UserPromptSubmit` hook fires deterministically and injects a one-line reminder when the user's prompt matches bulk-work keywords (`audit`, `categorize`, `review all`, `find every`, `across the docs`, `enumerate`, `inventory`, `sweep`). The reminder appears at the right moment, immediately before the agent picks its first tool — the consultation cost drops from "re-read the matrix" to "scan one line".

**How to install.** Run the installer from this repository against the target consumer repo:

```bash
bash scripts/agent-delegation/install.sh <target-repo-path>
```

The installer:

1. Copies this rule to `<target-repo-path>/.claude/rules/agent-delegation.md`
2. Merges the `UserPromptSubmit` hook into `<target-repo-path>/.claude/settings.json` (creating the file if missing, preserving existing keys)
3. Is idempotent — re-running it does not duplicate the hook entry

A bare `cp rules/agent-delegation.md <target>/.claude/rules/` works as a fallback, but consultation will be unreliable without the hook. Restart Claude Code in the target repo after installation for the rule and hook to take effect.
