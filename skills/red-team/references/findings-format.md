# Per-Agent Findings Format

All red-team sub-agents write findings to `docs/red-team/{slug}-{nn}/{lens}-findings.md` using
this format. The synthesis agent reads these files when producing the consolidated report.

---

```markdown
# {Lens} Assessment

## Agent Persona
I am the {Lens} reviewer. My role is to {brief description of adversarial focus}.
My adversarial posture: {what I assume and what I challenge}.

## Assessment Summary
Items examined: {count}
Findings: {count} (Critical: N, High: N, Medium: N, Low: N)

## Findings

### Finding 1: {title}
- **Severity:** Critical | High | Medium | Low
- **Category:** {lens-specific category}
- **Section:** {section identifier, e.g., §auth-middleware:45-120 — omit if artifact was not chunked}
- **Observation:** {what was found}
- **Evidence:** {specific evidence from artifact -- line numbers, quotes, structural observations}
- **Impact:** {what could go wrong}
- **Recommendation:** {what to do about it}
- **Defense:** {green-team rebuttal summary — debate mode only, omit otherwise}
- **Status:** Sustained | Rebutted | Contested {debate mode only, omit otherwise}

### Finding 2: ...

## Strengths
- {what the artifact got right, from this lens's perspective}
```

---

## Field Requirements

| Field | Required | Notes |
|-------|----------|-------|
| Agent Persona | Yes | Must state adversarial posture explicitly |
| Assessment Summary | Yes | Must include item counts -- not just finding counts |
| Severity | Yes | Exactly one of: Critical, High, Medium, Low |
| Category | Yes | Lens-specific (see agent prompts for valid categories) |
| Section | Conditional | Required when artifact was chunked (> 1500 lines). Use the `§` identifier from the assigned section. Omit for non-chunked artifacts. |
| Evidence | Yes | Must cite specific artifact content: line numbers, quotes, or structural observations. "This might be a problem" is not evidence. |
| Defense | Conditional | Required in debate mode only. Contains green-team rebuttal summary or "No rebuttal received." |
| Status | Conditional | Required in debate mode only. Exactly one of: Sustained, Rebutted, Contested. |
| Strengths | Yes | At least one strength, or explicit "No strengths identified after examining N items" |

## Empty Categories

When a lens finds no issues, the findings section must state:

```markdown
## Findings

No issues found after examining {N} items: {brief list of what was checked}.
```

A claim of zero issues with zero items checked is invalid.

## Severity Definitions

| Severity | Definition |
|----------|------------|
| Critical | Fundamental flaw that blocks the artifact's purpose or creates serious risk. Must be addressed before proceeding. |
| High | Significant issue that materially impacts quality, security, or correctness. Should be addressed before finalizing. |
| Medium | Notable gap or weakness. Should be addressed but does not block progress. |
| Low | Minor improvement opportunity. Address if convenient. |

## Structural Compliance Checklist

The orchestrator validates each agent's output against these checks. A finding file that
fails validation is flagged in the consolidated report methodology section.

| Check | Rule | Failure |
|-------|------|---------|
| Persona stated | `## Agent Persona` section exists with adversarial posture | Agent output incomplete |
| Effort quantified | `## Assessment Summary` contains `Items examined:` with a number > 0 | Unquantified review |
| Findings enumerated | Each finding has Severity, Category, Evidence fields | Unstructured finding |
| Evidence required | No finding has empty or placeholder Evidence | Speculative finding |
| Section referenced | When chunked, each finding includes a `§` section identifier | Missing traceability |
| Empty justified | Zero-finding reports include item count and list of what was checked | Unjustified empty |
| No hedging | Findings do not use "might", "could possibly", "perhaps" as primary evidence | Weak finding |
