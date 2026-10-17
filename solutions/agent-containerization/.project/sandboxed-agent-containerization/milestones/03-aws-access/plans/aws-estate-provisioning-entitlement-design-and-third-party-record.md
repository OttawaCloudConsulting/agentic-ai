# Feature Plan: AWS estate provisioning, entitlement design and third-party record

**Milestone:** 03 — AWS Access
**Feature:** 03.1: AWS estate provisioning, entitlement design and third-party record
**Status:** Planned
**Date:** 2026-09-30 (revised 2026-10-04 after an external review — see Review Revisions)

## Summary

The estate-side half of Milestone 03, and the only feature whose long pole sits in someone else's
organisation. It creates a dedicated IAM Identity Center principal and an agent permission set
entitled to nothing else, designs the entitlement scope around it — read-only by default, a bounded
session duration stated as a number, a data perimeter, a permission boundary, destructive-action
denies — and records all of it in this repository, together with the R14.1 third-party record for
AWS that must exist **before** any agent request reaches an AWS endpoint. Almost none of the estate
work is this project's to perform; what this feature owns is the **design, the evidence of what was
provisioned, and the records that everything after it consumes**. 03.2's broker mints against the
permission set this feature specifies; 03.3's pack cannot pass `lint-policy.sh` without the R14.1
anchor this feature writes.

**Start-gate, satisfied before planning.** Q9 is answered **yes** and Q1 is answered **a broad S3
surface** — both operator-answered 2026-09-30 and now **applied to the register**
(`REQUIREMENTS.md` § Open Questions, Q1 and Q9 rows, amended 2026-10-04). The plan cites the
register, not a conversation.

## Acceptance Criteria

Refined from the milestone README with the Q1/Q9 answers and the codebase scan. **Criteria 1–3, 4
and 8–11 are blocking. Criterion 5 is gap-able, criteria 6 and 12 are recorded outcomes.** The
blocking/gap-able split is set by operator decision 2026-10-04 and justified per criterion.

1. **A dedicated principal and agent permission set exist, entitled to nothing else** — **R6.3.2**
   (MUST), the operative requirement.
   - An Identity Center principal (user or group) created **for agent use only**, with the agent
     permission set assigned **only** to it.
   - **No operator permission set is reachable from it.** The estate's operator identity holds
     `OCC-Root-Admin`, `OCC-Network-Admin`, `OCC-Automation-Admin` and `OCC-Development-Admin`
     (`REQUIREMENTS.md:198`); the agent principal holds none, and the record states **how that was
     confirmed** rather than asserting it.
   - **R6.3.2a is honoured in the design, not worked around.** A trimmed config file is not a
     privilege boundary: an Identity Center access token permits `aws sso list-accounts` and
     `aws sso get-role-credentials` for everything its underlying identity is entitled to, and
     neither command consults the config. The boundary is therefore the **entitlements of this
     principal**, which is exactly what this feature bounds.
   - **Citation note, recorded as an observation against the milestone README.** The README cites
     "(R6.3.2, R6.5.2)" for this criterion. **R6.5.2 is Model-A-scoped** — its verification clause is
     `aws sso list-accounts` *from inside the container*, which Model B makes structurally
     impossible: R6.5.4 forbids an in-container SSO token, and T19's Model B pass condition is that
     the call **fails for want of a token**. So this plan rests the criterion on **R6.3.2**, and the
     Model-B entitlement verification lands under **R6.5.3 / R6.5.4 / R6.5.6** in 03.4. Recorded as a
     citation observation, not a change to the README (a gate artifact).
2. **Read-only by default, with per-profile write grants recorded individually** (R6.3.3, MUST).
   - The permission set is read-only as created.
   - Any write or mutate permission is granted **per use-case profile, explicitly and narrowly**, in
     a table whose rows name the profile, the permission, the resource scope and **what it permits a
     compromised agent to do**. An empty table is a valid state at this feature and is recorded as
     empty, not omitted.
3. **Session duration is bounded, short, and stated as a number** (R6.3.5, MUST). The record carries
   the figure and the accepted operational cost. A range, a "short", or a `TBD` fails.
4. **A data perimeter denies the agent principal resources outside the organisation** (R6.3.6) —
   **BLOCKING, by operator decision 2026-10-04.**
   - SCPs or role policies conditioned on `aws:ResourceOrgID` / `aws:PrincipalOrgID`.
   - The record names **which mechanism, at which scope (organisation / OU / role), and which
     condition keys**, because T13's pass condition is that the **denying control is named** rather
     than inferred from a denial.
   - **Why this one blocks while 5 does not.** R6.3.6 is a SHOULD in the register, but Q1's answer
     makes it the *only* remaining T13 control: with a broad S3 surface, R6.4.3 is impractical and
     the egress layer cannot distinguish an exfiltrating `PutObject` from a legitimate one at the
     domain level. A feature that closed with no perimeter would leave T13 with nothing, so
     **03.1 does not close without it** — it is not recordable as a named gap.
5. **A permission boundary prevents principal creation or escalation** (R6.3.7), and **destructive
   actions are denied even under a write-granting profile** (R6.3.9) — delete, terminate and policy
   modification, named as action patterns. **Gap-able:** either may be recorded as a **named gap with
   its consequence** if the estate cannot attach it. Both are SHOULDs with a control that survives
   their absence — the read-only default (criterion 2) still stands — which is the difference from
   criterion 4.
6. **CloudTrail attribution is designed and its granularity recorded as a finding** (R6.3.8).
   - Under Model B one broker principal fronts three agents, so per-agent attribution is **not**
     automatic. Per the milestone's ratified tradeoff: **attempt role-chaining with
     `RoleSessionName` carrying the R8.8 workload identity, and record the outcome either way.**
   - This feature records the **design and its feasibility**; 03.2 implements whichever shape holds.
     If per-agent naming is unreachable, the record states **per-broker granularity only** and the
     R6.3.8 attribution finding is carried to the operator as a proposed amendment (milestone DoD),
     not applied here. **Either outcome satisfies this criterion**; an unrecorded outcome does not.
7. *(merged into criterion 4's rationale and criterion 8 — Q1's answer now lives in the register.)*
8. **Q1's register answer is carried into the design with its full consequence.**
   - The record states, citing `REQUIREMENTS.md` Q1: **R6.4.3 is impractical** and **T13 rests
     entirely on R6.3.6**, a SHOULD enforced in an estate this project does not own. That sentence
     appears in the record's residuals verbatim, because it is the project's largest "the control is
     elsewhere" claim.
   - The consequences for 03.3 are written down here so the pack is not designed against a guess:
     `s3.addressing_style = virtual`, **no** bare `s3.<region>.amazonaws.com` endpoint, **no**
     `*.s3.<region>` wildcard, and `*.amazonaws.com` prohibited outright (R6.4.1, R6.4.2).
9. **AWS carries an R14.1 record before any agent traffic reaches it** (R14.1, MUST, per third
   party).
   - Written in `docs/records/third-party-assessments.md` in the **existing `Field | Value` shape**,
     with an explicit `<a id="r141-aws"></a>` anchor, a Summary Table row, and a T42 section entry.
   - **Provisional on the traffic-path row, by construction.** The exact FQDNs are placed by 03.3's
     not-yet-built `packs/aws-cli/pack.yaml`, so this record keys its traffic-path field to **Q1's
     endpoint classes** — STS in-region, S3 virtual-hosted in-region, plus the mediator-side
     Identity Center endpoints that are explicitly *not* on any agent's allowlist (R6.4.6). The row
     is marked provisional, and **03.3 verifies the exact FQDNs against it** — a dependency this
     plan states in Documentation rather than leaving to 03.3 to discover.
   - Per-field honesty, as the file's header already requires: any unconfirmed field is marked and
     the **resulting constraint on use** is recorded. An `Incomplete` status with an empty constraint
     cell is a harness failure, not a style issue.
   - **The anchor is load-bearing.** `scripts/lint-policy.sh:260` refuses a pack whose
     `third_parties[].record` anchor does not resolve (`grep -q "id=\"<anchor>\""`), and
     `verify-tool-packs.sh:175` probes exactly that refusal. 03.3's pack does not lint until this
     record exists.
10. **CloudTrail read access is available to the operator for the agent principal's events**, proven
    by an **executed query** — T12's pass condition is "AccessDenied, recorded in CloudTrail", which
    is unverifiable without it. The record carries a dedicated **CloudTrail read access evidence**
    section: the trail's scope, the query run, the event observed, and the **event-to-visibility
    delay as a number**. Phase A fails if the section is absent or placeholder-only. If access
    cannot be obtained, it is recorded as a gap that makes **T12 unverifiable in 03.4** — surfaced
    here, not there.
11. **No long-lived IAM access key exists anywhere** (R6.2.2, MUST NOT) — not in the image, the
    environment, any mounted volume, or this repository — and none is created by this provisioning.
    Asserted in the record and checked by the harness over the surfaces R6.2.2 names.
12. **What this feature does NOT prove is stated in the record.** The harness checks that the
    records say the right things; it cannot check that the estate does them. T10, T12, T13, T19 and
    T20 are 03.4's, measured from inside a container against a live broker. A reader must not be
    able to mistake a green harness here for a proven perimeter.

## Approach

### The starting position, measured rather than assumed

The codebase scan is unambiguous: `grep -rniE "aws|amazonaws|\bsts\b|\bsso\b|identity.center" policy/
packs/ profiles/ images/` returns **zero hits**. R6 lives only in `REQUIREMENTS.md` and prose. There
is nothing to retrofit and nothing to avoid breaking — this feature's repository-side work is
additive, and its risk is entirely in the estate and in the records' honesty.

Three record shapes already exist and are reused rather than invented: the `Field | Value` R14.1
record with an `id="r141-<party>"` anchor (HashiCorp and GitHub are the precedent, and they carry
explicit anchors **because** `lint-policy.sh` greps for them); the Summary Table row; and the T42
re-inspection table.

### Decision 1 — the entitlement design is a new record, not an architecture edit

| Option | Outcome | Cost |
|---|---|---|
| **A. New `docs/records/aws-estate-entitlement.md` (chosen)** | One file owns the estate design; harness-parseable; consistent with every other feature's records-in-`docs/records` convention | A reader follows one more pointer from the architecture document. Mitigated by the proposed edit in SF-5 |
| B. Extend `ARCHITECTURE_AND_DESIGN.md` § Security | The design sits with D13/D13a | `/build` may not edit gate artifacts — the posture 02.3, 02.4 and 02.5 all took |
| C. Extend `credential-inventory.md` | Credentials and entitlements in one place | Category error, and it breaks a harness: see below |

**Consequence, stated:** this feature adds **no row** to the credential inventory. The mediator's SSO
token (03.2) and the issued STS credentials (03.2/03.5) are the credentials, and they are those
features' rows. Pre-creating rows here would create cells `verify-containment.sh` phase A demands be
filled — `Stated maximum`, `Measured`, `Rebuild required` — for credentials that do not exist, taking
a green harness red the moment this feature landed.

### Decision 2 — the estate work is an external precondition; the repository records its evidence

Nothing in this plan creates AWS resources from the pod. The split is explicit in the sub-features:
**SF-2 is an external precondition with a defined blocked state**, and **SF-3 is the buildable
evidence-recording step**. The specification (SF-1) is written **first**, so the provisioning has
something to be measured against — the same ordering 02.5 used for its drills (Decision 7 there): a
record written after the fact describes whatever happened; a record written first is a specification
the execution can fail against.

**What a gap may and may not be, after the operator's 2026-10-04 decision.** A missing **permission
boundary** or **destructive-action deny** is a recorded named gap with its consequence (criterion 5).
A missing **data perimeter is not** — it blocks the feature (criterion 4), because Q1's answer leaves
T13 with no other control. A5's fallback text (`REQUIREMENTS.md:382`, "R6.3 becomes unimplementable;
fall back to a read-only permission set with no data perimeter") describes the **project-level**
fallback if the estate cannot be modified at all — which Q9's positive answer has already ruled out.
It is not a licence for this feature to close without the perimeter.

### Decision 3 — Q1 is broad, so R6.4.3 is recorded impractical and T13's weight moves

Now settled in the register rather than in this plan (`REQUIREMENTS.md`, Q1, amended 2026-10-04):

- **R6.4.3 (SHOULD) is impractical.** Bucket-specific FQDN allowlisting requires a bounded, known
  bucket set. A broad surface needs either a `*.s3.<region>` wildcard — re-opening exactly the
  exfiltration path R6.4.2 prohibits — or an allowlist that churns per bucket. Neither is a control.
- **T13 therefore rests entirely on R6.3.6**, enforced in the operator's organisation.
- **The residual is named, not softened:** the project's strongest AWS control is implemented
  somewhere this project does not own, by a requirement that is a SHOULD. That sentence belongs in
  the record verbatim, and criterion 4's blocking status is the plan's response to it.

### Decision 4 — the harness checks the records, and says so

03.1 is records-only, so a static phase is its only testable surface. The idiom already exists:
`verify-containment.sh` phase A parses three markdown records with three reusable shapes — row
extraction keyed on an id regex, section-scoped table extraction by header keywords, and
heading/anchor presence checks — with a `filled()` guard that rejects `""`, `—`, `TBD`, `n/a` and
`*pending*`.

**`GAP:` is not a universal escape hatch.** `filled()` alone would let any required cell pass by
being marked `GAP:`. Phase A therefore partitions its cells: the **criterion-4 and criterion-1/2/3
cells accept no `GAP:` marker at all** (a gap there is a feature failure, per Decision 2), while the
criterion-5 cells accept `GAP: <consequence>` with a **non-empty consequence**. A bare `GAP:` fails
everywhere.

### Decision 5 — publishability is a mechanical control, scoped to the AWS records

This repository is public. 02.5 had the equivalent problem with credential values and solved it with
a stated rule plus a harness check; the same shape applies to AWS identifiers, which are not secrets
but are reconnaissance material and trivially greppable once published. **This is repository hygiene,
not an R6.2.2 claim** — R6.2.2 prohibits long-lived IAM keys in the image, environment and volumes,
and criterion 11 covers that separately.

**Scoped, because a repo-wide scan is already red.** `policy/allowlist.base.yaml:141` carries
`antigravity-cli-auto-updater-974169037036.us-central1.run.app` — a 12-digit GCP project number —
and six other files carry incidental 12-digit strings. A bare repo-wide `[0-9]{12}` phase would fail
on arrival and teach its reader to ignore it. Phase C therefore scans **the two AWS records only**,
with AWS-specific patterns.

## Sub-Features

Ordered so the specification exists before the provisioning it specifies, and the harness exists
after the records it parses. **Five sub-features** — SF-2 and SF-3 are the external/buildable split
the review asked for.

- [x] **SF-1: The entitlement design record (specification first).**
  - `docs/records/aws-estate-entitlement.md` created, carrying: the principal and permission-set
    design; read-only default; the per-profile write-grant table (empty is valid, recorded as
    empty); the session duration **as a number** with its accepted cost; the data-perimeter
    mechanism, scope and condition keys **as the specification to be provisioned against**; the
    permission boundary; the destructive-action denies as action patterns; the CloudTrail attribution
    design with role-chaining stated as the intent; an empty-but-present **CloudTrail read access
    evidence** section; **Q1's register answer and the full R6.4.3-impractical / T13-rests-on-R6.3.6
    consequence**; the R6.2.2 no-long-lived-key assertion; and a "what this record does not prove"
    section.
  - Placeholders only — no account ID, ARN, start URL, SSO instance or principal ID.
  - Documentation only, 1 file. Written **before** any estate change, deliberately.
- [x] **SF-2: The estate precondition (external; not this repository's work).**
  - The operator creates the principal, the permission set and its assignment; attaches the data
    perimeter and the permission boundary; confirms the destructive-action denies; obtains CloudTrail
    read access for the agent principal's events.
  - **No repository change. This sub-feature is marked `[x]` only when the operator reports the
    estate state**, and its **blocked state is defined**: if the data perimeter cannot be attached,
    SF-2 is **BLOCKED** and 03.1 does not close (criterion 4). If only the permission boundary or a
    destructive deny is missing, SF-2 completes and the gap is recorded in SF-3 (criterion 5).
  - `/build` cannot drive this. A build session reaching SF-2 with no operator report **stops and
    says so** rather than proceeding to SF-3 on assumptions.
- [ ] **SF-3: The provisioning evidence, recorded.**
  - `aws-estate-entitlement.md` gains the evidence against each criterion, in placeholder form: what
    exists, at what scope, how confirmed, and **how "no operator permission set is reachable" was
    established**.
  - The **CloudTrail read access evidence** section filled: trail scope, the query run, the event
    observed, and the **event-to-visibility delay as a number**.
  - Each gap-able control that was not attached recorded as `GAP: <consequence>` (criterion 5).
  - 1 file modified.
- [ ] **SF-4: The AWS R14.1 third-party record.**
  - `docs/records/third-party-assessments.md` gains `## R14.1 — Amazon Web Services` with an
    explicit `<a id="r141-aws"></a>` anchor, in the existing `Field | Value` shape.
  - The traffic-path field is keyed to **Q1's endpoint classes** and marked **provisional**, with
    03.3 named as the feature that verifies the exact FQDNs (criterion 9).
  - R14.2 is **not applicable** (AWS is not a model provider on this path); the Summary Table row
    says so.
  - A `## T42 — Third-party traffic-path governance (re-inspection, Feature 03.1 SF-4)` section with
    the AWS row, stating the record exists **before** any agent request reaches an AWS endpoint.
  - 1 file, 3 insertions.
- [ ] **SF-5: The static harness, and the carried proposals.**
  - `tests/acceptance/verify-aws-estate.sh` created, house idiom (`set -euo pipefail`, `ROOT`
    resolution, `pass`/`fail`/`phase`/`note`, `=== Results:` termination, exit 1 on any failure):
    - **Phase A — the entitlement record:** every required section present, **including CloudTrail
      read access evidence**; the session duration matches a numeric pattern; the data-perimeter
      cells name a mechanism, a scope and at least one of `aws:ResourceOrgID` / `aws:PrincipalOrgID`,
      and **accept no `GAP:` marker**; the write-grant table present (empty allowed, absent not); the
      criterion-5 cells accept `GAP: <non-empty consequence>`; `filled()` applied throughout; Q1's
      answer and its consequence both present.
    - **Phase B — the R14.1 record:** every R14.1 field row present; `Assessment status` and
      `Resulting constraint on use` consistent (an `Incomplete` status with an empty constraint
      fails); the Summary Table row and the T42 row present; the traffic-path field marked
      provisional with 03.3 named.
    - **Phase C — publishability, scoped to the two AWS records:** no `arn:aws`, no `AKIA`/`ASIA`
      prefix, no `d-[0-9a-z]{10}` SSO instance id, no `*.awsapps.com` start-URL host, and no
      12-digit run **adjacent to AWS context** in those two files. Not a repo-wide scan — Decision 5
      says why.
    - **Phase D — the R6.4.2 / R6.2.2 standing guards:** `*.amazonaws.com` absent from `policy/`,
      `packs/` and `profiles/`; no `AKIA`/`ASIA` key material in `images/` or `compose/`. Both pass
      trivially today and become load-bearing at 03.3 — **stated in the header** so a future reader
      does not read a trivial pass as a proven control.
    - **Phase E — the anchor's real consumer.** A probe pack manifest referencing
      `docs/records/third-party-assessments.md#r141-aws` **passes `scripts/lint-policy.sh`**, and one
      referencing a nonexistent anchor is refused with
      `does not resolve -- no id="…" anchor` — the assertion 03.3 depends on, proved against
      `lint-policy.sh` (the actual enforcement point, `scripts/lint-policy.sh:260`) rather than
      against `compile-policy.sh`.
  - **The two carried proposals, recorded and not applied:** the architecture pointer to the new
    entitlement record, and — only if SF-3 recorded per-agent CloudTrail session naming as
    unreachable — the **R6.3.8 attribution-granularity finding**. The milestone DoD gates on both
    being *put to* the operator.
  - The **R6.5.2 citation observation** (criterion 1) recorded against the milestone README.
  - Criterion-to-evidence table in the entitlement record.
  - ~2 files (1 created, 1 modified).

No sub-feature is oversized. SF-1, SF-3 and SF-4 are single-file documentation; SF-2 is external and
carries no build work; SF-5 is one harness in an idiom with four worked precedents.

## Interface Contracts

### 1. `docs/records/aws-estate-entitlement.md` — the sections phase A parses

```markdown
# AWS Estate Entitlement Design — Feature 03.1

## Principal and permission set
| Field | Value |
|---|---|
| Identity Center principal | <PRINCIPAL_PLACEHOLDER> (dedicated, agent use only) |
| Permission set | <PERMISSION_SET_PLACEHOLDER> |
| Assigned to | that principal only |
| Operator permission sets reachable | none — confirmed by <method> |
| Session duration | **<N> minutes** |

## Write grants per profile
| Profile | Permission | Resource scope | What it permits a compromised agent |
|---|---|---|---|
| (none at this feature) | — | — | — |

## Data perimeter            <!-- no GAP: accepted here (criterion 4) -->
| Field | Value |
|---|---|
| Mechanism | SCP | role policy |
| Scope | organisation | OU | role |
| Condition keys | aws:ResourceOrgID, aws:PrincipalOrgID |

## Permission boundary       <!-- GAP: <consequence> accepted (criterion 5) -->
## Destructive-action denies <!-- GAP: <consequence> accepted (criterion 5) -->
## CloudTrail attribution
## CloudTrail read access evidence
| Field | Value |
|---|---|
| Trail scope | <account | organisation> |
| Query run | <command, placeholder-safe> |
| Event observed | <event name, outcome> |
| Event-to-visibility delay | **<N> seconds | minutes** |

## Q1 — accounts and services, and the consequence
## What this record does not prove
## Criterion-to-evidence table
```

Phase A's rules: every `## ` heading above present; `Session duration` matches
`[0-9]+ *(minute|minutes|min|hour|hours|h|m)\b`; `Event-to-visibility delay` matches
`[0-9]+ *(second|seconds|s|minute|minutes|min)\b`; the data-perimeter `Condition keys` cell contains
at least one of `aws:ResourceOrgID` / `aws:PrincipalOrgID`; `filled()` on every `| Field | Value |`
cell; `GAP:` accepted **only** under § Permission boundary and § Destructive-action denies, and only
with a non-empty consequence after the colon.

### 2. The R14.1 AWS record — the existing shape, not a new one

```markdown
## R14.1 — Amazon Web Services

<a id="r141-aws"></a>

| Field | Value |
|---|---|
| Party | Amazon Web Services, Inc. |
| Role on the traffic path | **Provisional (Q1 endpoint classes; exact FQDNs verified at 03.3).** STS in-region; S3 virtual-hosted in-region; Identity Center endpoints are mediator-side only and absent from every agent allowlist (R6.4.6). Placed on the path by `packs/aws-cli/pack.yaml` at 03.3 |
| What it can observe | <connection metadata vs request content, under D4 splicing> |
| Stated retention | <figure + qualifier, or **Not published.**> |
| Deletion terms | ... |
| Breach-notification path | ... |
| Assessment status | **Complete** | **Incomplete** — <which fields> |
| Resulting constraint on use | <mandatory and non-empty when Incomplete> |
| Date | <ISO date> |
| Source | [label](url) · [label](url) |
```

Summary Table row: `| Amazon Web Services | <status> | No (not a model provider) | <constraint> |`

### 3. `tests/acceptance/verify-aws-estate.sh` — contract

- `set -euo pipefail`; `ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "$ROOT"`.
- `pass`/`fail`/`phase`/`note`; `filled()` copied from `verify-containment.sh` phase A; the
  `expect <want-exit> <fragment> <label> <cmd...>` helper from `verify-mcp-inventory.sh` for phase E.
- Phase E creates a probe pack manifest, refuses to run if one already exists, and removes it in a
  `trap cleanup EXIT` — the `verify-mcp-inventory.sh` scaffolding convention.
- **No Docker, no network, no AWS call, no credential.** Static only — it must run on a machine with
  no AWS access at all.
- Exit `0` when everything passes, `1` otherwise. **No skip variable**, following the
  `retry_cold_peer` reasoning the project has used twice.

### 4. Placeholder vocabulary (fixed here so three features use the same tokens)

`<ACCOUNT_ID>`, `<ORG_ID>`, `<PERMISSION_SET_ARN>`, `<PRINCIPAL_ID>`, `<START_URL_HOST>`,
`<SSO_INSTANCE_ID>`, `<REGION>`. Phase C's patterns are written to **not** match these.

## Edge Cases

1. **The data perimeter cannot be attached.** **03.1 does not close** (criterion 4, operator
   decision). SF-2 is marked BLOCKED, the reason is recorded, and the milestone stalls here rather
   than proceeding to a broker whose only cross-account control is absent. Escalation, not a gap.
2. **Role-chaining for per-agent `RoleSessionName` proves unreachable.** The record states
   per-broker granularity, and the R6.3.8 finding is carried to the operator. 03.2 then builds the
   simpler shape. Criterion 6 is satisfied by either outcome.
3. **CloudTrail read access is missing or delayed.** If absent, recorded as a gap that makes T12
   unverifiable — a 03.4 blocker surfaced here. A long event-to-visibility delay is recorded **as a
   number**, because a drill that polls for 60 s against a 15-minute delay measures nothing (the
   shape of 02.5 SF-5's attempt-1 finding).
4. **A write grant is requested during this feature.** It goes in the table with its blast radius,
   or it does not exist. "Granted, scope TBD" fails `filled()`.
5. **An AWS identifier reaches a record by accident.** Phase C fails and the fix is the placeholder,
   never a phase-C exception.
6. **An incidental 12-digit number elsewhere in the tree.** Not phase C's business — Decision 5.
   `policy/allowlist.base.yaml:141` is the live example.
7. **The estate is changed after this feature closes.** The record carries its date and a review
   trigger; 03.5's re-validation is where drift is caught. Not solved here, stated here.
8. **03.3's exact FQDNs differ from Q1's endpoint classes.** Expected — the R14.1 traffic-path field
   is provisional by construction, and 03.3 owns reconciling it. A silent divergence is the failure
   mode; the provisional marker is what prevents it.
9. **Someone reads a green harness as a proven perimeter.** Criterion 12, the harness header and
   phase D's triviality note all say otherwise. The D16-shaped case: the check cannot see what it is
   being trusted for.
10. **`*.amazonaws.com` appears in a pack before 03.3.** Phase D fails.

## Test Command

```
bash tests/acceptance/verify-aws-estate.sh && bash scripts/lint-policy.sh
```

Records-only feature: the new static harness plus the policy linter — which is also phase E's
enforcement point, so running it directly is not redundant. **The full Milestone 02 composite is not
re-run here**: this feature changes no policy input, no pack, no profile and no image, and the scan
confirmed zero AWS strings in any of those surfaces. 03.3 is where the composite becomes a
regression check again. Per DD-12 the operator may adjust this command at build time without gate
re-approval.

## Test Strategy

- **Static only, and that is a stated limit rather than a convenience.** Every assertion is about
  what the records say. Nothing here proves an estate control works; T10, T12, T13, T19 and T20 do
  that in 03.4, from inside a container against a live broker.
- **Negative controls, each run once and recorded, not left in the suite** — the 02.x convention:
  - phase A: a `TBD` session duration fails; a data-perimeter cell naming no condition key fails; a
    data-perimeter cell marked `GAP:` fails **(the criterion-4 blocking rule)**; a criterion-5 cell
    marked bare `GAP:` with no consequence fails;
  - phase B: an `Incomplete` assessment status with an empty constraint cell fails;
  - phase C: a dummy `arn:aws:iam::<12 digits>:role/x` in a scratch copy of the record fails;
  - phase E: a probe pack naming a nonexistent anchor is refused by `lint-policy.sh` with
    `does not resolve -- no id="…" anchor` — the `verify-tool-packs.sh:175` idiom.
- **Anchor resolution is proven against its real enforcement point.** `scripts/lint-policy.sh:260`
  does the `grep -q "id=\"<anchor>\""`; `compile-policy.sh` does not. Phase E asserts the positive
  and the negative.
- **No phase spends an AWS call, a credential or a model token.**
- **Coverage:** the entitlement record carries the criterion-to-evidence table mapping each
  criterion to a phase, a recorded evidence line, or a named gap.

## Documentation

- `docs/records/aws-estate-entitlement.md` (new) — the entitlement design, the provisioning
  evidence, the CloudTrail read-access evidence, Q1's consequence, the named gaps, the
  criterion-to-evidence table, and the "what this record does not prove" section.
- `docs/records/third-party-assessments.md` (modify) — the R14.1 AWS record with its `r141-aws`
  anchor and provisional traffic-path field, the Summary Table row, the T42 section.
- `tests/acceptance/verify-aws-estate.sh` (new) — phases A–E, with the static-only limit in its
  header.
- `README.md` (modify) — a short "AWS access (03.1)" note: what exists (the estate design and the
  records), what does not (no pack, no broker, no AWS credential), and the standing statement that
  **the R12.8 notice remains in force for AWS-loading profiles**.
- **A dependency stated for 03.3:** the R14.1 traffic-path field is provisional and 03.3 verifies
  the exact FQDNs against it, reconciling or amending the record.
- **Not edited here:** `docs/ARCHITECTURE_AND_DESIGN.md`, `prd.md`, and the milestone README. The
  architecture pointer, the conditional R6.3.8 finding and the R6.5.2 citation observation are
  carried as proposed edits/observations, as 02.3, 02.4 and 02.5 each did.
- **Already applied, not carried:** `REQUIREMENTS.md`'s Q1 and Q9 rows (operator-accepted
  2026-10-04), which is why this plan cites the register.
- **No credential-inventory row** (Decision 1).

## Files to Create/Modify

| File | Action | Changes |
|------|--------|---------|
| `docs/records/aws-estate-entitlement.md` | Create | The entitlement design (SF-1), the provisioning and CloudTrail evidence (SF-3), the criterion-to-evidence table (SF-5) |
| `docs/records/third-party-assessments.md` | Modify | R14.1 AWS record + `r141-aws` anchor, Summary Table row, T42 section (SF-4) |
| `tests/acceptance/verify-aws-estate.sh` | Create | Phases A–E, static only (SF-5) |
| `README.md` | Modify | "AWS access (03.1)" note; R12.8 still in force for AWS profiles (SF-5) |
| `.project/.../milestone-status.txt` | Modify (by `/build`) | Sub-feature progress |

## Dependencies

- **Q9 answered yes — satisfied, and now in the register** (`REQUIREMENTS.md`, Q9, 2026-10-04). The
  start-gate; a negative answer would have invoked the milestone's fail-closed outcome instead of
  this plan.
- **Q1 answered — satisfied, and now in the register** (`REQUIREMENTS.md`, Q1, 2026-10-04): a broad
  S3 surface, carried through Decision 3.
- **Assumption A5 holds** — the estate is modifiable. The same dependency as Q9 from the other side.
- **The operator's organisation** for the principal, the permission set, the data perimeter, the
  permission boundary, the destructive denies and CloudTrail read access. **SF-2 is that
  dependency, made explicit as a sub-feature with a blocked state** rather than left as a note.
- **CloudTrail read access** — without it, criterion 10 is a gap and T12 is unverifiable in 03.4.
- **Milestone 02 complete** — satisfied. The record conventions, the `filled()` idiom and the
  anchor-resolution enforcement this plan reuses all landed there.
- **Not a dependency: R8.8/T34.** That gates 03.2's broker (D6), not this feature — and it is
  satisfied by 01.3/01.6 in any case.

## Review Revisions

External review of the first draft (2026-10-04) raised eight findings. Two were verified against the
code before acting: anchor enforcement really is `lint-policy.sh:260` and not `compile-policy.sh`,
and a repo-wide 12-digit scan really would have been red on arrival
(`policy/allowlist.base.yaml:141`). All eight are applied:

| Finding | Applied as |
|---|---|
| CloudTrail evidence had no record section and no phase-A check — the criterion could pass by omission | A required **CloudTrail read access evidence** section (Contract 1), a numeric delay, and a phase-A failure if absent (criterion 10) |
| The anchor was proved by compile, but enforced by `lint-policy.sh` | **Phase E**, asserting the positive and negative against `lint-policy.sh` (criterion 9, Test Strategy) |
| Q1 was treated as resolved while the register said "Open" | The register was **amended** (operator-accepted 2026-10-04) and the plan now cites it |
| R6.5.2 is Model-A-scoped and cannot hold under Model B | Criterion 1 rests on **R6.3.2**, with the Model-B verification at R6.5.3/R6.5.4/R6.5.6 in 03.4, and the README's citation recorded as an observation |
| Named gaps contradicted the README's acceptance criteria | **Operator decision:** the data perimeter **blocks** (criterion 4, Edge Case 1); the permission boundary and destructive denies are gap-able (criterion 5). Justified by Q1's answer, so no README change is needed |
| SF-2 required operator action with no defined blocked state | Split into **SF-2 (external precondition, with a BLOCKED state and a stop rule for `/build`)** and **SF-3 (buildable evidence recording)**; five sub-features now |
| SF-3's R14.1 FQDNs depended on 03.3's unbuilt pack | The traffic-path field is **provisional, keyed to Q1's endpoint classes**, with 03.3 named as the verifier (criterion 9, Edge Case 8) |
| Phase C's repo-wide scan was over-broad and red on arrival | **Scoped to the two AWS records** with AWS-specific patterns (Decision 5, Edge Case 6). The rule is repository hygiene, not an R6.2.2 claim — criterion 11 covers R6.2.2 separately |

## Architectural Deviations

1. **SourceIdentity added as a trust-policy gate alongside RoleSessionName (criterion 6).** The plan
   specified attribution via `RoleSessionName` carrying the R8.8 workload identity. The estate build
   (tg-infra, SF-2) sets both `RoleSessionName` and `sts:SourceIdentity` when chaining into
   `AgentSandboxReadOnlyRole`, but enforces only `SourceIdentity` in the role's trust policy
   (`StringLike sts:SourceIdentity "?*"` — AssumeRole fails without it, confirmed by live test).
   `RoleSessionName` is still set and recorded on the CloudTrail event, but is not itself a trust
   condition. Accepted: `SourceIdentity` is trust-enforceable and persists across role chaining in a
   way `RoleSessionName` alone does not, which strengthens the per-agent attribution criterion 6 asks
   for rather than weakening it. Recorded 2026-10-17, operator-accepted.
