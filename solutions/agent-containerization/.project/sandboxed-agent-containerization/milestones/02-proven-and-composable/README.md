# Milestone 02: Proven and Composable

> **Authority.** [`REQUIREMENTS.md`](../../../../REQUIREMENTS.md) is the authoritative register (R1–R15,
> SC-1…SC-8, T1–T45). [`docs/ARCHITECTURE_AND_DESIGN.md`](../../docs/ARCHITECTURE_AND_DESIGN.md) is
> the ratified design (D1–D21). This document cites both by ID and restates neither. Where they
> disagree with anything here, they win.
>
> **Gate-1 label.** The architecture document was written against the two-milestone Gate 1 shape and
> says "until M2 completes" in several places. Gate 3 mapped Gate-1 M2 onto this milestone and
> carved AWS out into Milestone 03 — see [`prd.md` § Milestones](../../../../prd.md).

## Goal

The operator can use the sandbox for **real work that does not require AWS**. The enforcement
boundary has been tested adversarially rather than assumed (R12.8), a use case can add or remove
tooling without hand-editing the security policy (SC-6), and the environment rebuilds from version
control with no manual steps (SC-8).

On the audit side the claim is narrower than "everything is recorded", and deliberately so: every
**destination** an agent attempted is recorded outside its blast radius and attributable to it
(SC-7), and each agent's action transcript is recorded alongside it **complete-as-written** —
tamper-evident, not tamper-resistant, because the agent authors it (D20).

**A session that needs AWS still waits for Milestone 03.** SC-5 is not in scope here. The
"not for real work" notice R12.8 requires comes off at the end of this milestone for every profile
that does not load the AWS pack — and that pack does not exist yet.

## Features

### Feature 02.1: Audit completeness — agent action log, sink and exports

Milestone 01 built the egress half of the audit trail inside the mediator. This feature builds the
half that no network control can produce, and it lands **before** 02.2 because R12.8 requires each
adversarial scenario to record whether the attempt was blocked, **logged and attributable** — two of
those three come from here.

**Acceptance Criteria:**

- The **agent action recorder** ships each agent's native session transcript off-container in real
  time to an append-only sink: Claude Code JSONL session files, Codex session logs, `agy` JSON
  output (R9.7, D20). It reads the transcript path on each agent's state volume and writes to the
  audit sink only — never back to any agent-reachable path.
- The **audit sink** holds the egress log and the agent action log outside every agent's blast
  radius: inside the mediator or shipped directly off-host, never a volume an agent container can
  reach or alter (R9.2, D12).
- Action-log lines correlate with the mediator's egress lines by **session identifier and
  timestamp**, and carry the R8.8 workload identity issued in 01.3, so a line says which agent did
  it rather than only that something did (R9.8) — **T35**, including the retroactive-edit half: an
  edit to the on-volume transcript after shipping does **not** propagate to the sink.
- **R9.7's privilege-change limb is covered, or its absence is recorded.** T35 exercises a tool
  invocation and a file modification only; R9.7 also names privilege changes. Either a
  privilege-change event is recorded, or the acceptance criterion is the recorded finding that no
  such event is reachable — agent containers run non-root with `cap_drop: ALL` and
  `no-new-privileges` (D15), which is a structural answer rather than an untested assumption.
- **D20's limitation is recorded in the shipped documentation, not designed around.** The agent
  authors its own transcript, so the record is complete-as-written and tamper-*evident*, not
  tamper-*resistant*. A compromised agent can write a false line before it ships. Stating this is
  the acceptance criterion; closing it is not in scope for any milestone here.
- Each of the four exports — egress log, agent action log, resolved egress policy, image digest plus
  SBOM — can be disabled individually in a profile, and **recording continues in every case**, with
  each disabled export explicitly recorded (R9.9, D11) — **T36**.
- Agent session transcripts are checked to confirm they do not capture credential values from
  command output, and any leak found is recorded with its mitigation (R8.6).
- Detection stays **pull-based by decision**: R9.6 push alerting is not built. The review trigger —
  a blocked attempt going unnoticed long enough to matter — is recorded in the runbook (`prd.md`
  § Future Enhancements).
- **T16 (audit completeness) is recorded during 02.2's run, not here.** Its method is "review the
  logs after T3–T7", and T3–T7 execute in 02.2. This feature builds what T16 inspects.

### Feature 02.2: Adversarial boundary validation

The step the architecture's bring-up sequence calls step 4, and the gate R12.8 places in front of
real use. Everything before this validated that the allowlist is *sufficient*; nothing yet validated
that the boundary is *effective*.

**Acceptance Criteria:**

- `validate-boundary.sh` exists as a committed, re-runnable suite and executes **all six R12.8
  scenarios**: DNS exfiltration, network-isolation routability, post-resolution CIDR deny under CDN
  rotation, policy modification from inside a container, agent-to-agent reachability, and a
  repository seeded with injected instructions. Each scenario records whether the attempt was
  **blocked**, whether it **appeared in the log**, and whether it was **attributable** — **T38**.
- **T1–T8 pass as recorded adversarial acceptance**, not as the smoke checks 01.2 and 01.3 ran:
  host filesystem containment, read-only enforcement, HTTP/HTTPS exfiltration, DNS exfiltration, raw
  TCP, CDN rotation, the metadata endpoint, and policy tampering from inside. Results are recorded
  per test, per agent.
- **T16** passes against the 02.1 sink: every attempt made during T3–T7 is present with its
  destination and verdict, blocked attempts included (SC-7, R9.1).
- Read-only mounts are verified as **actually enforced by the host's filesystem sharing layer** —
  Docker Desktop on macOS uses VirtioFS, which fakes ownership but is documented to enforce
  read-only. T2 passing inside the container is not the same claim (R11.4).
- **The `provisional` marker on `policy/allowlist.base.yaml` is resolved.** A shadow run of all three
  agents under the built mediator is the second source D17 requires; where it disagrees with the
  Docker Sandboxes capture the allowlist is amended, and the marker is removed from the file only
  once both sources agree (R5.8, D17). A remaining disagreement is recorded as a named gap, not
  silently dropped.
- Which threat-model injection sources were exercised and which were **not** is recorded. On the
  current design the **stdio MCP vector is not exercised**, because a stdio server is a subprocess of
  the agent and its tool calls cross no enforcement point (D18). This is a recorded blind spot, not
  a test failure.
- SC-1, SC-2 and SC-3 are demonstrated, each against the measurement its `prd.md` Goals row states.

### Feature 02.3: Tool pack set, use-case profiles and MCP inventory

01.5 built the composition mechanism and exercised it with one pack that declares no runtime egress.
This feature is where SC-6 is actually measured: real packs, with real egress entries, real mounts
and real credentials, and the MCP inventory that R7.14 makes subject to the same review as any pack.

**Acceptance Criteria:**

- The remaining R7.10 packs ship: **Terraform/OpenTofu**, **Kubernetes** (`kubectl`, `helm`) and
  **GitHub CLI**. Each declares its own pinned packages with checksums, egress FQDNs and CIDRs,
  mounts and modes, environment variables, credentials, write-access need, and its blast-radius
  contribution (R7.3, R7.11). AWS CLI is Milestone 03.
- **Every third party this feature places on the agent traffic path carries an R14.1 record before
  any traffic reaches it** — HashiCorp (`releases.hashicorp.com`, `registry.terraform.io`), GitHub,
  and the Kubernetes registries and clusters the pack reaches. 01.1 recorded Docker Sandboxes and the
  three model providers only; R14.1 is a MUST and applies per third party, not once per project.
  **T42 is re-run and extended** to cover each of them.
- **02.3 owns T14's recorded acceptance.** Terraform is the clean case — `releases.hashicorp.com` and
  `registry.terraform.io`, no credential. Loading it adds exactly its entries to the resolved policy
  and unloading removes them with no residue (R7.5). 01.5's run with the language-runtimes pack
  exercised OS-package and mount composition only, because that pack declares no runtime egress —
  which means it cannot satisfy T14's pass condition ("egress policy gains and loses exactly that
  pack's entries"). 01.5's run is therefore a prerequisite exercise and T14 passes as recorded
  acceptance here. **This reassigns T14 from 01.5, which the approved Milestone 01 README names as
  its owner** — see the Reviewer Comments in this milestone's `gate-3-review.md`.
- **Credential-bearing packs state their delivery model explicitly.** GitHub CLI carries a token and
  Kubernetes carries a `kubeconfig`. Upstream brokering (R8.3) is the mediator's fifth role and sits
  in **Milestone 03** — until then these credentials are secret-injected or volume-resident, and each
  is enumerated under R8.4 with its blast radius stated, individually reviewable and **independently
  revocable** (R7.12). Each feeds 02.5's revocation timing. R8.3 is a SHOULD; this records why it is
  not yet met rather than asserting it is.
- **Every pack credential is scoped to the single use-case profile that needs it** (R8.2, MUST). Under
  a profile that does not load the GitHub CLI pack, no GitHub token is reachable from any agent
  container; likewise the Kubernetes `kubeconfig`. Verified by inspection from inside each container,
  not by declaration.
- Named **use-case profiles** exist as version-controlled selections of packs, mounts, `AUTH_MODE`
  per agent, OS packages and export toggles (R7.9, R2.2). **SC-6 is measured by switching profile
  and confirming the resolved egress policy recomposes automatically**, with no hand-edit of any
  policy file.
- No pack may require capabilities, privileges or host access beyond the base container. A pack
  needing more is a design change requiring review, not a configuration change (R7.8).
- **The MCP inventory is built and enforced.** Every MCP server, plugin and skill is inventoried in
  the profile, version-pinned, and carries a risk tier (read-only / write / irreversible) plus a
  capability baseline (R7.14, D18). An uninventoried server is refused; a capability change on an
  inventoried server is reported as **drift**, not silently accepted — **T29**.
- **Each inventory entry carries the full R7.3 field set**, because R7.14 reviews MCP servers on the
  same basis as any other tool pack: pinned version with checksum, required egress FQDNs and CIDRs,
  required mounts and their mode, environment variables, credentials, and whether it needs write
  access. A field that does not apply is recorded as an explicit N/A, not omitted.
- Every inventoried server records its **transport** and names the enforcement point covering it, or
  states explicitly that none does. The stdio case states that none does (R7.15, D18) — **T30**. The
  per-agent transport defaults recorded in 01.1 are the input.
- Servers install only from a declared registry pinned in the profile. No wholesale package-registry
  egress entry permits arbitrary `npx <server>` — **T31**, re-verified against every profile the
  pack set introduces, since a registry entry added by any pack would defeat it.
- Each agent's **capability-declaration file** is enumerated and treated as a configuration change
  requiring review. An attempt to write it from inside the agent is blocked for Claude Code via
  `srt`; where it is not blocked, **the test records the gap rather than passing** (R7.17, D14) —
  **T32**.
- **`validate-boundary.sh` re-runs against every shipped profile** and the results are recorded. Each
  new pack adds egress entries, a mount or a credential to a boundary that was validated without
  them — the same reason Milestone 03 re-runs the matrix for the AWS pack.

### Feature 02.4: Reproducibility, provenance and onboarding

What makes SC-8 checkable rather than asserted, and what makes the environment usable by an operator
who did not build it.

**Acceptance Criteria:**

- **T18 clean rebuild:** rebuilding from version control on a clean machine produces a functionally
  identical environment with **no manual steps** (SC-8, R10.1). The rebuild covers the final pack set
  from 02.3, not the 01.5 reference pack. The clean machine is **macOS 26 on Apple silicon**, which is
  where R11.1 (MUST) is discharged as an owned check rather than assumed from the build host.
- **T45 published base image provenance:** the image the compose file consumes resolves to a
  CI-published GHCR digest with an SBOM. No profile consumes a mutable tag, and no branch-built image
  is consumed outside testing (D21, R10.2, R10.7).
- **D21's promotion trigger is brought forward to this milestone — amendment approved at Gate 3,
  2026-09-04.** D21 as ratified states the workflow builds from the working branch during the project
  and moves to `main` "on project completion", with branch-built images for testing only. Milestone 02
  is the real-work gate, so under the ratified trigger its Definition of Done would be satisfied by an
  image D21 says not to use — and project completion now sits behind Milestone 03's external Q9
  dependency, which may never resolve. This feature therefore **promotes the workflow to `main` (or an
  equivalent release ref)** and records the amendment to D21's stated trigger as a proposed edit to
  `docs/ARCHITECTURE_AND_DESIGN.md`, for application by an authority that may edit that document.
  `/milestone` does not edit it.
- **T39 entry point:** a fresh operator brings the environment up by following the README. `docker
  compose` with a profile-selected override is the only entry point and no wrapper CLI exists
  (R12.9, R12.1). Onboarding documentation covers first-run authentication for all three agents
  (R12.6); the AWS SSO half of R12.6 is Milestone 03.
- A **documented procedure for adding a destination to the allowlist** exists, naming who reviews it
  (R12.3). A **documented agent-version update path** exists and re-verifies the policy after each
  bump, because agent egress requirements change between releases (R10.6).
- The image builds without network access to anything outside the declared build allowlist (R10.4).
- **Two proposed edits to `docs/ARCHITECTURE_AND_DESIGN.md` are recorded for an authority that may
  apply them:** the D21 promotion-trigger amendment approved at Gate 3, and the addition of the
  **GitHub CLI pack** to the component inventory and file tree, which list the R7.10 pack set without
  it. `/milestone` applies neither.
- **R11.2 is assessed, not exercised.** Q2 settled deployment scope as one workstation, so R11.2 stays
  a SHOULD: any construct that would require architectural change on a Linux host is recorded. A
  Linux test run is not in scope.

### Feature 02.5: Containment, response and the authorization gate

Every feature above this one is preventive or detective. This is what happens after a detection —
D1's accepted weakness is that Option 2 has the worst recovery-to-known-good of the three options,
and D16 is the answer.

**Acceptance Criteria:**

- **T26 revocation half:** for each credential type the design persists, the documented revocation
  procedure is **executed and timed**, with a stated maximum time from detection to revocation
  (R13.1, R8.5). The one-year `CLAUDE_CODE_OAUTH_TOKEN` is the longest-lived and the priority; the
  02.3 pack credentials (GitHub token, `kubeconfig`) are included. 01.4 owns the inventory half.
  **Each rotation and revocation completes without rebuilding the environment** (R8.5, MUST) — where
  one cannot, the rebuild requirement is recorded as a named gap against R8.5 rather than folded into
  the timing.
- **T40 single-agent isolation:** stopping one agent container leaves the other two unaffected — a
  native property of the per-agent networks in D2 (R13.2). **The MCP-disable half is recorded as a
  proposed amendment, not built.** Disabling one MCP server across all agents currently requires a
  profile change plus rebuild; no live mechanism exists. Milestone 02 records the rebuild-required
  limitation as a **proposed amendment to R13.2 and T40** for approval against `REQUIREMENTS.md`.
  `/milestone` has no authority to edit the register, so **R13.2 stays formally unmet until the
  amendment is accepted.**
- **T41 return to known-good:** the documented recovery path is executed against a deliberately
  contaminated environment and completes, stating explicitly what happens to **each** persistent
  state volume. The path is *discard and re-bootstrap*, because a contaminated volume cannot
  currently be distinguished from a clean one — that is recorded, not solved (R13.3, D16).
- Tearing down a session destroys ephemeral state and preserves the declared persistent volumes
  (R12.5), which is the property T41's discard step deliberately overrides.
- **T37 human authorization gate:** an action the profile classifies as irreversible or high-impact,
  attempted unattended, halts for authorization — or the profile carries the explicit recorded waiver
  (R12.7). 01.5 built the profile field; this verifies the gate. The tension with assumption A2 is
  recorded rather than resolved.
- **T44 ToS monitoring and mediation seam:** a simulated provider terms change triggers re-review of
  the affected access route under the R14.3 owner named in 01.1, and the mediator's extension points
  are inspected to confirm a tool-call mediation layer could be hosted without redesign (R15.2).
- **Event versus incident is defined before go-live**, as the architecture's containment runbook
  requires. The runbook ships with the four containment actions: cut egress, isolate one agent,
  disable one MCP server (with its rebuild caveat), rotate credentials, return to known-good.

## Dependencies

- **All of Milestone 01.** This milestone tests, composes on top of, and documents what 01 built.
  There is no partial start: 02.1 needs 01.3's mediator identity and audit stream, 02.2 needs the
  whole pod, 02.3 needs 01.5's policy compiler.
- **02.1 gates 02.2.** R12.8 requires each scenario to record blocked / logged / attributable.
  Without the action log, the sink and the correlation, two of those three are unavailable and the
  adversarial run has to be repeated.
- **02.4 carries the approved D21 amendment.** The promotion to `main` is what makes the published
  digest usable for real work, and therefore what lets this milestone lift the R12.8 notice. The
  amendment is approved as a Gate 3 decision; applying it to `docs/ARCHITECTURE_AND_DESIGN.md` is a
  follow-up outside `/milestone`'s authority.
- **No dependency on Milestone 03.** SC-5 is out of scope here. Q1 and Q9 should already have been
  raised with the operator's organisation during Milestone 01; they block only Milestone 03 (D13a).
- **External:** Docker Desktop on macOS 26, Apple silicon (R11.1, A1). GitHub Actions and GHCR for
  02.4. For T18, a clean **macOS 26 Apple-silicon** machine or an equivalent clean environment on
  that host class — R11.1 is the class the rebuild must be proven on, so a Linux runner does not
  substitute.

## Ordering

Second milestone. It follows 01 because there is nothing to validate until the pod exists, and it
precedes 03 for two reasons recorded at Gate 3: Q9 is an external dependency with unknown lead time,
so a gated milestone in second position would block the third; and the AWS milestone's credential
brokering is hard-gated on per-agent workload identity (R8.8, D6, D13) in a way this milestone is
not. **That is not a claim that this milestone forgoes attribution.** R8.8 lands in 01.3, so the
identity exists before 02.1 starts and both 02.1's correlation and 02.2's T38 attributability
criterion depend on it — `prd.md`'s "degrades gracefully" phrasing is the fallback argument for the
ordering choice, not a licence to skip attribution here. If R8.8 were absent, T38 could record
blocked and logged but not attributable, and R12.8 would not be satisfied.

Internally the order is 02.1 → 02.2 → 02.3 → 02.4 → 02.5:

- **02.1 before 02.2** — the R12.8 record is three-part and this feature supplies two parts of it.
- **02.2 before 02.3** — the R12.8 gate is the milestone's reason to exist and should not sit behind
  pack work, which is the part of the milestone most likely to churn. The cost is that 02.3 re-runs
  `validate-boundary.sh` against every profile it introduces.
- **02.4 after 02.3** — the clean rebuild and the published digest must cover the final pack set, not
  an intermediate one.
- **02.5 last** — return-to-known-good and the revocation timings exercise everything above them,
  including the 02.3 pack credentials.

## Sizing

Five features — the DD-1 ceiling, as in Milestone 01, and again a consequence of the milestone being
indivisible: the R12.8 notice cannot come off until all five land.

- **02.3 is the largest, and is over the ceiling in substance rather than in count.** It carries two
  distinct bodies of work — three tool packs with credential handling and R14.1 governance, and the
  MCP inventory with four of its own tests (T29–T32). A sixth feature would breach DD-1, and R7.14
  places MCP servers under the same review basis as any tool pack, which is why they are co-located.
  The planned split at `/plan` time is along that seam: pack set and profiles, then MCP inventory and
  drift detection. **Named fallback if it runs long:** the MCP inventory half moves to its own
  milestone via `/milestone` revision mode. Deferring it silently inside 02.3 is not the fallback.
- **02.2 is the second largest** and is testing-shaped rather than build-shaped: one harness
  (`validate-boundary.sh`), six R12.8 scenarios and eight recorded tests. Its risk is not size but
  outcome — a failure here is a design finding against Milestone 01, not a bug to fix inside 02.2.
- **02.1 and 02.5** are each a single reviewable unit. 02.5 is documentation-and-drill heavy: three
  of its criteria are executed procedures with recorded timings rather than code.
- **02.4 is small in build terms.** Its long pole is access to a clean machine for T18; the D21
  promotion is a one-time workflow change.

## Configuration

| Parameter | Value at this milestone |
|---|---|
| `profile` | Named use-case profiles arrive in 02.3, alongside `default` |
| Tool packs | Terraform/OpenTofu, Kubernetes, GitHub CLI, language runtimes. **AWS CLI is Milestone 03** |
| MCP servers | Default-off, inventoried, version-pinned, from a declared registry (R7.14–R7.16, D18) |
| `policy/allowlist.base.yaml` | `provisional` marker resolved in 02.2 after the shadow run under the built mediator |
| Base image | Consumed by digest. Source ref promoted from the working branch to `main` in 02.4, per the approved D21 amendment |
| Exports | All four on by default; individually disableable, recording is not (R9.9, D11) |

## Definition of Done

- [ ] All features complete (`[x]` in `milestone-status.txt`)
- [ ] All acceptance criteria verified
- [ ] `gate-3-review.md` checklist fully resolved
- [ ] `milestone-status.txt` updated with final counts
- [ ] `progress.txt` milestone summary shows 5/5 features complete
- [ ] SC-1, SC-2, SC-3 demonstrated adversarially and recorded (T1–T8, T38)
- [ ] SC-6 demonstrated: switch use-case profile, egress policy recomposes with no hand-edit (T14)
- [ ] SC-7 demonstrated: every attempt from T3–T7 present in the sink with destination and verdict
      (T16), correlatable and attributable (T35)
- [ ] SC-8 demonstrated: clean-machine rebuild, no manual steps (T18), against a CI-published digest
      with an SBOM (T45)
- [ ] `policy/allowlist.base.yaml` no longer carries the `provisional` marker, or the remaining
      disagreement is recorded as a named gap
- [ ] Every third party added to the agent traffic path by 02.3 carries an R14.1 record, and T42
      covers all of them — not only the 01.1 set (R14.1 is a MUST per third party)
- [ ] Both amendments are recorded as proposed edits for an authority that may apply them:
      **R13.2/T40** (rebuild-required MCP disable, against `REQUIREMENTS.md`) and **D21** (promotion
      trigger, against `docs/ARCHITECTURE_AND_DESIGN.md`, approved at Gate 3 on 2026-09-04).
      `/milestone` applies neither
- [ ] **The R13.2/T40 amendment is accepted, or a targeted MCP/tool disable path is built.** R13.2 is
      a MUST. A recorded proposal is not acceptance, and the milestone does not lift the notice with
      a MUST outstanding
- [ ] **The D21 amendment is applied to `docs/ARCHITECTURE_AND_DESIGN.md`.** Until it is, the design
      document still says branch-built images are testing-only and the promotion waits for project
      completion — a live contradiction with the promotion 02.4 performs
- [ ] The **"not for real work" notice (R12.8) is lifted for every non-AWS profile**, once the two
      conditions above are met. A session requiring AWS still waits for Milestone 03
