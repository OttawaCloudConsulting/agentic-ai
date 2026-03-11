# Benchmark: nist-csf-assessment

**Date**: 2026-03-06
**Skill version**: unversioned
**Evaluator**: Claude (automated benchmark)

---

## Mode 1 — Static Quality Analysis

### Rubric A: Internal Quality Standards

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Conciseness | 4 | Instructions are terse and action-oriented throughout. The Phase 1 tech stack detection table (lines 73–79) is illustrative but justified by the breadth of IaC patterns. The 800-53 informative references note in Important Rules (line 29) is slightly redundant with Phase 2 step 4, but it's minor. No obvious filler or padding. |
| Degrees of Freedom | 5 | Phase 0 is tightly prescribed (exact URLs, version comparison logic, file format requirements) — correctly low-freedom for a fragile self-update operation. Phase 1 architecture discovery correctly uses medium freedom ("scan for…", "adapt scanning to detected tech stack"). Phase 2 mapping leaves appropriate latitude for judgment. Smart re-run logic is prescriptive where it needs to be. |
| Progressive Disclosure | 5 | SKILL.md is 147 lines — well under the 500-line limit. Two reference files exist (`nist-csf-subcategories.md`, `phase-templates.md`) and both are referenced with explicit "when to read" guidance: "Read the subcategory tables from `references/nist-csf-subcategories.md`" (line 107) and "Read the corresponding template in `references/phase-templates.md`" (line 21). Reference files are one level deep. Content is not duplicated between SKILL.md and references. |
| Structure | 4 | Clear sequential workflow (Phase 0 → 1 → 2 → 3) with an early Output section and Important Rules section before phases. Imperative form used consistently ("Fetch", "Read", "Compare", "Produce", "Write"). The Important Rules section (lines 23–33) could be placed slightly more prominently at the very top before the Output table, but the current placement is functional. User checkpoints are explicit and correctly placed. |
| Resource Appropriateness | 5 | Reference files are used correctly: `nist-csf-subcategories.md` holds the large data table (loaded during Phase 2), `phase-templates.md` holds output templates (loaded before writing each phase). No scripts directory (appropriate — the task is analytical/generative, not deterministic/computational). No assets directory (appropriate). No forbidden files. |

**Rubric A Score**: 4.6 / 5.0

### Rubric B: Anthropic Best Practices

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Naming | 5 | `nist-csf-assessment` is kebab-case, lowercase, 20 characters (well under 64). `name` field matches folder name. `SKILL.md` filename is correct case. No reserved prefixes used. |
| Frontmatter | 5 | Both required fields (`name`, `description`) are present and correctly formed. `name` is kebab-case. YAML delimiters present and valid. No XML angle brackets in description. Description is approximately 450 characters — under the 1024-character limit. |
| Trigger Quality | 4 | Description includes explicit trigger phrases: "assess CSF compliance", "run a NIST CSF mapping", "check Cybersecurity Framework posture", "evaluate CSF 2.0 controls", "perform a cybersecurity framework assessment". Negative triggers are present and specific: "Do NOT use for general security audits, penetration testing, ITSG assessments, or FedRAMP assessments." Minor gap: "NIST SP 800-53 control assessments" is not listed as a negative trigger — 800-53 and CSF are closely related and could cause false positives, especially since the skill itself produces 800-53 informative references as output. |
| Instruction Quality | 5 | Instructions are specific and actionable throughout. Phase 0 includes exact URLs to fetch. Error handling table (lines 37–44) lists specific failure scenarios with explicit fallback actions. Phase 2 mapping provides a five-item checklist with concrete examples (e.g., "CloudTrail/Azure Monitor/Cloud Audit Logs -> DE.CM-03"). Reference files are linked with explicit "when to read" guidance. No vague "validate before proceeding" patterns. |
| Error Handling | 5 | Error Handling section (lines 36–44) covers five distinct failure scenarios across three phases. Each failure maps to a specific, actionable fallback. The Phase 0 version-check failure correctly distinguishes between "cannot reach" and "unexpected format" — two different failure modes requiring different responses. Phase 2 reference file corruption is correctly identified as a hard stop (no silent fallback). |

**Rubric B Score**: 4.8 / 5.0

### Overall Quality Score: 4.7 / 5.0

### Key Findings

- The skill is exceptionally well-structured for a multi-phase, long-running workflow: phase checkpoints are mandatory, smart re-run is default, and each phase has clearly scoped inputs and outputs.
- Progressive disclosure is correctly implemented — SKILL.md stays under 150 lines by delegating large data (subcategories) and output templates to reference files with precise loading guidance.
- Error handling is a strength: five failure scenarios are covered with differentiated fallbacks, including a correct hard-stop for a corrupted reference file.
- Degrees of freedom are well-calibrated: the self-updating Phase 0 is tightly prescribed (fragile, exact URLs, version format), while the analytical phases allow model judgment.
- The only notable gap is the missing negative trigger for "NIST SP 800-53 control assessments" — the skill produces 800-53 informative references as output, which could cause the description to trigger on 800-53-specific requests it should not handle.

---

## Mode 2 — Trigger Accuracy Testing

### Test Cases

| # | Prompt | Expected | Predicted | Match | Reasoning |
|---|---|---|---|---|---|
| 1 | "Can you run a NIST CSF assessment on our AWS architecture?" | TRIGGER | TRIGGER | YES | Exact phrase match: "NIST CSF" + "assessment" in description. |
| 2 | "We need to check our Cybersecurity Framework posture before our board review" | TRIGGER | TRIGGER | YES | Exact phrase match: "check Cybersecurity Framework posture" in description. |
| 3 | "Map our codebase to CSF 2.0 controls and show us the gaps" | TRIGGER | TRIGGER | YES | "CSF 2.0 controls" and "gap" map to "evaluate CSF 2.0 controls" trigger phrase. |
| 4 | "We're preparing for NIST CSF compliance — can you assess where we stand?" | TRIGGER | TRIGGER | YES | "NIST CSF compliance" directly matches "assess CSF compliance" trigger phrase. |
| 5 | "Do a cybersecurity framework assessment for our GCP project" | TRIGGER | TRIGGER | YES | Exact match: "perform a cybersecurity framework assessment". |
| 6 | "Run a NIST CSF mapping against our Azure environment" | TRIGGER | TRIGGER | YES | Exact phrase match: "run a NIST CSF mapping" in description. |
| 7 | "Assess our CSF 2.0 Govern and Identify functions and produce a gap analysis" | TRIGGER | TRIGGER | YES | "CSF 2.0" + "assess" + "gap analysis" strongly matches skill purpose. |
| 8 | "I need to know which CSF subcategories we've implemented and which we haven't" | TRIGGER | TRIGGER | YES | "CSF subcategories" and "implemented" directly match skill outputs described in frontmatter. |
| 9 | "Generate a phased NIST Cybersecurity Framework assessment report with 800-53 references" | TRIGGER | TRIGGER | YES | "NIST Cybersecurity Framework assessment" plus "800-53 references" aligns squarely with description. |
| 10 | "We want to evaluate our security posture against the Cybersecurity Framework 2.0 before our audit" | TRIGGER | TRIGGER | YES | "evaluate" + "Cybersecurity Framework 2.0" maps to "evaluate CSF 2.0 controls" trigger phrase. |
| 11 | "Run a FedRAMP assessment on our AWS environment" | SUPPRESS | SUPPRESS | YES | Explicit negative trigger: "Do NOT use for FedRAMP assessments". |
| 12 | "Conduct a general security audit of our application" | SUPPRESS | SUPPRESS | YES | Explicit negative trigger: "Do NOT use for general security audits". |
| 13 | "Can you do a penetration test on our API endpoints?" | SUPPRESS | SUPPRESS | YES | Explicit negative trigger: "Do NOT use for penetration testing". |
| 14 | "Assess our ITSG-33 compliance for our Canadian government project" | SUPPRESS | SUPPRESS | YES | Explicit negative trigger: "Do NOT use for ITSG assessments". |
| 15 | "Map our controls to NIST SP 800-53 Rev 5 and identify gaps" | SUPPRESS | TRIGGER | NO | 800-53 is not listed as a negative trigger; description mentions 800-53 informative references positively, creating over-trigger risk. |
| 16 | "We need an ISO 27001 gap assessment before our certification audit" | SUPPRESS | SUPPRESS | YES | ISO 27001 not mentioned as a trigger; no overlap with CSF-specific phrases in description. |
| 17 | "Run a SOC 2 Type II readiness assessment" | SUPPRESS | SUPPRESS | YES | "SOC 2" not a trigger phrase; no overlap with CSF-specific language in description. |
| 18 | "Can you do a security risk assessment for our new microservices architecture?" | SUPPRESS | SUPPRESS | YES | "security risk assessment" is generic; no CSF-specific trigger phrases match; "general security audits" negative trigger applies. |
| 19 | "We need to assess our NIST 800-53 control implementation for our ATO package" | SUPPRESS | TRIGGER | NO | "NIST" + "assess" + "control implementation" could trigger despite being 800-53-specific; ATO context suggests FedRAMP but FedRAMP negative trigger may not fire on this phrasing. |
| 20 | "Check our compliance against CIS Controls v8" | SUPPRESS | SUPPRESS | YES | "CIS Controls" not a trigger phrase; no CSF-specific language present. |

### Accuracy Metrics

| Metric | Value |
|---|---|
| True Positive Rate | 10/10 (100%) |
| True Negative Rate | 8/10 (80%) |
| Overall Accuracy | 18/20 (90%) |

### Trigger Analysis

The description is well-optimized for true positive triggering: it includes five distinct natural-language trigger phrases that cover the full range of how real users request CSF assessments. The negative triggers correctly block FedRAMP, ITSG, penetration testing, and general security audits. The primary gap is the absence of "NIST SP 800-53" or "800-53 control assessment" as a negative trigger — since the skill produces 800-53 informative references as output, the description can inadvertently attract requests for pure 800-53 control assessments (tests 15 and 19). Adding "Do NOT use for NIST SP 800-53 control assessments" to the negative triggers would close this gap without disrupting legitimate CSF triggers.

---

## Summary

| Dimension | Score |
|---|---|
| Static Quality (Rubric A) | 4.6/5 |
| Static Quality (Rubric B) | 4.8/5 |
| Trigger Accuracy | 90% (18/20) |

**Benchmark verdict**: `nist-csf-assessment` is a high-quality, production-ready skill with excellent progressive disclosure, well-calibrated degrees of freedom, and thorough error handling. The only actionable gap is the missing "NIST SP 800-53 control assessments" negative trigger in the description, which introduces over-trigger risk on 800-53-specific requests.
