# Containment Drills — Feature 02.5

**Feature:** `containment-response-and-the-authorization-gate.md`
**Date:** 2026-09-29 (SF-1: skeleton and template), 2026-09-30 (SF-3: phases A–D measured; SF-4: phase E,
the MCP-disable exercise, the R13.2/T40 amendment text and the full T41 drill; SF-5: the five T26
drills for the pod-local and pack credential rows, S1–S5)
**Method:** Every drill follows `docs/containment-runbook.md` **verbatim**. A deviation is a
**finding**: it is fixed in the runbook and the drill is **re-run**, not annotated (Test Strategy).
A drill whose clock is interrupted is re-run, not annotated — `t0` to `t1` is only meaningful
without a gap (Edge Case 18).
**Outcome:** *(pending — SF-6 and SF-7)*. `verify-containment.sh` phases A–F are measured green
except phase A's two expected reds (§ "Expected red"), with a recorded negative control for each of
B, C, D and E. **SF-4 is complete**: phase E, the MCP-disable exercise, the R13.2/T40 amendment text
and the full T41 drill against the real pod. **SF-5 is complete**: all five pod-local and pack
credential rows drilled and inside their stated maxima — S4 00:06, S5 00:14, S1 00:07 (all against
10:00), S2 02:21 (15:00), S3 00:11 (30:00) — every one with identical image IDs before and after, so
R8.5's no-rebuild rule holds for the whole set. Phase A's drill-evidence red is **narrower but not
gone**: the S rows now carry measured values, the E and V rows do not. What remains is the provider
revocation drills (SF-6) and close-out (SF-7) — including revoking the `CLAUDE_CODE_OAUTH_TOKEN`
minted for this work.

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
| Outstanding token at the provider | **None at 2026-09-29.** Never minted outside a test (operator-confirmed). **Superseded 2026-09-30 — see below** |
| Pre-drill revocation required | **No** — Edge Case 1's premise was a *leaked* token, and none existed |
| Effect on the E4 drill | None. SF-6 mints a fresh drill token via `claude setup-token`, revokes it, and replays it. The 01.4 SF-3 standing obligation to revoke a token minted to prove a test cell still applies to that drill token |

**Correction, 2026-09-30.** A `CLAUDE_CODE_OAUTH_TOKEN` **is** outstanding: the operator minted one
**for this testing work**, and it is held in `references/.env_keys` (git-ignored; excluded from every
build context by the deny-all `.dockerignore`, which phase A asserts). No value is recorded here.

This does **not** reopen Edge Case 1, whose premise was a *leaked* one-year token needing revocation
ahead of the build — that token never existed. What it does do is make E4's **standing obligation**
live rather than hypothetical: `verify-auth-state.sh:236` and the inventory's E4 row both state that
a token minted to prove a test cell is revoked when the feature closes. **SF-7 must revoke this one**
and record the date, and the E4 timed drill at SF-6 still uses its own fresh token.

**Edge Case 1 still closes without a revocation date**, which is the honest record: a date entered
against it would assert an event that did not happen. The one-year replay window E4 carries in the inventory's
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

Rows **S1, S4 and S5 were drilled against the real pod** (`sandboxed-agent-pod`, `default` profile,
the `main` pins in `compose/pins.env`) on 2026-09-30, on the operator's explicit authorisation.
Rows **S2 and S3** are below, after them.

**Credential provenance.** Criterion 1's throwaway rule is satisfied by construction for these three
rows: S1, S4 and S5 are the pod's **own** locally issued material, and rotating them *is* the drill.
No third-party account and no provider credential took part — every replay is a bare `curl` through
the mediator, so 02.5 Deviation 4 (the `apikey` cell used at SF-4) is not engaged here and the
agents were never authenticated.

**Replay targets** are each agent's own allowlisted host, so an allowed request is a real one:
`claude` → `api.anthropic.com`, `codex` → `api.github.com`, `agy` →
`generativelanguage.googleapis.com`. No credential value, and no key material, is recorded — the
files are identified by sha256 prefix and the certificates additionally by serial.

### FINDING — attempt 1 of S4/S5 measured a `t1` that proved nothing, and was re-run

The first pass declared `t1` on a replay that returned `curl_rc=7` — *failed to connect to the
proxy* — because the readiness gate after `docker compose restart egress-mediator` tested only that
`docker exec` into the mediator worked. That is true while Squid is still binding its listeners. A
connection that never reaches the proxy is **indistinguishable from a revocation**, and the
egress-audit trail carried no line for the attempt at all, only the mediator's own `startup_check`.

Per Edge Case 18 the drill was **re-run, not annotated**. The gate is now: after the restart, poll
with the **new** credential until the proxy answers a non-`000` status, and only then replay the old
one. That wait is part of the procedure and is inside the measured time. Both rows below are from
attempt 2.

### Drill S4 — `codex` proxy credential (`basic_ncsa_auth`)

- Drill credential: the pod's own issued credential, rotated as the drill; no value recorded. Old
  credential sha256 prefix `567a93bfad6d`, new `417ddb918acb`
- Stated maximum: **10:00**
- t0 (incident declared, UTC): **2026-09-30T15:23:31Z**
- Steps, exactly as runbook § 4 states them:
  1. baseline — the old credential works: `http_code=200`, audit `verdict=allow`,
     `identity_source=listener+proxy_auth`, `squid=TCP_TUNNEL`
  2. `bash scripts/issue-identity.sh credential codex --force` → new `.cred`, htpasswd rebuilt
     (`9d765aa569b8…` → `6e93e9bf4593…`)
  3. **Edge Case 5, measured:** replay the old credential *before* the mediator restart →
     `http_code=200`, still `verdict=allow`. The htpasswd rebuild alone does **not** revoke
  4. `docker compose restart egress-mediator`; poll with the new credential until the proxy answers
     (1 poll)
  5. replay the old credential
- t1 (replay refused, UTC): **2026-09-30T15:23:37Z** — evidence: `curl_rc=56` and the audit line
  `verdict=deny, http_status=407, squid=TCP_DENIED, identity_source="listener"`. The
  `identity_source` degrading from `listener+proxy_auth` to `listener` is itself the refusal: the
  credential no longer contributes an identity
- Access-token replay: n/a (not an OAuth row)
- Measured: **00:06**   Within maximum: **yes**
- Image IDs before / after: five IDs, `2f28fb1cfa95 5cd5aa6b06e0 b88fbfd61649 d04b811d8bef
  eb1e3b8e434c`, identical before and after   Rebuild: **no**
- Re-issue: `codex` recreated (`up -d --force-recreate --no-deps codex`), entrypoint logged *proxy
  credential spliced into the proxy URL as user 'codex'*, and the new credential reached
  `api.github.com`: `http_code=200`, `verdict=allow`

### Drill S5 — `agy` proxy credential (`basic_ncsa_auth`, TLS hop)

- Drill credential: as S4. Old sha256 prefix `b9c7af1a77a6`, new `0609e688d3ce`
- Stated maximum: **10:00**
- t0 (incident declared, UTC): **2026-09-30T15:23:41Z**
- Steps: as S4, substituting `agy`, `--proxy-cacert /run/secrets/mediator-ca.crt` on every replay
  because its proxy hop is `https://`. Baseline `http_code=404` from
  `generativelanguage.googleapis.com` (`GET /` on that host answers 404 — the CONNECT was allowed
  and the real origin replied, which is the pass). **Edge Case 5 again confirmed:** the old
  credential still returned 404 `verdict=allow` after the htpasswd rebuild and before the restart.
  Readiness took 2 polls
- t1 (replay refused, UTC): **2026-09-30T15:23:55Z** — evidence: `curl_rc=56`, audit
  `verdict=deny, http_status=407, squid=TCP_DENIED, identity_source="listener"`
- Access-token replay: n/a
- Measured: **00:14**   Within maximum: **yes**
- Image IDs before / after: the same five, identical   Rebuild: **no**
- Re-issue: `agy` recreated, splice logged, new credential reached the origin (`http_code=404`,
  `verdict=allow`)

### Drill S1 — `claude` mTLS client certificate (Edge Case 6's whole CA path)

Revocation for this row is **not** "reissue the client certificate": there is no CRL and no OCSP, so
a certificate with the same subject under the same CA would still be accepted. It is
`ca --force` plus the three listener certificates plus the client certificate plus a mediator
restart plus `claude`/`agy` restarts, and the stated maximum covers all of it.

- Drill credential: the pod's own CA and client certificate, replaced as the drill. Old CA sha256
  `922fdd3054eebb71…` → new `dcca8a1b8d00b644…`; old client `2e08b33ad6fca09e…` serial
  `33EA2106FC98962F0F7E3B457B96A34E9363FC5C` → new `62bec34c58b5294f…` serial
  `4FC9FDD0375BF452F5DF0207C3504D96FF6C2E84`. The old certificate and key were copied to a scratch
  directory for the replay and deleted with it
- Stated maximum: **10:00**
- t0 (incident declared, UTC): **2026-09-30T15:25:29Z**
- Steps, exactly as runbook § 5.2 and § 4 state them:
  1. baseline — the current client certificate reaches `api.anthropic.com`: `http_code=404`
  2. `bash scripts/issue-identity.sh ca --force` (the script warns that every certificate under the
     old CA is now invalid)
  3. `issue-identity.sh listener claude|codex|agy --ip 172.31.{10,20,30}.2 --force` — all three,
     each verifying its own `iPAddress` SAN at issuance
  4. `issue-identity.sh client claude --force` — **`--force` per SF-4 Finding 1**; the bare form
     refuses and the rotation would silently not happen
  5. `docker compose restart egress-mediator`; poll with the **new** client certificate until it
     answers (2 polls)
  6. replay the **old** client certificate, trusting the **new** CA
     (`--proxy-cacert /run/secrets/mediator-ca.crt`), so the refusal is the mediator's and not a
     client-side trust failure
- t1 (replay refused, UTC): **2026-09-30T15:25:36Z** — evidence: `curl_rc=56` (the connection is
  torn down after the handshake) and `{"event":"proxy_internal","detail":"error:transaction-end-before-headers"}`
  on `egress-audit.log`. See the finding below: this is a **weaker** evidence form than S4/S5's 407
- Access-token replay: n/a
- Measured: **00:07**   Within maximum: **yes**
- Image IDs before / after: the same five IDs, identical   Rebuild: **no**
- Re-issue: `claude` and `agy` recreated so they take the new CA certificate. Afterwards **all three
  agents work under the new CA**: `claude` with the new client certificate → `api.anthropic.com`
  `http_code=404`; `agy` over its reissued TLS listener → `http_code=404`; `codex` (peek-only
  listener, `proxy_auth`) → `api.github.com` `http_code=200`. Edge Case 6's claim, that a reissued
  certificate under a *new* CA is accepted once the CA is redistributed, holds for the full path —
  SF-4 had shown only the client-certificate half

#### FINDING — a superseded client certificate is refused, but the refusal is not attributable on the trail

S4 and S5 produce a deny line naming the agent, the destination and `http_status=407`. S1 produces
`{"event":"proxy_internal","detail":"error:transaction-end-before-headers"}` with **no `agent`, no
`identity_source` and no destination**, because the rejection happens in the TLS handshake, before
Squid has a request to log. `squid-cache.log` at the shipped debug level carries nothing either —
`grep -inE "certificate|ssl_accept|clientca|verify"` over it returns no lines.

Measured characterisation of the client-certificate layer, from inside a `claude` container against
the live listener:

| Client certificate presented | Result |
|---|---|
| The current one, issued under the live CA | handshake completes; `Verify return code: 0 (ok)`; request allowed |
| **None** | `tlsv13 alert certificate required` (**SSL alert 116**) from the listener; `curl_rc=56` |
| One with subject `CN=claude` from a **foreign CA** (a stand-in for the superseded certificate, generated for this check) | `curl_rc=56`, connection torn down after the handshake; no alert text reaches an early-closing `s_client`, because TLS 1.3 sends the client certificate after the server's Finished |

**Consequence for the runbook, now in § 4:** for S1, confirming revocation cannot rest on the audit
trail. It rests on the replay's client-side failure plus the certificate sha256 and serial before
and after. An operator who wants a trail-visible S1 refusal would have to raise Squid's debug level,
which is not the shipped configuration.

### `restart` versus `--force-recreate` for a replaced `file:` secret (Edge Case 4)

Measured on `codex-proxy-credential` against a long-lived container holding the mount
(Docker Desktop on macOS, `darwin` host; the inode numbers below are the ones the container sees).
Only sha256 prefixes are printed.

| Form | Host file | Inside the running container | Restart needed? |
|---|---|---|---|
| **Truncate in place** — `> "$cred"`, and `cp` for the htpasswd. **This is what `issue-identity.sh` does** | inode unchanged (`544579446`), sha `417ddb918acb` → `9e0e86beec6f` | inode unchanged (`27`), sha follows **immediately**: `9e0e86beec6f` | **No.** The running container sees the new content with no restart and no recreate |
| **Write-then-rename** — `mv`, or an editor's atomic save (the R4.14 trap) | **new** inode (`552110771`), sha `4ad64e54823b` | `stat` still reports the **old** inode and size (`32`, `55 B`) — the metadata looks healthy — but a read fails: `cat: /run/secrets/codex-proxy-credential: No such file or directory`, rc=1 | **Yes.** `docker restart` of the same container re-resolves the path (inode `32` → the new content, sha `4ad64e54823b`) |

**This sharpens the plan's prediction rather than confirming it.** Edge Case 4 predicted the
rename form would leave the container *on the old inode*, i.e. quietly using the **old credential**.
What was measured is worse-looking and safer: the mount **breaks**, and the file becomes unreadable
while its metadata still looks fine. The failure is therefore **closed** — an agent started against
that mount gets no credential and is refused with a 407 whose `identity_source` is `listener` — not
a silent continuation on a revoked credential. The confusing part is the healthy-looking `stat`.

**The working form, now stated in `mediator/identity/README.md` and in README's 02.3 rotation
note:** rotate with `issue-identity.sh`, which writes in place, so **no restart at all is needed for
the file's content** to reach a running container. The agent step is still required for a *proxy
credential*, but for a reason that has nothing to do with the inode: the agent splices the value
into `HTTPS_PROXY` **at the entrypoint**, so a still-running container keeps using the old URL
however fresh the file is. The drills used `--force-recreate` and it works; a plain `docker restart`
re-runs the entrypoint too and would be expected to re-splice, but **that was not measured here** —
only the mount's re-resolution was. The runbook keeps `--force-recreate`, the measured form.

### Drill S2 — `github-token` fine-grained PAT

The one row whose credential **is** usable from inside the pod, so the replay is run from inside an
agent, through the mediator, under the `github` profile — the profile that grants `claude`
`api.github.com` (the `default` profile does not).

- Drill credential: a **fine-grained PAT minted for this drill** by the operator —
  *Public Repositories (read-only)*, every repository and account permission at **No access**,
  7-day expiry. Never the operator's working token. Staged in place (per the Edge Case 4 finding
  below) at `compose/generated/credentials/github/github-cli/github-token`. Read only from inside
  the container as `/run/secrets/pack-github-cli-github-token`, sha256 prefix `a1c9ec32ea28`; no
  value recorded
- Stated maximum: **15:00**
- t0 (incident declared, UTC): **2026-09-30T16:00:30Z**
- Steps:
  1. `github` profile built separately (a profile switch needs `--build`), and
     `scripts/check-profile-compose.sh --profile github` passes first: *secret set matches the
     manifests, no other drift from default*
  2. `up -d --force-recreate` under `compose/overrides/github.yaml`; all seven services `running`
  3. delivery confirmed from inside `claude`: the secret is readable, `GH_TOKEN` is set, and
     **`GH_TOKEN` equals the secret's content** — the 02.3 `env` mapping, verified rather than
     assumed
  4. baseline — the PAT authenticates through the mediator from inside `claude`:
     `GET https://api.github.com/user` → **200** (a token with no permissions still authenticates;
     an absent or revoked one gets 401, which is what makes this endpoint a valid clock)
  5. a detached poll started in a `claude` container: the same request every 2 s, each line
     timestamped, up to 20 minutes — so the clock cannot gap while the operator is at the console
     (Edge Case 18)
  6. the operator revokes the token at GitHub. **The console action is inside the measured time**,
     which is the point of the row: R13.1 bounds detection to revocation
- t1 (replay refused, UTC): **2026-09-30T16:02:51Z** — evidence: HTTP **401** from
  `api.github.com`, the first of 4 consecutive 401s in the poll. 74 poll lines, **one single
  transition**: 200 through `16:02:48Z`, 401 from `16:02:51Z`. No flapping
- Access-token replay: n/a (not an OAuth row)
- Measured: **02:21**   Within maximum: **yes**
- Image IDs before / after (the `github` profile's five): `383b5028b69d 5cd5aa6b06e0 7a0c046d44cd
  cbe2812a5b31 d04b811d8bef`, identical   Rebuild: **no**
- Re-issue: **not measured.** Only one drill token was minted (operator's decision when asked), so
  the "new credential in place, agent authenticated, image IDs unchanged" half of Contract 6 was not
  exercised for this row. Recorded as unmeasured rather than implied. The mechanism is the one
  measured under Edge Case 4 below — an in-place file swap plus `--force-recreate`, no rebuild —
  and S3 also defers its rotation half to this mechanism

#### FINDING — a revoked pack credential leaves no signal at the mediator at all

This is the third distinct evidence shape in this feature, and the weakest of the three for an
operator watching the pod:

| Row | Where the refusal happens | What the mediator's trail shows |
|---|---|---|
| S4, S5 | at the mediator, `proxy_auth` | `verdict=deny, http_status=407, squid=TCP_DENIED`, naming the agent, with `identity_source` degraded to `listener` |
| S1 | in the TLS handshake with the mediator | only `{"event":"proxy_internal","detail":"error:transaction-end-before-headers"}` — no agent, no destination |
| **S2** | **at the third party, inside the tunnel** | **`verdict=allow, http_status=200, squid=TCP_TUNNEL`** — indistinguishable from a successful request |

The replays after `t1` are on the trail as **allowed**: `{"agent":"claude","identity_source":
"listener+mtls","dest_host":"api.github.com","verdict":"allow","http_status":200,"squid":
"TCP_TUNNEL","bytes_out":846,"bytes_in":4300}`. The `http_status` there is the CONNECT tunnel's,
not the inner response's, and the mediator never sees the inner 401 — by design (D18: it does not
terminate TLS on this path). **Consequence:** a revoked pack credential cannot be confirmed revoked
from the pod's own audit trail. Confirmation is the replay's own HTTP status, from inside the agent.
Now stated in the runbook's § 4 evidence rule alongside S1's.

#### Two smaller observations, recorded because each would mislead a reader of this sink

**No measurable survival past the console action.** The last 200 was `16:02:48Z` and the first 401
`16:02:51Z` — one poll interval apart, so any survival window is under the 2 s cadence. That
completes a pattern worth stating plainly, because three of the five rows have one and the causes are
all different:

| Row | Survival past the revocation action | Cause |
|---|---|---|
| S4, S5 | until `docker compose restart egress-mediator` | `basic_ncsa_auth` reads the htpasswd at start and Squid caches accepted credentials (Edge Case 5) |
| S3 | ~10 s | the API server's authentication path; no operator action shortens it |
| **S2** | **none measurable (< 2 s)** | GitHub revokes at the provider, effective on the next request |
| S1 | none once the mediator restarts | the new CA is loaded at start |

**The first request through a freshly recreated cascade failed, and the baseline is not that
request.** Immediately after `up --force-recreate`, one `GET /user` returned `curl_rc=56` with the
audit line `verdict=allow, http_status=500, bytes_in=0, layer=front, resolved_ip=null` — a
front-layer failure with no origin contact, the cold-peer behaviour this repository already names
(`retry_cold_peer`). Every request from a second later returned 200. The recorded baseline is the
poll's own 200s. A drill that had taken that first failure as its baseline would have concluded the
drill credential never worked.

### Drill S3 — `kubeconfig` context credential

- Drill credential: a **disposable `kind` cluster** (`kind-sf5-drill`) created for this drill and
  deleted after it. Inside it, a dedicated namespace `sf5-drill`, a ServiceAccount `drill-agent`,
  and a `Role` granting only `get,list` on `pods` in that namespace. The kubeconfig holds one
  context and **token auth only** (Decision 6: no `exec`/auth-provider plugin), sha256 prefix
  `8cf3e8f21da6`; the token value is not recorded. Never the operator's `~/.kube/config`
- Stated maximum: **30:00**
- t0 (incident declared, UTC): **2026-09-30T15:35:30Z**
- Steps, exactly as the inventory's procedure states them:
  1. baseline — the drill kubeconfig works: `kubectl get pods -n sf5-drill` →
     *No resources found in sf5-drill namespace*
  2. baseline — and it is **scoped**, which is what makes it a drill credential and not an
     operator one: `kubectl get nodes` → `Forbidden: nodes is forbidden: User
     "system:serviceaccount:sf5-drill:drill-agent" cannot list resource "nodes" … at the cluster
     scope`
  3. revoke at the cluster: `kubectl -n sf5-drill delete serviceaccount drill-agent`
  4. replay once per second until refused
- t1 (replay refused, UTC): **2026-09-30T15:35:41Z** — evidence:
  `error: You must be logged in to the server (Unauthorized)` (HTTP 401)
- Access-token replay: n/a (not an OAuth row). But see the survival window below
- Measured: **00:11**   Within maximum: **yes**
- Image IDs before / after: the same five IDs, `2f28fb1cfa95 5cd5aa6b06e0 b88fbfd61649
  d04b811d8bef eb1e3b8e434c`, identical — the pod took **no action at all** in this drill, for the
  reason stated below   Rebuild: **no**
- Re-issue: not performed. The disposable cluster was deleted instead, which is the drill's own
  teardown. The rotation half of this row — a Compose secret-file swap plus `--force-recreate`,
  no rebuild — shares the pack-credential delivery path with S2 and is measured there

#### Two things this row measured that the plan did not predict

**A deleted ServiceAccount's bound token kept working for ~10 seconds.** The replay was refused on
the tenth attempt, not the first. This is the same *shape* as Edge Case 5's `basic_ncsa_auth` cache —
a revocation that is not yet effective — with a different cause (the API server's authentication
path, not our configuration) and no operator action that shortens it. It is well inside the 30:00
maximum and is recorded because a drill that replayed **once** immediately after the delete would
have concluded the credential still worked.

**S3's replay cannot be performed from inside the pod, by design.** The shipped `kubernetes` pack
declares `egress.runtime: []` (Decision 6), so no agent has a route to any cluster and the
credential is inert in the pod until a per-cluster egress pack is also loaded. The replay is
therefore **host-side**, and that is a property of the design rather than a shortcut in the drill:
the thing a revocation has to stop is reach from wherever the credential can be used, and in the
shipped configuration that is not the agent containers. Contrast S2, whose token *is* usable through
the mediator under the `github` profile, where the replay is run from inside an agent.

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
(`servers: []`). **Exercised 2026-09-30** against `codex`, four steps plus one probe, each run as
`docker compose -f compose.yaml -f overrides/test-mcp.yaml run --build --rm --no-deps codex`. The
substitution `test-mcp.yaml` makes is stated first, because it is what lets the exercise iterate:
it **bind-mounts** a scratch inventory over `/opt/agent-pack/mcp-inventory.json`, the path the gate
reads. On the shipped path that file is **image content** (02.3 Decision 8), so every inventory edit
below is a profile edit plus a rebuild in real use.

The server: `t40-server`, a stdio entry `command = "t40-demo"` in `~/.codex/config.toml`, with the
matching `capability_baseline.config_sha256` =
`a63cc539a19f32f4bf161cfbf6cfca9795ed18447bca1b672c22bd1002fc11c4`.

| Step | What was done | Result |
|---|---|---|
| 1 — enabled | Inventory carries `t40-server`; `config.toml` carries the matching entry | **exit 0**, the agent's own command ran. This is the baseline the disable has to move away from |
| 2 — disable attempt A: **inventory only** | Server removed from the inventory; the `config.toml` entry left in place | **exit 3** — `mcp-gate: REFUSED uninventoried server 't40-server' in /home/agent/.codex/config.toml (R7.14, T29)`. The agent **does not start** |
| 2b — **probe: can the agent fix its own config?** | From step 2's refused state, the start command was a `sed` deleting the entry | **exit 3, and the edit never ran.** See the finding below |
| 3 — disable attempt B: **inventory + the config entry** | Inventory empty, and the `config.toml` entry removed **from outside the agent**, through a helper container mounting `codex-state` | **exit 0**, the agent's own command ran. The server is disabled and the agent starts |
| 4 — a compromised agent re-adds the entry | The entry appended back to `config.toml` on the state volume, inventory still empty | **exit 3**, the same REFUSED line. The agent does not start. **Containment-safe**, and it is Decision 4's fourth prediction, measured |

**Which agents are stopped or recreated.** Only the agents that load the server. On the shipped path
the canonical `docker compose up --build --force-recreate` with no service argument recreates
**every** service, the mediator included; naming the affected agents —
`docker compose up --build --force-recreate codex` — narrows it to a rebuild plus a restart of that
agent. It is still a restart: there is no live form.

#### FINDING — the agent container cannot be used to remove its own entry

Step 2b is a finding against the runbook as SF-1 drafted it. § 3.3 step 2 says "remove the
corresponding entry from the agent's own config **on its state volume**" without saying from where.
The obvious reading — `docker compose exec` or `run` into that agent and edit the file — **does not
work**, and cannot: `images/entrypoint.sh` calls `run_mcp_gate` *before* `exec "$@"`, so a refused
gate exits 3 before any command the operator supplied ever runs. Measured: the `sed` did not
execute, and the exit was the gate's.

The working form, measured at step 3, is a helper container mounting the state volume directly:

```bash
docker run --rm -v sandboxed-agent-pod_codex-state:/s --entrypoint sh sandboxed-agent/codex:local \
  -c 'sed -i "/mcp_servers.<name>/,+1d" /s/.codex/config.toml'
```

The agent's own image is used deliberately: the state volume is owned by that image's runtime uid,
and a container built on a different base is refused at the filesystem (measured — the mediator
image could not read the same path). `§ 3.3` is corrected to this form.

**This sharpens Decision 4's tradeoff rather than changing it.** The gate refusing is the *correct*
behaviour — it is exactly what makes step 4 containment-safe — but it means the disable procedure
must reach the state volume from outside the blast radius, which the runbook now says.

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

Mechanical steps under the fixture topology are `verify-containment.sh` phase E — **measured
2026-09-30, 26 assertions, all green**. The **full drill** is performed once by the operator and
recorded below: identity rotation for the contaminated agent, re-bootstrap for all three agents, and
the recorder resuming without duplicates, against the `main`-pinned digest from 02.4.

### Phase E — the mechanical path (SF-4)

The runbook's § 5.1 path executed end to end: contaminate, `down` **without** `-v`,
`docker volume rm` the discard rows **by name**, then `up --build --force-recreate`.

`build-cache.yaml` is layered into the fixture stack for this phase. Criterion 3 contaminates "each
opt-in build-cache volume, when enabled", and a disposition only ever asserted statically is a
disposition nothing has exercised — so the fragment is enabled and its three volumes are really
contaminated and really discarded.

**The markers are test instrumentation, not detection** (D16). A contaminated volume stays
indistinguishable from a clean one; the path discards without trying to tell. Each marker was chosen
to be a file that does **not** exist on a fresh state volume — measured: `~/.claude` and `~/.gemini`
are seeded empty and `~/.codex/config.toml` is seeded with no `[mcp_servers.*]` table — so "no marker
remains" is unambiguous.

### Per-store outcomes

One row per store in the runbook's § 5.2 disposition table, with the outcome asserted after recovery.

| Store | Disposition | Marker planted | Outcome after recovery |
|---|---|---|---|
| `claude-state` | `discard` | a `hooks.PreToolUse` command entry in `~/.claude/settings.json` | **gone** — the file does not exist on the fresh volume |
| `codex-state` | `discard` | `[mcp_servers.t41probe]` appended to `~/.codex/config.toml` | **gone.** The file itself is back — the entrypoint re-seeds it on a fresh volume — and carries no `t41probe` table. Asserted on the table, not the file |
| `agy-state` | `discard` | a `t41ContaminationMarker` key in `~/.gemini/settings.json` | **gone** |
| `claude-build-cache`, `codex-build-cache`, `agy-build-cache` | `discard` | `/build-cache/.t41-marker` in each | **gone**, all three |
| `audit` | `preserve` | — | **byte-identical in its first 23025 B** after recovery |
| `claude-action-audit`, `codex-action-audit`, `agy-action-audit` | `preserve` | — | **byte-identical** in their first 966 B / 989 B / 861 B |
| project mount (`workspace/`) | `review` | `/workspace/.t41-marker` | **SURVIVED, and that is the assertion** (Edge Case 12). The path reviews host content and never discards it. The harness removes its own marker in the trap |
| `compose/generated/` | `rotate` | — | Not exercised by phase E. Host staging; its rotation is T26's procedure, drilled at SF-5 |
| `mediator/identity/` | `rotate` | — | Not exercised by phase E. Identity rotation is part of the **full drill** below and of S1/S4/S5 at SF-5 |

**A prefix, not the whole file.** The preservation assertion compares the first *N* bytes, where *N*
is the file's length before recovery. The mediator and the recorders legitimately append their own
start-up lines on the way back up; an equality test would fail on those and say nothing about
whether the pre-recovery record survived intact.

### The recorder on a fresh state volume (Edge Case 10)

Two separate claims, both measured for all three agents.

| Asserted | Result |
|---|---|
| the recorder does **not** re-ship what it already shipped | yes — each agent's pre-recovery session held **1** line on its sink before recovery and **1** after. The transcript that produced it went with the volume; a recorder that re-scanned from zero would have doubled it |
| the recorder still records | yes — a new session planted on the fresh volume shipped **exactly once** for each agent |

**What a discarded volume looks like to the recorder, observed rather than predicted.** 02.1 emits
`transcript_truncated` on a shrink and `transcript_replaced` on an inode change. A volume that is
removed and recreated is neither: the source glob matches nothing, then matches something new. The
events on the sink after recovery were **`recorder_start`** — one per recorder — and nothing else.

### Recorded negative control (run once, not left in the suite)

**Skip the `volume rm`.** Contaminate, `down`, then `up --build --force-recreate` with no discard.
Measured 2026-09-30:

| Asserted by phase E | Result without the discard |
|---|---|
| claude's planted hook entry is gone | **no — PRESENT** |
| agy's planted settings change is gone | **no — PRESENT** |
| each build-cache marker is gone | **no — PRESENT**, all three |

Every discard assertion fails, so the phase is a real one.

**And the control produced a second result worth keeping.** `codex` did not come back at all:

```
status=exited exit=3
codex-1  | mcp-gate: REFUSED uninventoried server 't41probe' in /home/agent/.codex/config.toml (R7.14, T29)
```

The planted `[mcp_servers.t41probe]` table survived on the undiscarded volume, and the start-time
gate refused the agent. That is **Decision 4's fourth prediction, measured from the other direction**
— a contaminated capability declaration is not merely recorded, it stops the agent starting — and it
is why the recovery path's discard is not optional for an agent contaminated this way.

### The full drill — performed 2026-09-30

Run against the **real pod** (`sandboxed-agent-pod`), on the operator's explicit authorisation, from
the `main`-pinned digests in `compose/pins.env` — `AGENT_BASE_DIGEST sha256:e3ae687e1b43…`,
`NODE_BASE_DIGEST sha256:83f487e0a634…`, `MEDIATOR_BASE_DIGEST sha256:d7e12182ce18…`. The three
state volumes and every credential on them were destroyed as part of the drill.

**Credential provenance, stated rather than glossed.** Decision 2 and criterion 1 say drills use
dedicated throwaway credentials. This drill used the keys already in `references/.env_keys`
(git-ignored, and excluded from every build context by the deny-all `.dockerignore` — phase A
asserts that), on the operator's decision, and exercised the **`apikey`** cell for all three agents
rather than `claude` and `codex`'s default `oauth-interactive`. T41 **revokes nothing**, so the
departure is bounded: no credential's lifetime was altered by this drill. It does **not** extend to
SF-5 and SF-6, where the drills revoke and the throwaway rule is load-bearing. See the feature
plan's Deviation 4.

#### Attempt 1 — FAILED at the rotation. Recorded, not annotated away.

The Method above says a deviation is a **finding**: fixed in the runbook, and the drill **re-run**.
Attempt 1 produced three findings and was discarded as a result.

**Finding 1 — the rotation did not happen, and the drill nearly did not notice.** Step 5.1d ran the
command the runbook's § 5.2 implied:

```
issue-identity: FAIL: .../mediator/identity/clients/claude-client.crt already exists.
                Re-issue it with: bash scripts/issue-identity.sh client claude --force
```

Nothing rotated. The CA and the client certificate were byte-identical afterwards, and the pod came
back up **on the same identity material the contaminated agent had held** — the one thing criterion
3 names for this store. Run mid-recovery among commands that do not fail, the refusal is easy to
step past. `docs/containment-runbook.md` § 5.2 now carries the `--force` form, the same correction
for the S4/S5 proxy-credential rows in § 4, and a check-the-sha instruction. **SF-5 must use
`credential <agent> --force`**; only the `client` case is measured here.

**Finding 2 — the drill discarded the evidence for its own failure.** `codex` exited 3 and `agy`
exited 2 on their *first* bootstrap, against the pre-existing state volumes. The harness grepped the
output for a summary line and kept nothing else, and the volumes that caused it were destroyed
minutes later by step 5.1b. **The cause cannot now be reconstructed.** A drill must keep failure
output before it discards the store that produced it; the script now writes each bootstrap's full
output to a file and prints the tail on a non-zero exit.

**Finding 3 — two assertions could not fail.** `agy`'s marker check tested whether
`~/.gemini/settings.json` *existed*, but `bootstrap-auth` legitimately rewrites that file
(`images/bootstrap-auth.sh:225`), so contamination surviving and normal operation were
indistinguishable. It now tests for the marker **key**. And because `codex` and `agy` never
authenticated in attempt 1, their pre-recovery sessions shipped zero lines, making "0 before, 0
after" a vacuous no-duplication result.

#### Attempt 2 — the drill of record

| Step | Result |
|---|---|
| 1 — pod up from the pinned digests | mediator, three agents and three recorders `running` |
| 2 — authenticate all three (`apikey`) | **exit 0** for all three. `claude`/`codex`: *credential supplied by environment*; `agy`: *already selects modelProvider=gemini*, then ready |
| 3 — pre-recovery sessions | shipped for all three, and the evidence prefixes captured: audit **107938 B**, action-audit **148702 / 238232 / 4529 B** |
| 4 — contaminate (criterion 3) | all five stores planted; `claude` is the contaminated agent |
| 5.1a — `down`, no `-v` | done |
| 5.1b — `docker volume rm` the three state volumes | removed by name |
| 5.1c — preserve rows | `audit` and the three action-audit volumes all still present |
| 5.1d — **rotate `claude`'s identity, `--force`** | `issued: …/clients/claude-client.crt (subject /CN=claude, clientAuth, no SAN, 365d)`. **CA sha256 unchanged: YES. Client certificate changed: YES** |
| 5.1e — `up --build --force-recreate` | pod back |
| 6 — re-bootstrap all three | **exit 0** for all three |
| 9 — the rotated identity works | `claude` reached `api.anthropic.com` through the mediator presenting the **new** client certificate: **HTTP 404** on `GET /`, which is a pass — the CONNECT was allowed, TLS reached the real origin, and the origin answered. Edge Case 6's claim, that a reissued certificate under the same CA is accepted, holds for the `client` case |
| 10 — image IDs | the same five IDs before and after. T41 rebuilds by design, and the rebuild was **reproducible** — 02.4's property, observed here incidentally. R8.5's no-rebuild rule is T26's, not this drill's |

**`t0` 2026-09-30T14:54:01Z → recovery complete 14:54:28Z (27 s).** T41 carries no stated maximum —
this is a duration, not a commitment measured against one.

#### Per-store outcomes — the real pod

| Store | Disposition | Outcome |
|---|---|---|
| `claude-state` | `discard` | marker **gone** |
| `codex-state` | `discard` | `config.toml` re-seeded; the planted `[mcp_servers.t41drill]` table **gone** |
| `agy-state` | `discard` | the `t41DrillMarker` **key gone**. `settings.json` itself is back, written by `bootstrap-auth` — asserted on the key, per Finding 3 |
| `audit` | `preserve` | first **107938 B byte-identical** |
| `claude-action-audit`, `codex-action-audit`, `agy-action-audit` | `preserve` | first **148702 / 238232 / 4529 B byte-identical** |
| project mount (`workspace/`) | `review` | marker **survived** — reviewed, never discarded (Edge Case 12) |
| `mediator/identity/` | `rotate` | `claude`'s client certificate **reissued**; **CA untouched**, sha256 unchanged across the whole drill |
| `compose/generated/` | `rotate` | no pack credential was staged under the `default` profile, so there was nothing to rotate. SF-5 covers P1/P2 |

#### The recorder across the discard

Counted naively the figures look wrong, and the reason is worth recording because it would mislead
the next reader of this sink too.

**The action-audit volumes are `preserve` rows, and both drill attempts reused the same session
ids.** So a count of "lines for session `d1d1d1d1`" spans *both* attempts. Read with timestamps, one
line per attempt:

```
claude   d1d1d1d1  14:51:21 (attempt 1)   14:53:52 (attempt 2)
claude   e9e9e9e9  14:51:46 (attempt 1)   14:54:19 (attempt 2)
codex    eaeaeaea  14:51:47 (attempt 1)   14:54:19 (attempt 2)
codex    d2d2d2d2                         14:53:52 (attempt 2 only — attempt 1's bootstrap failed)
```

**Exactly once per attempt**, for every session. A future drill should use a fresh session id per
run, or window the count by timestamp.

| Asserted | Result |
|---|---|
| the recorder does not re-ship its pre-recovery session | yes — each session's line count is unchanged across the recovery |
| the recorder records after recovery | yes — `claude` and `codex` shipped a post-recovery session at 14:54:19, after `t0` at 14:54:01 |

**A measured property of the recorder, and the reason no-duplication holds.** `recorder.sh:34` keeps
its per-source state in `/var/log/actions/.state` — on the **sink** volume, which is a `preserve`
row. The state therefore survives the state-volume discard, which is precisely what stops a
re-scan from doubling the sink. It is not luck; it is where the state lives.

Its corollary caught this drill out. In `snapshot` mode (`agy`) the state is the file's sha256, so
re-writing the **same content to the same path** after a discard ships **nothing** — correct
de-duplication, and it meant `agy`'s post-recovery recording was not demonstrated by attempt 2's
repeated payload. Closed separately with a unique payload:

```
{"ts":"2026-09-30T14:56:07.833Z","session_id":"ecececec-…","sha":"9b1058242797"}
```

One line, exactly once. `agy` records on the fresh volume.

#### After the drill

The pod was brought **down without `-v`**, so the rebuilt state volumes and every evidence volume
remain. `claude` is on a **new client certificate**; anything holding the previous one will be
refused. The agents are authenticated in the `apikey` cell from `references/.env_keys`, not in their
default `oauth-interactive` cell — a subsequent OAuth login is a normal `bootstrap-auth` run and is
not part of this drill's state.

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

Two of the four failures. **At SF-3 they named all twelve rows:**

```
FAIL: A2: rows with no measured value and no GAP: E1 E2 E3 E4 V1 V2 V3 S1 S2 S3 S4 S5
FAIL: A2: rows with no rebuild cell: E1 E2 E3 E4 V1 V2 V3 S1 S2 S3 S4 S5
```

**After SF-5 they name only the seven provider rows** — measured on the committed tree,
2026-09-30, with the same overall counts as SF-4 (**165 passed, 4 failed**, the four being these two
plus part 2's two):

```
FAIL: A2: rows with no measured value and no GAP: E1 E2 E3 E4 V1 V2 V3
FAIL: A2: rows with no rebuild cell: E1 E2 E3 E4 V1 V2 V3
```

The red is **narrower, not gone**, and this is the honest reading of it: the five S rows now carry
measured values because SF-5 drilled them, and the seven E/V rows close at SF-6. The failure count
does not drop until the last row is drilled, which is the behaviour Contract 4 asks for — a
per-row check would let a half-drilled inventory report green.

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

**Exact replacement text, written 2026-09-30 from the exercised path** (see § T40, MCP-disable
exercise). Two lines change and nothing else.

`REQUIREMENTS.md:337` — R13.2, replace:

> | R13.2 | MUST | S | A single agent can be isolated, and a single MCP server or tool disabled, without stopping the other agents |

with:

> | R13.2 | MUST | S | A single agent can be isolated live, without stopping the other agents. A single MCP server or tool can be disabled without stopping the other agents; disabling it restarts the agents that load it, because the capability inventory is image content and the agent's own declaration is on its state volume |

`REQUIREMENTS.md:510` — T40, replace:

> | T40 Single-agent isolation | Stop one agent container; then disable one MCP server | The other two agents continue unaffected. The MCP disable path is exercised and its current rebuild requirement recorded | R13.2 |

with:

> | T40 Single-agent isolation | Isolate one agent, both forms: stop it with its recorder, and detach it from its network with the container kept. Then disable one MCP server: remove it from the inventory, remove the agent's own declaration from its state volume **from outside that agent**, and recreate the agents that load it | The other two agents continue unaffected in both isolation forms, and the mediator keeps serving. The MCP disable requires a rebuild and a restart of the loading agents; removing it from the inventory alone refuses that agent at its next start (`mcp-gate` exit 3), which is containment-safe | R13.2 |

**What changed and why.**

- **Isolation splits into two forms**, because both are now measured and they are not
  interchangeable: `stop` is durable and ends the recording; `network disconnect` keeps the
  container for forensics and keeps the recording alive. R13.2 said "isolated" without saying which.
- **"without stopping the other agents" is kept and met.** Measured for both forms, for all three
  agents, at SF-3 phase B.
- **The disable clause admits the restart.** R13.2 as written implies a live disable. There is none,
  and building one is a feature in its own right (Decision 4, option B): a stdio server has no
  enforcement point at all (D18), and an HTTP server's egress could be cut live only through a
  mediator reload path that does not exist (D4).
- **The removal step says *from outside that agent*,** which the exercise measured as load-bearing:
  the gate runs before anything the agent runs, so a refused agent cannot edit its own declaration.
- **The refusal is named as containment-safe**, because it is the property that makes an
  inventory-only removal a safe intermediate state rather than a half-applied change.

**R13.2 stays formally unmet until the operator accepts this text.** Accepting it is the operator's
decision, the milestone Definition of Done gates on it, and the R12.8 notice is not lifted here.

---

## Criterion-to-evidence table (coverage)

Every numbered acceptance criterion maps to a harness phase, a drill, or a record section.

| Criterion | Evidence | Where | State |
|---|---|---|---|
| 1 — T26 tested revocation, every persisted type | Drills E1–E4, V1–V3, S1–S5 | This record, § T26 (SF-5, SF-6); inventory Table B | pending |
| 2 — T40 single-agent isolation | Phase B (both forms); MCP-disable exercise; amendment text | Phase B (SF-3); this record § T40, § Proposed edits 2 | **measured (SF-3 + SF-4)** — both isolation forms, the MCP-disable exercise and the amendment text. Acceptance of the amendment is the operator's, and R13.2 stays formally unmet until then |
| 3 — T41 return to known-good | Phase E (mechanical); full drill; per-store outcomes | Phase E (SF-4); this record § T41 | **measured (SF-4)** — phase E, and the full drill performed 2026-09-30 against the real pod and the `main` pins, after one failed attempt recorded as three findings |
| 4 — R12.5 teardown | Phase D | Phase D (SF-3); this record § R12.5 | **measured (SF-3)** |
| (Decision 3) — the pod-wide cut keeps the detection signal | Phase C | Phase C (SF-3); this record § The pod-wide cut | **measured (SF-3)** |
| 5 — T37 authorization gate | Phase F, compile negatives and runtime checks | Phase F (SF-2); this record § T37 | pending |
| 6 — T44 ToS monitoring and the seam | R14.3 record for three routes; tabletop SIMULATION; seam inspection | `third-party-assessments.md`; this record § T44 (SF-7) | pending |
| 7 — the runbook | Shipped, with event/incident defined before go-live; README links it | `docs/containment-runbook.md` (SF-1 draft, SF-7 final) | **draft (SF-1)** |
| 8 — records and proposed edits | This record; the two proposed edits above | This record (SF-7) | **edit 2 (R13.2/T40) written from the exercised path (SF-4)**; edit 1 pending SF-7 |
| 9 — the R12.8 notice is not lifted here | Stated, not acted on | This record, § Proposed edits 2 | **stated (SF-1)** |
