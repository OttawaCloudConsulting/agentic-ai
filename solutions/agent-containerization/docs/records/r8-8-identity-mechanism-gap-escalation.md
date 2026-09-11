# R8.8 Identity Mechanism Gap — Escalated to /milestone

**Raised during:** `/build` pre-flight for Feature 01.3 Egress mediator, before SF-1 (no code written)
**Date:** 2026-09-04
**Status:** **Resolved by the 2026-09-04 `/milestone` revision.** The revision split per-agent
workload identity out of 01.3 into **Feature 01.6**, so the block this record describes no longer
exists and 01.3 builds on network-derived identity. The underlying R8.8 gap is *not* closed — it is
re-homed. 01.6 must either close R8.8 with a real credential for every agent or amend R8.8 in
`REQUIREMENTS.md`; see the 01.3 plan's Dependencies section, "On later features".
Status flipped 2026-09-06 at 01.3 SF-1.

## Finding

01.3's feature plan (Interface Contract 2) assumes a uniform `https://` proxy hop from every agent
to the mediator, with per-agent mTLS client certificates satisfying R8.8 (D6, T34).
`docs/records/agent-verification.md` (01.1 SF-2, criterion 5) already recorded the actual per-agent
capability:

| Agent | Can present client cert today? | Mechanism |
|---|---|---|
| claude | **Yes** | `CLAUDE_CODE_CLIENT_CERT` / `CLAUDE_CODE_CLIENT_KEY` — confirmed empirically |
| codex | **No — structural.** Rejects an `https://`-scheme `HTTPS_PROXY` at URL-parse time, before any TLS handshake to the proxy is attempted. Cannot use a TLS-terminated proxy listener at all, only plain `http://` CONNECT. | No client-cert variable exists |
| agy | **No — reaches TLS layer, has nothing to offer.** Negotiates TLS to the proxy correctly (trusts the fixture CA via `SSL_CERT_FILE`) but has no documented or discovered client-cert variable. | — |

Net: **2 of 3 agents cannot meet R8.8's ratified mTLS mechanism today** — one (codex) for a
structural transport-layer reason (no TLS to the proxy at all, not just "no cert"), one (agy) for a
missing-feature reason. Only claude reaches `identity_source: listener+mtls` as 01.3's Interface
Contract 4 defines it; codex and agy would both be `identity_source: listener` (network-derived
identity only).

## Why this isn't absorbed by the plan as written

Interface Contract 4 explicitly designs for a **partial** negative: "if two agents can present a
certificate and one cannot, the two are held to `listener+mtls`, the third is recorded as
`listener`, and the gap is scoped to one agent." The result found here is the inverse ratio — one
agent succeeds, two do not — which is worse than the plan's own worked example. The plan reserves
`/milestone` revision only for a **total** negative ("no agent can present a client certificate at
all"). Whether a 2-of-3 shortfall should be treated the same as a total negative for R8.8 (a MUST)
is a design-register question, not an implementation detail — hence escalation rather than a
plan-time fallback or a recorded deviation.

## Options presented at the pre-flight gate

1. **Proceed, record deviation.** codex-net listener becomes plain HTTP CONNECT (destination TLS
   stays end-to-end via splice — no new party sees hostname or content; only the proxy-hop
   cryptographic identity is lost for codex). agy-net stays TLS with client cert optional. Interface
   Contract 2 amended for codex's `HTTPS_PROXY` scheme. Three listener modes become SF-1/SF-3 scope.
2. **Stop, escalate to `/milestone`.** Treat the 2-of-3 shortfall against R8.8 (a MUST) as requiring
   a milestone-level decision before any 01.3 code is written.

**Decision: Option 2 — escalate.** No 01.3 code was written. `milestone-status.txt` and
`progress.txt` are unchanged; Feature 01.3 remains `[~] planned, awaiting build`, 0/8 sub-features.

## What `/milestone` revision needs to decide

- Whether R8.8's mechanism is amended (analogous to how this plan already amended T28 for the
  proxy-hop trust anchor) to accept network-derived identity (`identity_source: listener`) as
  sufficient for codex and agy at this milestone, with cryptographic identity tracked as a residual —
  or whether R8.8 stays a hard MUST that 01.3 cannot close for two of three agents, which would
  change 01.3's scope, sizing, or the milestone's Definition of Done.
- If network-derived identity is accepted for codex/agy: whether codex-net's plaintext proxy hop
  (destination TLS unaffected) needs its own recorded control or acceptance note, given it changes
  the "TLS: verify client cert against CA" step in 01.3's Approach diagram for one of three networks.
- Whether agy-net's proxy-hop TLS is worth keeping (server-auth-to-agy on an isolated network, and
  keeps the path open if agy grows a client-cert variable) or should also drop to plain HTTP for
  consistency — either is defensible, SF-6 needs it decided either way.
- Downstream effect on Interface Contract 2 (per-agent `HTTPS_PROXY` scheme, not uniform), Interface
  Contract 4 (`identity_source` distribution: 1 `listener+mtls`, 2 `listener`, not the "one gap"
  case the schema's prose anticipates), and SF-1's verification scope (three concurrent listener
  modes on one proxy implementation, not one mode verified once).

## Related records

- `docs/records/agent-verification.md` — 01.1 SF-2, criterion 5 (source of the finding)
- `.project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/plans/egress-mediator.md` —
  01.3 feature plan, Interface Contracts 2 and 4, Dependencies section
