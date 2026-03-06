# Benchmark: nist-fedramp-assessment

**Date**: 2026-03-06
**Skill version**: unversioned
**Evaluator**: Claude (automated benchmark)

---

## Mode 1 — Static Quality Analysis

### Rubric A: Internal Quality Standards

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Conciseness | 4 | The skill is lean and purposeful. Each phase section covers exactly what the model needs. The Critical Rules table could be tightened (the "Dual inheritance model" and "FedRAMP ATO relevance" bullets are dense prose where a single-sentence rule with a reference pointer would reduce token cost), but there is no meaningful redundancy or filler. |
| Degrees of Freedom | 4 | High-freedom tasks (architecture description, control mapping notes) are left open. Low-freedom tasks (mandatory phase checkpoints, output file names, smart re-run logic) are locked down explicitly. Phase 0 URL fetch is prescribed with specific URLs, which is appropriately low-freedom for a validation step. One gap: Phase 1.2 scan for "security-relevant patterns" is listed as categories only — a low-freedom pointer to reference/nist-fedramp-controls.md for exact patterns would be tighter. |
| Progressive Disclosure | 5 | SKILL.md is 146 lines — well under the 500-line limit. Three reference files exist (nist-fedramp-controls.md, phase-templates.md, official-references.md). Each is referenced with explicit "before writing output, read..." guidance. Reference files are one level deep. Content is not duplicated between SKILL.md and references. |
| Structure | 5 | Frontmatter is valid YAML with name and description. Body opens with a purpose statement, then Output table, then Critical Rules, then Error Handling, then phased workflow, then Example, then References. Imperative form is used consistently throughout. The example section shows trigger phrase → actions → result, which is the correct pattern. |
| Resource Appropriateness | 4 | References are used correctly for voluminous domain content (control tables, output templates, official links). No scripts directory exists, which is correct — this skill's operations are inherently model-driven analysis, not deterministic automation. No assets directory, also correct. Minor note: Phase 0 references "cached control data in references/nist-fedramp-controls.md" but Phase 2 also instructs the model to read that file — the two are consistent, but the Phase 0 fallback language could point to Phase 2 explicitly to close the loop. |

**Rubric A Score**: 4.4 / 5.0

### Rubric B: Anthropic Best Practices

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Naming | 5 | Folder name `nist-fedramp-assessment` is kebab-case, lowercase, no spaces or underscores. `name` field in frontmatter matches exactly. File is named `SKILL.md` (correct case). No forbidden files (README.md, CHANGELOG.md) are present. |
| Frontmatter | 5 | Both required fields (`name`, `description`) are present. No XML angle brackets in description. Description is well under the 1024-character limit (approximately 620 characters). YAML delimiters are correct. No extraneous fields that would cause parse failures. |
| Trigger Quality | 5 | Description includes both WHAT (maps AWS architecture to NIST SP 800-53 Rev 5 / FedRAMP Moderate, produces 4 documents) and WHEN (explicit trigger phrases: "assess FedRAMP compliance", "run a NIST 800-53 control mapping", "check FedRAMP Moderate controls", "evaluate FedRAMP posture", "perform a NIST assessment", "assess for FedRAMP ATO readiness"). Negative triggers are present and accurate: "Do NOT use for NIST CSF assessments, ITSG-33 assessments, FedRAMP High or Low baselines, or non-AWS cloud environments." This is one of the better-constructed description fields for a narrow, specialist skill. |
| Instruction Quality | 5 | Instructions are specific and actionable. Phase 1.1 provides exact file indicators per tech stack. Phase 2 enumerates the five fields to determine per control. Phase 3 defers to templates via an explicit read-before-write instruction. The example section traces a concrete user phrase through four phases to four output files. Error handling table covers five distinct failure scenarios with prescribed responses. Critical rules are in a named `## Critical Rules` section near the top of the body. |
| Error Handling | 5 | Five error scenarios are covered in a table: unreachable Phase 0 URLs, no IaC, no architecture docs, empty codebase, ambiguous control status. Each has a prescribed action. Phase 0 also has a dedicated fallback paragraph with specific behavior. The Smart Re-run section handles the re-entry case. The "Partially Implemented" default for ambiguity is an explicit, safe fallback that prevents fabrication. |

**Rubric B Score**: 5.0 / 5.0

### Overall Quality Score: 4.7 / 5.0

### Key Findings

- The description field is a model example of trigger engineering: six affirmative trigger phrases plus four explicit negative triggers, all accurate, all within character limits.
- Progressive disclosure is implemented correctly — 146-line SKILL.md with three reference files, each referenced with explicit "when to read" guidance.
- The Critical Rules section near the top of the body ensures high-priority constraints (no fabricated controls, evidence over assumption) are loaded before any phase work begins.
- Minor conciseness opportunity: the "Dual inheritance model" critical rule contains two sentences of explanatory prose that could be condensed and the detail moved to a reference file — this is a nice-to-have, not a defect.
- Phase 1.2's scan targets ("IAM/access control, encryption, logging/auditing, network, data protection, backup/recovery, configuration management, incident response") are listed as prose rather than directed to a reference file; adding a pointer to nist-fedramp-controls.md for the pattern list would reduce model guesswork on what counts as security-relevant.

---

## Mode 2 — Trigger Accuracy Testing

The description field used for evaluation:

> Map AWS project architecture to NIST SP 800-53 Rev 5 / FedRAMP Moderate security controls. Produces a phased compliance assessment (4 output documents) with AWS shared responsibility inheritance and risk-rated gap analysis. Use when asked to assess FedRAMP compliance, run a NIST 800-53 control mapping, check FedRAMP Moderate controls, evaluate FedRAMP posture, perform a NIST assessment, or assess for FedRAMP ATO readiness. Do NOT use for NIST CSF assessments, ITSG-33 assessments, FedRAMP High or Low baselines, or non-AWS cloud environments.

### Test Cases

| # | Prompt | Expected | Predicted | Match | Reasoning |
|---|---|---|---|---|---|
| 1 | "Assess this project for FedRAMP Moderate compliance." | TRIGGER | TRIGGER | YES | Exact match to trigger phrase "assess FedRAMP compliance" with Moderate qualifier. |
| 2 | "Run a NIST 800-53 control mapping on our AWS infrastructure." | TRIGGER | TRIGGER | YES | Matches "run a NIST 800-53 control mapping" trigger exactly. |
| 3 | "Can you check our FedRAMP Moderate controls?" | TRIGGER | TRIGGER | YES | Matches "check FedRAMP Moderate controls" trigger phrase. |
| 4 | "We need to evaluate our FedRAMP posture before the audit." | TRIGGER | TRIGGER | YES | Matches "evaluate FedRAMP posture" trigger. |
| 5 | "Perform a NIST assessment on this codebase." | TRIGGER | TRIGGER | YES | Matches "perform a NIST assessment" trigger. |
| 6 | "Are we ready for FedRAMP ATO? Can you assess readiness?" | TRIGGER | TRIGGER | YES | Matches "assess for FedRAMP ATO readiness" trigger. |
| 7 | "Map our AWS CDK stack to NIST 800-53 Rev 5 security controls." | TRIGGER | TRIGGER | YES | Matches "NIST SP 800-53 Rev 5" and "AWS" from the WHAT clause; strongly aligns with described capability. |
| 8 | "We're pursuing a FedRAMP Moderate authorization — can you do a gap analysis?" | TRIGGER | TRIGGER | YES | FedRAMP Moderate + gap analysis is core output of this skill; "gap analysis" is mentioned in description. |
| 9 | "Identify control gaps in our AWS environment for FISMA compliance." | TRIGGER | TRIGGER | YES | FISMA alignment is mentioned in Critical Rules context; NIST 800-53 underpins FISMA — description's "NIST 800-53 control mapping" trigger covers this. |
| 10 | "Generate a compliance assessment for our AWS workload against FedRAMP." | TRIGGER | TRIGGER | YES | Matches "assess FedRAMP compliance" with AWS qualifier explicit in the request. |
| 11 | "Assess our cybersecurity program against the NIST Cybersecurity Framework." | SUPPRESS | SUPPRESS | YES | Negative trigger "Do NOT use for NIST CSF assessments" directly blocks this. |
| 12 | "Run an ITSG-33 control assessment for our Canadian federal project." | SUPPRESS | SUPPRESS | YES | Explicit negative trigger "ITSG-33 assessments" in description. |
| 13 | "Map our Azure environment to FedRAMP Moderate controls." | SUPPRESS | SUPPRESS | YES | Negative trigger "non-AWS cloud environments" blocks Azure requests. |
| 14 | "Assess this system for FedRAMP High authorization." | SUPPRESS | SUPPRESS | YES | Negative trigger "FedRAMP High or Low baselines" explicitly blocks FedRAMP High. |
| 15 | "We need a FedRAMP Low impact assessment for our SaaS." | SUPPRESS | SUPPRESS | YES | Negative trigger "FedRAMP High or Low baselines" covers FedRAMP Low. |
| 16 | "Perform a SOC 2 Type II readiness assessment." | SUPPRESS | SUPPRESS | YES | SOC 2 is outside NIST/FedRAMP scope; no trigger phrase matches; description is specific enough to avoid false positive. |
| 17 | "Run an ISO 27001 gap analysis against our ISMS." | SUPPRESS | SUPPRESS | YES | ISO 27001 is not mentioned in any trigger phrase; description's AWS/NIST/FedRAMP specificity correctly suppresses. |
| 18 | "Assess our GCP infrastructure for NIST 800-53 compliance." | SUPPRESS | SUPPRESS | YES | Negative trigger "non-AWS cloud environments" blocks GCP despite NIST 800-53 mention. |
| 19 | "We need a general security audit of our web application." | SUPPRESS | SUPPRESS | YES | No FedRAMP/NIST trigger phrase; description specificity prevents spurious triggering on generic security language. |
| 20 | "Can you help us with our System Security Plan documentation for FedRAMP?" | TRIGGER | TRIGGER | YES | SSP documentation is within FedRAMP ATO readiness scope; "assess for FedRAMP ATO readiness" and "FedRAMP compliance" triggers apply. Description mentions SSP context in body via Phase 2 FedRAMP ATO Note field. |

### Accuracy Metrics

| Metric | Value |
|---|---|
| True Positive Rate | 10/10 (100%) |
| True Negative Rate | 10/10 (100%) |
| Overall Accuracy | 20/20 (100%) |

### Trigger Analysis

The description's combination of six affirmative trigger phrases and four explicit negative triggers produces a highly discriminating trigger profile. The affirmative triggers cover the full range of how a real user would request this capability — from "assess FedRAMP compliance" (casual) to "run a NIST 800-53 control mapping" (technical) to "FedRAMP ATO readiness" (procurement-context). The negative triggers accurately exclude NIST CSF (which shares "NIST" but is a different framework), ITSG-33, FedRAMP High/Low, and non-AWS environments — all plausible adjacent requests that would otherwise match on partial keywords. One minor ambiguity: a user requesting NIST 800-53 compliance for a hybrid AWS/Azure environment would receive mixed signals (AWS qualifier matches, non-AWS negative trigger also applies); the description does not cover this edge case, but it is low-frequency.

---

## Summary

| Dimension | Score |
|---|---|
| Static Quality (Rubric A) | 4.4/5 |
| Static Quality (Rubric B) | 5.0/5 |
| Trigger Accuracy | 100% (20/20) |

**Benchmark verdict**: `nist-fedramp-assessment` is a high-quality, production-ready skill with exemplary trigger engineering and instruction specificity. The only actionable improvements are minor conciseness optimizations in the Critical Rules section — nothing that would affect correctness or reliability.
