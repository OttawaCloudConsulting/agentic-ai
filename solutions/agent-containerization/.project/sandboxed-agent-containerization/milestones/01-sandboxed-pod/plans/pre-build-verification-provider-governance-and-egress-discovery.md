# Feature Plan: Pre-build verification, provider governance and egress discovery

**Milestone:** 01 - Sandboxed Pod
**Feature:** 01.1: Pre-build verification, provider governance and egress discovery
**Status:** Planned
**Date:** 2026-09-04

## Summary

Resolves the UNVERIFIED items the architecture names as build blockers, and produces the
governance records and seed policy that Features 01.2-01.5 build against. Its output is records,
verification results and two policy files — not application code. It runs **before** any build work
and gates it: a negative `agy` `HTTPS_PROXY` result is a design change under D1 for one agent, not a
build task, and routes to `/milestone` revision mode rather than to a failed feature. The repository
is confirmed greenfield for this feature — no `policy/`, `compose/`, `profiles/`, `packs/`, scripts
or CI exist anywhere in the solution tree, and the repository root has no `.github/`.

## Acceptance Criteria

Restated from the milestone README with implementation detail. Requirement IDs are authoritative in
`REQUIREMENTS.md`; design IDs in `docs/ARCHITECTURE_AND_DESIGN.md`.

**Governance records (R14) — verified by T42 and T43**

1. An R14.1 record exists for **every** third party on the agent traffic path before any traffic
   reaches it — Docker Sandboxes, Anthropic, OpenAI, Google — each stating what the party can
   observe, its stated retention period for that data, its deletion terms and its
   breach-notification path. Where an assessment cannot be completed, the **resulting constraint on
   use is recorded** rather than left implicit.
2. Each of the three model providers additionally records its version-pinning capability or its
   absence, the history-retention and training-opt-out setting **actually in use**, and the data
   classification permitted to leave (R14.2).
3. Antigravity ToS monitoring (R14.3) has a **named owner** recorded, replacing the Gate 2
   open-items entry "Unassigned — needs a named person", together with the review trigger that
   fires re-review (Google clarifies, terms change, or public-API billing becomes material).

**Verification results (the go/no-go gate)**

4. `agy` verified against the pinned version, completed before 01.2 begins:
   (a) whether it honours `HTTPS_PROXY`; (b) whether the `GEMINI_API_KEY` route works, given the
   official install page documents it and a June 2026 maintainer statement contradicts it;
   (c) its CA-trust mechanism. **The criterion is that each result is recorded, not that each
   passes.**
5. Each agent's HTTP client is verified to be capable of **presenting a client certificate to a TLS
   proxy listener at all**. Current documented state: Claude Code exposes
   `CLAUDE_CODE_CLIENT_CERT` / `_KEY` / `_KEY_PASSPHRASE`; **Codex has no documented client-certificate
   variable at all** — unknown rather than untested; `agy` undocumented. If none of the three can,
   R8.8's mechanism changes shape and 01.3's largest sub-feature becomes a redesign.
6. The default MCP transport is recorded per agent and per configured server — UNVERIFIED for all
   three today, and the input R7.15 needs. Where a transport is stdio, the record states which
   enforcement point covers it, **or states that none does**.
7. The agent version pins that 01.2's Dockerfiles will consume are chosen and recorded here, since
   criteria 4-6 are defined as "against the pinned version".

**Discovery and seed policy**

8. A discovery run under Docker Sandboxes `locked-down` mode (never `balanced`), one agent at a
   time, against a **synthetic repository with throwaway credentials only** (D17, R12.4, R14.1).
9. `policy/allowlist.base.yaml` and `policy/denylist.base.yaml` are committed. The allowlist is
   seeded from the capture and cross-validated against a second source, and is marked
   **provisional** until both sources agree (R5.8, D17). No vendor reference allowlist is copied
   verbatim.
10. The denylist covers link-local `169.254.0.0/16` including `169.254.169.254`, loopback and
    RFC1918 (R5.6).

## Approach

Three sub-features in strict dependency order: SF-1, then SF-2, then SF-3.

**SF-1 precedes SF-3** because R14.1 requires the record to exist *before* the third party is placed
on the traffic path, and the discovery run puts Docker Sandboxes on it.

**SF-2 precedes SF-3** because SF-2 chooses the agent version pins and SF-3's capture is only valid
against them. R10.6 is explicit that agent egress requirements change between releases and the
policy is re-verified after each bump — a capture taken against unpinned agents seeds an allowlist
for versions the build will not run. SF-3 must run against exactly the pins SF-2 records.

SF-2 is additionally the go/no-go gate on 01.2-01.5.

**On the Docker Sandboxes assessment specifically.** Open Decision 3 records its retention and
data-handling terms as "not established", owner unassigned. D17 resolves this: the run proceeds
under the synthetic-repository and throwaway-credential constraint, and **the constraint is the
mitigation**. `/build` records the assessment as incomplete with that constraint attached and
continues — it does not stall waiting on Docker's legal terms.

**On cross-validation.** The criterion offers "agent verbose logging **or** `tcpdump` on the
mediator during a shadow run". No mediator exists until 01.3, so within 01.1 the second source is
**agent verbose logging**. The mediator-`tcpdump` shadow run is a later re-validation and is not
available here. The allowlist stays provisional either way until both sources agree.

**On the client-certificate check.** Nothing in the environment asks an agent for a client
certificate today, so the check needs a target. SF-2 stands up a **throwaway** TLS listener with
client-certificate verification enabled, reachable only over an `internal: true` network so that the
proxy is the sole route — which makes the same fixture serve as the real `HTTPS_PROXY` test: a
client that ignores proxy configuration has no route and simply fails. Scoped as throwaway so
`/build` neither skips the check nor starts building 01.3's mediator.

**On the allowlist shape.** The capture is taken one agent at a time and keyed per agent. A union
across all three agents is the failure mode the bring-up sequence names explicitly; the file shape
enforces the split so 01.5's policy compiler inherits a per-agent policy rather than a merged one.

## Sub-Features

- [x] **SF-1: Third-party and provider governance records** — Four R14.1 records (Docker Sandboxes,
  Anthropic, OpenAI, Google), three R14.2 provider records, and the R14.3 named owner with its
  review trigger. Converts the existing upstream research in `docs/RESEARCH_FINDINGS.md` — which is
  vendor-documented but not assessed — into records in the form R14.1 demands. Incomplete
  assessments are recorded with their resulting constraint, not deferred.

- [x] **SF-2: Agent client verification (go/no-go gate on 01.2-01.5; prerequisite of SF-3)** — Choose
  and record the three version pins — required by SF-3, whose capture is only valid against them
  (R10.6) — then against those pins verify: `agy` `HTTPS_PROXY` honouring, `GEMINI_API_KEY`
  route, and CA-trust mechanism; client-certificate presentation for all three agents; default MCP
  transport per agent and per configured server. Includes the throwaway TLS listener and
  `internal: true` fixture. Every result is recorded whether it passes or fails.

- [x] **SF-3: Egress discovery, seed allowlist and denylist** — Runs only after SF-1 and SF-2. The
  constrained `locked-down` discovery run against a synthetic repository, **at the SF-2 pins**, one
  agent at a time; seed `allowlist.base.yaml` from
  the capture; cross-validate against agent verbose logging; write `denylist.base.yaml`. Kept whole
  rather than split per agent: three capture runs share one seeding pass, one cross-validation pass
  and one denylist, and splitting would triple state-file churn for no isolation gain.

## Interface Contracts

**Record schema.** Every R14.1 record carries: `party`, `role on the traffic path`, `what it can
observe`, `stated retention`, `deletion terms`, `breach-notification path`, `assessment status`
(complete | incomplete), `resulting constraint on use` (required when incomplete), `date`, `source`.
Every R14.2 record adds: `version-pinning capability` (or explicit absence), `history-retention
setting in use`, `training-opt-out setting in use`, `data classification permitted to leave`.

**Version pin record — consumed by 01.2.** `agent`, `version`, `image digest or install source`,
`date pinned`. This is a cross-feature contract: 01.1 chooses the pins because criteria 4-6 are
defined against them; 01.2's Dockerfiles consume them.

**`policy/allowlist.base.yaml`** — keyed per agent, never a union. Typed entry lists, because R7.3
requires a pack manifest to declare "required egress FQDNs **and CIDRs**" and R7.4 composes the
effective policy from this base plus those packs — a base that can only express FQDNs cannot compose
with a CIDR-bearing pack:

```yaml
provisional: true          # D17 — until capture and cross-validation agree (not R5.8)
pins: agent-verification.md    # the SF-2 pins this capture was taken against (R10.6)
sources: [sbx-capture, agent-verbose-log]
agents:
  claude:
    allow_fqdns:
      - fqdn: api.anthropic.com
        port: 443
        upgrade: false     # R5.9 — Upgrade permitted on TCP/443 where an agent requires it
        source: [sbx-capture, agent-verbose-log]   # per-entry provenance
    allow_cidrs: []        # R7.3/R7.4 — shape must compose with CIDR-bearing packs
  codex:  {allow_fqdns: [], allow_cidrs: []}
  agy:    {allow_fqdns: [], allow_cidrs: []}
```

**`policy/denylist.base.yaml`** — post-resolution CIDR deny, deny wins over allow (R5.3, R5.7;
enforced in 01.3):

```yaml
deny_cidrs:
  - 169.254.0.0/16      # link-local, incl. 169.254.169.254 metadata endpoint (R5.6)
  - 127.0.0.0/8         # loopback
  - 10.0.0.0/8          # RFC1918
  - 172.16.0.0/12       # RFC1918
  - 192.168.0.0/16      # RFC1918
```

**Deliberately not in these files.** D5's third control — per-agent rate and concurrency limits —
is mediator configuration and belongs to 01.3, not to the base policy. Recorded here so the omission
is a decision rather than a gap. No `deny_fqdns` field: R5.3/R5.7 and D5 specify post-resolution
**CIDR** deny, and nothing in the register asks for FQDN-level deny.

## Edge Cases

- **`agy` cannot run under `sbx` at all.** D1 rejected Option 1 partly because "Antigravity
  unsupported". If that means `agy` cannot execute inside a sandbox rather than merely lacking a
  first-class template, its allowlist seed has no capture source and SF-3 must name the substitute
  (agent verbose logging as primary rather than as cross-validation). Establish this at the start of
  SF-3, before running the other two agents.
- **`agy` does not honour `HTTPS_PROXY`.** Go/no-go. On an `internal: true` network a client that
  ignores proxy configuration has no route and fails. Record the result, stop 01.2 for that agent,
  route to `/milestone` revision mode for a rescope. Not a failed feature.
- **No agent can present a client certificate.** R8.8's mechanism changes shape and 01.3's largest
  sub-feature becomes a redesign. Codex is the likeliest negative — no documented variable exists.
  Record per agent; a uniform negative is a design finding for 01.3, surfaced here deliberately
  because it is cheap to establish now and expensive to discover there.
- **Docker Sandboxes assessment cannot be completed.** Expected. Record incomplete with the
  synthetic-repo/throwaway-credential constraint as the mitigation (D17) and proceed.
- **`sbx` blocks UDP/ICMP and fully intercepts only HTTP/HTTPS.** A legitimate UDP dependency is
  invisible in the capture and will surface later as a novel failure. This is why the allowlist is
  provisional and why cross-validation is mandatory — record the blind spot in the file itself.
- **Capture yields a union rather than a per-agent policy.** Prevented by running one agent at a
  time with `--sandbox` scoping and by the per-agent file shape.
- **R14.3 named owner is operator input.** Neither the plan nor `/build` can produce a person's
  name. Treated as a `/build` start precondition, not a task.

## Test Command

```
bash scripts/lint-policy.sh
```

## Test Strategy

**01.1 owns T42 and T43.** Both are inspection tests against the records SF-1 produces:

| Test | Requirement | What it inspects | Owner |
|---|---|---|---|
| **T42** Third-party traffic-path governance | R14.1 | The record for every third party on the agent traffic path — what it observes, retention, breach-notification path, or the recorded constraint where the assessment could not be completed | **01.1**, for the Docker Sandboxes and model-provider set. 02.3 re-runs and extends it for the third parties that milestone adds |
| **T43** Provider governance record | R14.2 | The per-provider record — version-pinning capability, retention and training-opt-out settings in use, data classification permitted to leave | **01.1** |

**T44 is not owned here.** `M02 README:237-239` places the simulated terms change and the mediator
seam inspection in 02.5, under the R14.3 owner **named in 01.1**. 01.1 supplies that owner as an
input; it does not own the test. Splitting T44 would create the double ownership the approved Gate 3
review explicitly guards against, and the register records splits deliberately (as with T26) rather
than by inference. *Proposed amendment, not applied:* if the operator prefers T44 recorded as split
— 01.1 owning the owner-and-trigger record, 02.5 owning the simulation — that is a Gate 3 register
amendment, not a Gate 4 decision.

No other T-number belongs to 01.1. T1-T8 are 01.2/01.3 smoke checks with 02.2 owning them as
recorded adversarial acceptance; T26 is already split 01.4/02.5; T30's MCP transport question is
answered by SF-2's record but the test itself sits downstream of an enforcement point that does not
exist until 01.3.

**Artifact well-formedness** is checked by `scripts/lint-policy.sh` (`set -euo pipefail`, invoked as
`bash`, per repository convention). Scoped to the policy files only, matching the ratified purpose of
`scripts/` — it does **not** validate governance records, because those are inspection tests (T42,
T43), not lint targets:

- both policy YAML files parse
- `denylist.base.yaml` contains all five required ranges, `169.254.0.0/16` among them (R5.6)
- `allowlist.base.yaml` carries `provisional: true`, is keyed per agent, and every agent key exposes
  both `allow_fqdns` and `allow_cidrs`
- every allowlist entry carries a `source` annotation
- the `pins:` reference resolves to the SF-2 record (R10.6)

The SF-2 verification results are observations, not assertions — the acceptance criterion is that
each is recorded, so nothing checks for a required value.

## Documentation

- The R14.1/R14.2/R14.3 records are themselves the deliverable, not documentation about it.
- `policy/allowlist.base.yaml` states its provisional status **in the file** (Definition of Done),
  along with the `sbx` UDP/ICMP blind spot.
- `docs/RESEARCH_FINDINGS.md` — annotate the items this feature resolves, following the existing
  dated live-verification convention already used at `:269` and `:319`.
- The Gate 2 open-items table in `docs/ARCHITECTURE_AND_DESIGN.md` — mark resolved: Antigravity ToS
  owner, `agy` `GEMINI_API_KEY` route, `agy` `HTTPS_PROXY`/CA-trust, default MCP transport.
  Open Decision 3 moves to "incomplete, constrained" rather than resolved.
- Not in scope here: `README.md` drift and the CIS Docker Benchmark applicability table are 01.2
  criteria.

## Files to Create/Modify

| File | Action | Changes |
|------|--------|---------|
| `docs/records/third-party-assessments.md` | Create | R14.1 x4 and R14.2 x3 records, R14.3 named owner and review trigger. The T42/T43 inspection target. Nothing on disk serves as a record today — `docs/artifacts/` and `references/` hold duplicate copies of four published standards, which are gap-analysis input |
| `docs/records/agent-verification.md` | Create | SF-2 results: `agy` three checks, client-certificate presentation per agent, MCP default transport per agent and server, version pins |
| `docs/records/egress-discovery.md` | Create | Discovery run log, capture output, cross-validation comparison, and the disagreements keeping the allowlist provisional |
| `policy/allowlist.base.yaml` | Create | Per-agent seed allowlist, `provisional: true`, per-entry source annotation. Path fixed by the architecture file tree |
| `policy/denylist.base.yaml` | Create | Link-local incl. metadata endpoint, loopback, RFC1918 (R5.6) |
| `scripts/verify-agent-clients.sh` | Create | SF-2 harness: throwaway TLS listener with client-cert verification, `internal: true` fixture, per-agent probe. Throwaway — not the 01.3 mediator |
| `scripts/lint-policy.sh` | Create | The Test Command above. Policy files only — record completeness is T42/T43 inspection, not lint |
| `docs/RESEARCH_FINDINGS.md` | Modify | Annotate resolved UNVERIFIED items with dated results |
| `docs/ARCHITECTURE_AND_DESIGN.md` | Modify | Update the Open Items Carried Into Build table, **and add `docs/records/` to the ratified file tree**. The tree does not carry that directory today; adding it makes the location an explicit design update rather than a silent file-organization deviation |

## Dependencies

- **Upstream: none.** First feature of the first milestone.
- **Downstream: 01.1 gates 01.2-01.5.** The `agy` `HTTPS_PROXY` result is go/no-go; the version pins
  are consumed by 01.2's Dockerfiles; the client-certificate result determines whether 01.3's R8.8
  sub-feature is a build or a redesign; the MCP transport record is the input R7.15 needs.
- **Operator input required before `/build` starts:** the R14.3 named owner. Not producible by an
  implementation session.
- **External:** Docker Desktop on macOS 26, Apple silicon (R11.1, A1). Docker Sandboxes (`sbx`)
  available, under the R14.1 constraint. Model provider APIs reachable (A4). A synthetic repository
  and throwaway credentials for all three agents.
- **Not blocking:** Q1 and Q9 should be raised with the operator's organisation during this
  milestone because the lead time is not ours to control, but they block only Milestone 03 (D13a).

## Architectural Deviations

(none)
