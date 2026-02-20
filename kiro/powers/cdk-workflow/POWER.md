---
name: "cdk-workflow"
displayName: "CDK Workflow"
description: "AWS CDK validation, deployment, and documentation refresh workflows"
keywords: ["cdk deploy", "cdk synth", "cdk test"]
---

# CDK Workflow Power

Provides end-to-end workflows for AWS CDK projects covering validation, deployment, and documentation maintenance. Activate this power when working on CDK constructs and stacks that need to be validated, deployed, or when documentation has drifted from the current codebase state.

## Available Workflows

### Validate and Deploy

Run sequential validation gates (git-secrets, prettier, eslint, typescript build, security scans) followed by `cdk deploy`, then update tracking and commit.

See `steering/cdk-validation.md` for the complete workflow.

### Documentation Update

Refresh README.md, docs/ARCHITECTURE.md, and docs/TESTING.md to match the current state of CDK stacks, constructs, and test suites. Use after completing features, before creating a PR, or when documentation feels stale.

See `steering/cdk-docs-update.md` for the complete workflow.

## Onboarding

When first activated, verify:

1. The workspace contains `cdk.json`
2. A validation script exists at `scripts/cdk-validation.sh`
3. Check for `progress.txt` and `CHANGELOG.md` for tracking workflows
