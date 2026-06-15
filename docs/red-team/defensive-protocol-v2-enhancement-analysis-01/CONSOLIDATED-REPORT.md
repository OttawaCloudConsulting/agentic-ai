# Red-Team Report: Defensive Protocol v2 Enhancement Analysis

## Executive Summary

The document is a competent strategic argument — passive rules under-fire in long sessions and deterministic hooks are the right remedy — but its risk profile is dominated by failures of the document's *own technical correctness*, not by gaps in its reasoning. The three highest-severity findings are all Critical and all concern claims the document presents as settled that do not survive contact with live Claude Code documentation or the repository's own filesystem: (1) the flagship P0 `PreToolUse` hook emits only `additionalContext`, which Claude reads *after* the tool has already run — so the "pre-action prediction pause" cannot fire before a destructive command; (2) the failure-reminder hook targets `PostToolUse`, which fires only on success — failed tools route to `PostToolUseFailure`, so the document's #1-priority behavior (Failure Response) has no working lever as specified; and (3) the native-compaction premise behind the §4.3 session-management reframe is sourced circularly to the project's own prose, with no Claude Code reference anywhere.

Compounding the technical-correctness problem, multiple cited file paths were never opened: `docs/rules/commands/` (the anchor for the §5.5 path-incoherence finding) does not exist, and the proposed default state homes `agents/investigations/` and `agents/memory/` do not exist either — meaning the document's headline "missing-path fix" prescribes writing to a directory tree that is itself missing. The repository-precedent argument is overstated throughout: the installed hooks prove configuration *shape*, not enforcement *effectiveness*, and the agent-delegation precedent (a prompt-keyword match at submission time) is structurally different from the runtime tool-event triggers the defensive trio actually needs. Do not treat the P0/P2 hook proposals as ready-to-ship; the hook events, the matcher patterns, the cited paths, and the compaction premise all require correction and live-doc validation first.

**Overall risk:** Critical
**Total findings:** 19 (Critical: 3, High: 5, Medium: 6, Low: 4)

---

## Critical & High Findings

### Finding 1: P0 `PreToolUse` reminder arrives after the high-risk command has already run

- **Severity:** Critical
- **Lens(es):** Feasibility
- **Observation:** The P0 hook emits only `hookSpecificOutput.additionalContext`, so it cannot force the agent to state DOING / EXPECT / IF MISMATCH *before* execution. Claude reads that context on the next model request — after the tool call has already completed. The document's highest-priority enhancement therefore fails its central behavioral requirement: a destructive command executes first, and the prediction template appears only afterward.
- **Evidence:** Target lines 184–202 describe P0 as a pre-run prediction nudge; line 197 emits only `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"..."}}`. Live Claude Code hooks docs (fetched via `curl -L -s https://code.claude.com/docs/en/hooks.md`, lines ~640–880) state "Claude reads the reminder on the next model request" and list `PreToolUse` additional context as appearing "next to the tool result."
- **Impact:** The flagship safety mechanism does not prevent the action it is designed to gate. It degrades from a pre-action pause to a post-action note, defeating the stated purpose of the §High-Risk prediction tier.
- **Recommendation:** For high-risk commands, return `permissionDecision: "ask"` or `permissionDecision: "deny"` with a clear reason, or use `exit 2` for hard blocks. Reserve `additionalContext` for post-action context only, never for a mandatory pre-action pause.

### Finding 2: Failure-reminder hook targets the wrong event — `PostToolUse` fires only on success; failures route to `PostToolUseFailure`

- **Severity:** Critical
- **Lens(es):** Feasibility (authoritative; verified against live docs), Assumptions
- **Observation:** The proposal repeatedly assigns Bash non-zero failure handling to `PostToolUse`. Current Claude Code separates successful and failed tool completion: `PostToolUse` runs only after a tool executes *successfully*; failed tools trigger a distinct `PostToolUseFailure` event. As specified, the anti-slop Failure Response — the document's stated #1-priority, worst-reliability behavior — has no working lever for the exact failure cases it is meant to handle. The Assumptions lens independently flagged the exit-status visibility as unverified and noted the disclaimer (§7 line 257) sits 135 lines after the recommendation is presented as concrete in §3.1/§6.
- **Evidence:** Target line 77 proposes "`PostToolUse` hook detecting non-zero Bash exit / tool error"; target line 212 ships it as P2. Live docs (`curl -L -s .../hooks.md`, lines ~1520–1660) state "`PostToolUse` hooks fire after a tool has already executed successfully" and "`PostToolUseFailure` runs when a tool execution fails," with sample input including `"error": "Command exited with non-zero status code 1"`. Target line 257 admits only in passing that "the `PostToolUse` exit-status claim is unverified."
- **Impact:** Implementing P2 as written leaves anti-slop failure reminders entirely absent for failed tools. The single enforcement mechanism for the document's top-priority behavior does not exist as specified; a reader scanning §3.1/§6 for the recommendation will not see the §7 caveat.
- **Recommendation:** Replace the P2 event with `PostToolUseFailure`; read the top-level `error`, `tool_name`, and `tool_input` fields; emit `hookSpecificOutput.hookEventName: "PostToolUseFailure"` with `additionalContext` carrying the FAILED / THEORY / PROPOSE reminder. Move the "unverified" caveat inline to §3.1 line 77 and §6 P2 line 212.

### Finding 3: Native-compaction premise behind the §4.3 reframe is sourced circularly to the project's own docs, with no Claude Code reference

- **Severity:** Critical
- **Lens(es):** Assumptions
- **Observation:** §4.3 (lines 134–136) asserts as the premise of an entire recommendation that "Claude Code now performs automatic context summarization/compaction… (noted in the harness's own context-management description)." No such "harness's own context-management description" exists in the repository, and no Claude Code version, changelog, or external doc is cited. The only in-repo mention of compaction is `docs/commands/handoff.md:100` — a command doc the same author wrote. A Belief is leaking into the analysis as settled fact, the exact failure §7 was built to prevent.
- **Evidence:** Document lines 134–136. Cross-file grep for `compaction|summariz|context-management` across `docs/` and `CLAUDE.md` returns only `docs/commands/handoff.md:100` and unrelated benchmark/skill text — no Claude Code reference. Contrast §7 line 257, where the author correctly quarantines other Claude-Code-internals claims as "Belief — needs validation"; this one is stated flatly in §4.3 and used to reframe the session-management rule.
- **Impact:** §4.3's recommendation ("native compaction handles remembering, the rule handles re-confirming intent") rewrites the session-management rule against an unverified behavioral claim about Claude Code internals. If the harness does not compact as assumed, the reframing advice is wrong.
- **Recommendation:** Demote the native-compaction claim to the §7 "Belief — needs validation" list and verify against the actual Claude Code hooks/context reference (claude-code-guide or context7) before acting on any §4.3 reframe. Do not rewrite the session-management rule on this premise until verified.

### Finding 4: The agent-delegation precedent is not transferable; "the mechanism is solved and in production" overstates maturity — the hooks prove shape, not enforcement

- **Severity:** High
- **Lens(es):** Assumptions, Feasibility
- **Observation:** The document's spine (TL;DR line 13, §2 lines 48–65, §6 P0 line 184) asserts the mechanism is "solved and in production here." Two independent problems undermine this. (Assumptions) The agent-delegation hook fires on `UserPromptSubmit` by grepping the *user's prompt text* for keywords — the trigger is present in the prompt before any tool runs. The defensive trio's load-bearing triggers are NOT in the user prompt: a tool *failure*, a destructive command formed mid-session, "every ~10 actions" degradation — all runtime states `UserPromptSubmit` never sees. The document's own P0 sketch silently switches to `PreToolUse:Bash`, conceding the precedent is a different mechanism. (Feasibility) The installed hooks prove only that `.claude/settings.json` contains hook entries of valid JSON shape; they provide no transcript, test harness, or runtime evidence that any hook caused the agent to consult a rule before a risky action.
- **Evidence:** `.claude/rules/agent-delegation.md:213` — hook "injects a one-line reminder when the user's prompt matches bulk-work keywords." Document line 52: "Every claim in that paragraph applies verbatim to the defensive trio" — it does not; the triggers are structurally different. Document lines 60–65: "Both are exactly the shape needed… The mechanism is solved and in production here." The real `.claude/settings.json` contains only a `UserPromptSubmit` plaintext reminder (lines 3–10) and a `PreToolUse:Bash` graphify `additionalContext` reminder (lines 15–22); live docs confirm `additionalContext` is read on the next model request.
- **Impact:** Readers may approve P0 believing it is a copy-paste of a production pattern when it requires new, unvalidated runtime-event hook wiring whose enforcement effectiveness is unproven. The effort estimate is too optimistic.
- **Recommendation:** Stop claiming the mechanism is "solved/in production." State precisely: `UserPromptSubmit`-keyword matching is proven for configuration shape; runtime-event hooks (`PreToolUse` pattern-match, `PostToolUseFailure` exit-status) are a different, unvalidated mechanism. Cite the graphify `PreToolUse:Bash` `additionalContext` injection — not agent-delegation — as the only directly transferable precedent, and add a proof-of-concept harness (controlled settings file; sample `rm -rf`, `chmod u+x`, failing-Bash, and bulk prompts; captured transcripts) before claiming enforcement feasibility.

### Finding 5: Cited command-doc path `docs/rules/commands/` does not exist; the §5.5 path-incoherence finding rests on a fabricated location

- **Severity:** High
- **Lens(es):** Assumptions, Completeness
- **Observation:** §5.5 (line 177) and §4.2 anchor to "`docs/rules/commands/{handoff,catchup,dream,investigate}.md`" as where the command docs hardcode `agents/memory/handoff.md`. That directory does not exist. The command docs actually live at `commands/` (canonical), `docs/commands/` (descriptions), and `.claude/rules/commands/` — and the latter does not even contain `investigate.md`. The underlying coherence mismatch (rules are path-agnostic, command docs are path-hardcoded) is real, but the document points the reader at a nonexistent path to verify it and never acknowledges the three parallel trees — the same multi-copy topology it carefully maps for the rules in §1.
- **Evidence:** `ls docs/rules/commands/` → "No such file or directory." `find . -name handoff.md` → `./commands/handoff.md`, `./docs/commands/handoff.md`, `./.claude/rules/commands/handoff.md` — none under `docs/rules/commands/`. `investigate.md` exists only at `commands/investigate.md` and `docs/commands/investigate.md`. `.claude/rules/commands/` contains catchup, create-prd, dream, handoff, start-feature — no investigate. The CLAUDE.md context block itself shows these files at `.claude/rules/commands/`.
- **Impact:** A consumer or follow-up agent acting on §5.5 will look in `docs/rules/commands/` and find nothing, undermining the documentation-cleanup deliverable and leaving the actual three locations un-reconciled. The "Fix" in §5.5 references a non-existent location.
- **Recommendation:** Correct the path to the real command-doc locations and enumerate all three trees (`commands/`, `docs/commands/`, `.claude/rules/commands/`), mirroring the §1 topology table. Re-verify that those files actually hardcode `agents/memory/handoff.md` (the grep inside the located docs was never completed in the evidence chain).

### Finding 6: §3 enforcement tables omit three named anti-slop behaviors despite claiming exhaustive per-rule coverage

- **Severity:** High
- **Lens(es):** Completeness
- **Observation:** §3 claims to be "Per-rule: intent → in-session effect → enforcement gap → effort" and §0 line 13 asserts "every behavioral lever" is covered. The anti-slop file has 14 H2 sections; three named, substantive sections are entirely absent from the §3.1 table: **Core Principle** ("Reality is the arbiter…"), **Claude-Specific Guidance** ("Your failure mode: optimizing for completion by batching many actions"), and **Summary** ("STOP > THINK > REPORT > WAIT"). Claude-Specific Guidance is the most enforcement-relevant section in the file — it names the completion-batching bias the entire enforcement argument depends on.
- **Evidence:** anti-slop H2 sections: Core Principle (5), Failure Response (13), Confusion Response (32), Evidence Standards (44), Verification Cadence (55), Error Handling (70), Second-Order Effects (78), Autonomy Boundaries (86), Contradiction Handling (111), Pushing Back (121), Stop/Undo/Revert (140), Script Safety (151), Claude-Specific Guidance (166), Summary (181). Artifact §3.1 table (lines 75–85) has no row for Core Principle, Claude-Specific Guidance, or Summary.
- **Impact:** An enumeration presented as exhaustive silently drops three behaviors, one of them the keystone of the enforcement argument. A reader trusting §3 as the complete inventory will miss them.
- **Recommendation:** Add rows for the three omitted sections (Core Principle and Summary flagged as framing-only / non-leverable; Claude-Specific Guidance mapped to the CLAUDE.md pointer), or restate §3's scope as "leverable behaviors only" and list what was deliberately excluded and why.

### Finding 7: P0 `case`-pattern matcher misses common destructive command variants it claims to cover

- **Severity:** High
- **Lens(es):** Feasibility (tested evidence), Completeness
- **Observation:** The P0 shell `case` patterns are an unreliable detector for the proposed high-risk command set. They match narrow case-sensitive substrings and miss real variants of `rm`, force pushes, SQL drops, migrations, and executable-bit changes — and additionally omit several triggers the document itself enumerates as high-risk (`git branch -D` branch deletion, `git commit --amend`, plain `rm -f`). The hook gives a false sense of coverage; agents can run destructive commands semantically inside the trigger set without any reminder or block.
- **Evidence:** Target line 197: `case "$CMD" in *rm\ -rf*|*git*push*--force*|*git*push*-f*|*git*rebase*|*git*reset*--hard*|*DROP\ *|*\ migrate*|*chmod\ +x*)`. Running the exact parse-and-match logic against sample payloads produced: `rm -r -f /tmp/build => no`; `rm -fr /tmp/build => no`; `git push origin +main => no`; `psql -c "drop table users" => no`; `migrate up => no`; `chmod u+x script.sh => no`; `chmod +rx script.sh => no`. The enumerated trigger lists (epistemology lines 44–51 "Deleting … branches"/"amend"; session-management lines 58–62 data deletion, public-API edits — neither Bash-expressible) are not covered; artifact line 92's own trigger set already drops branch deletion and amend.
- **Impact:** The deterministic trigger is presented as the safety net for destructive/irreversible Bash actions but silently misses common irreversible git operations and trivially obfuscated variants. The gap between "what the rule calls high-risk" and "what the matcher catches" is never stated, so the reader over-trusts coverage.
- **Recommendation:** Replace substring globs with a tested classifier: use Claude Code's `if` field for coarse filtering, parse commands with a real parser or strict argv extraction, apply case-insensitive SQL matching, and cover chmod symbolic and numeric executable-bit modes. Alternatively, explicitly list which enumerated high-risk actions the matcher cannot catch and why they remain advisory-only.

### Finding 8: P0 hook handles only Bash; deletions/overwrites via Write, Edit, and MCP tools bypass the entire enforcement layer

- **Severity:** High
- **Lens(es):** Completeness
- **Observation:** The P0 hook uses `"matcher": "Bash"` and pattern-matches shell command strings. The epistemology high-risk triggers (file deletion, "Overwriting files with uncommitted changes") and the Chesterton's-Fence file-deletion reminder (line 95) are unreachable when the agent deletes or overwrites via the native `Write` tool (overwrites a file), `Edit` tool, or MCP filesystem tools. Overwriting an uncommitted file via the Write tool is arguably the single irreversible action most likely in an agentic coding session, and it bypasses the entire proposed enforcement layer.
- **Evidence:** Artifact line 195: `"matcher": "Bash"`. Epistemology trigger list (lines 44–51) includes "Deleting files…" and "Overwriting files with uncommitted changes." Artifact line 92 lists "overwrite-with-uncommitted" as a mapped trigger and line 95 proposes a reminder "on file *deletion*," yet the only sketched hook cannot see non-Bash mutations. The §7 open questions (lines 259–262) never raise the non-Bash gap.
- **Impact:** A core class of high-risk action bypasses the consolidation that line 186 claims merges "epistemology §High-Risk + session-management §Irreversible Actions + anti-slop §Failure Response into one deterministic trigger." The consolidation silently covers only the Bash-expressible subset while being presented as full coverage.
- **Recommendation:** Add `PreToolUse` matchers for `Write` and `Edit` (and note MCP filesystem tools) covering overwrite/delete, or explicitly scope P0 as "Bash-issued destructive commands only" and file the native-tool deletion/overwrite case as a separate flagged follow-up rather than leaving it implied-covered.

---

## Medium & Low Findings

### Finding 9: Proposed default state homes `agents/investigations/` and `agents/memory/` do not exist — the missing-path "fix" recreates the missing-path problem

- **Severity:** Critical
- **Lens(es):** Completeness

> Placement note: rated Critical by the Completeness lens and retained at that rating (no lens contradicts it); it counts toward the Critical total above. Grouped here in the Medium/Low section only for proximity to the related path-citation findings (5, 7, 8).

- **Observation:** The document's central documentation deliverable (§4.2 lines 126–130, §6.2 lines 238–241) prescribes concrete file homes — `agents/investigations/<topic>.md` and `agents/memory/{checkpoint,handoff}.md` — and calls these the resolution of "the missing-path problem," asserting they "align with the existing command docs." None of `agents/`, `agents/memory/`, or `agents/investigations/` exists anywhere in the repository. (Distinct from Finding 5, which concerns the *cited* command-doc path; this concerns the *prescribed default* state paths.)
- **Evidence:** Disk check: `agents/ ABSENT`, `agents/memory ABSENT`, `agents/investigations ABSENT`. Artifact line 128: "Investigations → `agents/investigations/<topic>.md`"; line 129: "Checkpoints / handoff → `agents/memory/{checkpoint,handoff}.md`"; line 240: same paths in the drop-in CLAUDE.md block; line 132 claims this gives "*this* project concrete homes."
- **Impact:** The CLAUDE.md block, pasted verbatim, tells the agent to write to a directory tree that does not exist. The agent will either fail the write (no recovery path specified) or silently create an ad-hoc tree — the exact "writes nowhere / inconsistently" failure §4.2 claims to fix.
- **Recommendation:** State that the installer or adoption step must `mkdir -p agents/investigations agents/memory`, or change the defaults to the one directory that exists (`scratch/`). Verify the target tree exists before asserting the paths "align with existing command docs."

### Finding 10: "The model cannot reliably count its own tool calls" is asserted as fact with no evidence

- **Severity:** Medium
- **Lens(es):** Assumptions
- **Observation:** The action-counter argument (TL;DR point 2 line 18, §4.1 line 114) is stated categorically and in bold as settled: "The model has no reliable running count of its own tool calls across a long session. It will approximate, drift, and under pressure simply not track it." No measurement, test, or citation supports this behavioral claim, yet it justifies reframing two rules (P1, line 208).
- **Evidence:** Document lines 18 and 114, stated as settled with no experiment, transcript, or reference. The targeted rule text is real (`session-management.md:22` "Every ~10 actions"; `anti-slop.md:57–58` "3 actions / 5 actions"), but the claim that the model *cannot* honor counts is itself untested.
- **Impact:** If the claim is overstated (the model may track approximate counts well enough for a soft "~10 actions" heuristic), the P1 reframe from counts to events solves a non-problem and deletes a working cadence ("a false promise," line 208).
- **Recommendation:** Label this a Belief, not a fact, at line 114. Either cite a transcript showing count drift or soften to "counts are unreliable enough that event triggers are more robust" rather than the absolute claim.

### Finding 11: Reliability ratings (Low/Med/High) are unmeasured estimates used as data to derive the P0–P3 prioritization

- **Severity:** Medium
- **Lens(es):** Assumptions
- **Observation:** §3.1–§3.3 assign every behavior a "Reliability without a hook" rating. The legend (line 71) honestly calls these "my estimate," but the body then converts them into superlative ROI rankings ("Highest-ROI enhancement in the document," line 92; "Highest-precision, lowest-effort hardening in the whole trio," line 85), and the §6 P0–P3 ordering inherits the unmeasured estimates.
- **Evidence:** Line 71 admits estimation; lines 85, 92 attach superlatives; no session data, A/B comparison, or instrumentation backs any rating.
- **Impact:** The prioritization reads as evidence-based but is one person's intuition formatted as a table. If, e.g., Failure Response is followed more often than rated, the P0/P2 ordering misallocates effort.
- **Recommendation:** Keep the reasoned estimates but drop the superlatives; frame §6 priorities as "based on unmeasured estimates" and identify what observation would confirm the ordering.

### Finding 12: No recovery treatment for runtime prerequisite failure — missing python3/jq degrades enforcement to a silent no-op

- **Severity:** Medium
- **Lens(es):** Assumptions, Completeness
- **Observation:** The existing hooks and the proposed P0 hook depend on `jq` (UserPromptSubmit) and `python3` (PreToolUse), with the P0 command piping stdin through `python3 -c … 2>/dev/null||true`. On a machine lacking python3 (or jq), `$CMD` is empty, every `case` arm fails to match, and the high-risk reminder never fires — a silent no-op of the entire safety layer, directly violating the anti-slop "silent fallbacks convert hard failures into silent corruption / let it crash" principle the document is built to defend. The repo also mixes parsers (UserPromptSubmit uses `jq`, the P0 sketch and graphify use `python3`), and no section states these prerequisites or a failure path. (Distinct from Finding 13, which concerns installer idempotency, not interpreter availability.)
- **Evidence:** Artifact line 197: `python3 -c "…" 2>/dev/null||true`. `.claude/settings.json:9` UserPromptSubmit uses `jq -r '.prompt'`; line 21 graphify uses `python3`. The graphify hook already `|| true`s on python3 failure. No section of the artifact mentions a python3/jq absence path, hook-misfire path, or codex absence; §7 (lines 250–262) lists only the JSON-contract uncertainty.
- **Impact:** On any consumer machine without python3/jq, the enforcement layer degrades to nothing with no signal — the worst outcome under the document's own doctrine, and harder to detect because it looks installed. The gap propagates to every consumer via the installer (P2), which is never specified to check prerequisites.
- **Recommendation:** State runtime prerequisites explicitly (python3 or jq; POSIX shell; writable `.claude/settings.json`). Pick one JSON parser for repo consistency. Replace `|| true` with a fail-loud check, and add an install-time prerequisite check that decides whether a missing interpreter hard-fails install or falls back to a pure-shell matcher. State the chosen default.

### Finding 13: Installer idempotency is under-specified — marker discipline and a second CLAUDE.md idempotency problem are unaddressed

- **Severity:** Medium
- **Lens(es):** Feasibility
- **Observation:** The proposal treats a defensive installer as straightforward shell work, but the existing working pattern depends on `jq`, marker-based duplicate detection, valid-JSON checks, temp-file writes, and marker versioning. Appending a CLAUDE.md block adds a *second* idempotency problem the proposal never addresses.
- **Evidence:** Target line 144 recommends an installer that "copies the trio" and "merges the `PreToolUse` high-risk hook" using the "same idempotent pattern"; line 214 repeats "copy trio + merge hooks + append CLAUDE.md block, idempotent." The existing installer declares "Dependencies: jq" (`scripts/agent-delegation/install.sh:19`), rejects invalid settings JSON (lines 66–74), checks a hook marker (lines 91–95), and merges with `jq` (lines 101–112).
- **Impact:** A re-run duplicates hooks or CLAUDE.md content unless every inserted artifact copies the same marker and merge discipline. Command changes without a marker bump leave stale hooks; marker changes without migration create duplicate behavior.
- **Recommendation:** Specify the installer contract before implementation: required `jq`, stable hook markers, version-bump behavior, invalid-JSON handling, atomic temp-file writes, CLAUDE.md block sentinels, and an idempotency test that runs the installer twice and diffs the result.

### Finding 14: Action-counter hook understates state and concurrency work

- **Severity:** Medium
- **Lens(es):** Feasibility
- **Observation:** A `PreToolUse` star-matcher incrementing a temp-file counter is not a moderate reuse of the graphify pattern. It needs per-session identity, locking, reset semantics, cleanup, and batch behavior — none of which the proposal provides. A naive counter loses increments under concurrent hook runs and accumulates stale state across sessions.
- **Evidence:** Target line 118: "A `PreToolUse` (matcher `*`) hook can maintain a counter in a temp file." Live docs (`curl … hooks.md | grep -n "concurrent\|parallel\|spawns\|every tool call"`) state hooks run "on every tool call inside the agentic loop," "All matching hooks run in parallel," and "`PostToolUse` fires once per tool, which means it fires concurrently when Claude makes parallel tool calls. `PostToolBatch` fires exactly once with the full batch."
- **Impact:** The counter loses increments under parallel tool batches and has no reliable reset on a semantic "verification" unless verification is separately defined and detected.
- **Recommendation:** Prefer the document's own option (b): replace count-based rules with event triggers. If a counter is still required, implement it as a real hook script with `session_id`-keyed storage, atomic locking, explicit reset triggers, TTL cleanup, and tests covering parallel batches.

### Finding 15: The load-bearing open question (wire hooks vs. advisory-only) is left without a recommended default

- **Severity:** Medium
- **Lens(es):** Completeness
- **Observation:** Of the three §7 open questions, question 2 — whether to wire enforcement hooks at all — is the go/no-go decision for the entire P0/P2 proposal set, and the document declines to recommend a default, merely restating the tradeoff. (Question 1 does carry a recommendation; question 3 is procedural.)
- **Evidence:** Artifact line 261: "Do you want enforcement hooks wired (P0), or keep the rules advisory-only…? Hooks change behavior deterministically but add `.claude/settings.json` surface to maintain." No recommendation follows, unlike question 1's "The commit message implies retired."
- **Impact:** The document's entire prioritized-enhancement spine is gated on a question the analysis refuses to take a position on; the reader cannot act on §6 without first resolving a punted decision.
- **Recommendation:** State a recommended default. The document's own §2 evidence — that this repo already proved passive rules under-fire — points to "wire the P0 reminder hook" as the defensible default; label it as such.

### Finding 16: §2 hook description is quantitatively wrong (~12 lines vs. actual 6; parser mismatch)

- **Severity:** Low
- **Lens(es):** Assumptions
- **Observation:** §2 line 62 describes the UserPromptSubmit hook as "`printf`s a one-line reminder. ~12 lines of shell." The actual hook command is 6 lines and parses with `jq -r '.prompt'`, while the document's P0 sketch assumes python3 JSON parsing — the "~12 lines" is roughly double the real count.
- **Evidence:** Parsed `.claude/settings.json`: UserPromptSubmit command is 6 lines, uses `jq` (True), `printf` (True), python3 (False). Document line 62 says "~12 lines."
- **Impact:** Minor on its own, but it shows the "verified from `.claude/settings.json`" claim (line 60) was described from memory, not inspection — compounding Finding 4.
- **Recommendation:** Correct "~12 lines" to 6 and note the existing hook uses `jq` while the proposed P0 hook uses `python3` (reconcile to one).

### Finding 17: "Two of these are already wired" miscounts the listed injection points; "three" contradicts a five-item list

- **Severity:** Low
- **Lens(es):** Assumptions
- **Observation:** §2 line 58 says "Claude Code gives three deterministic injection points… `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, plus `Stop`/`SessionStart`" — stating "three" then listing five — and the "currently doesn't [use]" qualifier is false for the two that the very next clause says ARE wired.
- **Evidence:** Document line 58 as quoted; `.claude/settings.json` wires exactly UserPromptSubmit and PreToolUse.
- **Impact:** Internal contradiction in the count and the qualifier; low impact on conclusions but signals the §2 enumeration was not checked.
- **Recommendation:** State precisely which events Claude Code exposes (verify the full list against the hooks reference) and that this repo currently wires two of them (UserPromptSubmit, PreToolUse).

### Finding 18: §6.2 CLAUDE.md block claims to bind all rule behaviors but covers only a curated hard-behavior subset

- **Severity:** Low
- **Lens(es):** Completeness
- **Observation:** Line 244 states the §6.2 block resolves "when the soft rules bind," and §3.1 line 83 routes Autonomy/Contradiction/Pushing-Back mitigation explicitly to "the CLAUDE.md pointer (§6.2)." The block (lines 220–242) contains no autonomy/contradiction/pushing-back/Chesterton's-Fence/RCA/investigation-discipline content — an unmet internal cross-reference.
- **Evidence:** Artifact line 83 ("Mitigate via the CLAUDE.md pointer (§6.2)") vs. the §6.2 block (lines 226–236), which lists only Failure Response, Script Safety, verify-on-event, high-risk prediction, INTENT one-liner, degradation checkpoint, handoff-before-clear, and the three path defaults.
- **Impact:** A consumer adopting the block believes the soft personality rules are reinforced when they are not; the "raises rule salience" claim (line 206) holds only for the three hard behaviors actually listed.
- **Recommendation:** Either add the promised soft-rule reminders to the §6.2 block or remove the line-83 promise and narrow line 244's "soft rules bind" claim to the behaviors actually covered.

### Finding 19: Documentation analysis content-checks only one of three docs/rules description files for drift

- **Severity:** Low
- **Lens(es):** Completeness
- **Observation:** §5 verifies only `docs/rules/defensive-protocol-v2-anti-slop.md` (the shebang contradiction) against its canonical source. It never checks whether the epistemology and session-management description files drifted, though §1 notes byte-size divergence for anti-slop and asserts the docs files are "prose summaries."
- **Evidence:** Artifact §5.4 (lines 169–174) checks only `…anti-slop.md:88`. No finding examines `docs/rules/defensive-protocol-v2-epistemology.md` (4157 bytes) or `…-session-management.md` (3620 bytes) for content accuracy; both are present and unexamined.
- **Impact:** The documentation analysis is complete for one of three description files; the same class of drift in the other two would go undetected. "Analysis of accompanying documentation" is partially delivered.
- **Recommendation:** Extend §5 to verify the epistemology and session-management descriptions against their canonical sources, or state explicitly that only anti-slop was content-checked and the other two were assumed faithful.

**Filtered findings:** 0 omitted. Every finding across all three lenses carries specific, reproducible evidence (file paths, line numbers, grep/parse output, or live-doc quotes); none rested on purely speculative evidence or merely restated a recommendation, so none met the filtering bar. Per the "when in doubt, keep" rule, all 24 source findings were retained and consolidated to 19 via dedup.

---

## Cross-Cutting Themes

**Theme A — Claims about Claude Code internals asserted as settled without validation against live docs.** *(Lenses: Assumptions, Feasibility.)* The document's three most damaging errors all share this shape: the native-compaction premise (Finding 3) is sourced to the project's own prose; the `PreToolUse` timing claim (Finding 1) and the `PostToolUse` failure-event assignment (Finding 2) both contradict the current hooks reference. Feasibility caught the latter two only by fetching live docs; the Assumptions lens flagged the pattern but, by its own admission, the document failed to apply its §7 "Belief — needs validation" quarantine consistently. Any hook recommendation in this document must be re-validated against `code.claude.com/docs/en/hooks.md` before implementation.

**Theme B — Cited file paths asserted as observed but never opened.** *(Lenses: Assumptions, Completeness.)* `docs/rules/commands/` (Finding 5) and `agents/investigations/`, `agents/memory/` (Finding 9) are all referenced as if real — the first as the anchor of a "verified" coherence finding, the second two as the prescribed fix for the missing-path problem. None exists on disk. The document does rigorous multi-copy topology work for the rule files in §1 but applies none of that rigor to the command-doc trees or to its own proposed state homes.

**Theme C — The gap between what the rules call high-risk and what a Bash-only matcher can catch.** *(Lenses: Completeness, Feasibility.)* Findings 7 and 8 are two faces of the same systemic over-claim: the P0 hook is presented as consolidating the full irreversible/high-risk trigger set, but the `case` patterns miss trivially obfuscated and enumerated Bash variants (Finding 7) *and* the `Bash` matcher cannot see native `Write`/`Edit`/MCP mutations at all (Finding 8). The non-pattern-matchable triggers the rules name (uncertainty, "be careful," public-API edits) can never be caught by this mechanism, and the document never states the coverage boundary.

**Theme D — Repository precedent overstated as proof of enforcement.** *(Lenses: Assumptions, Feasibility.)* Finding 4 (precedent transferability and "mechanism solved") and Finding 12's silent-no-op risk both stem from treating "valid hook JSON exists in this repo" as evidence that "hooks reliably enforce the defensive trio." Configuration shape was verified; enforcement effectiveness was never demonstrated, and on a prerequisite-poor machine the enforcement is not merely unproven but actively silent.

---

## Strengths

- **The §7 Verified/Belief split is real discipline where it was applied.** It correctly quarantines the `PreToolUse`/`PostToolUse` JSON-contract and exit-status claims as "Belief — needs validation (do NOT treat as fact)" and names the validation path (claude-code-guide / context7). The structurally verifiable claims it labels "Verified" — file topology, `rules/ == .claude/rules/` byte-identity, the v1 deletion in `9e0a6e6` (−298 lines), the shebang contradiction (`.claude/rules/…anti-slop.md:160` "Shebangs may be included" vs `docs/rules/…anti-slop.md:88` "Do not add shebangs"), the two hook precedents — all checked out against the repo. *(Assumptions, Completeness, Feasibility.)*
- **The §1 source-of-truth topology table is a genuinely complete, independently verified enumeration** of the rule representations (all three live copies plus the deleted v1, with load-status) — the one place the document does multi-copy completeness work thoroughly. *(Completeness.)*
- **The core strategic thesis is correct:** passive rules alone are a weak enforcement mechanism for long sessions and high-pressure failure paths, and deterministic hooks are the right class of remedy. *(Feasibility.)*
- **Real, correctly identified precedents exist:** `.claude/settings.json` does contain working `UserPromptSubmit` and `PreToolUse:Bash` hooks, and the P0 embedded Python one-liner successfully parses the current `PreToolUse` Bash payload shape `tool_input.command` in sample tests; the proposed `chmod +x` hard block aligns with current `PreToolUse` `exit 2` blocking support. *(Feasibility.)*

---

## Per-Agent Findings

| Lens | Findings File |
|------|---------------|
| Assumptions | [assumptions-findings.md](./assumptions-findings.md) |
| Completeness | [completeness-findings.md](./completeness-findings.md) |
| Feasibility | [feasibility-findings.md](./feasibility-findings.md) |

---

## Methodology

| Field | Value |
|-------|-------|
| Artifact | scratch/defensive-protocol-v2-enhancement-analysis.md |
| Artifact type | Analysis / Proposal document |
| Date | 2026-06-15 |
| Agents | Assumptions (Opus), Completeness (Opus), Feasibility (Codex / gpt-5.5 via `codex exec`) |
| Agent compliance | Assumptions: Pass (bundled persona); Completeness: Pass (bundled persona); Feasibility: Pass (Codex agent, inline persona) |
| Chunked | No |
| Debate | No |
| Findings produced (pre-dedup) | 24 (Assumptions 9, Completeness 9, Feasibility 6) |
| Findings after dedup | 19 (Critical: 3, High: 5, Medium: 6, Low: 4) |
| Findings filtered | 0 |

### Dedup ledger (5 merges; 24 → 19)

| Consolidated | Merged from | Element / shared problem | Resulting severity |
|---|---|---|---|
| Finding 2 | Assumptions F3 + Feasibility F2 | `PostToolUse` failure hook (line 77/212) targets wrong event | Critical (Feasibility authoritative — verified vs live docs; `PostToolUseFailure` exists) |
| Finding 4 | Assumptions F2 + Feasibility F6 | "mechanism solved/in production" (line 65) — precedent proves shape not enforcement | High |
| Finding 5 | Assumptions F4 + Completeness F2 | `docs/rules/commands/` path (line 177) does not exist | High |
| Finding 7 | Completeness F7 + Feasibility F3 | P0 `case` matcher (line 197) misses destructive variants | High (Feasibility carries tested output) |
| Finding 12 | Assumptions F7 + Completeness F5 | missing python3/jq → silent no-op of enforcement | Medium |

Kept separate (not duplicates): Completeness F1 (Finding 9 — prescribed `agents/` state paths absent) is distinct from the cited-command-path findings; Feasibility F5 (Finding 13 — installer idempotency/markers) is distinct from the interpreter-availability problem in Finding 12; Completeness F4 (Finding 8 — Bash-only matcher misses native-tool mutations) is a distinct coverage gap from the pattern-coverage gap in Finding 7.
