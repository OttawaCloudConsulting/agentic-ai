# Control Pool and Inheritance Model

## Source of Truth

Controls are defined in [Annex 3A — Security Control Catalogue (ITSG-33)](https://www.cyber.gc.ca/en/guidance/annex-3a-security-control-catalogue-itsg-33).
The CCCS Medium Cloud Profile selection is Annex B of [ITSP.50.103](https://www.cyber.gc.ca/en/guidance/guidance-security-categorization-cloud-based-services-itsp50103), published as a spreadsheet.
`references/cccs-medium-profile.md` is generated from that spreadsheet by `scripts/build_profile.py`.

## Pool Resolution

The pool is the set of controls the assessment evaluates. Resolve it once, at the start of Phase 2, and record which source was used.

1. **Supplied list** — if the invocation names a control list (a file path, a pasted table, or a named project baseline), that list is the pool. Normalize IDs to the `XX-N` / `XX-N(E)` form. Flag any ID not present in `cccs-medium-profile.md` as "outside CCCS Medium profile" rather than dropping it.
2. **Default** — otherwise the pool is every control in `references/cccs-medium-profile.md`.

The pool is fixed once resolved. Applicability decides which pool controls apply to this system; it never adds controls from outside the pool.

## Applicability

Every pool control receives exactly one applicability decision, made against the Phase 1 component inventory:

- **Applicable** — name the component(s) whose surfaces the control governs. A control may apply to several components; assess each.
- **Not Applicable** — state the reason: no component has the surface the control governs (for example, AC-18 Wireless Access where no component operates wireless networks).
- **Organizational** — the control is a policy, procedure, personnel or training obligation (most `-1` controls, AT, PS, much of PL) that code cannot evidence. Classify as GC Org-level unless the invocation provides evidence.

A control never disappears silently. Controls the project cannot evidence still appear, as Organizational or Not Applicable with a reason.

## Control Inheritance Model

For each applicable control, classify the implementation responsibility:

| Category | Meaning | Example |
|---|---|---|
| **AWS Inherited** | Fully provided by AWS, no customer action needed | PE-\* (Physical), data center security |
| **AWS Shared** | AWS provides the capability, customer must configure it | SC-28: AWS provides S3 encryption, customer must enable it |
| **Customer Implemented** | Entirely the customer's responsibility | AC-12: session termination inside the application |
| **GC Org-level** | Implemented at the GC organization/department level, not per-project | AT-\* (Security Training), PS-\* (Personnel Security) |

`Client IaaS/PaaS = No` in the catalogue means Annex B assigns the control to the CSP alone; default those to AWS Inherited.
Application-layer controls (session handling, input validation, application authentication and audit content) are Customer Implemented even where the platform beneath them is AWS Shared.
