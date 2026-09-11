# Proxy Controls Verification — 01.3 SF-6

**Feature:** 01.3 Egress mediator, SF-6
**Date:** 2026-09-07
**Outcome:** The three listeners and the three controls are built and measured. Three findings
change what later sub-features must do, and one of them **corrects SF-1**.

## Method

A throwaway Compose fixture under `.build-scratch/sf6/` (git-ignored), on Docker Desktop for
macOS 26 / Apple silicon, Docker Engine 28.3.2, running the **shipped** mediator image
(`sandboxed-agent/mediator:local`, `squid-openssl 6.13-2+deb13u2`) with `images/mediator/entrypoint.sh`
and `mediator/config/` bind-mounted so the render could be iterated without a rebuild. Hardening
was the shipped hardening: `user 13:13`, `cap_drop: ALL`, `read_only: true`,
`ip_unprivileged_port_start=0`, `ip_forward=0`.

Three `internal: true` agent networks (`172.33.10/20/30.0/24`) and one external network
(`172.33.40.0/24`) carrying an nginx origin with five names on one address, a neighbour container
one address away, a controlled authoritative resolver, and a probe on each network plus one on the
external network. **Two distinct CAs** — a fixture mediator CA anchoring the proxy hops and signing
all three listener certificates, and a separate origin CA — so "whose certificate did the client
see" is an observable.

Certificates carry `iPAddress` SANs and **every TLS assertion below ran with certificate
verification enabled at the client** (`--proxy-cacert`, `--cacert`, no `-k`).

## Listener surface (criterion 6, criterion 1)

Five listeners for three agents, bound as rendered:

```
Accepting HTTPS Socket connections at conn3 local=172.33.10.2:3128   listening port: claude
Accepting SSL bumped HTTP Socket connections at conn5 local=127.0.0.1:3200   listening port: claudein
Accepting SSL bumped HTTP Socket connections at conn7 local=172.33.20.2:3128   listening port: codex
Accepting HTTPS Socket connections at conn9 local=172.33.30.2:3128   listening port: agy
Accepting SSL bumped HTTP Socket connections at conn11 local=127.0.0.1:3201   listening port: agyin
```

Every agent-facing listener binds that agent's **static address**, never `0.0.0.0`; the two inner
cascade listeners bind loopback, which criterion 1 already permits. From the probe on the external
network, both the mediator's `egress-net` address and an agent network address are unreachable on
3128.

## Control results

| # | Property | Result |
|---|---|---|
| 1a | Per-agent allowlist, not a union | **PASS** |
| 1b | SNI equals the CONNECT host (domain fronting refused) | **PASS**, all three paths |
| 2 | `deny_fqdns` and `deny_cidrs`, deny wins | **PASS**, including the `/32` neighbour discrimination — with both names allowlisted, see below |
| 3a | Per-agent concurrency ceiling | **PASS**, and it calibrates **1:1** — see below |
| 3b | Per-agent byte-rate ceiling | **PASS** — 67160 B/s against a 65536 B/s pool over a spliced tunnel |
| — | CONNECT-only method restriction | **PASS** — a plain `GET` through the proxy returns 403 |
| — | Splice, no destination decryption | **PASS** — the client sees `CN=sf6-origin`, `Verify return code: 0 (ok)`; the mediator CA never appears |
| — | No resolution of a non-allowlisted host | **PASS** — see the ordering finding |

### 1a — per-agent allowlist is not a union

```
pclaude  allowed.test    expect ALLOW  200
pclaude  agy-only.test   expect deny   000 (curl 56)
pagy     agy-only.test   expect ALLOW  200
pagy     allowed.test    expect deny   000 (curl 56)
pcodex   allowed.test    expect ALLOW  200
pcodex   agy-only.test   expect deny   000 (curl 60)
```

### 1b — domain fronting refused on all three paths

CONNECT an allowlisted host while sending a different SNI. All three refused (curl exit 35), and
the audit line records the mismatch rather than inferring it:

```
agent=agy   port=127.0.0.1:3201   url=agy-only.test:443 status=403 squid=TCP_DENIED sni="allowed.test"
agent=codex port=172.33.20.2:3128 url=allowed.test:443  status=403 squid=TCP_DENIED sni="agy-only.test"
```

The `claude` case fronted one **allowlisted** name with another (`collector.test` SNI, `allowed.test`
CONNECT) and was still refused — equality, not membership.

### 2 — deny wins, and the `/32` discriminates

`denied.test` shares the origin's address with `allowed.test` and is refused, which is the
T6/CDN-rotation shape: same address, different name, opposite verdict, decided per connection at L7
rather than from an IP snapshot.

**The address deny needs the name to be allowlisted, or the test proves nothing.** The first attempt
at this measurement was wrong and is recorded rather than quietly replaced: it aimed a CONNECT at
`neighbour.test` while that name was **not** in `claude`'s allowlist, so the refusal came from the
host gate (control 1a) and `deny_cidrs` was never reached at all. The audit line gave it away — the
verdict was on the **front** listener (`172.33.10.2:3128`), which carries no `dst` rule.

Re-run with `neighbour.test` **allowlisted for `claude`**, so it passes the gate and the only thing
left to refuse it is the post-resolution address deny — which is exactly D5's rebinding/CDN case and
the whole reason control 2 exists:

```
pclaude allowed.test    (-> 172.33.40.10, not denied)   200
pclaude neighbour.test  (-> 172.33.40.9,  deny /32)     000 (curl 35)
```

and the verdict lands on the **inner** listener, which is where the connection is actually made:

```
agent=claude port=127.0.0.1:3200   url=neighbour.test:443 status=200 squid=TCP_DENIED  sni="neighbour.test"
agent=claude port=172.33.10.2:3128 url=neighbour.test:443 status=200 squid=TCP_TUNNEL  sni="-"
```

Both names are allowlisted, both resolve to adjacent addresses on the same origin image, one is
refused and the other is not. That is the `/32` discrimination criterion 10 asks for.

**T7 (`169.254.169.254`) is refused by the host gate, not by `deny_cidrs`** — an IP literal matches
no `dstdomain` entry, so it never reaches the address deny. It is refused either way
(`TCP_DENIED_ABORTED`), and refused *earlier*, which is the better outcome; recorded here so the
control that actually fired is not mis-attributed.

---

## Finding 1 — rule ORDER is a control, and SF-1's verified configuration had it wrong

SF-1's `squid.conf` evaluates `http_access deny deny_cidrs` **before** any allowlist check.
`deny_cidrs` is a `dst` ACL, which forces Squid to resolve the CONNECT host. Under that order
`CONNECT <attacker-chosen-name>:443` is **resolved by the mediator** — through Squid's own upstream,
on no audit line, bypassing the pod resolver's per-agent allowlist entirely — and only then refused.
That is the DNS exfiltration channel criterion 4 exists to close, reopened one layer up at the proxy.

SF-6 therefore renders the per-agent `dstdomain` gate first, and the ordering was **measured** rather
than reasoned about. With the mediator's upstream pointed at the controlled authoritative resolver:

| CONNECT target | Allowlisted for `codex`? | Queries seen at the controlled resolver |
|---|---|---|
| `nope.test` | no | **0** |
| `allowed.test` | yes | **2** |

The allowlisted case is what makes the absence meaningful: the observation path demonstrably works,
so zero is a real zero rather than a broken test.

## Finding 1a — `dstdomain` reverse lookups leaked PTR queries; closed with `-n`

Found while re-testing control 2, and it is the same leak class as finding 1 one query type over.
Squid's `dstdomain` ACL, given a destination that is a bare IP literal, issues a **reverse (PTR)
lookup** through its own upstream purely to obtain a name to compare. Measured at the controlled
resolver:

```
172.33.40.2 254.169.254.169.in-addr.arpa. PTR IN      <- from CONNECT 169.254.169.254:443
172.33.40.2 9.40.33.172.in-addr.arpa. PTR IN          <- from CONNECT 172.33.40.9:443
```

Mediator-originated, agent-triggered, unaudited DNS egress — on a destination the policy was in the
middle of **refusing**. The same shape as the `dnsdist` security-poll egress SF-5 closed.

Every rendered `dstdomain` ACL now carries `-n`, which disables the lookup: an IP literal matches no
name and falls through to default-deny, resolving nothing. Re-measured after the change:

| CONNECT target | `in-addr.arpa` queries before | after |
|---|---|---|
| `169.254.169.254:443` and `172.33.40.9:443` | 4 | **0** |

Both are still refused, and the name-based controls are unchanged (`allowed.test` 200;
`neighbour.test`, `denied.test` and `agy-only.test` all refused).

## Finding 2 — the pre-CONNECT 403 exists on two of three listeners, not none and not all

SF-1's P5 concluded that a body-bearing refusal is unreachable, and Deviation 2 was recorded against
it. Measured with the SF-6 rule order, the picture is more precise, and the difference is the
**peek**, not the agent:

*`codex`'s peeking listener — no pre-CONNECT refusal:*
```
$ printf 'CONNECT nope.test:443 HTTP/1.1\r\nHost: nope.test:443\r\n\r\n' | nc 172.33.20.2 3128
HTTP/1.1 200 Connection established
```
audit: `url=nope.test:443 status=200 squid=TCP_DENIED_ABORTED`

*`claude`'s front listener, inside the proxy-hop TLS — the 403 IS delivered:*
```
HTTP/1.1 403 Forbidden
Server: squid
Content-Type: text/html;charset=utf-8
```

A listener that peeks must accept the CONNECT before it can see the ClientHello, so no rule ordering
reaches it — that half of SF-1's P5 stands. But the TLS-fronted agents' **front** listener does not
peek, so it decides from the CONNECT line alone and returns a real 403 **inside a TLS session whose
certificate the agent trusts and validates**. The body reaches `claude` and `agy`.

**This is SF-7's input and it is not resolved here.** Interface Contract 6 as amended describes a
pre-CONNECT 403 path without qualifying it per listener; the measured surface is:

| Agent | Pre-CONNECT verdict | Post-ClientHello verdict |
|---|---|---|
| `claude` | **403 with body**, delivered inside the trusted proxy-hop TLS | terminate, no body |
| `agy` | **403 with body**, same | terminate, no body |
| `codex` | CONNECT accepted first — **no body**, `TCP_DENIED_ABORTED` | terminate, no body |

The operator-facing audit record remains the authoritative denial surface for every case, which is
what Interface Contract 6 already says. What changes is that the client half is available to two
agents and not to the third, and SF-7 should build the surface knowing which.

## Finding 3 — `maxconn` calibrates 1:1; SF-1's double-count caveat does not reproduce

SF-1 recorded that "under peek, one client transaction produces more than one accounted connection,
so the effective ceiling is not the literal number in the directive", and asked SF-6 to calibrate
empirically. Measured with `max_concurrent: 2`, connections opened 0.4s apart and held open:

| Layer | n=1 | n=2 | n=3 |
|---|---|---|---|
| `claude` front (`https_port`, no peek) | `200` | `200 200` | `200 200 000` |
| `codex` single listener (`http_port ssl-bump`, peeks) | `200` | `200 200` | `200 200 000` |

**Nominal equals effective on both layer types**, peeking included. SF-8 should assert the nominal
value; no calibration factor is needed. SF-1's caveat is recorded as not reproducing under this rule
shape rather than being quietly dropped.

**One behavioural property SF-8 must build its assertion around.** `maxconn` is a threshold on the
client's *current* connection count, not a queue. When five connections are opened simultaneously and
all five exceed the ceiling, **all five are refused** — not two admitted and three refused:

```
p1=000 p5=000 p3=000 p4=000 p2=000
```

The assertion that distinguishes a working ceiling from a broken one is therefore "the N+1th
connection is refused while the first N are not", with staggered opens — not "N of M succeed" from a
simultaneous burst, which passes for a mediator that refuses everything.

## Finding 4 — a peeking listener without `tls-cert=` silently stops peeking

The reason Deviation 5 exists. `http_port ... ssl-bump generate-host-certificates=off` with no
`tls-cert=` **parses cleanly** and then:

```
Will not bump SSL at http_port 0.0.0.0:3128 due to TLS initialization failure.
1788791038.100 url=example.com:443 status=503 squid=TCP_TUNNEL sni="-"
```

`sni="-"` on every line — the SNI control is not running — and even an allowlisted request fails
(`curl: (56) CONNECT tunnel failed, response 503`). This is the same silent-failure class SF-1 found
in the SNI fallback: a configuration that parses and looks correct while enforcing nothing. It is
why `codex`'s listener carries a bumping certificate, and why SF-8's fronting assertion — not its
happy-path assertion — is the one that would catch a regression here.

## Carried forward

| Finding | Lands in |
|---|---|
| Allowlist gate must precede any `dst` ACL, or the mediator resolves attacker-chosen names | **shipped** in `mediator/config/proxy.conf.tmpl`; SF-8 asserts the absence of the upstream query |
| `dstdomain` must carry `-n`, or an IP-literal CONNECT leaks a PTR query | **shipped**; SF-8 should assert the absence of `in-addr.arpa` at the T4 fixture |
| A `deny_cidrs` assertion is only meaningful when the name is **allowlisted** — otherwise the host gate refuses first and control 2 is never reached | **SF-8** (`policy/resolved/test-fixtures.yaml` must allowlist the denied-address name) |
| `deny_cidrs` verdicts are decided **post-accept on every agent** (the inner listener peeks), so Interface Contract 6's pre-CONNECT 403 path covers the host gate and `deny_fqdns` only | **SF-7** |
| Pre-CONNECT 403 reaches `claude`/`agy` and not `codex` | **SF-7** (denial surface), **SF-8** (Phase C assertions differ per listener) |
| `maxconn` nominal == effective; assert the N+1th with staggered opens | **SF-8** |
| Front line reports `TCP_TUNNEL` while the inner line reports the verdict | **SF-7** (audit writer must take the inner verdict) — unchanged from SF-1's P4 caveat, re-observed here |
| `cache_peer` cold start: the first request through the cascade after a restart fails | **SF-7** (stage-2 self-check warms it), **SF-8** (not a control result) — re-observed here as `curl 56`, not SF-1's `500` |
| `connections_per_minute` has no mechanism | **dropped** — feature plan Deviation 4 |
| `codex` needs a bumping certificate | **shipped** — feature plan Deviation 5 |
