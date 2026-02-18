---
name: "investigation"
displayName: "Investigation"
description: "Structured debugging workflow separating facts from theories with systematic hypothesis testing"
keywords: ["debug", "investigate", "troubleshoot"]
---

# Investigation Power

Provides a structured debugging workflow for tracking down root causes of errors, failures, and unexpected behavior. Separates verified facts from unverified theories, maintains multiple competing hypotheses, and records every test performed.

## Available Workflows

### Structured Debugging
Create and maintain an investigation record when debugging an unknown issue. Systematically work through hypotheses, record findings, and document the resolution.

See `steering/structured-debugging.md` for the complete workflow.

## Onboarding

When first activated:
1. Identify the symptom, location, and when the issue started
2. Choose a project-appropriate location for investigation records (e.g., `docs/investigations/`, `agents/investigations/`, or similar)
3. Create the investigation file and begin systematic analysis
