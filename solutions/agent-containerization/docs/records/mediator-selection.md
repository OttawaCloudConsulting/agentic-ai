# Mediator Implementation Selection — 01.3 SF-1

**Feature:** 01.3 Egress mediator, SF-1
**Date:** 2026-09-06
**Outcome:** **Squid selected**, with two named architectural consequences (P5, P6) that the
feature plan did not anticipate and that change what SF-6 builds. `iron-proxy` was not built
against; the reasoning for not falling back to it is recorded under *Selection decision* below.

## Method

A throwaway Compose fixture under `.build-scratch/sf1/` (git-ignored), on Docker Desktop for
macOS 26 / Apple silicon, `linux/aarch64`, Docker Engine 28.3.2:

- `agent-net` (`internal: true`) carrying a probe container, and `egress-net` carrying an nginx
  origin. The Squid container is the only member of both — the same isolation mechanism 01.1 SF-2
  used, and the same one 01.2 built the pod on.
- Origin serves `allowed.test`, `denied.test`, `collector.test`, `agy-only.test`, `ws.test` as
  network aliases on one address, with a TLS certificate from a **throwaway origin CA that is
  distinct from the mediator CA** — so "whose certificate did the client see" is an observable,
  which is what P6's splice assertion rests on.
- Probe container: `curl 8.14.1`, `openssl` 3.5.x.
- Five agent-facing listeners plus two loopback listeners were exercised; the exact `squid.conf`
  that produced these results is reproduced verbatim under *Verified configuration* below, since
  it — not a script — is SF-6's actual input.

**Not shipped code.** The plan specifies SF-1 produces "a record and a decision, not shipped
code", and the Files to Create/Modify table lists no harness. The fixture was left in
`.build-scratch/`. Reproducibility is carried by the verbatim configuration and the raw command
output quoted per property below.

## Version pin (plan requirement: "records the exact proxy version every property was verified against")

| Item | Value |
|---|---|
| Package | `squid-openssl` |
| Version | `6.13-2+deb13u2` |
| Squid version string | `Squid Cache: Version 6.13` |
| TLS library | OpenSSL 3.5.7 (9 Jun 2026) |
| Base image | `debian:trixie-slim` @ `sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132` |
| Architecture | `aarch64-linux-gnu` |
| Build info | `Debian GNU/Linux 13 (trixie)` |

Relevant configure options confirmed present in this build:
`--with-openssl`, `--enable-ssl-crtd`, `--enable-delay-pools`,
`--enable-auth-basic=DB,fake,getpwnam,LDAP,NCSA,PAM,POP3,RADIUS,SASL,SMB`,
`--enable-external-acl-helpers=...`, `--with-default-user=proxy`.

**SF-4 must pin both the package version and the base image digest.** Debian point releases
supersede in place — the bookworm suite was observed serving `5.7-2+deb12u5` from `bookworm/main`
and `5.7-2+deb12u6` from `bookworm-security/main` in the same `apt-cache policy` output. An
unpinned `apt-get install squid-openssl` therefore silently moves off the build these properties
were verified against, and the directives they rest on are version-scoped.

Note: this build ships **no** `squid.conf.documented`. `/usr/share/doc/squid-common/` contains only
`copyright`. Configuration correctness was established with `squid -k parse -f ...`, which fails
hard on unknown directives, rather than against on-image documentation.

## Property results

| # | Property | Verdict |
|---|---|---|
| P1 | Client-certificate verification available per listener, subject reachable by policy and log | **PASS** (required-mode). **Optional-mode (`DELAYED_AUTH`) FAILED** — handed to 01.6, and **closed there 2026-09-09 by design, not by fix**: the mechanism has no consumer in this pod (see P1 below) |
| P2 | Post-resolution deny on the address actually connected to | **PASS** |
| P3 | Per-client concurrency, connection-rate and byte-rate ceilings | **PARTIAL** — concurrency PASS, byte rate PASS, **connection rate has no native mechanism** |
| P4 | Agent identity on every access-log line, allow and deny alike, derived from the listener | **PASS**, with a cascade caveat (see P7) |
| P5 | Immediate, body-bearing refusal naming the destination | **FAIL** on any listener that peeks. Structural, not configurable |
| P6 | SNI observable and comparable to the CONNECT host without decrypting | **PASS only via a self-cascade**. Direct combination with proxy-hop TLS is rejected by Squid |
| P7 | Heterogeneous listeners in one instance, each selecting independent per-agent policy | **PASS**, and it requires the same self-cascade P6 requires |
| P8 | Per-client policy selection from a proxy credential | **PASS** on the plain transport, with the FIXTURE helper (`basic_fake_auth`) |
| P9 | The same, on `https_port`, with the REAL helper (`basic_ncsa_auth`) | **PASS** — measured 2026-09-10 (01.6 SF-3). Both transports, real hashes; refusal is **407**, never 403 |

---

### P7 — heterogeneous listeners and per-agent policy selection: PASS (with cascade)

Three agent-facing listeners run concurrently in one Squid instance, each selecting an independent
per-agent allowlist keyed on `myportname` — not on the client address, which matters because SF-4
may separate the listeners by address, by port, or by both, and `myportname` is invariant to that
choice.

Final matrix, all from the probe on `agent-net`:

```
claude/3128 allowed.test    exp allow: 200 (exit=0)
claude/3128 agy-only.test   exp deny : 000 (exit=35)
agy/3130    agy-only.test   exp allow: 200 (exit=0)
agy/3130    allowed.test    exp deny : 000 (exit=35)
codex/3129  allowed.test    exp allow: 200 (exit=0)
codex/3129  agy-only.test   exp deny : 000 (exit=60)
```

The allowlists are genuinely per-agent and not a union: `agy-only.test` is reachable from the `agy`
listener and refused from `claude` and `codex`; `allowed.test` is the converse.

**The `https_port` trap, and why the cascade exists.** Squid's `http_port ... tls-cert=` does *not*
terminate TLS from the client — the `tls-cert=` there is the bumping certificate. Verified: with
`http_port 3128 ... tls-cert=`, a raw TLS probe fails and the port works as a *plain* proxy.

```
--- 3128 as PLAIN proxy ---
200
--- 3128 raw TLS probe ---
error:0A00010B:SSL routines:tls_validate_record_header:wrong version number
```

Proxy-hop TLS requires `https_port`. But `https_port` refuses `ssl-bump`:

```
FATAL: ssl-bump on https_port requires tproxy/intercept which is missing.
FATAL: Bungled squid.conf line 9: https_port 0.0.0.0:3128 name=claude ... ssl-bump ...
```

So in Squid 6.13 **one listener cannot both terminate the proxy-hop TLS and peek the client's
ClientHello.** The `claude` and `agy` listeners need both. The resolution verified here is a
**self-cascade**: the agent-facing `https_port` terminates the proxy hop and forwards the CONNECT to
a **loopback** `http_port ... ssl-bump` listener, one per fronted agent, via `cache_peer` +
`never_direct`. Identity survives the hop because each agent gets its own inner port name.

This is a topology decision, not a tuning detail, and it belongs to SF-6.

### P6 — SNI observable, comparable, without decryption: PASS via the cascade; **silent failure without it**

With peek + splice, the observed certificate is the origin's own, not the mediator's — no
decryption:

```
=== plain listener 3129: CONNECT allowed.test, SNI allowed.test (control) ===
depth=0 CN=sf1-origin
verify error:num=20:unable to get local issuer certificate
CONNECTION ESTABLISHED
```

`CN=sf1-origin` is the origin CA's leaf. The mediator CA never appears, which is the splice
assertion criterion 5 needs.

**Domain fronting is refused on a peeking listener.** CONNECT to `allowed.test` (allowlisted) while
sending SNI `denied.test`:

```
=== plain listener 3129 (peek+splice): CONNECT allowed.test, SNI denied.test ===
error:0A00010B:SSL routines:tls_validate_record_header:wrong version number
```
— Squid refused in plaintext before the tunnel. The corresponding audit line:
```
port=127.0.0.1:3228 method=CONNECT url=allowed.test:443 status=403 squid=TCP_DENIED sni="denied.test"
```

**The silent-failure mode, and it is the most important single finding in this record.** Squid 6.13
has **no `ssl::server_name_mismatch` ACL** — `acl x ssl::server_name_mismatch` is rejected at parse
time (`invalid ACL type`). The available predicate is `ssl::server_name --client-requested <name>`.
On a listener that does **not** peek, that ACL still matches — by falling back to the CONNECT
hostname. The identical fronting request through a non-peeking `https_port` **succeeded**:

```
=== TLS listener 3131 (https_port, no ssl-bump): CONNECT allowed.test, SNI denied.test ===
200
```

A configuration that looks like it enforces SNI, parses cleanly, and passes an allowlist test, is
therefore capable of enforcing nothing at all. R5.5 explicitly bars an IP-set snapshot; this is the
same class of hole one layer up. **SF-6 and SF-8 must assert the fronting case, not the happy
case** — the happy case passes either way.

**Strict SNI-equals-CONNECT-host is expressible only by generated per-name pairing.** Since there is
no mismatch predicate, equality is written as one rule per allowlisted name, pairing the host ACL
and the SNI ACL on the same `http_access` line:

```
acl h_allowed dstdomain allowed.test
acl s_allowed ssl::server_name --client-requested allowed.test
http_access allow p_claudein h_allowed s_allowed
```

This is compatible with SC-6 (the configuration is generated from the resolved policy, never
hand-edited) but it does fix the compiler's output shape: N allowlist entries produce N paired
ACLs and N access lines per agent, not one `dstdomain` list.

### P2 — post-resolution deny on the address actually connected to: PASS

`acl deny_cidrs dst 169.254.169.254/32 172.18.0.9/32`, evaluated before any allow rule.

```
P2 metadata 169.254.169.254                       : denied
P2 neighbour 172.18.0.2 (origin, NOT in deny /32) : 200:0
```

The `/32` discrimination criterion 10 asks for holds: `172.18.0.9/32` is denied and the adjacent
`172.18.0.2` — the actual origin — is not. Deny is evaluated on the resolved address Squid connects
to, and `deny` precedes `allow` in the rule order, so deny wins.

### P3 — per-client ceilings: PARTIAL

**Byte rate — PASS, and better than expected.** `delay_pools` shapes **spliced CONNECT tunnels**,
which was the open question: a 64 KB/s class-1 pool bound to the `codex` listener, against a 20 MB
object:

```
speed=69564 B/s size=835336
```

69.5 KB/s against a 64 KB/s pool over a spliced tunnel. The pool is server→client; the
client→server direction is not shaped by this mechanism and SF-6 should not claim it is.

**Concurrency — PASS, with a calibration caveat.** `acl maxconn_codex maxconn 2`:

```
single request after drain: 200:0
3 parallel 20MB fetches: p1=35 p2=35 p3=60
```
with the audit lines showing `status=403 squid=TCP_DENIED`. The ceiling fires and is logged. The
caveat: under peek, one client transaction produces more than one accounted connection, so the
effective ceiling is not the literal number in the directive. **SF-6 must calibrate the threshold
empirically and SF-8 must assert the calibrated value**, not the nominal one.

**Connection rate — NO native mechanism.** Squid 6.13 has no per-client connection-rate directive.
`maxconn` bounds concurrency, `delay_pools` bounds bytes; neither bounds connections per unit time.
Options, neither exercised here: an `external_acl_type` token-bucket helper (this build has
`--enable-external-acl-helpers`), or accepting the gap. **This is a recorded gap against D5
control 3**, which names all three ceilings. It compounds the bound the plan already states — under
D4's splice the mediator counts connections and bytes, never requests — and SF-6 should not present
control 3 as complete.

### P4 — agent identity on every log line, allow and deny alike: PASS

`acl tag_<agent> annotate_transaction agent=<agent>` bound to each listener by `myportname` on a
never-matching rule (`http_access deny p_claude tag_claude !all`), read back with `%note{agent}`:

```
agent=codex  lport=3129 url=allowed.test:443  status=200 squid=TCP_TUNNEL
agent=codex  lport=3129 url=agy-only.test:443 status=200 squid=TCP_DENIED
agent=claude lport=3228 url=agy-only.test:443 status=200 squid=TCP_DENIED
agent=claude lport=3128 url=allowed.test:443  status=200 squid=TCP_TUNNEL
```

Identity is present on allow and deny alike, derived from the listener, with no client credential
in play — which is exactly the network-derived identity this feature is built on, and `%un` and
`%ssl::>cert_subject` stay empty without contradicting it. `%ssl::>cert_subject` does populate when
a client certificate is present (P1), so the same log format serves 01.6 unchanged.

**Cascade caveat, and it is an audit-correctness problem.** On the fronted listeners the *front*
line reports the tunnel, and the *inner* line reports the verdict. A denied request produces:

```
port=127.0.0.1:3228 ... status=403 squid=TCP_DENIED   <- the real verdict
port=172.19.0.3:3128 ... status=200 squid=TCP_TUNNEL  <- the front, reporting success
```

Taken alone the front line says a denied connection succeeded. **SF-7's audit writer must take the
verdict from the inner listener** and either suppress the front line or mark it as a hop, or the
audit log R9.1 requires will misreport denials for two of three agents.

### P5 — immediate, body-bearing refusal naming the destination: FAIL

This is structural and no configuration setting reaches it.

A peeking listener must accept the CONNECT before it can see the ClientHello, so it answers
`200 Connection established` first:

```
$ printf 'CONNECT agy-only.test:443 HTTP/1.1\r\nHost: agy-only.test:443\r\n\r\n' | nc squid 3129
HTTP/1.1 200 Connection established
```

The refusal therefore has to be delivered *inside* the TLS session the client then starts. With
`generate-host-certificates=off` — required, since minting per-destination certificates is the
MITM capability D4 and criterion 5 forbid — Squid presents its static listener certificate, whose
SAN cannot match the destination:

```
* Server certificate:
*  subject: CN=sf1-codex-listener
*  subjectAltName does not match hostname agy-only.test
* SSL: no alternative certificate subject name matches target hostname 'agy-only.test'
```

Any client that verifies certificates — which is every client this pod runs — aborts at that point
and **never sees the 403 body**, regardless of whether it trusts the mediator CA. The agent sees a
TLS error. `deny_info` with a custom template was wired and confirmed reachable, but its body only
reaches non-verifying or plaintext callers.

**This is not a Squid limitation; it follows from splicing.** A proxy that refuses to decrypt cannot
deliver an application-layer error inside an encrypted session it declines to terminate. `iron-proxy`
would fail identically for the same reason. The only way to deliver the body is to mint a matching
certificate, i.e. to become an MITM — the thing the architecture rules out.

Consequences, all of which land outside SF-1:

- **Criterion 5's "returns HTTP 403 with a body naming the destination"** is achievable only on the
  non-peeking path (a plain `GET` to the proxy, which the CONNECT-only restriction refuses anyway).
  The plan's Approach section states the agent "sees an error it can act on rather than a hang" —
  it sees a TLS error, which is actionable but is not the 403 the plan describes.
- **R9.3, R9.4 and R12.2's operator-facing denial surface** must be served by the audit log and the
  mediator's own denial surface (Interface Contract 6), not by the client-visible response.
- **Interface Contract 6 needs re-reading against this** before SF-7 builds it.

Surfaced for a plan decision rather than silently reinterpreted.

### P1 — client-certificate verification available per listener: PASS required-mode, FAIL optional-mode

Required mode, `https_port ... clientca=/pki/mediator-ca.crt`:

```
no client cert   : 000 (exit=56)   <- refused at the TLS handshake
with client cert : 200 (exit=0)
```

The allow rule required `acl cert_claude user_cert CN sf1-claude-client`, so the subject is
reachable by policy, and it is reachable by the log:

```
subj="/CN=sf1-claude-client"
```

**Default `clientca=` semantics are required-at-handshake, not optional.** A client presenting
nothing is refused during TLS, before any ACL runs — so there is no ACL-level refusal and no access
log line naming the agent. That matters to 01.6: `claude` can present a certificate, `agy` cannot,
and a listener configured this way gives `agy` no route at all rather than a logged refusal.

**The optional-verification mechanism did not work.** `sslflags=DELAYED_AUTH`, which is supposed to
defer the client-certificate check to ACL evaluation, refused the connection with **and** without a
client certificate:

```
DELAYED_AUTH, no client cert   : 000 (exit=56)
DELAYED_AUTH, with client cert : 000 (exit=56)
```

Parse was clean; the failure is at runtime. **Recorded as an open gap for 01.6**, not chased here —
01.3 ships with client-certificate verification off on all three listeners, so nothing in this
feature depends on it. 01.6 must resolve it before it can offer per-listener optional verification,
and if it cannot, 01.6's choice narrows to required-mode on the `claude` listener only.

> **Gap closed 2026-09-09 (Feature 01.6 SF-1, Decision 1) — closed by design, not by fix.**
> The `DELAYED_AUTH` runtime failure above is **not** resolved, and 01.6 does not chase it. Optional
> mode exists to let one listener serve both a cert-bearing and a cert-less client. **That case does
> not occur in this pod.** D2 gives every agent its own listener on its own `internal: true` network,
> so the `claude` front listener serves exactly one client and that client can present a certificate
> (criterion 5); the `agy` listener stays server-auth-only and the `codex` listener stays plain HTTP
> CONNECT, and neither needs optional mode either. The mechanism has **no consumer**, so chasing a
> Squid runtime bug to enable it is work with no requirement behind it.
>
> 01.6 therefore ships `clientca=` in **required** mode on the `claude` **front** `https_port` alone,
> which is the configuration measured PASS above. The two named consequences are accepted rather than
> mitigated: a cert-less client is refused at the TLS handshake and produces **no audit line at all**
> (01.6 SF-4 records this in `mediator/identity/README.md` and in the R12.2 troubleshooting section
> of `README.md`, because silence there is a diagnostic signal rather than an absence of one), and
> required mode is safe only because the listener has a single client — it would be unsafe on a
> shared one.
>
> The paragraph above's fallback — *"if it cannot, 01.6's choice narrows to required-mode on the
> `claude` listener only"* — is the outcome, reached by choice rather than by defeat. If a future
> feature ever needs one listener to serve both a cert-bearing and a cert-less client, this gap
> reopens and must be re-measured on the Squid build in force then.

### P8 — per-client policy selection from a proxy credential: PASS

`auth_param basic program /usr/lib/squid/basic_fake_auth` with `acl u_claude proxy_auth claudeuser`
on a plain `http_port` — the transport shape `codex` is restricted to:

```
no credential : 000 (exit=56)
wrong user    : 000 (exit=56)
right user    : 200 (exit=0)
```

Policy keys off the credential, and `%un` carries it to the log. The proxy half of R8.8's fallback
path exists in this implementation. The agent half — whether `codex` or `agy` will actually send
one — is 01.6's, per the split recorded in the plan's Approach section.

`basic_fake_auth` accepts any password and is a fixture helper only; a real deployment needs a real
helper or an `external_acl_type`.

### P9 — proxy-credential policy selection on `https_port`, with the real helper: PASS

**Measured 2026-09-10, 01.6 SF-3, against the shipped mediator image** (`sandboxed-agent/mediator:local`,
`squid-openssl 6.13-2+deb13u2`, Squid Cache: Version 6.13, Debian trixie). P8 left two things
unmeasured and 01.6 SF-1 handed a third over; this closes all three before `codex`'s and `agy`'s
profiles were flipped, which is what the feature plan required rather than assumed.

**The three questions, and why each mattered.** P8 ran on a plain `http_port` with
`basic_fake_auth`. `agy`'s hop to the mediator is TLS, so `https_port` **with** `proxy_auth` was
unmeasured on this build. `basic_fake_auth` accepts any password, so no hash format had ever been
exercised — and `basic_ncsa_auth` hashes through glibc `crypt(3)`, which has **no bcrypt**, so
`htpasswd -B` would have been the wrong reach. And a refusal's status code had never been observed
at all, which decides whether the `control=identity` / `ERR_MEDIATOR_IDENTITY` route the `mtls`
path takes is reachable here.

**Method.** A minimal `squid.conf` inside the shipped image: one plain `http_port` and three
`https_port`s, `auth_param basic program /usr/lib/squid/basic_ncsa_auth <htpasswd>`, per-user
`acl <name> proxy_auth <user>`, and an `openssl s_server` on 127.0.0.1:9999 as a bare TCP acceptor
so a permitted CONNECT can actually complete. Credentials were `codexuser` / `agyuser` with
`openssl passwd -apr1` hashes. Probes were raw CONNECTs — `/dev/tcp` for the plain port,
`openssl s_client -quiet -verify_return_error` for the TLS ones — with the
`Proxy-Authorization: Basic` header present, absent, or carrying a wrong username or password.

The three TLS ports differ only in the shape of the rule that annotates the attribution value,
because that shape is the second finding:

| Port | Rule shape |
|---|---|
| `tlsbare` | `http_access allow ... u_agy` only — no annotation |
| `tlsanno` | `http_access deny p !u_agy idsrc_pl rsn_cred` — the `mtls` path's "override on the miss" idiom, transposed |
| `tlsbase` | `deny p idsrc_pl !all` then `deny p u_agy idsrc_pa !all` — baseline, then upgrade |

**Result — the helper and the transport.**

```
plain  3181 no credential:                     HTTP/1.1 407 Proxy Authentication Required
plain  3181 wrong user:                        HTTP/1.1 407 Proxy Authentication Required
plain  3181 wrong password:                    HTTP/1.1 407 Proxy Authentication Required
plain  3181 right credential:                  HTTP/1.1 200 Connection established

TLS    3182 bare-deny  no credential:          HTTP/1.1 407 Proxy Authentication Required
TLS    3182 bare-deny  wrong user:             HTTP/1.1 407 Proxy Authentication Required
TLS    3182 bare-deny  right credential:       HTTP/1.1 200 Connection established

TLS    3183 anno-deny  no credential:          HTTP/1.1 407 Proxy Authentication Required
TLS    3183 anno-deny  wrong user:             HTTP/1.1 407 Proxy Authentication Required
TLS    3183 anno-deny  right credential:       HTTP/1.1 200 Connection established

TLS    3184 base+upg  no credential:           HTTP/1.1 407 Proxy Authentication Required
TLS    3184 base+upg  wrong user:              HTTP/1.1 407 Proxy Authentication Required
TLS    3184 base+upg  right credential:        HTTP/1.1 200 Connection established
```

`https_port` with `proxy_auth` works, `basic_ncsa_auth` is present in the shipped image at
`/usr/lib/squid/basic_ncsa_auth`, and it accepts `openssl passwd -apr1` hashes. `agy`'s mediator
side is therefore verified and its profile can be flipped.

**Result — the refusal is 407, never 403.** On every transport and every rule shape, including the
one that puts a `deny_info`-eligible ACL last. A missed `proxy_auth` ACL makes Squid answer its own
challenge, so there is **no error-page route and no `control=identity` verdict** on this path. That
is a real difference in kind from the `mtls` subject-mismatch refusal, which is a 403 with
`ERR_MEDIATOR_IDENTITY` — and it is why 01.6 SF-3 renders neither for a `proxy_auth` listener.

**Result — a `proxy_auth` ACL miss halts ACL evaluation on its line.** This is the finding that
changed the implementation, and it is visible in the `idsrc` column of the access log:

```
port=plainauth un=-         idsrc=-                   status=407
port=plainauth un=nobody    idsrc=-                   status=407
port=plainauth un=codexuser idsrc=-                   status=407   (wrong password)
port=plainauth un=codexuser idsrc=listener+proxy_auth status=200
port=tlsanno   un=-         idsrc=-                   status=407
port=tlsanno   un=nobody    idsrc=-                   status=407
port=tlsanno   un=agyuser   idsrc=listener+proxy_auth status=200
port=tlsbase   un=-         idsrc=listener            status=407
port=tlsbase   un=nobody    idsrc=listener            status=407
port=tlsbase   un=agyuser   idsrc=listener+proxy_auth status=200
```

`tlsanno` is the `mtls` idiom transposed, and it **does not work**: the annotation sits after
`!u_agy` on the deny line, evaluation stops at the credential ACL, and the 407 line carries
`idsrc=-` — an audit line stating no attribution strength at all, which is precisely what
criterion 3 exists to prevent. `tlsbase` is the shape that works: annotate the weak value on a line
carrying **no** `proxy_auth` term, so it always evaluates, then override it to the strong value on a
line gated on the credential. `annotate_transaction key=value` replaces where `key+=value` appends,
so last-wins makes the override an override.

**Also confirmed:** `%un` carries the username to the log and the password never appears there.
Zero `rejected-user`-style helper errors; `cache.log` shows the helper starting normally.

**Consequence for 01.6 SF-3.** Both agents take the positive branch. The renderer emits
`auth_param basic program /usr/lib/squid/basic_ncsa_auth` against an htpasswd the mediator alone
holds, an `acl cred_<agent> proxy_auth <identity>` per listener, the baseline-then-upgrade
annotation pair, and a bare `http_access deny p_<agent>_frontid !cred_<agent>` ahead of every
forwarding rule. Because the htpasswd holds hashes and not plaintext, the mediator cannot
authenticate to its own front listener — so the cascade warm-up is skipped for a `proxy_auth` agent
exactly as it is for an `mtls` one.

## Operational findings not attached to a property

**Squid cannot log to `/dev/stdout` after dropping to the `proxy` user.** With
`access_log stdio:/dev/stdout`:

```
FATAL: Cannot open '/dev/stdout' for writing.
	The parent directory must be writeable by the
	user 'proxy', which is the cache_effective_user set in squid.conf.
```

SF-4's entrypoint must either `chown` the container's stdout to the runtime user or log to a path
under the audit volume. This interacts with D12's audit sink and with the mediator's read-only
rootfs, so it is SF-4's to resolve, not a fixture artifact.

**`cache_peer` is cold on first use.** The first request through the cascade after a restart
returned `status=500` while the peer was still being probed; six sequential requests immediately
afterwards all returned `200`. SF-7's stage-2 startup self-check should warm the cascade, and SF-8
must not treat a single cold-start failure as a control result.

**`error_directory` replaces the whole error set.** `deny_info` naming a custom template only
resolves if the template lives in the active `error_directory`, which then supersedes the packaged
language directories entirely — the entrypoint has to compose the directory (packaged `en` plus the
mediator's own pages) rather than point at a directory containing one file.

## Verified configuration

The `squid.conf` that produced the results above, verbatim. Not shipped configuration —
SF-6 renders the equivalent from the resolved policy — but this is the shape that was proven.

```squid
pid_filename none
cache deny all
cache_log /var/log/squid/cache.log
dns_nameservers 127.0.0.11
shutdown_lifetime 1 seconds

https_port 0.0.0.0:3128 name=claude tls-cert=/pki/claude-listener.crt tls-key=/pki/claude-listener.key
https_port 0.0.0.0:3130 name=agy    tls-cert=/pki/agy-listener.crt    tls-key=/pki/agy-listener.key
http_port  0.0.0.0:3129 name=codex  ssl-bump tls-cert=/pki/codex-listener.crt tls-key=/pki/codex-listener.key generate-host-certificates=off
https_port 0.0.0.0:3138 name=cc_req tls-cert=... tls-key=... tls-cafile=/pki/mediator-ca.crt clientca=/pki/mediator-ca.crt
https_port 0.0.0.0:3139 name=cc_opt tls-cert=... tls-key=... tls-cafile=/pki/mediator-ca.crt clientca=/pki/mediator-ca.crt sslflags=DELAYED_AUTH
http_port  0.0.0.0:3149 name=authp

http_port 127.0.0.1:3228 name=claudein ssl-bump tls-cert=/pki/claude-listener.crt tls-key=/pki/claude-listener.key generate-host-certificates=off
http_port 127.0.0.1:3230 name=agyin    ssl-bump tls-cert=/pki/agy-listener.crt    tls-key=/pki/agy-listener.key    generate-host-certificates=off

acl step1 at_step SslBump1
ssl_bump peek step1
ssl_bump splice all

acl p_claude   myportname claude
acl p_agy      myportname agy
acl p_codex    myportname codex
acl p_claudein myportname claudein
acl p_agyin    myportname agyin
acl p_ccreq    myportname cc_req
acl p_ccopt    myportname cc_opt
acl p_authp    myportname authp
acl fronted    myportname claude agy

acl tag_claude annotate_transaction agent=claude
acl tag_agy    annotate_transaction agent=agy
acl tag_codex  annotate_transaction agent=codex
http_access deny p_claude   tag_claude !all
http_access deny p_claudein tag_claude !all
http_access deny p_agy      tag_agy    !all
http_access deny p_agyin    tag_agy    !all
http_access deny p_codex    tag_codex  !all

cache_peer 127.0.0.1 parent 3228 0 no-query no-digest no-netdb-exchange name=claudepeer
cache_peer 127.0.0.1 parent 3230 0 no-query no-digest no-netdb-exchange name=agypeer
cache_peer_access claudepeer allow p_claude
cache_peer_access claudepeer deny all
cache_peer_access agypeer allow p_agy
cache_peer_access agypeer deny all
never_direct allow fronted

auth_param basic program /usr/lib/squid/basic_fake_auth
auth_param basic children 2
auth_param basic realm sf1
acl u_claude proxy_auth claudeuser

acl cert_claude user_cert CN sf1-claude-client

acl CONNECT method CONNECT
http_access deny !CONNECT

acl h_allowed   dstdomain allowed.test
acl s_allowed   ssl::server_name --client-requested allowed.test
acl h_collector dstdomain collector.test
acl s_collector ssl::server_name --client-requested collector.test
acl h_agyonly   dstdomain agy-only.test
acl s_agyonly   ssl::server_name --client-requested agy-only.test
acl deny_fqdns  dstdomain denied.test
acl deny_cidrs  dst 169.254.169.254/32 172.18.0.9/32

acl maxconn_codex maxconn 2
delay_pools 1
delay_class 1 1
delay_parameters 1 65536/65536
delay_access 1 allow p_codex
delay_access 1 deny all

deny_info ERR_SF1_DENIED all

http_access deny deny_fqdns
http_access deny deny_cidrs
http_access deny p_codex maxconn_codex
http_access allow fronted
http_access allow p_claudein h_allowed   s_allowed
http_access allow p_claudein h_collector s_collector
http_access allow p_agyin    h_agyonly   s_agyonly
http_access allow p_codex    h_allowed   s_allowed
http_access allow p_ccreq    cert_claude h_allowed
http_access allow p_ccopt    cert_claude h_allowed
http_access allow p_authp    u_claude    h_allowed
http_access deny all

logformat sf1 %ts.%03tu agent=%note{agent} lport=%lp url=%ru status=%>Hs squid=%Ss bytes=%<st user=%un subj="%ssl::>cert_subject" sni="%ssl::>sni"
access_log stdio:/var/log/squid/access.log sf1
error_directory /run/errors
```

## Selection decision

**Squid `squid-openssl 6.13-2+deb13u2` is selected.** The implementation is pinned here and 01.6
inherits it.

Six of eight properties pass outright or pass with a named condition. The two that do not are not
reasons to prefer the fallback:

- **P5 fails for architectural reasons, not implementation ones.** Any proxy that splices rather
  than decrypts is unable to deliver an application-layer refusal inside a session it declines to
  terminate. `iron-proxy` inherits the identical failure. Switching implementations buys nothing.
- **P3's missing connection-rate ceiling** is a gap in every off-the-shelf CONNECT proxy the
  architecture named; Squid at least supplies the extension point (`external_acl_type`) to close it.
- **P6 and P7's cascade requirement** is a Squid-specific cost, and it is the one place where
  `iron-proxy` — being purpose-written — could plausibly do better by peeking the ClientHello on a
  TLS-terminated proxy hop in one listener. It was not chosen anyway: the cascade is verified
  working, and trading a packaged, security-supported proxy for an unaudited dependency to remove
  one loopback hop is the worse trade for a component whose whole purpose is to be the pod's single
  enforcement point. **Recorded as a decision, not as an absence of a question.**

### What this hands to later sub-features

| Finding | Lands in |
|---|---|
| Self-cascade topology (front `https_port` → loopback `ssl-bump` listener per fronted agent) | SF-6 |
| Per-name paired host+SNI ACL generation; N entries → N rules | SF-2 (artifact shape), SF-6 (rendering) |
| Fronting must be asserted, not the happy path | SF-6, SF-8 |
| `maxconn` threshold must be empirically calibrated under peek | SF-6, SF-8 |
| Connection-rate ceiling has no native mechanism — helper or recorded gap | SF-6 |
| Audit verdict must come from the inner listener, not the front | SF-7 |
| P5: no client-visible 403 body; denial surface is log-and-operator-only | SF-7, and a plan decision on criterion 5 |
| Cannot log to `/dev/stdout` as `proxy`; `error_directory` composition | SF-4 |
| `cache_peer` cold start | SF-7 (self-check warms), SF-8 (not a control result) |
| `clientca=` is required-mode by default; `DELAYED_AUTH` did not work | **01.6** — closed 2026-09-09 by design, not by fix (see P1 above); required mode on the `claude` front listener alone |
| Proxy-credential policy selection works on the plain transport | **01.6 — CLOSED.** Agent half measured 2026-09-09, positive for both `codex` and `agy` (`docs/records/agent-verification.md`, criterion 1). Mediator half on `https_port`, and with the real helper rather than the fixture one, measured 2026-09-10 as **P9 below** — both agents' listeners now declare `client_auth: proxy_auth` |
| Pin package version **and** base image digest | SF-4 |
