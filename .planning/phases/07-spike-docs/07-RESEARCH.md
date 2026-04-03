# Phase 7: /spike + Docs - Research

**Researched:** 2026-04-03
**Domain:** Claude Code skill authoring (SKILL.md flow controller + reference files + detail docs)
**Confidence:** HIGH

## Summary

Phase 7 delivers two workstreams: (1) the `/spike` adversarial research skill and (2) complete documentation for all 7 pipeline skills. Both workstreams follow well-established patterns from Phases 1-6 -- no new technology or architectural exploration is needed.

The `/spike` skill follows the exact SKILL.md flow controller pattern used by `/build`, `/plan`, `/design`, and `/milestone`. It is the first skill to use sequential sub-agent spawning (research agent then red-team agent), but the sub-agent pattern itself is already proven in `/design` (Gate 2 architecture scan) and `/build` (codebase refresh). The primary novelty is the adversarial two-agent flow and the follow-up append mode.

Documentation is straightforward: create `docs/skills/spike.md` from the build.md template, add a SKILLS.md catalog row, and verify all 6 existing SKILL.md files already have `disable-model-invocation: true` (verified: they do).

**Primary recommendation:** Follow established skill patterns exactly. The spike SKILL.md should be ~150-180 lines as a flow controller loading reference files. The research and red-team agents use the `Agent` tool with explicit prompts and constrained tooling.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Sequential agent flow -- research agent completes first, then red-team agent reviews findings
- **D-02:** Final artifact only -- both agents run autonomously without user checkpoints
- **D-03:** Red-team has full tooling -- web search, docs, codebase access. Can independently verify claims
- **D-04:** Comprehensive red-team scope -- challenges factual errors, missing alternatives, flawed reasoning, unverified assumptions, version/compatibility issues
- **D-05:** Question + tooling list as inputs
- **D-06:** Prerequisite: progress.txt must exist
- **D-07:** State lifecycle: add `[ ]` entry on creation, mark `[x]` resolved on user signal
- **D-08:** Follow-up mode re-runs research + red-team on follow-up question, appends to Follow-Up Log, offers resolution
- **D-09:** Fixed sections per SPIKE-03 -- Question, Available Tooling, Methodology, Findings, Red-Team Assessment, Recommendation, Status, Follow-Up Log
- **D-10:** Red-Team Assessment is an equal peer section at the same level as Findings
- **D-11:** Recommendation contains a clear pick with rationale
- **D-12:** Follow-Up Log uses dated entries with full findings + red-team assessment per entry
- **D-13:** Create /spike docs from scratch + verify existing 6 skill docs
- **D-14:** `/project` router's SKILL.md already exists at `skills/project/SKILL.md`. Phase 7 creates `skills/project/spike/SKILL.md`. Verify all 7 have `disable-model-invocation: true`
- **D-15:** Spike detail doc follows same structure as other skill detail docs

### Claude's Discretion
- Research agent prompt design and methodology approach
- Red-team agent prompt design and challenge structure
- Exact sub-agent tooling configuration
- Topic slug generation for file naming (`docs/spikes/<topic>.md`)
- How to detect follow-up mode (existing spike file check)
- Spike section within `progress.txt` format details
- Internal session and agent orchestration approach
- How to handle edge cases (no tooling listed, ambiguous questions)
- Documentation audit verification approach and gap-filling strategy

### Deferred Ideas (OUT OF SCOPE)
None
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SPIKE-01 | `/spike` accepts research question + tooling list, spawns research sub-agent | Agent tool pattern from /design Gate 2 scan; D-01, D-05 lock the approach |
| SPIKE-02 | `/spike` spawns red-team sub-agent to validate findings | Sequential agent flow per D-01; red-team scope per D-04 |
| SPIKE-03 | Produces `docs/spikes/<topic>.md` with fixed sections | Section structure defined in DESIGN.md DD-14 artifact spec; D-09 locks sections |
| SPIKE-04 | Adds spike entry to `progress.txt` under `## Spikes` | Spike section format defined in progress-format.md; D-07 locks lifecycle |
| SPIKE-05 | Follow-up mode appends to Follow-Up Log | D-08, D-12 lock the append behavior with dated entries |
| SPIKE-06 | Marks spike `[x]` resolved on user signal | D-07 locks the resolution mechanism |
| DOCS-01 | Each skill has detail doc at `docs/skills/<name>.md` | 6 of 7 exist; only spike.md needs creation. Verified via filesystem |
| DOCS-02 | `docs/SKILLS.md` catalog has row for each skill | `/spike` row missing; all others present. Pattern established |
| DOCS-03 | Each skill directory has SKILL.md with `disable-model-invocation: true` | 6 of 7 verified; spike/SKILL.md is created as part of SPIKE-01 |
</phase_requirements>

## Architecture Patterns

### Skill File Structure (established pattern)

```
skills/project/spike/
+-- SKILL.md                    # Flow controller (~150-180 lines)
+-- references/
    +-- research-agent.md       # Research sub-agent prompt and methodology spec
    +-- redteam-agent.md        # Red-team sub-agent prompt and challenge spec
    +-- spike-format.md         # Spike artifact template and section spec
    +-- progress-format.md      # State file format spec (own copy per D-04)
```

### Pattern 1: SKILL.md as Flow Controller

**What:** SKILL.md is a concise (~150-200 line) flow controller that loads reference files at each step rather than inlining all logic.
**When to use:** Every skill in the project pipeline follows this pattern.
**Established in:** /build (144 lines), /design (143 lines), /plan (160 lines), /milestone (163 lines), /define (197 lines).

Key structural elements:
1. YAML frontmatter with `disable-model-invocation: true`
2. Rules section (read fresh, interactive prompts, no auto-dispatch)
3. Prerequisites section (progress.txt must exist)
4. Numbered steps that reference external files via `Read references/<name>.md`
5. Error handling section
6. Completion report template

### Pattern 2: Sequential Sub-Agent Spawning

**What:** Use the `Agent` tool to spawn sub-agents that run autonomously, write findings to a temp file, then the parent skill reads findings and continues.
**When to use:** When the skill needs deep investigation or analysis that benefits from a focused context.
**Established in:** /design (Gate 2 architecture scan writes to `/tmp/architecture-scan-findings.md`), /build (codebase refresh sub-agent).

For `/spike`, two sequential agents:
1. Research agent writes to `/tmp/spike-research-findings.md`
2. Red-team agent reads research findings and writes to `/tmp/spike-redteam-findings.md`
3. Parent SKILL.md assembles both into the final spike artifact

### Pattern 3: Follow-Up Mode Detection

**What:** Detect whether the user is invoking the skill on an existing artifact (follow-up) vs. new invocation.
**Established in:** /design (refresh mode detection), /milestone (revision mode detection), /plan (re-plan mode detection).

For `/spike`:
- User provides a topic that matches an existing `docs/spikes/<topic>.md` file -> follow-up mode
- New topic -> new spike mode
- Detection should check filesystem, consistent with other skills

### Pattern 4: State File Updates

**What:** Write spike entries to `progress.txt` under the existing `## Spikes` section.
**Format:** Already defined in progress-format.md:
```
[ ] Spike Name  docs/spikes/<topic>.md
```
Resolved format:
```
[x] Spike Name  docs/spikes/<topic>.md  Resolved: YYYY-MM-DD
```

### Pattern 5: Detail Doc Structure

**What:** Each skill has a detail doc at `docs/skills/<name>.md` following a consistent structure.
**Established in:** All 6 existing skill detail docs (project.md, define.md, design.md, milestone.md, plan.md, build.md).

Structure:
```markdown
# /<name>

**Source:** `skills/project/<name>/`
**Command:** `/<name>`
**Activation:** Manual only (`disable-model-invocation: true`)

## Purpose
## When to Use
## When NOT to Use
## Behavior
### 1. [Step name]
### 2. [Step name]
...
## Artifacts
## Skill Files
## Related Skills
```

### Anti-Patterns to Avoid
- **Merging research and red-team perspectives:** D-10 requires Red-Team Assessment as an equal peer section. Never fold red-team findings into the Findings section.
- **Inlining agent prompts in SKILL.md:** Agent prompts belong in reference files to keep SKILL.md under 200 lines.
- **Cross-directory reference reads:** Per D-04, each skill maintains its own copy of shared references (progress-format.md).
- **Auto-dispatching next skill:** Per established rules, tell user what to run next but never auto-invoke.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sub-agent execution | Custom agent orchestration | Claude Code `Agent` tool | Built-in tool handles context isolation, tool access, and return values |
| Topic slug generation | Complex slug algorithm | Simple kebab-case conversion (lowercase, spaces to hyphens, strip special chars) | Consistent with milestone and feature slug patterns already in use |
| Spike artifact templating | Dynamic template engine | Static markdown template in `references/spike-format.md` or `assets/spike-template.md` | All other skills use static templates loaded from assets/ or inlined in reference files |
| State file parsing | Custom parser | Read and regex match against known patterns | All skills use simple text matching on progress.txt; no parser needed |

## Common Pitfalls

### Pitfall 1: Red-Team Agent Confirmation Bias
**What goes wrong:** Red-team agent agrees with research findings instead of challenging them.
**Why it happens:** If the red-team agent prompt is too deferential or receives findings as authoritative.
**How to avoid:** Red-team agent prompt must explicitly instruct adversarial posture -- "your job is to find flaws, not confirm." Give it independent tool access (D-03) so it can verify claims.
**Warning signs:** Red-Team Assessment section that reads like a summary rather than a critique.

### Pitfall 2: Follow-Up Overwrites Original Findings
**What goes wrong:** Re-invoking `/spike` on the same topic replaces the original artifact.
**Why it happens:** Writing to the same file path without checking for existing content.
**How to avoid:** Follow-up mode must READ the existing spike artifact, APPEND to the Follow-Up Log section, and preserve all original content. D-08 and D-12 are explicit about this.
**Warning signs:** Spike artifact with only one entry when follow-ups occurred.

### Pitfall 3: Missing progress.txt Spikes Section
**What goes wrong:** Spike entry write fails because `## Spikes` section doesn't exist or uses different format.
**Why it happens:** The bootstrap template includes `## Spikes` with `(none yet)` placeholder, but edge cases exist.
**How to avoid:** When writing spike entry, check if `(none yet)` placeholder exists and replace it. If section missing entirely, create it.
**Warning signs:** Spike artifact exists but no corresponding progress.txt entry.

### Pitfall 4: SKILL.md Exceeding 200 Lines
**What goes wrong:** Agent prompts and spike template inlined in SKILL.md push it well over the 200-line soft limit.
**Why it happens:** Spike has more logic than most skills (two agents, follow-up mode, resolution).
**How to avoid:** Decompose into reference files: research-agent.md, redteam-agent.md, spike-format.md. SKILL.md stays as flow controller.
**Warning signs:** SKILL.md growing past 180 lines during writing.

### Pitfall 5: Documentation Audit Missing Gaps
**What goes wrong:** Claiming DOCS-01/02/03 compliance without actually verifying each file.
**Why it happens:** Assuming all existing docs are correct because they were created in prior phases.
**How to avoid:** Explicitly read and verify each of the 7 detail docs, 7 SKILLS.md rows, and 7 SKILL.md frontmatter entries.
**Warning signs:** Skipping verification with "already done in Phase X."

## Code Examples

### SKILL.md Frontmatter Pattern
```yaml
---
name: spike
description: >
  Adversarial technical research with red-team validation. Spawns research
  and red-team sub-agents to investigate technical questions and produce
  structured spike artifacts. Supports follow-up research on existing spikes.
  Use when investigating technical feasibility, comparing approaches, or
  validating assumptions before committing to a plan.
disable-model-invocation: true
---
```
Source: Pattern from skills/project/build/SKILL.md frontmatter

### Agent Tool Spawn Pattern (from /design Gate 2)
```
Spawn a sub-agent using the Agent tool to perform [task description].
The agent [reads/writes] [specific artifacts].

Agent Prompt:
Instruct the agent to:
1. [Step 1]
2. [Step 2]
3. Write structured findings to /tmp/[output-file].md

Agent Tool Access:
The agent uses only: [list of tools]
```
Source: skills/project/design/references/gate-2-design.md

### Progress.txt Spike Entry Format
```
## Spikes

[ ] WebSocket Auth Compatibility  docs/spikes/websocket-auth.md
[x] SQLite to Postgres Migration  docs/spikes/sqlite-postgres.md  Resolved: 2026-03-17
```
Source: skills/project/build/references/progress-format.md (Spikes Section Format)

### Spike Artifact Sections (from DESIGN.md DD-14)
```markdown
# Spike: <Topic Name>

## Question
[The specific technical question or hypothesis]

## Available Tooling
[What tools were provided for the research]

## Methodology
[What the research agent investigated and how]

## Findings
[Research agent's discoveries, organized by sub-question or theme]

## Red-Team Assessment
[Validation agent's critique: errors, alternatives missed, unsupported claims, gaps]

## Recommendation
[Conclusion incorporating both findings and red-team feedback; actionable]

## Status
open | resolved

## Follow-Up Log
[Chronological entries, each with dated findings + red-team assessment]
```
Source: DESIGN.md DD-14 artifact specification

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single-pass research | Adversarial research + red-team | DD-14 (project design) | Higher quality findings, catches confirmation bias |
| Inline all skill logic | SKILL.md flow controller + reference files | Phase 1 onwards | Skills stay under 200 lines, reference files are self-contained |
| Shared references across skills | Own copy per skill (D-04) | Phase 2 onwards | No cross-directory reads, each skill is self-contained |

## Open Questions

1. **Research agent tool access scope**
   - What we know: D-03 says red-team gets full tooling (web search, docs, codebase). Research agent also needs tooling per SPIKE-01.
   - What's unclear: Exact tool list for research agent vs. red-team agent. Both likely need Read, Bash, Glob, WebSearch, WebFetch.
   - Recommendation: Give both agents the same broad tool access. The reference files should specify which tools each agent uses. This is Claude's discretion per CONTEXT.md.

2. **Topic slug collision handling**
   - What we know: Topics map to `docs/spikes/<topic>.md`. Follow-up mode detects existing files.
   - What's unclear: What if user provides a different question but the slug collides with an existing spike?
   - Recommendation: Check for existing file, ask user to confirm follow-up vs. rename. Edge case -- handle in reference file.

3. **AskUserQuestion for resolution signal**
   - What we know: D-08 says "offers resolution after each follow-up." D-07 says mark `[x]` when user signals.
   - What's unclear: Exact UX flow for resolution offer.
   - Recommendation: After each follow-up completes, use AskUserQuestion with options like "Resolved" / "Follow-up" / "Done for now". This is Claude's discretion.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual verification (skill produces markdown artifacts, no executable code) |
| Config file | none |
| Quick run command | Manual: invoke `/spike` with a test question |
| Full suite command | Manual: verify all 7 skill docs, SKILLS.md rows, SKILL.md frontmatter |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SPIKE-01 | Accepts question + tooling, spawns research agent | manual-only | Invoke `/spike` with test question | N/A |
| SPIKE-02 | Spawns red-team agent to validate | manual-only | Verify red-team section in output artifact | N/A |
| SPIKE-03 | Produces spike artifact with fixed sections | manual-only | Check `docs/spikes/<topic>.md` has all 8 sections | N/A |
| SPIKE-04 | Adds entry to progress.txt Spikes section | manual-only | Check progress.txt after spike creation | N/A |
| SPIKE-05 | Follow-up appends to Follow-Up Log | manual-only | Invoke `/spike` on existing topic, verify append | N/A |
| SPIKE-06 | Marks `[x]` resolved on user signal | manual-only | Signal resolution, check progress.txt | N/A |
| DOCS-01 | Each skill has detail doc | smoke | `ls docs/skills/{project,define,design,milestone,plan,build,spike}.md` | 6 of 7 exist |
| DOCS-02 | SKILLS.md has row per skill | smoke | `grep -c '/spike\|/project\|/define\|/design\|/milestone\|/plan\|/build' docs/SKILLS.md` | Partial |
| DOCS-03 | Each SKILL.md has disable-model-invocation | smoke | `grep -rl 'disable-model-invocation: true' skills/project/*/SKILL.md skills/project/SKILL.md` | 6 of 7 exist |

### Sampling Rate
- **Per task commit:** Verify created/modified files exist and have expected structure
- **Per wave merge:** Check all 7 skill doc triplets (SKILL.md + detail doc + catalog row)
- **Phase gate:** Full manual verification of all success criteria

### Wave 0 Gaps
None -- this phase produces markdown skill files, not executable code. Verification is structural (file exists, has expected sections) rather than test-based.

## Sources

### Primary (HIGH confidence)
- `skills/project/DESIGN.md` DD-14 -- spike skill design decisions, artifact spec, pipeline integration
- `skills/project/build/SKILL.md` -- flow controller pattern (144 lines), most recent skill
- `skills/project/build/references/progress-format.md` -- spike entry format in progress.txt
- `skills/project/design/references/gate-2-design.md` -- sub-agent spawn pattern
- `docs/skills/build.md` -- detail doc pattern
- `docs/SKILLS.md` -- catalog table pattern
- All 6 existing `skills/project/*/SKILL.md` -- verified `disable-model-invocation: true`

### Secondary (MEDIUM confidence)
- None needed -- all patterns are internal to this codebase

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no external libraries; pure markdown skill files following established patterns
- Architecture: HIGH -- 6 prior skills establish the exact pattern; spike adds sequential agents (already proven in /design)
- Pitfalls: HIGH -- pitfalls are derived from concrete patterns in the codebase and locked decisions

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (stable -- internal patterns, no external dependencies)
