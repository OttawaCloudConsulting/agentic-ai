# Red-Team Skill — Concept Document

## Purpose

A standalone, general-purpose `/red-team` skill that provides adversarial review of any artifact — code, designs, PRDs, spike outputs, architecture docs, or anything else a user points it at. It addresses four gaps in the current ad-hoc red-team patterns scattered across skills like `/spike` and `/occ-skill-refactor`:

1. **No reuse** — red-team logic is duplicated; this skill provides a single canonical implementation.
2. **Too narrow** — current red-teaming only covers research validation and skill quality; this skill covers any artifact type.
3. **Not tunable** — no way to control depth, focus areas, or adversarial intensity; this skill introduces configurable lenses.
4. **Missing structure** — output format varies; this skill defines a consistent report structure.

This skill is standalone and discrete. Existing skills (`/spike`, `/occ-skill-refactor`, `/occ-skill-creator`) retain their own red-team implementations — no migration is planned. Future integration by other skills is possible but not expected.

---

## Invocation

Conversational and context-based. The user describes what to red-team in natural language:

```
/red-team my design
/red-team the code we just wrote
/red-team docs/architecture/system-design.md
/red-team the PRD for feature X
```

The skill interprets the request, identifies the target artifact(s), and proceeds.

### Options

| Flag | Effect |
|------|--------|
| `--debate` | Enables Agent Teams debate mode (red + green team) |
| `--rounds N` | Number of debate rounds (requires `--debate`, default 1) |
| `--auto` | Skips the approval gate |

---

## Adversarial Lenses

Lenses are the focus areas for adversarial review. The skill **auto-detects** relevant lenses based on artifact type, but the user can **override** or extend them.

### Artifact Type Detection

The orchestrator determines artifact type through a combination of:

- **File extension and path** — `.tf` files suggest infra, files under `docs/` suggest documentation
- **Content analysis** — reading the file to identify structure (e.g., PRD headings, code patterns, architectural diagrams)
- **User hint** — the natural language in the invocation (e.g., "my design" vs "the code we just wrote") provides strong signal

When artifact type is ambiguous, the orchestrator includes its classification in the approval gate for user confirmation.

### Example Lenses

| Lens | Focus | Typical Artifact Types |
|------|-------|----------------------|
| **Security** | Vulnerabilities, attack vectors, auth gaps, data exposure | Code, architecture, infra |
| **Feasibility** | Can this actually be built? Timeline realism, resource gaps | PRDs, designs, proposals |
| **Assumptions** | Unverified claims, unstated dependencies, wishful thinking | Any |
| **Completeness** | Missing edge cases, unaddressed requirements, gaps | Any |
| **Operational** | Deployment risk, monitoring gaps, failure modes, recovery | Architecture, infra, code |
| **Design** | Coupling, cohesion, extensibility, pattern misuse | Code, architecture |
| **Cost** | Resource waste, over-engineering, hidden ongoing costs | Architecture, infra, proposals |
| **Compliance** | Regulatory, policy, or standards violations | Any |

The orchestrator proposes a lens set based on artifact analysis. Each lens maps to a specialized sub-agent with a tailored persona and evaluation criteria.

**Depth:** By default, a red-team review is always deep. There is no "quick scan" mode — the adversarial posture demands thoroughness.

---

## Agent Architecture

### Multi-Agent Team

The skill spawns **multiple specialized sub-agents** (minimum 2, maximum 10) based on the selected lenses. Preference is 2-3 agents unless complexity demands more, the user requests additional agents, or debate mode requires additional participants. Each agent operates in its own isolated context to prevent confirmation bias.

All red-team agents run **in parallel** in default mode. In debate mode with Agent Teams, sequencing is required for the debate rounds.

Agent tooling can vary per agent. The orchestrator decides what tools each agent receives — some agents may get broader access (e.g., security agent), others may be restricted. Tool assignment is part of the orchestrator's agent team proposal.

```
/red-team
    |
    v
[Orchestrator] ──analyze artifact──> propose agent team + lenses
    |                                          |
    |  <── user approval (configurable) ───────┘
    |
    ├──spawn (parallel)──> [Security Agent]     ──> docs/red-team/{desc}-{nn}/security-findings.md
    ├──spawn (parallel)──> [Assumptions Agent]  ──> docs/red-team/{desc}-{nn}/assumptions-findings.md
    ├──spawn (parallel)──> [Design Agent]       ──> docs/red-team/{desc}-{nn}/design-findings.md
    |
    └──spawn──> [Synthesis Agent]               ──> docs/red-team/{desc}-{nn}/CONSOLIDATED-REPORT.md
```

### Agent Responsibilities

- **Orchestrator (SKILL.md):** Analyzes the target artifact, determines artifact type, selects lenses, proposes agent team, manages approval gate, spawns agents, triggers synthesis.
- **Red-Team Sub-Agents (per lens):** Each agent has a specific adversarial persona and lens. Operates independently. Writes its own findings file. First section of every findings file is the agent introducing itself and its persona.
- **Green-Team Members (debate mode only):** Participate via [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams). They debate directly with red-team members, influencing the red-team agents' final findings through adversarial dialogue — they do not produce separate report files.
- **Synthesis Agent:** Independent sub-agent that reads all findings files, deduplicates, resolves contradictions, and produces `CONSOLIDATED-REPORT.md`. Always dynamically generated by the orchestrator (not sourced from persona library) since its role is fixed and uniform across all red-team runs.

### Agent Persona Resolution

When the orchestrator determines it needs a specific red-team agent type, it resolves the persona in this order:

1. **`.claude` directory** — check for matching agent persona definitions
2. **Reference files** — check `references/` for matching persona specs
3. **Dynamically created** — orchestrator generates the persona on the fly

If existing personas in `.claude` or `references/` do not match the orchestrator's requirements for the specific lens, it creates a dynamic persona rather than forcing a mismatched one.

### Agent Findings File Format

Every red-team sub-agent findings file follows this structure:

```markdown
# {Lens} Assessment

## Agent Persona
I am the {Lens} reviewer. My role is to... {brief persona description}.
My adversarial posture: {what I assume and what I challenge}.

## Assessment Summary
Findings: {count} ({Critical: N, High: N, Medium: N, Low: N})

## Findings

### Finding 1: {title}
- **Severity:** Critical | High | Medium | Low
- **Category:** {lens-specific category}
- **Observation:** {what was found}
- **Evidence:** {how it was verified}
- **Impact:** {what could go wrong}
- **Recommendation:** {what to do about it}

### Finding 2: ...

## Strengths
- {what the artifact got right, from this lens's perspective}
```

---

## Agent Teams (Debate Mode)

Debate mode uses [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams) to enable structured adversarial dialogue between red-team and green-team members. The green-team does not produce separate reports — it influences the red-team agents' findings by debating directly with them.

### Default Mode: Red-Team Only

Red-team sub-agents run in parallel, each writes findings. Synthesis agent compiles the consolidated report.

### Debate Mode: Red + Green Team

When `--debate` is specified, the workflow uses Agent Teams coordination:

1. **Red-team agents** run and write initial findings (parallel).
2. **Green-team members** debate directly with red-team agents via Agent Teams — challenging findings, providing rebuttals, and defending the artifact with evidence. This dialogue influences the red-team agents' final findings.
3. **Additional rounds** (if `--rounds > 1`): further debate iterations between red and green members.
4. **Red-team agents update their findings files** to reflect the debate outcome — noting which findings were sustained, modified, or withdrawn after green-team challenge.
5. **Synthesis agent** reads all final findings files and produces `CONSOLIDATED-REPORT.md`, noting where findings were sustained, rebutted, or remain contested after debate.

The green-team operates with the same rigor as red-team agents — rebuttals must provide evidence, not just disagree.

### Activation

```
/red-team my design                     # default: red-team only
/red-team my design --debate            # enables green-team debate via Agent Teams
/red-team my design --debate --rounds 2 # multi-round debate
```

---

## Approval Gate

Before spawning agents, the orchestrator presents the proposed team:

```
Red-Team Plan for: docs/architecture/system-design.md
Artifact type: Architecture Document

Proposed agents:
  1. Security Agent — attack vectors, auth, data exposure
  2. Operational Agent — failure modes, monitoring, recovery
  3. Design Agent — coupling, extensibility, pattern fit
  4. Assumptions Agent — unverified claims, unstated deps

Debate mode: off
Output: docs/red-team/system-design-01/

Proceed? [Yes / Modify / Cancel]
```

**Configurable:** The gate is shown by default. Can be skipped with `--auto`.

---

## Output Location

Reports are written to `docs/red-team/{description}-{nn}/` where:

- `{description}` is a slug derived from the artifact or user's description
- `{nn}` is a zero-padded sequence number (01, 02, 03...)

The skill detects previous runs by checking for existing `{description}-*` directories and increments the sequence number. No formal history tracking — the directory naming provides a lightweight audit trail.

### Directory Structure

```
docs/red-team/system-design-01/
  ├── security-findings.md
  ├── operational-findings.md
  ├── design-findings.md
  ├── assumptions-findings.md
  └── CONSOLIDATED-REPORT.md
```

### Consolidated Report Structure (CONSOLIDATED-REPORT.md)

```markdown
# Red-Team Report: {artifact description}

## Executive Summary
{1-2 paragraph synthesis of all findings across all agents}
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
- **Defense (if debate mode):** {green-team rebuttal, if any}
- **Status:** Sustained | Rebutted | Contested

## Medium & Low Findings
{Same structure, lower severity}

## Cross-Cutting Themes
{Patterns that emerged across multiple lenses}

## Strengths
{What the artifact got right — consolidated from all agents}

## Methodology
Agents: {list of agents and their lenses}
Debate mode: {on/off}
Rounds: {N}
Artifact: {path or description}
Date: {timestamp}
```

---

## Confirmation Bias Prevention

Inherited from the spike red-team pattern and strengthened:

1. **Explicit adversarial instruction:** Each agent's persona prompt states its job is to find flaws.
2. **Isolated contexts:** Every agent runs as a separate sub-agent — no shared reasoning.
3. **Structured output forces enumeration:** Agents must list specific findings; empty categories must explicitly state verification was performed.
4. **Quantified effort:** Assessment summary requires counts — "0 findings after checking N items" is valid; "looks good" is not.
5. **Multi-perspective:** Multiple agents with different lenses naturally challenge each other's blind spots.
6. **Green-team adversarial balance:** In debate mode, defenders debate directly with red-team members via Agent Teams, providing evidence-based challenges that influence findings.

---

## Relationship to Existing Red-Team Patterns

This skill is a **superset** of the existing patterns but does not replace them:

| Current Pattern | Where | Relationship |
|----------------|-------|-------------|
| Spike red-team agent | `skills/project/spike/` | Independent — spike's red-team is specific to its research validation design |
| Skill refactor red-team | `skills/occ-skill-refactor/` | Independent — refactor's red-team is specific to its skill quality review |
| Skill creator red-team | `skills/occ-skill-creator/` | Independent — same as refactor |

Existing skills are out of scope for change. This skill is standalone and divergent by design.
