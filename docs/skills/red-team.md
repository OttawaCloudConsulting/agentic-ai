# /red-team

**Source:** `skills/red-team/`
**Command:** `/red-team`
**Activation:** Manual only (`disable-model-invocation: true`) -- invoked via slash command. Not auto-triggered by conversational phrases.

## Purpose

Adversarial review skill for any artifact -- code, infrastructure, architecture docs, PRDs, or proposals. Spawns parallel sub-agents (Opus), each reviewing through a different adversarial lens, plus a dedicated synthesis agent that consolidates all findings into a single report under `docs/red-team/{slug}-{nn}/`. Findings are evidence-based and quantified: every finding cites line numbers or quoted text, empty categories state what was examined, and hedged findings ("might", "perhaps") are discarded. Supports an optional `--debate` mode where green-team defenders challenge findings before synthesis.

## When to Use

- Red-teaming a design, PRD, proposal, or architecture document before committing to it
- Adversarially reviewing code or infrastructure (Terraform, CDK, CloudFormation) for flaws, gaps, and risks
- When asked to "find holes in", "challenge my design", or "what could go wrong"

## When NOT to Use

- General code review, proofreading, or style feedback (non-adversarial review)
- Technical research questions (use `/spike`, which embeds its own red-team pass)
- Complexity/YAGNI gating of a diff or plan (use `/over-engineering-review`)

## Behavior

### 1. Target Resolution

Parses the invocation argument as an explicit file path, glob pattern, or natural language reference ("the PRD", "my design"); with no argument, resolves from conversation context. Missing paths, empty globs, and ambiguous references trigger `AskUserQuestion` with likely alternatives. Globs matching more than 10 files require confirmation. Multi-file targets are concatenated with `=== path ===` separators. Validates that at least one non-empty file was read before proceeding.

### 2. Classification and Lens Selection

Classifies the artifact type (Code, Infrastructure, Architecture/Design, PRD/Proposal, Other) using three signals in priority order: file extension/path, content structure, and user hint -- the user hint is the tiebreaker and authoritative when the user explicitly names a type. The type maps to 2-3 default lenses (e.g., Code gets Security, Design, Completeness; PRD gets Assumptions, Completeness, Feasibility). The user can override with explicit lens selection or exclusion. All 8 lenses: Security, Assumptions, Completeness, Design, Feasibility, Operational, Cost, Compliance. The classification and selected lenses are displayed before agents spawn; low-confidence classifications are flagged for correction. Artifacts over 1500 lines are chunked into labeled sections with a full-artifact summary per `references/chunking-rules.md`.

### 3. Approval Gate and Agent Spawn

Derives the output path `docs/red-team/{slug}-{nn}/` (kebab-case artifact name plus incrementing run number) and presents the proposed agent team via `AskUserQuestion` (Approve / Modify / Cancel). Passing `--auto` skips the gate only when fewer than 5 agents are selected -- at 5+ the gate is mandatory as a cost checkpoint. Each lens persona resolves through a 3-tier hierarchy: project override (`.claude/red-team/{lens}-agent.md`), bundled persona (`references/{lens}-agent.md`), then dynamic generation. All agents spawn in parallel in a single message, model `opus`, each writing `{lens}-findings.md` to the run directory. Security agents additionally get `Bash` for verification. Output is then verified for structural compliance against `references/findings-format.md` and recorded Pass/Partial/Fail per agent.

### 4. Debate Phase (--debate only)

When `--debate` is passed, spawns one green-team defender per lens (parallel, Opus) that sends evidence-based rebuttals to its paired red-team agent via Agent Teams messaging. Red-team agents assign each finding a status -- Sustained, Rebutted, or Contested -- and rewrite their findings files with Defense and Status fields. Default 1 round; `--rounds N` runs up to 5. Failed green-team agents or communication failures degrade gracefully: affected findings are marked Sustained and the fallback is noted in the methodology.

### 5. Synthesis

Spawns a single dynamically generated synthesis agent (Opus) after all red-team agents complete. It receives all findings files, the report template from `references/report-template.md`, agent compliance results, and run metadata, and writes `CONSOLIDATED-REPORT.md` to the run directory. The report is verified to contain an Executive Summary, Methodology, and total findings count; if the write fails, the report content is displayed for manual save. Partial agent failures do not block synthesis -- only a total failure aborts.

### 6. Completion Summary

Displays the artifact, overall risk rating (Critical/High/Medium/Low), finding counts by severity (plus Sustained/Rebutted/Contested counts in debate mode), the report path, and suggested next steps based on findings.

## Artifacts

| Artifact | Path | Created By |
|----------|------|------------|
| Per-lens findings | `docs/red-team/{slug}-{nn}/{lens}-findings.md` | Red-team agents (updated with Defense/Status in debate mode) |
| Consolidated report | `docs/red-team/{slug}-{nn}/CONSOLIDATED-REPORT.md` | Synthesis agent |

## Skill Files

```
skills/red-team/
+-- SKILL.md                              # Flow controller (5 steps + error handling)
+-- CONCEPT.md                            # Design concept
+-- MVP.md                                # MVP scope
+-- references/
    +-- agent-prompt-template.md          # Red-team agent prompt assembly template
    +-- {lens}-agent.md                   # 8 bundled personas: security, assumptions, completeness, design, feasibility, operational, cost, compliance
    +-- chunking-rules.md                 # Large-artifact splitting, labeling, and section assignment
    +-- debate-rules.md                   # Green-team protocol, personas, and status labels
    +-- findings-format.md                # Structured findings output spec and compliance checklist
    +-- persona-resolution.md             # Dynamic persona generation and mismatch detection
    +-- report-template.md                # Consolidated report structure and synthesis rules
    +-- synthesis-prompt-template.md      # Synthesis agent prompt assembly template
```

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `/spike` | Runs its own embedded red-team pass on research findings; use `/spike` for research questions, `/red-team` for existing artifacts |
| `/over-engineering-review` | Complementary review focused on complexity and YAGNI/KISS, not adversarial risk finding |
