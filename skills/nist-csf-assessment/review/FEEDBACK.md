# Feedback: nist-csf-assessment

**Date**: 2026-03-06
**Reviewer**: skill-creator review protocol
**Reviewed path**: skills/nist-csf-assessment/

---

## Critique Review — Internal Quality Standards

### Findings

- **[Conciseness — Line 8]** The opening paragraph of the body largely duplicates the frontmatter description. The description already states "Map project architecture to NIST Cybersecurity Framework (CSF) 2.0 outcomes. Produces a phased assessment at the subcategory level with cloud service evidence mapping and NIST 800-53 informative references. Always uses the latest published CSF version." Line 8 repeats this almost verbatim. The body paragraph adds "risk-rated gap analysis" and "Phase 0 self-updates the reference file" — only those deltas justify remaining.

- **[Conciseness — Lines 28–29]** The cloud service examples in the Important Rules (GuardDuty/Defender for Cloud/Chronicle -> DE.AE-02, etc.) are domain examples that appear again in Phase 2 instructions at lines 110–113. This is duplication between sections. The Phase 2 location is the correct home; the Important Rules entry is the redundant one.

- **[Degrees of Freedom — Lines 59–63]** Phase 0 instructions are appropriately low-freedom for the version-check and fetch logic. The overwrite instruction ("preserving the `<!-- version: X.X -->` header and table format") is correctly specific. Good.

- **[Degrees of Freedom — Lines 84–86]** Phase 1.2 ("Scan for security-relevant patterns: IAM/access control, encryption, logging/auditing...") and 1.3 are high-freedom, which is appropriate — discovery is inherently flexible. No issue.

- **[Degrees of Freedom — Lines 107–115]** Phase 2 mapping criteria list (Status, Platform Evidence, Customer Evidence, 800-53 References, Notes) is the right level of specificity for a structured output. The instruction to read the template file before writing is correct low-freedom guidance.

- **[Progressive Disclosure — Line count]** SKILL.md is 147 lines. Well under the 500-line limit. No overflow risk.

- **[Progressive Disclosure — Lines 141–142]** Reference files are cited with explicit "when to read" guidance: "read during Phase 2 for the full subcategory list" and "read before writing any phase output." This is correct.

- **[Progressive Disclosure — Lines 21, 94, 115, 123]** References are loaded conditionally within specific phases, not unconditionally at the top. Correct pattern.

- **[Structure — Line 23]** "Important Rules" section is placed after "Output" — this is a structural weakness. Critical operating rules (evidence over assumption, always assess to latest version, no fabricated subcategories) should appear before workflow phases, ideally near the top of the document. A reader skimming to Phase 2 may miss these rules.

- **[Structure — Lines 35–44]** Error Handling table is well-positioned before the phase workflows. The failure modes are specific and actionable. Good.

- **[Structure — Lines 45–53]** Smart Re-run section appears before Phase 0, which is correct since it applies to all phases. Content is concise and action-oriented.

- **[Structure — Lines 70–80]** The tech stack detection table in Phase 1.1 is thorough. The caveat at line 80 ("This list is illustrative — scan for any IaC or CI/CD patterns") appropriately opens freedom back up after providing the illustrative list.

- **[Structure — Line 107]** "For every subcategory across all 6 Functions (GV, ID, PR, DE, RS, RC)" — this is correct reference to the six Functions. Good orientation for the model.

- **[Conciseness — Lines 143–146]** The References section lists four external URLs. The NIST CSF landing page and CSRC reference tool URLs are already cited inline in Phase 0 (lines 61, 62). Listing them again in References is redundant. CSWP 29 and SP 800-53 Rev 5 links add value as standalone references; the Phase 0 URLs do not need to be repeated.

- **[No forbidden files]** No README.md, CHANGELOG.md, INSTALLATION_GUIDE.md, or LICENSE.txt in the skill directory. Clean.

- **[Resource Appropriateness]** Two reference files found: `nist-csf-subcategories.md` (domain data table, correct location) and `phase-templates.md` (output templates, correct location). Both are properly deferred to on-demand loading via phase instructions.

### What Works Well

- Progressive disclosure is correctly implemented: references are conditionally loaded within specific phases, not front-loaded.
- Error handling table is comprehensive and specific — covers five distinct failure scenarios with concrete fallbacks.
- Smart Re-run section is concise and well-placed.
- Phase checkpoints between phases are explicitly enforced with specific questions.
- The "no fabricated subcategories" rule (line 30) is a strong guard against hallucination — essential for a compliance tool.
- Cloud service examples are multi-cloud and non-prescriptive (AWS/Azure/GCP parity).
- Phase 0 self-update pattern is well-designed: specific fetch targets, version comparison, and graceful fallback.

---

## Red-Team Review — Anthropic Best Practices

### Findings

- **[Naming — Folder/Name field match]** Folder name `nist-csf-assessment` and `name: nist-csf-assessment` match. Kebab-case, lowercase, no underscores. Passes.

- **[Frontmatter — Description length]** The description (line 3) is long. Counting characters: approximately 580 characters. Under the 1024-character limit. Passes.

- **[Frontmatter — No XML angle brackets]** No `<` or `>` characters in the description. Passes.

- **[Frontmatter — WHAT + WHEN coverage]** Description covers WHAT (map architecture to CSF 2.0, produces phased assessment with cloud evidence and 800-53 references) and WHEN (trigger phrases: "assess CSF compliance", "run a NIST CSF mapping", "check Cybersecurity Framework posture", "evaluate CSF 2.0 controls", "perform a cybersecurity framework assessment"). Negative triggers present ("Do NOT use for general security audits, penetration testing, ITSG assessments, or FedRAMP assessments"). Strong frontmatter.

- **[Trigger Quality — Over-trigger risk from 800-53 references]** The SKILL.md body prominently references NIST 800-53 (lines 29, 112, 141, 146). If a user asks something like "help me with 800-53 controls" or "check my NIST compliance posture," this skill could plausibly over-trigger vs. a dedicated SP 800-53 skill. The negative triggers in the description only exclude FedRAMP, ITSG, penetration testing, and general audits — they do not explicitly exclude standalone 800-53 assessments. This is a latent over-trigger risk if an 800-53 skill ever coexists.

- **[Trigger Quality — Under-trigger risk]** Low risk. The trigger phrases are concrete and cover the realistic user vocabulary: "NIST CSF", "CSF compliance", "Cybersecurity Framework posture", "CSF 2.0 controls". A user asking about any of these will reliably load this skill.

- **[Instruction Quality — Actionability]** Phase 0 instructions at lines 58–63 are specific: fetch a named URL, read a named comment, compare versions, overwrite a named file. High actionability. Phase 1 scan instructions at lines 72–79 provide a concrete table of file indicators. Phase 2 at lines 107–115 lists five structured output fields. All phases are actionable.

- **[Instruction Quality — No concrete example]** The skill has no worked example (trigger phrase → actions → result). The Anthropic best practices flag missing examples as a nice-to-have. For a complex multi-phase workflow, an example would significantly aid comprehension and correct invocation.

- **[Instruction Quality — References cited with when-to-read]** Lines 21, 94, 115, 123, and 141–142 all provide explicit when-to-read guidance. Passes.

- **[Error Handling — Coverage]** Five failure modes documented (lines 37–44): Phase 0 network failure, Phase 0 unexpected format, Phase 1 no IaC detected, Phase 1 no architecture docs, Phase 2 missing reference file. All have specific fallbacks. The Phase 2 failure (stop and report) is correctly hard-stop — proceeding without the subcategory reference file would produce fabricated output. Good.

- **[Error Handling — Silent failures]** No silent fallbacks detected. Phase 0 network failure reports and proceeds with noted caveats; Phase 2 reference failure stops entirely. No `or {}` equivalents.

- **[File Structure — Forbidden files]** No README.md or other forbidden files in the skill directory. Passes.

- **[Progressive Disclosure — Tier 2 line count]** 147 lines. Well within the 500-line limit. Passes.

- **[Progressive Disclosure — Reference loading]** Both reference files are linked with conditional, phase-specific loading instructions. No unconditional loading. Passes.

- **[Critical instructions positioning]** The "Important Rules" section (lines 23–33) is section 3 in the document, after Output (section 2). Per best practices, critical instructions should be near the top. The rules at lines 25–26 (evidence over assumption, always assess to latest version) are operating invariants that should not follow the output spec — a model skimming to Phase 1 could miss them.

- **[`disable-model-invocation` field]** Not present. This is correct — this skill should auto-trigger. Passes.

- **[Optional fields — `compatibility`]** Not present. Given that Phase 0 makes live web fetches, noting that network access is required would be useful for consumers running in air-gapped environments. Minor gap.

### What Works Well

- Description is among the strongest seen: WHAT, WHEN, multi-phrase triggers, and explicit negative triggers all present in under 1024 characters.
- Error handling covers the most dangerous failure (fabricated subcategories) with a hard stop.
- Trigger quality is high: low under-trigger risk, low over-trigger risk in current isolated deployment.
- Multi-phase structure with mandatory user checkpoints is clearly articulated.
- The self-updating Phase 0 pattern with version pinning is an advanced and well-specified pattern.

---

## Compiled Findings

### Critical Issues

None — no blockers that would break skill functionality or cause upload failure. YAML frontmatter is valid, name field is correct, no forbidden files, line count is within limit.

### Improvements

1. **Reorder sections: move "Important Rules" above "Output"** — The critical invariants (evidence over assumption, always assess to latest version, no fabricated subcategories, phase checkpoints mandatory) must be encountered before the model reaches the phase workflow instructions. Currently they appear after the output table, which a skimming model may not read before diving into Phase 0. Move "Important Rules" to be the first section after the opening paragraph, or restructure as a "## Critical" section immediately below the frontmatter body intro.

2. **Remove duplicate cloud service examples from Important Rules** — Lines 28–29 give cloud service → subcategory examples (GuardDuty/DE.AE-02, AWS Config/ID.AM-05). These same examples appear in Phase 2 at lines 110–113. The Phase 2 location is the correct context; the Important Rules usage is redundant. Remove from Important Rules, keep in Phase 2.

3. **Add a negative trigger for standalone 800-53 assessments** — The description currently excludes FedRAMP and ITSG but not pure 800-53 work. If a co-deployed 800-53 skill exists, the 800-53 content in this skill's body could cause over-triggering. Add "Do NOT use for standalone NIST SP 800-53 control assessments" to the description's negative triggers.

4. **Trim duplicate URLs from References section** — Lines 143–144 repeat the NIST CSF landing page and CSRC reference tool URLs already cited inline in Phase 0. Remove those two lines from the References section; retain the CSWP 29 and SP 800-53 Rev 5 links, which are not cited inline and add standalone reference value.

5. **Add a `compatibility` note** — Phase 0 requires live network access to `nist.gov` and `csrc.nist.gov`. Add a `compatibility` frontmatter field noting this requirement so consumers in restricted environments know to expect fallback behavior.

### Minor Notes

1. **No worked example** — The skill has no trigger-phrase → actions → result example. For a four-phase, multi-checkpoint workflow this is a meaningful omission. A brief example (e.g., "User says: 'Run a CSF assessment on this repo.' Claude: runs Phase 0 version check, proceeds to Phase 1 discovery...") would help users understand the scope before invoking.

2. **Opening body paragraph duplicates description** — Line 8 restates the description almost verbatim. Trim to the two-sentence delta: the Phase 0 self-update behavior and the risk-rated gap analysis. The rest is already in the frontmatter.

3. **Reference files lack documented table-of-contents status** — Best practices recommend a table of contents for reference files over 100 lines. Both reference files (`nist-csf-subcategories.md`, `phase-templates.md`) are likely large. Verify each has a table of contents; if not, add one.

---

## Prioritized Action Items

1. Reorder sections — move "Important Rules" (or rename to "## Critical") to appear immediately after the intro paragraph, before "## Output". Critical invariants must be encountered before the phase instructions.

2. Add a negative trigger for standalone 800-53 assessments to the description's "Do NOT use for..." clause, to prevent future over-trigger conflicts.

3. Add a `compatibility` frontmatter field indicating network access is required (Phase 0 live fetch).

4. Remove cloud service examples from Important Rules (lines 28–29) — they duplicate Phase 2 content and do not belong in a rules list.

5. Trim the References section — remove the two URLs already cited inline in Phase 0 (NIST CSF landing page, CSRC reference tool). Retain CSWP 29 and SP 800-53 links.

6. Trim the opening body paragraph (line 8) to only the delta content not already in the frontmatter description.

7. Add a minimal worked example — one or two sentences showing trigger phrase and what phases the skill runs.

8. Verify `nist-csf-subcategories.md` and `phase-templates.md` each have a table of contents; add if missing.
