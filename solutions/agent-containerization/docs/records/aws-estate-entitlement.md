# AWS Estate Entitlement Design — Feature 03.1

Specifies the Identity Center principal, permission set and entitlement scope the operator's AWS
organisation provisions against (SF-1), ahead of any estate change (Decision 2). Satisfies R6.3.2,
R6.3.2a, R6.3.3, R6.3.5, R6.3.6, R6.3.7, R6.3.8, R6.3.9, R6.2.2, and records the CloudTrail read
access evidence T12 (03.4) depends on. Criteria numbers below refer to the Gate-4 plan's Acceptance
Criteria section (`aws-estate-provisioning-entitlement-design-and-third-party-record.md`).

**Status at this writing: specification provisioned and evidence recorded (SF-3).** SF-2 was
reported complete by the operator 2026-10-17, via tg-infra (`occ-tg-infra-platform`, branch
`feat/agent-sandbox-role`, merged to `main` at `cca571f`, PRs #10/#11). Evidence below is from
read-only verification and one live chain test, not from this repository.

## Principal and permission set

| Field | Value |
|---|---|
| Identity Center principal | `svc-agent-sandbox` (`<PRINCIPAL_ID>`, identity store `<IDENTITY_STORE_ID>`, SSO instance `<SSO_INSTANCE_ID>`) — dedicated, agent use only |
| Permission set | `OCC-Agent-Sandbox-RO` (`<PERMISSION_SET_ID>`) — chain-only, carries no AWS managed policy; inline policy permits `sts:AssumeRole` + `sts:SetSourceIdentity` on the Dev target role ARN only, plus the DenyOutsideOrg/DenyDestructive guardrail repeated inline |
| Assigned to | Group `OCC-Agent-Sandbox` only; `svc-agent-sandbox` is the group's sole member; the group's only assignment is `OCC-Agent-Sandbox-RO` on account `<ACCOUNT_ID>` (Development) |
| Operator permission sets reachable | None. Confirmed by: `svc-agent-sandbox` verified (identitystore/sso-admin list calls, tg-infra, 2026-10-17) to be in exactly one group with no direct assignment; that group carries exactly one permission-set assignment, scoped to the Development account only |
| Session duration | **60 minutes** (IdC permission set, `PT1H`). The chained Dev-account role session (below) is a second, separate duration |

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

**Assignment scope (operator decision 2026-10-17):** Development account (`<ACCOUNT_ID>`) only. No
other account or OU was considered necessary at this feature.

### Chained target role (Development account)

| Field | Value |
|---|---|
| Role | `arn:aws:iam::<ACCOUNT_ID>:role/platform/AgentSandboxReadOnlyRole` |
| MaxSessionDuration | 3600 seconds (AWS ceiling; the broker built in 03.2 proposes requesting `DurationSeconds=900` — not yet confirmed, since the broker does not exist yet) |
| Permission boundary | `arn:aws:iam::<ACCOUNT_ID>:policy/org/Boundary-Default` (mandatory on this role) |
| Managed policy | `ReadOnlyAccess` |
| Trust policy | Allows `sts:AssumeRole` + `sts:SetSourceIdentity` from the Dev account root, narrowed by: `aws:PrincipalArn` `ArnLike` matching `AWSReservedSSO_OCC-Agent-Sandbox-RO_*`; `aws:PrincipalOrgID` `StringEquals` `<ORG_ID>`; `sts:SourceIdentity` `StringLike` `?*` (non-empty, required) |

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
| Mechanism | Inline Deny statement (`DenyOutsideOrg`), present in both the permission set's inline policy and the Dev target role's identity policy — not an SCP (permission-set-scoped, operator decision 2026-10-17; an org-level SCP was offered as a stronger alternative and declined for now) |
| Scope | Role — every role the permission set provisions (`AgentSandboxReadOnlyRole`) |
| Condition keys | `aws:ResourceOrgID` (`StringNotEqualsIfExists`, with a `NotResource` carve-out for ~18 AWS-owned ARNs, pattern copied from AWS's own published resource-perimeter SCP example) on the identity/permission-set side; `aws:PrincipalOrgID` (`StringEquals`, `<ORG_ID>`) on the Dev role's trust policy |

Criterion 4 (R6.3.6): **blocking**, by operator decision 2026-10-04. Per Decision 3 / `REQUIREMENTS.md`
Q1 (amended 2026-10-04, "a broad S3 surface"), R6.4.3 (bucket-specific FQDN allowlisting) is
impractical — a broad surface needs either a `*.s3.<region>` wildcard, which re-opens exactly the
exfiltration path R6.4.2 prohibits, or an allowlist that churns per bucket, which is not a control.
T13 therefore rests entirely on this data perimeter, enforced in the operator's organisation by a
requirement (R6.3.6) that is a SHOULD. A feature that closed with no perimeter would leave T13 with
nothing, so this section accepts no `GAP:` marker — T13's pass condition is that the denying control
is **named** (mechanism, scope, condition key), not inferred from a denial.

**Live verification (2026-10-17, read-only chain test as `svc-agent-sandbox`).** A read against a
public bucket outside the organisation (`noaa-ghcn-pds`) was denied (`AccessDenied`/403), consistent
with `DenyOutsideOrg` firing — not independently confirmed to be that specific statement versus
another denial path. In-org reads (S3, EC2, Lambda, IAM list, EC2 public AMI describe) all succeeded
through the chained role.

**Residual limitation, recorded rather than silently absorbed (operator-accepted 2026-10-17).**
`aws:ResourceOrgID` requires a resource-scoped API call to be present; Cost Explorer
(`ce:GetCostAndUsage`) and Support (`support:DescribeSeverityLevels`) are not resource-scoped and
both succeeded under `ReadOnlyAccess` in the live test. The data perimeter has no opinion on either
service — it is not a leak the perimeter was supposed to catch and missed, it is two services
structurally outside what an org-ID condition key can gate. Accepted as-is; no explicit deny was
added for them.

## Permission boundary       <!-- GAP: <consequence> accepted (criterion 5) -->

| Field | Value |
|---|---|
| Mechanism | `arn:aws:iam::<ACCOUNT_ID>:policy/org/Boundary-Default`, attached to both `AgentSandboxReadOnlyRole` and the `OCC-Agent-Sandbox-RO` permission set (mandatory on the Dev role) |
| Prevents | principal creation and privilege escalation |

Criterion 5 (R6.3.7): attached. Not a gap. A SHOULD with a control that survives its absence — the
read-only default (criterion 2) still stands without it — which is the operator's stated distinction
from criterion 4; attaching it anyway is the stronger outcome.

## Destructive-action denies <!-- GAP: <consequence> accepted (criterion 5) -->

| Field | Value |
|---|---|
| Action patterns denied | `DenyDestructive` inline statement: IAM writes and `PassRole`; `organizations:*`; delete actions on S3/EC2/RDS/Lambda/DynamoDB; KMS key destruction and key-policy changes; Secrets Manager delete and resource-policy changes; `cloudformation:DeleteStack`; CloudWatch Logs/CloudTrail delete, stop, update and put; `sso:*`; `identitystore:*` |
| Mechanism | Explicit Deny, inline, repeated on both the Dev target role and the permission set |

Criterion 5 (R6.3.9): attached. Not a gap. Live test (2026-10-17): an `s3 mb` (create-bucket) call
through the chained role was denied — not independently confirmed whether `DenyDestructive` or the
absence of `s3:CreateBucket` from `ReadOnlyAccess` caused the denial, since either alone would
produce the same result.

## CloudTrail attribution

| Field | Value |
|---|---|
| Design intent | Role-chaining, attribution via `sts:SourceIdentity` carrying the workload identity (see Architectural Deviations in the feature plan — the plan specified `RoleSessionName`; the build gates on `SourceIdentity` instead, with `RoleSessionName` also set but not enforced) |
| Feasibility | **Reachable, confirmed live.** Chain attempt without `--source-identity` was denied (`AccessDenied`); with `--source-identity svc-agent-sandbox` it succeeded, and the resulting CloudTrail event carries `SourceIdentity=svc-agent-sandbox` |
| Granularity | Per-agent, via `SourceIdentity` set to the workload id at chain time — not per-broker-only. The R6.3.8 finding this criterion anticipated (unreachable → per-broker only) does not apply; attribution is reachable |

Criterion 6 (R6.3.8): satisfied — role-chaining attribution is reachable and verified live, not merely
designed. Not independently confirmed whether the enforcing control is the trust policy's
`sts:SourceIdentity` condition specifically (elimination by tg-infra: the identity-side policy allows
the call unconditionally and the data-perimeter deny does not touch it, leaving the trust condition
as the only remaining variable between the failing and succeeding calls; CloudTrail's own event does
not name which policy produced the denial).

## CloudTrail read access evidence

| Field | Value |
|---|---|
| Trail scope | Account-level event history (Development account, `<ACCOUNT_ID>`), management events, 90-day window. No organisation trail profile was available to verify from; this scope is narrower than an org trail would be |
| Query run | `aws cloudtrail lookup-events --profile OCC-Development-ReadOnly --region ca-central-1 --start-time 2026-10-17T01:45:00Z --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRole` |
| Event observed | Two `AssumeRole` events: `AccessDenied` at `2026-10-17T01:45:55Z` (the omitted-`SourceIdentity` probe, no session name/`SourceIdentity` recorded); success at `2026-10-17T01:45:57Z` (event `781c6910`, `SourceIdentity=svc-agent-sandbox`) |
| Event-to-visibility delay | **~111–142 seconds (roughly 2–2.5 minutes)** — polled every ~30s; zero events visible at `01:47:46Z`, both present by `01:48:17Z`; calls were made at `01:45:55Z`/`01:45:57Z` |

Criterion 10: satisfied. T12's pass condition ("AccessDenied, recorded in CloudTrail") is verified
reachable with a measured, non-trivial delay — 03.4's drills must poll past ~2.5 minutes, not a
shorter window, or they will measure nothing (Edge Case 3).

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

Specifically carried forward to 03.4, unverified here despite the SF-3 live tests:

- Whether the `SourceIdentity` trust condition (not the data perimeter, not `ReadOnlyAccess`'s own
  scope) is what actually produced the no-`SourceIdentity` `AccessDenied` — established by
  elimination, not direct observation.
- Whether `DenyDestructive` or the absence of `s3:CreateBucket` from `ReadOnlyAccess` caused the
  denied `s3 mb` call.
- Whether `DenyOutsideOrg` specifically (versus some other denial path) caused the denied read
  against the public out-of-org bucket.
- Account-to-account resource access (only a public, unauthenticated-read bucket was tested outside
  the org).
- The broker's actual issued session duration (03.2 does not exist yet; 900 seconds is a proposal,
  not a built value) and whether the broker in fact sets `SourceIdentity`/`RoleSessionName` to the
  R8.8 workload identity as this record assumes it will.

## Criterion-to-evidence table

| Criterion | Requirement | Evidence | Phase |
|---|---|---|---|
| 1 | R6.3.2 | Principal and permission set table; Operator permission sets reachable method | A |
| 2 | R6.3.3 | Write grants per profile table (empty valid) | A |
| 3 | R6.3.5 | Session duration, numeric | A |
| 4 | R6.3.6 | Data perimeter table, no `GAP:` accepted | A |
| 5 | R6.3.7 / R6.3.9 | Permission boundary `Boundary-Default` attached; `DenyDestructive` inline — both attached, no gap recorded | A |
| 6 | R6.3.8 | CloudTrail attribution: reachable, confirmed live via `SourceIdentity` (see plan Architectural Deviations) | A |
| 8 | Q1 register | Q1 section, consequence verbatim | A |
| 9 | R14.1 | `third-party-assessments.md#r141-aws`, provisional traffic-path | B |
| 10 | T12 precondition | CloudTrail read access evidence, numeric delay | A |
| 11 | R6.2.2 | No long-lived IAM access key assertion | D |
| 12 | — | This section | — |

## Placeholder vocabulary

`<ACCOUNT_ID>`, `<ORG_ID>`, `<PERMISSION_SET_ARN>`, `<PRINCIPAL_ID>`, `<START_URL_HOST>`,
`<SSO_INSTANCE_ID>`, `<REGION>`. Fixed here so this record, the R14.1 AWS record and the harness use
the same tokens (plan Interface Contract 4).
