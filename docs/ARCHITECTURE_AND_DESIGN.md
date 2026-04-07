# Architecture and Design: Red-Team Skill

## Overview

The `/red-team` skill provides general-purpose adversarial review of any artifact in a Claude Code project. The user invokes `/red-team <target>`, and the skill orchestrates a team of parallel sub-agents -- each with a different adversarial lens -- to systematically find flaws, gaps, and risks in the target artifact. Findings are synthesized into a severity-rated consolidated report.

The skill is a standalone Claude Code skill living in `skills/red-team/` as a library component. Users copy it to their own projects. It does not replace or integrate with existing red-team patterns in `/spike`, `/occ-skill-refactor`, or `/occ-skill-creator`.

The architecture is phased:
- **Phase 1 (MVP):** 4 lenses, auto-selection, parallel agents, consolidated report
- **Phase 2:** Expanded to 8 lenses, user lens override, approval gate, per-agent findings in output
- **Phase 3:** Dedicated synthesis agent, persona resolution hierarchy, debate mode via Agent Teams

## Component Diagram

```
/red-team <target>
    |
    v
[Orchestrator (SKILL.md)]
    |-- Step 1: Resolve target artifact (file path or conversation context)
    |-- Step 2: Classify artifact type, select lenses
    |-- Step 3: Determine output path (docs/red-team/{slug}-{nn}/)
    |-- Step 4: Create output directory
    |-- Step 5: (Phase 2+) Present approval gate
    |
    |-- Step 6: Resolve per-lens persona prompts (3-tier: .claude/ -> references/ -> dynamic)
    |-- Step 7: Spawn parallel sub-agents (one per lens):
    |     |
    |     [Security Agent]     --> docs/red-team/{slug}-{nn}/security-findings.md
    |     [Assumptions Agent]  --> docs/red-team/{slug}-{nn}/assumptions-findings.md
    |     [Design Agent]       --> docs/red-team/{slug}-{nn}/design-findings.md
    |     [Completeness Agent] --> docs/red-team/{slug}-{nn}/completeness-findings.md
    |     ... (up to 10 agents)
    |
    |-- Step 8: (Phase 3 debate mode) Green-team debate via Agent Teams
    |
    |-- Step 9: Synthesis
    |     Dedicated synthesis agent reads all findings, deduplicates, filters, writes report
    |
    v
docs/red-team/{slug}-{nn}/
    ├── security-findings.md
    ├── assumptions-findings.md
    ├── design-findings.md
    ├── completeness-findings.md
    └── CONSOLIDATED-REPORT.md
```

## Data Flow

1. **User invocation** -- user provides target (file path or natural language reference)
2. **Artifact resolution** -- orchestrator reads target file(s); if ambiguous, prompts user
3. **Classification** -- orchestrator analyzes file extension, content structure, and user hint to determine artifact type
4. **Lens selection** -- artifact type maps to 2-3 lenses via static mapping table; user override available in Phase 2+
5. **Output path** -- orchestrator checks for existing `docs/red-team/{slug}-*` directories, increments sequence number
6. **Agent spawning** -- orchestrator resolves per-lens persona via 3-tier hierarchy (`.claude/red-team/` override -> `references/` bundled -> dynamic generation), spawns all agents in parallel via `Agent` tool
7. **Agent execution** -- each agent independently reviews the artifact through its adversarial lens, writes structured findings to the output directory
8. **Debate (--debate only)** -- green-team agents spawned via Agent Teams, paired with red-team agents for evidence-based rebuttals; findings updated with Defense/Status fields (Sustained/Rebutted/Contested)
9. **Synthesis** -- dedicated synthesis agent reads all findings files, deduplicates, actively filters weak findings, and writes `CONSOLIDATED-REPORT.md`; in debate mode, rebutted findings moved to methodology section
10. **Completion** -- orchestrator displays summary (finding counts, risk level, report path, debate outcome counts if applicable, suggested next steps)

## Component Inventory

| # | Component | Type / Technology | Purpose |
|---|-----------|-------------------|---------|
| 1 | SKILL.md | Claude Code skill (markdown + YAML frontmatter) | Orchestrator: artifact resolution, classification, lens selection, agent spawning, synthesis agent dispatch |
| 2 | `references/security-agent.md` | Persona prompt (markdown) | Security lens adversarial persona, focus areas, output format |
| 3 | `references/assumptions-agent.md` | Persona prompt (markdown) | Assumptions lens adversarial persona, focus areas, output format |
| 4 | `references/completeness-agent.md` | Persona prompt (markdown) | Completeness lens adversarial persona, focus areas, output format |
| 5 | `references/design-agent.md` | Persona prompt (markdown) | Design lens adversarial persona, focus areas, output format |
| 6 | `references/feasibility-agent.md` | Persona prompt (markdown) | Feasibility lens adversarial persona (Phase 2) |
| 7 | `references/operational-agent.md` | Persona prompt (markdown) | Operational lens adversarial persona (Phase 2) |
| 8 | `references/cost-agent.md` | Persona prompt (markdown) | Cost lens adversarial persona (Phase 2) |
| 9 | `references/compliance-agent.md` | Persona prompt (markdown) | Compliance lens adversarial persona (Phase 2) |
| 10 | `references/report-template.md` | Report template (markdown) | Consolidated report structure and field definitions |
| 11 | `references/findings-format.md` | Output format spec (markdown) | Standardized per-agent findings format shared across all lens prompts |
| 12 | `references/persona-resolution.md` | Resolution rules (markdown) | 3-tier persona lookup rules, mismatch detection, dynamic generation template |
| 13 | `references/agent-prompt-template.md` | Prompt template (markdown) | Red-team agent prompt assembly structure with debate mode additions |
| 14 | `references/synthesis-prompt-template.md` | Prompt template (markdown) | Synthesis agent prompt assembly structure with debate mode additions |
| 15 | `references/debate-rules.md` | Debate protocol (markdown) | Green-team persona, debate rounds, status labels, error handling |
| 16 | Sub-agents (runtime) | Claude Code Agent tool invocations | Parallel adversarial review agents, one per selected lens |
| 17 | Synthesis agent (runtime) | Claude Code Agent tool invocation | Deduplication, filtering, consolidated report generation; dynamically generated by orchestrator each run |
| 18 | Green-team agents (runtime) | Claude Code Agent Teams | Debate participants defending the artifact against red-team findings; spawned via Agent Teams in debate mode |

## Security Model

### Access Control

No separate access control. The skill runs within the user's Claude Code session with the user's existing permissions. Sub-agents inherit the session's tool access, scoped by the orchestrator:

- **Configurable per-agent tool access:** The orchestrator assigns tools based on lens type and artifact. For example:
  - Security agent: `Read`, `Glob`, `Grep`, `Write`, `Bash` (`Write` for findings; `Bash` for security verification)
  - Assumptions agent: `Read`, `Glob`, `Grep`, `Write` (`Write` for findings files)
  - Design agent: `Read`, `Glob`, `Grep`, `Write` (`Write` for findings files)

### Audit and Logging

All run metadata captured in the Methodology section of `CONSOLIDATED-REPORT.md`: agents used, lenses applied, artifact path, date. No separate log files.

## File Organization

```
skills/red-team/
├── SKILL.md                              # Orchestrator: workflow, lens mapping, critical rules
├── references/
│   ├── security-agent.md                 # Security lens persona prompt
│   ├── assumptions-agent.md              # Assumptions lens persona prompt
│   ├── completeness-agent.md             # Completeness lens persona prompt
│   ├── design-agent.md                   # Design lens persona prompt
│   ├── feasibility-agent.md              # Feasibility lens persona prompt (Phase 2)
│   ├── operational-agent.md              # Operational lens persona prompt (Phase 2)
│   ├── cost-agent.md                     # Cost lens persona prompt (Phase 2)
│   ├── compliance-agent.md               # Compliance lens persona prompt (Phase 2)
│   ├── report-template.md               # Consolidated report structure
│   ├── findings-format.md               # Per-agent findings output format spec
│   ├── persona-resolution.md            # 3-tier persona lookup rules and dynamic template
│   ├── agent-prompt-template.md         # Red-team agent prompt assembly template
│   ├── synthesis-prompt-template.md     # Synthesis agent prompt assembly template
│   └── debate-rules.md                  # Debate mode protocol, green-team persona, status labels
```

Output directory (created per-run):

```
docs/red-team/{slug}-{nn}/
├── security-findings.md                  # Security agent findings
├── assumptions-findings.md               # Assumptions agent findings
├── completeness-findings.md              # Completeness agent findings
├── design-findings.md                    # Design agent findings
└── CONSOLIDATED-REPORT.md               # Synthesized, deduplicated report
```

## Configuration

### Required

| Parameter | Type | Validation | Description |
|-----------|------|------------|-------------|
| `<target>` | string | Must resolve to existing file(s) in repo or conversation context | Artifact to review |

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `--debate` | flag | off | Enable red + green team debate via Agent Teams (Phase 3) |
| `--rounds` | integer | 1 | Number of debate rounds; requires `--debate` (Phase 3) |
| `--auto` | flag | off | Skip approval gate; overridden when >5 agents (Phase 2) |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `CONSOLIDATED-REPORT.md` | Markdown | Synthesized report: executive summary, severity-rated findings, cross-cutting themes, strengths, methodology |
| `{lens}-findings.md` | Markdown | Per-agent findings with persona, assessment summary, individual findings, strengths |
| Terminal summary | Text | Finding counts by severity, overall risk level, report path, suggested next steps |

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | SKILL.md is the orchestrator (not a separate agent) | Keeps architecture simple; orchestration logic is sequential and doesn't benefit from agent isolation. SKILL.md reads files, makes decisions, spawns agents. |
| 2 | Agents write directly to output directory (no temp files) | Eliminates temp file cleanup, ensures findings are always persisted, simplifies the flow. Output directory created before agent spawning. |
| 3 | Per-lens persona prompts in separate files (`references/{lens}-agent.md`) | Progressive disclosure: orchestrator loads only the prompts needed for selected lenses. Easier to maintain and extend individual lenses. Phase 3 adds 3-tier resolution (see #18). |
| 4 | Shared findings format spec in `references/findings-format.md` | Common output structure referenced by all persona prompts. Single source of truth for the findings file format. |
| 5 | Report template in `references/report-template.md` | Keeps SKILL.md lean. Template loaded during synthesis step only. |
| 6 | Static lens-to-artifact mapping table in SKILL.md | Simple, predictable, no external config. Table is small (~10 rows). User override (Phase 2) provides flexibility without changing the table. |
| 7 | Output directory naming: `docs/red-team/{slug}-{nn}/` | Lightweight audit trail via directory naming. No formal run history database. Sequential numbering provides ordering. |
| 8 | Active filtering in synthesis (not preserve-all) | Reduces noise. Weak findings (low evidence, speculative) downgraded or omitted with note. Keeps consolidated report actionable. |
| 9 | Mandatory approval gate at 5+ agents | Cost-awareness checkpoint. Even with `--auto`, spawning 5+ parallel agents requires user confirmation. |
| 10 | Configurable per-agent tool access | Orchestrator assigns tools based on lens type. Security agents may need Bash for verification; analysis-focused agents are read-only. Balances capability with least-privilege. |
| 11 | Opus preferred for sub-agents | Adversarial review benefits from Opus depth. The `model: "opus"` setting is a preference hint to Claude Code; if Opus is unavailable, the best available model is used automatically. No explicit fallback logic needed. |
| 12 | Smart chunking for large artifacts | Orchestrator segments large files by logical boundaries (headings, functions, classes). Each agent gets relevant sections + full-artifact summary. Prevents context overflow. |
| 13 | Markdown-only output format | Simplicity. Reports are human-readable and version-controllable. No JSON or other machine-readable formats. |
| 14 | Confirmation bias prevention via 5 structural safeguards | Adversarial instruction, isolated contexts, structured output, quantified effort, multi-perspective lenses. These are architectural constraints, not optional guidelines. |
| 15 | Agent Teams for debate mode (Phase 3) | Green-team members debate directly with red-team agents via Agent Teams coordination, influencing findings through evidence-based rebuttal rather than producing separate reports. |
| 16 | Debate mode findings carry status labels | Each finding marked as Sustained, Rebutted, or Contested after green-team challenge. Provides transparency on which findings survived adversarial debate. |
| 17 | Synthesis agent dynamically generated (Phase 3) | Synthesis role is fixed and uniform across all runs. No need for persona library lookup -- orchestrator generates the synthesis agent prompt each time. |
| 18 | 3-tier persona resolution hierarchy (Phase 3) | Project override (`.claude/red-team/`) -> bundled (`references/`) -> dynamic generation. Allows teams to customize personas without forking the skill. Mismatch detection prevents accidental cross-wiring. Resolution tier recorded in methodology for transparency. |

## Agent Teams Integration (Debate Mode — Phase 3)

### Coordination Pattern

Debate mode uses Claude Code Agent Teams to coordinate structured adversarial dialogue between red-team and green-team members:

```
Phase 3 Debate Flow:

1. Red-team agents run in parallel (same as default mode)
   → Each writes initial findings to {lens}-findings.md

2. Green-team members spawned via Agent Teams
   → Each paired with one or more red-team agents
   → Green members read the red-team findings
   → Green members prepare evidence-based rebuttals

3. Debate round(s):
   → Green-team presents rebuttals to red-team agents
   → Red-team agents evaluate rebuttals against their evidence
   → Red-team agents update findings: mark as Sustained, Rebutted, or Contested
   → If --rounds > 1: additional debate iterations

4. Red-team agents write final updated findings files
   → New fields: Defense (green-team rebuttal), Status (Sustained/Rebutted/Contested)

5. Synthesis agent reads all final findings
   → CONSOLIDATED-REPORT.md includes debate outcome per finding
```

### Message Flow

- Red-team agents and green-team members communicate via Agent Teams messaging
- Green-team does NOT produce separate report files -- influence is through debate only
- Green-team rebuttals must include evidence (citations, code references, documentation links)
- "I disagree" without evidence is not a valid rebuttal

### Green-Team Persona

Green-team members defend the artifact. Their posture:
- Assume the artifact is well-designed until shown specific evidence of flaws
- Challenge vague or speculative red-team findings
- Provide counter-evidence from the codebase, documentation, or industry best practices
- Acknowledge valid findings rather than reflexively defending

### Activation

```
/red-team my design --debate              # 1 round of debate
/red-team my design --debate --rounds 3   # 3 rounds
```

## Deployment Workflow

### Step-by-step (for users adopting the skill)

1. Copy `skills/red-team/` directory to target project's `skills/` or `.claude/skills/`
2. Verify SKILL.md frontmatter is recognized (skill appears in `/skills` list)
3. Test with a small artifact: `/red-team path/to/small-file.md`
4. Verify output directory created at `docs/red-team/`
5. Review consolidated report for correct structure and evidence-based findings

### Phased Development

| Phase | Features | Milestone |
|-------|----------|-----------|
| 1 (MVP) | F1-F7: Core skill, 4 lenses, parallel agents, orchestrator synthesis, smart chunking | End-to-end red-team of any artifact |
| 2 | F8-F11: 8 lenses, user override, approval gate, per-agent output | Full lens coverage with user control |
| 3 | F12-F14: Synthesis agent, persona resolution, Agent Teams debate | Advanced adversarial validation with structured debate |

**Note:** F12 (Synthesis Agent), F13 (Persona Resolution), and F14 (Debate Mode) are now implemented. All Phase 3 features are complete.

## Dependency Graph

```
[SKILL.md (Orchestrator)]
    ├── resolves persona: [.claude/red-team/{lens}-agent.md] -> [references/{lens}-agent.md] -> dynamic
    ├── reads [references/persona-resolution.md] (resolution rules and dynamic template)
    ├── reads [references/agent-prompt-template.md] (agent prompt assembly)
    ├── reads [references/findings-format.md] (referenced by persona prompts)
    ├── reads [references/report-template.md] (during synthesis)
    ├── reads [references/synthesis-prompt-template.md] (synthesis prompt assembly)
    ├── reads [references/debate-rules.md] (debate protocol, when --debate)
    ├── spawns [Sub-Agent per lens] (parallel, via Agent tool)
    │       └── writes [docs/red-team/{slug}-{nn}/{lens}-findings.md]
    ├── (--debate) coordinates [Green-Team Agents] (via Agent Teams)
    │       └── debates with [Sub-Agent per lens], updates findings with Status
    ├── spawns [Synthesis Agent] (via Agent tool)
    │       ├── reads [docs/red-team/{slug}-{nn}/*-findings.md]
    │       └── writes [docs/red-team/{slug}-{nn}/CONSOLIDATED-REPORT.md]
```

## Out of Scope

| Item | Rationale |
|------|-----------|
| Replace existing skill-specific red-team patterns | Standalone by design; `/spike`, `/occ-skill-refactor`, `/occ-skill-creator` retain their own |
| Automated remediation of findings | Review and reporting only; remediation is a separate workflow |
| CI/CD integration or scheduled runs | On-demand invocation; future enhancement if demand exists |
| URL, clipboard, or piped input sources | Repo files and conversation context only |
| Non-adversarial review modes | Different posture and output; use general code review tools instead |
| Custom user-defined lens types | Future enhancement; current lens set covers common needs |
