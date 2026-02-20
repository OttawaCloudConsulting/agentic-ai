---
name: "compliance"
displayName: "Compliance Assessment"
description: "ITSG-33 / CCCS Medium Cloud Profile compliance assessment with control mapping and gap analysis"
keywords: ["compliance", "ITSG-33", "CCCS", "security controls"]
---

# Compliance Assessment Power

Provides structured workflows for mapping project architecture to ITSG-33 security controls under the CCCS Medium Cloud Profile. Produces phased compliance assessments with AWS shared responsibility inheritance, audit evidence, and risk-rated gap analysis suitable for GC cloud environments.

## Available Workflows

### Interactive Assessment
Multi-phase compliance assessment with user checkpoints between phases. Walks through architecture discovery, control mapping across 8 control families, and gap analysis with remediation guidance. Pauses for user validation at each phase boundary.

See `steering/interactive-assessment.md` for the complete workflow.

### Automated Assessment
Dispatch a full end-to-end assessment that runs all phases without stopping. Useful for baseline assessments or CI-driven compliance checks where interactive review is not needed.

See `steering/automated-assessment.md` for the complete workflow.

## Onboarding

When first activated, verify:
1. The workspace contains infrastructure code (CDK, Terraform, CloudFormation, Crossplane, or similar)
2. Check for existing assessment output in `docs/compliance/` before starting fresh
3. If previous assessments exist, offer smart re-run (only changed phases) before starting from scratch
