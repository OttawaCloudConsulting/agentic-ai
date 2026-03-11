# Benchmark: cdk-testing

**Date**: 2026-03-06
**Skill version**: unversioned
**Evaluator**: Claude (automated benchmark)

---

## Mode 1 — Static Quality Analysis

### Rubric A: Internal Quality Standards

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Conciseness | 4 | SKILL.md is 113 lines — well under the 500-line limit. The pipeline table is an efficient encoding of 6 steps. Minor bloat: the WARNING in Gate 2 restates information already present in Critical Rules (line 18 explicitly says dev/sandbox only); a cross-reference would suffice. |
| Degrees of Freedom | 5 | Fragile, exact-sequence operations (validation pipeline, deploy command) are locked to low-freedom scripts and specific CLI commands. The commit workflow is correctly offloaded to references/commit-workflow.md with "read this when" guidance. High-freedom decisions (which files to stage, feature naming) are left to the consumer as expected. |
| Progressive Disclosure | 4 | Three-tier structure is correctly implemented: frontmatter triggers, SKILL.md body contains workflow, commit detail lives in references/commit-workflow.md. Gate 3 explicitly says "read references/commit-workflow.md" with clear when-to-read guidance. Minor gap: commit-workflow.md is 68 lines and lacks a table of contents — not required at this size but worth noting for future growth. |
| Structure | 5 | Critical Rules section is at the top (line 11) — highest-risk rules are not buried. Sections follow a logical gate progression (prerequisites → workflow → gate 1 → gate 2 → gate 3 → example → failure handling). Imperative form used throughout ("Run", "Deploy", "Stage", "STOP"). No forbidden files present. |
| Resource Appropriateness | 5 | scripts/cdk-validation.sh holds the deterministic validation logic (appropriate for low-freedom, repeatably executed operations). references/commit-workflow.md holds detailed procedural steps that are long enough to warrant separation and are loaded conditionally. assets/ not present (not needed). |

**Rubric A Score**: 4.6 / 5.0

### Rubric B: Anthropic Best Practices

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Naming | 5 | Folder name `cdk-testing` is kebab-case, lowercase, no spaces or underscores. `name` field in frontmatter matches folder name exactly. SKILL.md is correctly cased. No forbidden prefixes (`claude`, `anthropic`) used. |
| Frontmatter | 5 | Both required fields (`name`, `description`) are present and correctly formed. Optional `compatibility` field is populated with environment requirements (Node.js, npm, AWS CDK CLI, git-secrets, AWS credentials). YAML is valid with correct delimiters. No XML angle brackets in any field. |
| Trigger Quality | 5 | Description includes WHAT (CDK validation, security scanning, build, test, deployment) and WHEN (specific trigger phrases: "test cdk", "validate my cdk", "run cdk checks", "deploy cdk to dev", "/test-cdk"). Negative triggers are present and accurate ("Do NOT use for CDK synth-only workflows, Python CDK projects, or non-CDK TypeScript testing"). Description is well under 1024 characters. |
| Instruction Quality | 5 | Instructions are specific and actionable throughout: exact bash commands with flag explanations, explicit pass criteria for each gate (exit code 0), explicit stop conditions ("STOP. Report which check failed. Do not proceed to Gate 2"). The example section shows a full trigger → result trace. Reference to commit-workflow.md is paired with a precise "when to read" condition (after Gates 1-2 pass). |
| Error Handling | 4 | Failure Handling section covers 5 specific CDK deploy error scenarios (IAM permission, bootstrap required, stack dependency, region mismatch) with recovery commands. Gate failure paths are clearly defined. Minor gap: no documented recovery for the case where git-secrets is not installed (the compatibility field mentions it's optional, but the skill doesn't say what to do when it's absent beyond the script's own auto-skip behavior). |

**Rubric B Score**: 4.8 / 5.0

### Overall Quality Score: 4.7 / 5.0

### Key Findings

- The skill is a strong implementation: concise, well-structured, with appropriate degrees of freedom correctly applied to each gate's fragility level.
- Trigger quality is a standout: the description contains specific user-facing phrases, relevant technology scope, and precise negative triggers — reducing both under-trigger and over-trigger risk.
- Critical Rules at the top of the body (before any workflow content) is the correct pattern for safety-critical instructions like "never use --require-approval never against production."
- The WARNING block in Gate 2 (lines 70-72) duplicates the production safety rule already stated in Critical Rules (line 18). This is minor redundancy — either remove from Gate 2 or remove from Critical Rules, not both.
- The commit-workflow.md reference is well-integrated with explicit conditional load guidance, but the reference file itself has no table of contents — acceptable at 68 lines but worth adding if it grows.

---

## Mode 2 — Trigger Accuracy Testing

The skill's description field:

> Run CDK validation, security scanning, build, test, and deployment. Use when the user asks to test CDK code, validate CDK configurations, run CDK checks, or deploy CDK to a dev environment. Triggers on requests like "test cdk", "validate my cdk", "run cdk checks", "deploy cdk to dev", or "/test-cdk". Handles TypeScript CDK projects with cdk.json and package.json. Do NOT use for CDK synth-only workflows, Python CDK projects, or non-CDK TypeScript testing.

### Test Cases

| # | Prompt | Expected | Predicted | Match | Reasoning |
|---|---|---|---|---|---|
| 1 | "test cdk" | TRIGGER | TRIGGER | YES | Exact trigger phrase listed in description. |
| 2 | "validate my CDK stacks before I push" | TRIGGER | TRIGGER | YES | Matches "validate my cdk" trigger phrase with minor variation. |
| 3 | "run cdk checks on my TypeScript project" | TRIGGER | TRIGGER | YES | Matches "run cdk checks" phrase; TypeScript CDK is the described scope. |
| 4 | "deploy cdk to dev" | TRIGGER | TRIGGER | YES | Exact trigger phrase in description. |
| 5 | "/test-cdk" | TRIGGER | TRIGGER | YES | Exact slash-command trigger listed in description. |
| 6 | "I need to validate my CDK configuration" | TRIGGER | TRIGGER | YES | Matches "validate CDK configurations" use case in description. |
| 7 | "run all my CDK tests and deploy if they pass" | TRIGGER | TRIGGER | YES | Covers test + conditional deploy — both within described scope. |
| 8 | "can you build and test my CDK app?" | TRIGGER | TRIGGER | YES | Build and test are both listed pipeline steps in the description. |
| 9 | "check my CDK code for security issues" | TRIGGER | TRIGGER | YES | Security scanning is explicitly listed as a capability. |
| 10 | "run git-secrets and lint on my CDK project" | TRIGGER | TRIGGER | YES | Security scanning (git-secrets) and validation are described capabilities. |
| 11 | "synthesize my CDK stack to check what will be deployed" | SUPPRESS | SUPPRESS | YES | Description explicitly excludes "CDK synth-only workflows." |
| 12 | "run cdk synth" | SUPPRESS | SUPPRESS | YES | Synth-only workflow is a listed negative trigger. |
| 13 | "test my Python CDK app" | SUPPRESS | SUPPRESS | YES | "Python CDK projects" is listed as a negative trigger. |
| 14 | "validate my Terraform infrastructure" | SUPPRESS | SUPPRESS | YES | Not CDK; description is CDK-specific with no mention of Terraform. |
| 15 | "run CloudFormation stack validation" | SUPPRESS | SUPPRESS | YES | CloudFormation is not CDK testing; description scope does not include it. |
| 16 | "write unit tests for my TypeScript service" | SUPPRESS | SUPPRESS | YES | Non-CDK TypeScript testing is an explicit negative trigger. |
| 17 | "how do I install the AWS CDK?" | SUPPRESS | SUPPRESS | YES | General CDK help question, not a test/validate/deploy workflow request. |
| 18 | "run jest tests for my React app" | SUPPRESS | SUPPRESS | YES | Non-CDK TypeScript testing — explicit negative trigger applies. |
| 19 | "deploy CDK to staging" | SUPPRESS | SUPPRESS | YES | Description specifies dev environment; staging is excluded by implication and the skill's own safety rules — a careful evaluator would suppress. |
| 20 | "run npm audit on my CDK project" | TRIGGER | TRIGGER | YES | npm audit is a listed pipeline step; CDK project context matches the skill's scope. |

### Accuracy Metrics

| Metric | Value |
|---|---|
| True Positive Rate | 10/10 (100%) |
| True Negative Rate | 10/10 (100%) |
| Overall Accuracy | 20/20 (100%) |

### Trigger Analysis

The description achieves high trigger precision by combining three elements: a functional summary (what the skill does), specific user-facing trigger phrases (what people actually say), and explicit negative triggers (what it does not handle). The negative triggers for Python CDK, CDK synth-only, and non-CDK TypeScript testing are the most valuable boundary markers — without them, the skill would over-trigger on adjacent requests. The one ambiguous edge case is "deploy CDK to staging": the description says dev environment, and the skill's Critical Rules reinforce this, but the description does not explicitly say "Do NOT use for staging or production deployments" — adding this negative trigger would close the gap cleanly.

---

## Summary

| Dimension | Score |
|---|---|
| Static Quality (Rubric A) | 4.6/5 |
| Static Quality (Rubric B) | 4.8/5 |
| Trigger Accuracy | 100% (20/20) |

**Benchmark verdict**: cdk-testing is a high-quality, production-ready skill with excellent trigger precision, appropriate use of progressive disclosure and low-freedom scripting for fragile operations, and thorough error handling. The only actionable improvements are removing the duplicated production safety warning in Gate 2 (already covered in Critical Rules) and adding a negative trigger for staging/production deployments to the description.
