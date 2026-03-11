# Feedback: itsg-assessment

**Date**: 2026-03-06
**Reviewer**: skill-creator review protocol
**Reviewed path**: skills/itsg-assessment/

---

## Critique Review — Internal Quality Standards

### Findings

- **Conciseness — Phase 1 tables (lines 74–93)**: The tech stack detection table (lines 74–79) lists common file indicators that Claude already knows. The pattern is clear from the first two rows; the full table adds token cost without adding knowledge Claude lacks. Consider collapsing to a prose list or cutting to IaC-specific entries only.
- **Conciseness — Phase 1.2 category table (lines 84–93)**: The "What to search for" column contains standard AWS resource naming (e.g., `iam.Role`, `aws_iam_*`, `Effect: Allow/Deny`). This is widely known; value is low relative to token cost. The last line (line 93) — "Adapt search terms to the detected IaC framework" — partially acknowledges this but doesn't justify keeping the full table.
- **Conciseness — Smart Re-run section (lines 48–54)**: The four-step re-run logic largely mirrors the Phase 0–3 flow and is clear, but step 2 ("If significant changes detected, re-run that phase") is vague — "significant changes" is undefined. Either define it or trust Claude to interpret it without the elaboration.
- **Degrees of Freedom — Phase 0 (lines 56–65)**: Phase 0 fetches a URL from a reference file and compares against another reference file, then optionally updates the control file. This is a low-freedom, fragile operation (network, diff, conditional update) described in high-freedom prose. A script would be more appropriate. Without one, the steps are precise but the execution is not deterministic.
- **Degrees of Freedom — Phase 1.1 (lines 69–80)**: Tech stack detection is a flexible discovery task — high-freedom prose is correct here.
- **Degrees of Freedom — Phase 2 (lines 114–127)**: Mapping hundreds of controls to a four-status model is the core work; the instructions are appropriately flexible. No issue.
- **Progressive Disclosure — SKILL.md line count**: The file is 155 lines, well within the 500-line limit. No overflow issue.
- **Progressive Disclosure — Reference loading (lines 150–154)**: The References section at the bottom names all three reference files with explicit when-to-read guidance. This is correct.
- **Progressive Disclosure — Phase templates cited conditionally**: Lines 45, 103, 123, 131 all say "Before writing, read `references/phase-templates.md`." This is correct conditional loading — templates are not inlined.
- **Structure — "Important Rules" section placement (lines 10–23)**: Rules are at the top under a clear header. This is correct.
- **Structure — "Example" section (lines 25–33)**: The example is compact and covers the core use case. However, it is positioned before the Output table (line 34), which is a natural reference point during execution. Minor ordering issue — the Output table should precede or accompany the example.
- **Structure — Error Handling table (lines 140–149)**: Five rows cover the main failure modes. This is good. However, the "Ambiguous control status" row (line 147) describes normal behavior (marking Partially Implemented) already defined in Phase 2 — this is redundant.
- **Redundancy — "Canadian jurisdiction" rule (line 17) vs. frontmatter negative trigger**: The negative trigger "Do NOT use for FedRAMP, NIST CSF, SOC 2, or non-Canadian compliance frameworks" appears in the frontmatter description AND is re-stated in Important Rules line 17. The body repetition is low-value since it only fires after triggering.
- **Redundancy — Phase 0 failure handling**: Phase 0 section (line 65) documents the fetch-fail fallback. Error Handling table (line 142) repeats it. One location is sufficient.

### What Works Well

- The three-phase structure with mandatory checkpoints is clearly defined and correctly scoped.
- Reference files are named with explicit when-to-read instructions at both the point of use and in the References footer section.
- Error handling covers the most likely failure scenarios with concrete actions.
- The skill stays well under the 500-line limit, leaving room for growth.
- Important Rules are first — the most critical guardrails (evidence over assumption, no inflated compliance) are surfaced before any workflow.
- The frontmatter description is comprehensive: includes what, when, specific trigger phrases, and negative triggers.

---

## Red-Team Review — Anthropic Best Practices

### Findings

- **Naming conventions**: Folder name `itsg-assessment` is kebab-case. `name` field matches exactly. `SKILL.md` is correctly cased. No forbidden files present. Pass.
- **Frontmatter — description character count**: The description (line 3) is approximately 510 characters, well under the 1024-character limit. Pass.
- **Frontmatter — no XML angle brackets**: Confirmed absent. Pass.
- **Frontmatter — trigger phrases**: Includes "assess ITSG", "run a CCCS Medium compliance check", "evaluate Canadian cloud compliance", "map ITSG-33 controls", "perform a GC cloud security assessment", "check Protected B data handling requirements." These are specific and user-facing. Pass.
- **Frontmatter — negative triggers**: "Do NOT use for FedRAMP, NIST CSF, SOC 2, or non-Canadian compliance frameworks." This is present and appropriately specific. Pass.
- **Trigger quality — under-trigger risk**: Low. The description covers the domain vocabulary users would actually use. Acronym coverage (ITSG, CCCS, GC, Protected B) matches how practitioners phrase requests.
- **Trigger quality — over-trigger risk**: Low-medium. "Canadian cloud compliance" and "GC cloud security assessment" could theoretically match non-ITSG-33 Canadian frameworks (e.g., TBS PBMM). The negative trigger list names specific frameworks but does not say "ITSG-33 only" in a way that would catch adjacent Canadian frameworks. A user asking about "PBMM compliance" or "GC Protect B architecture review" might not trigger this skill when they should, or might trigger it when a different framework is the actual target.
- **Progressive disclosure — three-tier compliance**: Tier 1 (frontmatter) loads the description. Tier 2 (SKILL.md body, 155 lines) loads on trigger. Tier 3 (three reference files) loads conditionally. All three tiers are correctly implemented.
- **Progressive disclosure — reference files mentioned without content inlined**: Control tables, output templates, and official URLs are all deferred to references. No content duplication detected between SKILL.md body and reference files (files not read in full, but SKILL.md contains no inline control tables or template blocks, confirming correct deferral).
- **Instruction quality — actionability**: Phase steps are specific. Phase 1.1 specifies file patterns per IaC type. Phase 1.2 lists search categories. Phase 2 defines the four-status model. Phase 3 specifies output file names and ordering. Actionable throughout.
- **Instruction quality — verification steps**: Phase checkpoints (lines 105–112, 125–127) include specific questions to ask the user. This is explicit verification. Pass.
- **Instruction quality — reference file guidance**: Each reference is cited with when-to-read context (e.g., "read during Phase 2 to map each control"). Pass.
- **Error handling — documented failure modes**: Five failure modes in the Error Handling table (lines 140–149). Each has a concrete action. Pass.
- **Error handling — silent failures prevented**: Phase 0 explicitly reports skip reason on fetch failure (line 65). Empty project case asks for user input before proceeding (line 149). No silent fallbacks. Pass.
- **Examples — core use case demonstrated**: Lines 25–33 show a CDK project scenario with all four phases mapped to concrete actions. Pass.
- **Critical instructions at the top**: "Important Rules" section at lines 10–23 precedes all workflow sections. Pass.
- **File structure — no forbidden files**: No README.md, CHANGELOG.md, INSTALLATION_GUIDE.md, or LICENSE.txt present in the skill directory. Three reference files present: `itsg33-controls.md`, `official-references.md`, `phase-templates.md`. All are agent-facing data/template files. Pass.
- **Missing `compatibility` field**: The skill is AWS-specific (ca-central-1, ca-west-1 regions, CDK/Terraform/CloudFormation detection). No `compatibility` field in frontmatter. This is a nice-to-have for environment clarity but not a blocker.
- **Missing `license` field**: No license declared. Low priority for internal use, but noted as a gap if this skill is published.
- **Phase 0 network dependency undocumented in frontmatter**: The skill fetches a live URL during Phase 0. This is a runtime dependency not surfaced in frontmatter `compatibility`. Users in air-gapped or restricted environments would hit the fetch-fail path silently.

### What Works Well

- Description is the strongest part of this skill: specific, correctly scoped, includes negative triggers, well within character limit.
- Three-tier progressive disclosure is implemented correctly — templates and control data are deferred, not inlined.
- Error handling is thorough for a domain-specific skill of this complexity.
- No forbidden files present.
- User checkpoint questions (lines 108–111, 127) are concrete and elicit the specific out-of-band context that code analysis cannot detect.

---

## Compiled Findings

### Critical Issues

None identified. The skill has valid frontmatter, correct file structure, no forbidden files, actionable instructions, and proper progressive disclosure.

### Improvements

1. **Remove redundant body rule for framework exclusion (line 17)**: The "Canadian jurisdiction" rule in Important Rules restates what the frontmatter negative trigger already communicates. The body only loads after triggering, so this rule fires too late to prevent mis-triggering and too early in the body to add value mid-assessment. Remove or replace with a positive statement about what the skill does cover (e.g., "Apply CCCS Medium Cloud Profile control selection only").

2. **Collapse or remove Phase 1.1 tech stack detection table (lines 74–79)**: The indicators listed (package.json, requirements.txt, Dockerfile, etc.) are widely known. If retained, trim to IaC-specific indicators only — those are the ones that affect control mapping behavior and have non-obvious detection patterns (e.g., Crossplane YAML vs. CloudFormation YAML).

3. **Collapse or trim Phase 1.2 search category table (lines 84–93)**: The resource name examples (`iam.Role`, `aws_iam_*`, `Effect: Allow/Deny`) are common knowledge. Consider removing the "What to search for" column and listing only the category names — Claude will generate appropriate search terms. Retain the IaC adaptation note (line 93) as a standalone sentence.

4. **Deduplicate Phase 0 failure handling**: Phase 0 section (line 65) and Error Handling table (line 142) both document the fetch-fail fallback. Remove the Error Handling table row — the fallback is already at the point of use.

5. **Remove "Ambiguous control status" from Error Handling table (line 147)**: This row describes normal behavior (mark Partially Implemented with notes) already specified in Phase 2. It is not an error condition. Remove it from the error table.

6. **Add `compatibility` field to frontmatter**: The skill requires AWS infrastructure, specific Canadian AWS regions, and makes live network calls during Phase 0. Surfacing this in `compatibility` helps users evaluate fit before triggering. Example: `compatibility: "AWS workloads in Canadian regions (ca-central-1, ca-west-1). Requires network access for Phase 0 validation."`

7. **Tighten "significant changes" definition in Smart Re-run (line 51)**: "Significant changes detected" is undefined. Specify a concrete heuristic, e.g., "any IaC file modified since the phase output was written, or any new AWS service added."

### Minor Notes

- The `## Example` section (lines 25–33) is positioned before the Output table (lines 34–44). Moving the Output table before the example would give context for what the example's output steps produce.
- The over-trigger risk for adjacent Canadian frameworks (PBMM, TBS) is low but real. Consider adding "PBMM" or "TBS cloud" to the negative trigger list if this skill is deployed in environments where those frameworks are also discussed.
- No `license` field — low priority for internal use.

---

## Prioritized Action Items

1. Add `compatibility` field to frontmatter documenting AWS requirement, Canadian region dependency, and Phase 0 network access need.
2. Remove the "Canadian jurisdiction" rule from Important Rules body (line 17) — redundant with frontmatter negative trigger; replace if needed with a positive scope statement.
3. Deduplicate Phase 0 failure handling — remove the Error Handling table row (line 142), keep the in-phase fallback at line 65.
4. Remove "Ambiguous control status" from Error Handling table (line 147) — describes normal Phase 2 behavior, not an error condition.
5. Define "significant changes" concretely in Smart Re-run section (line 51).
6. Trim Phase 1.1 tech stack detection table to IaC-specific indicators only, or remove entirely.
7. Trim Phase 1.2 search category table — remove resource name examples, keep category names and the IaC adaptation note.
8. Move Output table (lines 34–44) before the Example section (lines 25–33) for better reading order.
9. Consider adding PBMM/TBS to negative triggers if deployed in multi-framework GC environments.
10. Add `license` field if skill will be published externally.
