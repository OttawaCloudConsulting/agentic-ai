# Architecture and Design: Rules Template Corrective Actions

## Overview

Four corrective actions to rules templates in `rules/`, addressing issues found during validation review. One rename, three new files splitting the defensive protocol into independent disciplines.

## Scope

### Modified
| # | File | Change | Reason |
|---|------|--------|--------|
| 1 | `rules/crossplane-best-practices.md` | Rename to `rules/crossplane-v1-best-practices.md` | Disambiguate v1 vs v2 targeting |

### Created
| # | File | Purpose |
|---|------|---------|
| 2 | `rules/defensive-protocol-v2-anti-slop.md` | Core guardrails: stop on failure, verify cadence, autonomy boundaries |
| 3 | `rules/defensive-protocol-v2-epistemology.md` | Reasoning framework: tiered prediction protocol, investigation methodology |
| 4 | `rules/defensive-protocol-v2-session-management.md` | Session continuity: checkpoints, handoffs, context window awareness |

### Preserved (unchanged)
- `rules/crossplane-v2-best-practices.md`
- `rules/kubernetes-best-practices.md`
- `rules/cdk-best-practices.md`
- `rules/terraform-best-practices.md`
- `rules/defensive-protocol.md` (original v1, kept as reference)

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Rename crossplane file to `crossplane-v1-best-practices.md` | The two crossplane rules target different major versions and should never be used together. Explicit version in filename prevents loading the wrong one. |
| 2 | Split defensive protocol into 3 independent files | Original interleaved critical guardrails with heavy process. Splitting allows consumers to adopt selectively and front-loads the most important content in each file. |
| 3 | Three v2 files are fully independent — no cross-references | Each file must work alone. No mention of sibling files. Consumer can adopt one, two, or all three. |
| 4 | Original `defensive-protocol.md` preserved | Consumers already using v1 are not forced to migrate. Both versions coexist. |
| 5 | Tiered prediction protocol in epistemology file | Routine actions: one-liner intent. High-risk actions: full DOING/EXPECT format. Prevents the "too heavy so ignored entirely" failure mode. |
| 6 | Contextual verification cadence (3 risky / 5 routine) | Fixed cadence of 3 was too heavy for routine work. Contextual model maintains rigor where it matters while reducing overhead on established patterns. |
| 7 | Generic file path references only | Original referenced `agents/memory/`, `agents/investigations/` — paths most consumer projects won't have. V2 files describe *what* to write, not *where*. |
| 8 | Each v2 file is self-contained, decoupled from CLAUDE.md | Rules must function regardless of what defensive protocols (if any) exist in the project's CLAUDE.md. No assumptions about surrounding context. |

## Content Mapping: Original to V2

Shows where each section of `defensive-protocol.md` lands in the v2 split.

| Original Section | V2 File |
|-----------------|---------|
| Core Principle | anti-slop |
| Prediction Protocol | epistemology (tiered) |
| Failure Response | anti-slop |
| Confusion Response | anti-slop |
| Evidence Standards | anti-slop |
| Verification Cadence | anti-slop (count) + session-management (checkpoint mechanism) |
| Context Window Management | session-management |
| Investigation Protocol | epistemology |
| Root Cause Analysis | epistemology |
| Chesterton's Fence | epistemology |
| Error Handling | anti-slop |
| Abstraction Timing | epistemology |
| Autonomy Boundaries | anti-slop |
| Contradiction Handling | anti-slop |
| Pushing Back | anti-slop |
| Handoff Protocol | session-management |
| Second-Order Effects | anti-slop |
| Irreversible Actions | session-management |
| Codebase Navigation | epistemology |
| Stop/Undo/Revert Commands | anti-slop |
| Claude-Specific Guidance | anti-slop |

## File Format Requirements

All rule files must comply with the content model in `CLAUDE.md`:
- Pure markdown, no YAML frontmatter
- Behavioral guidelines, not action-oriented workflows
- One concern per file
- Always-on context — never invoked by the user

## Dependency Order

Features are independent and can be implemented in any order. No feature blocks another.

## Out of Scope
- Modifying rules that passed review (kubernetes, cdk, terraform)
- Changing crossplane-v2-best-practices.md content or size
- Deleting the original defensive-protocol.md
- Any changes to the rules content model or directory structure
