# Assumptions Assessment

## Agent Persona

I am the Assumptions reviewer. My role is to separate verified facts from unverified claims, expose unstated dependencies, and flag wishful happy-path reasoning in the enhancement analysis. My adversarial posture: every claim presented as fact is an assumption until it cites tested evidence, and every analogy ("agent-delegation already proved this") is load-bearing until shown to be transferable.

## Assessment Summary

Items examined: 41 (the full target document's claims, plus 9 cross-file verifications: `.claude/settings.json`, `docs/RULES.md` lines 9/43, `rules/` vs `.claude/rules/` diffs of all three files, `git show 9e0a6e6`, `docs/rules/defensive-protocol-v2-anti-slop.md:88`, `.claude/rules/...anti-slop.md:160`, session-management line 22, command-doc path locations, kiro references, installer-script presence)
Findings: 9 (Critical: 1, High: 3, Medium: 3, Low: 2)

## Findings

### Finding 1: Native compaction claim is sourced circularly to the project's own docs, not to any Claude Code source

- **Severity:** Critical
- **Category:** Circular Reasoning
- **Observation:** §4.3 (lines 134–136) asserts as the premise of an entire recommendation: "Claude Code now performs **automatic context summarization/compaction** when context grows long (noted in the harness's own context-management description)." There is no "harness's own context-management description" anywhere in the repository, and the document cites no Claude Code version, changelog, or external doc. The only in-repo mention of compaction is `docs/commands/handoff.md:100` ("preserve state before auto-compaction") — a command doc the same author authored. The claim that the harness summarizes context is therefore justified by pointing at the project's own prose, which is itself unverified.
- **Evidence:** Document lines 134–136. Cross-file grep for `compaction|summariz|context-management` across `docs/` and `CLAUDE.md` returns only `docs/commands/handoff.md:100` (author's own doc) and unrelated benchmark/skill text. No Claude Code reference exists. Contrast with §7 line 257, where the author correctly quarantines other Claude-Code-internals claims as "Belief — needs validation" — but this native-compaction claim is stated flatly in §4.3 as settled and used to reframe the session-management rule.
- **Impact:** §4.3's recommendation ("reframe to complement native compaction; native compaction handles remembering, the rule handles re-confirming intent") is built on an unverified behavioral claim about Claude Code internals. If the harness does not perform the compaction the document assumes — or does it differently — the reframing advice is wrong and the session-management rule gets rewritten against a fiction. This is a Belief leaking into the analysis as if settled, exactly the failure §7 was supposed to prevent.
- **Recommendation:** Demote the native-compaction claim to the §7 "Belief — needs validation" list alongside the other Claude Code internals claims. Verify against the actual Claude Code hooks/context reference (via `claude-code-guide` or context7) before any §4.3 reframing is acted on. Do not rewrite the session-management rule on this premise until verified.

### Finding 2: The agent-delegation precedent is not transferable to the defensive trio's trigger semantics, yet the document treats it as a solved template throughout

- **Severity:** High
- **Category:** Inherited Assumption
- **Observation:** The document's spine (TL;DR line 13, §2 lines 48–65, §6 P0 line 184) repeatedly asserts the mechanism is "solved and in production here" because agent-delegation shipped a working hook. But agent-delegation's hook fires on `UserPromptSubmit` by grepping the **user's prompt text** for keywords (`audit`, `enumerate`, etc.) — the trigger is present in the prompt, before any tool runs. The defensive trio's load-bearing triggers are NOT in the user prompt: a tool *failure* (anti-slop Failure Response), a destructive command formed mid-session (epistemology high-risk tier), and "every ~10 actions" degradation. These occur during agent execution, not at prompt submission. The document inherits "hooks solve passive-rule consultation" from one trigger class (prompt-keyword match) and applies it to a structurally different class (runtime tool events) without proving the transfer.
- **Evidence:** `.claude/rules/agent-delegation.md:213` — the hook "injects a one-line reminder when the user's prompt matches bulk-work keywords." `.claude/settings.json:9` — the UserPromptSubmit hook parses `.prompt` and greps it. Document line 52: "Every claim in that paragraph applies verbatim to the defensive trio." It does not apply verbatim: the agent-delegation trigger is a string in the user's prompt; the defensive triggers are runtime states (exit codes, command patterns at PreToolUse) that UserPromptSubmit never sees. The document's own P0 sketch (lines 191–199) silently switches to `PreToolUse:Bash` — a different hook event than the precedent it invokes — which concedes the precedent is not the same mechanism.
- **Impact:** "The mechanism is solved" (line 65) overstates the maturity of the proposal. The PreToolUse/PostToolUse hooks the trio actually needs are unproven for this purpose (the document admits as much for PostToolUse in §7). Readers may approve P0 believing it is a copy-paste of a production pattern when it requires new, unvalidated hook wiring.
- **Recommendation:** Stop claiming the mechanism is "solved/in production." State precisely: UserPromptSubmit-keyword matching is proven; runtime-event hooks (PreToolUse pattern-match, PostToolUse exit-status) are a *different* mechanism requiring separate validation. The only directly transferable precedent is the graphify `PreToolUse:Bash` `additionalContext` injection — cite that, not agent-delegation, as the P0 precedent.

### Finding 3: PostToolUse failure-detection hook (anti-slop's highest-value lever) assumes exit-status visibility the document never verified

- **Severity:** High
- **Category:** Unverified Claim
- **Observation:** The anti-slop Failure Response is the document's stated worst-reliability/highest-stakes behavior (§3.1 line 77, "Low–Med"). Its proposed enforcement (§3.1 line 77, §6 P2 line 212) is "a `PostToolUse` hook detecting non-zero Bash exit / tool error." The document does not verify that PostToolUse can observe a tool's exit status in the current Claude Code version — it flags this only in passing at §7 line 257 ("the `PostToolUse` exit-status claim is unverified") while still presenting the hook as a concrete recommendation in §3.1 and §6.
- **Evidence:** Document line 77 presents the PostToolUse lever inside the per-rule enforcement table as the answer for Failure Response. Line 212 ships it as P2. Line 257 then admits "the `PostToolUse` exit-status claim is unverified." The recommendation precedes the disclaimer by 135 lines and is not cross-referenced where stated.
- **Impact:** If PostToolUse cannot see exit status (plausible — hooks often receive tool input, not captured stdout/exit codes), the single enforcement mechanism for the document's #1 priority behavior does not exist, and P2 is unbuildable as specified. A reader scanning §3.1/§6 for the recommendation will not see the §7 caveat.
- **Recommendation:** Move the "unverified — PostToolUse may not expose exit status" caveat inline to §3.1 line 77 and §6 P2 line 212, not just §7. Verify before any implementation. If PostToolUse cannot see failures, the Failure Response has no hook lever and that must be stated as a known gap, not a planned fix.

### Finding 4: The document cites command docs at a path that does not exist

- **Severity:** High
- **Category:** Unverified Claim
- **Observation:** §5.5 (line 177) states: "`docs/rules/commands/{handoff,catchup,dream,investigate}.md` hardcode `agents/memory/handoff.md`...". The directory `docs/rules/commands/` does not exist. The command docs live at `commands/`, `docs/commands/`, and `.claude/rules/commands/`. The "verified" §5.5 coherence-mismatch finding rests on a file path the author did not actually read.
- **Evidence:** `ls docs/rules/commands/` → "No such file or directory". `find . -name handoff.md` → `./commands/handoff.md`, `./docs/commands/handoff.md`, `./.claude/rules/commands/handoff.md` — none under `docs/rules/commands/`. The CLAUDE.md context block itself shows these files at `.claude/rules/commands/`, confirming the correct location. The document's §5.5 path is fabricated.
- **Impact:** §5.5 is presented under the §5 "Documentation findings" heading and its sub-claims are framed as observed. A path-level error in a coherence-mismatch finding undermines the finding's credibility and means the "Fix" in §5.5 references a non-existent location. Anyone acting on §5.5 will fail to find the cited files.
- **Recommendation:** Correct the path to the real command-doc locations (`commands/`, `docs/commands/`, `.claude/rules/commands/`) and re-verify that those files actually hardcode the paths claimed (the grep for `agents/memory/handoff.md` inside the located handoff docs was not completed in the document's evidence chain).

### Finding 5: "The model cannot reliably count its own tool calls" is asserted as fact with no evidence

- **Severity:** Medium
- **Category:** Unverified Claim
- **Observation:** The action-counter argument (TL;DR point 2 line 18, §4.1 line 114) is stated categorically: "**The model has no reliable running count of its own tool calls across a long session.** It will approximate, drift, and under pressure simply not track it." No measurement, test, or citation supports this behavioral claim about the model. It is plausible, but it is presented as an established fact and is the justification for reframing two rules (P1, line 208).
- **Evidence:** Document line 114, stated in bold as settled. Line 18 repeats it ("It cannot do this reliably"). No experiment, transcript, or reference is offered. The rule text it targets is real (`.claude/rules/...session-management.md:22` "Every ~10 actions"; `...anti-slop.md:57–58` "3 actions / 5 actions"), but the claim that the model *cannot* honor counts is itself untested.
- **Impact:** If the claim is overstated (the model may track approximate counts adequately for a soft "~10 actions" heuristic), then the P1 reframe from counts to events is solving a non-problem and removes a working cadence. The recommendation to delete "every N actions" as "a false promise" (line 208) is only correct if the premise is true.
- **Recommendation:** Label this a Belief, not a fact, in line 114. Either cite evidence (a transcript showing count drift) or soften to "counts are unreliable enough that event triggers are more robust" — a defensible claim — rather than the absolute "the model has no reliable count."

### Finding 6: Reliability ratings ("Low", "Med", "High") across all three per-rule tables are unmeasured estimates presented in a data-shaped format

- **Severity:** Medium
- **Category:** Scale Assumption
- **Observation:** §3.1–§3.3 assign every behavior a "Reliability without a hook" rating (Low/Med/High). The legend (line 71) honestly calls these "my estimate," but the body then uses them as if they were measurements to rank enhancements ("Highest-ROI enhancement in the document," line 92; "Highest-precision, lowest-effort hardening in the whole trio," line 85). The prioritization in §6 (P0/P1/P2/P3) is derived from these unmeasured ratings.
- **Evidence:** Line 71 legend admits estimation. Lines 85, 92 convert estimates into superlative ROI rankings. No session data, A/B comparison, or instrumentation backs any rating. The entire P0–P3 ordering inherits the unmeasured estimates.
- **Impact:** The prioritization reads as evidence-based but is one person's intuition formatted as a table. If, say, the Failure Response is actually followed more often than rated "Low–Med," the P0/P2 ordering is misallocated effort. Tables imply data; these are opinions.
- **Recommendation:** Keep the estimates (they are reasoned) but stop attaching superlatives ("highest-ROI," "highest-precision in the whole trio") to unmeasured ratings. Frame §6 priorities as "based on unmeasured estimates" and identify what would have to be observed to confirm the ordering.

### Finding 7: Installed install scripts and hook tooling are assumed buildable on prerequisites never stated

- **Severity:** Medium
- **Category:** Unstated Dependency
- **Observation:** The P0 hook sketch (lines 191–199) and §4.5/§6 P2 installer (lines 144, 214) depend on tooling that is never enumerated as a prerequisite: `python3` (the P0 sketch parses JSON with `python3 -c`), a POSIX `case`/shell, and an idempotent JSON-merge step for `.claude/settings.json` (the agent-delegation installer used to merge the hook — that merge logic, and whether it needs `jq`, is assumed to be portable). The existing UserPromptSubmit hook in this repo uses `jq`, while the P0 sketch uses `python3` — two different runtime dependencies, neither declared as required.
- **Evidence:** Document P0 sketch line 197 uses `python3 -c`. `.claude/settings.json:9` (UserPromptSubmit) uses `jq -r`. `.claude/settings.json:21` (graphify) uses `python3`. The document never states that a consumer repo must have python3 AND/OR jq installed for these hooks to fire. The graphify hook silently `|| true`s on python3 failure — meaning on a box without python3 the defensive hook would no-op silently, defeating the enforcement the whole document argues for.
- **Impact:** On a consumer machine lacking python3 (or jq), the proposed hooks degrade to silent no-ops — the exact "passive, doesn't fire" failure the document set out to fix, now harder to detect because it looks installed. The installer's idempotent JSON-merge is asserted ("same idempotent pattern") but the merge implementation's own dependencies are unexamined.
- **Recommendation:** State the runtime prerequisites (python3 or jq; POSIX shell; writable `.claude/settings.json`) explicitly for any hook recommendation. Pick one JSON parser for consistency with the repo. Add a fail-loud check rather than `|| true` so a missing interpreter surfaces instead of silently disabling enforcement.

### Finding 8: Quantitative descriptions of the existing hook are wrong, weakening the "precedent" argument's precision

- **Severity:** Low
- **Category:** Unverified Claim
- **Observation:** §2 (line 62) describes the UserPromptSubmit hook as "`printf`s a one-line reminder. ~12 lines of shell." The actual hook command is 6 lines, and it parses the prompt with `jq -r '.prompt'` (the document's mental model elsewhere, e.g. the P0 sketch, assumes python3 JSON parsing). The "~12 lines" is roughly double the real count.
- **Evidence:** Parsed `.claude/settings.json`: UserPromptSubmit hook command is 6 lines (`c.count('\n')+1 == 6`), uses `jq` (True), uses `printf` (True), uses python3 (False). Document line 62 says "~12 lines."
- **Impact:** Minor on its own, but it shows the "verified from `.claude/settings.json`" claim (line 60) was not measured precisely. Compounds Finding 2: the precedent the argument leans on was described from memory, not inspection.
- **Recommendation:** Correct "~12 lines" to 6, and note the existing hook uses `jq` while the proposed P0 hook uses `python3` (reconcile to one).

### Finding 9: "Two of these are already wired" miscounts the listed injection points

- **Severity:** Low
- **Category:** Unverified Claim
- **Observation:** §2 line 58 lists injection points as "`UserPromptSubmit`, `PreToolUse`, `PostToolUse`, plus `Stop`/`SessionStart`" then says "Two of these are *already wired in this repo*." The repo wires `UserPromptSubmit` and `PreToolUse` — two events — but the sentence lists four-to-five candidate events including `PostToolUse`, `Stop`, `SessionStart` that are NOT wired, and the phrasing "three deterministic injection points" immediately before contradicts the five-item list that follows in the same sentence.
- **Evidence:** Document line 58: "Claude Code gives three deterministic injection points the trio could use and currently doesn't: `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, plus `Stop`/`SessionStart`." This says "three" then lists five. `.claude/settings.json` wires exactly UserPromptSubmit and PreToolUse. The "three injection points... and currently doesn't [use]" is also false for UserPromptSubmit and PreToolUse, which the very next clause says ARE wired.
- **Impact:** Internal contradiction in the count and the "currently doesn't use" qualifier. Low impact on conclusions but signals the §2 enumeration was not checked.
- **Recommendation:** State the count precisely: Claude Code exposes UserPromptSubmit, PreToolUse, PostToolUse, Stop, SessionStart (verify the full list against the hooks reference); this repo currently wires two of them (UserPromptSubmit, PreToolUse).

## Strengths

- The §7 "Verification status & open questions" split is a genuine strength from the assumptions lens: it correctly quarantines the PreToolUse/PostToolUse JSON-contract and exit-status claims as "Belief — needs validation before implementing hooks (do NOT treat as fact)" (lines 256–257) and explicitly names the validation path (claude-code-guide / context7). The structurally verifiable claims it labels "Verified" — file topology, `rules/ == .claude/rules/` byte-identity, the v1 deletion in `9e0a6e6` (−298 lines), the shebang contradiction, and the two hook precedents — all checked out against the repo (diffs identical; commit confirmed; `.claude/rules/...anti-slop.md:160` "Shebangs may be included" vs `docs/rules/...anti-slop.md:88` "Do not add shebangs" is a real direct contradiction; `docs/RULES.md:9` and `:43` cite a deleted file). The discipline fails only where it should have applied the same quarantine and didn't (Findings 1, 5).
