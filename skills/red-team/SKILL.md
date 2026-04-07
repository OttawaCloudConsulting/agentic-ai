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

# /red-team — Adversarial Review

Spawn parallel adversarial sub-agents to find flaws, gaps, and risks in any artifact.
Each agent reviews through a different lens and writes structured, evidence-based findings.
A dedicated synthesis agent consolidates findings into a consolidated report.

## Rules

- **Evidence over assumption.** Every finding must cite specific evidence -- line numbers,
  quoted text, or structural observations. "This might be a problem" is not a finding.
- **No lazy "looks good."** Empty finding categories must state:
  "No issues found after examining N items: {list}."
- **Adversarial posture.** Each agent's job is to find flaws, not confirm quality.
- **Isolated contexts.** Each sub-agent runs as a separate Agent tool invocation.
  No shared reasoning between agents.
- **Quantified effort.** Assessment summaries require counts -- "Checked 8 interfaces,
  found 2 with missing error handling" not "some interfaces lack error handling."
- **No hedging.** Findings must not use "might", "could possibly", "perhaps" as primary
  evidence. State what is wrong concretely or discard the finding.
- **Structural compliance.** Agent output is validated against the checklist in
  `references/findings-format.md`. Non-compliant output is flagged in the report.

## Step 1 — Resolve Target Artifact

Parse the user's invocation to identify and read the target artifact. The target may be
an explicit file path, a glob pattern, a natural language reference, or a combination.

### 1a. Determine target type

Examine the argument(s) after `/red-team`:

- **Explicit file path** (contains `/`, `.`, or looks like a path): proceed to 1b.
- **Glob pattern** (contains `*`, `**`, or `?`): proceed to 1c.
- **Natural language** (e.g., "my design", "the PRD", "the code we just wrote"): proceed to 1d.
- **No argument**: proceed to 1d (resolve from conversation context).

### 1b. Resolve explicit file path

Use the `Read` tool to read the file. Resolve relative paths from the project root.

- If the file exists, store its content as the artifact. Record the path for later use.
- If the file does not exist, report the exact path that failed and use `AskUserQuestion`
  to ask the user to provide the correct path. Offer 2-3 likely alternatives if they
  can be inferred (e.g., similar filenames via `Glob`).

### 1c. Resolve glob pattern

Use the `Glob` tool to expand the pattern. Then read all matched files with `Read`.

- If no files match, report the pattern that matched nothing and ask the user to clarify.
- If more than 10 files match, use `AskUserQuestion` to confirm the user wants all of
  them reviewed, or to narrow the scope.

### 1d. Resolve natural language reference

Scan the conversation context for the most recent artifact matching the user's description:

1. Check files the user explicitly mentioned, read, edited, or created in this session.
2. Match the user's description to those files (e.g., "the PRD" → a file with PRD-like
   content, "my design" → a recently discussed design document).
3. If exactly one file matches, read it with `Read` and proceed.
4. If multiple candidates match, use `AskUserQuestion` to present 2-3 options and ask
   the user to select one.
5. If no candidates match, use `AskUserQuestion` to ask the user to specify a file path.

### 1e. Multi-file concatenation

When the target spans multiple files (glob expansion, explicit list, or comma-separated paths),
read each file with `Read` and concatenate with `=== path/to/file.ext ===` separators.
Record all paths for the report methodology section.

### 1f. Validation

Before proceeding to Step 2, confirm at least one file was read and content is non-empty.
Record the resolved path(s) and artifact content for subsequent steps.
If validation fails, report what went wrong and ask the user to clarify.

## Step 2 — Classify Artifact and Select Lenses

Determine the artifact type by evaluating three signals in order, then map the type to
adversarial lenses. The goal is a confident classification with 2-3 lenses selected.

### 2a. Signal 1 — File extension and path

Examine the resolved file path(s) from Step 1. Use the strongest signal first:

| Extension / Path Pattern | Artifact Type |
|---|---|
| `.py`, `.ts`, `.js`, `.go`, `.rs`, `.java`, `.rb`, `.c`, `.cpp`, `.cs`, `.sh`, `.bash` | Code |
| `.tf`, `.tfvars`, `.hcl` | Infrastructure |
| Files under `cdk/`, `infra/`, `infrastructure/`, or importing `aws-cdk-lib` | Infrastructure |
| `.yaml`, `.yml` with CloudFormation `AWSTemplateFormatVersion` or `Resources:` keys | Infrastructure |
| `.md`, `.txt`, `.rst` under `docs/`, `design/`, or `architecture/` | Architecture / Design |
| `.md`, `.txt` with filename containing `prd`, `proposal`, `rfc`, `spec` | PRD / Proposal |
| `.json`, `.yaml`, `.toml`, `.ini`, `.env`, `.cfg` | Code (config) |
| No match from above | Defer to Signal 2 |

For multi-file artifacts, use the dominant type. If files span multiple types (e.g., code +
config), classify by the primary files the user referenced. If evenly split, classify as
the broader type (e.g., Code over config).

### 2b. Signal 2 — Content structure

When Signal 1 is ambiguous or produces a generic type, scan the artifact content for
structural indicators:

**Code indicators:**
- Function/method definitions, class declarations, import statements
- Syntax patterns: braces, semicolons, type annotations, decorators
- Shebang lines (`#!/usr/bin/env`)

**Architecture / Design indicators:**
- Headings: "Architecture", "Design", "Component", "System", "Overview", "Diagram"
- Mermaid or ASCII diagrams, component descriptions, data flow narratives
- Design decision tables, ADR format, trade-off analysis

**PRD / Proposal indicators:**
- Headings: "Goals", "Non-Goals", "Requirements", "Acceptance Criteria", "User Stories"
- Feature descriptions, success criteria, stakeholder lists
- Problem statement followed by proposed solution

**Infrastructure indicators:**
- Resource definitions, provider blocks, module declarations
- AWS/GCP/Azure resource names (e.g., `aws_lambda_function`, `google_compute_instance`)
- Stack definitions, construct patterns, template parameters

If content signals contradict the extension signal, prefer the content signal. For example,
a `.md` file containing mostly code blocks is likely a Code artifact, not documentation.

### 2c. Signal 3 — User hint

If the user's invocation included descriptive language, use it to confirm or override
the classification:

| User Language | Suggests |
|---|---|
| "code", "function", "API", "implementation", "module", "service" | Code |
| "design", "architecture", "system design", "component" | Architecture / Design |
| "PRD", "proposal", "RFC", "spec", "requirements", "plan" | PRD / Proposal |
| "infra", "terraform", "CDK", "CloudFormation", "stack", "deployment" | Infrastructure |

The user hint is the weakest signal when other signals agree, but it is the **tiebreaker**
when Signal 1 and Signal 2 conflict. If the user explicitly names an artifact type
(e.g., "red-team my design"), treat that as authoritative.

### 2d. Resolve classification

Apply the three signals to reach a final classification:

1. If all signals agree → use that type. Confidence: high.
2. If two signals agree → use the majority type. Confidence: high.
3. If all three signals disagree → prefer user hint > content structure > extension.
   Confidence: medium.
4. If only one signal is available (e.g., no user hint, generic extension) → use it.
   Confidence: low.

For **low confidence** classifications, note the uncertainty in the display output (Step 2f)
so the user can correct it before agents are spawned.

### 2e. Select lenses

**User override:** If the invocation specifies lenses ("focus on security and cost") use
only those. If it excludes lenses ("skip compliance"), remove from auto-selected set.
Validate against the 8 known lenses; fall back to auto-selection for invalid names.

**Auto-selection** (default when no override) — map artifact type to lenses:

| Artifact Type | Default Lenses |
|---|---|
| Code | Security, Design, Completeness |
| Architecture / Design document | Assumptions, Design, Feasibility |
| PRD / Proposal | Assumptions, Completeness, Feasibility |
| Infrastructure (Terraform, CDK, CloudFormation) | Security, Completeness, Operational |
| Other / Unknown | Assumptions, Completeness |

All 8 lenses: Security, Assumptions, Completeness, Design, Feasibility, Operational,
Cost, Compliance. Personas in `references/{lens}-agent.md`. Verify prompt files exist.

### 2f. Display classification

Present the classification and selected lenses to the user before proceeding:

```
CLASSIFICATION
Target: {path or comma-separated paths}
Artifact type: {type} {(low confidence — correct me if wrong) if confidence is low}
Lenses: {lens1}, {lens2}[, {lens3}] {(user-specified) | (auto-selected)}
```

Proceed to Step 2g (chunking check) before Step 3.

### 2g. Chunk large artifacts

When the artifact exceeds **1500 lines**, split it so each agent receives manageable
sections with full-artifact context. If ≤ 1500 lines, skip to Step 3.

1. **Detect:** Count total lines. If ≤ 1500, set `chunked = false` and skip to Step 3.
2. **Split:** Segment by logical boundaries based on artifact type.
3. **Summarize:** Generate a full-artifact summary (≤ 30 lines) for all agents.
4. **Label:** Each section gets an identifier: `§{name}:{start}-{end}` (e.g., `§auth-middleware:45-120`).
5. **Assign:** Distribute sections to agents (lens-aware when possible).

See `references/chunking-rules.md` for splitting strategies, labeling rules, and
section assignment. When chunked, Step 3f uses the chunked prompt variant.

## Step 3 — Spawn Red-Team Agents

### 3a. Determine output path

Derive the output directory for this run:

1. **Slug:** Take the artifact filename (without extension), convert to kebab-case,
   lowercase. For multi-file artifacts, use the first file's name.
   Examples: `SystemDesign.md` → `system-design`, `auth_api.py` → `auth-api`.

2. **Run number:** Check for existing `docs/red-team/{slug}-*` directories using `Glob`.
   - If none exist, set `{nn}` to `01`.
   - If existing runs found, extract the highest `{nn}` and increment by 1, zero-padded.
   - Example: `system-design-02` exists → next is `system-design-03`.

3. **Full path:** `docs/red-team/{slug}-{nn}/`

### 3b. Approval gate

Present the proposed agent team for user confirmation before spawning.

**Skip rule:** If the user passed `--auto` AND fewer than 5 agents are selected, skip
this step and proceed to 3c. If 5+ agents are selected, the gate is **mandatory**
regardless of `--auto` (cost-awareness checkpoint — Design Decision #9).

Display:

```
PROPOSED AGENT TEAM
Artifact: {path}
Type: {type}
Output: docs/red-team/{slug}-{nn}/
Agents ({count}):
  - {Lens}: {one-line description from persona preamble}
  ...
```

When the gate is mandatory (5+ agents), prepend:
`"NOTE: {count} agents — confirmation required even with --auto."`

Use `AskUserQuestion` with three options:

1. **Approve** — proceed to Step 3c.
2. **Modify** — user specifies lenses to add or remove. Re-run Step 2e with the
   modification, update the agent count, then re-display this gate.
3. **Cancel** — stop the run. Report cancellation and exit.

### 3c. Create output directory

Create the output directory using `Bash`:

```
mkdir -p docs/red-team/{slug}-{nn}
```

Also create `docs/red-team/` if it does not exist (handled by `-p`).

### 3d. Resolve per-lens persona prompts

For each selected lens, resolve its persona prompt using a 3-tier hierarchy:

1. **Project override:** Check `.claude/red-team/{lens}-agent.md` in the project root.
   If it exists and its `## Preamble` section declares an adversarial posture matching
   the lens name, use it. If the file exists but the posture is mismatched (e.g., a
   security persona file that describes a design lens), skip it and fall to tier 2.
2. **Bundled persona:** Read `references/{lens}-agent.md` from the skill directory.
   This is the default for all 8 lenses (Security, Assumptions, Completeness, Design,
   Feasibility, Operational, Cost, Compliance).
3. **Dynamic generation:** If neither tier 1 nor tier 2 produces a valid prompt, generate
   a persona dynamically. See `references/persona-resolution.md` for the generation
   template and mismatch detection rules.

Also read `references/findings-format.md` for the output format specification (shared
across all agents).

Record the resolution tier used per lens (override / bundled / dynamic) for the
methodology section of the consolidated report. If a lens fails all 3 tiers, skip it
and note the failure in the completion summary.

### 3e. Determine per-agent tool access

Each agent receives tools based on its lens type:

- **Security:** `Read`, `Glob`, `Grep`, `Bash` (Bash for verifying security claims)
- **All other lenses:** `Read`, `Glob`, `Grep` (read-only)

### 3f. Spawn agents in parallel

Spawn ALL agents in a **single message** with multiple `Agent` tool calls.

For each agent:

- **Model:** Set `model: "opus"` for maximum adversarial depth.
- **Description:** `"Red-team {lens} review"` (e.g., `"Red-team security review"`).
- **Output path:** Instruct the agent to write findings to:
  `docs/red-team/{slug}-{nn}/{lens}-findings.md`

#### Agent Prompt Assembly

Construct each agent's prompt following the template in `references/agent-prompt-template.md`:
persona preamble + persona section + anti-bias directive + output format + output path +
artifact type + artifact content (or chunked sections). When `--debate` is active, append
the debate mode additions from the template.

### 3g. Verify agent output

After all agents complete, verify each produced valid output:

1. `Glob` for `docs/red-team/{slug}-{nn}/*-findings.md` files.
2. For each lens, confirm findings file exists and is non-empty.
3. Read each file and check structural compliance against `references/findings-format.md`:
   `## Agent Persona` with adversarial posture, `## Assessment Summary` with item count,
   each finding has Severity/Category/Evidence, no empty Evidence placeholders.
4. Record per-agent: **Pass** / **Partial** / **Fail** with persona tier (override/bundled/dynamic).
5. Report compliance in the Methodology section. Partial does not block synthesis.

### 3h. Debate phase (--debate only)

**Skip this step** if the user did not pass `--debate`. Proceed directly to Step 4.

When `--debate` is active, spawn green-team defenders to challenge red-team findings
via Agent Teams. See `references/debate-rules.md` for the full protocol, green-team
persona template, and status label definitions.

**Rounds:** Default 1. If `--rounds N` specified, run N rounds (cap at 5).

#### 3h-i. Spawn green-team agents

Spawn one green-team agent per red-team lens, in parallel (single message with multiple
Agent calls). Each green-team agent receives:

- The dynamically generated green-team persona (see `references/debate-rules.md`)
- The corresponding `{lens}-findings.md` contents
- The artifact content (or summary if chunked)
- **Model:** Set `model: "opus"`.
- **Description:** `"Green-team {lens} defense"`.

Green-team agents communicate rebuttals via Agent Teams messaging to the paired
red-team agent. They do NOT write separate report files.

#### 3h-ii. Debate rounds

For each round:

1. Green-team agents send evidence-based rebuttals to their paired red-team agents.
2. Red-team agents evaluate rebuttals against their original evidence.
3. Red-team agents assign a status to each finding:
   - **Sustained** — red-team evidence holds despite challenge
   - **Rebutted** — green-team provided compelling counter-evidence
   - **Contested** — both sides have valid evidence, no clear winner

If `--rounds > 1`, green-team reads the updated findings and sends follow-up rebuttals.
Red-team agents may change statuses between rounds based on new evidence.

#### 3h-iii. Finalize debate findings

After all rounds complete, red-team agents rewrite their `{lens}-findings.md` files
with two additional fields per finding:

- **Defense:** Summary of green-team rebuttal (or "No rebuttal received")
- **Status:** Sustained | Rebutted | Contested

Verify the updated findings files exist and contain Defense/Status fields. If a
red-team agent fails to update, keep the original findings and mark all as Sustained.

#### 3h-iv. Error handling

| Scenario | Action |
|----------|--------|
| Green-team agent fails | Mark paired findings as Sustained (no defense) |
| Red-team agent fails to respond | Keep original findings, mark Sustained |
| Agent Teams communication fails | Fall back to non-debate, note in methodology |

## Step 4 — Spawn Synthesis Agent

After red-team agents complete, output is verified (Step 3g), and debate concludes
(Step 3h, if active), spawn a dedicated synthesis agent to produce the consolidated
report. The synthesis agent is dynamically generated each run.

### 4a. Collect inputs

1. Use `Glob` to find all `docs/red-team/{slug}-{nn}/*-findings.md` files.
2. Read each findings file with `Read`.
3. Read `references/report-template.md` for the report structure and synthesis rules.
4. Collect the compliance results recorded in Step 3g (pass/partial/fail per agent).

If zero findings files exist (all agents failed), skip to Step 5 and report the failure.
If some agents failed but others produced output, proceed with available findings.

### 4b. Construct synthesis agent prompt

Construct the synthesis agent prompt following `references/synthesis-prompt-template.md`:
role + rules + report template contents + agent compliance results + metadata + output
path + all findings file contents. When `--debate` was active, findings will contain
Defense and Status fields — the template's debate additions apply.

### 4c. Spawn synthesis agent

Spawn a single `Agent` with the constructed prompt:

- **Model:** Set `model: "opus"` for synthesis depth.
- **Description:** `"Red-team synthesis"`.
- **Tools:** `Read`, `Glob`, `Grep`, `Write` (needs Write for the report, Read/Glob/Grep
  to cross-reference the artifact if needed for dedup decisions).

This is a single agent, not parallel — it runs after all red-team agents have completed.

### 4d. Verify report output

After the synthesis agent completes:

1. Use `Read` to confirm `docs/red-team/{slug}-{nn}/CONSOLIDATED-REPORT.md` exists
   and is non-empty.
2. Spot-check: verify the report contains `## Executive Summary`, `## Methodology`,
   and a `**Total findings:**` line.
3. If the write failed or the report is incomplete, display the synthesis agent's
   output to the user and offer to retry or save manually.

## Step 5 — Completion Summary

Display to the user:

```
Red-Team Report Complete
========================
Artifact: {path}
Artifact type: {type}
Overall Risk: {Critical | High | Medium | Low}

Findings: {total} (Critical: N, High: N, Medium: N, Low: N)
{IF DEBATE: Sustained: N, Rebutted: N, Contested: N}
Report: docs/red-team/{slug}-{nn}/CONSOLIDATED-REPORT.md

Suggested next steps:
- {actionable recommendation based on findings}
```

## Error Handling

| Scenario | Action |
|----------|--------|
| Target not found or path invalid | Report error, use `AskUserQuestion` to clarify |
| Artifact type ambiguous | Default to Other/Unknown lenses (Assumptions, Completeness) |
| Sub-agent fails to produce findings | Note which lens failed in report, continue with rest |
| All sub-agents fail | Report the error, offer to retry or ask user for guidance |
| `docs/red-team/` does not exist | Create it automatically |
| Write failure on report | Display report content to user for manual save |
| Debate: green-team agent fails | Mark paired findings as Sustained, continue synthesis |
| Debate: Agent Teams communication fails | Fall back to non-debate mode, note in methodology |
