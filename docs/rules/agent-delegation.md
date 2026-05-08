# Multi-Agent Delegation

**Source:** `rules/agent-delegation.md`
**Scope:** All project types — multi-agent delegation strategy for Claude Code sessions
**Activation:** Automatic — loaded when placed in `.claude/rules/`. **Requires** a `UserPromptSubmit` hook to fire reliably (see Setup / Installation).

## Core Principle

State the delegation decision before the first tool call on any bulk task. The matrix is only consulted reliably when the harness forces consultation — passive context loses to the agent's default-to-action bias.

## Overview

This rule defines which sub-agent should handle which class of work. The delegation matrix covers six agents — Sonnet (coordinator), Haiku (cheap localized work), Opus (deep reasoning), Codex (terminal/scripting), Gemini (long-context discovery), and Explore (in-session bulk reads) — with explicit trigger phrases, escalation logic, and avoidance criteria.

The rule ships with a companion `UserPromptSubmit` hook because field testing showed that loading the matrix into context is not enough. Without a forcing function, the agent reads the rule but routes around it: by the time a bulk task arrives, "act now" beats "consult the matrix" on every iteration. The hook injects a one-line reminder when the user's prompt matches bulk-work keywords, raising the trigger card to the agent's attention at the moment it is about to pick its first tool.

Adopt this rule on any project where Claude Code is the primary development agent. The hook is harmless on solo workflows (it only fires on bulk-work keywords) and load-bearing on workflows that actually use sub-agents.

## Sections

### Trigger Card

A six-line fast-path table at the top of the rule. Maps task shape to agent: bulk discovery → Explore, bash/logs → Haiku, repo-wide search → Gemini, architecture/blocker → Opus, terminal/scripting → Codex, default → Sonnet. Designed to drop consultation cost from "re-read the matrix" to "scan five lines."

### Entry Condition

A single forcing sentence: "Before starting any task with more than five read-only tool calls, multi-file enumeration, or repo-wide search, state which agent should run it — including 'me'." Converts the rule from passive matrix to active checklist. The hook (Setup / Installation, below) is what makes this fire reliably.

### Philosophy

Establishes that delegation is a deliberate optimization for context efficiency, iteration speed, token cost, specialization, and reduced cognitive fragmentation — not a way to offload responsibility. The coordinating agent retains architectural ownership even when subtasks are delegated.

### Primary Coordinator (Sonnet)

Sonnet is the default development and orchestration agent. Responsibilities: multi-step coordination, architectural consistency, `CLAUDE.md` enforcement, integration of delegated outputs, correctness validation, and nuanced refactoring. Even when delegation occurs, Sonnet remains responsible for final integration, consistency validation, project-wide reasoning, and implementation cohesion.

### Delegation Matrix

Six rows. Each lists the agent, when to delegate to it, its strengths, and its weaknesses:

- **Sonnet** — default for feature development, refactoring, debugging, coordinated multi-file changes. Best balance of reasoning, context retention, architectural cohesion. Less cost-efficient for repetitive boilerplate.
- **Haiku** — tests, documentation, schema mappings, repetitive CRUD, simple UI/CSS. Fast and cheap for localized tasks. Weak at deep architectural reasoning.
- **Opus** — unresolved system failures, security design, difficult debugging, core architecture decisions. Maximum reasoning depth. Highest latency and cost.
- **Codex** — terminal workflows, shell scripts, deterministic implementation, regex transformations, tooling glue. Strong execution accuracy. Smaller effective context, weaker project-wide cohesion.
- **Gemini** — repository-wide discovery, large log analysis, legacy codebase scanning, long-document ingestion. Massive context window. Lower implementation precision; outputs require validation.
- **Explore** — bulk read-only discovery, multi-file enumeration, "where is X defined" questions, initial codebase reconnaissance. Built-in Claude Code subagent; preserves the main context window. Read-only; reads excerpts, not whole files; misses content past its read window.

### Delegation Requirements

When delegating: provide explicit task scope, include architectural constraints, supply relevant interfaces and types, keep tasks focused and bounded, request implementation-ready outputs, avoid open-ended rewrites. All delegated outputs return to the coordinating agent for validation, reconciliation, testing, and integration review.

### Verification Policy

Five mandatory checks on delegated outputs: architectural consistency review, project-convention validation, testing before merge, reconciliation with `CLAUDE.md`, and side-effect evaluation. Do not merge delegated outputs without review.

### Parallel Delegation

When beneficial, fan out to multiple agents simultaneously: Explore for in-session reads, Gemini for cross-repository discovery, Haiku for tests/docs, Codex for scripts/tooling, Sonnet for orchestration, Opus for escalation. Parallel delegation should improve throughput without fragmenting architectural ownership.

### Trigger Phrase Routing

A 12-row table mapping common user phrasings to target agents. Examples: "Generate exhaustive unit tests for…" → Haiku. "Find where X is defined…" → Explore. "Scan the repository for…" → Gemini. "Design the architecture for…" → Opus. "Refactor this subsystem safely…" → Sonnet. "Write a shell script to…" → Codex. The table is the matrix's "by example" companion.

### Escalation Logic

Six-step ordering: start with Sonnet → use Explore for bulk reads → delegate localized work to Haiku → use Gemini for repo-wide work → use Codex for execution-heavy workflows → escalate to Opus when blocked, when architectural uncertainty persists, when debugging becomes non-deterministic, or when security/systems reasoning becomes critical. Escalation is intentional, not automatic.

### Repository Discovery Guidance

Splits in-session vs. long-context discovery. **Explore** for searching the current repository, enumerating files, locating definitions, and preserving the main context window. **Gemini** for legacy or massive repositories, dependency chains across millions of lines, log analysis, long-document ingestion. Both are discovery tools; implementation derived from their analysis must be validated by Sonnet or Opus before merge.

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
bash scripts/install-agent-delegation.sh <target-repo-path>
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

The keyword set is intentionally narrow to keep false positives low. Add or remove keywords by editing the rule file's Setup section, then re-running the installer with a bumped marker (`v1` → `v2`).

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

# 2. Hook entry present
jq -r '.hooks.UserPromptSubmit[].hooks[].command' <target>/.claude/settings.json \
  | grep -q 'agent-delegation-hook v1' && echo OK

# 3. Hook fires on a matching prompt
printf '{"prompt":"please audit the docs directory"}' \
  | bash -c "$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' <target>/.claude/settings.json)"
# expect: a single line starting with "Reminder (agent-delegation rule):"

# 4. Hook silent on a non-matching prompt
printf '{"prompt":"fix the typo on line 12"}' \
  | bash -c "$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' <target>/.claude/settings.json)"
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
