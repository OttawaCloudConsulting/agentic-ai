# Benchmark: terraform-testing

**Date**: 2026-03-06
**Skill version**: unversioned
**Evaluator**: Claude (automated benchmark)

---

## Mode 1 — Static Quality Analysis

### Rubric A: Internal Quality Standards

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Conciseness | 4 | SKILL.md is 128 lines — well within the 500-line limit. The pipeline table (lines 78–88) is efficient. The "Prerequisites" section (lines 18–19) adds no information and could be deleted. The output format example (lines 102–113) duplicates what the script itself would print, borderline justified. |
| Degrees of Freedom | 5 | CLI invocations are given as specific bash commands (low freedom, appropriate for a fragile, sequential pipeline). Configuration table and failure handling use medium freedom prose. Critical rules use imperative form at the top. Specificity is well-matched to the task. |
| Progressive Disclosure | 4 | Frontmatter is concise (~70 words). SKILL.md body is lean at 128 lines. No `references/` directory exists, which is fine given the skill's scope. The script itself handles the deterministic logic. No content appears split incorrectly. Minor gap: no explicit "when to read" guidance for the script file — it is referenced directly in invocations, which is adequate but not explicit. |
| Structure | 4 | Sections flow logically: Critical Rules → Prerequisites → Workflow → Running the Script → Configuration → Pipeline Steps → Failure Handling → Output Format → Example. Critical rules appear at the top. Imperative form is used throughout. The "Prerequisites" section is a stub with no actionable content and should either be populated or removed. |
| Resource Appropriateness | 5 | A shell script (`scripts/test-terraform.sh`) is used correctly for the deterministic, sequential pipeline — exactly the right resource type. No references/ directory exists and none is needed given the scope. No forbidden files (README.md, etc.) are present. |

**Rubric A Score**: 4.4 / 5.0

---

### Rubric B: Anthropic Best Practices

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Naming | 5 | Folder name `terraform-testing` is kebab-case, lowercase, no spaces, no underscores, well under 64 characters. The `name` field matches exactly. `SKILL.md` is correctly cased. No forbidden prefixes (`claude`, `anthropic`). |
| Frontmatter | 5 | Both required fields (`name`, `description`) are present and correctly formatted. YAML delimiters are valid. No XML angle brackets in the description. No invalid characters. Optional fields are not used but not required. |
| Trigger Quality | 4 | Description includes what the skill does (validation, security scanning, planning, deployment testing for .tf and .tfvars files) and specific trigger phrases ("test terraform", "validate my terraform", "run terraform checks", "deploy terraform to dev", "/test-terraform"). Negative triggers are present and accurate ("Do NOT use for CloudFormation, Pulumi, CDK, or non-Terraform infrastructure code"). Minor gap: the description does not mention OpenTofu, which is the open-source Terraform fork and a common trigger context; users asking about OpenTofu validation would not trigger this skill. Description is 441 characters — within the 1024-character limit. |
| Instruction Quality | 5 | Instructions are specific and actionable throughout. Exact bash invocations are given for each mode. Configuration options are documented in a table with variable names, purposes, and precedence rules. Failure modes are covered with explicit recovery guidance. Suppression patterns for checkov and trivy are documented inline. The worked example (lines 116–127) shows trigger phrase → action → result. Critical rules are at the top under `## Critical Rules`. |
| Error Handling | 4 | Critical vs. non-critical step distinction is documented in the pipeline table. Failure behavior is explicitly covered: critical failures exit immediately, security scan findings are warnings by default. False positive suppression for both checkov and trivy is documented with inline comment syntax. Minor gap: no guidance on what to do if `terraform init` fails due to provider registry connectivity issues, or if the script itself is missing/not found at the expected path. |

**Rubric B Score**: 4.6 / 5.0

---

### Overall Quality Score: 4.5 / 5.0

### Key Findings

- **Strength — Instruction precision**: Bash invocations are exact and copy-pasteable. Configuration table with precedence order (`CLI > env > config file > defaults`) is a high-value addition that prevents common misconfiguration errors.
- **Strength — Trigger design**: Negative triggers are accurate and well-scoped. The description correctly prevents false positives from CDK, CloudFormation, Pulumi, and Ansible users.
- **Strength — Appropriate use of scripts**: Deterministic pipeline logic lives in `scripts/test-terraform.sh`, keeping SKILL.md lean and following the low-freedom resource pattern correctly.
- **Weakness — OpenTofu gap**: The skill description and body do not mention OpenTofu (the open-source Terraform fork). Users working with `tofu` commands would not trigger this skill. This is a growing use case that warrants explicit mention.
- **Weakness — Stub section**: The "Prerequisites" section (lines 18–19) contains only "Before running, ensure Terraform code is ready for validation." — this is content-free and adds no value. It should either document actual prerequisites (Terraform installed, AWS credentials configured, etc.) or be removed entirely.

---

## Mode 2 — Trigger Accuracy Testing

The skill's description field (used for trigger evaluation):

> Run Terraform validation, security scanning, planning, and deployment testing for .tf and .tfvars files. Use when the user asks to test Terraform code, validate Terraform configurations, run Terraform checks, or deploy Terraform to a dev environment. Triggers on requests like "test terraform", "validate my terraform", "run terraform checks", "deploy terraform to dev", or "/test-terraform". Do NOT use for CloudFormation, Pulumi, CDK, or non-Terraform infrastructure code.

### Test Cases

| # | Prompt | Expected | Predicted | Match | Reasoning |
|---|---|---|---|---|---|
| 1 | "test my terraform" | TRIGGER | TRIGGER | YES | Exact match to listed trigger phrase "test terraform". |
| 2 | "validate my terraform" | TRIGGER | TRIGGER | YES | Exact match to listed trigger phrase "validate my terraform". |
| 3 | "run terraform checks on the networking module" | TRIGGER | TRIGGER | YES | Matches "run terraform checks" with an appended qualifier. |
| 4 | "deploy terraform to dev" | TRIGGER | TRIGGER | YES | Exact match to listed trigger phrase. |
| 5 | "can you validate my .tf files before I push?" | TRIGGER | TRIGGER | YES | Mentions .tf files and validate — both in the description. |
| 6 | "run checkov on my terraform code" | TRIGGER | TRIGGER | YES | Checkov is a listed pipeline step; "terraform code" maps to skill scope. |
| 7 | "I need to run tflint against my infrastructure configs" | TRIGGER | TRIGGER | YES | tflint is listed in the pipeline steps in the SKILL.md description context; "terraform" implied by tflint usage. Borderline but likely triggers. |
| 8 | "validate and plan my terraform before we merge this PR" | TRIGGER | TRIGGER | YES | "validate" and "terraform" are both present; matches core use case. |
| 9 | "/test-terraform" | TRIGGER | TRIGGER | YES | Explicit trigger phrase listed in description. |
| 10 | "run security scanning on my .tfvars files" | TRIGGER | TRIGGER | YES | .tfvars files are explicitly mentioned in the description. |
| 11 | "how do I deploy my CloudFormation stack?" | SUPPRESS | SUPPRESS | YES | CloudFormation is explicitly listed in negative triggers. |
| 12 | "validate my Pulumi program" | SUPPRESS | SUPPRESS | YES | Pulumi is explicitly listed in negative triggers. |
| 13 | "help me write a new Terraform module for S3" | SUPPRESS | SUPPRESS | YES | Writing new Terraform code is not testing/validation; description scopes to testing/validation/deployment. |
| 14 | "what is the best way to structure Terraform variables?" | SUPPRESS | SUPPRESS | YES | General Terraform question — not testing or validation. No trigger phrase match. |
| 15 | "run CDK synth and deploy my stack" | SUPPRESS | SUPPRESS | YES | CDK is explicitly listed in negative triggers. |
| 16 | "help me debug why my Ansible playbook isn't idempotent" | SUPPRESS | SUPPRESS | YES | Ansible is covered by "non-Terraform infrastructure code" negative trigger. |
| 17 | "can you review my terraform.tfstate file for drift?" | SUPPRESS | SUPPRESS | YES | State file review is not validation/testing of .tf code; description scopes to .tf and .tfvars files. |
| 18 | "test my Python unit tests in pytest" | SUPPRESS | SUPPRESS | YES | Non-infrastructure testing; no Terraform context. |
| 19 | "validate my ARM template for Azure" | SUPPRESS | SUPPRESS | YES | ARM templates are non-Terraform; covered by "non-Terraform infrastructure code" negative trigger. |
| 20 | "run terraform init and show me what providers get installed" | SUPPRESS | SUPPRESS | YES | This is a Terraform exploration/information request, not a testing/validation workflow trigger. Borderline — could over-trigger since "terraform init" is a pipeline step, but description scopes to testing/validation/deployment patterns. Predicted suppress with low confidence. |

### Accuracy Metrics

| Metric | Value |
|---|---|
| True Positive Rate | 10/10 (100%) |
| True Negative Rate | 10/10 (100%) |
| Overall Accuracy | 20/20 (100%) |

### Trigger Analysis

The description performs well across all 20 test cases. The combination of explicit trigger phrases ("test terraform", "validate my terraform", "/test-terraform"), file type mentions (.tf, .tfvars), and a targeted negative trigger list (CloudFormation, Pulumi, CDK) creates a precise and discriminative description. The one genuine ambiguity is case #20 — a `terraform init` inquiry — which sits at the boundary between exploratory Terraform use and the testing pipeline; in practice, model behavior could go either way. The most significant coverage gap is OpenTofu: a user asking to "test my opentofu config" or "validate my tofu files" would likely not trigger this skill, despite OpenTofu being functionally identical to Terraform for this pipeline's purposes.

---

## Summary

| Dimension | Score |
|---|---|
| Static Quality (Rubric A) | 4.4/5 |
| Static Quality (Rubric B) | 4.6/5 |
| Trigger Accuracy | 100% (20/20) |

**Benchmark verdict**: `terraform-testing` is a well-structured, production-quality skill with precise trigger design and actionable instructions. The two concrete improvement targets are: (1) replace or remove the content-free "Prerequisites" section, and (2) add OpenTofu coverage to the description and body to capture the growing fork userbase.
