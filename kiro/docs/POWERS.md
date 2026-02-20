# Kiro Powers Reference

Powers are keyword-activated workflow bundles. Each contains a `POWER.md` (metadata + onboarding) and `steering/` files (workflow-specific guidance). Powers activate dynamically when conversation context matches their keywords.

## Installation

Copy the desired power directory into your project and install from local path:

```bash
cp -r kiro/powers/<power-name> <your-project>/.kiro/powers/<power-name>
```

Then in Kiro IDE: Powers panel > Add power from Local Path > select the copied directory.

## Powers

### defensive-protocol

| Field | Value |
|-------|-------|
| Source | `rules/defensive-protocol.md` |
| Keywords | defensive, verification, failure handling, checkpoint, predict |
| Steering | `defensive-protocol.md` |
| Related Steering | — |

Defensive epistemology for agentic coding. Core behavioral framework: prediction protocol (DOING/EXPECT/RESULT), failure response (stop/report/wait), verification cadence (3 actions then checkpoint), context management, autonomy boundaries, Chesterton's fence, and contradiction handling. Enforces safe, observable development practices.

### project-lifecycle

| Field | Value |
|-------|-------|
| Source | `commands/start-feature.md`, `commands/create-prd.md` |
| Keywords | feature, prd, requirements, spec, start feature |
| Steering | `feature-start.md`, `prd-creation.md` |
| Related Steering | — |

Workflows for starting features and creating project requirements. The feature-start workflow reads project tracking, identifies the next pending item, and presents a summary. The prd-creation workflow conducts a structured interview to produce requirements, architecture docs, and feature tracking.

### terraform-workflow

| Field | Value |
|-------|-------|
| Source | `commands/test-terraform.md`, `commands/update-docs-terraform.md` |
| Keywords | terraform plan, terraform apply, tfvars, terraform test |
| Steering | `terraform-validation.md`, `terraform-docs-update.md` |
| Related Steering | `terraform-best-practices.md` |

Terraform validation, deployment, and documentation refresh. The validation workflow runs sequential gates (git-secrets through apply). The docs workflow synchronizes README and architecture docs with the current codebase.

### cdk-workflow

| Field | Value |
|-------|-------|
| Source | `commands/test-cdk.md`, `commands/update-docs-cdk.md` |
| Keywords | cdk deploy, cdk synth, cdk test |
| Steering | `cdk-validation.md`, `cdk-docs-update.md` |
| Related Steering | `cdk-best-practices.md` |

CDK validation, deployment, and documentation refresh. The validation workflow runs a pre-commit script and CDK deploy. The docs workflow synchronizes README, architecture, and testing docs.

### compliance

| Field | Value |
|-------|-------|
| Source | `commands/compliance-assess.md`, `commands/compliance-auto-assess.md` |
| Keywords | compliance, ITSG-33, CCCS, security controls |
| Steering | `interactive-assessment.md`, `automated-assessment.md` |
| Related Steering | — |

ITSG-33 / CCCS Medium Cloud Profile compliance assessment. The interactive workflow runs a multi-phase assessment (discovery, control mapping, gap analysis) with user checkpoints between phases. The automated workflow dispatches the full assessment as a background task.

### documentation

| Field | Value |
|-------|-------|
| Source | `commands/update-docs.md` |
| Keywords | update docs, refresh readme, documentation |
| Steering | `docs-refresh.md` |
| Related Steering | — |

Generic documentation refresh. Synchronizes README and architecture docs with codebase state. For Terraform or CDK projects, use the tech-specific workflow powers instead.

### investigation

| Field | Value |
|-------|-------|
| Source | `commands/investigate.md` |
| Keywords | debug, investigate, troubleshoot |
| Steering | `structured-debugging.md` |
| Related Steering | `defensive-protocol.md` |

Structured debugging workflow. Creates investigation records separating facts from theories, maintains 3+ competing hypotheses, and tracks systematic testing. Complements the defensive-protocol steering file's investigation and failure handling guidance.

### terraform-testing

| Field | Value |
|-------|-------|
| Source | `skills/terraform-testing/SKILL.md` |
| Keywords | terraform validate, tflint, checkov, trivy |
| Steering | `validation-pipeline.md` |
| Related Steering | `terraform-best-practices.md` |

Portable Terraform validation and deployment pipeline. Configurable via `.test-terraform.conf`. Supports validate-only, plan, deploy, and deploy-destroy modes. Auto-detects OS and installs missing tools.
