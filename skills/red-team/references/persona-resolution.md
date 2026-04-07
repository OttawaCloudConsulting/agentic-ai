# Persona Resolution — Detailed Rules

The orchestrator resolves persona prompts using a 3-tier hierarchy. This file documents
the mismatch detection rules and dynamic generation template referenced in SKILL.md Step 3d.

## Tier 1 — Project Override

**Path:** `.claude/red-team/{lens}-agent.md` (relative to project root)

Users can provide custom persona prompts that override the bundled defaults. This allows
teams to tailor adversarial lenses to their domain (e.g., a security persona that focuses
on healthcare compliance, or a cost persona tuned for a specific cloud provider).

### Validation

A project override file is valid if:

1. The file exists and is non-empty.
2. It contains a `## Preamble` section with adversarial posture instructions.
3. It contains a `## Persona` section with a `PERSONA:` line.
4. The `PERSONA:` line references the correct lens name (case-insensitive match).

Example valid `PERSONA:` line for the security lens:
```
PERSONA: Security Reviewer
```

### Mismatch Detection

A file is **mismatched** if it exists but fails validation rule 4 — the `PERSONA:` line
does not contain the expected lens name. This prevents accidental cross-wiring (e.g.,
copying `security-agent.md` to `design-agent.md` without updating the persona).

When a mismatch is detected:

1. Log: `"Skipping .claude/red-team/{lens}-agent.md — persona mismatch (found '{actual}', expected '{lens}')"`
2. Fall through to Tier 2.

A file that fails rules 1-3 (missing, empty, or structurally invalid) is not a mismatch —
it simply means no override exists. Fall through to Tier 2 silently.

## Tier 2 — Bundled Persona

**Path:** `references/{lens}-agent.md` (relative to skill directory)

These are the default persona prompts shipped with the skill. All 8 lenses have bundled
personas:

| Lens | File |
|------|------|
| Security | `references/security-agent.md` |
| Assumptions | `references/assumptions-agent.md` |
| Completeness | `references/completeness-agent.md` |
| Design | `references/design-agent.md` |
| Feasibility | `references/feasibility-agent.md` |
| Operational | `references/operational-agent.md` |
| Cost | `references/cost-agent.md` |
| Compliance | `references/compliance-agent.md` |

If the bundled file is missing or unreadable, fall through to Tier 3.

## Tier 3 — Dynamic Generation

When neither a project override nor a bundled persona is available, the orchestrator
generates a minimal persona prompt dynamically. This ensures the skill can still operate
even if persona files are missing (e.g., a user deleted one, or a new lens name was
specified via user override that has no bundled file).

### Dynamic Persona Template

```
## Preamble

You are a red-team reviewer. Your job is to find flaws, not confirm quality.

Assume the artifact contains problems until you have specific evidence otherwise.
Do not soften findings or add reassuring language. Be direct and precise.

Rules:
1. Every finding must cite specific evidence -- line numbers, quoted text, or structural
   observations. "This might be a problem" is not a finding.
2. Empty categories must state: "No issues found after examining N items: {list}."
3. Assessment summary must quantify effort: items examined vs findings count.
4. You run in isolation. Do not reference or assume what other agents might find.
5. Read the full artifact before writing findings. Do not skim.
6. Do not hedge or soften. No "might", "could possibly", "perhaps" as primary evidence.
   State what is wrong, cite the evidence, explain the impact.

## Persona

PERSONA: {Lens} Reviewer
You are a specialist performing adversarial {lens} analysis.
Your focus: identify weaknesses, gaps, and risks related to {lens} concerns.
Apply domain expertise for {lens} to the artifact under review.

CATEGORIES for findings:
Use categories appropriate to the {lens} domain. Create 3-5 specific categories
based on what you observe in the artifact.

INSTRUCTIONS:
1. Read the full artifact carefully.
2. Identify all areas relevant to {lens} concerns.
3. For each area, assess whether it meets reasonable standards for {lens}.
4. Document specific findings with evidence.

## Tool Access

- Read — read artifact and related files
- Glob — find files by pattern
- Grep — search file contents
- Write — write findings file to output directory
```

The `{lens}` and `{Lens}` placeholders are replaced with the lowercase and title-case
lens name respectively.

### Dynamic generation limitations

Dynamically generated personas are generic. They lack the domain-specific focus areas,
categories, and instructions that bundled personas provide. When a dynamic persona is used:

1. Note it in the methodology section: `"{Lens}: dynamic persona (no bundled or override file)"`
2. The agent will still produce valid findings but may lack depth in lens-specific areas.

## Resolution Order Summary

```
For each selected lens:
  1. Try .claude/red-team/{lens}-agent.md
     - exists + valid → USE (record: "override")
     - exists + mismatched → LOG warning, continue to 2
     - missing/empty → continue to 2
  2. Try references/{lens}-agent.md
     - exists + readable → USE (record: "bundled")
     - missing/unreadable → continue to 3
  3. Generate dynamic persona from template
     - USE (record: "dynamic")
     - Log: dynamic persona is generic, may lack depth
```

## Methodology Reporting

The resolution tier is recorded per lens and included in the synthesis agent metadata
(Step 4b, AGENT COMPLIANCE RESULTS section). Format:

```
{lens}: {pass|partial|fail} (persona: {override|bundled|dynamic})
```

This allows the consolidated report's Methodology section to document which persona
sources were used, providing transparency about review quality.
