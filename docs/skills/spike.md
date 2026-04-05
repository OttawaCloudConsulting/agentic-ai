# /spike

**Source:** `skills/project/spike/`
**Command:** `/spike`
**Activation:** Manual only (`disable-model-invocation: true`) -- invoked via slash command. Not auto-triggered by conversational phrases.

## Purpose

Adversarial technical research skill that investigates technical questions using sequential research and red-team agents. Accepts a research question and list of available tooling, produces a structured spike artifact at `docs/spikes/<topic>.md` with both research findings and independent red-team validation. The two perspectives are presented as equal peer sections -- never merged or suppressed. Supports follow-up research on existing spikes with dated append entries. Tracks spike lifecycle in `progress.txt` (open/resolved).

## When to Use

- Investigating technical feasibility before committing to an approach
- Comparing libraries, frameworks, or tools for a specific use case
- Validating technical assumptions with adversarial review
- Researching integration approaches for external services
- Any technical question that benefits from a devil's advocate perspective

## When NOT to Use

- When you want to check project status or get routing (use `/project`)
- When you want to define project scope or create a PRD (use `/define`)
- When you want to design system architecture (use `/design`)
- When you want to define milestones and features (use `/milestone`)
- When you want to plan a feature (use `/plan`)
- When you want to implement a feature (use `/build`)

## Behavior

### 1. Input Gathering and Mode Detection

Reads `progress.txt` from the project root. Gathers the user's research question and available tooling list per SPIKE-01. If provided in the invocation message, uses them directly; otherwise prompts with `AskUserQuestion`. Generates a topic slug (kebab-case) and checks if `docs/spikes/<slug>.md` exists. If it exists, enters follow-up mode. If not, enters new spike mode. Slug collisions prompt the user to choose follow-up or new spike with a different name.

### 2. Research Agent

Spawns a sub-agent to investigate the research question. The agent uses web search (WebFetch), codebase tools (Read, Glob, Grep, Bash), and documentation to research each tool in the available tooling list. Produces structured findings including methodology, per-tool analysis (version, compatibility, documentation, community activity, known issues, integration), comparison matrix, and findings summary. Writes results to `/tmp/spike-research-findings.md`.

### 3. Red-Team Agent

After the research agent completes, spawns a second sub-agent with an explicitly adversarial posture. The red-team agent reads the research findings and independently verifies claims using its own tool access (same tools as research agent per D-03). Challenges factual errors, missing alternatives, flawed reasoning, unverified assumptions, and version/compatibility issues. Quantifies verification effort (N of M claims checked). Writes structured critique to `/tmp/spike-redteam-findings.md`.

### 4. Artifact Assembly

Assembles the final spike artifact from both agent outputs. The artifact has 8 fixed sections: Question, Available Tooling, Methodology, Findings, Red-Team Assessment, Recommendation, Status, Follow-Up Log. The Red-Team Assessment is an equal peer section to Findings -- the two perspectives are never merged. The Recommendation states a clear pick with rationale, incorporating red-team feedback and noting remaining risks. Adds a `[ ]` entry to `progress.txt` under the `## Spikes` section.

### 5. Follow-Up Mode

When invoked on an existing spike topic, re-runs the research and red-team agents on the follow-up question. Appends a dated entry to the Follow-Up Log with full findings, red-team assessment, and updated recommendation. Preserves all original content -- never overwrites findings, red-team assessment, or prior follow-ups. After each follow-up, offers resolution: Resolved (marks spike `[x]` in progress.txt), Follow-up (continues), or Done (leaves open).

### 6. Resolution

When the user signals resolution, updates the spike artifact status from `open` to `resolved` and marks the `progress.txt` entry `[x]` with a resolution date.

## Artifacts

| Artifact | Path | Created By |
|----------|------|------------|
| Spike artifact | `docs/spikes/<topic>.md` | /spike (new spike or follow-up append) |
| progress.txt | `progress.txt` | /spike (adds spike entry, marks resolved) |

## Skill Files

```
skills/project/spike/
+-- SKILL.md                              # Flow controller (~159 lines)
+-- references/
    +-- research-agent.md                 # Research sub-agent prompt and methodology spec
    +-- redteam-agent.md                  # Red-team sub-agent prompt and challenge spec
    +-- spike-format.md                   # Spike artifact template and section spec
    +-- progress-format.md                # State file format spec (own copy per D-04)
```

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `/project` | Reads `progress.txt` for spike status; routes users to `/spike` |
| `/milestone` | Reads spike artifacts when referenced in milestone planning |
| `/design` | Spike findings may inform architecture decisions |
| `/plan` | Spike findings may inform feature planning |
