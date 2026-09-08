# Epic {{epic-id}}: {{epic-title}}

## Traceability

- **Parent:** {{portfolio-theme-or-none}}
- **Source artifacts:**
  - `{{path-to-prd}}` -- scope and goals
  - `{{path-to-architecture-doc}}` -- design decisions and component inventory
  - `{{path-to-progress}}` -- milestone index and gate state
- **Children:** {{count}} Features, listed in [Child Features](#child-features)
- **Work item set:** `{{workitems-dir}}`

## Work Item Fields

### Core

| Field | Value |
|-------|-------|
| Work Item Type | Epic |
| ID / Key | {{tracker-id-or-TBD}} |
| Title | {{epic-title}} |
| Parent | {{portfolio-epic-theme-or-none}} |
| State | {{state}} |
| State Category | {{Proposed / In Progress / Resolved / Complete / Removed}} |
| Assignee / Owner | {{owner}} |
| Team / Area Path | {{team-or-area-path}} |
| Target Release / PI | {{release-or-program-increment}} |
| Priority | {{1-4 or High/Medium/Low}} |
| Tags / Labels | {{comma-separated}} |

### Planning and Value

| Field | Value |
|-------|-------|
| Value Area | {{Business or Architectural}} |
| Business Value | {{score-or-scale}} |
| Time Criticality | {{score-or-scale}} |
| Risk Reduction / Opportunity Enablement | {{score-or-scale}} |
| Job Size | {{score-or-scale}} |
| WSJF | {{(BV + TC + RROE) / Job Size, or TBD}} |
| Effort / Size | {{story-points, t-shirt, or person-days}} |
| Start Date | {{YYYY-MM-DD}} |
| Target Date | {{YYYY-MM-DD}} |
| Risk | {{High / Medium / Low}} |
| Confidence | {{High / Medium / Low}} |

### Governance and Custom

| Field | Value |
|-------|-------|
| Requestor / Sponsor | {{name-and-role}} |
| Cost Center / Budget Code | {{code}} |
| Funding Type | {{capex / opex / not tracked}} |
| Compliance Scope | {{none, or named regime}} |
| Data Classification | {{public / internal / confidential / restricted}} |
| Environments Impacted | {{dev / staging / prod / all}} |
| Security Review Required | {{yes / no}} |
| Architecture Review Required | {{yes / no}} |
| Documentation Impact | {{yes / no}} |
| External Dependency | {{yes -- named below / no}} |

## Summary

{{One paragraph. What this Epic delivers and why it exists. Readable by someone
with no prior context on the project.}}

## Business Context

{{The problem or opportunity driving the Epic. Who is affected, what the current
state costs, what evidence supports that. Cite the source of any number.}}

## Epic Hypothesis

For {{target-user-or-system}}
who {{need-or-pain}},
the {{solution-name}} is a {{solution-category}}
that {{primary-benefit}}.
Unlike {{current-state-or-alternative}},
this Epic {{key-differentiator}}.

**Business outcomes:** {{what changes in the business or platform if this succeeds}}
**Leading indicators:** {{early signals observable before the Epic completes}}
**Success measures:** {{metric, current value, target value, measurement method}}

## Goal

{{The outcome, stated so it can be judged true or false. Not a list of activities.}}

## MVP and Scope

**Minimum viable increment:** {{the smallest deliverable that tests the hypothesis}}

**In scope:**

- {{item}}

**Out of scope:**

- {{item}} -- {{why, and where it lands instead if anywhere}}

**Exit criteria for the MVP:** {{what evidence decides persevere or pivot}}

## Acceptance Criteria

{{Epic-level and verifiable. Each line names what is checked and what evidence
settles it. Not a restatement of the child Features.}}

- [ ] {{criterion}}
- [ ] {{criterion}}

## Child Features

| ID | Feature | Outcome | Milestone artifact | Size | Depends on |
|----|---------|---------|--------------------|------|------------|
| {{FEAT-NN}} | {{feature-title}} | {{what is true when done}} | `{{milestone-path}}` | {{size}} | {{none or FEAT-NN}} |

## Sequencing

{{The order the Features run in and why. Name what is parallelizable and what is
strictly serial, with the constraint that forces the order.}}

## Dependencies

| Dependency | Type | Owner | Needed by | Status |
|------------|------|-------|-----------|--------|
| {{what}} | {{internal / external / team}} | {{who}} | {{when}} | {{state}} |

## Assumptions and Constraints

**Assumptions:**

- {{assumption}} -- {{what breaks if it is false}}

**Constraints:**

- {{constraint}} -- {{source: policy, platform, contract, budget}}

## Risks

| Risk | Impact | Likelihood | Mitigation | Owner |
|------|--------|------------|------------|-------|
| {{risk}} | {{H/M/L}} | {{H/M/L}} | {{action}} | {{who}} |

## Non-Functional Requirements

| Category | Requirement | How it is verified |
|----------|-------------|--------------------|
| Performance | {{target}} | {{method}} |
| Availability | {{target}} | {{method}} |
| Security | {{requirement}} | {{method}} |
| Observability | {{signal to emit}} | {{method}} |
| Cost | {{budget or ceiling}} | {{method}} |
| Data retention | {{policy}} | {{method}} |

## Architecture Notes

{{Design direction and the decisions already settled at Epic level. Name what is
decided, what is deferred to Feature planning, and cite the architecture document
for each.}}

## Rollout and Release

| Aspect | Plan |
|--------|------|
| Release strategy | {{big bang / phased / flag-gated / canary}} |
| Migration or backfill | {{required steps, or none}} |
| Rollback | {{procedure and trigger}} |
| Decommission | {{what the Epic replaces and when it is switched off}} |
| Communication | {{who is told, when, by what channel}} |

## Definition of Ready

- [ ] Business outcomes and success measures stated and measurable
- [ ] MVP defined with explicit exit criteria
- [ ] Child Features identified and sized at least coarsely
- [ ] Dependencies identified with owners
- [ ] Non-functional requirements stated or explicitly marked not applicable
- [ ] {{project-specific gate}}

## Definition of Done

- [ ] All child Features closed
- [ ] All acceptance criteria verified with evidence recorded
- [ ] Success measures reported against their targets
- [ ] Non-functional requirements verified
- [ ] Documentation updated
- [ ] Deployed to {{target environment}} and confirmed working
- [ ] {{project-specific gate}}

## Open Questions

| # | Question | Blocks | Owner | Needed by |
|---|----------|--------|-------|-----------|
| 1 | {{question}} | {{what it blocks}} | {{who}} | {{when}} |

## References

- {{link or path}} -- {{what it establishes}}
