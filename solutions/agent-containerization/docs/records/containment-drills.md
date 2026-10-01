# Containment Drills — Feature 02.5

**Feature:** `containment-response-and-the-authorization-gate.md`
**Date:** 2026-09-29 (SF-1: skeleton and template), 2026-09-30 (SF-3: phases A–D measured; SF-4: phase E,
the MCP-disable exercise, the R13.2/T40 amendment text and the full T41 drill; SF-5: the five T26
drills for the pod-local and pack credential rows, S1–S5; SF-6: the seven provider rows, E1–E4 and
V1–V3, plus two defects fixed in image code and eight items carried to user documentation)
**Method:** Every drill follows `docs/containment-runbook.md` **verbatim**. A deviation is a
**finding**: it is fixed in the runbook and the drill is **re-run**, not annotated (Test Strategy).
A drill whose clock is interrupted is re-run, not annotated — `t0` to `t1` is only meaningful
without a gap (Edge Case 18).
**Credential-handling rule, binding on anyone reproducing these drills (D-6):** never print a
credential file's contents while inspecting its structure. Key names via `grep -o`, size via
`wc -c`, identity via a sha256 prefix — that is enough to tell one credential from another and to
prove a rotation happened, without putting a value in a transcript, a scrollback or a public record.
This rule exists because one drill in this record broke it and recorded the breach as a finding
against its own conduct (§ V2).
**Outcome:** **COMPLETE — SF-7 close-out 2026-09-30.** All twelve credential rows drilled (one
stated gap: V2's timed half, by operator decision), `verify-containment.sh` phases A–F **fully
green** with phase A's two expected reds both closed, T37 and T44 recorded, the R14.3 three-route
record and the T44 tabletop written in `third-party-assessments.md`, and all **eight** items in
§ "MUST REACH USER DOCUMENTATION" written into `README.md` and the runbook. **One thing is deliberately not
closed here:** the one-year `CLAUDE_CODE_OAUTH_TOKEN` in
`references/.env_keys` is still live** — replayed 2026-09-30T22:04:35Z, HTTP **200** twice; the
operator has stated it will be revoked out of session, and no revocation date is recorded because no
replay has confirmed one (this feature's own D-5 rule, applied to itself). **SF-6 is complete and phase A's drill-evidence half is green
(167 passed, 2 failed — the two are the R14.3 pair that closes at SF-7).** All twelve credential rows
are drilled, one of them (V2) recorded as a `GAP` on its timed half by operator decision. `verify-containment.sh` phases A–F are measured green
except phase A's two expected reds (§ "Expected red"), with a recorded negative control for each of
B, C, D and E. **SF-4 is complete**: phase E, the MCP-disable exercise, the R13.2/T40 amendment text
and the full T41 drill against the real pod. **SF-5 is complete**: all five pod-local and pack
credential rows drilled and inside their stated maxima — S4 00:06, S5 00:14, S1 00:07 (all against
10:00), S2 02:21 (15:00), S3 00:11 (30:00) — every one with identical image IDs before and after, so
R8.5's no-rebuild rule holds for the whole set. Phase A's drill-evidence red is **narrower but not
gone**: the S rows now carry measured values, the E and V rows do not. **SF-6 is complete**, and so is close-out (SF-7) — with
the `CLAUDE_CODE_OAUTH_TOKEN` obligation named above as the one thing it did not discharge.

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

- Drill credential: a **fine-grained PAT minted for this drill** by the operator, to the drill's
  instructions — *Public Repositories (read-only)*, every repository and account permission at
  **No access**, 7-day expiry. Never the operator's working token. **Stated, not observed:** the
  scope and expiry are what was asked for; what the pod verified is that the token authenticated
  (200) and then did not (401). The drill deliberately never reads the value, so it cannot inspect
  the token's own grants. Staged in place (per the Edge Case 4 finding
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

**Rows E1, E2, E3 and E4 are drilled (2026-09-30).** V1–V3 are still pending: they need interactive
logins and access-token replays measured in hours and days (Edge Case 2), and Edge Case 3 has to be
put to the operator before V1/V2 are drilled.

**Credential provenance — the throwaway rule is load-bearing here, unlike SF-4's T41.** These drills
**revoke**, so Deviation 4's use of the working keys in `references/.env_keys` does **not** extend to
them (the deviation says so itself). The operator minted three dedicated drill keys in
`references/.sf6-drill_env_keys`, and the drill script **asserts** the separation before it starts:
each drill key is compared against its counterpart in `references/.env_keys` and the run aborts on a
match. Keys reach the containers by the bare `-e NAME` form, so no value enters `argv`; the polls
print status codes only.

> **Repository-hygiene finding, fixed before any drill ran.** `.gitignore` carried the **exact
> path** `references/.env_keys`, so the newly created `references/.sf6-drill_env_keys` was matched by
> no rule: `git check-ignore` returned nothing, and the `git add solutions/agent-containerization`
> that each of this feature's commits runs would have staged three live provider keys into a public
> repository. The rule is now `references/*env_keys*`. No commit ever staged the file and it is
> absent from history; `.dockerignore` already excluded `references/**` deny-all, so no build
> context carried it either.

### Drills E1, E2, E3 — the three provider API keys

All three share **one `t0`**, because one operator declares one incident and then visits three
consoles in series. Each row's `t1` is its own. The serialisation therefore sits **inside** the
later rows' measured times, which is the honest reading of R13.1: it bounds detection to
revocation, and the console visit *is* the revocation. Every row had 15:00 of room and used at most
02:29 of it.

- Drill credential: three dedicated drill keys minted by the operator for this drill (Anthropic,
  OpenAI, Google AI Studio), never the working keys — asserted, not assumed, as described above.
  No value recorded
- Stated maximum: **15:00** each
- t0 (incident declared, UTC): **2026-09-30T20:07:46Z**
- Steps:
  1. pod up under `default` with `--force-recreate` and **no `--build`**, so the images cannot
     change under the R8.5 evidence
  2. baseline, each key from inside **its own** agent and through the mediator, on an endpoint that
     authenticates without spending model tokens: `claude` → `GET api.anthropic.com/v1/models`
     (`x-api-key`), `codex` → `GET api.openai.com/v1/models` (`Bearer`), `agy` →
     `GET generativelanguage.googleapis.com/v1beta/models?key=…`. **All three 200**
  3. one detached poll per row, same request every 2 s, each line timestamped, 25-minute ceiling —
     so no clock can gap while the operator is at three consoles (Edge Case 18)
  4. the operator revokes all three
- t1 (replay refused, UTC) and measured:

| Row | Agent | Endpoint | Last 200 | t1 (first refusal) | Evidence | Measured | Within 15:00 |
|---|---|---|---|---|---|---|---|
| E1 | `claude` | `api.anthropic.com/v1/models` | `20:10:13Z` | **`20:10:15Z`** | HTTP **401** | **02:29** | yes |
| E2 | `codex` | `api.openai.com/v1/models` | `20:10:08Z` | **`20:10:11Z`** | HTTP **401** | **02:25** | yes |
| E3 | `agy` | `generativelanguage…/v1beta/models` | `20:09:48Z` | **`20:09:51Z`** | HTTP **401**, then alternating 401/400 | **02:05** | yes |

- **Refusal is monotonic in all three rows** — no poll returned 200 after its first refusal. 78, 62
  and 81 poll lines respectively. Survival past the console action is under the 2 s cadence for all
  three, the same as S2 and unlike S3's ~10 s or S4/S5's until-restart
- Access-token replay: n/a — these are static API keys, not OAuth rows. V1–V3 are where Edge Case 2
  bites
- Image IDs before / after: the five `default`-profile IDs (`2f28fb1cfa95 5cd5aa6b06e0
  b88fbfd61649 d04b811d8bef eb1e3b8e434c`), identical   Rebuild: **no** for all three
- Re-issue: not performed, and not required by these rows' procedures — a revoked API key is
  replaced by minting a new one at the provider, which is the same operation as minting the drill
  key and was already exercised at step 0. The keys stay revoked

#### E3's refusal status is not stable — 401 and 400 alternate

`agy`'s row answered **401** on most refused replays and **400** on two of nineteen, interleaved:
`401 401 401 401 401 401 401 401 401 400 401 401 401 401 400 401 401 401 401`. A harness that
asserted a specific refused status for this row would be flaky. What is stable is the property that
matters: **not 200, and never 200 again**. Recorded so that SF-7's criterion-to-evidence table, and
any later regression of this row, assert the absence of success rather than the presence of one code.

### Drill E4 — the one-year `CLAUDE_CODE_OAUTH_TOKEN` (`oauth-token` cell)

**This row's credential is minted on the HOST, not in the pod** — `images/bootstrap-auth.sh:291`
requires `CLAUDE_CODE_OAUTH_TOKEN` in the environment and mints nothing, because `claude
setup-token`'s flow is interactive. So the drill starts with an operator action, and the token
reaches the container by the bare `-e NAME` form like every other key here.

- Drill credential: a **fresh one-year token** minted by the operator with `claude setup-token` on
  the host for this drill, staged in `references/.sf6-drill_env_keys`. Asserted at run time to
  differ from the token already outstanding in `references/.env_keys` — that older one is **SF-7's**
  standing obligation, not this drill's. No value recorded
- Stated maximum: **15:00**
- t0 (incident declared, UTC): **2026-09-30T20:18:01Z**
- Steps:
  1. **two probes before any clock**, because a drill whose baseline is wrong measures nothing:
     - *the cheap one* — the token as a plain `Authorization: Bearer` against
       `GET api.anthropic.com/v1/models`: **200**, with and without `anthropic-beta:
       oauth-2025-04-20`. Free and pollable at 2 s, so this became the poll
     - *the real consumer* — the `claude` CLI itself with `AUTH_MODE=oauth-token`:
       `claude -p` returned **`OK`**, end to end through the mediator
  2. one detached poll on the bearer probe, 2 s cadence, 30-minute ceiling
  3. the operator revokes the grant at the Anthropic account that minted it
- t1 (replay refused, UTC): **2026-09-30T20:22:40Z** — evidence: HTTP **401** (last 200 at
  `20:22:38Z`, two seconds earlier), monotonic across the remaining polls, 138 poll lines in total.
  **Confirmed by the real consumer after revocation:** the CLI replay returned
  `Not logged in · Please run /login`. The cheap probe and the real credential path agree
- Access-token replay: n/a — a `setup-token` grant is a single long-lived token, not a
  refresh/access pair. V1–V3 are where Edge Case 2 bites
- Measured: **04:39**   Within maximum: **yes**
- Image IDs before / after: the five `default`-profile IDs, identical   Rebuild: **no**
- Re-issue: not performed. The token stays revoked, and E4's cell is a documented fallback rather
  than the default (R4.12 makes `oauth-interactive` `claude`'s default precisely so a year-long
  credential is not minted by default)

#### Edge Case 3 does NOT bite for this row — the revocation was single-grant

The operator reported that the console offered **only the single-grant revoke**: no account-wide
"log out all sessions", and no collateral effect on the operator's own sessions. Recorded as the
favourable case, which means **R4.17 is not engaged for E4**. Edge Case 3 remains open for V1 and
V2, where the credential is a provider *session* rather than a minted grant, and it is those rows
that have to be asked about before they are drilled.

**Why E4 took 04:39 where E1–E3 took around 02:15.** The difference is console navigation, not
provider latency: a `setup-token` grant is an **OAuth grant**, so it does not appear under
console.anthropic.com → API keys where the three E1–E3 keys live. The runbook's E4 line should say
where to look, and the operator's report is that the grant is revoked from the Anthropic account
that minted it rather than from the API-keys page. Recorded because four and a half minutes of a
fifteen-minute budget went to finding the page, and an incident is a worse time to search.

#### An observation about the cell's own reporting, not a finding against the credential

During both probes `bootstrap-auth` printed `(claude|codex, oauth-interactive) has no credential
yet` while the CLI on the very same invocation authenticated successfully on the drill token. The
`-e CLAUDE_AUTH_MODE=oauth-token` passed to `compose run` did not reach the entrypoint's `AUTH_MODE`
check, so the bootstrap reported the default cell's state while the credential the CLI actually used
came from the environment. Harmless here — the probe measured the credential, which is what the row
is about — but worth knowing that this warning does **not** mean the token is absent.

#### The mediator saw all three refused replays as allowed

Exactly S2's finding, now with a third and fourth provider behind it, so it is a property of the
architecture rather than of GitHub:

```
{"agent":"claude","identity_source":"listener+mtls","dest_host":"api.anthropic.com","verdict":"allow","http_status":200,"squid":"TCP_TUNNEL"}
{"agent":"codex","identity_source":"listener+proxy_auth","dest_host":"api.openai.com","verdict":"allow","http_status":200,"squid":"TCP_TUNNEL"}
{"agent":"agy","identity_source":"listener+proxy_auth","dest_host":"generativelanguage.googleapis.com","verdict":"allow","http_status":200,"squid":"TCP_TUNNEL"}
```

Every one of those lines is a **revoked** key being refused by its provider. The `http_status` is
the CONNECT tunnel's; the mediator does not terminate TLS on this path (D18) and never sees the
inner 401. **No provider-credential revocation is confirmable from the pod's own audit trail** — for
E rows, V rows and S2 alike. The runbook's § 4 evidence rule already says this for S2/S3; it applies
unchanged to every E and V row.

#### SF-7 close-out — the standing obligation is NOT discharged, and this is the evidence

E4's cell carries a standing obligation: revoke every one-year token minted to prove it. Two tokens
existed.

- **The SF-6 drill token** (`references/.sf6-drill_env_keys`) was revoked *by the drill itself* and
  measured dead — HTTP 401, monotonic across 138 poll lines, confirmed independently by the `claude`
  CLI replying `Not logged in`. Discharged.
- **The older token in `references/.env_keys`**, outstanding since before these drills, is **still
  live at close-out.** Replayed 2026-09-30T22:04:35Z: `GET api.anthropic.com/v1/models` with it as a
  plain bearer returned **HTTP 200**, twice, two seconds apart. Identified in this record by
  **sha256 prefix `8390a8b0`** and length only; no value, and no prefix beyond the provider's public
  type prefix.

The operator has stated it will be revoked **out of session**. **No revocation date is recorded,
because no replay has confirmed one** — and recording a date on the strength of an intention is
precisely what D-5 says not to do. The obligation therefore ships as an **open item** of this
feature rather than as a completed step, and the next replay that returns 401 is what closes it.

*(Why it is stated this loudly: the alternative was to write "revoked 2026-09-30" from an operator
answer that the replay then contradicted. A record that does that is worth less than no record.)*

### V1 — first attempt, abandoned before the clock, and the three findings it produced

**No `t0` was declared, so nothing here is a mis-measurement** — the baseline never held, and under
this record's own Method a drill whose baseline is wrong measures nothing. What the attempt did
produce is three findings about the pod, two of them defects.

**Sequence, from the mediator's trail and the volume itself:**

| Time (UTC) | Event |
|---|---|
| 20:30:11 | the operator's interactive login **completes** — `platform.claude.com` and `api.anthropic.com` both `allow`, **no deny anywhere**. The boundary is not involved in anything below |
| 20:32:39 | the credential file reads **509 B**, `expiresAt` **2026-10-01T04:29:59Z**, `refreshTokenExpiresAt` **2026-10-28T03:45:20Z** |
| 20:35:24 | baseline probes run; the CLI reports `Failed to authenticate: OAuth session expired and could not be refreshed` |
| 20:36 | the on-volume file is **281 B**, with `accessToken` and `refreshToken` as **empty strings** and `expiresAt` **0** |

#### FINDING 1 (defect) — the agent's own failure path destroys the credential evidence

On a refused refresh the CLI **cleared the token fields in place**: 509 B → 281 B,
`{"claudeAiOauth":{"accessToken":"","refreshToken":"","expiresAt":0,…}}`. No operator action and no
mediator deny took part.

**Consequence for T26 and T41, and it inverts an ordering:** the credential a revocation drill has to
replay can be destroyed by the agent before the drill replays it. This attempt's material survived
only because it was **preserved first** — 509 B copied to host scratch before any probe ran. "Preserve
before you probe" is therefore a procedural requirement of these rows, not prudence, and it is now
stated in the runbook. It is also a second, independent illustration of Decision 5's point: a copy of
the volume may already have left, so discarding is not revoking.

#### FINDING 2 (defect) — `bootstrap-auth` declares that emptied credential *authenticated*

`images/bootstrap-auth.sh:191`, the `claude` branch of `already_authenticated`:

```bash
[ -s "$CLAUDE_CONFIG_DIR/.credentials.json" ] || [ -s "$HOME/.claude.json" ]
```

It tests **non-emptiness of the file**, not the shape of its contents. The wiped file is 281 B, so
`-s` passes and a re-login is skipped:

```
bootstrap-auth: (claude, oauth-interactive) already authenticated -- no-op
```

`~/.claude.json` was **absent**, so the `-s` on `.credentials.json` was the sole cause.

**The check that would have caught it is eleven lines below, in the `codex` branch, with a comment
describing this exact failure** — `[ -s … ] && grep -q '"refresh_token"' …`, annotated *"SHAPE, not
just presence (edge case 11): a bootstrap interrupted mid-copy … must not read as authenticated"*.
The `claude` branch never received the equivalent.

**Finding 1 and Finding 2 compose into a trap:** a refused refresh empties the credential, and the
bootstrap then refuses to re-mint it, so the agent is **unrecoverable without an operator discarding
the state volume**. That also makes T41's *"each agent re-bootstraps authentication"* step
conditional on the credential not having been emptied first — a Milestone 02 criterion resting on a
presence test. The fix is one line mirroring the `codex` branch; it touches an image and therefore a
rebuild, so it is recorded here for the operator's decision rather than applied inside a drills
sub-feature.

#### FINDING 3 (method, against this drill) — the cheap probe was the wrong authority for this row

The attempt also ran the access token as a plain bearer against `api.anthropic.com/v1/models`, the
probe that worked for **E4**, and it returned 401. That proves nothing: a Claude Code *session*
access token (scopes `user:inference`, `user:profile`, …) is not necessarily accepted at that
endpoint, so its 401 is consistent with a perfectly live session. Standing it next to the CLI's
failure, as though both said the same thing, was a method error. **For V1 the CLI is the authority**,
and the record says so before the measured attempt rather than after.

#### What remains undetermined, and is not being guessed

Whether the session was already dead at 20:32 despite its future expiry — which would mean the E4
revocation reached **more than the single grant** it appeared to, and would require correcting E4's
"Edge Case 3 does not bite" conclusion — or whether it was live and the probe sequence triggered a
refresh the provider legitimately refused. The state volume has been discarded (its runbook
disposition, and V1's own containment step) and the drill is being re-run with the CLI alone as the
first and only probe. **E4's conclusion stands as recorded until that re-run says otherwise**, and it
is flagged here so a reader does not find the two records silently inconsistent.

### Drill V1 — `claude`'s OAuth refresh + access token on the state volume

Attempt 2, run serialized after attempt 1's findings above. **One container touches the credential
at a time**, because attempt 1's leading explanation is a refresh race between concurrent
`compose run` containers sharing one state volume — corroborated here: the baseline CLI call left
the credential **byte-identical** (`fa470907f6c4…` before and after), where attempt 1's overlapping
containers left it emptied.

- Drill credential: a fresh interactive login performed by the operator into the pod, on the
  operator's own Anthropic account (this cell has no separate-account form). Preserved to host
  scratch **before any probe**, per Finding 1. 509 B, sha256 `fa470907f6c4…`; no value recorded
- Stated maximum: **10:00 — a containment clock, not a provider clock** (operator decision,
  2026-09-29). It bounds isolate-and-discard, not the provider's effectiveness
- Measured expiries, read from the credential itself rather than inferred: access token
  **2026-10-01T04:42:20Z** (7 h 53 m out), refresh token **2026-10-28T02:59:43Z** (28 days).
  01.4 measured the 28-day refresh lifetime by inference; the file now carries
  `refreshTokenExpiresAt` explicitly, which corroborates it
- t0 (incident declared, UTC): **2026-09-30T20:45:46Z**
- Steps, in the order the runbook mandates for a V row — **contain first, then revoke**, because a
  copy of the volume may already have left (Decision 5):
  1. **isolate** — `docker network disconnect` the agent from its only network
  2. **drain, then stop the recorder** (§ 3.2 ordering), 6 s
  3. **discard** `claude-state` — `docker volume rm`
  4. the operator revokes the OAuth session at the provider. **Granularity, operator-reported:
     single-session — the console revoked the pod's session alone, with no account-wide
     "log out everywhere" and no effect on the operator's own other sessions. So Edge Case 3 does
     **not** bite for this row either, and R4.17 is not engaged. Two of two provider rows drilled so
     far have offered per-credential revocation; Edge Case 3's premise remains unreproduced, and V2
     is the next chance to test it**
  5. **access-token replay** — the preserved credential restored **unchanged**, expiry still in the
     future, so the CLI uses the access token without refreshing
  6. **refresh-token replay** — restored with `expiresAt` forced to the past, so the refresh token
     is the only way forward
- **Contained at 20:45:53Z — 00:07.   Within the 10:00 containment clock: yes**
- t1 (replays refused, UTC): **20:49:09Z** (access token) and **20:49:13Z** (refresh token) —
  **03:23** and **03:27** from `t0`. Evidence, from the row's authoritative consumer:
  `Failed to authenticate: OAuth session expired and could not be refreshed`, on both
- Image IDs before / after: the five `default`-profile IDs, identical   Rebuild: **no**
- Re-issue: not performed; the session stays revoked

#### Edge Case 2's premise does NOT hold for V1 — the access token did not outlive revocation

This is the row's substantive result, and it is the opposite of what the plan anticipated.

Edge Case 2 and criterion 1 both provide for V1's **8-hour access token surviving revocation until
its own expiry**, with that survival recorded as the measured time and a compensating action added
to the runbook. **Measured: it did not survive.** The access token's own stated expiry was
`2026-10-01T04:42:20Z`, 7 h 53 m after `t0`; it was already refused **03:23** after `t0`, on the
first post-revocation replay. The token died on revocation, not on expiry.

**The limitation of this measurement, stated rather than glossed.** The CLI reports one message for
both halves (`OAuth session expired and could not be refreshed`), so through this consumer the two
cannot be separated cleanly: the natural reading is that the access-token call was rejected, the CLI
then attempted a refresh, and that was refused too. A raw-HTTP separation is not available for this
row — the bearer probe that works for E4 is **not** authoritative for a session token (Finding 3),
and it returned 401 both before *and* after revocation. What is measured with confidence: **the
credential as a whole stops working within 03:23 of `t0`, and well before the access token's stated
expiry.**

**Consequence for the runbook:** the compensating action Edge Case 2 asks for — isolate and discard
at `t0`, before revoking — stays in the runbook, and stays right. But it is now there as
**defence-in-depth against a survival that was not observed**, rather than as mitigation for a
measured 8-hour hole. The honest claim against R13.1 for V1 is the containment clock (**00:07**)
plus the provider becoming effective inside **03:27**, and the plan's anticipated finding is
recorded as **not reproduced**. V2/V3's 10-day JWT is a separate question and is not answered by
this row.

#### Finding 1 reproduced independently

The refresh-replay failure wiped the credential a second time — 509 B → **281 B**, both token fields
empty — from a file this drill had just restored. Two independent observations of the same
destructive failure path, in one sub-feature, on a file that in the second case was *known-good
before the call*. The preserved host copy is what made the second replay possible at all.

#### Both defects are FIXED, and fixing the first one exposed a third structural trap

The operator was offered fix-now / defer-to-SF-7 / leave-as-a-finding and **chose fix now**, so
SF-6 changed image code — recorded as **Deviation 5** in the feature plan, since a drills
sub-feature was not scoped to touch the pod's authentication path.

**The fix.** `already_authenticated()`'s `claude` branch now tests the credential's **shape**, as
its own docstring ("Presence and shape only") always claimed and as the `codex` branch eleven lines
below already did. Both arms require a non-empty `accessToken`. The undocumented
`$HOME/.claude.json` arm was **narrowed, not removed** — Chesterton's Fence: it has no recorded
rationale, claude 2.1.260 was measured not to create it, and narrowing it wrongly costs a re-login
prompt, never a bad credential accepted as good.

**Then the fix did nothing, and that is the third instance of one trap.** All three agents were
rebuilt and `bootstrap-auth` in the rebuilt image **still reported the old behaviour**, because
`images/bootstrap-auth.sh` was copied in the `agent-base` stage — pulled from GHCR **by digest**
(D21), and BuildKit skips a stage nothing references. `entrypoint.sh` hit this at **01.6 SF-3** (a
credential splice that silently did not happen), `pack-install.sh` at **02.3 SF-2**, and the
`agent-base` stage carried a note predicting the third:

> *"an edit to images/bootstrap-auth.sh does not reach a local build until CI republishes this stage
> and compose/pins.env is repinned. Recorded rather than fixed here; the next feature that needs to
> edit it will have to choose, with this note in front of it."*

This is that feature. The COPY **moved** to `agent-packs` (Deviation 6), beside the three files that
made the same move for the same reason — moved rather than duplicated, so no operator is left unable
to tell which copy is running. **Found by building, not by reasoning**, which is the same way 01.6
SF-3 found it.

**Verified in both directions after the move:**

| Credential on the volume | `bootstrap-auth` says |
|---|---|
| the emptied shape this drill produced (`accessToken: ""`, `expiresAt: 0`) | `WARNING -- has no credential yet` + the exact login command. **Re-login is no longer skipped** |
| a shaped credential (non-empty `accessToken`) | `already authenticated -- no-op`, unchanged |

**Consequence for this feature's other numbers, stated so no reader has to work it out:** the
rebuild changed the agent image IDs at this point. Every R8.5 "no rebuild" result already recorded —
S1–S5, E1–E4, V1 — was measured against the *pre-fix* images and is internally consistent, each
comparing before and after **its own** drill. V2 and V3 will be measured against the post-fix
images.

#### Two procedural gaps the clock exposed, both now in the runbook

**The discard fails while a stray one-off container holds the volume, and the message names only a
hex ID.** Attempt 2's first clock was **voided** for exactly this (Edge Case 18: a clock that does
not complete is re-run, not annotated): `docker volume rm` returned
`volume is in use - [08efe4ad2025…]`. The holder was the operator's own **login container** — a
`compose run` one-off, still running from the interactive login minutes earlier. This compounds
SF-3's recorded finding that one-off containers carry `com.docker.compose.oneoff=True` and are
ignored by `compose stop`/`start`/`down`: **`compose down` will not clear them, so the discard step
must clear them explicitly.**

```bash
docker ps -aq --filter label=com.docker.compose.project=<project>               --filter label=com.docker.compose.oneoff=True | xargs -r docker rm -f
```

**For an agent whose command exits, isolation is degenerate and the discard is the containment.**
The shipped `default` command prints a version and exits, so `claude` was `exited` when the
containment ran. The disconnect succeeded on the exited container the first time and returned
`endpoint sandboxed-agent-pod-claude-1 not found` on the re-run — it had already taken effect. No
part of the isolation could stop traffic that was not flowing. The containment that actually
contains, for this shape, is the state-volume discard; T40's disconnect form is measured properly in
harness phase B, where the agents are given a long-running command for that purpose.

### V2 — the survival half measured, the timed row still outstanding

**What this attempt did and did not produce.** No `t0` was declared and no containment clock was
run, so **V2's timed row remains undrilled**. What it did produce is the row's *substantive*
question, measured: whether a revoked `codex` session's tokens keep working. They do — **both
halves** — which is the opposite of V1's result and the confirmation Edge Case 2 was written for.

#### FINDING (confirmed) — a revoked `codex` session's access **and** refresh tokens both keep working

The operator revoked the session in the ChatGPT UI. Afterwards, from inside the pod, with the
preserved `auth.json` restored and nothing else changed:

| Replay | Time (UTC) | Result |
|---|---|---|
| full credential, real consumer (`codex exec`) | **21:19:36** | **succeeded** — fresh session `01a0f42f-…`, 14-line rollout, model answered |
| `access_token` **emptied**, `refresh_token` kept, forcing a refresh | **21:20:06** | **succeeded** — its own new session `01a0f430-…`, 14 lines. The refresh token minted a working token *after* revocation |
| preserved `access_token` direct to its own audience (`api.openai.com/v1/models`) | 21:20:34 | **403**, where an unauthenticated request to the same endpoint returns **401** — the identity is still recognised, and merely unentitled for that endpoint |

The second row is the one that matters and it was nearly missed: that run emitted 401s on
`wss://chatgpt.com/backend-api/codex/responses` and a trailing `OK` whose token count (1,838) was
*identical* to the previous run, which looked like stale output. The session files settle it — it
wrote **its own** rollout, 14 lines, at 21:20:10. The 401s were a transport fallback, not a failure.
**Evidence of success here is a new session file, not the presence of an `OK`.**

**The access token's own lifetime, read from its JWT rather than from a vendor claim:**
`iat 2026-09-30T21:09:25Z`, `exp 2026-10-10T21:09:25Z` — **exactly 10.0 days**,
`aud ["https://api.openai.com/v1"]`, `iss https://auth.openai.com`. The inventory's "10-day access
token" is confirmed to the second.

**Consequence, and it is not symmetric with V1.** For V1 the isolate-and-discard-before-revoking
ordering turned out to be defence in depth against a survival that did not occur. **For V2 it is
load-bearing:** provider-side revocation did not contain this credential at all, so the *only*
containment that worked is the pod-side one — isolate the agent and discard its volume at `t0`.
And because the **refresh token** survives, the exposure is **not** bounded by the access token's
ten days; it is bounded by whatever actually invalidates the refresh token, which per-device
revocation in the ChatGPT UI demonstrably did not.

#### FINDING (method, against this drill's own conduct) — a credential value was printed

While listing `auth.json`'s **field names**, the drill used a `sed` that emitted each key *with its
value*, printing the session's `access_token`, `id_token` and `refresh_token` in full into the
session transcript, along with the account id, plan type and the profile e-mail and name carried in
the `id_token`. This record's own rule — *no credential value ever enters this record* — held for
the record itself: nothing was written to disk in the repository, and the preserved copy lived at
mode 0600 outside the repository. The transcript is the exposure.

It is recorded here rather than quietly fixed because it is the same class of failure this feature
keeps finding in the pod: **a check that looks like it inspects names but actually handles values.**
The safe form for this purpose is `grep -o` on the key names, or a byte count and a sha256 prefix —
never a substitution that echoes the matched text.

**Remediation attempted, and its measured outcome.** The operator revoked the session immediately in
the ChatGPT UI. The replays above then established that **the revocation did not invalidate either
half** — which is why this incident and the V2 finding are the same measurement read two ways: the
mitigation for the leak was the very action the row proves ineffective. **Residual, accepted by the
operator (2026-09-30):** the exposed credential set remains valid — the access token until
2026-10-10T21:09:25Z, the refresh token until something invalidates it. Account-wide logout and a
password change were offered as stronger measures and **declined**; no further action was taken.
The preserved local copy was deleted. R4.17 is engaged here in a way no drill planned: the
per-credential revocation this account offers does not, in fact, revoke.

#### FINDING — a `codex` agent that has run once cannot start again

Unrelated to credentials, found while completing the replay, and blocking it. `codex` v0.152.1
**provisions its own bundled system skills** into the state volume on first run —
`~/.codex/skills/.system/` holding `imagegen`, `openai-docs`, `plugin-creator`, `review-agent` and a
`.codex-system-skills.marker`, written at 21:18:24, three minutes *after* `auth.json` and by the
agent itself rather than by the login. Every shipped profile inventories `skills: []` (02.3
Decision 8), so `images/mcp-gate.js` then refuses the agent at start:

```
mcp-gate: REFUSED uninventoried server 'codex-system-skills' in /home/agent/.codex/skills/.system (R7.14, T29)
```

**exit 3, before the agent CLI runs.** The refusal is correct — the gate is doing exactly its job,
on content the agent wrote to its own state volume. The consequence is that **a `codex` container
that has completed one run cannot be started again** until an operator removes that directory or the
inventory declares those skills. Two existing conclusions are affected:

- **T41's "each agent re-bootstraps authentication"** (criterion 3) meets this on any `codex`
  re-bootstrap that follows real use, and SF-4's MCP-disable finding already established that the
  fix cannot be applied from inside the agent — `run_mcp_gate` precedes `exec "$@"`, so a refused
  agent exits before any edit can run. The working form is a helper container on that agent's **own**
  image, mounting the state volume (runbook § 3.3).
- **02.3 Decision 8's image-baked inventory** is what makes this an operator action rather than a
  configuration change: declaring the skills requires a rebuild and a repin.

Not fixed here — it is a 02.3 surface, and SF-6 is a drills sub-feature that has already taken two
deviations into image code. Recorded for the operator's decision.

### MUST REACH USER DOCUMENTATION (written at SF-7)

Operator-facing consequences that a reader of `README.md` and the runbook must not have to find in a
drills record. **SF-7's close-out is not complete until each is written into user-facing
documentation.**

| # | What must be documented | Where it belongs | Source |
|---|---|---|---|
| **D-1** | **Provider revocation does not contain a `codex` session.** Both token halves keep working after per-device revocation in the ChatGPT UI; the refresh token keeps minting new access tokens, so the window is not the access token's 10 days. **Containment is pod-side: isolate the agent and discard its state volume at `t0`, before revoking** — and for this row that ordering is load-bearing, not defence in depth | `README.md` containment section **and** runbook § 3.4 / § 4 (V2/V3 rows) | V2 finding above |
| **D-2** | **The asymmetry between rows.** V1's access token died on revocation; V2's did not. An operator must not generalise from one provider to another, and the per-row evidence rule already in runbook § 4 is the reason each row is replayed rather than assumed | runbook § 4 | V1 + V2 |
| **D-3** | **A `codex` agent that has run once will not restart** until its self-provisioned `~/.codex/skills/.system` is removed by a helper container on its own image, or the profile's MCP inventory declares those skills (a rebuild and repin, 02.3 Decision 8). Include the exact refusal text so the message is searchable | `README.md` MCP-inventory section **and** runbook § 3.3 | codex-skills finding above |
| **D-4** | **A stray `compose run` one-off container blocks every volume discard**, `compose down` does not clear one-offs, and an interactive login leaves exactly such a container behind. Include the clearing command | runbook § 5 (already in § 3.4; must also reach the README's recovery text) | V1 drill |
| **D-5** | **"Revoked" is not a state you may assume.** `t1` is a replay that fails. V2 is the worked example: a console action reported success while the credential kept working. User documentation must tell an operator to replay after revoking | `README.md` containment section | V2 finding |
| **D-7** | **`README.md`'s `oauth-mount` warning overstates its cost and understates its risk.** "Costs you your host codex login" was **not** measured: after the container rolled, the host set's refresh token still worked. Rolling is not revoking. The correction must say both halves — the host login may well keep working, **and** a captured copy is not neutralised by rotation | `README.md` `oauth-mount` section (the paragraph at README:262) **and** the V3 inventory row | V3 finding above |
| **D-8** | **`docker compose images --quiet` cannot verify R8.5 across a containment that removes a container** — it lists per container, so a removed agent looks like a changed image. Compare per service by name, or re-create the service first | runbook § 3.4 (where the R8.5 confirmation command is given) | V3 method note |
| **D-6** | **The credential-handling rule for anyone reproducing these drills:** never print a credential file's contents while inspecting its structure — key names via `grep -o`, size via `wc -c`, identity via a sha256 prefix | `docs/records/containment-drills.md` method preamble **and** the README's drill-reproduction note | method finding above |

#### Where each item was written — SF-7, 2026-09-30

**All eight are now in user-facing documentation.** The table above is the source; this one is the
destination, so a reader can check the claim rather than take it. Close-out was not complete while
any item was only in this record.

| # | Written into | What it says there |
|---|---|---|
| **D-1** | `README.md` § "Containment and response (02.5)", bullet 2 · `docs/containment-runbook.md` § 3.4 (second bullet of the two revocation rules) · § 4 (the V-row clock note, rewritten) | Provider revocation leaves both `codex` token halves working; containment is pod-side and the isolate-then-discard-then-revoke ordering is load-bearing for V2/V3, not defence in depth |
| **D-2** | `README.md` § "Containment and response", bullet 3 · runbook § 3.4 and § 4 (same rewritten note) | `claude`'s access token died on revocation, `codex`'s did not — the per-row replay rule is why, and an operator must not generalise across providers |
| **D-3** | `README.md` § "Tool packs, use-case profiles and MCP inventory (02.3)" (new bullet, with the exact refusal text) · `README.md` § "Containment and response", bullet 5 · runbook § 3.3 (with the helper-container command) · runbook § 5.1 step 9 | A `codex` agent that has run once will not restart until `~/.codex/skills/.system` is cleared from outside the agent, or the inventory declares those skills (a rebuild and a repin) |
| **D-4** | `README.md` § "Containment and response", bullet 4 (with the clearing command) · runbook § 5.1 **step 6**, promoted to its own numbered step before the discard (it was already in § 4's clock notes) | A stray `compose run` one-off blocks every volume discard, `compose down` does not clear one-offs, and an interactive login leaves exactly such a container |
| **D-5** | `README.md` § "Containment and response", bullet 1 · `README.md` § "Revocation (R12.6)" · runbook § 3.4 (first bullet of the two revocation rules) | "Revoked" is not a state to assume: `t1` is a replay that fails, and V2 is the worked example of a console action reporting success over a credential that kept working |
| **D-6** | `README.md` § "Containment and response" (closing paragraph) · this record's **Method** preamble | Never print a credential file's contents while inspecting its structure — key names via `grep -o`, size via `wc -c`, identity via a sha256 prefix |
| **D-7** | `README.md` § "Codex `oauth-mount` (optional, one-shot)" — the warning paragraph rewritten with both halves · `credential-inventory.md` V3 row (already carried the finding) | The old "costs you your host codex login" was never measured: the host set still worked afterwards. Rolling is not revoking, and a captured copy is not neutralised by rotation |
| **D-8** | `docs/containment-runbook.md` § 3.4 (at the R8.5 confirmation command) | `docker compose images --quiet` lists per container, so a containment that removed a container makes a naive comparison read as a changed image — compare per service by name, or re-create the service first |

**The plan's SF-7 bullet says "six (D-1 to D-6)"; there are eight.** D-7 and D-8 were added to this
table during SF-6 alongside the first six, and the plan's own SF-6 built-note records the count as
eight. The table is the binding list and the numbering is left as SF-6 wrote it — nothing is missing
and nothing was renumbered. Not recorded as a deviation: the record supersedes a bullet written
before the last two items existed.

### Drill V3 — `codex`'s OAuth set with host provenance (`oauth-mount`)

This row's credential type is **identical to V2's**; only its provenance differs. So what V3
uniquely tests is the provenance property the plan states as **"rotation is not revocation — a
captured refresh token stays valid after the legitimate client refreshes past it"** — and that
claim was in **direct contradiction** with `README.md`'s own operational advice for this cell
(*"Treat it as a one-shot bootstrap that costs you your host codex login: expect to run `codex
login` on the host again"*). Both cannot hold. This drill decides it.

- Drill credential: **the operator's own host `codex` login** — which is not a departure from the
  throwaway rule but the definition of this cell: host provenance *is* the credential under test
  (R4.13–R4.15). Staged by `scripts/stage-oauth-mount.sh`, which strips `OPENAI_API_KEY` on the way
  through. Preserved pre-rotation copy: 4025 B, sha256 `cb59d5447902…`; host copy 4050 B,
  `883ca04a7291…` (differing only by the stripped key). No value recorded, and `~/.codex` was never
  written to. **Operator authorised the measurement, having been told it could cost the host login.**
- Stated maximum: **10:00 — the containment clock**, as V1 and V2
- t0 (incident declared, UTC): **2026-09-30T21:35:38Z**
- **Contained at 21:35:54Z — 00:16.   Within the 10:00 containment clock: yes.** One-off containers
  were cleared first, per **D-4**, the gap V1's voided clock exposed; isolate → 6 s recorder drain →
  stop → discard `codex-state`. The other two agents and the mediator stayed `running`, 1962 audit
  lines and both action-audit volumes preserved
- Image IDs before / after: identical — but see the measurement-method note below, because the naive
  comparison **looked** like a change   Rebuild: **no**

#### The bootstrap boundary held, measured rather than assumed

| Property | Result |
|---|---|
| the staged set reaches the volume | `auth.json` 4025 B, sha256 `cb59d5447902…` — **byte-identical to the staged copy** |
| `OPENAI_API_KEY` stripped (test-validity control, so the cell cannot pass on the API key) | field **absent** from the volume copy |
| the bootstrap source is absent at steady state (R4.15 — the boundary is the mount, not a flag) | `/run/oauth-src` **not present** in a steady-state container |

#### FINDING (confirmed) — rotation is NOT revocation, and the README's advice is wrong about the cost

Measured in four steps, each with its own evidence, and the V2 lesson applied throughout —
**success is a new session file, not the presence of an `OK`**:

| # | Step | Evidence |
|---|---|---|
| 1 | pod bootstrapped from the staged set | volume sha `cb59d5447902…`, `last_refresh 2026-09-27T22:56:13Z` |
| 2 | the pod's copy forced to refresh (its `access_token` emptied, refresh token left) | **rolled**: sha → `00eae84a5adb…`, `last_refresh` → **2026-09-30T21:33:40Z**, model call succeeded, 14-line session at 21:33:44Z. 01.4 SF-3's "codex **rolls** its refresh token" is reconfirmed |
| 3 | the **captured pre-rotation copy** restored and replayed | **worked** — its own 14-line session at 21:34:09Z. `auth.json` unchanged afterwards (`cb59d5447902…`, `last_refresh` still 09-27), so this step used the superseded **access** token |
| 4 | the captured copy with its **`access_token` emptied**, so only the **superseded refresh token** can work | **worked** — session count 2 → 3, a 14-line session at 21:34:37Z, and `auth.json` **refilled** with a new access token (`last_refresh 2026-09-30T21:34:34Z`, sha → `b72d7f020e89…`). The superseded refresh token minted a working credential **one minute after the pod had rolled past it** |

**So both documents were half right, and the distinction they collapse is the whole finding.**
`codex` does **roll** its refresh token — a new token is minted, which is what 01.4 SF-3 measured and
what the README describes. It does **not revoke the old one**. Rolling and revoking are different
events, and every operational consequence follows from which one you assume:

- **The plan's premise is CONFIRMED.** A captured refresh token stays valid after the legitimate
  client refreshes past it. For an incident, this is the important direction: **rotation does not
  neutralise a copy that has already left** (Decision 5, now measured for this row rather than
  argued).
- **`README.md`'s stated cost is NOT what was measured.** "Costs you your host codex login — expect
  to run `codex login` on the host again" did not happen: the host set's refresh token still worked
  after the container's roll. The cost is *possible*, not certain, and the README states it as
  certain. **This is D-7 below.**
- **Together with V2, the picture for `codex` is coherent and uncomfortable:** neither provider-side
  revocation (V2) nor rotation (V3) invalidates a captured credential set. The only thing that
  contained anything in either row is the pod-side action — isolate and discard at `t0` — and a
  captured `codex` credential must be treated as **live until its own expiry** regardless of what
  the console reports.

#### Measurement-method note — `compose images` is a per-CONTAINER listing

The naive R8.5 comparison across this drill **looked like a change**: five image IDs before, four
after. The missing line was `69c0a08b3b2c…`, `codex`'s own image, absent because the containment had
**removed codex's container** — `docker compose images` enumerates images per running container, not
per defined service. Recreating the service restored the fifth line, identical, and the correct
result is **no rebuild**.

Recorded because the runbook tells an operator to confirm R8.5 with
`docker compose images --quiet` before and after, and **any containment that removes a container
will make that comparison lie**. Compare per service by name, or re-create the service before
comparing. V1's comparison was unaffected because that drill recreated `claude` before its replays.

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

## T37 — the authorization gate (SF-2, results recorded at SF-7)

Built at SF-2 and measured by `verify-containment.sh` **phase F**. Enforcement is by **capability
absence** (Decision 1): a profile must account for every action its loaded packs — and its
inventoried MCP servers — can enable, as either `classify` (requires human authorization) or
`waive: {<action>: <reason>}`, and the compiler refuses a classification the pod cannot enforce.

**Phase F result: 35 passed, 0 failed** (composite run of the committed tree, 2026-09-30). It covers
both directions: one compile negative per Interface Contract 2 row against probe profiles in a
scratch copy; every shipped profile compiles and passes `--check`; and the runtime half under
`default` — capability absence inside all three agents (no `GH_TOKEN`/`GITHUB_TOKEN`/`KUBECONFIG`,
no `/run/secrets/pack-*`, no `credential.helper`, no `~/.git-credentials`) plus a refused
`CONNECT github.com` from `claude` and `agy`, with deny lines carrying `identity_source`
`listener+mtls` and `listener+proxy_auth` respectively.

**Baseline note, unchanged from SF-2:** `compile-policy.sh --check` still exits 4 for the
`test-fixtures` and `test-selfcheck` profiles, as it did before SF-2 — those two are compiled from
`allowlist.test.yaml`.

### Recorded negative control

Run once on a scratch copy of the committed tree, 2026-09-30, and **not** left in the suite. The
plan predicted one variant; the compiler has **two** distinct refusals here, and both were measured
because they are different controls and a reader would otherwise assume the wrong one.

**Variant A — the waiver removed entirely** (the plan's literal "removing `git-push` from
`github`'s `waive`"). The action is then neither classified nor waived, and the *accounting* rule
fires first:

```
compile-policy: INVALID: profiles/github.yaml: the action 'git-push' is declared by
packs/github-cli/pack.yaml but this profile neither classifies nor waives it (R12.7). Add it to
authorization.classify, or to authorization.waive with a recorded reason
```

**exit 2** — an input-validation failure. Silence is not an option: a profile cannot decline to have
an opinion about an action its own pack enables.

**Variant B — `git-push` moved from `waive` to `classify`** (the refusal the plan's "exit 3"
describes). The classification is now one the pod cannot enforce, and the T37 rule fires:

```
compile-policy: REFUSED: profiles/github.yaml classifies 'git-push' as requiring human
authorization, but it loads pack 'github-cli' (packs/github-cli/pack.yaml), whose credential,
egress or binaries enable that action for an unattended agent. A classification the pod cannot
enforce is a note, not a control (T37). Either remove the pack from this profile's 'packs', or move
'git-push' from 'classify' to 'waive' with a recorded reason for why unattended 'git-push' is
acceptable here
```

**exit 3** — the T37 refusal proper.

Together they are the whole gate in negative form: **exit 2 says you must decide, exit 3 says you
may not decide something the pod cannot deliver.** The plan's single predicted control is variant B;
variant A is recorded because the obvious edit an operator would make (deleting the waiver) produces
the *other* message, and a reader who expects exit 3 would mis-read exit 2 as a different defect.

### `codex` and `github.com` (Edge Case 16)

`codex`'s base allowlist already carries `github.com` and `api.github.com` for reasons recorded at
01.1, so under `default` its only barrier to `git-push` is the **absent credential**. No live push is
attempted — the harness contacts no third-party host. The residual this leaves is a
repository-embedded credential in the project mount (a token in `.git/config`).

**Measured at SF-2, phase F.** The credential-absence checks ran inside `codex` like the other two
agents and passed — no `GH_TOKEN`/`GITHUB_TOKEN`/`KUBECONFIG`, no `/run/secrets/pack-*`, no
`credential.helper`, no `~/.git-credentials` — and no `CONNECT github.com` refusal was asserted for
`codex`, because for this agent there is none to assert: the name is on its base allowlist and the
request is allowed at the mediator. The halt rests on credential absence alone, which is what the
phase measures, and the residual above is unchanged by the measurement.

---

## T44 — the mediation seam (SF-7)

Inspected 2026-09-30 on the **built** mediator image (`sandboxed-agent/mediator:local`,
image ID `5cd5aa6b06e0`), not on the Dockerfile's intent. Three things, as criterion 6 asks, and the
conclusion names its limits.

### 1. The build flags — the capability is COMPILED IN

```bash
docker run --rm --entrypoint squid sandboxed-agent/mediator:local -v
```

```
Squid Cache: Version 6.13
Service Name: squid
Debian GNU/Linux 13 (trixie)
```

Its `configure options` carry **both** `'--enable-icap-client'` and `'--enable-ecap'`, and the
image ships the adaptation module directory. So the content-adaptation seam is **present in the
binary this pod runs**: an ICAP service or an eCAP module could be attached by configuration alone,
with no new image and no upstream build of Squid.

Note the `--rm`: a one-off left behind here is exactly the container that blocks a volume discard
later (D-4). Inspection uses the same hygiene the runbook demands during an incident.

### 2. The front/inner `cache_peer` cascade — where an adaptation point would sit

The topology is a **self-cascade**: for the two TLS-fronted agents, a front listener terminates the
proxy hop and forwards through `cache_peer 127.0.0.1 parent <inner>` to an inner `http_port …
ssl-bump` listener that peeks the ClientHello (`images/mediator/entrypoint.sh:442-472`;
`mediator/config/proxy.conf.tmpl:7-20`). `codex` gets one listener that does both. Identity survives
the hop because policy is selected by `myportname`, never by the client address — every inner
listener sees `127.0.0.1`.

For T44 the cascade matters in one specific way: it is **two master transactions**, so an adaptation
service attached at the inner layer would see the CONNECT and its own annotations, and the front's
`cache_peer_access <agent>peer allow p_<agent>_frontreal` is what keeps the inner reachable by
nothing else. The seam therefore has a place to attach that is already per-agent and already
identity-annotated. **What it would see is still only the CONNECT envelope** — see § 4.

### 3. The template seams — `@GATE_RULES@` and `@PROXY_LISTENERS@`

`mediator/config/proxy.conf.tmpl` is rendered at start from `policy/resolved/<profile>.yaml`; the
fixed lines carry the **ordering** (which is the policy) and the `@…@` markers carry only per-agent
content (`proxy.conf.tmpl:1-5`). `@PROXY_LISTENERS@` (line 77) renders the listener set with its
per-agent `clientca=`/`tls-cert=` and auth scheme; `@GATE_RULES@` (line 247) renders the per-agent
allowlist gate, and it is deliberately placed **before** any rule that can resolve a name
(`proxy.conf.tmpl:195-203`) so that a name off an agent's list is refused before the mediator
resolves it.

Both are true seams in the sense T44 asks about: new rule classes render into an existing, ordered
policy, and the entrypoint fatals on any **surviving** marker in the rendered file, so a
half-substituted policy cannot start. Adding a rule class means an entrypoint change plus a
recompile — **an image rebuild, not a live reload** (D4).

### 4. Conclusion, with its limits named

**A tool-call-aware layer is not reachable without a decision, and the decision is not this
feature's.** Concretely:

- **The binary is not the blocker.** ICAP and eCAP are compiled in (§ 1), and the cascade already
  offers a per-agent, identity-annotated attach point (§ 2).
- **TLS termination is the blocker, and it is a D4 decision.** Every allowed path today is
  peek+splice: the mediator sees the CONNECT envelope and the SNI, never the request body, so no
  adaptation service attached today could see a tool call. Seeing one means terminating and
  inspecting agent-to-provider TLS — which is what D4 declines, and it is a **decision**, not a
  missing capability.
- **For `agy` it is never available at all** (R5.13): its proxy hop is itself TLS, and its route is
  the one where termination is out of scope by requirement rather than by preference.
- **The mediator never sees stdio** (D18). An MCP server on stdio has no egress leg through this
  seam, so a tool-call layer built here would be blind to exactly the surface 02.3's `mcp-gate`
  exists to cover.
- **Any rule class is a rebuild** (§ 3), so even the reachable half is not a runtime control.

**"Without redesign" does not mean "without a decision".** The seam is real and the capability is
compiled in; what stands between it and tool-call mediation is D4's refusal to terminate TLS and
D18's stdio blind spot. Recorded, not resolved.

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

**After SF-6 completed they are GONE — this half of phase A is green.** Measured on the committed
tree 2026-09-30: **167 passed, 2 failed**, and the two remaining failures are part 2's R14.3 pair
alone, which closes at SF-7. All twelve inventory rows carry a measured value (or, for V2, a
recorded `GAP`) and a rebuild cell:

```
PASS: A2: every inventory row carries a measured detection-to-revocation time or a GAP
PASS: A2: every inventory row states whether a rebuild was required (R8.5)
```

Edge Case 17's expected red is therefore closed, on the sub-feature the plan said would close it.

**After SF-6's E rows, E4 and V1 they named only V2 and V3** — measured on the committed tree
2026-09-30, after the Deviation 5/6 image change, at **165 passed, 4 failed**: the same totals as
before that change, which is the regression evidence for it.

```
FAIL: A2: rows with no measured value and no GAP: V2 V3
FAIL: A2: rows with no rebuild cell: V2 V3
```

`verify-auth-state.sh` — the harness that actually covers `already_authenticated()` — was
deliberately **not** run: its own header records that it iterates **live provider credentials, the
operator's real accounts**, which is why D22 keeps it out of the composite. With the drill session
revoked it would fail for want of a credential rather than for a regression, and would spend the
operator's working credentials to do it. The two-direction test of the rebuilt image above is the
targeted evidence in its place.

**After SF-5 they named only the seven provider rows** — measured on the committed tree,
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
| SF-6 (drills complete) | **green — measured: 167 passed, 2 failed, both the R14.3 pair** | **red — measured, the same 2 failures** |
| SF-7 (close-out) | **green** | **green — measured: `verify-containment.sh` 169 passed, 0 failed, rc=0 (2026-09-30)** |

**Deviation 3 is closed.** Phase A is fully green, and the two-part expected red is now a recorded
history rather than an outstanding state. The closing write was the R14.3 three-route table, the
cadence statement and the tabletop in `docs/records/third-party-assessments.md` § R14.3 — the shape
phase A reads, with SF-7's content in it.

---

## Proposed edits — recorded here, not applied (criterion 8)

Two edits are carried as exact replacement text for an authority that may apply them. Neither is
applied by this feature.

### 1. `docs/ARCHITECTURE_AND_DESIGN.md` — the runbook table

The architecture document's runbook table states "denylist entry at the mediator" as a live action.
It is **a rebuild**, not a live action: the policy is baked into the mediator image and there is no
live reload (D4). The live forms are the **network disconnects**, and the recorder is stopped
**alongside** its agent, after it drains.

**Exact replacement text, written 2026-09-30 from the measured forms** (SF-3 phases B–D, SF-4's
MCP-disable exercise and full T41 drill, SF-5/SF-6's twelve revocation rows). Four of the five rows
change; the MCP row is already correct and is left alone.

`ARCHITECTURE_AND_DESIGN.md:697-707` — the runbook table, replace:

> | Need | Action |
> |---|---|
> | Cut egress immediately | Denylist entry at the mediator, or detach the agent's network |
> | Isolate one agent, others keep running | Stop that container. Per-agent networks (D2) make this native, not a special case (R13.2) |
> | Disable one MCP server or tool across all agents | Profile inventory change plus rebuild. **No live mechanism exists** — recorded, not solved (R13.2 partially unmet) |
> | Rotate credentials | Per credential type, per the tested revocation procedure with its stated maximum detection-to-revocation time (R13.1, R8.5). The one-year `CLAUDE_CODE_OAUTH_TOKEN` is the longest-lived and the priority |
> | Return to known-good | Rebuild containers from the pinned digest and **discard the state volumes**, re-bootstrapping authentication. A contaminated volume cannot currently be distinguished from a clean one, so the documented path does not attempt to (R13.3, D16) |
>
> Define what constitutes an event versus an incident before go-live.

with:

> | Need | Action |
> |---|---|
> | Cut egress immediately | **`docker network disconnect sandboxed-agent-pod_egress-net sandboxed-agent-pod-egress-mediator-1`** — the live form, and the only one. A denylist entry is **not** a live action: the policy is compiled into the mediator image and there is no live reload (D4), so a denylist change is a recompile plus a rebuild. Detaching the mediator keeps DNS, policy and the audit writer running, so the blocked attempt is still recorded — which is the detection signal (R9.1) |
> | Isolate one agent, others keep running | Two forms, not interchangeable, both measured. **Disconnect** (`docker network disconnect sandboxed-agent-pod_<agent>-net sandboxed-agent-pod-<agent>-1`) keeps the container for forensics and keeps its recorder writing. **Stop** is durable and ends the recording — stop the agent's recorder *alongside* it, after the recorder drains. Per-agent networks (D2) make both native, not a special case (R13.2) |
> | Disable one MCP server or tool across all agents | Profile inventory change plus rebuild. **No live mechanism exists** — recorded, not solved (R13.2 partially unmet) |
> | Rotate credentials | Per credential type, per the tested revocation procedure with its stated maximum detection-to-revocation time (R13.1, R8.5). The one-year `CLAUDE_CODE_OAUTH_TOKEN` is the longest-lived and the priority. **Two measured qualifications:** `t1` is a replay that fails, never a console action; and for `codex` neither provider revocation nor rotation retires a captured OAuth set, so for that agent the containment is pod-side — isolate and discard the state volume at `t0`, *before* revoking |
> | Return to known-good | Rebuild containers from the pinned digest and **discard the state volumes**, re-bootstrapping authentication. A contaminated volume cannot currently be distinguished from a clean one, so the documented path does not attempt to (R13.3, D16). **Clear stray one-off `compose run` containers first** — `docker volume rm` refuses while any container references the volume, and `compose down` does not remove one-offs |
>
> Event and incident are defined in `docs/containment-runbook.md` § 1, operator-confirmed
> 2026-09-29 and reviewed again at feature close-out. The runbook is the operational form of this
> table; this table is the design statement.

**What changed and why.**

- **"Denylist entry at the mediator" was never a live action.** The resolved policy is baked into
  the image at build (D4, and 01.5 SF-4's compile-stage drift check makes it structural). Offering it
  as the first option for "cut egress immediately" points an operator at a rebuild during an
  incident. The live form is the network detach, measured at SF-3 phase C.
- **Isolation splits into two forms**, because both are measured and they trade differently:
  `disconnect` preserves the container and the recording; `stop` is durable and ends the recording.
  The old row said "stop that container" and lost the forensic option.
- **The recorder is named.** Stopping an agent without its recorder leaves a writer with nothing to
  read; stopping the recorder before it drains loses the tail of the evidence. Order matters and the
  old row did not carry it.
- **The credential row gains the two measured rules** that change what an operator must do, not just
  what they must know: replay-confirms-revocation, and the `codex` ordering.
- **The one-off container clearing** is in the recovery row because without it the discard step
  simply fails, with an error naming only a hex ID.
- **The "define event versus incident" instruction is discharged**, so it becomes a pointer rather
  than an open action.

**Not applied here.** This is proposed text for the design authority, exactly as 02.3 and 02.4 did
with their own architecture edits.

### 2. `REQUIREMENTS.md` — the R13.2 / T40 amendment

R13.2 as written asks for a targeted disable path. What exists is a profile edit plus a rebuild plus
recreation of every agent that loads the server; a stdio server has no enforcement point at all
(D18). The amendment records the tested path rather than a speculative one.

**ACCEPTED BY THE OPERATOR 2026-09-30, and APPLIED to `REQUIREMENTS.md` (lines 337 and 510) verbatim
as written below.** R13.2 is therefore **met** as amended. This feature supplied the tested text and
did not accept it; the operator did, after close-out. The milestone Definition of Done gates on acceptance,
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

**ACCEPTED 2026-09-30.** The operator accepted this text and it was applied verbatim to
`REQUIREMENTS.md:337` and `:510`; R13.2 is met as amended, and that DoD box is closed. **The R12.8
notice is still not lifted** — it waits on the remaining DoD item, applying the D21 amendment to
`docs/ARCHITECTURE_AND_DESIGN.md`.

---

## Criterion-to-evidence table (coverage)

Every numbered acceptance criterion maps to a harness phase, a drill, or a record section. Closed at
SF-7, 2026-09-30.

| Criterion | Evidence | Where | State |
|---|---|---|---|
| 1 — T26 tested revocation, every persisted type | Drills E1–E4, V1–V3, S1–S5 | This record, § T26 (SF-5, SF-6); inventory Table B | **MEASURED (SF-5 + SF-6)** — all twelve rows drilled 2026-09-30, each inside its stated maximum, each with identical service image IDs before and after (R8.5). **One stated GAP: V2's timed clock** (operator decision); its substantive question was measured. The inventory's Residual 4 is rewritten from "documented, not tested" to its measured state |
| 2 — T40 single-agent isolation | Phase B (both forms); MCP-disable exercise; amendment text | Phase B (SF-3); this record § T40, § Proposed edits 2 | **MEASURED (SF-3 + SF-4)** — both isolation forms, the MCP-disable exercise and the amendment text. **The amendment was ACCEPTED and APPLIED 2026-09-30** (`REQUIREMENTS.md:337`, `:510`), so R13.2 is met as amended |
| 3 — T41 return to known-good | Phase E (mechanical); full drill; per-store outcomes | Phase E (SF-4); this record § T41 | **MEASURED (SF-4)** — phase E, and the full drill performed 2026-09-30 against the real pod and the `main` pins, after one failed attempt recorded as three findings |
| 4 — R12.5 teardown | Phase D | Phase D (SF-3); this record § R12.5 | **MEASURED (SF-3)** |
| (Decision 3) — the pod-wide cut keeps the detection signal | Phase C | Phase C (SF-3); this record § The pod-wide cut | **MEASURED (SF-3)** |
| 5 — T37 authorization gate | Phase F, compile negatives and runtime checks | Phase F (SF-2); this record § T37 | **MEASURED (SF-2, recorded SF-7)** — phase F 35 passed, 0 failed; both negative-control variants run once and recorded (exit 2 accounting, exit 3 T37 refusal) |
| 6 — T44 ToS monitoring and the seam | R14.3 record for three routes; tabletop SIMULATION; seam inspection | `third-party-assessments.md` § R14.3; this record § T44 | **RECORDED (SF-7)** — three-route Route/Owner/Review-trigger table; cadence **quarterly + provider announcements** (operator-confirmed); tabletop labelled **SIMULATION** with the owner's decision (suspend the `agy` route) and the containment it triggers — recorded with the finding that **no written re-review checklist exists**, so the decision was made against the trigger list and the runbook rather than a checklist; seam inspected on the built image (ICAP and eCAP compiled in; TLS termination is the blocker and it is a D4 decision) |
| 7 — the runbook | Shipped, with event/incident defined before go-live; README links it | `docs/containment-runbook.md` (SF-1 draft, SF-7 final) | **FINAL (SF-7)** — every command is a measured form; the incident list was reviewed again at close-out and neither added to nor struck; § 6's drill cadence set to **quarterly, with the R14.3 review**; `README.md` § "Containment and response (02.5)" links it |
| 8 — records and proposed edits | This record; the two proposed edits above | This record (SF-7) | **BOTH WRITTEN** — edit 2 (R13.2/T40) from the exercised path (SF-4); edit 1 (the architecture runbook table) from the measured forms (SF-7). Neither applied, by design |
| 9 — the R12.8 notice is not lifted here | Stated, not acted on | This record, § Proposed edits 2 | **STATED (SF-1, unchanged)** — not lifted by this feature. The R13.2/T40 half of its condition is now met (accepted and applied 2026-09-30); the D21 amendment's application to `docs/ARCHITECTURE_AND_DESIGN.md` is the remaining one, and lifting the notice is `/milestone`'s |
| **MUST REACH USER DOCUMENTATION (D-1 … D-8)** | Eight operator-facing consequences written into `README.md` and the runbook | § MUST REACH USER DOCUMENTATION → "Where each item was written" | **ALL EIGHT WRITTEN (SF-7)** — D-1 README + runbook § 3.4/§ 4; D-2 README + runbook § 3.4/§ 4; D-3 README (MCP section, with the exact refusal text) + runbook § 3.3/§ 5.1; D-4 README + runbook § 5.1 step 6; D-5 README (twice) + runbook § 3.4; D-6 README + this record's Method preamble; D-7 README `oauth-mount` paragraph + inventory V3 row; D-8 runbook § 3.4 |

### Open items this feature does NOT close

Stated here so close-out is not read as "everything is finished".

1. **R13.2 is MET as amended** — the operator accepted the T40 amendment text (§ Proposed edits 2)
   on 2026-09-30 and it was applied verbatim to `REQUIREMENTS.md:337` and `:510`. The **R12.8 notice is
   still not lifted** (criterion 9): its other condition is the D21 amendment's application to
   `docs/ARCHITECTURE_AND_DESIGN.md`, and the lift itself is the milestone's act, not this
   feature's.
2. **The one-year `CLAUDE_CODE_OAUTH_TOKEN` in `references/.env_keys` is still live** — replayed
   2026-09-30T22:04:35Z, HTTP 200. The operator will revoke it out of session; the closing evidence
   is the next replay that returns 401 (§ Drill E4, "SF-7 close-out").
3. **One proposed edit remains unapplied** — `ARCHITECTURE_AND_DESIGN.md`'s runbook table
   (§ Proposed edits 1). Applying it is the design authority's. The R13.2/T40 edit was accepted and
   applied on 2026-09-30.
4. **V2's timed row is a GAP**, by operator decision.
5. **Detection stays pull-based** (R9.6 remains MAY). Nothing here bounds compromise to detection —
   only detection to revocation.
6. **The T44 tabletop surfaced two gaps, the first about its own premise.** There is **no written
   re-review checklist** — criterion 6 assumed one, and the decision was made against the route
   table's triggers and the runbook's actions instead, which is enough to decide and not the same
   thing. And neither the triggers nor the runbook carries a **resumption** criterion: both say when
   to suspend a route, neither says what would let one restart. Recorded in
   `third-party-assessments.md`, not fixed here.

### Close-out regression — the full composite, harness by harness

Run on the committed tree, 2026-09-30. Run **one harness at a time**: an earlier combined `&&` run
was killed by the OS for memory, which is an environment fact, not a failure.

| Harness | Result | rc |
|---|---|---|
| `verify-pack-composition.sh` | 109 passed, 0 failed | 0 |
| `verify-pod-topology.sh` | 63 passed, 0 failed | 0 |
| `verify-egress-mediator.sh` | 101 passed, 0 failed | 0 |
| `verify-audit-completeness.sh` | 76 passed, 0 failed | 0 |
| `verify-tool-packs.sh` | 41 passed, 0 failed | 0 |
| `verify-mcp-inventory.sh` | 44 passed, 0 failed | 0 |
| `validate-boundary.sh` (`default terraform kubernetes github`) | 416 passed, 0 failed | 0 |
| `verify-reproducibility.sh` | 25 passed, 0 failed | 0 |
| **`verify-containment.sh`** | **169 passed, 0 failed** — phase A fully green | 0 |
| `scripts/lint-policy.sh` | OK | 0 |

Every count equals its SF-2 baseline except containment, which moved from 167 passed / 2 failed to
**169 passed / 0 failed** — the two R14.3 checks, closed by SF-7's own writing.
