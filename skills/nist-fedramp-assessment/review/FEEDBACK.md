# Feedback: nist-fedramp-assessment

**Date**: 2026-03-06
**Reviewer**: skill-creator review protocol
**Reviewed path**: skills/nist-fedramp-assessment/

---

## Critique Review — Internal Quality Standards

### Findings

- **Conciseness — lines 28–30 (Critical Rules)**: The "Dual inheritance model" rule (line 28) is lengthy prose that explains the FedRAMP CRM concept inline. This is domain reference material that belongs in references/nist-fedramp-controls.md or a new references/fedramp-concepts.md, not in the critical rules list. Claude does not need the explanation of what CRM means at SKILL.md tier; it only needs the rule to apply it.
- **Conciseness — lines 29–30 (Critical Rules)**: "USA context" and "FedRAMP ATO relevance" rules contain explanatory prose (e.g., "Default AWS regions are us-east-1 and us-west-2", "Note FISMA alignment where applicable") that adds token cost without changing behavior. These are background facts Claude already knows or can find in references.
- **Conciseness — lines 103–110 (Phase 2)**: The five-item enumerated list restates field definitions that should live exclusively in references/phase-templates.md. If the template file contains these field definitions, they are duplicated here. If it does not, the definitions belong there. Either way, lines 103–110 are the wrong tier for this content.
- **Conciseness — lines 134–138 (Example)**: The example is well-constructed and appropriately sized. No bloat.
- **Degrees of Freedom — Phase 1.2 (line 80–82)**: "Scan for security-relevant patterns: IAM/access control, encryption, logging/auditing, network, data protection, backup/recovery, configuration management, incident response" is a high-freedom instruction appropriate for a flexible discovery step. However, the next line ("For IaC-specific detection patterns...") trails off without completing the guidance — "adapt scanning to the detected tech stack" is vague enough to be unhelpful. Either provide the IaC-specific patterns in references/ with a link, or remove the sentence.
- **Degrees of Freedom — Phase 0 (lines 53–63)**: Phase 0 is a fragile, external-fetch operation. The steps are appropriately specific (exact URLs, exact comparison action, explicit fallback). Degrees of freedom are correctly calibrated here.
- **Degrees of Freedom — Phase 3 (lines 117–126)**: "produce a risk-rated remediation entry" defers entirely to the template file. That is correct for medium-freedom tasks. Good.
- **Progressive Disclosure — SKILL.md line count**: SKILL.md is 146 lines. Well under the 500-line limit. No overflow issue.
- **Progressive Disclosure — reference links**: Lines 21, 90, 103, 111, 119 all cite reference files with explicit when-to-read guidance ("Before writing any phase output, read..."). This is correct and well-executed.
- **Progressive Disclosure — references listed but not linked in the body**: Line 141–145 lists references/official-references.md but no earlier instruction in the skill body tells Claude when or why to read it. It appears only in the trailing References section. This file has no explicit when-to-read anchor and will likely be ignored.
- **Structure — section order**: Critical Rules appear before Phase workflows. That is correct; most important constraints are at the top.
- **Structure — imperative/infinitive form**: Consistently used throughout. Good.
- **Structure — Smart Re-run (lines 44–51)**: Smart Re-run is a useful feature but its placement between Critical Rules and Phase 0 breaks the sequential flow of the workflow. It would read more naturally immediately after the Output table (before Phase 0), as a pre-flight step, or folded into Phase 0.
- **Forbidden files**: Only SKILL.md and three reference files present. No README.md, CHANGELOG.md, LICENSE.txt, or INSTALLATION_GUIDE.md. Clean.

### What Works Well

- Progressive disclosure is implemented correctly: frontmatter triggers, SKILL.md body guides, references/ carries the bulk data.
- User checkpoints after Phase 1 and Phase 2 are explicit and well-specified, including the exact questions to ask.
- Error handling table (lines 34–42) is specific, covers realistic scenarios, and provides clear fallback actions — not generic catch-alls.
- Phase 0 framework validation with explicit URLs and fallback is a notable strength. The skill self-heals on stale control data.
- The Example section (lines 128–139) demonstrates the full workflow concisely with concrete file path references.
- Negative triggers in the frontmatter description are present and specific (NIST CSF, ITSG-33, FedRAMP High/Low, non-AWS environments).

---

## Red-Team Review — Anthropic Best Practices

### Findings

- **Naming conventions**: Folder name `nist-fedramp-assessment` is kebab-case lowercase. `name` field matches exactly. `SKILL.md` is correctly cased. No forbidden prefixes. No issues.
- **Frontmatter — description length**: The description (line 3) is a single long sentence. Measured: approximately 470 characters. Within the 1024-character limit. No issue.
- **Frontmatter — description completeness**: WHAT (map architecture to NIST 800-53/FedRAMP Moderate), WHEN (specific trigger phrases listed), and negative triggers (NIST CSF, ITSG-33, FedRAMP High/Low, non-AWS) are all present. Strong description.
- **Frontmatter — XML angle brackets**: None present. Clean.
- **Trigger quality — under-trigger risk**: Low. The description includes seven explicit trigger phrases ("assess FedRAMP compliance", "run a NIST 800-53 control mapping", "check FedRAMP Moderate controls", "evaluate FedRAMP posture", "perform a NIST assessment", "assess for FedRAMP ATO readiness"). A user asking about any of these will trigger correctly.
- **Trigger quality — over-trigger risk**: Low-medium. The phrase "perform a NIST assessment" is moderately broad — it could match NIST CSF or NIST SP 800-171 queries. The negative triggers partially mitigate this, but "NIST assessment" alone is vague. Consider tightening to "perform a NIST 800-53 assessment" in the description.
- **Progressive disclosure**: Three-tier system is correctly implemented. No reference files are loaded unconditionally; all have "before writing output, read..." guards. references/ is one level deep. No nested subdirectories.
- **Instruction quality — specificity**: Phase 0 and Phase 1 steps are specific and actionable. Phase 2 field definitions (lines 103–110) are specific. Phase 3 delegates to the template, which is appropriate.
- **Instruction quality — reference files cited with when-to-read**: references/phase-templates.md and references/nist-fedramp-controls.md are cited with explicit when-to-read guidance. references/official-references.md is listed only in the trailing References section (lines 141–145) with no when-to-read anchor in the body — this violates the guideline that "each reference file should have explicit when-to-read guidance."
- **Error handling**: Error handling table at lines 34–42 covers five realistic failure scenarios with specific actions. No silent failures. The Phase 0 fallback (lines 63) is also explicit. This criterion is well-satisfied.
- **Examples**: One concrete example at lines 128–139 demonstrates trigger phrase → phased actions → output files. It covers the core use case. Satisfies the criterion.
- **Critical instructions at the top**: Critical Rules section appears at line 23, before any phase instructions. Correct placement.
- **File structure — forbidden files**: No README.md or other forbidden files present.
- **Reference files — table of contents**: Best practices require a table of contents for reference files >100 lines. The three reference files (nist-fedramp-controls.md, phase-templates.md, official-references.md) have not been read, but given their likely size (nist-fedramp-controls.md for the full FedRAMP Moderate control set is almost certainly >100 lines), this should be verified and enforced.
- **`compatibility` field**: The skill is explicitly scoped to AWS workloads with US data residency requirements. The absence of a `compatibility` field is a missed opportunity to signal the environment constraint at the metadata tier, where it is always in context.

### What Works Well

- Frontmatter description is the strongest part of this skill: correct length, excellent trigger phrase coverage, and meaningful negative triggers.
- Error handling is thorough and specific — one of the better implementations across skills reviewed.
- Phase checkpoints with explicit user questions demonstrate good agentic safety practice.
- Reference citation pattern ("Before writing output, read references/X.md for Y") is correct and consistent.
- The dual-phase re-run check (smart re-run) prevents redundant work and is a practical quality-of-life feature for repeated assessments.

---

## Compiled Findings

### Critical Issues

None. The skill will function correctly as written. No frontmatter errors, no forbidden files, no structural failures.

### Improvements

1. **references/official-references.md has no when-to-read anchor** (lines 141–145): The file is listed in the trailing References section but never cited in the workflow body with guidance on when to read it. If it contains useful reference links, add a when-to-read trigger in Phase 0 (e.g., "If official source URLs change or are uncertain, consult references/official-references.md for current authoritative links"). If it is not needed during execution, remove it from the skill entirely.
2. **Inline explanatory prose in Critical Rules adds token cost without behavioral value** (lines 28–30): The explanation of what the FedRAMP CRM is, what CUI means, and what FISMA alignment means belongs in a reference file or is knowledge Claude already has. Trim these rules to their actionable instructions only.
3. **Phase 2 field definitions duplicate content that belongs in phase-templates.md** (lines 103–110): If phase-templates.md already defines these fields, this is duplication. If it does not, move the definitions there and replace lines 103–110 with "Read references/phase-templates.md Phase 2 section for required field definitions and output structure."
4. **Smart Re-run section placement disrupts workflow flow** (lines 44–51): Move Smart Re-run to a pre-flight position — either immediately after the Output table or as the first step of Phase 0 — so the document reads as a linear workflow.
5. **IaC-specific detection guidance is incomplete** (line 82): "adapt scanning to the detected tech stack" is not actionable. Either add IaC-specific patterns to a reference file and link to it, or remove the sentence.

### Minor Notes

- **Over-trigger risk from "perform a NIST assessment"**: Tighten to "perform a NIST 800-53 assessment" to reduce false positive matches against NIST CSF or other NIST framework queries.
- **Missing `compatibility` field**: The skill is AWS-specific and US-region scoped. Adding `compatibility: "AWS workloads; US regions (us-east-1, us-west-2); FedRAMP Moderate baseline"` surfaces this constraint at the metadata tier.
- **Reference files >100 lines should have a table of contents**: Verify that references/nist-fedramp-controls.md and references/phase-templates.md each include a table of contents at the top. Given their likely size, this is probable but unconfirmed.

---

## Prioritized Action Items

1. Add a when-to-read anchor for references/official-references.md in the workflow body, or remove the file from the skill if it serves no execution-time purpose. (Improvement — affects instruction quality and progressive disclosure correctness.)
2. Trim Critical Rules lines 28–30 to their actionable instructions. Remove the inline explanatory prose about CRM, CUI, and FISMA. (Improvement — reduces token cost without losing behavioral guidance.)
3. Audit Phase 2 field definitions (lines 103–110) against references/phase-templates.md. If duplicated, remove from SKILL.md and replace with a reference citation. (Improvement — eliminates duplication, reduces SKILL.md weight.)
4. Move Smart Re-run section to immediately after the Output table or into Phase 0 as a pre-flight step. (Improvement — improves readability and workflow linearity.)
5. Resolve the incomplete IaC detection guidance at line 82: either link to IaC-specific patterns in references/ or remove the trailing sentence. (Improvement — eliminates a vague, non-actionable instruction.)
6. Tighten "perform a NIST assessment" to "perform a NIST 800-53 assessment" in the frontmatter description. (Minor — reduces over-trigger risk.)
7. Add a `compatibility` field to frontmatter. (Minor — surfaces environment constraint at metadata tier.)
8. Verify references/nist-fedramp-controls.md and references/phase-templates.md each have a table of contents. Add if missing. (Minor — Anthropic best practice for reference files >100 lines.)
