# Containment Drills — Feature 02.5

**Feature:** `containment-response-and-the-authorization-gate.md`
**Date:** 2026-09-29 (SF-1: skeleton and template), 2026-09-30 (SF-3: phases A–D measured)
**Method:** Every drill follows `docs/containment-runbook.md` **verbatim**. A deviation is a
**finding**: it is fixed in the runbook and the drill is **re-run**, not annotated (Test Strategy).
A drill whose clock is interrupted is re-run, not annotated — `t0` to `t1` is only meaningful
without a gap (Edge Case 18).
**Outcome:** *(pending — SF-4 through SF-7)*. SF-3 is recorded: `verify-containment.sh` phases A–D
measured green except phase A's two expected reds (§ "Expected red"), plus the three recorded
negative controls for B, C and D.

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

**Measured 2026-09-30, `verify-containment.sh` phase B** — the fixture topology, under this
harness's own Compose project, three agents × two forms, 63 assertions, all green. No model token
and no login was spent.

**Stop form,** per agent X (`docker compose stop X`, then `docker compose stop X-recorder` once the
recorder has had its poll interval to drain — the order is Edge Case 9's):

| Asserted | Result |
|---|---|
| X is `exited` | yes, all three |
| X's recorder is `exited`, stopped **after** the agent it records | yes, all three |
| the other two agents are `running` | yes, for every X |
| the other two still complete an allowed fixture request through the mediator | yes — `HTTP 200` from each |
| the other two each produce a **fresh** egress line on the audit trail | yes — one `verdict` line per attempt, inside the assertion's own window |
| `docker compose start X X-recorder` restarts both cleanly, and X reaches the mediator again | yes, all three |

**Disconnect form,** per agent X (`docker network disconnect <proj>_X-net <proj>-X-1`):

| Asserted | Result |
|---|---|
| X is still `running` — the container is kept for forensics | yes, all three |
| X has no route to anything | yes. `curl: (7) Failed to connect to 172.31.<10\|20\|30>.2 port 3128 after 0 ms: Couldn't connect to server` — it is on that one network only, so the mediator's address is simply not routable |
| **the mediator keeps serving** | yes. It reads `MEDIATOR_AGENT_NETWORKS` at start only, so an *agent-side* detach does not touch it. **Measured, not assumed** (criterion 2) |
| the other two agents are unaffected (running, allowed, audited) | yes, for every X |
| `docker network connect` restores X | yes, all three |

**One measured detail the runbook now states.** Reconnecting an agent gives it a **freshly allocated
address** from its network's `ip_range` (measured: `claude` came back on `172.31.10.129`), not
necessarily the address it held before the detach. Nothing depends on an agent's own address — the mediator is reached at its static `.2` and the
listener certificates carry *its* address, not the agents' — so the agent recovers, but a forensic
note that records "the container's address" must be taken **before** the reconnect, not after.

**Not measured, and deliberately still untested: detaching the *mediator* from one agent's
network.** Edge Case 7 stands as written. The mediator validates its network set at start only, so
that operation's effect is unknown and it is recorded as untested rather than recommended. Phase B
measures the agent-side detach, which is the form the runbook hands the operator.

#### Recorded negative control (run once, not left in the suite)

**Stop the mediator instead of an agent.** The "others unaffected" assertion must be able to fail,
or its passes mean nothing.

```
docker compose -p <fixture project> stop egress-mediator
```

Measured 2026-09-30, with all three agents running and previously green:

| Agent | Result with the mediator stopped |
|---|---|
| `claude` | `curl: (28) Connection timed out after 25003 milliseconds` |
| `codex` | `curl: (7) Failed to connect to 172.31.20.2 port 3128 after 14286 ms: Couldn't connect to server` |
| `agy` | `curl: (7) Failed to connect to 172.31.30.2 port 3128 after 14248 ms: Couldn't connect to server` |

All three fail, so the assertion is a real one. `docker compose start egress-mediator` restored all
three to `HTTP 200`. The asymmetry in the failure mode is itself informative: `claude`'s hop is TLS
to a listener that is gone, so it times out; `codex` and `agy` are refused at TCP.

### MCP-disable exercise (Decision 4)

Runs against 02.3's `test-mcp.yaml`, because **no shipped profile carries a server**
(`servers: []`). The record states every step, which agents are stopped or recreated, and that the
shipped path **requires a rebuild** because the inventory is baked into the image (02.3 Decision 8).

*(pending SF-4)*

---

## The pod-wide cut — Decision 3's other live form (SF-3)

**Measured 2026-09-30, `verify-containment.sh` phase C.** The runbook's § 3.1 live form:

```bash
docker network disconnect <proj>_egress-net <proj>-egress-mediator-1
```

| Asserted | Result |
|---|---|
| the mediator is **still running** with its egress leg cut | yes — which is the whole reason this form is chosen over `stop egress-mediator` (Decision 3): the detection signal stays alive |
| every agent's allowed request fails | yes, all three |
| **each failed attempt is still on the audit trail** | yes, all three — one `verdict` line per attempt, in the assertion's own window |
| reattaching restores the allow for every agent | yes, all three |

**What the audit line actually says, and why the assertion is keyed on presence rather than on a
verdict.** The policy decision is unchanged by the cut — the destination is still allowlisted — so
the line reads `"verdict":"allow"` and the failure appears one layer down:

```json
{"ts":"…","event":"connect_accepted","agent":"claude","identity_source":"listener+mtls","layer":"inner","dest_host":"allowed.fixture.lab","dest_port":443,"sni":"allowed.fixture.lab"}
{"ts":"…","agent":"claude","identity_source":"listener+mtls","layer":"inner","dest_host":"allowed.fixture.lab","dest_port":443,"resolved_ip":"172.31.40.20","verdict":"allow","control":null,"bytes_out":0,"bytes_in":0,"sni":"allowed.fixture.lab","method":"CONNECT","http_status":503,"squid":"TCP_TUNNEL"}
{"ts":"…","event":"proxy_internal","detail":"error:transaction-end-before-headers"}
```

`http_status: 503` with `bytes_out: 0` and `bytes_in: 0` is the signature of the cut: the request was
accepted, attributed and evaluated, and then had nowhere to go. A phase that asserted
`verdict == "deny"` would have been asserting the wrong thing, so phase C asserts **that a line for
that (agent, destination) exists in the window** and nothing about its verdict.

**Finding — Edge Case 8 is refined, not contradicted.** Edge Case 8 predicted that the failure would
surface as a DNS `SERVFAIL` from unbound's dead upstream, with dnsdist still deciding and auditing.
Measured, the name was **already in unbound's cache** from the phase-B requests, so no DNS query left
the mediator at all: `dns-audit.log` carried nothing in the window, `resolved_ip` was answered from
cache, and the attempt failed at the TCP leg to `172.31.40.20` instead. The property Edge Case 8 was
written to protect — *attempts remain visible* — holds either way, but the line that carries them is
`egress-audit.log`, not `dns-audit.log`. On a cold cache the DNS path would also fail and audit; a
warm cache is the more likely state during a real incident, since the cut follows traffic.

**One operational detail the runbook now states.** `docker network connect` reattaches the mediator
with a **dynamically assigned** `egress-net` address, not necessarily the one it had. Nothing depends
on it — `egress-net` carries no policy-addressed peer in the shipped topology and the fixtures are
reached by destination address — but the reattach is not an exact restoration of the prior state.

#### Recorded negative control (run once, not left in the suite)

**With the cut in place, stop the audit writer**, and show that the "the attempt still reached the
audit sink" assertion can fail. The writer has no `ps` in the mediator image, so it is found through
`/proc`:

```bash
docker exec <proj>-egress-mediator-1 sh -c \
  'for d in /proc/[0-9]*; do c=$(tr "\0" " " < $d/cmdline); case "$c" in *audit-writer*) echo ${d#/proc/};; esac; done'
docker exec <proj>-egress-mediator-1 sh -c 'kill -9 <pid>'
```

Measured 2026-09-30: the assertion failed — **0** lines for `(claude, allowed.fixture.lab)` after the
kill, against 2 for the same attempt while the writer was alive.

**And the confound is the finding.** Killing the writer did not leave a mediator that proxies without
recording. It took the **whole container** down (`exited`, code 137): the entrypoint treats any child
leaving on its own as an incident, because a live proxy that is no longer recording is exactly the
state R9.1 forbids. So the negative control proves the assertion *can* fail, but it does so for two
reasons at once — no writer **and** no proxy — and the subsequent attempt reported
`curl: (7) Failed to connect to 172.31.10.2 port 3128`. A cleaner single-variable control would need
a writer that could be stopped without failing the mediator closed, which is a property this design
deliberately does not have. Recorded as measured rather than engineered around.

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

**Measured 2026-09-30, `verify-containment.sh` phase D.** A marker is written into each agent's
`/tmp` (tmpfs) and each agent's `/home/agent` (its state volume), then `docker compose down`
**without `-v`**, then `up` again.

| Asserted | Result |
|---|---|
| `down` removed every container | yes — 0 containers matching the project prefix |
| `down` removed every network | yes — 0 networks matching the project prefix |
| every named volume survived | yes — the same 7 volumes before and after, `audit` included |
| each agent's `/tmp` marker is **gone** | yes, all three — `/tmp` is a tmpfs and does not survive the container |
| each agent's state-volume marker is **still there** | yes, all three |
| the audit line count did not decrease | yes — 94 lines before, 97 after. The three added lines were not read back, so they are not attributed here; a +3 delta is consistent with the mediator's own start-up events on the fresh container, and the assertion is `>=`, not equality |

This is the mechanical basis for the runbook's **first rule** (§ 2): `down` is safe during an
incident and `down -v` destroys the evidence. T41's discard is therefore selective —
`docker volume rm` of the named **state** volumes only, never `-v`.

#### Recorded negative control (run once, not left in the suite)

**`down -v` instead of `down`.** Measured 2026-09-30, from the same marked state:

| Asserted | Result with `-v` |
|---|---|
| named volumes survive | **no** — all 7 project volumes were removed |
| each agent's state marker is present after `up` | **no** — absent in all three |
| the audit line count did not decrease | **no** — 46 lines before, 2 after (a fresh volume with only the new start's events) |

Every preservation assertion fails, so the phase is a real one. The 46 → 2 line count is the concrete
cost the runbook's first rule exists to prevent.

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

## Expected red — phase A, in two separate parts

Phase A is **red by design until SF-7**, and in **two independent parts** with different closing
sub-features. Neither is skipped — there is no skip variable, following the same reasoning as
`retry_cold_peer`. Measured 2026-09-30 when phase A landed: **12 passed, 4 failed**, and all four
failures are the two parts below.

### Part 1 — the drill-evidence check (Edge Case 17), green at SF-6

`verify-containment.sh` phase A parses the inventory's **Stated maximum**, **Measured** and
**Rebuild required** columns and fails on an unfilled cell. It is therefore **red from SF-3 until
SF-6**, by design, exactly as 02.4 SF-2 recorded its own expected red.

Two of the four failures, each naming all twelve rows:

```
FAIL: A2: rows with no measured value and no GAP: E1 E2 E3 E4 V1 V2 V3 S1 S2 S3 S4 S5
FAIL: A2: rows with no rebuild cell: E1 E2 E3 E4 V1 V2 V3 S1 S2 S3 S4 S5
```

The **Stated maximum** column is the opposite case, and it passes: filled for all twelve rows as of
SF-1, as it must be — the maximum is a commitment made before the drill.

**Parser rule, binding on SF-3 — implemented as stated.** Interface Contract 4 says phase A "fails on
an empty cell", but as of SF-1 the Measured and Rebuild cells are **not empty** — they carry the
literal token `*(pending — 02.5 SF-5/SF-6 drill)*`. Phase A therefore treats a cell **containing
`pending`** as unfilled, exactly as it treats an empty one. A parser that only checked for emptiness
would have gone green against SF-1's placeholders and asserted that drills had happened when none
had. Beyond that, phase A holds each cell to Contract 4's stated shape: **Measured** must read
`mm:ss`/`h:mm:ss` or name a `GAP`, and **Rebuild required** must read `no` or `GAP (R8.5)`. Phase A
also asserts that the Table A and Table B row-id sets are **equal**, so a credential row cannot be
added to one table and forgotten in the other.

### Part 2 — the R14.3 three-route check (criterion 6), green at SF-7

Interface Contract 8 puts criterion 6's R14.3 check in phase A — "the R14.3 record names an owner and
triggers for the three routes" — but `third-party-assessments.md` is written by **SF-7**. As of SF-1
it carries the single-route Antigravity block inherited from 01.4 SF-3 and no cadence statement. So
phase A's other two failures are:

```
FAIL: A4: the R14.3 record has no Route/Owner/Review-trigger row for: claude codex agy
FAIL: A4: the R14.3 record states no monitoring cadence
```

**Shape rule, binding on SF-7.** Phase A reads, and SF-7 must therefore write, a table **inside the
`## R14.3` section** whose header row names `Route`, `Owner` and `Review trigger`, with one row per
route whose first cell is `claude`, `codex` and `agy` (backticks optional), plus the word `cadence`
somewhere in that section. The existing single-route block satisfies none of this and is not
retro-fitted here: SF-7 owns the content, and this is only the shape phase A can check.

**This corrects the plan's SF-6 bullet.** SF-6 says "Phase A goes green"; only **Part 1** goes green
at SF-6. Phase A goes fully green at **SF-7**. See the feature plan's Deviation 3.

| Recorded at | Part 1 (drill evidence) | Part 2 (R14.3) |
|---|---|---|
| SF-3 (phase A lands) | **red — measured, 2 failures** | **red — measured, 2 failures** |
| SF-6 (drills complete) | *(pending — expected green)* | *(pending — still red)* |
| SF-7 (close-out) | *(pending — expected green)* | *(pending — expected green)* |

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
| 2 — T40 single-agent isolation | Phase B (both forms); MCP-disable exercise; amendment text | Phase B (SF-3); this record § T40 | **both forms measured (SF-3)**; MCP half pending SF-4 |
| 3 — T41 return to known-good | Phase E (mechanical); full drill; per-store outcomes | Phase E (SF-4); this record § T41 | pending |
| 4 — R12.5 teardown | Phase D | Phase D (SF-3); this record § R12.5 | **measured (SF-3)** |
| (Decision 3) — the pod-wide cut keeps the detection signal | Phase C | Phase C (SF-3); this record § The pod-wide cut | **measured (SF-3)** |
| 5 — T37 authorization gate | Phase F, compile negatives and runtime checks | Phase F (SF-2); this record § T37 | pending |
| 6 — T44 ToS monitoring and the seam | R14.3 record for three routes; tabletop SIMULATION; seam inspection | `third-party-assessments.md`; this record § T44 (SF-7) | pending |
| 7 — the runbook | Shipped, with event/incident defined before go-live; README links it | `docs/containment-runbook.md` (SF-1 draft, SF-7 final) | **draft (SF-1)** |
| 8 — records and proposed edits | This record; the two proposed edits above | This record (SF-7) | pending |
| 9 — the R12.8 notice is not lifted here | Stated, not acted on | This record, § Proposed edits 2 | **stated (SF-1)** |
