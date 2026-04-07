# Red-Team Skill -- MVP Specification

This document scopes the [full concept](CONCEPT.md) down to a minimum viable product. The MVP delivers end-to-end adversarial review with a reduced lens set, simplified architecture, and no debate mode. It is designed to be implementable in a single session while delivering immediate value.

---

## 1. Scope

### In MVP

| Feature | Detail |
|---------|--------|
| Invocation | `/red-team <target>` -- natural language, file paths, or conversation context |
| Artifact detection | Auto-classify via file extension, content analysis, and user hint |
| Lenses | 4 lenses: Security, Assumptions, Completeness, Design |
| Lens selection | Auto-selected based on artifact type (2-3 per run) |
| Agent architecture | Orchestrator (SKILL.md) spawns 2-3 parallel sub-agents, one per lens |
| Synthesis | Orchestrator reads all sub-agent findings, deduplicates, writes consolidated report |
| Output | Single file: `docs/red-team/{slug}-{nn}/CONSOLIDATED-REPORT.md` |
| Bias prevention | Adversarial prompts, isolated contexts, structured output, quantified effort |

### Deferred

| Feature | Reason |
|---------|--------|
| `--debate` flag / green team / Agent Teams | Requires Agent Teams integration; not needed for core value |
| `--rounds N` flag | Only meaningful with debate mode |
| `--auto` flag and approval gate | MVP team is small and deterministic; gate adds friction without value at this scale |
| Lenses: Feasibility, Operational, Cost, Compliance | Expand after core 4 lenses are proven |
| User lens override | Auto-selection is sufficient for MVP |
| Persona resolution hierarchy (`.claude` -> `references/` -> dynamic) | Hardcoded prompts in `references/` are sufficient |
| Separate synthesis agent | Orchestrator handles synthesis; extract when complexity demands it |
| Per-agent findings files in output directory | Only consolidated report shipped; per-agent files stay in `/tmp/` |
| Agent-specific tool customization | All agents get the same tool set in MVP |

---

## 2. SKILL.md Specification

### Frontmatter

```yaml
---
name: red-team
description: >-
  Adversarial review of any artifact -- code, designs, PRDs, architecture docs,
  or proposals. Spawns parallel sub-agents with different adversarial lenses to
  find flaws, gaps, and risks. Use when asked to red-team, critique, challenge,
  or adversarially review work. Triggers on "red-team this", "find holes in",
  "challenge my design", "what could go wrong", or "/red-team". Do NOT use for
  general code review, proofreading, style feedback, or non-adversarial review.
disable-model-invocation: true
---
```

### Workflow

#### Step 1 -- Identify Target Artifact

Parse the user's invocation to determine the target:

- **Explicit file path:** Read the file directly.
- **Natural language reference** (e.g., "my design", "the code we just wrote"): Resolve from conversation context. If ambiguous, use `AskUserQuestion` with 2-3 options to clarify.
- **Multiple files:** If the target spans multiple files, read all and concatenate for analysis. Treat as a single artifact.

Read the target artifact content. If the file does not exist or cannot be resolved, report the error and ask the user to clarify.

#### Step 2 -- Classify Artifact and Select Lenses

Determine artifact type using three signals:

1. **File extension and path** -- `.py`, `.ts`, `.tf` suggest code/infra; `docs/` suggests documentation
2. **Content structure** -- PRD headings, code patterns, architectural diagrams, config blocks
3. **User hint** -- the natural language in the invocation ("my design" vs "the API code")

Select lenses from the mapping table:

| Artifact Type | Default Lenses |
|---|---|
| Code | Security, Design, Completeness |
| Architecture / Design document | Assumptions, Design, Completeness |
| PRD / Proposal | Assumptions, Completeness |
| Infrastructure (Terraform, CDK, CloudFormation) | Security, Completeness, Design |
| Other / Unknown | Assumptions, Completeness |

Display the classification and selected lenses to the user before proceeding:

```
Target: docs/architecture/system-design.md
Artifact type: Architecture Document
Lenses: Assumptions, Design, Completeness
```

#### Step 3 -- Spawn Red-Team Agents

Read `references/agent-prompts.md` for the adversarial persona prompt for each selected lens.

For each selected lens, spawn a sub-agent using the `Agent` tool:

- Pass the agent its persona prompt (from `references/agent-prompts.md`), the full artifact content, and the artifact type classification.
- Instruct the agent to write structured findings to `/tmp/red-team-{lens}-findings.md` (e.g., `/tmp/red-team-security-findings.md`).
- **All agents run in parallel** -- spawn all agent tool calls in a single message.

After all agents complete, read each `/tmp/red-team-{lens}-findings.md` to verify output was produced. If any agent failed to produce output, note the failure in the report and continue with available findings.

#### Step 4 -- Assemble Consolidated Report

Read `references/report-template.md` for the consolidated report structure.

Read all `/tmp/red-team-*-findings.md` files produced in Step 3. Then:

1. **Deduplicate** -- merge findings flagged by multiple lenses into single entries, noting all contributing lenses.
2. **Sort by severity** -- Critical first, then High, Medium, Low.
3. **Identify cross-cutting themes** -- patterns that emerge across multiple lenses.
4. **Consolidate strengths** -- merge from all agents.
5. **Write methodology** -- agents used, lenses applied, artifact path, date.

Determine the output path:

- Check for existing `docs/red-team/{slug}-*` directories.
- Increment the sequence number (`{nn}`) from the highest existing run, or start at `01`.
- Create the directory if it does not exist.

Write the consolidated report to `docs/red-team/{slug}-{nn}/CONSOLIDATED-REPORT.md`.

#### Step 5 -- Completion Summary

Display to the user:

```
Red-Team Report Complete
========================
Artifact: docs/architecture/system-design.md
Overall Risk: High

Findings: 7 (Critical: 1, High: 2, Medium: 3, Low: 1)
Report: docs/red-team/system-design-01/CONSOLIDATED-REPORT.md

Suggested next steps:
- Address the 1 critical finding immediately
- Review high-severity findings before proceeding with implementation
```

### Critical Rules

1. **Evidence over assumption.** Every finding must cite specific evidence from the artifact -- line numbers, quoted text, or structural observations. "This might be a problem" is not a finding.
2. **No lazy "looks good."** Empty finding categories must explicitly state: "No issues found after checking N specific items." A claim of zero issues with zero items checked is invalid.
3. **Adversarial posture.** Each agent's prompt states its job is to find flaws, not confirm quality. Assume the artifact contains problems until proven otherwise.
4. **Isolated contexts.** Each sub-agent runs as a separate `Agent` tool invocation. No shared reasoning between agents. This prevents confirmation bias.
5. **Quantified effort.** Assessment summaries require counts -- "Checked 8 interfaces, found 2 with missing error handling" not "some interfaces lack error handling."

### Error Handling

| Scenario | Action |
|----------|--------|
| Target artifact not found or path invalid | Report error, use `AskUserQuestion` to clarify target |
| Artifact type ambiguous | Default to "Other/Unknown" lenses (Assumptions, Completeness) |
| Sub-agent fails to produce findings file | Note which lens failed in the report, continue with remaining findings |
| All sub-agents fail | Report the error, offer to retry or ask user for guidance |
| `docs/red-team/` directory does not exist | Create it automatically |
| Write failure on report | Display report content directly to user for manual save |

---

## 3. Supporting Files

### `references/agent-prompts.md`

Contains the adversarial persona prompt template and lens-specific prompts for all 4 MVP lenses. Each lens prompt includes:

1. **Persona introduction** -- who the agent is and its adversarial posture
2. **Focus areas** -- what specifically to examine for this lens
3. **Output format** -- structured findings matching the format below

**Per-agent output format** (written to `/tmp/red-team-{lens}-findings.md`):

```markdown
# {Lens} Assessment

## Agent Persona
I am the {Lens} reviewer. My role is to {brief description}.
My adversarial posture: {what I assume and what I challenge}.

## Assessment Summary
Items examined: {count}
Findings: {count} (Critical: N, High: N, Medium: N, Low: N)

## Findings

### Finding 1: {title}
- **Severity:** Critical | High | Medium | Low
- **Category:** {lens-specific category}
- **Observation:** {what was found}
- **Evidence:** {specific evidence from artifact -- line numbers, quotes, structural observations}
- **Impact:** {what could go wrong}
- **Recommendation:** {what to do about it}

### Finding 2: ...

## Strengths
- {what the artifact got right, from this lens's perspective}
```

**Lens-specific focus areas:**

| Lens | Persona Focus | What to Challenge |
|------|--------------|-------------------|
| Security | Vulnerabilities, attack vectors, auth gaps, data exposure | Trust boundaries, input validation, secrets management, access control, error information leakage |
| Assumptions | Unverified claims, unstated dependencies, wishful thinking | "Everyone knows" statements, implicit prerequisites, unvalidated scale estimates, missing evidence for claims |
| Completeness | Missing edge cases, unaddressed requirements, gaps | Error paths, boundary conditions, missing requirements, undefined behavior, integration points |
| Design | Coupling, cohesion, extensibility, pattern misuse | Unnecessary complexity, tight coupling, leaky abstractions, violated principles, scalability limits |

**Confirmation bias prevention** (applied to all lens prompts):

1. Explicit adversarial instruction: "Your job is to find flaws, not confirm quality."
2. Structured output forces enumeration of specific findings.
3. Empty categories must state: "No issues found after examining N items."
4. Assessment summary requires quantified effort (items examined vs findings count).
5. Agent runs in isolated context -- no shared reasoning with other agents.

### `references/report-template.md`

Contains the consolidated report structure:

```markdown
# Red-Team Report: {artifact description}

## Executive Summary
{1-2 paragraph synthesis across all agents}
Overall risk: {Critical | High | Medium | Low}
Total findings: {count} (Critical: N, High: N, Medium: N, Low: N)

## Critical & High Findings
{Deduplicated, merged findings from all agents, highest severity first}

### Finding 1: {title}
- **Severity:** {level}
- **Lens(es):** {which agent(s) flagged this}
- **Observation:** {merged description}
- **Evidence:** {consolidated evidence}
- **Impact:** {what could go wrong}
- **Recommendation:** {what to do about it}

## Medium & Low Findings
{Same structure, lower severity}

## Cross-Cutting Themes
{Patterns that emerged across multiple lenses}

## Strengths
{What the artifact got right -- consolidated from all agents}

## Methodology
Agents: {list of agents and their lenses}
Artifact: {path or description}
Date: {timestamp}
```

---

## 4. Agent Architecture

```
/red-team <target>
    |
    v
[Orchestrator (SKILL.md)]
    |-- read target artifact
    |-- classify artifact type
    |-- select 2-3 lenses from mapping table
    |-- read references/agent-prompts.md
    |
    |-- spawn parallel (Agent tool, single message):
    |     [Security Agent]     --> /tmp/red-team-security-findings.md
    |     [Assumptions Agent]  --> /tmp/red-team-assumptions-findings.md
    |     [Design Agent]       --> /tmp/red-team-design-findings.md
    |
    |-- read all /tmp/red-team-*-findings.md
    |-- deduplicate, sort, synthesize
    |-- read references/report-template.md
    v
docs/red-team/{slug}-{nn}/CONSOLIDATED-REPORT.md
```

### Key Simplifications from CONCEPT.md

| CONCEPT.md | MVP |
|---|---|
| Separate orchestrator agent | SKILL.md is the orchestrator |
| Separate synthesis agent | Orchestrator handles synthesis |
| Approval gate with modify/cancel options | Auto-proceeds (display classification only) |
| 3-tier persona resolution (`.claude` -> `references/` -> dynamic) | Prompts hardcoded in `references/agent-prompts.md` |
| 8 lenses | 4 lenses (Security, Assumptions, Completeness, Design) |
| User lens override | Auto-selection only |
| Per-agent findings in output directory | Per-agent findings in `/tmp/` only; output has consolidated report only |
| Agent-specific tool assignment | All agents get same tools |

### Agent Tool Access

All red-team sub-agents receive: `Read`, `Glob`, `Grep`, `Bash`, `Agent` (for sub-searches), `WebFetch`, `WebSearch`.

Broad access enables independent verification of claims in the artifact -- agents can read related code, check configurations, search for usage patterns, and verify external references.

---

## 5. Output

### Directory Naming

Output goes to `docs/red-team/{slug}-{nn}/` where:

- **`{slug}`** -- kebab-case descriptor derived from the artifact name or user's description (e.g., `system-design`, `auth-api-code`, `feature-x-prd`)
- **`{nn}`** -- zero-padded sequence number starting at `01`, incremented from the highest existing run for this slug

The orchestrator checks for existing `docs/red-team/{slug}-*` directories and increments accordingly. No formal history tracking -- directory naming provides the audit trail.

### Directory Contents (MVP)

```
docs/red-team/system-design-01/
  └── CONSOLIDATED-REPORT.md
```

Single file. Per-agent findings remain in `/tmp/` during execution and are not persisted to the output directory in MVP.

---

## 6. Acceptance Criteria

- [ ] `/red-team path/to/file.md` produces a consolidated report in `docs/red-team/`
- [ ] `/red-team` with natural language description (e.g., "the code we just wrote") resolves target from conversation context
- [ ] Artifact type is auto-detected and displayed to user before agent spawning
- [ ] 2-3 sub-agents spawn in parallel per invocation (verified by parallel `Agent` tool calls)
- [ ] Each sub-agent writes structured findings with severity levels and specific evidence
- [ ] Consolidated report deduplicates findings flagged by multiple lenses
- [ ] Report includes findings count by severity in executive summary
- [ ] Empty finding categories explicitly state verification was performed with item counts
- [ ] Sequential runs for the same artifact increment the `{nn}` counter (01, 02, 03...)
- [ ] SKILL.md body is under 500 lines (overflow in `references/`)
- [ ] Skill works end-to-end without manual intervention beyond initial invocation

---

## 7. Migration Path to Full Concept

Ordered by value -- each step is independently shippable:

| Step | Feature | Adds |
|------|---------|------|
| 1 | Approval gate + `--auto` flag | User review of proposed agent team before spawning; `--auto` skips gate |
| 2 | Remaining lenses + user override | Feasibility, Operational, Cost, Compliance; user can specify or exclude lenses |
| 3 | Separate synthesis agent | Dedicated agent for dedup/synthesis instead of orchestrator handling it |
| 4 | Per-agent findings in output | Individual findings files alongside consolidated report in output directory |
| 5 | Persona resolution hierarchy | 3-tier lookup: `.claude` -> `references/` -> dynamic generation |
| 6 | `--debate` flag + Agent Teams | Green team debate, `--rounds N`, multi-round adversarial dialogue |
