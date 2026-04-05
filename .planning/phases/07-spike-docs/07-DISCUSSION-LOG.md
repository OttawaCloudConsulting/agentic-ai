# Phase 7: /spike + Docs - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-03
**Phase:** 07-spike-docs
**Areas discussed:** Research & red-team flow, Spike invocation UX, Spike artifact structure, Documentation gap audit

---

## Research & red-team flow

| Option | Description | Selected |
|--------|-------------|----------|
| Sequential | Research agent completes first, then red-team reviews findings | :heavy_check_mark: |
| Parallel with synthesis | Both agents run simultaneously, Claude synthesizes | |
| Iterative rounds | Research -> red-team -> research responds -> final synthesis | |

**User's choice:** Sequential
**Notes:** Ensures red-team has full context to challenge research findings. Matches SPIKE-01/02 ordering.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Final artifact only | Research + red-team run autonomously, user sees completed doc | :heavy_check_mark: |
| Research summary first | Show research findings before spawning red-team | |
| Both checkpoints | Show research, then red-team, then final artifact | |

**User's choice:** Final artifact only
**Notes:** Fastest flow, minimal interaction.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, full tooling | Red-team can independently verify claims, find counter-evidence | :heavy_check_mark: |
| Read-only (no web) | Red-team only reads research output and codebase | |
| You decide | Claude decides based on topic | |

**User's choice:** Yes, full tooling
**Notes:** Makes adversarial review credible with independent verification capability.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Comprehensive | Factual errors, missing alternatives, flawed reasoning, unverified assumptions | :heavy_check_mark: |
| Focused on risks | Primarily challenge risk assessment and missing failure modes | |
| Devil's advocate | Argue the opposite position regardless | |

**User's choice:** Comprehensive
**Notes:** Matches SPIKE-02 spec.

---

## Spike invocation UX

| Option | Description | Selected |
|--------|-------------|----------|
| Question + tooling list | Per SPIKE-01: user provides research question and available tooling | :heavy_check_mark: |
| Question only | User provides question, /spike auto-discovers tooling | |
| Interactive interview | Brief 2-3 question interview to refine scope | |

**User's choice:** Question + tooling list
**Notes:** Focused scope, clear artifact.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Add on creation, resolve on signal | Add [ ] entry when created, [x] when user signals resolved | :heavy_check_mark: |
| Add on creation only | Add entry, user manually edits to resolve | |
| You decide | Claude decides state management approach | |

**User's choice:** Add on creation, resolve on signal
**Notes:** Clean lifecycle per SPIKE-04/06.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Append new research round | Re-run research + red-team, append to Follow-Up Log | :heavy_check_mark: |
| Lightweight append only | User provides findings manually, appended to log | |
| Full re-evaluation | Re-run both agents with all context, update Recommendation | |

**User's choice:** Append new research round
**Notes:** Per SPIKE-05, offers resolution after each follow-up.

---

| Option | Description | Selected |
|--------|-------------|----------|
| progress.txt must exist | Requires bootstrapped project (Phase 1 only) | :heavy_check_mark: |
| No prerequisites | Works without progress.txt | |
| Gate 2 approved | Requires design to be done first | |

**User's choice:** progress.txt must exist
**Notes:** Spikes can happen anytime in the pipeline lifecycle.

---

## Spike artifact structure

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed sections per SPIKE-03 | Question, Tooling, Methodology, Findings, Red-Team, Recommendation, Status, Follow-Up Log | :heavy_check_mark: |
| Flexible with required minimum | Require core sections, others optional | |
| Template with optional deep-dives | Fixed core plus optional appendices | |

**User's choice:** Fixed sections per SPIKE-03
**Notes:** Consistent and scannable.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Equal peer section | Red-Team Assessment at same level as Findings | :heavy_check_mark: |
| Inline annotations | Red-team challenges within Findings section | |
| Separate verdict block | Structured Confirmed/Challenged/Refuted per finding | |

**User's choice:** Equal peer section
**Notes:** Per SPIKE-01/02: two perspectives are never merged or suppressed.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Clear pick with rationale | State recommended approach, why, and remaining risks | :heavy_check_mark: |
| Ranked options | List all viable options ranked by fit | |
| You decide | Claude decides format based on whether clear winner exists | |

**User's choice:** Clear pick with rationale
**Notes:** Actionable — user can act on it or disagree.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Dated entries with findings + red-team | Each follow-up appends date, question, new findings, new red-team | :heavy_check_mark: |
| Simple dated notes | Date, question, brief summary | |
| You decide | Claude decides within SPIKE-05 constraints | |

**User's choice:** Dated entries with findings + red-team
**Notes:** Complete audit trail.

---

## Documentation gap audit

| Option | Description | Selected |
|--------|-------------|----------|
| Create /spike docs + verify others | Write spike.md, audit existing 6 docs for compliance, fix gaps | :heavy_check_mark: |
| Create /spike docs only | Only write new spike documentation | |
| Full rewrite pass | Rewrite all 7 detail docs for consistency | |

**User's choice:** Create /spike docs + verify others
**Notes:** Balanced approach — new docs plus compliance verification.

---

| Option | Description | Selected |
|--------|-------------|----------|
| /project has SKILL.md already | Router SKILL.md exists, create spike/SKILL.md, verify all 7 | :heavy_check_mark: |
| You decide | Claude audits and fills gaps | |

**User's choice:** /project has SKILL.md already
**Notes:** Phase 7 creates skills/project/spike/SKILL.md.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, same pattern | Purpose, When to Use, When NOT to Use, Behavior, Artifacts, Skill Files, Related Skills | :heavy_check_mark: |
| Adapted for research tool | Adjusted sections for research-oriented skill | |
| You decide | Claude decides based on usefulness | |

**User's choice:** Yes, same pattern
**Notes:** Consistent with build.md, plan.md, etc.

---

## Claude's Discretion

- Research agent prompt design and methodology approach
- Red-team agent prompt design and challenge structure
- Sub-agent tooling configuration
- Topic slug generation for file naming
- Follow-up mode detection (existing spike file check)
- Spike section format details in progress.txt
- Internal agent orchestration approach
- Edge case handling (no tooling listed, ambiguous questions)
- Documentation audit verification approach

## Deferred Ideas

None — discussion stayed within phase scope.
