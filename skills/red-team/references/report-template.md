# Consolidated Report Template

The synthesis agent uses this template when consolidating findings from all red-team
sub-agents into the final `CONSOLIDATED-REPORT.md`. The orchestrator passes the full
contents of this file to the synthesis agent as part of its dynamically generated prompt.

---

```markdown
# Red-Team Report: {artifact description}

## Executive Summary

{1-2 paragraph synthesis across all agents. State the most important findings upfront.
Do not soften or hedge -- be direct about the artifact's risk profile.}

**Overall risk:** {Critical | High | Medium | Low}
**Total findings:** {count} (Critical: N, High: N, Medium: N, Low: N)

---

## Critical & High Findings

{Deduplicated, merged findings from all agents. Highest severity first.
If a finding was flagged by multiple lenses, merge into a single entry.}

### Finding 1: {title}
- **Severity:** {level}
- **Lens(es):** {which agent(s) flagged this}
- **Section:** {section identifier(s) — omit if artifact was not chunked}
- **Observation:** {merged description}
- **Evidence:** {consolidated evidence from all contributing agents}
- **Impact:** {what could go wrong}
- **Recommendation:** {what to do about it}
- **Defense:** {green-team rebuttal summary — debate mode only, omit otherwise}
- **Status:** Sustained | Rebutted | Contested {debate mode only, omit otherwise}

### Finding 2: ...

---

## Medium & Low Findings

{Same structure as above. Include only findings with sufficient evidence.
Weak or speculative findings may be omitted -- note what was filtered and why
at the end of this section.}

### Finding N: ...

**Filtered findings:** {count} findings omitted due to insufficient evidence.
{One-line summary of each filtered finding and the reason for filtering.}

---

## Cross-Cutting Themes

{Patterns that emerged across multiple lenses. These are higher-order observations
about systemic issues, not individual findings.}

- **Theme 1: {title}** -- {description, noting which lenses surfaced this}
- **Theme 2: {title}** -- ...

---

## Strengths

{What the artifact got right -- consolidated from all agents.
Genuine strengths only. Do not pad this section.}

- {strength from agent 1}
- {strength from agent 2}
- ...

---

## Per-Agent Findings

Individual agent findings are preserved alongside this report for full traceability.

| Lens | Findings File |
|------|---------------|
| {Lens 1} | [{lens1}-findings.md](./{lens1}-findings.md) |
| {Lens 2} | [{lens2}-findings.md](./{lens2}-findings.md) |
| ... | ... |

---

## Methodology

| Field | Value |
|-------|-------|
| Artifact | {file path or description} |
| Artifact type | {classified type} |
| Date | {YYYY-MM-DD} |
| Agents | {list of lenses used} |
| Agent compliance | {pass/partial/fail per lens, from Step 3g verification} |
| Chunked | {Yes (N sections) or No — whether smart chunking was applied} |
| Debate | {Yes (N rounds) or No — whether debate mode was used} |
| Findings produced | {total across all agents before dedup} |
| Findings after dedup | {total in this report} |
| Findings filtered | {count of weak findings omitted} |
| Findings sustained | {count — debate mode only, omit otherwise} |
| Findings rebutted | {count — debate mode only, omit otherwise} |
| Findings contested | {count — debate mode only, omit otherwise} |
```

---

## Synthesis Rules

1. **Deduplicate across lenses.** If two agents flag the same issue, merge into one finding.
   List all contributing lenses. Use the highest severity assigned by any agent.
2. **Active filtering.** Weak findings (speculative, no specific evidence, "might be an issue")
   may be downgraded or omitted. Always note what was filtered and why.
3. **Severity preserved.** Do not downgrade severity during synthesis unless the evidence
   from multiple agents contradicts the original rating.
4. **Cross-cutting themes.** After dedup, look for patterns across 2+ findings that suggest
   a systemic issue. These go in the Themes section, not as separate findings.
5. **No new findings.** Synthesis merges and organizes -- it does not invent findings that
   no agent reported.
6. **Debate findings (when applicable).** Rebutted findings are omitted from main sections
   and listed in Methodology under "Rebutted findings." Contested findings remain in the
   report with both Evidence and Defense, allowing the reader to judge. Sustained findings
   are included at original severity. The Executive Summary notes the debate outcome counts.

---

## Dedup Rules

Two findings are **duplicates** when they refer to the same artifact element (same line
range, function, section, or design decision) AND describe the same core problem, even
if framed differently by each lens.

Two findings are **NOT duplicates** when they refer to the same element but identify
different problems (e.g., a security vulnerability vs. a completeness gap in the same
function), or when they describe similar problem types in different artifact elements.

**Chunked artifacts:** When findings include section identifiers (`§`), use the identifier
to match locations across agents. Two findings in different sections are not duplicates
even if they describe similar problems — they may indicate a cross-cutting theme (see §4e).

For each duplicate set:

1. Merge into a single finding entry.
2. List all contributing lenses in the **Lens(es)** field.
3. Use the **highest severity** assigned by any contributing agent.
4. Combine evidence from all agents -- do not discard any agent's evidence.
5. Use the most specific and actionable recommendation from the set.

---

## Filtering Criteria

After dedup, evaluate each remaining finding against these filters:

| Filter | Action |
|--------|--------|
| No specific evidence (empty, placeholder, or "TBD" in Evidence field) | **Remove.** Note as filtered. |
| Evidence is purely speculative ("this might...", "could potentially...") | **Remove.** Note as filtered. |
| Finding restates the recommendation without identifying an actual problem | **Remove.** Note as filtered. |
| Low severity with generic observation and no artifact-specific evidence | **Downgrade to filtered.** Note as filtered. |
| Finding duplicates a higher-severity finding that survived dedup | **Remove.** Already captured. |

**Do not filter** findings that have specific evidence, even if the severity seems low.
When in doubt, keep the finding -- err on the side of inclusion.

For every filtered finding, record the original title, severity, originating agent,
and reason for filtering (one line each). These appear in the "Filtered findings"
subsection of the report.

---

## Overall Risk Determination

| Condition | Overall Risk |
|-----------|-------------|
| Any Critical finding | **Critical** |
| No Critical, but any High finding | **High** |
| No Critical or High, but any Medium finding | **Medium** |
| Only Low findings or no findings | **Low** |
