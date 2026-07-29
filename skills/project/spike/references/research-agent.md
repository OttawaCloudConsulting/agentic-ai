# Research Agent Specification

Spawned by `/spike` SKILL.md to investigate a user-defined research question using available tooling. The research agent runs first in the sequential two-agent flow (D-01), performing deep investigation and writing structured findings to a temp file for red-team review. The agent runs autonomously without user checkpoints (D-02).

## Input

The research agent receives two inputs from the parent SKILL.md:

- **`research_question`** -- the user's specific technical question or hypothesis (verbatim from SPIKE-01)
- **`available_tooling`** -- list of tools, libraries, or approaches to evaluate (verbatim from SPIKE-01)

## Agent Prompt

Instruct the agent to:

1. **Read the research question and available tooling list** provided in the agent prompt. Restate the question in your own words to confirm understanding.

2. **Develop a methodology:** Break the question into sub-questions that need investigation. Identify what evidence would answer each sub-question. Document your methodology before beginning research.

3. **For each tool/library in the available tooling list, investigate:**
   - Current version and release cadence
   - Compatibility with the project's existing stack (check package.json, go.mod, Cargo.toml, or equivalent)
   - Documentation quality and completeness
   - Community activity (recent commits, open issues, maintenance status)
   - Known issues, limitations, or breaking changes
   - API surface and ease of integration

4. **Use web search** (WebFetch) for:
   - Official documentation and API references
   - Release notes and changelogs
   - Compatibility matrices and migration guides
   - Community discussions about known issues

5. **Use codebase tools** (Read, Glob, Grep, Bash) to:
   - Check existing project patterns that may constrain tool choices
   - Identify current dependencies and version constraints
   - Find existing usage of related tools or patterns
   - Understand integration points where the evaluated tools would connect

6. **Write structured findings** to `${TMPDIR:-/tmp}/spike-<slug>-research-findings.md` with these sections:

   ```
   # Research Findings

   ## Question Restated
   [Your interpretation of the research question]

   ## Methodology
   [Sub-questions identified, evidence sought, approach taken]

   ## Per-Tool Analysis
   ### [Tool/Library Name]
   - Version: [current version]
   - Compatibility: [with project stack]
   - Documentation: [quality assessment]
   - Community: [activity level]
   - Known Issues: [limitations, breaking changes]
   - Integration: [how it fits with existing patterns]

   ### [Next Tool/Library]
   ...

   ## Comparison Matrix
   | Criterion | Tool A | Tool B | ... |
   |-----------|--------|--------|-----|
   | [criterion] | [rating] | [rating] | ... |

   ## Findings Summary
   [Key discoveries, clear patterns, strongest candidates]

   ## Open Questions
   [What remains uncertain, what needs further investigation]
   ```

   Note: The Comparison Matrix section is included only when multiple tools are being compared. Omit it for single-tool investigations.

## Agent Tool Access

The agent uses: `Read`, `Bash`, `Glob`, `Grep`, `WebFetch`.

These tools allow documentation lookup via web search, codebase scanning for existing patterns and constraints, and version checking via package manifests and CLI commands.

## Output

The agent writes its findings to `${TMPDIR:-/tmp}/spike-<slug>-research-findings.md`. The parent SKILL.md reads this file after agent completion and uses it to populate the Methodology and Findings sections of the spike artifact.

## Edge Cases

### No tooling listed

When the user provides a research question but no specific tools or libraries to evaluate:

- Skip the Per-Tool Analysis and Comparison Matrix sections
- Research the question broadly, investigating approaches, patterns, and techniques rather than specific tools
- The Findings Summary should address the question directly with evidence gathered

### Ambiguous question

When the research question is vague or could be interpreted multiple ways:

- Restate the question with the agent's interpretation in the Question Restated section
- Proceed with the stated interpretation
- Note alternative interpretations in Open Questions for the user to clarify if needed

### Web search unavailable

When WebFetch is unavailable or returns errors:

- Fall back to codebase analysis and the agent's documented knowledge
- Note in the Methodology section that web search was unavailable
- Clearly mark which findings are based on codebase evidence vs. documented knowledge
- Flag version-specific claims as potentially stale in Open Questions
