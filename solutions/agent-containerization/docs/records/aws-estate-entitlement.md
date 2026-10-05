# AWS Estate Entitlement Design — Feature 03.1

Specifies the Identity Center principal, permission set and entitlement scope the operator's AWS
organisation provisions against (SF-1), ahead of any estate change (Decision 2). Satisfies R6.3.2,
R6.3.2a, R6.3.3, R6.3.5, R6.3.6, R6.3.7, R6.3.8, R6.3.9, R6.2.2, and records the CloudTrail read
access evidence T12 (03.4) depends on. Criteria numbers below refer to the Gate-4 plan's Acceptance
Criteria section (`aws-estate-provisioning-entitlement-design-and-third-party-record.md`).

**Status at this writing: specification only.** SF-2 (the estate precondition) has not yet been
reported by the operator. Every value below is a placeholder — see Placeholder vocabulary at the
end — and the Provisioning evidence, CloudTrail read access evidence and Criterion-to-evidence
table sections carry no filled cells until SF-3.

## Principal and permission set

| Field | Value |
|---|---|
| Identity Center principal | `<PRINCIPAL_ID>` (dedicated, agent use only) |
| Permission set | `<PERMISSION_SET_ARN>` |
| Assigned to | that principal only |
| Operator permission sets reachable | none — confirmed by `<method>` |
| Session duration | **`<N>` minutes** |

Criterion 1 (R6.3.2): the boundary is the entitlements of this principal, not the AWS CLI config a
container happens to ship with. An Identity Center access token permits `aws sso list-accounts` and
`aws sso get-role-credentials` for everything its underlying identity is entitled to, and neither
command consults a config file — R6.3.2a is honoured in the design rather than worked around by
trimming a config the token's identity could bypass regardless. The operator's existing identity
holds `OCC-Root-Admin`, `OCC-Network-Admin`, `OCC-Automation-Admin` and `OCC-Development-Admin`
(`REQUIREMENTS.md:198`); this principal is created separately from that identity and holds none of
them, and "Operator permission sets reachable" above states the method used to confirm it (e.g. an
Identity Center console listing of the principal's assigned permission sets) rather than asserting
it unverified.

**Citation note (criterion 1, recorded as an observation against the milestone README, not a change
to it).** The milestone README cites "(R6.3.2, R6.5.2)" for this criterion. R6.5.2 is Model-A-scoped
— its verification clause is `aws sso list-accounts` *from inside the container*, which Model B
makes structurally impossible (R6.5.4 forbids an in-container SSO token; T19's Model B pass
condition is that the call **fails** for want of a token). This record therefore rests criterion 1
on **R6.3.2** alone; the Model-B entitlement verification (R6.5.3 / R6.5.4 / R6.5.6) is 03.4's.

## Write grants per profile

| Profile | Permission | Resource scope | What it permits a compromised agent |
|---|---|---|---|
| (none at this feature) | — | — | — |

Criterion 2 (R6.3.3): the permission set is read-only as created. This table is empty at this
feature by design and is recorded as empty rather than omitted — an empty table is a valid state
here. Any future write or mutate grant is added to this table per use-case profile, explicitly and
narrowly, naming what it permits a compromised agent to do; a row reading "granted, scope TBD" does
not satisfy this section.

## Data perimeter            <!-- no GAP: accepted here (criterion 4) -->

| Field | Value |
|---|---|
| Mechanism | `<SCP \| role policy>` |
| Scope | `<organisation \| OU \| role>` |
| Condition keys | `aws:ResourceOrgID`, `aws:PrincipalOrgID` |

Criterion 4 (R6.3.6): **blocking**, by operator decision 2026-10-04. Per Decision 3 / `REQUIREMENTS.md`
Q1 (amended 2026-10-04, "a broad S3 surface"), R6.4.3 (bucket-specific FQDN allowlisting) is
impractical — a broad surface needs either a `*.s3.<region>` wildcard, which re-opens exactly the
exfiltration path R6.4.2 prohibits, or an allowlist that churns per bucket, which is not a control.
T13 therefore rests entirely on this data perimeter, enforced in the operator's organisation by a
requirement (R6.3.6) that is a SHOULD. A feature that closed with no perimeter would leave T13 with
nothing, so this section accepts no `GAP:` marker — T13's pass condition is that the denying control
is **named** (mechanism, scope, condition key), not inferred from a denial.

## Permission boundary       <!-- GAP: <consequence> accepted (criterion 5) -->

| Field | Value |
|---|---|
| Mechanism | `<permission boundary policy ARN>` |
| Prevents | principal creation and privilege escalation |

Criterion 5 (R6.3.7): a SHOULD with a control that survives its absence — the read-only default
(criterion 2) still stands without it — which is the operator's stated distinction from criterion 4.
May be recorded as `GAP: <consequence>` if the estate cannot attach it (SF-3).

## Destructive-action denies <!-- GAP: <consequence> accepted (criterion 5) -->

| Field | Value |
|---|---|
| Action patterns denied | `<delete* / terminate* / policy-modification action list>` |
| Mechanism | `<explicit deny statement, scope>` |

Criterion 5 (R6.3.9): denied even under a write-granting profile, named as action patterns (delete,
terminate, policy modification). Same gap-able status and rationale as the permission boundary
above.

## CloudTrail attribution

| Field | Value |
|---|---|
| Design intent | Role-chaining: attempt `RoleSessionName` carrying the R8.8 workload identity, so CloudTrail can attribute an API call to the originating agent despite one broker principal (Model B) fronting all three agents |
| Feasibility | `<reachable \| unreachable — see Provisioning evidence>` |
| Granularity if unreachable | Per-broker only; the R6.3.8 attribution-granularity finding is carried to the operator as a proposed milestone-DoD amendment (not applied here) |

Criterion 6 (R6.3.8): per the milestone's ratified tradeoff, this feature records the design and its
feasibility; 03.2 implements whichever shape holds. Either outcome — role-chaining reachable, or
per-broker granularity only with the finding carried forward — satisfies this criterion. An
unrecorded outcome does not.

## CloudTrail read access evidence

| Field | Value |
|---|---|
| Trail scope | `<account \| organisation>` |
| Query run | `<command, placeholder-safe>` |
| Event observed | `<event name, outcome>` |
| Event-to-visibility delay | **`<N>` seconds \| minutes** |

Criterion 10: T12's pass condition ("AccessDenied, recorded in CloudTrail") is unverifiable without
this evidence. If access cannot be obtained, SF-3 records it as a gap that makes T12 unverifiable in
03.4 — surfaced here, not there. A long event-to-visibility delay is recorded **as a number**: a
drill that polls for 60 seconds against a 15-minute delay measures nothing (Edge Case 3).

## Q1 — accounts and services, and the consequence

`REQUIREMENTS.md`, Q1 (amended 2026-10-04): answered **a broad S3 surface**.

Full consequence, carried verbatim (criterion 8): **R6.4.3 is impractical, and T13 rests entirely on
R6.3.6**, a SHOULD enforced in an estate this project does not own. That is the project's largest
"the control is elsewhere" claim, and it is this project's strongest residual AWS risk statement.

Consequence for 03.3's pack design, written down here so the pack is not designed against a guess:

- `s3.addressing_style = virtual`
- **No** bare `s3.<region>.amazonaws.com` endpoint
- **No** `*.s3.<region>` wildcard
- `*.amazonaws.com` prohibited outright (R6.4.1, R6.4.2)

## AWS carries an R14.1 record before any agent traffic reaches it

See `docs/records/third-party-assessments.md#r141-aws` (SF-4). Criterion 9: the traffic-path field
there is provisional, keyed to Q1's endpoint classes (STS in-region, S3 virtual-hosted in-region,
plus the mediator-side Identity Center endpoints absent from every agent allowlist per R6.4.6); 03.3
verifies the exact FQDNs against it once `packs/aws-cli/pack.yaml` exists.

## No long-lived IAM access key

Criterion 11 (R6.2.2, MUST NOT): no long-lived IAM access key exists in the image, the environment,
any mounted volume, or this repository, and none is created by this provisioning. This design uses
Identity Center / STS temporary credentials exclusively (R6.3.1's premise); nothing in SF-1 through
SF-5 introduces an `AKIA`/`ASIA`-prefixed key, and phase D of `verify-aws-estate.sh` (SF-5) guards the
repository side of this assertion on every run.

## What this record does not prove

Criterion 12: this record and its harness (`verify-aws-estate.sh`) check that the **records say the
right things** — that a session duration is a number, that a data-perimeter cell names a mechanism
and a condition key, that an R14.1 record exists before traffic. They cannot check that the estate
**does** these things. T10, T12, T13, T19 and T20 are 03.4's, measured from inside a container
against a live broker. A green harness here is not a proven perimeter.

## Criterion-to-evidence table

| Criterion | Requirement | Evidence | Phase |
|---|---|---|---|
| 1 | R6.3.2 | Principal and permission set table; Operator permission sets reachable method | A |
| 2 | R6.3.3 | Write grants per profile table (empty valid) | A |
| 3 | R6.3.5 | Session duration, numeric | A |
| 4 | R6.3.6 | Data perimeter table, no `GAP:` accepted | A |
| 5 | R6.3.7 / R6.3.9 | Permission boundary / Destructive-action denies, `GAP: <consequence>` accepted | A |
| 6 | R6.3.8 | CloudTrail attribution design and feasibility | A |
| 8 | Q1 register | Q1 section, consequence verbatim | A |
| 9 | R14.1 | `third-party-assessments.md#r141-aws`, provisional traffic-path | B |
| 10 | T12 precondition | CloudTrail read access evidence, numeric delay | A |
| 11 | R6.2.2 | No long-lived IAM access key assertion | D |
| 12 | — | This section | — |

## Placeholder vocabulary

`<ACCOUNT_ID>`, `<ORG_ID>`, `<PERMISSION_SET_ARN>`, `<PRINCIPAL_ID>`, `<START_URL_HOST>`,
`<SSO_INSTANCE_ID>`, `<REGION>`. Fixed here so this record, the R14.1 AWS record and the harness use
the same tokens (plan Interface Contract 4).
