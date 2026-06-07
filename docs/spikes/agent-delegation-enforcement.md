# Spike: Agent Delegation Enforcement

## Question

How can we improve the existing `agent-delegation` rule + hook system so that sub-agent delegation is triggered **more frequently** and **more efficiently** — fires on actual bulk/heavy-read work shape (low false-negative), without nagging on trivial prompts (low false-positive), and without mid-task blind spots — while preserving architectural ownership in the coordinating agent?

## Available Tooling

Mechanisms evaluated as candidates for improving delegation triggering:

- `UserPromptSubmit` hook (current approach — keyword tripwire on prompt text)
- `PreToolUse` hook (work-shape detection: counter on read-only calls; soft `additionalContext` nudge vs hard `deny` redirect; `type:"prompt"`/`type:"agent"` LLM judge)
- `PostToolUse` / `PostToolBatch` / `Stop` / `SubagentStop` / `SubagentStart` hooks
- Custom subagents in `.claude/agents/*.md` (description-driven auto-delegation)
- Output styles, `CLAUDE.md`/rules, `Task`/`Agent` tool description, slash commands, skills, `SessionStart`
- External sources via firecrawl (live `code.claude.com` docs + Anthropic engineering blog) and context7 MCP (`/websites/code_claude`)

## Methodology

Two-agent sequential spike (D-01): a research agent investigated, then an independent red-team agent adversarially verified every load-bearing claim against fresh sources.

Sub-questions: (1) which hook events detect work-shape / inject context / block, and the exact output protocol of each; (2) can a `PreToolUse` hook count across calls — is `session_id` available, what input fields exist; (3) what delegation targets exist and how `description` drives auto-delegation; (4) which non-hook mechanisms change runtime behavior vs are passive; (5) Anthropic's own multi-agent guidance.

Sources (all live, May 2026): firecrawl scrapes of `code.claude.com/docs/en/hooks`, `/sub-agents`, `/output-styles`, `/slash-commands`, the Claude Code changelog, and `anthropic.com/engineering/multi-agent-research-system`; context7 `query-docs` against `/websites/code_claude` (including the SDK `PreToolUseHookSpecificOutput` TypedDict); direct repo inspection of `rules/agent-delegation.md`, `scripts/agent-delegation/install.sh`, and `.claude/settings.json`.

## Findings

### Confirmed defects in the current system

All four suspected weaknesses verified against the installed hook and the lifecycle docs:

1. **Work-shape blindness.** The installed hook greps `.prompt` text against `audit|categorize|review all|find every|across the docs|enumerate|inventory|sweep`. It matches prompt *text*, not work *shape*. Bulk tasks phrased without a keyword ("where is X used", "map the deps", "trace callers of foo", "go through the components") never fire it → high false-negative.
2. **Mid-task blind spot.** `UserPromptSubmit` fires once per turn on the user's submission only. Delegation needs arising from the agent's own mid-task planning (e.g. deciding to grep the whole repo three steps into a feature) get no nudge. Verified: `UserPromptSubmit` is once-per-turn; tool calls live in the nested agentic loop.
3. **False positives.** A trivial prompt containing a keyword ("what does inventory mean here?") fires needlessly.
4. **The rule alone is passive.** As `CLAUDE.md`-style context it is "a user message after the system prompt" — routed around by the agent's default-to-action bias (the rule itself says so).

### Empty-target gap

The repo has **zero custom subagents** (`.claude/agents/` does not exist). The delegation matrix names Haiku / Opus / Gemini / Codex as "agents", but only `Explore`, `Plan`, and `general-purpose` are real Claude Code subagents — Gemini/Codex are external CLIs invoked via Bash/skills. So model-initiated auto-delegation currently has almost nothing concrete to route to.

### Mechanism analysis (verified protocols)

- **`PreToolUse` is the only event that fires mid-task on every tool call** and can see work shape. Input includes `session_id`, `transcript_path`, `cwd`, `permission_mode`, `tool_name`, `tool_input`, `tool_use_id`, `effort` (`.level ∈ low/medium/high/xhigh/max`), and — inside a subagent — `agent_id` / `agent_type` (use these to suppress the nudge when already inside a subagent). A per-session counter file keyed by `session_id` is feasible; the hook is a fresh process per call, so state must be external.
- **`PreToolUse` supports `additionalContext`** (added in changelog 2.1.9, verified verbatim). It is delivered alongside the tool result. Soft-nudge output shape:
  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "additionalContext": "agent-delegation: N read-only calls this turn with no delegation. Run bulk discovery in an Explore subagent (preserves main context). State your delegation decision before continuing."
    }
  }
  ```
  Omitting `permissionDecision` leaves the normal permission flow untouched while still delivering `additionalContext` (resolved to high confidence via the SDK TypedDict where both fields are independently `NotRequired`, plus the 2.1.110 changelog fix proving the dropped-context bug was only on the tool-*failure* path — not live-smoke-tested).
- **Hard redirect** is possible via `permissionDecision: "deny"` + `permissionDecisionReason` (shown to Claude), precedence `deny > defer > ask > allow` — but aggressive and loop-prone.
- **`PreToolUse` `type:"prompt"` judge**: sends tool input + prompt to a fast model (Haiku default), returns `{ok, reason}`; on `ok:false` the call is denied. Lowest false-positive but adds a model call per check — gate behind the cheap counter.
- **`PostToolBatch`** fires once after a parallel batch resolves, with `tool_calls[]` visible (atomic batch signal). Note `tool_response` for `Read` carries full file bodies and can be large.
- **`SubagentStart`** can inject `additionalContext` into a spawned subagent (enforce "return path + summary, not raw dumps" at spawn). **`SubagentStop`** does NOT support `additionalContext` — to inject context after a subagent returns, use `PostToolUse` on the `Agent` tool, whose `tool_response` carries `totalTokens` / `totalDurationMs` / `totalToolUseCount` (telemetry for an eval loop).
- **Custom subagent `description`** is the documented driver of model-initiated auto-delegation; "use proactively" is the documented trigger phrase. Frontmatter supports `name`, `description`, `tools`, `model` (incl. `haiku`), and more.
- **Output styles** modify the *system prompt* every turn (stronger than a rule's appended user message) but drop built-in SWE instructions unless `keep-coding-instructions: true`.

### External best practices (Anthropic multi-agent guidance)

- "Scale effort to query complexity": simple fact-finding = 1 agent / 3–10 calls; comparisons = 2–4 subagents; complex research = 10+. Directly transferable to threshold tuning.
- Token economics: agents ≈4× chat tokens, multi-agent ≈15×; token usage explains ~80% of performance variance; coding is among the *least* parallelizable workloads. → Reserve delegation for high-value bulk/parallel discovery, not blanket coding.
- "Subagent output to filesystem to minimize the game of telephone" — return lightweight references, not raw content.

### Comparison matrix

| Mechanism | Work-shape? | Mid-task? | Block/redirect? | False-pos risk | Complexity |
|---|---|---|---|---|---|
| UserPromptSubmit (current) | No (prompt text) | No (once/turn) | Yes (`decision:block`) | Med | Low |
| PreToolUse counter (soft) | Yes | Yes | Soft (`additionalContext`) | Low | Med |
| PreToolUse `prompt` judge | Yes (LLM) | Yes | Yes (`ok:false`→deny) | Lowest | Med-High |
| PostToolBatch | Yes (batch) | Yes (once/batch) | Yes | Low | Med |
| PostToolUse on `Agent` | n/a (measures) | Yes | No | n/a | Low |
| SubagentStart | n/a | At spawn | No | n/a | Low |
| Custom subagent `description` | Yes (model) | Yes | n/a (it IS delegation) | Low-Med | Low |
| Output style (orchestrator) | No (always-on) | n/a | No | Med | Low-Med |
| CLAUDE.md / rule (current) | No | No | No | n/a | Low |

## Red-Team Assessment

Overall quality: **thorough** (with one materially flawed recommendation — the regex broadening — and an overstated central ranking).

Claims verified: **13 out of 14 key technical claims independently checked** against the live `code.claude.com` docs (scraped fresh May 2026, not the research agent's cached files), the live changelog, the context7 `/websites/code_claude` type definitions, an independent WebSearch of Anthropic's multi-agent post, and direct repo inspection. The one remaining claim (omit-`permissionDecision` runtime behavior) could not be settled by a live smoke test, but type-level + changelog evidence resolves it to high confidence.

Issues found: **6** (1 factual/quantitative error in a recommendation, 1 muddled rationale, 4 reasoning/scope challenges).

### Verification ledger (independent sources only)

| # | Claim | Verdict | Independent evidence |
|---|---|---|---|
| 1 | `PreToolUse` `additionalContext` added in changelog 2.1.9 | **TRUE (exact)** | changelog line "2.1.9 — Added support for `PreToolUse` hooks to return `additionalContext` to the model"; corroborated by context7. |
| 1b | `additionalContext` delivered when `permissionDecision` OMITTED | **TRUE (high confidence, not live-tested)** | SDK `PreToolUseHookSpecificOutput` TypedDict: `permissionDecision` AND `additionalContext` both independently `NotRequired`. Field table only conditions it on `defer`, not on omission. Changelog 2.1.110 fix "additionalContext being dropped when the tool call fails" proves the normal/allowed path already delivers it. |
| 2 | `session_id` in PreToolUse input | **TRUE** | Common-input-fields table; appears in the PreToolUse stdin example. |
| 2b | `agent_id` / `agent_type` real fields inside subagents | **TRUE (exact)** | "When running with `--agent` or inside a subagent, two additional fields are included." `agent_id` "Present only when the hook fires inside a subagent call." |
| 2c | Subagent reads share parent `session_id`, scoped by `agent_id` | **TRUE (supported)** | No field grants subagents a distinct `session_id`; `agent_id` is the documented discriminator. |
| 3 | `PostToolBatch` exists with `tool_calls[]` input | **TRUE (exact)** | Dedicated section; lifecycle table; `tool_calls` array example. |
| 4 | `effort` / `$CLAUDE_EFFORT` on PreToolUse | **TRUE** | Common-input-fields table. |
| 5 | `type:"prompt"` hook, Haiku default, `{ok,reason}`, PreToolUse `ok:false`→deny | **TRUE (exact)** | Hook-types docs. |
| 6 | "use proactively" drives auto-delegation; `description` is the driver | **TRUE (exact)** | "To encourage proactive delegation, include phrases like 'use proactively' in your subagent's description field." |
| 6b | `model: haiku` is a valid frontmatter value | **TRUE** | Frontmatter table accepts `sonnet`/`opus`/`haiku`/full ID/`inherit`. |
| 7 | SubagentStop does NOT support `additionalContext` | **TRUE (exact)** | "They do not support `additionalContext`… use a `PostToolUse` hook on the `Agent` tool instead." |
| 8 | UserPromptSubmit once-per-turn; PreToolUse every tool call | **TRUE** | Cadence docs. |
| 9 | Zero custom subagents exist today | **TRUE** | No `.claude/agents/` in repo or `~/.claude/agents/`. |
| 10 | Anthropic 4× / 15× token figures | **TRUE** | Independent WebSearch confirms. |

### Factual Errors

1. **The broadened regex (research rec #2) is a false-positive machine.** Run against 12 trivial/non-bulk prompts, the proposed pattern **fired on 9 of 12**, including "go through the auth flow with me", "is X used anywhere", "where is the bug in my logic", "explain how dependencies work in npm", "list all the reasons this could fail", "how do I grep recursively". Bare tokens `used`, `dependenc`, `grep`, `go through`, `walk through`, `list all`, `where is` are high-frequency in ordinary coding dialogue and carry no bulk-work signal. The current regex fired on only 1 of the same 12. The research traded a high-false-negative regex for a high-false-positive one and did not stress-test it. **Correction:** if kept, require multiplicity/scope anchors, not bare verbs — e.g. `\b(every|all)\s+\w+\s+(file|module|component|usage|reference|caller)s?\b`, `\brepo-wide\b`, `\bacross (the )?(codebase|repo)\b`. Better: the PreToolUse counter makes the prompt-stage regex nearly redundant, so the broadening should be demoted or dropped.

(No other factual/technical errors found — hook mechanics, field names, version numbers, frontmatter schema, and Anthropic figures all check out exactly.)

### Missing Alternatives

- **Output style as a primary lever, not a footnote.** It modifies the system prompt every turn (the rule only appends a user message). Given Anthropic's finding that token usage explains 80% of variance and that description-based auto-delegation "isn't enough" (docs' words), durable system-prompt framing may move behavior more than any per-call nudge. Deserved a real comparison incl. the `keep-coding-instructions: true` test.
- **`SessionStart` `initialUserMessage` / a session-wide `--agent` orchestrator** that *replaces the system prompt entirely* — for a repo whose purpose is delegation discipline, making the orchestrator persona the session default is structurally stronger than nudging a default-SWE agent.
- **Lower the bar to delegate rather than detect when to.** With zero subagents and a matrix pointing at non-subagents, the agent has nothing cheap/obvious to route to. Shipping 2–3 well-described subagents may raise delegation frequency more than any hook.
- **No-hook telemetry-first approach.** Instrument current state with only the `PostToolUse`-on-`Agent` logger to measure the actual baseline before building detection machinery.

### Reasoning Issues

1. **The central ranking is probably inverted.** A trigger is worthless without a target. The research verifies zero custom subagents exist, yet ranks the PreToolUse counter #1 and "create real subagents" #3. Creating subagents is the dependency-free, no-new-process, no-race, no-latency, model-initiated fix — it should be #1; the counter is at best a complement.
2. **Nudge fatigue / "passive rule is ignored" is relocated, not solved.** `additionalContext` is *also* soft, injected context — the same epistemic status as the rule the research declares "routed around". The docs even warn imperative phrasing can trip prompt-injection defenses and surface the text to the user instead of acting on it. No evidence offered that a soft nudge changes behavior more reliably than the existing rule; only the hard `deny` path forces change, and that is loop-prone.
3. **The efficiency framing contradicts the cited evidence.** Goal is "more efficient", yet recs add per-call overhead, and Anthropic's own data (15× tokens for multi-agent, coding least parallelizable) implies *total*-token efficiency often gets worse. Spawning an Explore subagent for a 6-read task can cost more total tokens than reading inline — you pay the subagent's system prompt + summarization round-trip to save main-context tokens. The research conflates **context-window efficiency** with **total-token efficiency** and never quantifies the trade.
4. **Rec #4's rationale is muddled.** `PreToolUse` fires before *each* call, so 8 parallel Reads = 8 invocations; the counter does not structurally undercount — the only undercount is the race condition (flagged separately). PostToolBatch is a legitimately cleaner *atomic* signal, but the stated reason misattributes why.

### Unverified Assumptions

- "Soft `additionalContext` nudges change behavior" — load-bearing under recs #1/#4/#5, never demonstrated; same epistemic status as "the rule will be consulted" (declared false).
- A read-only subagent `description` reliably triggers model-initiated delegation — docs confirm the mechanism but hedge ("when automatic delegation isn't enough, request it yourself"); hit-rate unmeasured.
- The 5–6 threshold transfers from Anthropic's research-fan-out guidance to a per-call coding gate — plausible but unvalidated.
- Per-turn counter reset via UserPromptSubmit is sound — admitted untested; an intermediate "continue" prompt would reset the counter mid-investigation and re-arm the nudge.
- `flock` availability — the named race fix is **absent on macOS by default** (the dev's platform is darwin); the counter sketch assumes a Linux coreutils environment the dev machine lacks.

### Version/Compatibility Concerns

- Consumer repos must be on **≥2.1.9** for the soft-nudge output to work; older clients silently get nothing. The installer does no version check.
- Omit-`permissionDecision` behavior resolved to high confidence but not live-tested — a 1-call smoke test should gate shipping.
- `defer` requires v2.1.89+; prompt-judge / `continueOnBlock` assume a recent client — no minimum-version note for the installer.
- `PostToolBatch` `tool_response` can be large (full file bodies; >10,000 chars spill to file) — a naive handler risks slow hooks and large injected context.
- macOS `flock` absent — installer would ship a racy counter on darwin.

### Strengths

- Core technical claims accurate (13/14 verified exactly); no fabrication or paraphrase-distortion.
- Honest uncertainty labeling — the two soft spots (omit-`permissionDecision`; counter race) both flagged in Open Questions.
- Correct diagnosis of the two real defects (work-shape-blind regex; once-per-turn cadence).
- Correctly surfaced the empty-target gap (it just under-ranked it).
- The `agent_id`-suppression detail (don't nudge Explore to delegate to Explore) is sharp and correct.
- Recs to create real subagents, push the delegation contract via SubagentStart, and instrument Agent calls are low-risk and well-founded.

## Recommendation

**Adopt the red-team's re-ordering. Ship targets before triggers, and measure before adding detection machinery.** The research is technically sound (13/14 claims verified), but its ranking optimizes for the most novel mechanism rather than the highest-leverage one.

Recommended sequence:

1. **Create 2–3 real custom subagents under `.claude/agents/` (highest leverage, do first).** At minimum a read-only `bulk-explorer` (`tools: Read, Grep, Glob`, `model: haiku`, description using "use PROACTIVELY for repo-wide discovery … >5 read-only calls … returns a path-map + summary, never raw dumps"). This is the only change that enables *model-initiated* auto-delegation, costs one file each, adds no hook processes, and has no race conditions. Without targets, every trigger can only say "go use Explore" — so this is the dependency for everything else. It also reconciles the matrix (which points at Haiku/Opus/Gemini/Codex — not Claude Code subagents) with what actually exists.

2. **Add `PostToolUse`-on-`Agent` telemetry now, and measure the baseline before building more.** Log `totalTokens` / `totalDurationMs` / `totalToolUseCount` per delegation. This both closes the eval loop and tests the unproven premise (do soft nudges and new subagents actually change behavior?) before investing in the counter.

3. **Add the `PreToolUse` counter as a soft `additionalContext` nudge (complement, not centerpiece).** Matcher `Read|Grep|Glob`; session-scoped counter file; suppress when `agent_id` is present; reset per turn. Ship only after: (a) a 1-call smoke test confirms `additionalContext` is delivered when `permissionDecision` is omitted; (b) the counter uses a **macOS-safe** lock (`mkdir`-based mutex, not `flock`) or accepts undercount (safe — it only delays the nudge); (c) the installer adds a client-version note (≥2.1.9). Prefer the soft nudge over `deny` (loop risk).

4. **Push the delegation contract via `SubagentStart` `additionalContext`** ("objective + output format + boundaries; return path + summary, not raw content"). Low risk, enforces fidelity at spawn.

5. **DROP or tightly anchor the `UserPromptSubmit` regex broadening.** The proposed broad pattern fires on 9/12 trivial prompts. If kept at all, require multiplicity/scope anchors (`every|all … files|components|usages`, `repo-wide`, `across the codebase`). The PreToolUse counter makes prompt-stage matching largely redundant.

6. **Optional, deferred: `PostToolBatch` nudge and a Haiku `prompt`-judge** — only if telemetry shows the counter alone has too high a false-rate. Gate the judge behind the counter to bound cost.

### Remaining risks after red-team review

- **Soft nudges may be ignored** exactly like the passive rule — this is unproven either way. Recommendation 2 (telemetry) exists specifically to detect this; do not over-build until the data is in.
- **Total-token efficiency may worsen** even as main-context efficiency improves. Delegation pays off for genuine bulk/parallel read-only discovery (Anthropic's "scale effort to complexity"), not for small or tightly-coupled coding tasks. Keep thresholds high (≥5) and never auto-delegate implementation/integration.
- **Auto-delegation hit-rate of `description` fields is a soft model judgment**, not deterministic — measured by the telemetry in step 2.
- **Version dependency**: soft-nudge output is silent on clients <2.1.9.

### Revisit conditions

- After step 2 telemetry yields a baseline delegation rate and per-delegation token deltas — re-rank the remaining steps against real data.
- If consumer clients are below 2.1.9 (soft nudge silently no-ops) → fall back to plain-stdout `UserPromptSubmit` context.
- If nudge fatigue appears in transcripts (agent acknowledging then ignoring injected reminders) → escalate to an output-style/orchestrator-agent system-prompt approach instead of more hooks.

## Suggestions for Deeper Review

Open items identified after the spike was assembled. This document is comprehensive as a research/decision artifact but not yet as an implementation or distribution spec. The following are flagged as options for a later, more thorough review — none are resolved here.

1. **Distribution path (highest priority).** This system is a *distributable installer*: `scripts/agent-delegation/install.sh` ships the rule + `UserPromptSubmit` hook into consumer repos. Every recommendation above is currently framed as a local edit to this repo. Decide and document how each rec reaches consumers:
   - Should `install.sh` also copy `.claude/agents/*` subagents into the target?
   - Should it merge the new `PreToolUse` counter, `SubagentStart`, and `PostToolUse`-on-`Agent` hooks (each with its own idempotency marker)?
   - If recs stay local-only, state explicitly that they do not propagate to consumers and why.
   Without this, the improvements never reach the people who install the system.

2. **Build-ready artifacts.** The doc is decision-ready, not build-ready. A deeper pass should attach concrete files:
   - Full `.claude/agents/bulk-explorer.md` (frontmatter + body) and any sibling subagents.
   - The final `PreToolUse` counter hook command (macOS-safe `mkdir` mutex, `agent_id` suppression, per-turn reset), the `SubagentStart` contract injector, and the `PostToolUse`-on-`Agent` telemetry logger.
   - An `install.sh` diff implementing whatever item 1 decides.

3. **Quantify the efficiency tension.** Red-team's sharpest unresolved point: main-context efficiency vs total-token efficiency. Add a concrete estimate (e.g. inline 6 reads vs an Explore spawn: system prompt + tool calls + summarization round-trip) so the ≥5 threshold is grounded in numbers, not borrowed from Anthropic's research-fan-out guidance.

4. **Correct the delegation matrix.** The rule's matrix names Haiku / Opus / Gemini / Codex as "agents", but only some are real Claude Code subagents (`Explore`, `Plan`, `general-purpose`, plus any custom `.claude/agents/*`); Gemini/Codex are external CLIs/plugin skills invoked via Bash. Produce a corrected table of *actually wired* targets in the consumer environment and how each is invoked, so the matrix advice maps to reachable mechanisms.

5. **Upgrade the existing hook for consistency.** The installed `UserPromptSubmit` hook emits plain stdout; the new counter is recommended to use structured `additionalContext`. Decide whether to migrate the existing hook to the same structured form (bump the marker `v1`→`v2`; installer is idempotent on the marker) so both hooks use one output convention.

6. **Close the protocol smoke test.** `additionalContext` delivered when `permissionDecision` is omitted = "high confidence, not live-tested." A single PreToolUse hook call would settle it. Run before committing to the rec #3 soft-nudge output shape; if it fails, fall back to `permissionDecision: "allow"` + `additionalContext` or to plain stdout.

## Status
open

## Follow-Up Log
(no follow-ups yet)
