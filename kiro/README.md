# Kiro Powers & Steering Library

Drop-in Kiro configurations for infrastructure-as-code projects. Contains powers (workflow tools) and steering files (always-on guidance) designed for the Kiro IDE and CLI.

## Structure

```
kiro/
├── powers/                    # Keyword-activated workflow bundles
│   ├── defensive-protocol/    # Defensive coding practices
│   ├── project-lifecycle/     # Feature start, PRD creation
│   ├── terraform-workflow/    # Terraform validation and docs
│   ├── cdk-workflow/          # CDK validation and docs
│   ├── compliance/            # ITSG-33/CCCS compliance assessment
│   ├── documentation/         # Generic documentation refresh
│   ├── investigation/         # Structured debugging
│   └── terraform-testing/     # Terraform validation pipeline
├── steering/                  # Always-on and auto-activated guidance
│   ├── defensive-protocol.md
│   ├── terraform-best-practices.md
│   ├── cdk-best-practices.md
│   ├── kubernetes-best-practices.md
│   ├── crossplane-best-practices.md
│   └── crossplane-v2-best-practices.md
└── docs/
    ├── POWERS.md              # Powers reference guide
    └── STEERING.md            # Steering reference guide
```

## Installing Powers

1. Copy the desired power directory into your project:
   ```
   cp -r kiro/powers/<power-name> <your-project>/.kiro/powers/<power-name>
   ```
2. In Kiro IDE: Powers panel > Add power from Local Path > select the copied directory
3. The power activates automatically when you mention relevant keywords

## Installing Steering Files

Copy desired steering files into your project's `.kiro/steering/` directory:

```
mkdir -p <your-project>/.kiro/steering
cp kiro/steering/<file>.md <your-project>/.kiro/steering/
```

Steering files load automatically based on their inclusion mode:
- `always` — loaded in every interaction
- `auto` — loaded when conversation context matches the file's description

## Recommended Content by Project Type

| Project Type | Powers | Steering |
|-------------|--------|----------|
| Terraform | defensive-protocol, project-lifecycle, terraform-workflow, terraform-testing, documentation, investigation, compliance | terraform-best-practices |
| CDK | defensive-protocol, project-lifecycle, cdk-workflow, documentation, investigation, compliance | cdk-best-practices |
| Kubernetes | defensive-protocol, project-lifecycle, documentation, investigation | kubernetes-best-practices |
| Crossplane | defensive-protocol, project-lifecycle, documentation, investigation | crossplane-best-practices, crossplane-v2-best-practices |

## Relationship to Claude Code Content

This directory contains Kiro-native equivalents of the Claude Code content in the parent repository (`commands/`, `rules/`, `skills/`). The content has been restructured for Kiro's keyword-activated power model and steering inclusion modes. See `docs/POWERS.md` and `docs/STEERING.md` for detailed mapping.
