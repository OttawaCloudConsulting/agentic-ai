# Multi-Agent Delegation

**Source:** `rules/agent-delegation.md`
**Scope:** All project types — multi-agent delegation strategy for Claude Code sessions
**Activation:** Automatic — loaded when placed in `.claude/rules/`. **Requires** a `UserPromptSubmit` hook to fire reliably (see Setup / Installation).

## Core Principle

State the delegation decision before the first tool call on any bulk task. The matrix is only consulted reliably when the harness forces consultation — passive context loses to the agent's default-to-action bias.

## Overview

This rule defines which sub-agent should handle which class of work. The delegation matrix routes to **real spawnable agents** in the Claude Code harness (the `Agent` tool's `subagent_type`, plus `model` overrides) — the main thread (coordinator), `Explore` (bulk read-only discovery), `cavecrew-investigator` (compressed code location), `general-purpose` (multi-step search/research), `Plan` (architecture), `cavecrew-builder` (surgical 1–2 file edits), `cavecrew-reviewer` (diff review), `codex:codex-rescue` (terminal/second-opinion), and `Agent + model: haiku/opus` for cost/depth tuning — with explicit trigger phrases, escalation logic, and avoidance criteria. Model names (Sonnet/Haiku/Opus/Gemini) are **not** spawnable agent types; the rule routes to agents and uses `model` overrides for tuning.

**Plugin availability:** `cavecrew-*` agents come from the `caveman` plugin and `codex:codex-rescue` from the `codex` plugin. The rule includes fallback routing to built-ins (`Explore`, `general-purpose`, `Agent + model`) for harnesses without those plugins.

The rule ships with a companion `UserPromptSubmit` hook because field testing showed that loading the matrix into context is not enough. Without a forcing function, the agent reads the rule but routes around it: by the time a bulk task arrives, "act now" beats "consult the matrix" on every iteration. The hook injects a one-line reminder when the user's prompt matches bulk-work keywords, raising the trigger card to the agent's attention at the moment it is about to pick its first tool.

Adopt this rule on any project where Claude Code is the primary development agent. The hook is harmless on solo workflows (it only fires on bulk-work keywords) and load-bearing on workflows that actually use sub-agents.

## Sections

### Trigger Card

A fast-path table at the top of the rule. Maps task shape to agent: bulk discovery → Explore, locate code → cavecrew-investigator, multi-step search → general-purpose, architecture/planning → Plan, surgical 1–2 file edit → cavecrew-builder, diff review → cavecrew-reviewer, terminal/second-opinion → codex:codex-rescue, cheap localized task → Agent + model: haiku, deep reasoning → Agent + model: opus, default → main thread. Designed to drop consultation cost from "re-read the matrix" to "scan a few lines."

### Entry Condition

A single forcing sentence: "Before starting any task with more than five read-only tool calls, multi-file enumeration, or repo-wide search, state which agent should run it — including 'me'." Converts the rule from passive matrix to active checklist. The hook (Setup / Installation, below) is what makes this fire reliably.

### Philosophy

Establishes that delegation is a deliberate optimization for context efficiency, iteration speed, token cost, specialization, and reduced cognitive fragmentation — not a way to offload responsibility. The coordinating agent retains architectural ownership even when subtasks are delegated.

### Primary Coordinator (main thread)

The main thread is the default development and orchestration agent. Responsibilities: multi-step coordination, architectural consistency, `CLAUDE.md` enforcement, integration of delegated outputs, correctness validation, and nuanced refactoring. Even when delegation occurs, the main thread remains responsible for final integration, consistency validation, project-wide reasoning, and implementation cohesion.

### Delegation Matrix

Ten rows. Each lists the agent, when to delegate to it, its strengths, and its weaknesses:

- **main thread (me)** — default for feature development, refactoring, debugging, coordinated multi-file changes. Holds architectural context. Consumes the primary context window on bulk work.
- **Explore** — bulk read-only discovery, multi-file enumeration, "where is X defined" questions, initial codebase reconnaissance. Built-in subagent; preserves the main context window. Read-only; reads excerpts, not whole files.
- **cavecrew-investigator** — locate code ("where is X defined", "what calls Y", map a directory). Read-only locator with compressed output (~60% fewer tokens back to the main thread). Refuses to suggest fixes.
- **general-purpose** — multi-step search/research, open-ended discovery, repo-wide dependency tracing. Full toolset; heavier than Explore; validate output before merge.
- **Plan** — architecture decisions and implementation-strategy design. Returns step-by-step plans and critical files. Read-only, planning only.
- **cavecrew-builder** — surgical 1–2 file edits: typo fixes, single-function rewrites, mechanical renames. Hard-refuses 3+ file scope.
- **cavecrew-reviewer** — diff / branch / file review with severity-tagged one-line findings. Review only.
- **codex:codex-rescue** — terminal/scripting workflows, second implementation or diagnosis pass, deep root-cause. Independent engine; validate before merge.
- **Agent + `model: haiku`** — cheap localized tasks: tests, docs, schema mappings, repetitive CRUD, log parsing. Weak at deep architectural reasoning.
- **Agent + `model: opus`** — unresolved failures, security design, hard debugging, core architecture. Maximum reasoning depth; highest latency and cost.

A plugin-availability paragraph follows the matrix with fallback routing (`cavecrew-investigator` → `Explore`, `cavecrew-builder` → `Agent + model: haiku`, `cavecrew-reviewer` / `codex:codex-rescue` → `general-purpose`) for harnesses without the `caveman` / `codex` plugins.

### Delegation Requirements

When delegating: provide explicit task scope, include architectural constraints, supply relevant interfaces and types, keep tasks focused and bounded, request implementation-ready outputs, avoid open-ended rewrites. All delegated outputs return to the coordinating agent for validation, reconciliation, testing, and integration review.

### Verification Policy

Five mandatory checks on delegated outputs: architectural consistency review, project-convention validation, testing before merge, reconciliation with `CLAUDE.md`, and side-effect evaluation. Do not merge delegated outputs without review.

### Parallel Delegation

When beneficial, fan out to multiple agents simultaneously: Explore/cavecrew-investigator for in-session reads and code-locate, general-purpose for repo-wide discovery, Agent + `model: haiku` for tests/docs, codex:codex-rescue for scripts/tooling, the main thread for orchestration, Agent + `model: opus` for escalation. Parallel delegation should improve throughput without fragmenting architectural ownership.

### Trigger Phrase Routing

A 14-row table mapping common user phrasings to target agents. Examples: "Generate exhaustive unit tests for…" → Agent + `model: haiku`. "Find where X is defined…" → cavecrew-investigator. "Scan the repository for…" → general-purpose. "Review this diff / PR…" → cavecrew-reviewer. "Design the architecture for…" → Plan. "Refactor this subsystem safely…" → main thread. "Write a shell script to…" → codex:codex-rescue. The table is the matrix's "by example" companion.

### Escalation Logic

Six-step ordering: start on the main thread → use Explore/cavecrew-investigator for bulk reads and code-locate → delegate localized work to Agent + `model: haiku` → use general-purpose for repo-wide or multi-step discovery → use codex:codex-rescue for execution-heavy or second-opinion workflows → escalate to Agent + `model: opus` when blocked, when architectural uncertainty persists, when debugging becomes non-deterministic, or when security/systems reasoning becomes critical. Escalation is intentional, not automatic.

### Repository Discovery Guidance

Splits fast in-session vs. open-ended multi-step discovery. **Explore** (or **cavecrew-investigator** for compressed locate-only output) for searching the current repository, enumerating files, locating definitions, and preserving the main context window. **general-purpose** for open-ended searches where first tries may miss, dependency chains across many files, and multi-step research needing the full toolset. Both are discovery agents; implementation derived from their analysis must be validated on the main thread before merge.

### Avoid Delegation When

Five anti-patterns: small edits solvable in current context, highly coupled changes requiring deep continuity, security-sensitive implementations without review, active merge-conflict areas, and tasks where delegation overhead exceeds implementation effort. Excessive delegation increases fragmentation and integration cost.

### Operational Principles

Six concise rules: prefer focused over broad delegation; preserve architectural ownership in the coordinator; optimize for correctness over token savings; treat specialized agents as force multipliers, not replacements; keep implementation responsibility centralized; minimize context fragmentation.

## Setup / Installation

### Why a hook is required

The rule's design history is load-bearing. An earlier POC version was loaded into context but never consulted before action. The agent's failure mode — already documented in `defensive-protocol-v2-anti-slop.md` as "optimizing for completion by batching many actions" — wins against any passive matrix. Adding more text to the rule does not fix this; the text is already in context. What is missing is a forcing function that fires at the right moment.

A `UserPromptSubmit` hook is the right mechanism. Hooks fire deterministically — they do not depend on the agent remembering to consult them. The hook scans the user's prompt for bulk-work keywords and, on match, injects a one-line reminder asking the agent to state its delegation decision before the first tool call. The agent then sees the reminder when it is about to pick a tool, not when it is reading the rule file.

### Installer usage

```bash
bash scripts/agent-delegation/install.sh <target-repo-path>
```

The installer:

1. Copies `rules/agent-delegation.md` to `<target>/.claude/rules/agent-delegation.md`.
2. Merges a `UserPromptSubmit` hook into `<target>/.claude/settings.json`, creating the file with `{}` if missing and preserving all existing keys.
3. Is idempotent — re-running does not duplicate the hook entry. Idempotency is keyed off the `agent-delegation-hook v1` marker on the first line of the hook command.

Required dependency: `jq`. The installer exits with a clear error if `jq` is not on `PATH`.

The installer does not have an executable bit set (per the Script Safety section of `defensive-protocol-v2-anti-slop.md`). Always invoke with an explicit `bash` interpreter.

### Hook contract

The hook is a `UserPromptSubmit` entry with `matcher: "*"` and a single inline command:

```bash
# agent-delegation-hook v1
prompt=$(jq -r '.prompt' < /dev/stdin)
if printf '%s' "$prompt" | grep -Eqi 'audit|categorize|review all|find every|across the docs|enumerate|inventory|sweep'; then
  printf 'Reminder (agent-delegation rule): if this task involves bulk discovery (>5 reads, repo-wide grep, multi-file audit), state your delegation decision before the first tool call.\n'
fi
exit 0
```

Behaviour:

- Reads the user's prompt from stdin (Claude Code delivers a JSON payload with `.prompt`).
- Case-insensitive `grep -E` against the keyword set.
- On match, prints the reminder line on stdout — Claude Code injects stdout as additional context before the agent processes the prompt.
- On no match, exits silently. No injection, no overhead.

The keyword set is intentionally narrow to keep false positives low. To change keywords, edit the heredoc in `scripts/agent-delegation/install.sh`, bump the marker (`v1` → `v2`), then re-run the installer. Editing the rule file does **not** affect the installed hook — the `command` value in `.claude/settings.json` is a static string captured at install time. The bumped marker is what forces a re-install over an existing `v1` entry.

### Manual install

If you cannot use the installer, copy the rule and add the hook entry by hand:

```bash
cp rules/agent-delegation.md <target>/.claude/rules/agent-delegation.md
```

Then merge the JSON shape below into `<target>/.claude/settings.json` under `.hooks.UserPromptSubmit`:

```json
{
  "matcher": "*",
  "hooks": [
    {
      "type": "command",
      "command": "<inline command from Hook Contract above>",
      "timeout": 5
    }
  ]
}
```

The `command` value must be a JSON-escaped single string (newlines as `\n`). The installer handles this via `jq --arg`; doing it by hand is error-prone — prefer the installer.

### Verification

Confirm the rule and hook are wired correctly:

```bash
# 1. Rule file landed
test -f <target>/.claude/rules/agent-delegation.md && echo OK

# 2. Hook entry present (marker-keyed — robust to other UserPromptSubmit hooks)
jq -r '.hooks.UserPromptSubmit[].hooks[].command' <target>/.claude/settings.json \
  | grep -q 'agent-delegation-hook v1' && echo OK

# Extract the agent-delegation hook by its marker, NOT by array index, in case
# the target already had other UserPromptSubmit hooks ahead of it.
HOOK_CMD=$(jq -r '
  [.hooks.UserPromptSubmit[].hooks[]
   | select(.command? | type == "string" and contains("agent-delegation-hook v1"))
   | .command][0]' <target>/.claude/settings.json)

# 3. Hook fires on a matching prompt
printf '{"prompt":"please audit the docs directory"}' | bash -c "$HOOK_CMD"
# expect: a single line starting with "Reminder (agent-delegation rule):"

# 4. Hook silent on a non-matching prompt
printf '{"prompt":"fix the typo on line 12"}' | bash -c "$HOOK_CMD"
# expect: no output, exit 0
```

Restart Claude Code in the target repo after install — settings are loaded once per session.

### Uninstall

Remove the rule file and the hook entry:

```bash
rm <target>/.claude/rules/agent-delegation.md
jq 'del(.hooks.UserPromptSubmit[] | select(.hooks[]?.command | tostring | contains("agent-delegation-hook v1")))' \
  <target>/.claude/settings.json > /tmp/settings.tmp \
  && mv /tmp/settings.tmp <target>/.claude/settings.json
```

If `.hooks.UserPromptSubmit` is then empty, the entry is harmless but can be cleaned up by hand.

### Troubleshooting

- **Hook does not fire.** Confirm the prompt actually contains a keyword from the set (case-insensitive). The match is substring-based via `grep -E`, so partial words count — "auditing" matches "audit". If the prompt is paraphrased without keywords, the hook stays silent by design; the rule's matrix is still in context but consultation falls back to the agent's judgment.
- **Hook errors.** Run the inline command manually with a sample stdin payload (see Verification step 3). Most failures are missing `jq` or a malformed `settings.json` (run `jq '.' <target>/.claude/settings.json` to validate).
- **Reminder appears but agent ignores it.** The hook ensures the agent *sees* the reminder; it cannot force action. If the agent still skips delegation, file the failure case alongside the prompt — it indicates either the keyword set or the reminder text needs tuning.
- **`jq` not installed.** The installer requires `jq` for safe JSON merging. Install with `brew install jq` (macOS) or `apt install jq` (Debian/Ubuntu).

## Related Rules

- `rules/defensive-protocol-v2-anti-slop.md` — Names the "default-to-action" failure mode this rule's hook is designed to counter. Worth reading together.
- `rules/defensive-protocol-v2-epistemology.md` — Companion v2 module for reasoning under uncertainty; complements the delegation matrix's escalation logic.
- `rules/defensive-protocol-v2-session-management.md` — Companion v2 module for session continuity; relevant when delegated work spans long sessions.
