# Pod Resolver Verification — 01.3 SF-5

**Date:** 2026-09-07
**Host:** Docker Desktop 28.3.2, macOS 26, Apple silicon (R11.1, A1)
**Subject:** whether the resolver binary the mediator image already carries can express
acceptance criterion 4 — the closed forwarder — and, where it cannot, what does.

SF-4 installed `unbound` into the mediator image and said so explicitly rather than
quietly: *"the QTYPE restriction to A/AAAA and the EDNS-option stripping that criterion 4
requires are unverified in unbound and are SF-5's to establish. If SF-5 finds it cannot
express them, the package changes here and nothing else does."*
(`images/mediator/Dockerfile`, and `mediator-runtime-verification.md` §5.) This record is
that establishment. It is SF-1-shaped for the same reason SF-1 was: a property that fails
changes *what* SF-5 builds, not how well, and discovering it in SF-8 Phase D would be
expensive.

Nothing here is shipped configuration. The fixture is `.build-scratch/sf5/`.

---

## What criterion 4 actually demands

Six testable properties, taken from the criterion's own words:

| # | Property | Criterion 4's wording |
|---|---|---|
| R1 | Per-agent policy keyed on the arriving network | "names present in the resolved allowlist **for that network's agent**" |
| R2 | **Exact** match — a subdomain of an allowlisted name is not forwarded | "a query whose name is an **exact match**"; and the wildcard edge case: `<payload>.anthropic.com` "would hand back the channel R5.4 exists to close" |
| R3 | QTYPE restricted to `A`/`AAAA` | "restricts QTYPE to `A` and `AAAA`" — also the structural ECH mitigation, since `HTTPS`/`SVCB` is how an ECH config is retrieved |
| R4 | Re-origination: canonicalised (lowercased) name, no client EDNS option | "constructs a fresh query from the canonicalised (lowercased) name ... drops every EDNS option it did not originate"; "mixed-case QNAME (0x20 encoding), EDNS options including client-subnet ... all carry bits to an upstream the agent does not otherwise reach" |
| R5 | Allowlisted names are forwarded and resolve | "It **must** forward the allowlisted names — it is not authoritative for `api.anthropic.com`" |
| R6 | Every DNS decision audited — name, QTYPE, verdict, agent | "Every DNS decision is audited" |

**A plan-internal contradiction, resolved in favour of criterion 4.** The Files to
Create/Modify table describes `mediator/config/resolver.conf.tmpl` as *"Closed resolver:
allowlisted names answered, everything else REFUSED, **no forwarding**"*. Criterion 4 and
the SF-5 sub-feature text both say allowlisted names **are** forwarded to a named upstream,
and say so with reasons — the mediator is not authoritative for `api.anthropic.com`. The
table's phrase is read as "no *open* forwarding". Criterion 4 governs; the table wording is
corrected in the same commit.

---

## The fixture

Four `internal: true` networks mirroring the pod's shape (three agent networks plus an
upstream network), the resolver under test multi-homed across them at the `.2` address on
each agent network, one `dig` probe per agent network, and — the T4 fixture — a **controlled
authoritative server** that answers everything locally, forwards nowhere, and captures every
packet that reaches it.

The capture is the point. A resolver's own log says what it *decided*; only a capture at the
upstream says what actually **left**. Both R2 and R4 turn on that distinction, and the
SF-4 record was itself corrected once for evidence that proved less than it claimed.
`tcpdump` writes a pcap at the authoritative server and the queries are parsed out of it
field by field — QNAME **as raw bytes, case preserved**, QTYPE, and every EDNS option
present. unbound's `log-queries` shows none of those three.

---

## Candidate A — `unbound` 1.22.0 alone: FAILS THREE OF SIX

Configured as the closed forwarder its role implies: `local-zone: "." refuse` globally and
per view, `access-control-view` mapping each agent subnet to its own view, one
`local-zone: <name> transparent` per allowlisted name, and a single `forward-zone`. To close
R2 the one pure-unbound shape available was also tried — a wildcard `local-data`
(`*.api.anthropic.com. IN A 0.0.0.0`) intended to answer subdomains locally so they are
never forwarded.

| # | Result | Evidence |
|---|--------|----------|
| R1 | **PASS** | `claude` resolves `api.anthropic.com`; the same query from `codex` and `agy` returns REFUSED, and vice versa. Views select policy by arriving subnet, with no cross-agent leakage |
| R2 | **FAIL** | `leak.api.anthropic.com` and `deep.leak.api.anthropic.com` both **reached the authoritative server** and were answered. The wildcard `local-data` did not intercept them: under a `transparent` local-zone a name with no local data falls through to recursion, and the wildcard did not match first |
| R3 | **FAIL** | `TXT`, `HTTPS` and `MX` on the allowlisted name **all reached the authoritative server**. unbound has no QTYPE-based policy at all — `local-zone` types and RPZ both key on name, never on type |
| R4 | **SPLIT** | EDNS **PASS**: a client `+subnet=203.0.113.0/24` and a client `+cookie=` both arrived upstream as `OPT` with **no options**. unbound in forward mode genuinely re-originates. QNAME case **FAIL**: `ApI.AnThRoPiC.CoM` was forwarded upstream **with the client's case intact** |
| R5 | **PASS** | Allowlisted names resolve through to the upstream |
| R6 | partial | `log-queries`/`log-local-actions` record name, type and client address; verdict and agent are inferred, not stated |

**R2 and R3 are not tuning failures; they are structural.** unbound's `local-zone` is
subtree-scoped by construction — the closest enclosing zone governs a name and every name
beneath it — so "this exact name and nothing below it" has no expression. And no unbound
directive selects on QTYPE.

**Each failure is a live channel, not a cosmetic gap.**

- **R2** is the DNS tunnel in its textbook form. Every label below an allowlisted name is
  attacker-chosen and reaches an upstream the agent has no other route to. This is precisely
  what the plan's own wildcard edge case says "would hand back the channel R5.4 exists to
  close" — and the compiler already refuses wildcard *allowlist entries* to prevent it
  (`scripts/compile-policy.sh`). Candidate A reopens the same channel at the resolver, below
  the compile-time guard that was built to close it.
- **R3** removes the structural ECH mitigation. Criterion 4 restricts QTYPE to `A`/`AAAA`
  specifically so an agent cannot retrieve an Encrypted ClientHello configuration, which
  arrives in `HTTPS`/`SVCB` records. `HTTPS` queries reaching the upstream means the
  domain-fronting edge case loses the one control the plan credits against it. `TXT` is
  additionally a high-capacity exfiltration path in its own right.
- **R4/case** is the 0x20 channel the criterion names by name. DNS name comparison is
  case-insensitive, so a mixed-case QNAME **passes an exact-match allowlist unchanged** and
  carries roughly one bit per alphabetic character — about 15 bits per query through
  `api.anthropic.com` — to the upstream. Low bandwidth, but a channel that survives the
  control specifically built to close it.

---

## Candidate B — policy front (`dnsdist` 1.9.16) + loopback re-originating `unbound`

Two stages, each doing the half the other cannot:

- **`dnsdist` on the three agent addresses, port 53** — the policy engine. Per-agent
  allowlists selected by `NetmaskGroupRule` on the arriving subnet, exact names via
  `QNameSetRule`, QTYPE via `QTypeRule(A)`/`QTypeRule(AAAA)`, and a terminal
  `addAction(AllRule(), RCodeAction(REFUSED))` default-deny.
- **`unbound` on `127.0.0.1:5353` inside the mediator** — re-origination and caching only.
  It holds no policy, because it sees nothing the front has not already allowed.

| # | Result | Evidence |
|---|--------|----------|
| R1 | **PASS** | Each agent resolves its own names; another agent's name returns REFUSED |
| R2 | **PASS** | `leak.api.anthropic.com` and `deep.leak.api.anthropic.com` → REFUSED, and **absent from the upstream capture** |
| R3 | **PASS** | `TXT`, `HTTPS`, `MX`, `ANY` on the allowlisted name → REFUSED, and absent from the capture |
| R4 | **PASS** | EDNS options stripped; mixed-case QNAME refused (see below) |
| R5 | **PASS** | Allowlisted `A`/`AAAA` resolve through to the upstream |
| R6 | **PASS** | One JSON line per decision, allow and deny alike, carrying agent, name, QTYPE and verdict |

**The second stage is required, and that was tested rather than assumed.** Pointing
`dnsdist` straight at the upstream with no `unbound` behind it, the client's EDNS options
arrived **verbatim**:

```
qname='api.anthropic.com' qtype=A  edns=['CLIENT-SUBNET(00011800cb0071)', 'COOKIE(9fb3ef5353bff3ca)']
```

`00011800cb0071` is the probe's own `203.0.113.0/24`, and the cookie is byte-for-byte what
the client sent. `dnsdist` **proxies the client's packet**; it does not construct a new one.
So the two stages are not layering for its own sake — the front supplies the policy `unbound`
cannot express, and the back supplies the re-origination `dnsdist` does not perform. Remove
either and a named criterion-4 property fails.

**The 0x20 term is closed by refusal, not by rewrite — a deviation from the criterion's
wording, taken deliberately.** Criterion 4 says the resolver "constructs a fresh query from
the canonicalised (lowercased) name". `dnsdist` has no QNAME-rewrite action, and
`RegexRule` is case-**insensitive** (verified: `RegexRule("[A-Z]")` matched an all-lowercase
name, refusing everything). What does work is a `LuaRule` predicate comparing the wire name
against its own lowercasing, placed **before** the allow rules:

```
api.anthropic.com   A  -> NOERROR      (canonical)
ApI.AnThRoPiC.CoM   A  -> REFUSED      (0x20 channel)
API.ANTHROPIC.COM   A  -> REFUSED
```

Refusing is not weaker than rewriting — the channel is closed either way — and it is
**more auditable**: a non-canonical query becomes a logged `verdict=deny`,
`control=qname_case` decision instead of a silent normalisation. The one behavioural cost is
that a client deliberately randomising case for anti-spoofing (0x20 as a defence) would be
refused. No agent in this pod does so: they resolve through glibc or Node stub resolvers,
and under `HTTPS_PROXY` most do not resolve the destination at all.

### What actually left the pod, end to end

Every query reaching the controlled authoritative server across the full battery — twelve
probes spanning six allowed and six refused cases — was an allowlisted name, lowercased,
`A` or `AAAA`, carrying no EDNS option:

```
qname='api.anthropic.com'                  qtype=A     edns=['OPT/no-options']
qname='api.anthropic.com'                  qtype=AAAA  edns=['OPT/no-options']
qname='api.openai.com'                     qtype=A     edns=['OPT/no-options']
qname='generativelanguage.googleapis.com'  qtype=A     edns=['OPT/no-options']
```

No subdomain, no `TXT`/`HTTPS`/`MX`/`ANY`, no mixed case, no `example.com`, no encoded
label. This is the T4 assertion in its intended form: **the controlled authoritative server
receives no query it should not have received.**

### Audit line (R6)

```json
{"agent":"claude","identity_source":"listener","qname":"api.anthropic.com.","qtype":"1","verdict":"allow","control":null}
{"agent":"claude","identity_source":"listener","qname":"leak.api.anthropic.com.","qtype":"1","verdict":"deny","control":"allowlist"}
{"agent":"claude","identity_source":"listener","qname":"ApI.AnThRoPiC.CoM.","qtype":"1","verdict":"deny","control":"qname_case"}
{"agent":"codex","identity_source":"listener","qname":"api.anthropic.com.","qtype":"1","verdict":"deny","control":"allowlist"}
```

`agent` is derived from the arriving subnet and `identity_source` is `listener`, matching
Interface Contract 4 — the DNS decisions and the egress decisions carry attribution of the
same declared strength.

### Listener surface (criterion 1)

Enumerated from `/proc/net/{tcp,udp}` inside the container:

```
tcp/udp 172.32.10.2:53      agent network — the resolver
tcp/udp 172.32.20.2:53      agent network — the resolver
tcp/udp 172.32.30.2:53      agent network — the resolver
tcp/udp 127.0.0.1:5353      loopback — the re-originating resolver
```

Exactly one resolver listener per agent network, nothing bound on the external network, and
the second stage on loopback — which criterion 1 already permits ("any management, metrics,
admin or health endpoint binds the loopback interface inside the mediator, never an agent
network"). The permitted per-network set remains `{proxy, resolver}`.

---

## As built — the shipped mediator, not the fixture

The findings above were taken on a throwaway fixture. The same battery was then run
against the real pod: `compose/compose.yaml`'s `egress-mediator`, its configuration
**rendered by the entrypoint from `policy/resolved/default.yaml`** rather than
hand-written, with probe containers attached to the pod's own agent networks.

The rendered allowlist matches the artifact exactly, including the `agy`
auto-updater host the profile excludes (criterion 12) — `NAMES_agy` carries five
names and not that one.

```
claude  api.anthropic.com                     A      -> NOERROR   (160.79.104.10)
claude  api.anthropic.com                     AAAA   -> NOERROR
claude  api.openai.com                        A      -> REFUSED   another agent's name
codex   api.openai.com                        A      -> NOERROR
codex   github.com                            A      -> NOERROR
agy     generativelanguage.googleapis.com     A      -> NOERROR
claude  leak.api.anthropic.com                A      -> REFUSED   subdomain
claude  example.com                           A      -> REFUSED   not allowlisted
claude  api.anthropic.com                     TXT    -> REFUSED   QTYPE
claude  api.anthropic.com                     HTTPS  -> REFUSED   QTYPE / ECH
claude  ApI.AnThRoPiC.CoM                     A      -> REFUSED   0x20
agy     antigravity-cli-auto-updater-...      A      -> REFUSED   criterion 12 exclusion
```

Allowed names resolve for real, through Docker's embedded resolver to the operator's
own upstreams — so this is the closed forwarder working, not a fixture answering
itself.

**Audit trail.** Thirteen decisions produced thirteen JSON lines, on the audit volume
**and** on the container's stdout — D12's two sinks, both carrying the DNS trail:

```json
{"ts":"2026-09-07T13:15:01Z","agent":"claude","identity_source":"listener","qname":"api.anthropic.com.","qtype":"A","verdict":"allow","control":null}
{"ts":"2026-09-07T13:15:02Z","agent":"claude","identity_source":"listener","qname":"leak.api.anthropic.com.","qtype":"A","verdict":"deny","control":"allowlist"}
{"ts":"2026-09-07T13:15:03Z","agent":"claude","identity_source":"listener","qname":"ApI.AnThRoPiC.CoM.","qtype":"A","verdict":"deny","control":"qname_case"}
```

**Listener surface**, enumerated from `/proc/net/{tcp,udp}` in the running mediator:

```
tcp     127.0.0.1:3128     squid, still HOLDING (SF-6 opens the agent-facing ports)
tcp/udp 127.0.0.1:5353     the re-originating resolver
tcp/udp 172.31.10.2:53     claude-net  — the resolver
tcp/udp 172.31.20.2:53     codex-net   — the resolver
tcp/udp 172.31.30.2:53     agy-net     — the resolver
udp     0.0.0.0:54671      ephemeral outbound socket — see below
```

One resolver per agent network, nothing bound on the mediator's `egress-net`
address, and the second stage on loopback.

### Two failures found while building, both fixed at the source

Neither is a resolver finding; both are recorded because each would have been a
build that works on one machine and not another.

- **The resolved policy artifact was mode `0600`, and the image inherited it.** The
  mediator runs as uid 13 and could not read its own policy — it aborted at start
  naming the field, which is the right direction, but for the wrong reason.
  `scripts/compile-policy.sh` writes through `mktemp`, which creates `0600`, and
  `COPY` preserves the source mode. Git records only the executable bit, so a **fresh
  clone builds a working image and a tree where the compiler had just run does
  not** — a failure that reproduces only for whoever last recompiled. Fixed at both
  ends: the compiler now `chmod 0644`s the artifact, and the Dockerfile pins the mode
  itself rather than trusting the context.
- **`COPY --chmod=0444` was the wrong repair**, and it is worth naming because it
  looks right. A single `--chmod` applies to the copied **directories** too, and a
  directory without the execute bit cannot be traversed — so the policy became
  unreadable a second time, more confusingly. `RUN chmod -R a=rX` is the correct
  form; the capital `X` sets execute only where the target is a directory.

## Results carried forward

- **`qtype` is logged as a number** (`1`, `28`, `16`, `65`), not a mnemonic. SF-7 owns the
  audit schema and should map it.
- **The case check runs before the allowlist check**, so a query that is both non-canonical
  and non-allowlisted is attributed `control=qname_case`. Correct outcome, and the ordering
  is deliberate — envelope integrity before policy — but SF-7 and SF-8 should not read
  `qname_case` as meaning the name would otherwise have been allowed.
- **`dnsdist` health-check queries reach the upstream** and are **not** attributable to any
  agent, since they originate in the mediator. Pointed at an allowlisted name with
  `mustResolve=false`, so they are within policy — but SF-8's audit-completeness phase will
  see upstream queries with no matching audit line unless the check is disabled. The backend
  is a loopback process in the same container, so disabling it is defensible.
- **An ephemeral outbound UDP socket appears on `0.0.0.0`.** The resolver's upstream
  queries leave from a wildcard-bound ephemeral port, so `/proc/net/udp` lists a
  socket reachable in principle from an agent network. It is not a service: unbound
  accepts only replies matching a query it originated. It matters for SF-8, whose
  criterion-1 assertion must enumerate **listening services**, not every bound UDP
  socket, or it will fail on this. Binding `outgoing-interface: 127.0.0.1` would
  remove it, and is deliberately not done — it would break the configurable upstream
  the harness depends on for T4.
- **Squid's own resolution path is SF-6's, and it collides with this design.** If SF-6 points
  `dns_nameservers` at the pod resolver, Squid's queries arrive from `127.0.0.1` — no agent
  subnet, so no view, so REFUSED by default-deny. SF-1's verified configuration used
  `dns_nameservers 127.0.0.11` (Docker's embedded resolver) and that remains available.
  Recorded so SF-6 does not rediscover it.

## Not established here

- Behaviour under the shipped resolved-policy artifact. The fixture used hand-written
  allowlists mirroring `policy/resolved/default.yaml`; rendering the configuration from the
  artifact is the build, and SF-8 Phase D is the assertion.
- Anything about the upstream's identity. Which address the mediator forwards to is a
  configuration decision recorded with the build, not a property tested here.
- Load, cache and failure behaviour of the two-stage cascade under concurrency.
