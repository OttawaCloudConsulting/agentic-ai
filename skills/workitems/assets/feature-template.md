# Feature {{feature-id}}: {{feature-title}}

## Traceability

- **Epic:** {{epic-id}} -- {{epic-title}} (`{{relative-path-to-epic-doc}}`)
- **Parent:** {{epic-id}}
- **Source artifact:** `{{milestone-readme-path}}` -- Milestone {{NN}}: {{milestone-name}}
- **Children:** {{count}} Stories, listed in [Child Stories](#child-stories)

## Work Item Fields

### Core

| Field | Value |
|-------|-------|
| Work Item Type | Feature |
| ID / Key | {{tracker-id-or-TBD}} |
| Title | {{feature-title}} |
| Parent | {{epic-id}} -- {{epic-title}} |
| State | {{state}} |
| State Category | {{Proposed / In Progress / Resolved / Complete / Removed}} |
| Assignee / Owner | {{owner}} |
| Team / Area Path | {{team-or-area-path}} |
| Iteration / Sprint | {{iteration-or-sprint}} |
| Target Release | {{release-or-fix-version}} |
| Priority | {{1-4 or High/Medium/Low}} |
| Tags / Labels | {{comma-separated}} |

### Planning and Value

| Field | Value |
|-------|-------|
| Value Area | {{Business or Architectural}} |
| Business Value | {{score-or-scale}} |
| Time Criticality | {{score-or-scale}} |
| Effort / Size | {{story-points, t-shirt, or person-days}} |
| Start Date | {{YYYY-MM-DD}} |
| Target Date | {{YYYY-MM-DD}} |
| Risk | {{High / Medium / Low}} |
| Confidence | {{High / Medium / Low}} |

### Governance and Custom

| Field | Value |
|-------|-------|
| Requestor / Stakeholder | {{name-and-role}} |
| Cost Center / Budget Code | {{code}} |
| Compliance Scope | {{none, or named regime}} |
| Data Classification | {{public / internal / confidential / restricted}} |
| Environments Impacted | {{dev / staging / prod / all}} |
| Feature Flag | {{flag-name or none}} |
| Security Review Required | {{yes / no}} |
| Documentation Impact | {{yes / no}} |
| External Dependency | {{yes -- named below / no}} |

## Summary

{{One paragraph. What this Feature delivers and why it exists. Readable by someone
who has not read the Epic.}}

## Business Context

{{The problem or opportunity. Who is affected, what it costs today, what evidence
supports that. Cite the source of any number.}}

## Feature Hypothesis

For {{target-user-or-system}}
who {{need-or-pain}},
the {{feature-name}} is a {{capability-category}}
that {{primary-benefit}}.
Unlike {{current-state-or-alternative}},
this Feature {{key-differentiator}}.

**Leading indicator:** {{signal observable within the delivery window}}
**Success measure:** {{metric, current value, target value, measurement method}}

## Goal

{{The outcome, stated so it can be judged true or false. Not a list of activities.}}

## Scope

**In scope:**

- {{item}}

**Out of scope:**

- {{item}} -- {{why, and where it lands instead if anywhere}}

## Acceptance Criteria

{{Feature-level and verifiable. Each line names what is checked and what evidence
settles it. Not a restatement of the child Stories.}}

- [ ] {{criterion}}
- [ ] {{criterion}}

## Child Stories

| ID | Story | Outcome | Document | Size | Depends on |
|----|-------|---------|----------|------|------------|
| {{STORY-NN.N}} | {{story-title}} | {{what is true when done}} | `{{relative-path-to-story-doc}}` | {{size}} | {{none or STORY-NN.N}} |

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
| Accessibility | {{standard}} | {{method}} |
| Data retention | {{policy}} | {{method}} |

## Technical Notes

{{Design direction, affected components, interfaces, and decisions already made.
Name what is decided and what is deferred to Story planning. Cite the architecture
document for each decision.}}

## Test and Verification Approach

{{Test levels involved, environments and data needed, who verifies, and what
evidence closes the Feature.}}

## Rollout and Release

| Aspect | Plan |
|--------|------|
| Release strategy | {{big bang / phased / flag-gated / canary}} |
| Feature flag | {{name and default state, or none}} |
| Migration or backfill | {{required steps, or none}} |
| Rollback | {{procedure and trigger}} |
| Communication | {{who is told, when, by what channel}} |

## Definition of Ready

- [ ] Parent Epic linked and the Feature traces to a stated Epic outcome
- [ ] Acceptance criteria written and verifiable
- [ ] Child Stories identified and sized
- [ ] Dependencies identified with owners
- [ ] Non-functional requirements stated or explicitly marked not applicable
- [ ] {{project-specific gate}}

## Definition of Done

- [ ] All child Stories closed
- [ ] All acceptance criteria verified with evidence recorded
- [ ] Non-functional requirements verified
- [ ] Tests written and passing in the target environment
- [ ] Documentation updated
- [ ] Deployed to {{target environment}} and confirmed working
- [ ] {{project-specific gate}}

## Open Questions

| # | Question | Blocks | Owner | Needed by |
|---|----------|--------|-------|-----------|
| 1 | {{question}} | {{what it blocks}} | {{who}} | {{when}} |

## References

- {{link or path}} -- {{what it establishes}}
