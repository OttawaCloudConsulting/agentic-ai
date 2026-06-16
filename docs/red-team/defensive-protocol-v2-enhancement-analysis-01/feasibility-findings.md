# Feasibility Assessment

## Agent Persona

I am a red-team feasibility reviewer. I treat proposal claims as unproven until the artifact, repository state, or tool documentation provides specific evidence that the work can be built and delivered as described.

## Assessment Summary

Items examined: 34
Findings: 6 (Critical: 2, High: 1, Medium: 3, Low: 0)

## Findings

### Finding 1: P0 reminder arrives after the high-risk command runs

**Severity:** Critical
**Category:** Technical Infeasibility
**Observation:** The P0 `PreToolUse` sketch emits only `hookSpecificOutput.additionalContext`, so it does not force the agent to state DOING / EXPECT / IF MISMATCH before execution. Claude reads that context on the next model request, after the tool call has already completed.
**Evidence:** Target lines 184-202 describe the P0 hook as a pre-run prediction nudge and line 197 emits only `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"..."}}`. Current Claude Code hooks docs fetched with `curl -L -s https://code.claude.com/docs/en/hooks.md | sed -n '640,880p'` state: "Claude reads the reminder on the next model request" and list `PreToolUse` additional context as appearing "next to the tool result."
**Impact:** The highest-priority enhancement fails its central behavioral requirement. A destructive command executes first, and the prediction template appears only afterward.
**Recommendation:** For high-risk commands, return `permissionDecision: "ask"` or `permissionDecision: "deny"` with a clear reason, or use `exit 2` for hard blocks. Use `additionalContext` only for post-action context, not for mandatory pre-action pauses.

### Finding 2: Failure-reminder hook targets the wrong event

**Severity:** Critical
**Category:** Technical Infeasibility
**Observation:** The proposal repeatedly assigns Bash non-zero failure handling to `PostToolUse`, but current Claude Code separates successful and failed tool completion. `PostToolUse` runs only after success; failed tools trigger `PostToolUseFailure`.
**Evidence:** Target line 77 proposes "`PostToolUse` hook detecting non-zero Bash exit / tool error"; target line 212 proposes "`PostToolUse` failure-reminder hook: on non-zero tool exit." Current Claude Code docs fetched with `curl -L -s https://code.claude.com/docs/en/hooks.md | sed -n '1520,1660p'` state: "`PostToolUse` hooks fire after a tool has already executed successfully." The next section states: "`PostToolUseFailure` runs when a tool execution fails" and its sample input includes `"error": "Command exited with non-zero status code 1"`.
**Impact:** Implementing P2 as written leaves anti-slop failure reminders absent for the exact failure cases the hook is supposed to handle.
**Recommendation:** Replace the P2 event with `PostToolUseFailure` and read the top-level `error`, `tool_name`, and `tool_input` fields. Emit `hookSpecificOutput.hookEventName: "PostToolUseFailure"` with `additionalContext` containing the FAILED / THEORY / PROPOSE reminder.

### Finding 3: P0 command matcher misses common destructive variants

**Severity:** High
**Category:** Integration Risk
**Observation:** The shell `case` patterns are not a reliable detector for the proposed high-risk command set. They match narrow substrings, are case-sensitive, and miss real variants of `rm`, force pushes, SQL drops, migrations, and executable-bit changes.
**Evidence:** Target line 197 uses `case "$CMD" in *rm\ -rf*|*git*push*--force*|*git*push*-f*|*git*rebase*|*git*reset*--hard*|*DROP\ *|*\ migrate*|*chmod\ +x*)`. Running the exact parse-and-match logic against sample hook payloads produced:
`rm -r -f /tmp/build => no`; `rm -fr /tmp/build => no`; `git push origin +main => no`; `psql -c "drop table users" => no`; `migrate up => no`; `chmod u+x script.sh => no`; `chmod +rx script.sh => no`.
**Impact:** The hook gives a false sense of coverage. Agents can run destructive commands that are semantically inside the proposed trigger set without receiving any reminder or block.
**Recommendation:** Replace substring globs with a tested classifier. Use Claude Code's `if` field for coarse filtering, parse shell commands with a real parser or strict argv extraction, apply case-insensitive SQL matching, and explicitly cover chmod symbolic and numeric executable-bit modes.

### Finding 4: Action-counter hook understates state and concurrency work

**Severity:** Medium
**Category:** Integration Risk
**Observation:** A `PreToolUse` star-matcher that increments a temp-file counter is not a moderate reuse of the graphify pattern. It needs per-session identity, locking, reset semantics, cleanup, and batch behavior. The proposal gives none of those.
**Evidence:** Target line 118 proposes: "A `PreToolUse` (matcher `*`) hook can maintain a counter in a temp file." Current docs fetched with `curl -L -s https://code.claude.com/docs/en/hooks.md | grep -n "concurrent\\|parallel\\|spawns\\|every tool call"` state: "on every tool call inside the agentic loop"; "All matching hooks run in parallel"; and "`PostToolUse` fires once per tool, which means it fires concurrently when Claude makes parallel tool calls. `PostToolBatch` fires exactly once with the full batch."
**Impact:** A naive temp-file counter loses increments under concurrent hook runs and accumulates stale state across sessions. It also has no reliable way to reset when the agent performs a semantic "verification" unless verification is separately defined and detected.
**Recommendation:** Prefer the document's option b: replace count-based rules with event triggers. If a counter is still required, implement it as a real hook script using `session_id`-keyed storage, atomic locking, explicit reset triggers, TTL cleanup, and tests covering parallel tool batches.

### Finding 5: Installer idempotency is under-specified

**Severity:** Medium
**Category:** Integration Risk
**Observation:** The proposal treats a defensive installer as straightforward shell work, but the existing working pattern depends on `jq`, marker-based duplicate detection, valid JSON checks, temp-file writes, and marker versioning. Appending a CLAUDE.md block adds a second idempotency problem that the proposal does not address.
**Evidence:** Target line 144 recommends an installer that "copies the trio" and "merges the `PreToolUse` high-risk hook" using the "same idempotent pattern"; target line 214 repeats "copy trio + merge hooks + append CLAUDE.md block, idempotent." The existing installer states "Dependencies: jq" at `scripts/agent-delegation/install.sh:19`, rejects invalid settings JSON at lines 66-74, checks a hook marker at lines 91-95, and performs the array merge with `jq` at lines 101-112.
**Impact:** A re-run duplicates hooks or CLAUDE.md content unless the new installer copies the same marker and merge discipline for every inserted artifact. Command changes without a marker bump leave stale hooks installed; marker changes without migration create duplicate behavior.
**Recommendation:** Specify the installer contract before implementation: required `jq`, stable hook markers, version bump behavior, invalid JSON handling, atomic temp-file writes, CLAUDE.md block sentinels, and an idempotency test that runs the installer twice and diffs the result.

### Finding 6: Existing hooks prove configuration shape, not enforcement effectiveness

**Severity:** Medium
**Category:** Missing Proof-of-Concept
**Observation:** The document overstates the repository precedent. The installed hooks prove that `.claude/settings.json` contains hook entries and that their JSON shape matches current docs. They do not prove that the proposed defensive behavior is enforced before risky actions.
**Evidence:** Target lines 60-65 conclude: "Both are exactly the shape needed to enforce the defensive trio. The mechanism is solved and in production here." The real `.claude/settings.json` contains only a `UserPromptSubmit` plaintext reminder at lines 3-10 and a `PreToolUse:Bash` graphify `additionalContext` reminder at lines 15-22. Current docs state `additionalContext` is read on the next model request, and the target file provides no transcript, test harness, or runtime evidence showing a hook caused the agent to consult a rule before a risky action.
**Impact:** The effort estimate is too optimistic. The repo precedent supports hook installation syntax, not the stronger claim that the proposed hooks reliably enforce stop-on-failure, pre-risk prediction, or verification cadence.
**Recommendation:** Add a proof-of-concept harness before claiming feasibility: run Claude Code with a controlled settings file, issue sample prompts for `rm -rf`, `chmod u+x`, failing Bash commands, and bulk prompts, then capture transcripts showing exactly when Claude receives and acts on each hook message.

## Strengths

- The document correctly identifies that passive rules alone are a weak enforcement mechanism for long sessions and high-pressure failure paths.
- The repository does contain real hook precedents: `.claude/settings.json` has `UserPromptSubmit` and `PreToolUse:Bash` hooks, and the installed v2 rule files are byte-identical to the canonical `rules/` copies.
- The P0 embedded Python one-liner successfully parses the current Claude Code `PreToolUse` Bash payload shape `tool_input.command` in sample JSON tests.
- The proposed hard block for `chmod +x` aligns with current Claude Code support for `PreToolUse` `exit 2` blocking and with the installed anti-slop rule's script-safety text.
