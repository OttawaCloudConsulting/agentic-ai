# Benchmark: itsg-assessment

**Date**: 2026-03-06
**Skill version**: unversioned
**Evaluator**: Claude (automated benchmark)

---

## Mode 1 — Static Quality Analysis

### Rubric A: Internal Quality Standards

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Conciseness | 4 | The skill is lean and purposeful — every section earns its place. The Phase 1 detection tables (lines 74–94) are efficient. Minor redundancy: "Before writing, read `references/phase-templates.md`" appears three times (lines 45, 103, 123, 131) — a single "Before writing any phase output, read `references/phase-templates.md`" in the Output section (which already exists on line 45) renders the per-phase repetitions slightly redundant. |
| Degrees of Freedom | 4 | High-freedom phases (discovery, control mapping) are correctly left open with guidance rather than scripts. Low-freedom rules (evidence citation, inheritance classification, data residency defaults) are appropriately locked down in the Important Rules section. The detection table at Phase 1.1 correctly uses medium freedom — preferred patterns listed, not hardcoded scripts. Could be stronger by specifying exact search commands for the Phase 1.2 patterns. |
| Progressive Disclosure | 5 | SKILL.md is 155 lines — well under the 500-line limit. Heavy content (control tables, output templates, official URLs) is correctly offloaded to three reference files. Each reference is cited with explicit "when to read" guidance (lines 152–154). Reference files are one level deep. The three-tier loading model is correctly implemented. |
| Structure | 4 | Clear sequential workflow with named phases. Important Rules appear near the top (line 10). Example is concrete and shows all phases (lines 27–33). Imperative form used throughout. Minor gap: the "Smart Re-run" section (line 47) sits between the Output section and Phase 0 — it would read more naturally before Phase 0 or as a sub-section of it. |
| Resource Appropriateness | 5 | Three reference files serve distinct, non-overlapping purposes: control data (`itsg33-controls.md`), output templates (`phase-templates.md`), and validation URLs (`official-references.md`). No scripts — appropriate, since the workflow is investigative/analytical rather than deterministic. No assets — correct for this skill type. No forbidden files detected. |

**Rubric A Score**: 4.4 / 5.0

### Rubric B: Anthropic Best Practices

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Naming | 5 | `itsg-assessment` is kebab-case, lowercase, no spaces or underscores, 15 characters (well under 64). The `name` field in frontmatter matches the folder name. `SKILL.md` is correctly cased. No forbidden prefixes (`claude`, `anthropic`) used. |
| Frontmatter | 5 | Both required fields (`name`, `description`) are present and correct. No XML angle brackets. Description is approximately 540 characters — under the 1024-character limit. No forbidden files (README.md, CHANGELOG.md) present in the skill folder. |
| Trigger Quality | 4 | Description includes what the skill does AND specific trigger phrases ("assess ITSG", "run a CCCS Medium compliance check", "evaluate Canadian cloud compliance", "map ITSG-33 controls", "perform a GC cloud security assessment", "check Protected B data handling requirements"). Negative triggers are present and accurate ("Do NOT use for FedRAMP, NIST CSF, SOC 2, or non-Canadian compliance frameworks"). Minor gap: "ISO 27001" is not listed in the negative triggers, creating a potential false positive for ISO assessments in Canadian GC contexts. |
| Instruction Quality | 5 | Instructions are specific and actionable throughout. Phase 1.2 provides exact search categories and patterns per IaC type. Error handling is documented in a dedicated table. Each reference file has explicit "when to read" guidance. Phase checkpoints include specific questions to ask the user. The example (lines 27–33) demonstrates core use case with phase-by-phase actions and outputs. Critical rules appear at the top under "## Important Rules". |
| Error Handling | 5 | The Error Handling table (lines 140–148) covers five distinct failure modes with specific, unambiguous actions: network failure (skip + report + proceed), missing IaC (report + ask), missing docs (proceed with reduced confidence + note), ambiguous status (mark Partially Implemented + flag), and empty project (report + ask). Phase 0 failure fallback (line 65) is particularly well-specified — it names the exact fallback message to emit. |

**Rubric B Score**: 4.8 / 5.0

### Overall Quality Score: 4.6 / 5.0

### Key Findings

- The progressive disclosure implementation is excellent — 155 lines in SKILL.md with three purpose-specific reference files, each cited with explicit "when to read" guidance.
- Error handling is a standout strength: five failure modes covered with specific, unambiguous fallback actions including an exact message string for the Phase 0 network failure case.
- "Before writing, read `references/phase-templates.md`" is repeated three times (Output section + Phase 1.4 + Phase 2 + Phase 3) — this is redundant given the Output section already establishes this rule; the per-phase repetitions add token cost without adding clarity.
- The negative triggers in the description omit ISO 27001, which could cause the skill to incorrectly trigger on ISO 27001 assessments for Canadian GC environments where ITSG-33 alignment is sometimes discussed alongside ISO.
- The "Smart Re-run" section placement (between Output and Phase 0) breaks the natural reading flow; it would be more logical as a pre-check step inside Phase 0 or as an introductory step before any phase begins.

---

## Mode 2 — Trigger Accuracy Testing

The description field being evaluated:

> Map project architecture to ITSG-33 / CCCS Medium Cloud Profile security controls for Canadian GC cloud workloads handling Protected B data. Produces a phased compliance assessment with AWS control inheritance and risk-rated gap analysis. Use when asked to assess ITSG, run a CCCS Medium compliance check, evaluate Canadian cloud compliance, map ITSG-33 controls, perform a GC cloud security assessment, or check Protected B data handling requirements. Do NOT use for FedRAMP, NIST CSF, SOC 2, or non-Canadian compliance frameworks.

### Test Cases

| # | Prompt | Expected | Predicted | Match | Reasoning |
|---|---|---|---|---|---|
| 1 | "Run an ITSG-33 compliance assessment on this CDK project" | TRIGGER | TRIGGER | YES | Exact trigger phrase "assess ITSG" / "ITSG-33" present in description. |
| 2 | "Can you check if our GC cloud workload meets CCCS Medium requirements?" | TRIGGER | TRIGGER | YES | "CCCS Medium compliance check" is an explicit trigger phrase. |
| 3 | "We need to evaluate our Protected B data handling for Canadian compliance" | TRIGGER | TRIGGER | YES | "check Protected B data handling requirements" is a direct trigger phrase match. |
| 4 | "Map our Terraform infrastructure to ITSG-33 controls" | TRIGGER | TRIGGER | YES | "map ITSG-33 controls" is an explicit trigger phrase. |
| 5 | "Do a GC cloud security assessment for our AWS environment" | TRIGGER | TRIGGER | YES | "perform a GC cloud security assessment" is an explicit trigger phrase. |
| 6 | "We're deploying to AWS Canada and need to check compliance for Protected B data" | TRIGGER | TRIGGER | YES | "Protected B data" + "Canadian" GC context matches description scope directly. |
| 7 | "Assess our CCCS Medium Cloud Profile alignment for this CloudFormation stack" | TRIGGER | TRIGGER | YES | "CCCS Medium Cloud Profile" is central to the description, strong signal. |
| 8 | "Run a Canadian cloud compliance check on our workload" | TRIGGER | TRIGGER | YES | "evaluate Canadian cloud compliance" is an explicit trigger phrase. |
| 9 | "I need a phased ITSG compliance review with gap analysis" | TRIGGER | TRIGGER | YES | "ITSG" + "gap analysis" both appear in the description, clear match. |
| 10 | "Check our ca-central-1 deployment against ITSG-33 Annex 3A controls" | TRIGGER | TRIGGER | YES | "ITSG-33" + Canadian region context; description explicitly covers this domain. |
| 11 | "Run a FedRAMP authorization assessment for our AWS environment" | SUPPRESS | SUPPRESS | YES | "Do NOT use for FedRAMP" is an explicit negative trigger. |
| 12 | "Assess our SOC 2 Type II compliance posture" | SUPPRESS | SUPPRESS | YES | "Do NOT use for... SOC 2" is an explicit negative trigger. |
| 13 | "Map our controls to NIST CSF tiers" | SUPPRESS | SUPPRESS | YES | "Do NOT use for NIST CSF" is an explicit negative trigger. |
| 14 | "Do a security review of our Node.js API — check for OWASP Top 10 issues" | SUPPRESS | SUPPRESS | YES | General security code review with no Canadian compliance or ITSG framing; description is domain-specific. |
| 15 | "Evaluate our ISO 27001 compliance readiness" | SUPPRESS | TRIGGER | NO | ISO 27001 is not listed in the negative triggers; description says "non-Canadian compliance frameworks" but ISO 27001 can apply to Canadian GC environments, creating ambiguity. |
| 16 | "Review our AWS architecture for security best practices" | SUPPRESS | SUPPRESS | YES | Generic security review with no Canadian compliance context; description requires ITSG/CCCS/GC framing. |
| 17 | "We need a NIST SP 800-53 control mapping for our cloud workload" | SUPPRESS | SUPPRESS | YES | NIST SP 800-53 is a US framework; description scope is explicitly Canadian and ITSG-33. |
| 18 | "Perform a PCI-DSS gap analysis on our payment processing system" | SUPPRESS | SUPPRESS | YES | PCI-DSS is not mentioned and is outside the Canadian GC compliance framing; strong suppression. |
| 19 | "Check our on-premises datacenter security controls" | SUPPRESS | SUPPRESS | YES | Description explicitly scopes to "cloud workloads"; on-premises assessment would not trigger. |
| 20 | "We need to pass our SOX IT audit — review our access controls" | SUPPRESS | SUPPRESS | YES | SOX/financial audit context with no Canadian GC or ITSG framing; clear suppression. |

### Accuracy Metrics

| Metric | Value |
|---|---|
| True Positive Rate | 10/10 (100%) |
| True Negative Rate | 9/10 (90%) |
| Overall Accuracy | 19/20 (95%) |

### Trigger Analysis

The description is well-constructed for triggering: it includes six concrete trigger phrases that map to realistic user language ("assess ITSG", "run a CCCS Medium compliance check", "evaluate Canadian cloud compliance", "map ITSG-33 controls", "perform a GC cloud security assessment", "check Protected B data handling requirements"), covering the full range of how a GC compliance practitioner would frame a request. The negative triggers effectively suppress FedRAMP, NIST CSF, and SOC 2 — the most common overlapping frameworks. The single gap is the absence of ISO 27001 from the negative trigger list: the phrase "non-Canadian compliance frameworks" is ambiguous since ISO 27001 is used in Canadian GC contexts, and without an explicit negative trigger, the skill may incorrectly activate for ISO assessments that mention Canadian data or AWS.

---

## Summary

| Dimension | Score |
|---|---|
| Static Quality (Rubric A) | 4.4/5 |
| Static Quality (Rubric B) | 4.8/5 |
| Trigger Accuracy | 95% (19/20) |

**Benchmark verdict**: `itsg-assessment` is a high-quality skill with excellent progressive disclosure, strong error handling, and reliable triggering for its intended domain. The primary actionable improvements are: deduplicate the `phase-templates.md` read instruction across phases, and add ISO 27001 to the negative triggers in the description.
