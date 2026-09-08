# Story {{story-id}}: {{story-title}}

## Traceability

- **Epic:** {{epic-id}} -- {{epic-title}} (`{{relative-path-to-epic-doc}}`)
- **Parent Feature:** {{feature-id}} -- {{feature-title}} (`{{relative-path-to-feature-doc}}`)
- **Source artifact:** `{{milestone-readme-path}}:{{line}}` -- `### Feature {{NN.N}}: {{source-section-title}}`
- **Implementation plan:** `{{plan-path-or-none}}`

## Work Item Fields

### Core

| Field | Value |
|-------|-------|
| Work Item Type | Story |
| ID / Key | {{tracker-id-or-TBD}} |
| Title | {{story-title}} |
| Parent | {{feature-id}} -- {{feature-title}} |
| State | {{state}} |
| State Category | {{Proposed / In Progress / Resolved / Complete / Removed}} |
| Assignee / Owner | {{owner}} |
| Team / Area Path | {{team-or-area-path}} |
| Iteration / Sprint | {{iteration-or-sprint}} |
| Priority | {{1-4 or High/Medium/Low}} |
| Tags / Labels | {{comma-separated}} |

### Planning and Value

| Field | Value |
|-------|-------|
| Story Points | {{points}} |
| Business Value | {{score-or-scale}} |
| Start Date | {{YYYY-MM-DD}} |
| Target Date | {{YYYY-MM-DD}} |
| Risk | {{High / Medium / Low}} |
| Blocked | {{yes -- reason / no}} |

### Governance and Custom

| Field | Value |
|-------|-------|
| Requestor / Stakeholder | {{name-and-role}} |
| Data Classification | {{public / internal / confidential / restricted}} |
| Environments Impacted | {{dev / staging / prod / all}} |
| Feature Flag | {{flag-name or none}} |
| Security Review Required | {{yes / no}} |
| Documentation Impact | {{yes / no}} |
| External Dependency | {{yes -- named below / no}} |

## User Story

As {{role-or-system}},
I want {{capability}},
so that {{outcome}}.

## Description

{{What the work is, in enough detail that someone who did not write it can start.
State the current behavior and the target behavior. Cite `path:line` for anything
that already exists.}}

## Acceptance Criteria

{{Verifiable. Each criterion names what is checked and what evidence settles it.
Use Given/When/Then where behavior is conditional, a plain checklist otherwise.}}

- [ ] {{criterion}}
- [ ] {{criterion}}

## Tasks

| # | Task | Estimate | Owner |
|---|------|----------|-------|
| 1 | {{task}} | {{hours-or-TBD}} | {{who}} |

## Dependencies

| Dependency | Type | Owner | Needed by | Status |
|------------|------|-------|-----------|--------|
| {{what}} | {{internal / external / story}} | {{who}} | {{when}} | {{state}} |

## Technical Notes

{{Affected files, interfaces, and decisions already made. Name what is decided and
what the implementer chooses. Cite the architecture document or plan for each
decision that came from one.}}

## Test Notes

{{Test level, the command that runs it, the environment and data needed, and what
output counts as passing.}}

## Definition of Ready

- [ ] Parent Feature linked and the Story traces to a stated Feature outcome
- [ ] Acceptance criteria written and verifiable
- [ ] Sized and prioritized
- [ ] Dependencies identified, or none
- [ ] {{project-specific gate}}

## Definition of Done

- [ ] All acceptance criteria verified with evidence recorded
- [ ] Tests written and passing
- [ ] Code reviewed and merged
- [ ] Documentation updated
- [ ] {{project-specific gate}}

## Open Questions

| # | Question | Blocks | Owner | Needed by |
|---|----------|--------|-------|-----------|
| 1 | {{question}} | {{what it blocks}} | {{who}} | {{when}} |

## References

- {{link or path}} -- {{what it establishes}}
