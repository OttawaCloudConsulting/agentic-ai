---
name: "documentation"
displayName: "Documentation Refresh"
description: "Refresh project documentation to match current codebase state"
keywords: ["update docs", "refresh readme", "documentation"]
---

# Documentation Refresh Power

Provides a generic workflow for refreshing project documentation (readme, architecture docs) to match the current codebase state. Use after completing features, before creating a PR, or when documentation has drifted.

For CDK or Terraform projects, use the technology-specific powers (`cdk-workflow` or `terraform-workflow`) instead — they include documentation update workflows tailored to those stacks.

## Available Workflows

### Documentation Refresh

Update README.md and docs/ARCHITECTURE.md to reflect the current project structure, components, configuration, and dependencies.

See `steering/docs-refresh.md` for the complete workflow.

## Onboarding

When first activated, verify:

1. The workspace has a README.md and/or docs/ARCHITECTURE.md to update
2. Check for `progress.txt` and `CHANGELOG.md` for tracking context
3. Confirm this is not a CDK or Terraform project (use the specific powers for those)
