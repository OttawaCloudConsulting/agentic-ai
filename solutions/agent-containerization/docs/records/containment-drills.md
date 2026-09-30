# Containment Drills — Feature 02.5

**Feature:** `containment-response-and-the-authorization-gate.md`
**Date:** 2026-09-29 (SF-1: skeleton and template only — no drill has run yet)
**Method:** Every drill follows `docs/containment-runbook.md` **verbatim**. A deviation is a
**finding**: it is fixed in the runbook and the drill is **re-run**, not annotated (Test Strategy).
A drill whose clock is interrupted is re-run, not annotated — `t0` to `t1` is only meaningful
without a gap (Edge Case 18).
**Outcome:** *(pending — SF-3 through SF-7)*

> **This repository is public.** No credential value, OAuth code, or token prefix longer than the
> provider's own public type prefix (`sk-ant-`, `ghp_`) ever enters this record. Drills use
> **dedicated drill credentials, never the operator's working credentials** (Decision 2).

---

## Pre-drill revocation — the leaked one-year token (Edge Case 1)

Edge Case 1 assumed an outstanding one-year `CLAUDE_CODE_OAUTH_TOKEN` (inventory row **E4**) needing
revocation ahead of this feature's build order. **It does not exist.** The operator confirmed on
2026-09-29 that no such token was ever minted outside a test: the `oauth-token` cell was exercised to
prove the delivery path, not to hold a working credential, and R4.12 makes `oauth-interactive`
`claude`'s default precisely so a year-long token is not minted by default.

| Item | Value |
|---|---|
| Row | E4 |
| Outstanding token at the provider | **None.** Never minted outside a test (operator-confirmed 2026-09-29) |
| Pre-drill revocation required | **No** — there is nothing to revoke |
| Effect on the E4 drill | None. SF-6 mints a fresh drill token via `claude setup-token`, revokes it, and replays it. The 01.4 SF-3 standing obligation to revoke a token minted to prove a test cell still applies to that drill token |

**This closes Edge Case 1 without a revocation date**, which is the honest record: a date entered here
would assert an event that did not happen. The one-year replay window E4 carries in the inventory's
blast-radius column is unchanged — it describes the credential type, and SF-6 still drills it.

---

## Drill template (Interface Contract 6)

Every T26 drill below is recorded in exactly this shape. Deviations from the runbook's stated steps
are marked **FINDING** inline.

```
### Drill <row id> — <credential type>
- Drill credential: <how it was minted>; never the working credential; no value recorded
- Stated maximum: <mm:ss, copied from credential-inventory.md Table B; never re-derived here>
- t0 (incident declared, UTC): <ISO-8601>
- Steps: <numbered, exactly as the runbook states them; any deviation is marked FINDING>
- t1 (replay refused, UTC): <ISO-8601> — evidence: <HTTP status / 407 / TLS alert; no credential material>
- Access-token replay (OAuth rows): <status at t1, and at each later check until refused or expired>
- Measured: <mm:ss>   Within maximum: yes | no
- Image IDs before / after: <service: 12-hex prefix, each>   Rebuild: no | GAP (R8.5)
- Re-issue: <new credential in place; agent authenticated; image IDs unchanged>
```

---

## T26 — pod-local and pack credentials (SF-5)

*(pending SF-5 — rows S1, S2, S3, S4, S5)*

### `restart` versus `--force-recreate` for a replaced `file:` secret (Edge Case 4)

A Compose `file:` secret is a bind mount. `cp` over the file keeps the inode and a restart sees the
new content; `mv`, or an editor's write-then-rename, leaves the container on the **old inode** (the
R4.14 trap). SF-5 measures both — inode before and after, and a replay of the old credential — and
`mediator/identity/README.md` is corrected to whichever form works.

*(pending SF-5)*

---

## T26 — provider credentials (SF-6)

*(pending SF-6 — rows E1, E2, E3, E4, V1, V2, V3)*

### Access-token survival findings (Edge Case 2)

Where a revoked session's access token stays valid until its own expiry, **that survival is the
measured time**, recorded honestly against R13.1's stated maximum rather than hidden behind the
console time. Each such row gets a compensating action added to the runbook: isolate the agent and
discard its volume at `t0`, before revoking.

*(pending SF-6)*

### Provider revocation granularity (Edge Case 3)

Where a provider offers only "log out all sessions" rather than revoking one token, the granularity
observed is recorded here, and the fact that an all-or-nothing revocation also ends the operator's
own sessions is recorded **against R4.17**.

*(pending SF-6)*

---

## T40 — single-agent isolation (SF-3 mechanical, SF-4 MCP half)

### Stop form and disconnect form

*(pending SF-3 — `verify-containment.sh` phase B, per agent, both forms. Includes the measured answer
to whether the mediator tolerates an agent-network detach — it reads `MEDIATOR_AGENT_NETWORKS` at
start only, and this is measured, not assumed.)*

### MCP-disable exercise (Decision 4)

Runs against 02.3's `test-mcp.yaml`, because **no shipped profile carries a server**
(`servers: []`). The record states every step, which agents are stopped or recreated, and that the
shipped path **requires a rebuild** because the inventory is baked into the image (02.3 Decision 8).

*(pending SF-4)*

---

## T41 — return to known-good (SF-4)

Mechanical steps under the fixture topology are `verify-containment.sh` phase E. The **full drill**
is performed once and recorded here: identity rotation for the contaminated agent, re-bootstrap for
all three agents, and the recorder resuming without duplicates. The drill runs against the
`main`-pinned digest from 02.4.

### Per-store outcomes

One row per store in the runbook's § 5.2 disposition table, with the outcome asserted after recovery.

*(pending SF-4)*

---

## R12.5 — teardown (SF-3)

*(pending SF-3 — `verify-containment.sh` phase D: `down` without `-v` removes containers, `tmpfs` and
networks and preserves every named volume, `audit` included, asserted with markers.)*

---

## T37 — the authorization gate (SF-2)

*(pending SF-2 — `verify-containment.sh` phase F: one compile negative per Interface Contract 2 row;
every shipped profile compiles; the runtime credential-absence checks under `default`; and
`CONNECT github.com` refused from `claude` and `agy` with each deny line carrying `agent` and
`identity_source`.)*

### Recorded negative control

Removing `git-push` from the `github` profile's `waive` block makes the compile exit 3. Run once and
recorded here; not left in the suite.

*(pending SF-2)*

### `codex` and `github.com` (Edge Case 16)

`codex`'s base allowlist already carries `github.com` and `api.github.com` for reasons recorded at
01.1, so under `default` its only barrier to `git-push` is the **absent credential**. No live push is
attempted — the harness contacts no third-party host. The residual this leaves is a
repository-embedded credential in the project mount (a token in `.git/config`).

*(pending SF-2)*

---

## T44 — the mediation seam (SF-7)

*(pending SF-7 — `squid -v` on the built image for the ICAP and eCAP build flags; the front/inner
`cache_peer` cascade; and the template's `@GATE_RULES@` and `@PROXY_LISTENERS@` seams. The recorded
conclusion names its limits: a tool-call layer needs TLS termination, which is a D4 decision and is
never available for `agy` (R5.13), and the mediator never sees stdio (D18). "Without redesign" does
not mean "without a decision".)*

---

## Expected red — the phase A drill-evidence check (Edge Case 17)

`verify-containment.sh` phase A parses the inventory's **Stated maximum**, **Measured** and
**Rebuild required** columns and fails on an empty cell. It is therefore **red from SF-3 until
SF-6**, by design, exactly as 02.4 SF-2 recorded its own expected red. It is **not skipped** — there
is no skip variable, following the same reasoning as `retry_cold_peer`.

**Parser rule, binding on SF-3.** Interface Contract 4 says phase A "fails on an empty cell", but as
of SF-1 the Measured and Rebuild cells are **not empty** — they carry the literal token
`*(pending — 02.5 SF-5/SF-6 drill)*`. Phase A must therefore treat a cell **containing `pending`** as
unfilled, exactly as it treats an empty one. A parser that only checks for emptiness would go green
against SF-1's placeholders and assert that drills had happened when none had. The Stated maximum
column is the opposite case: it is filled for all twelve rows as of SF-1 and phase A should find it
so.

| Recorded at | State |
|---|---|
| SF-3 (phase A lands) | *(pending — expected red)* |
| SF-6 (drills complete) | *(pending — expected green)* |

---

## Proposed edits — recorded here, not applied (criterion 8)

Two edits are carried as exact replacement text for an authority that may apply them. Neither is
applied by this feature.

### 1. `docs/ARCHITECTURE_AND_DESIGN.md` — the runbook table

The architecture document's runbook table states "denylist entry at the mediator" as a live action.
It is **a rebuild**, not a live action: the policy is baked into the mediator image and there is no
live reload (D4). The live forms are the **network disconnects**, and the recorder is stopped
**alongside** its agent, after it drains.

*(exact replacement text — pending SF-7)*

### 2. `REQUIREMENTS.md` — the R13.2 / T40 amendment

R13.2 as written asks for a targeted disable path. What exists is a profile edit plus a rebuild plus
recreation of every agent that loads the server; a stdio server has no enforcement point at all
(D18). The amendment records the tested path rather than a speculative one.

**R13.2 stays formally unmet until the operator accepts this amendment.** This feature supplies
tested amendment text; it does not accept it. The milestone Definition of Done gates on acceptance,
and the R12.8 notice is **not lifted here** (criterion 9).

*(exact amendment text — pending SF-4, which exercises the path it describes)*

---

## Criterion-to-evidence table (coverage)

Every numbered acceptance criterion maps to a harness phase, a drill, or a record section.

| Criterion | Evidence | Where | State |
|---|---|---|---|
| 1 — T26 tested revocation, every persisted type | Drills E1–E4, V1–V3, S1–S5 | This record, § T26 (SF-5, SF-6); inventory Table B | pending |
| 2 — T40 single-agent isolation | Phase B (both forms); MCP-disable exercise; amendment text | Phase B (SF-3); this record § T40 (SF-4) | pending |
| 3 — T41 return to known-good | Phase E (mechanical); full drill; per-store outcomes | Phase E (SF-4); this record § T41 | pending |
| 4 — R12.5 teardown | Phase D | Phase D (SF-3) | pending |
| 5 — T37 authorization gate | Phase F, compile negatives and runtime checks | Phase F (SF-2); this record § T37 | pending |
| 6 — T44 ToS monitoring and the seam | R14.3 record for three routes; tabletop SIMULATION; seam inspection | `third-party-assessments.md`; this record § T44 (SF-7) | pending |
| 7 — the runbook | Shipped, with event/incident defined before go-live; README links it | `docs/containment-runbook.md` (SF-1 draft, SF-7 final) | **draft (SF-1)** |
| 8 — records and proposed edits | This record; the two proposed edits above | This record (SF-7) | pending |
| 9 — the R12.8 notice is not lifted here | Stated, not acted on | This record, § Proposed edits 2 | **stated (SF-1)** |
