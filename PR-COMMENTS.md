# PR #22 — Copilot Review Comments

**PR:** feat(red-team): implement /red-team adversarial review skill
**Reviewer:** copilot-pull-request-reviewer[bot]
**Date:** 2026-04-07
**Total comments:** 10 posted + 1 suppressed

---

## Critical (fix before merge)

### 1. Missing `Write` tool in agent tool access

**Files:** `SKILL.md:302`, `security-agent.md:68`, `operational-agent.md:73`, `persona-resolution.md:110`

Agents are instructed to write findings files via the Write tool, but Step 3e does not grant them `Write`. This would cause all agents to fail at output. The same issue is echoed across all persona files and the dynamic persona template.

**Copilot suggestion:**
```markdown
- **Security:** `Read`, `Glob`, `Grep`, `Write`, `Bash` (`Write` for findings; `Bash` for security verification)
- **All other lenses:** `Read`, `Glob`, `Grep`, `Write` (`Write` for findings files)
```

**Disposition:** ACCEPT — This is a genuine bug. Agents cannot write findings without the `Write` tool.

> **Review:** Confirmed. SKILL.md:299-302 lists tools without `Write`, while `agent-prompt-template.md:37-38` explicitly instructs agents to "Write your findings to the output path above using the Write tool." The fix must update SKILL.md Step 3e, and should also update the `## Tool Access` section in `security-agent.md:64-69` and `operational-agent.md:68-73` to include `Write`, and update the dynamic persona template in `persona-resolution.md:106-111` which also lists tools without `Write`. The ARCHITECTURE_AND_DESIGN.md security model section (lines 92-95) also omits `Write` from its tool examples and should be updated for consistency.

---

### 2. Inconsistent debate status labels

**File:** `agent-prompt-template.md:81`

The agent prompt template uses "Sustained/Modified/Withdrawn" but every other file (findings-format.md, debate-rules.md, synthesis-prompt-template.md, report-template.md) uses "Sustained/Rebutted/Contested". Mismatched labels would cause synthesis to fail or produce incorrect status categorization.

**Copilot suggestion:**
```
Update to: Sustained / Rebutted / Contested
```

**Disposition:** ACCEPT — Clear copy error. The canonical labels are Sustained/Rebutted/Contested.

> **Review:** Confirmed, but the scope is wider than Copilot flagged. `agent-prompt-template.md:80-81` uses "Sustained/Modified/Withdrawn" — that needs fixing. Additionally, `ARCHITECTURE_AND_DESIGN.md:200` uses the same wrong labels ("Sustained, Modified, or Withdrawn") in the Phase 3 Debate Flow section. Both files need updating to "Sustained/Rebutted/Contested" to match the canonical labels in `findings-format.md:31`, `debate-rules.md:96-101`, and `synthesis-prompt-template.md:77`. Copilot missed the ARCHITECTURE_AND_DESIGN.md instance.

---

## Medium (doc consistency)

### 3. Preamble validation mismatch in persona resolution

**File:** `SKILL.md:282`

Step 3d says the override is valid if its `## Preamble` section declares an adversarial posture matching the lens name. But `references/persona-resolution.md` validates based on the `PERSONA:` line containing the lens name. Two different validation rules for the same check.

**Copilot suggestion:**
```markdown
If it exists and contains a `PERSONA:` line naming the selected lens, use it.
If the file exists but the `PERSONA:` line is missing or names a different lens
(for example, a security override used for the design lens), skip it and fall
to tier 2.
```

**Disposition:** ACCEPT — The `PERSONA:` line check is more precise and mechanically verifiable than "preamble posture matching." Align SKILL.md to match persona-resolution.md.

> **Review:** Confirmed. SKILL.md:280 says "its `## Preamble` section declares an adversarial posture matching the lens name" while `persona-resolution.md:14-17` validates against "a `PERSONA:` line" containing the lens name. The persona-resolution.md approach is clearly more specific (rules 1-4 on lines 15-17) and the suggested fix text is correct. Only SKILL.md Step 3d needs updating; no other files reference the preamble-based validation.

---

### 4. Chunking preamble has no section identifier

**File:** `chunking-rules.md:80`

The findings format requires every finding in a chunked artifact to include a `§` section identifier. But the chunking rules state the preamble is shared across all agents without its own identifier. This makes it impossible to file a compliant finding about preamble content (imports, constants, module-level code).

**Copilot suggestion:** Assign `§preamble:{start}-{end}` to preamble sections.

**Disposition:** ACCEPT — Real gap. Preamble content can contain findings (e.g., unused imports, hardcoded config). It needs a `§` identifier for traceability.

> **Review:** Confirmed. `chunking-rules.md:79-80` explicitly says the preamble is "Not assigned a standalone identifier — it provides context, not review scope." Meanwhile, `findings-format.md:48` requires a `§` section identifier for every finding when the artifact is chunked. This creates an impossible compliance situation for preamble findings. The fix (`§preamble:{start}-{end}`) is sound. Update `chunking-rules.md` lines 79-80 to assign the identifier, and add `§preamble` to the examples on line 69-72.

---

### 5. No "Rebutted findings" section in report template

**File:** `report-template.md:124`

The debate rules and synthesis prompt say rebutted findings should appear in the Methodology section under "Rebutted findings," but the report template's Methodology section is only a key-value table with no subsection for listing rebutted findings.

**Copilot suggestion:** Add a dedicated `### Rebutted findings` subsection.

**Disposition:** ACCEPT — Without an explicit placeholder, the synthesis agent has no unambiguous target for rebutted findings. Add a conditional subsection after the Methodology table.

> **Review:** Confirmed. `report-template.md:88-104` Methodology section is purely a key-value table ending at line 104. Synthesis rule #6 (`report-template.md:121-122`) and `synthesis-prompt-template.md:81-82` both say rebutted findings go "in the Methodology section under 'Rebutted findings'" but no such subsection exists in the template. Adding a conditional `### Rebutted findings` subsection after the Methodology table (after line 104) is the right fix. It should be marked as debate-mode-only with a note to omit when debate is not active.

---

### 6. Opus-only vs "graceful Sonnet degradation"

**File:** `ARCHITECTURE_AND_DESIGN.md:173`

Design decision #11 says "Opus preferred for sub-agents, graceful Sonnet degradation" and describes warning behavior when a lesser model is detected. But SKILL.md hard-requires `model: "opus"` for both red-team and synthesis agents with no fallback or warning logic.

**Copilot suggestion:** Either document actual behavior (Opus-only) or add fallback logic.

**Disposition:** ACCEPT — Update design decision #11 to reflect reality. The `model: "opus"` setting is a preference hint to Claude Code, not a hard requirement. If Opus is unavailable, Claude Code will use the best available model. Reword to clarify this is a preference, not a guarantee, and no explicit fallback logic is needed.

> **Review:** Confirmed. ARCHITECTURE_AND_DESIGN.md:172 says "Opus preferred for sub-agents, graceful Sonnet degradation" and describes "warning behavior when a lesser model is detected," but SKILL.md:310 simply sets `model: "opus"` with no warning or fallback logic anywhere in the workflow. The disposition reasoning is correct — `model: "opus"` is a hint, not an enforcement mechanism. Reword decision #11 to state it is a preference hint and remove the "graceful degradation" language since no degradation logic exists.

---

## Low (wording nit)

### 7. "No rebuttal" vs "accepted" ambiguity

**File:** `debate-rules.md:113`

The text says a finding with no rebuttal is marked Sustained because "green-team accepted it." But acceptance should be an explicit ACCEPT response with evidence, not silence. This conflates green-team failure (no response) with green-team agreement.

**Copilot suggestion:** Distinguish between explicit ACCEPT and no response.

**Disposition:** ACCEPT — Minor but valid. Clarify: explicit ACCEPT = Defense field records acceptance reason; no response = Defense field says "No rebuttal received (agent failure or timeout)." Both result in Sustained status, but the Defense field differentiates the cause.

> **Review:** Confirmed. `debate-rules.md:112` says "A finding that receives no rebuttal (green-team accepted it) is marked Sustained" — the parenthetical conflates silence with agreement. The green-team persona in `debate-rules.md:37-42` defines explicit ACCEPT as a response type, so the distinction already exists in the protocol. The fix is localized to `debate-rules.md:112` and possibly `debate-rules.md:127` where "No rebuttal received" is used in the Defense field example. Update both to distinguish the two cases.

---

## Suppressed (low confidence)

### 8. Deleted codebase-assessment.md may have dangling references

**File:** `docs/codebase-assessment.md:1`

Copilot suggests the deletion may leave dangling references in progress.txt and recommends archiving under `docs/archive/` instead.

**Disposition:** DISMISS — The file is from a completed, unrelated task (deprecated MCP servers cleanup). The progress.txt in this PR is for the red-team skill, not the old assessment. No dangling references exist.

> **Review:** Agree with DISMISS. Searched the red-team skill source files and found no references to `codebase-assessment.md`. The file is unrelated to this PR's scope. Copilot's suggestion to archive under `docs/archive/` is unnecessary overhead for a file from a completed, separate task.
