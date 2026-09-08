# Field Mapping: Canonical to Azure DevOps and Jira

The templates use tool-agnostic field names so one document set serves any
tracker. This file maps each canonical field to its Azure DevOps and Jira
equivalent, and records where the two disagree.

Read this when the user names a target tracker, when a field value needs to be
constrained to that tracker's allowed values, or when a canonical field has no
native home and needs a custom field.

## Contents

- [Hierarchy: the load-bearing difference](#hierarchy-the-load-bearing-difference)
- [Core fields](#core-fields)
- [Planning and value fields](#planning-and-value-fields)
- [Fields that differ by level](#fields-that-differ-by-level)
- [Governance and custom fields](#governance-and-custom-fields)
- [State and state category](#state-and-state-category)
- [Link and relation types](#link-and-relation-types)
- [Where the narrative body goes](#where-the-narrative-body-goes)

## Hierarchy: the load-bearing difference

The structure is `Epic > Feature > Story > Task`.

**Azure DevOps** supports this natively in the Agile, Scrum, and CMMI process
templates. The Agile process ships `Epic > Feature > User Story > Task`. The Scrum
process ships `Epic > Feature > Product Backlog Item > Task`. No configuration is
needed to file any of the three levels this skill produces.

**Jira** does not. The default hierarchy is three levels: Epic at level 1,
standard types (Story, Task, Bug) at level 0, and Subtask at level -1. There is no
`Feature` level out of the box, and a Feature cannot be a parent of a Story without
configuration. Three ways to get there, in descending order of how common they are:

1. **Advanced Roadmaps custom hierarchy level.** Create a `Feature` issue type in
   Jira first, add it to the project's issue type scheme, then register it as a
   hierarchy level above Epic in Advanced Roadmaps. Requires a Jira Premium or
   Enterprise plan.
2. **Rename the levels.** Rename the built-in `Epic` to `Feature`, then add a new
   `Epic` type at a higher custom level. Cheap, but it rewrites the meaning of
   existing Epics across the whole instance.
3. **Jira Align.** Its native portfolio hierarchy is
   `Theme > Epic > Capability > Feature > Story`. Note that a Jira Align Feature
   sits below Capability, so an Epic-to-Feature parent link is two levels, not one.

This matters more for a three-level document set than it did for a single Feature
document. If Jira is the target and none of the above is configured, the Epic and
the Stories both land natively but the Feature layer has nowhere to live, and the
Epic-to-Story parent link collapses one level. Say so before generating, and record
the intended parent in the document so the link can be restored once the hierarchy
exists.

## Core fields

Present on all three levels unless noted.

| Canonical | Azure DevOps | Reference name | Jira | Notes |
|-----------|--------------|----------------|------|-------|
| Work Item Type | Work Item Type | `System.WorkItemType` | Issue Type / Work Type | See hierarchy note above for Jira |
| ID / Key | ID | `System.Id` | Key | ADO is an integer, Jira is `PROJ-123` |
| Title | Title | `System.Title` | Summary | Jira Summary is plain text, 255 char limit |
| Parent | Parent | `System.Parent` | Parent (or Epic Link on older instances) | `Epic Link` is a legacy Jira custom field, still present on many server and older cloud instances |
| State | State | `System.State` | Status | Values are process-template and workflow dependent, see below |
| State Category | State Category | `System.StateCategory` | Status Category | ADO: Proposed, In Progress, Resolved, Completed, Removed. Jira: To Do, In Progress, Done |
| Assignee / Owner | Assigned To | `System.AssignedTo` | Assignee | ADO also has `System.CreatedBy` and `System.ChangedBy` |
| Team / Area Path | Area Path | `System.AreaPath` | Component, or Team custom field | ADO Area Path is a tree; Jira Components are a flat multi-select |
| Iteration / Sprint | Iteration Path | `System.IterationPath` | Sprint | Feature and Story only. ADO Iteration Path is a tree. Jira Sprint is a custom field supplied by Jira Software and applies to boards |
| Target Release | Custom, commonly a Release picklist | custom | Fix Version/s | Jira Fix Version is native and multi-valued. ADO has no native equivalent above Iteration Path; teams use a custom field |
| Priority | Priority | `Microsoft.VSTS.Common.Priority` | Priority | ADO is 1 to 4 (1 highest). Jira default is Highest to Lowest |
| Tags / Labels | Tags | `System.Tags` | Labels | ADO Tags are semicolon-delimited on import. Jira Labels reject spaces |
| Description | Description | `System.Description` | Description | Both are rich text. ADO is HTML, Jira Cloud is ADF |

## Planning and value fields

| Canonical | Azure DevOps | Reference name | Jira | Notes |
|-----------|--------------|----------------|------|-------|
| Value Area | Value Area | `Microsoft.VSTS.Common.ValueArea` | Custom picklist | ADO allowed values are `Business` and `Architectural`, default `Business`. Business means it delivers value to a user or another system; Architectural means it supports other work |
| Business Value | Business Value | `Microsoft.VSTS.Common.BusinessValue` | Custom number field | Used by WSJF and similar prioritization models |
| Time Criticality | Time Criticality | `Microsoft.VSTS.Common.TimeCriticality` | Custom number field | How fast business value decays. The other WSJF input |
| Risk Reduction / Opportunity Enablement | Custom | custom | Custom number field | The third WSJF numerator input. Native in neither. Epic level in practice |
| Job Size | Custom, or reuse Effort | custom | Custom number field | WSJF denominator |
| WSJF | Custom | custom | Custom number field | Computed, not entered. Store it only if the team actually recomputes it on change |
| Start Date | Start Date | `Microsoft.VSTS.Scheduling.StartDate` | Start date | Jira Start date is native on newer cloud plans, a custom field otherwise |
| Target Date | Target Date | `Microsoft.VSTS.Scheduling.TargetDate` | Due date | Jira `duedate` is a system field |
| Risk | Risk | `Microsoft.VSTS.Common.Risk` | Custom picklist | ADO default values are `1 - High`, `2 - Medium`, `3 - Low` |
| Confidence | Custom | custom | Custom picklist | No native field in either. Common on portfolio boards |
| Blocked | Custom, commonly a Blocked picklist | custom | Custom picklist, or a `Blocked` flag | Story level. Jira Software has a `Flagged` field on some plans |

## Fields that differ by level

The one field that is genuinely different rather than merely more or less common:

| Level | Sizing field | ADO reference name | Jira |
|-------|--------------|--------------------|------|
| Epic | Effort | `Microsoft.VSTS.Scheduling.Effort` | Story Points, or a custom rollup |
| Feature | Effort | `Microsoft.VSTS.Scheduling.Effort` | Story Points, or a custom rollup |
| Story | Story Points | `Microsoft.VSTS.Scheduling.StoryPoints` | Story Points |

ADO uses `Effort` on Epic and Feature and `Story Points` on User Story. They are
different fields, so a rollup that sums `Story Points` across a Feature's children
does not populate that Feature's `Effort`. Set both deliberately or set neither.

`Microsoft.VSTS.Scheduling.RemainingWork` and `CompletedWork` exist on Task, not on
the three levels this skill produces.

## Governance and custom fields

None of these is native in either tracker except where noted. All need a custom
field. Include a row only when the organization actually tracks it; an empty
governance table is worse than an absent one because it reads as "checked and
clear".

| Canonical | Typical ADO type | Typical Jira type | Why it is commonly added |
|-----------|------------------|-------------------|--------------------------|
| Acceptance Criteria | Native: `Microsoft.VSTS.Common.AcceptanceCriteria`, HTML | Custom text field (paragraph) | The one exception. ADO has this natively on Bug, Epic, Feature, and Scrum PBI. Jira almost always needs a custom field |
| Requestor / Stakeholder | Identity | User picker | Audit trail for who asked, distinct from who owns delivery |
| Cost Center / Budget Code | Text or picklist | Text or picklist | Chargeback and capitalization reporting |
| Funding Type | Picklist | Picklist | Epic level. Capex versus opex drives accounting treatment |
| Compliance Scope | Picklist | Picklist | Routes the item to an extra review path |
| Data Classification | Picklist | Picklist | Drives handling rules and environment restrictions |
| Environments Impacted | Multi-select picklist | Multi-select | Deploy coordination and change advisory |
| Feature Flag | Text | Text | Ties the work item to the runtime toggle that gates it |
| Security Review Required | Boolean | Checkbox or picklist | Gate before release |
| Architecture Review Required | Boolean | Checkbox or picklist | Epic level. Gate before Features are broken out |
| Documentation Impact | Boolean | Checkbox or picklist | Catches docs work that otherwise falls out of scope |
| External Dependency | Boolean plus text | Checkbox plus text | Distinguishes "we are blocked" from "we are slow" in reporting |

## State and state category

State names are process-template and customization dependent. Map on the state
**category**, which is stable, rather than on the state name, which is not.

| Category | ADO Agile | ADO Scrum | ADO Basic | Jira default |
|----------|-----------|-----------|-----------|--------------|
| Proposed / To Do | New | New | To Do | To Do, Backlog |
| In Progress | Active | In Progress | Doing | In Progress |
| Resolved | Resolved | (no distinct state) | (none) | In Review, varies |
| Complete / Done | Closed | Done | Done | Done |
| Removed | Removed | Removed | (none) | Cancelled, varies |

ADO's `Removed` category exists so an item can be taken off the backlog without
being marked complete. Jira has no equivalent category and teams model it as a
`Done`-category status named `Cancelled` or `Won't Do`, which means removed items
count as completed in default Jira reports unless the filter excludes them.

## Link and relation types

| Canonical intent | Azure DevOps | Jira |
|------------------|--------------|------|
| Parent | `Parent` link (tree) | `Parent`, or `Epic Link` on legacy instances |
| Children | `Child` link (tree) | Child issues, requires the hierarchy configured for Feature |
| This blocks that | `Predecessor` / `Successor` (dependency) | `blocks` / `is blocked by` |
| Related work | `Related` | `relates to` |
| Duplicate | `Duplicate` / `Duplicate Of` | `duplicates` / `is duplicated by` |
| Supporting document | Hyperlink or attached file | Web link, Confluence link, or attachment |

ADO tree links (`Parent`, `Child`) enforce a single parent. Dependency links
(`Predecessor`, `Successor`) do not roll up in the backlog hierarchy, so a
cross-team dependency belongs there, not in the tree.

The generated document set encodes the tree in each document's `Traceability`
section as relative paths. When the items are filed, the tracker's tree links
become the source of truth and the document paths become the audit trail.

## Where the narrative body goes

Both trackers have one rich-text description field, not eighteen. The documents'
narrative sections are not separate fields.

**Recommended split, all levels:**

- **Description field**: Summary, Business Context, Hypothesis, Goal, Scope. On a
  Story, the User Story and Description sections. These are what a reader needs
  before deciding whether to read further.
- **Acceptance Criteria field** (ADO native, Jira custom): the Acceptance Criteria
  section verbatim.
- **Remaining sections**: keep in the linked document. Dependencies, Risks,
  Non-Functional Requirements, Rollout, and Open Questions all change on their own
  cadence, and pasting them into a description field means they go stale in the
  place people look first.
- **Structured fields**: Dependencies and Risks are better modeled as linked work
  items than as prose, because that is what makes them appear in dependency and
  risk reports. Keep the table in the document as the readable summary and link the
  real items.

Attach or link the full document to the work item. State in the description where
it lives, so the tracker record is never the only copy.
