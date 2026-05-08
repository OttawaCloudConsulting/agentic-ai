# Multi-Agent Delegation

> Delegate bulk discovery, repetitive generation, and repo-wide search to specialized sub-agents. The coordinator (Sonnet) keeps architectural ownership. State the delegation decision before the first tool call on any bulk task.

---

## Trigger Card

```text
Bulk discovery (read-only)             → Explore
Log retrieval / output parsing         → Haiku
Repo-wide search / dependency map      → Gemini
Architecture / unresolved blocker      → Opus
Terminal / scripting workflows         → Codex
Default                                → Sonnet (me)
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

## Primary Coordinator (Sonnet)

Sonnet is the default development and orchestration agent.

Responsibilities:

- Coordinate multi-step implementation work
- Maintain architectural consistency
- Enforce `CLAUDE.md` standards
- Integrate outputs from delegated agents
- Validate correctness before merge
- Handle nuanced reasoning and refactoring

Even when delegation occurs, Sonnet remains responsible for:

- final integration
- consistency validation
- project-wide reasoning
- implementation cohesion

---

## Delegation Matrix

| Agent       | Delegate When... | Strengths | Weaknesses |
|-------------|------------------|-----------|------------|
| **Sonnet**  | Default for feature development, refactoring, debugging, and coordinated multi-file changes | Best balance of reasoning, context retention, and architectural cohesion | Less cost-efficient for repetitive boilerplate |
| **Haiku**   | Generating tests, documentation, schema mappings, repetitive CRUD, simple UI/CSS updates, log retrieval and output parsing | Extremely fast and low-cost for localized implementation tasks | Weak at deep architectural reasoning and complex dependencies |
| **Opus**    | Resolving unresolved system failures, security design, difficult debugging, or core architecture decisions | Maximum reasoning depth and abstract systems thinking | Highest latency and cost |
| **Codex**   | Terminal workflows, shell scripts, deterministic implementation tasks, regex transformations, tooling glue code | Strong execution-oriented accuracy and structured implementation | Smaller effective context and weaker project-wide cohesion |
| **Gemini**  | Repository-wide discovery, large log analysis, legacy codebase scanning, long-document ingestion | Massive context window enables large-scale analysis | Lower implementation precision; requires validation before merge |
| **Explore** | Bulk read-only discovery, multi-file enumeration, "where is X defined / which files reference Y", initial codebase reconnaissance | Built-in Claude Code subagent; preserves the main context window; supports quick / medium / very-thorough search breadth | Read-only (cannot edit); reads excerpts, not whole files — misses content past its read window; not for cross-file consistency checks or open-ended analysis |

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

- **Explore** → in-session bulk reads and multi-file enumeration
- **Gemini** → cross-repository discovery and long-context dependency tracing
- **Haiku** → tests, docs, and repetitive support code
- **Codex** → scripts, tooling, transformations, terminal workflows
- **Sonnet** → orchestration, implementation coordination, integration
- **Opus** → escalation for unresolved architectural or reasoning issues

Parallel delegation should improve throughput without fragmenting architectural ownership.

---

## Trigger Phrase Routing

| Trigger Phrase | Delegate To | Purpose |
|---|---|---|
| "Generate exhaustive unit tests for..." | Haiku | Fast low-cost test generation |
| "Update docs / comments / schema mappings..." | Haiku | Repetitive maintenance tasks |
| "Find where X is defined..." | Explore | In-session bulk read and search |
| "Enumerate files matching..." | Explore | Multi-file read-only enumeration |
| "Scan the repository for..." | Gemini | Repository-wide discovery |
| "Trace all usages of..." | Gemini | Long-context dependency analysis |
| "Design the architecture for..." | Opus | Deep systems reasoning |
| "Investigate unresolved multi-system failures..." | Opus | Advanced debugging escalation |
| "Refactor this subsystem safely..." | Sonnet | Coordinated multi-file refactoring |
| "Implement production-ready feature..." | Sonnet | Default execution path |
| "Write a shell script to..." | Codex | CLI and scripting workflows |
| "Transform files using regex or automation..." | Codex | Deterministic transformation tasks |

---

## Escalation Logic

1. Start with **Sonnet**
2. Use **Explore** for in-session bulk reads and search
3. Delegate repetitive or localized tasks to **Haiku**
4. Use **Gemini** for repository-wide analysis or long-context work
5. Use **Codex** for execution-heavy or tooling-oriented workflows
6. Escalate to **Opus** when:
   - blocked after multiple iterations
   - architectural uncertainty persists
   - debugging becomes non-deterministic
   - security or systems reasoning becomes critical

Escalation should be intentional, not automatic.

---

## Repository Discovery Guidance

Use **Explore** when:

- searching the current repository in-session
- enumerating files by pattern
- locating where a symbol or string is defined
- preserving the main context window during reconnaissance

Use **Gemini** when:

- searching legacy or massive repositories
- tracing dependency chains across millions of lines
- analyzing extensive logs
- ingesting long technical documentation

The split: Explore for in-session reads where the context window is not the bottleneck; Gemini for long-context workloads where it is. Both are discovery tools — implementation generated from their analysis must be validated by Sonnet or Opus before merge.

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
