# Feature Plan: Per-agent workload identity

**Milestone:** 01 - Sandboxed Pod
**Feature:** 01.6: Per-agent workload identity
**Status:** Planned
**Date:** 2026-09-09

## Summary

Feature 01.3 shipped a mediator whose per-agent policy selection works on **network-derived**
identity: each agent sits alone on its own `internal: true` segment, policy is selected by
`myportname`, and every audit line reads `identity_source: "listener"`. This feature adds the
client-authentication layer on top of that mediator and closes R8.8 — each agent issued a distinct
workload identity with a defined lifecycle, used to authenticate to the enforcement point and
recorded on every audit line. The form is the strongest each agent's client actually supports, which
01.1 SF-2 measured as non-uniform: `claude` presents a client certificate, `codex` cannot reach a
TLS listener at all, `agy` reaches the `CertificateRequest` stage with nothing to offer. One unknown
remains and this feature establishes it before building on it — whether `codex` or `agy` will send a
**proxy credential** (`Proxy-Authorization`, or userinfo in the proxy URL). The feature also enforces
the subject-to-listener binding refusal (T34), amends T34's unexecutable register method in the same
shape 01.3 amended T28, extends the `identity_source` enumeration so an audit line states the
strength of its own attribution, and records which agents qualify for Milestone 03 credential
brokering under D6's precondition.

## Acceptance Criteria

1. **The proxy-credential mechanism is verified per agent before it is built on, not assumed.**
   `codex` and `agy` are tested against a listener that requires a proxy credential — both the
   `Proxy-Authorization` header form and the userinfo-in-proxy-URL form — and each result is
   **recorded** in `docs/records/agent-verification.md` in the shape criterion 5 already uses. The
   criterion is that the result is recorded, not that it passes. A negative for both is a permitted
   outcome and this plan states what is built in that case.

2. **Each agent carries a distinct workload identity with a defined lifecycle**, used to
   authenticate to the mediator and recorded on every audit line (R8.8). The form is the strongest
   that agent's client supports: mTLS client certificate for `claude`; proxy credential for
   `codex`/`agy` where criterion 1 finds one; otherwise network-derived — exactly one agent
   container per `internal: true` network, on which no other agent holds an interface.

3. **The audit line states the strength of its own attribution.** `identity_source` — present on
   every verdict line since 01.3 SF-7 and emitting the literal `listener` for all three agents — has
   its **enumeration** extended and its value made per-connection rather than hardcoded. The schema
   is not replaced. A network-derived attribution is never readable as a cryptographic one.

4. **A credential bound to one identity is refused when presented by another (T34).** For the mTLS
   agent this runs literally at the listener: the certificate subject must equal the listener's own
   agent, and a valid certificate issued by the same CA carrying a different subject is refused
   **with an audit line**, not silently. For an agent with no client credential the cross-binding
   case is **structural** — no route to another agent's network exists to present anything over —
   and the harness asserts network disjointness by enumeration rather than by a presentation
   attempt.

5. **T34's register method is amended in `REQUIREMENTS.md`, not reinterpreted locally.** T34 reads
   "present agent A's client certificate", which is unexecutable for an agent that has none. The
   amendment follows the block shape 01.3 SF-3 used for T28 and 01.4 SF-2 used for T24: previous
   text, why it is unexecutable, the property it exists to protect, and what is explicitly
   unchanged.

6. **Identity lifecycle is defined and documented** (R8.8's "defined lifecycle"): subject naming,
   validity bound, renewal path and revocation path, for the certificate form and for any credential
   form criterion 1 enables. This **extends** the lifecycle 01.3 SF-3 recorded in
   `mediator/identity/README.md`; it does not define a second one and does not create a second CA.
   The CA private key stays on the operator host and never enters the mediator.

7. **D6's precondition is enforced, not relaxed.** Milestone 03 credential brokering is enabled only
   for an agent whose identity is **cryptographically bound** at the mediator. Whichever agents
   qualify is recorded as Milestone 03's inherited input, in the record the milestone's Definition
   of Done names.

8. **The pre-existing acceptance harnesses stay green.** Enabling client-certificate verification,
   changing `claude`'s `identity_source` value and mounting new per-agent secrets each break
   assertions 01.2 and 01.3 shipped. The feature closes on the composite Test Command, not on its
   own phases alone.

## Approach

### The starting position, stated because it decides the shape

01.3 pinned Squid `squid-openssl 6.13-2+deb13u2` and measured three properties this feature is built
on (`docs/records/mediator-selection.md`):

- **P1 PASS in required mode.** `https_port ... clientca=/pki/mediator-ca.crt` refuses a client that
  presents nothing, and the subject is reachable by both policy (`acl <name> user_cert CN <subject>`)
  and log (`subj="/CN=..."`).
- **P1 FAIL in optional mode.** `sslflags=DELAYED_AUTH` refused the connection **with and without** a
  client certificate (`000`/`000`). Parse was clean; the failure is at runtime. 01.3 handed this to
  01.6 as an open gap.
- **P8 PASS.** `auth_param basic` with `acl <name> proxy_auth <user>` keys policy off a proxy
  credential on a plain `http_port` — the transport shape `codex` is restricted to — and `%un`
  carries the credential to the log. The proxy half of the fallback path exists. The **agent** half
  is this feature's criterion 1.

Three shipped facts constrain where the work lands:

- **Listener directives are rendered by `images/mediator/entrypoint.sh`, not written in
  `proxy.conf.tmpl`.** The template carries the `@PROXY_LISTENERS@` marker (`:67`); the `https_port`
  and `http_port` strings are built at `entrypoint.sh:351-352` (TLS agents, two listeners each — a
  front listener and a loopback inner bump listener) and `:411` (`codex`, one). `clientca=` is added
  to the front `https_port` string, in the renderer.
- **Policy selection is `myportname`, never the client address** (`proxy.conf.tmpl:18-20`,
  `entrypoint.sh:432-434`). Identity survives the front-to-inner hop because each layer has its own
  port *name*; the client address is `127.0.0.1` on every inner listener. The `user_cert` binding
  rule therefore attaches to the front port name, which is what makes it a subject-to-**listener**
  binding rather than a subject-to-address one.
- **`identity_source` is not a Squid field.** It is a string literal in the audit writer's two
  printf templates (`images/mediator/audit-writer.sh:144` deny, `:153` allow). Making it
  per-connection is a change to the `agent`/`layer` annotation idiom, not a change to the writer's
  vocabulary — see Decision 3.

### Decision 1 — required-mode verification on the `claude` front listener only; the DELAYED_AUTH gap is disposed of, not chased

Optional-mode verification exists to let one listener serve both a cert-bearing and a cert-less
client. **That case does not occur here.** D2 gives every agent its own listener on its own network,
so the `claude` front listener serves exactly one client and that client can present a certificate.
The `agy` listener stays server-auth-only and the `codex` listener stays plain HTTP CONNECT; neither
needs optional mode either. The DELAYED_AUTH runtime failure is therefore recorded as **closed by
design, not by fix** — the feature has no consumer for the mechanism, and chasing a Squid runtime
bug to enable a mode nothing needs is work with no requirement behind it. The disposal is written
into `docs/records/mediator-selection.md` against the open gap, so the gap is closed on the record
rather than left dangling.

`clientca=` goes on the **front** `https_port` only. The loopback inner bump listener
(`127.0.0.1:<inner>`, `entrypoint.sh:352`) must not carry it: its client is Squid's own cascade hop,
which presents nothing, and requiring a certificate there would refuse the mediator's own traffic at
the handshake. The self-check shadow listeners (`:384-385`, `:418`) are likewise left alone — stage 2
of the startup self-check probes through them and holds no client certificate.

The consequence is stated rather than glossed, because the two refusal paths land in different
places:

| Case on the `claude` front listener | Where it is refused | Audit line? |
|---|---|---|
| No client certificate presented | TLS handshake, before any ACL runs | **No** — the connection dies before Squid has a request to log |
| Valid certificate, same CA, wrong subject | `user_cert CN` ACL, after the handshake | **Yes** — this is T34's literal case, and it is logged |

T34's own test is the second row, so T34 is satisfiable with an audit line. The first row is a
property of `clientca=`'s required-at-handshake semantics, measured at 01.3 SF-1, and it is exactly
what makes required mode safe on a single-client listener and unsafe on a shared one.

### Decision 2 — the certificate subject is the resolved-policy `identity` value, which stops being inert

`scripts/compile-policy.sh` emits `identity: <agent>` into every agent block (`:826`) and
schema-requires it (`:256`), and `policy/resolved/default.yaml` carries it (`:18,27,39`) — but
`grep '\.identity\b' images/mediator/entrypoint.sh` returns nothing. **The field is validated,
emitted, and consumed by nothing.** 01.3's Interface Contract 1 reserved it for exactly this:
`identity: claude` is "NOT a certificate subject at this feature — 01.6 binds a cert subject to this
same value."

This feature binds it. `issue-identity.sh` takes the subject from it, the `user_cert CN` ACL matches
it, and the audit line's `agent` note already equals it. One identity token across issuance, policy,
enforcement and audit, rather than four that must be kept in step by hand. `mediator/identity/README.md`
already reserves the subject `CN=<agent>` for 01.6 in its subject-naming table, and
`issue-identity.sh:64-66` already comments that the listener subject is deliberately
`CN=mediator-listener-<agent>` rather than `CN=<agent>` so that T34 is unambiguous. Both are honoured
as written.

### Decision 3 — `identity_source` is rendered from `client_auth`, per listener, in the same pass that renders the enforcement

It cannot stay a literal. Two mechanisms were considered before the one taken.

**Rejected: derive it in the audit writer from the `agent` field.** That is uncoupled from
enforcement. The writer would say `listener+mtls` for `claude` on a connection where no certificate
was verified — including the T34 refusal line — which is precisely the misreading criterion 3 exists
to prevent.

**Rejected: annotate on the front layer and propagate to the inner layer by request header.**
`annotate_transaction` acts on the master transaction, and the front-to-inner hop is not one
transaction: the front reaches the inner listener through `cache_peer 127.0.0.1 parent <inner>`
(`entrypoint.sh:359`), which is a new client connection and a new master transaction. That is why
`agent` and `layer` are already **re-derived per layer** from `myportname` rather than carried across
— `entrypoint.sh:570-585`, whose comment says the annotations exist "so the writer can tell a front's
tunnel line from the inner line carrying the real verdict". A header would cross the hop, but the
agent can set that header itself, so the inner layer would be trusting a claim it cannot verify, and
the scrub-then-add ordering (`request_header_access` versus `request_header_add`) is unverified on
Squid 6.13. A forgeable claim guarding an attribution field is worse than no field.

**Taken: render `idsrc` from the same `client_auth` value, in the same renderer pass, that renders
the enforcement.** The soundness argument is one sentence: *`idsrc` and `clientca=` come from the
same policy field in the same pass, so the annotation cannot say a listener authenticates when the
listener does not.* This is not the static derivation rejected above, which had no such coupling.

The topology is what makes per-listener derivation true rather than merely convenient:

- The inner listener binds **`127.0.0.1` only** (`entrypoint.sh:352`). No agent network can reach it.
- Its only client is the front's cascade hop, and `cache_peer_access <agent>peer allow
  p_<agent>_frontreal` (`:366-367`) admits only that agent's own front.
- So a connection reaching `claude`'s inner listener necessarily came through `claude`'s front
  listener, which under required-mode `clientca=` necessarily presented a valid CA-issued
  certificate.

The annotation is therefore per **listener** on layers that are only reachable through an
authenticating front, and per **request** on the layer where the check actually runs:

| Layer | Agent | How `idsrc` is set |
|---|---|---|
| Front (`https_port`, agent-facing) | `claude` | Per request: `listener+mtls` gated on the `user_cert CN` ACL; the mismatch path overrides it to `listener` |
| Inner (`http_port 127.0.0.1`) | `claude` | Per listener: `listener+mtls`, sound by the argument above |
| Single listener (front == inner) | `codex` | Per request, on SF-1's branch: `listener+proxy_auth` gated on `proxy_auth`, else `listener` |
| Front and inner | `agy` | As `claude`, with `proxy_auth` in place of `user_cert` on SF-1's branch |

Two ordering constraints make it correct, and both are asserted rather than assumed:

1. **The `user_cert CN` mismatch deny must precede any rule that forwards to the peer.**
   `cache_peer_access` is evaluated after `http_access`. A mismatched certificate that reached an
   allow rule first would be forwarded, and the inner listener would then annotate `listener+mtls` on
   a connection its front should have refused. The deny rule is rendered ahead of the agent allow
   rules.
2. **The self-check ports must be excluded.** `_front_names`/`_inner_names` for `SC_AGENT` include
   the shadow listeners, and only `p_<agent>_real` filters them (`grep -v '^selfcheck'`,
   `entrypoint.sh:449`). Annotating on the un-filtered inner set would label stage-2's own traffic
   `listener+mtls`. The `idsrc` annotation attaches to the `_real` set, and the existing
   `agent=selfcheck` tag is followed by its own `idsrc=listener` — `annotate_transaction key=value`
   **replaces** where `key+=value` appends, so last-wins ordering is the documented behaviour and is
   what the self-check override relies on.

The enumeration becomes:

| Value | Meaning | Sufficient for M03 brokering? |
|---|---|---|
| `listener` | Network-derived: the arriving `internal: true` network, via `myportname`, named the agent | No |
| `listener+mtls` | Network-derived, **and** a client certificate whose subject equals the listener's agent was verified against the mediator CA | **Yes** |
| `listener+proxy_auth` | Network-derived, **and** a proxy credential bound to this agent was accepted | No — Decision 4 |

`listener+proxy_auth` is emitted only if criterion 1 returns a positive for that agent. If criterion 1
is negative for both, the enumeration ships with two values and the third is recorded as unreachable
on the measured clients, rather than left in the schema as aspiration.

### Decision 4 — the Milestone 03 brokering gate is `listener+mtls` alone

D6's precondition is that the broker knows *which* agent is calling, strongly enough that a
compromised agent cannot claim to be another. A basic proxy credential does not meet that bar: it is
a bearer shared secret; it is readable in the agent's own environment and `/proc`; and on `codex-net`
it crosses the proxy hop in the clear, because that hop is plain HTTP by construction (01.1 SF-2).
An agent that can read its own credential can present it, and an agent that could read another's
could present that. The certificate case differs in kind — the private key authenticates, and
possession is what the listener checks.

**So the brokering gate is the cryptographic form alone**, which on today's evidence means `claude`.
A positive criterion-1 result still earns its keep: it gives `codex`/`agy` a real, per-agent,
revocable identity token and a stronger audit line than network-derived attribution, which is what
R8.8 asks for. It does **not** move them through D6's gate. This is recorded as Milestone 03's
inherited input so the restriction is inherited explicitly rather than rediscovered there.

### Decision 5 — the listener's authentication mode is profile data, not renderer code

`profiles/default.yaml:132-135` declares the listener shape and `compile-policy.sh:810-812` validates
exactly three keys via `has()`:

```yaml
listeners:
  claude: {scheme: https, tls: true,  port: 3128}
  codex:  {scheme: http,  tls: false, port: 3128}
  agy:    {scheme: https, tls: true,  port: 3128}
```

There is no credential or client-certificate key anywhere in the profile schema. The alternative to
adding one is a hardcoded per-agent capability list in the renderer — which puts a policy decision
("this agent must authenticate") inside `entrypoint.sh`, where the compiler cannot validate it, the
resolved policy does not show it, and `lint-policy.sh` cannot check it. The whole point of the
compile step is that the mediator renders what policy says.

So `listeners.<agent>` gains `client_auth: mtls | proxy_auth | none`, validated by the compiler at
the profile-side `for k in scheme tls port` loop (`compile-policy.sh:810-812`), carried into the
resolved artifact's per-agent `listener:` map (`compile-policy.sh:827`, e.g.
`policy/resolved/default.yaml:19`), and read by the renderer to decide whether the front listener
gets `clientca=` and whether an `auth_param`/`proxy_auth` block is emitted.

Cost, stated in full because it is the widest blast radius in the feature: the compiler,
`lint-policy.sh`, the renderer, **all four profiles** that declare a `listeners:` block —
`profiles/default.yaml:132`, `profiles/test-fixtures.yaml:59`, `profiles/test-selfcheck.yaml:65`,
`profiles/oauth-mount.yaml:124` — and the resolved artifacts compiled from them. A required key
added to one profile fails every other profile's compile. See the second tradeoff callout.

### Decision 6 — the credential helper is real, not the fixture

`basic_fake_auth` accepts any password, and 01.3's record already flags it as a fixture helper only.
If criterion 1 is positive, the shipped path is `basic_ncsa_auth` against an htpasswd file delivered
as a Compose secret to the mediator alone, with each agent's own credential delivered to that agent
alone. The lifecycle **extends** `mediator/identity/README.md` in the same shape it already uses:
rotation is rewrite-the-file, restart the mediator, update that agent's environment; revocation is
remove the agent's line and restart. No second lifecycle document, no CRL, no OCSP — the same
population-size argument that justified the certificate revocation path.

### Decision 7 — verification first, with both branches written now

SF-1 is discovery-shaped and its result decides SF-3. Because the acceptance criterion is
"recorded", not "passes", both branches are specified here rather than deferred to build time:

- **Positive for an agent** — that agent gets a proxy credential, `client_auth: proxy_auth` in the
  profile, an `acl <name> proxy_auth` policy key, `identity_source: listener+proxy_auth`, and a
  credential scoped to it alone.
- **Negative for an agent** — its identity stays network-derived, `client_auth: none`,
  `identity_source: listener`, and the structural T34 case is what the harness asserts for it. This
  is the state 01.3 already ships; the work is then to **record it as final** for that agent, not to
  leave it unstated.

A negative for both is not a milestone-level escalation the way the 2026-09-04 R8.8 gap was. That
escalation existed because the gap was undecided. This plan decides it in advance: R8.8 closes
cryptographically for `claude`, and for the other two by the register amendment plus the recorded
network-derived form, with the residual carried per audit line rather than in a footnote.

### Decision 8 — the regression surface is scheduled, not discovered

Four shipped assertions break the moment this feature lands. All four were found on disk, and two of
them were written by 01.3 *to be* inverted here:

1. **`tests/acceptance/verify-egress-mediator.sh:105` hardcodes the attribution value.**
   `assert_verdict`'s universal final check is
   `jq -e '.agent != null and .ts != null and .identity_source == "listener"'`. It runs on **every**
   verdict assertion in the harness. The moment `claude`'s attribution becomes `listener+mtls`, every
   `assert_verdict` on a `claude` line fails. This is the single most consequential harness fact in
   the feature. `assert_verdict` gains a per-agent expected value rather than a literal.
2. **`verify-egress-mediator.sh:341-343` is an unconditional `pass` with no probe behind it**, and
   its comment says why: *"01.6 inverts this for the listeners whose agent can present one, and
   asserting it here is what makes that inversion visible when it lands."* It is replaced by a real
   probe: a cert-less connection to the `claude` front listener is refused at the handshake, and the
   `agy` and `codex` listeners still accept a credential-less client.
3. **Cert-less TLS probes to the `claude` front listener** at `:308`, `:315`, `:362`, `:391` and
   `:445`, all through the `probe_ca` helper (`:58-77`), which mounts the CA and nothing else. Under
   required mode every one fails at the handshake. A fourth probe variant is added that also mounts
   the client key pair, and it keeps `-verify_return_error` with no insecure-TLS bypass, for the
   reason 01.3 gave at `:300-303`: a bypass makes the one check that catches a mis-issued listener
   certificate pass unconditionally.
4. **`tests/acceptance/verify-pod-topology.sh` asserts mount-set equality.** 01.3 SF-4 hit this exact
   wall when the CA secret was mounted into `claude` and `agy`, and extended the allowed set rather
   than leaving it to break. Mounting `claude-client.{crt,key}` does it again.

5. **The policy compiler is a build stage of the mediator image, and the build refuses an
   unreviewed artifact.** `images/mediator/Dockerfile:99,231` copies `compile-policy.sh` into the
   image, and `scripts/compile-policy-build.sh` compares the build's output against the committed
   `policy/resolved/` and exits non-zero on any difference — *"the build refuses an artifact nobody
   reviewed (R5.14)"*. So the compiler change, all four profiles and both regenerated resolved
   artifacts must land in one commit, or the mediator image does not build. This also puts
   `tests/acceptance/verify-pack-composition.sh` — 01.5's harness, which drives that build and its
   drift check — on the regression list.

Each is amended in the sub-feature that causes the break, not in a cleanup pass afterwards.

## Sub-Features

- [x] **SF-1: Proxy-credential capability verification for `codex` and `agy`** — The one remaining
  unknown, answered before anything is built on it. Extends `scripts/verify-agent-clients.sh`: its Go
  CONNECT fixture (`:55-165`) today exposes only `-plain :18080` and `-tls :18443` with
  `RequireAndVerifyClientCert`, and has **no `Proxy-Authorization` handling at all** — no header
  read, no 407, no realm. It gains a credential-requiring mode on both transports, logging the
  presented credential the way it already logs `cert=` from the peer certificate CN. The matrix
  (`:271-341`) gains `{codex, agy} × {proxy-auth-header, proxy-auth-userinfo}` at the pinned versions
  (`@openai/codex@0.152.1`, agy per its install script — R10.6). Recorded in
  `docs/records/agent-verification.md` as a new criterion section in the shape criterion 5 uses
  (`:92-118`): a `| Agent | Result | Mechanism | Evidence |` table where the evidence is fixture log
  lines and probe output, not a summary, followed by a "Consequence for R8.8" prose block. Also
  writes the DELAYED_AUTH disposal (Decision 1) into `docs/records/mediator-selection.md` against the
  open gap at `:507`. **The deliverable is the record**; the pass/fail split decides SF-3's branch.
  No product code. Note the preflight: the script requires `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` and
  `GOOGLE_API_KEY` and exits 64 without them. Depends on nothing in this feature.

- [x] **SF-2: Client-certificate issuance, required-mode verification and the T34 binding refusal for
  `claude`** — The cryptographic path end to end, for the one agent that can carry it. Adds a
  `client` mode to `scripts/issue-identity.sh` (a fifth `case` arm alongside `ca`, `listener`,
  `status` and the bare-word renewal): subject `CN=<agent>` taken from the resolved policy's
  `identity` value, `extendedKeyUsage = clientAuth` only, `basicConstraints = critical,CA:FALSE`, no
  SAN, the same CA and the same 365-day bound the listener path uses, issued under the same
  `( umask 077 )` discipline, with a `verify_client` counterpart to `verify_listener` (`:186-212`)
  asserting chain, subject and EKU. **Also fixes the truncated `--help`**: it prints `sed -n '2,36p'`
  (`:288`) and the mode list already ends at line 36, so `status` and the renewal form are invisible
  today and a fifth mode would be too. Wires `claude-client.{crt,key}` as a Compose secret scoped to
  the `claude` service alone, plus `CLAUDE_CODE_CLIENT_CERT`/`CLAUDE_CODE_CLIENT_KEY`. Adds
  `client_auth` to the profile listener schema (Decision 5) through `compile-policy.sh`,
  `lint-policy.sh`, **all four** profiles that declare a `listeners:` block and both regenerated
  resolved artifacts — one commit, or `compile-policy-build.sh` refuses the image build (R5.14). Renders `clientca=` onto the `claude` **front** `https_port` only
  (`entrypoint.sh:351`), leaving the inner and self-check listeners untouched. Adds the
  `acl <name> user_cert CN <identity>` binding rule and the `idsrc` annotation, extends
  `logformat mediator_raw` with the 14th field and `audit-writer.sh` in lockstep (Decision 3).
  **Amends `verify-egress-mediator.sh` in the same commit** — `assert_verdict`'s hardcoded
  `identity_source == "listener"` at `:105`, the placeholder `pass` at `:341-343`, and the five
  cert-less `claude` probes — and `verify-pod-topology.sh`'s mount set. The largest sub-feature; see
  the sizing note. Depends on SF-1 only for the DELAYED_AUTH disposal being on the record, not for
  its result.

- [x] **SF-3: The `codex`/`agy` identity path, on SF-1's result** — Conditional by design, both
  branches specified. **Positive for an agent:** a per-agent proxy credential, `basic_ncsa_auth`
  against an htpasswd Compose secret mounted to the mediator alone, that agent's credential delivered
  to that agent alone, `client_auth: proxy_auth` in the profile, an `acl <name> proxy_auth` policy
  key on its listener, and `idsrc=listener+proxy_auth`. **Negative for an agent:** `client_auth:
  none`, identity recorded as network-derived and final, `identity_source` stays `listener`, nothing
  is built. **For `agy` specifically, the mediator side is verified before the profile is flipped**: P8 was
  measured on a plain `http_port` only, and `agy`'s hop is TLS, so `https_port` with `proxy_auth` is
  unmeasured on this Squid build. In both branches the agent's structural T34 case is what SF-4
  asserts. Carries the plaintext-credential acceptance note for `codex` if that branch is taken — the credential crosses
  the plain-HTTP proxy hop in the clear on a two-member `internal: true` network and is visible in
  the agent's own environment and `/proc`; bounded to `codex`, recorded, not mitigated, and it is the
  concrete reason Decision 4 does not admit it to the brokering gate. Depends on SF-1 and SF-2 (SF-2
  pins the `idsrc` annotation and the `client_auth` schema this extends).

- [ ] **SF-4: T34 in the harness, the register amendment, and the Milestone 03 inherited input** —
  The closing unit. Extends `verify-egress-mediator.sh` with a T34 phase in its existing idiom
  (`phase`/`pass`/`fail`/`note`, `set -uo pipefail` accumulating into `FAILED`): the **literal** case
  for `claude` — issue a same-CA certificate with subject `CN=codex`, present it on the `claude`
  front listener, assert refusal **and** assert the audit line naming it, since the audit trail is
  the authoritative surface (`:79-82`) — and the **structural** case for the other two, asserting
  network disjointness by enumeration against `compose.yaml`'s three `internal: true` networks, on
  which each agent holds exactly one interface and no agent holds one on another's. Applies the T34
  amendment to `REQUIREMENTS.md` per Interface Contract 4. Writes `docs/records/workload-identity.md`
  — per-agent identity form, the `identity_source` each produces, and the resulting Milestone 03
  brokering restriction — the record the milestone's Definition of Done names. Extends
  `mediator/identity/README.md` with the client certificate's lifecycle and any credential's, and
  **corrects its forecast at `:128`**, which reads "at most six after 01.6 adds client certificates"
  on the assumption of three client certificates; the real count is four unless SF-1 returns a
  positive that changes it. Depends on SF-2 and SF-3.

**Sizing note.** Four sub-features. **SF-2 is the largest** and it is the one worth naming: an
issuance-script change, a profile/compiler schema change, a Compose secrets change, a renderer
change, a two-file audit contract change and two harness amendments. It is kept whole rather than
split because the pieces are one causal chain — the certificate must exist before the listener can
require it, the listener must require it before the audit line can report it, and the harness breaks
at the instant the listener requires it, so any split would land a red harness at a sub-feature
boundary. **Its split condition, if it runs long:** *SF-2a* — issuance `client` mode, the
`client_auth` schema carried end to end as `none` everywhere, the Compose secret and agent env, and
the harness amendments to `assert_verdict` and `probe_ca` written to accept both values. The tree is
green and nothing is enforced. *SF-2b* — flip `claude` to `client_auth: mtls`, render `clientca=`,
add the `user_cert` binding rule and the `idsrc` field, invert `:341-343`. That line is clean because
2a leaves every harness passing and 2b is the single enforcement flip. SF-1 is small in code but
gated on real agent runs and three API keys. SF-3 is small in either branch. SF-4 is test code, one
register amendment and two records.

## Interface Contracts

### 1. `scripts/issue-identity.sh` — extended, not replaced

The shipped interface is preserved verbatim; one mode is added.

```
issue-identity.sh ca [--force]
issue-identity.sh listener <claude|codex|agy> --ip <addr> [--force]
issue-identity.sh client   <claude|codex|agy> [--force]        # NEW
issue-identity.sh <agent>                                      # renewal, reuses recorded .ip
issue-identity.sh status
```

`client` takes no `--ip`: a client certificate carries no SAN, so there is no address to record and
no `.ip` file. Outputs land beside the existing tree:

```
mediator/identity/ca/mediator-ca.{key,crt,srl}          # unchanged, 01.3 SF-3
mediator/identity/listeners/<agent>-listener.{key,crt,ip}  # unchanged, 01.3 SF-3
mediator/identity/clients/<agent>-client.{key,crt}         # NEW
```

`mediator/identity/.gitignore` is `*` with `!.gitignore` and `!README.md`, so the new subdirectory is
already covered and no `.gitignore` change is needed. Keys are written under `( umask 077 )`.

Client certificate shape, alongside the shipped listener block for contrast:

| | Listener (01.3 SF-3) | Client (01.6 SF-2) |
|---|---|---|
| Subject | `CN=mediator-listener-<agent>` | `CN=<agent>` — the resolved-policy `identity` value |
| `basicConstraints` | `critical,CA:FALSE` | `critical,CA:FALSE` |
| `keyUsage` | `critical,digitalSignature,keyEncipherment` | `critical,digitalSignature` |
| `extendedKeyUsage` | `serverAuth` | `clientAuth` |
| `subjectAltName` | `IP:<addr>` | **none** |
| Validity | 365 days | 365 days |
| Key | RSA 2048, sha256 | RSA 2048, sha256 |

P1's verified configuration carried `tls-cafile=/pki/mediator-ca.crt` alongside
`clientca=/pki/mediator-ca.crt` (`docs/records/mediator-selection.md:390`). Both are rendered — the
same CA file in both roles — rather than assuming `clientca=` alone suffices, because the measured
line is the one that was proven to pass a client certificate.

The disjoint EKU is deliberate: a listener certificate must not pass as a client certificate and a
client certificate must not pass as a listener certificate. The subject mismatch already refuses both
directions at the `user_cert CN` ACL; the EKU is the second, independent bar, and `verify_client`
asserts it the way `verify_listener` asserts `TLS Web Server Authentication`.

### 2. Profile listener schema — one key added

```yaml
listeners:
  claude: {scheme: https, tls: true,  port: 3128, client_auth: mtls}
  codex:  {scheme: http,  tls: false, port: 3128, client_auth: none}   # or proxy_auth, on SF-1
  agy:    {scheme: https, tls: true,  port: 3128, client_auth: none}   # or proxy_auth, on SF-1
```

`client_auth` ∈ `{mtls, proxy_auth, none}`. It is added to the profile-side `for k in scheme tls
port` loop at `compile-policy.sh:810-812`, which is where `has()` checks the existing three keys —
not to the resolved-artifact field loop at `:256`, which checks only that the per-agent `listener`
key exists. It is carried into the resolved artifact inside that per-agent map:

```yaml
agents:
  claude:
    identity: claude
    listener_port: 3128
    listener: {scheme: https, tls: true, port: 3128, client_auth: mtls}
```

Validation rules:

- `client_auth: mtls` requires `tls: true` on that listener. Squid cannot request a client
  certificate on a listener that does not speak TLS, and the combination is a policy file that would
  render a mediator refusing its own agent.
- `client_auth` is **required**, not defaulted. An absent key is a compile error, not a silent
  `none` — a listener that silently stops authenticating because a key was dropped is the failure
  this field exists to make visible.
- `lint-policy.sh` gains the same two checks so the error arrives before a build.

The renderer reads `agents.<agent>.listener.client_auth` and `agents.<agent>.identity` from the
resolved policy. `identity` stops being inert here (Decision 2).

### 3. Audit line — one key's values extended, one logformat field added

The JSON line schema (01.3 Interface Contract 4) is **unchanged in shape**. `identity_source` stops
being a literal and gains two values:

```json
{"ts":"2026-09-09T12:00:00.123Z","agent":"claude","identity_source":"listener+mtls",
 "dest_host":"api.anthropic.com","dest_port":443,
 "resolved_ip":"203.0.113.10","verdict":"allow","control":null,
 "bytes_out":1234,"bytes_in":5678}
```

The intermediate contract between `proxy.conf.tmpl` and `audit-writer.sh` changes in lockstep. The
14th field is **inserted at position 2**, immediately after `%#{agent}note`, not appended:

```
logformat mediator_raw %{%Y-%m-%dT%H:%M:%S}tg.%03tuZ %#{agent}note %#{idsrc}note %#{layer}note ...
```

```bash
while IFS=' ' read -r ts agent idsrc layer control reason authority status squid bout bin sni method server extra; do
```

Appending at the end instead would land the value in the trailing `extra` var and be discarded
silently, because the short-line guard at `audit-writer.sh:63-70` tests an empty `$server`, which
would still be populated. The header field map at `:29-46` is renumbered. `%#` URL-escaping applies
to the new field like every other attacker-influenced one.

Values, and what produces each:

| Value | Produced by | Emitted for |
|---|---|---|
| `listener` | unconditional annotation on the agent's `_real` port names, and the override on the `user_cert` mismatch path | any agent with `client_auth: none`; the T34 refusal line; the self-check's own traffic |
| `listener+mtls` | annotation gated on `acl <name> user_cert CN <identity>` at the front, and rendered from `client_auth: mtls` on the inner `_real` names | `claude`, on a connection whose certificate subject matched |
| `listener+proxy_auth` | annotation gated on `acl <name> proxy_auth <user>` | an agent with `client_auth: proxy_auth`, on SF-1's result |

The T34 refusal line is stated plainly rather than left to inference. A same-CA certificate with the
wrong subject is refused by `http_access` **before** the peer is reached, so it is a pre-CONNECT
verdict and takes Interface Contract 6's 403-with-body path, with its own error template:

```json
{"ts":"...","agent":"claude","identity_source":"listener","layer":"front",
 "verdict":"deny","control":"identity","reason":"subject_mismatch",
 "policy":"policy/resolved/default.yaml", ...}
```

`control=identity` and `reason=subject_mismatch` are new tokens, and
`mediator/config/errors/ERR_MEDIATOR_IDENTITY` is their error page — the same route
`ERR_MEDIATOR_METHOD` already takes. There is **no inner line for that connection**, because it never
reached the peer.

Non-verdict lines (`event` key, no `verdict` key — `audit-writer.sh:81`, `:100-102`) carry the field
on the same terms; the mediator's own cascade-warming `connect_accepted` events (Deviation 10) are
annotated `listener`, since no client credential is involved in Squid talking to itself.

### 4. `REQUIREMENTS.md` T34 amendment — the text `/build` applies

Placed in the Acceptance Test Matrix preamble alongside the 2026-09-06 T28 and 2026-09-07 T24
amendments, in the same block shape. `/plan-feature` carries it; SF-4 applies it.

> **Amendment, 2026-09-09 (Feature 01.6 SF-4, Gate 4 criterion 5).** T34's method previously read
> *"Present agent A's client certificate for a credential bound to agent B; inspect audit lines"*.
> 01.1 SF-2 measured that only `claude` can present a client certificate at all: `codex` rejects an
> `https://`-scheme proxy URL at parse time and never reaches a TLS listener, and `agy` reaches the
> `CertificateRequest` stage with nothing to offer. For two of three agents the method names an
> artifact that does not exist, so the test is unexecutable rather than failing — the same defect
> shape as T28 and T24 above. T34 is now stated as the property it exists to protect — **an identity
> bound to one agent cannot be used by another** — and its method is split by the identity form the
> agent actually carries. For an agent with a client certificate the test is unchanged and runs
> literally. For an agent whose identity is network-derived the cross-binding case is **structural**:
> no route exists over which another agent's credential could be presented, and the method is
> enumeration of network membership rather than a presentation attempt. **R8.8 is unchanged and no
> agent is exempted** — every agent still carries a distinct identity recorded on every audit line;
> what changes is how the refusal is demonstrated for an agent that holds no presentable credential.
> The attribution strength of each form is recorded per audit line in `identity_source`, and the
> Milestone 03 brokering gate remains the cryptographic form alone (D6). See
> `docs/records/workload-identity.md`.

And the matrix row itself:

| Test | Method | Passes when | SC |
|---|---|---|---|
| T34 Per-agent workload identity | **Per identity form.** *Cryptographic:* present agent A's client certificate on agent B's listener; inspect audit lines. *Network-derived:* enumerate each agent container's network interfaces and each `internal: true` network's membership | Cross-binding is refused — by the listener for a presented credential, and by the absence of any route for a network-derived identity. Every audit line carries the issuing agent's identity and the strength of that attribution | R8.8 |

### 5. Agent-side environment and mounts — extends 01.3 Interface Contract 2

Only the rows this feature changes; everything else in that contract is unchanged.

| Variable / mount | `claude` | `codex` | `agy` |
|---|---|---|---|
| secret `<agent>-client.{crt,key}` | **mounted** — `/run/secrets/claude-client.{crt,key}` | not mounted | not mounted |
| `CLAUDE_CODE_CLIENT_CERT` / `_KEY` | `/run/secrets/claude-client.crt` / `.key` | — | — |
| Proxy URL | unchanged, `https://172.31.10.2:3128` | unchanged unless SF-1 positive **and** the userinfo form is the one that works, in which case `http://<user>:<pass>@172.31.20.2:3128` | unchanged unless SF-1 positive on the userinfo form |
| secret `mediator-credentials` (htpasswd) | not mounted | not mounted | not mounted — **mediator only**, and only if SF-1 is positive for either agent |

The htpasswd file goes to the mediator alone. Each agent receives only its own credential, and only
through the surface its client actually reads — which is what SF-1 establishes.

## Edge Cases

1. **The inner bump listener and the self-check listeners must not inherit `clientca=`.** Their
   client is Squid's own cascade hop and the self-check probe, neither of which holds a certificate.
   Rendering `clientca=` onto `entrypoint.sh:352`, `:384-385` or `:418` alongside `:351` refuses the
   mediator's own traffic at the handshake, and the symptom is stage-2 self-check failure at every
   start, not an obvious identity error. The renderer applies `client_auth` to the **front** listener
   only, and the harness asserts the self-check still passes (Phase F).

2. **A cert-less refusal produces no audit line at all.** Required-at-handshake means the connection
   dies before Squid has a request to log (measured, 01.3 SF-1). An operator debugging "claude gets
   nothing" will find silence in the audit trail rather than a denial. This is recorded in
   `mediator/identity/README.md` and in the R12.2 denial-troubleshooting section of `README.md`,
   because "no line" is a diagnostic signal here and looks identical to "the agent made no request".
   The diagnostic surface that *is* populated is Squid's own `cache_log`, at
   `$AUDIT_DIR/squid-cache.log` (`entrypoint.sh:50`), and the troubleshooting text names it — the
   audit trail is silent here by design, not by defect.

3. **Certificate expiry is a total outage for `claude`, not a degradation.** The listener refuses at
   the handshake, so an expired client certificate looks exactly like case 2. `issue-identity.sh
   status` must report client certificates alongside listener certificates with their remaining
   validity, or the 365-day bound is a trap. The renewal path is the bare-word form plus a mediator
   restart — but a client certificate renewal also needs the **agent** container restarted to re-read
   the secret, which the listener path does not, and the README says so.

4. **A 14th logformat field appended rather than inserted is silently discarded.** Named in
   Interface Contract 3 and repeated here because it produces no error: `audit-writer.sh`'s trailing
   `extra` var absorbs it and the short-line guard does not fire. The harness asserts the field's
   presence on a real line rather than trusting the render.

5. **`issue-identity.sh:75`'s `check_agent` validates against `BUMP_AGENTS=(claude codex agy)`, so
   `client codex` would be accepted** even where no `codex` client certificate has any consumer.
   `TLS_AGENTS=(claude agy)` is declared at `:71` and referenced by nothing. The `client` mode
   validates against the resolved policy's `client_auth` rather than against either array, so
   issuance and enforcement cannot disagree.

6. **Four profiles declare a `listeners:` block, not two** — `default.yaml:132`,
   `test-fixtures.yaml:59`, `test-selfcheck.yaml:65` and `oauth-mount.yaml:124`. A required
   `client_auth` key added to `default.yaml` alone fails every other profile's compile, and the
   symptoms land in three different harnesses. All four change together, and both resolved artifacts
   are regenerated in the same commit — otherwise `compile-policy-build.sh`'s drift check refuses the
   mediator image build (R5.14).

7. **T34's literal case needs a certificate that must never reach a running agent.** SF-4 issues a
   `CN=codex` client certificate to exercise the refusal. It is issued into the harness's own
   scratch, not into `mediator/identity/clients/`, and torn down with the Compose project — the
   harness already runs under `PROJECT="sf8-verify-$$"` with `trap cleanup EXIT`.

8. **SF-1's fixture must distinguish "did not send" from "sent and was refused".** A 407 with no
   retry and a client that never opens the connection look the same from the outside. The fixture
   logs the request line and the presence or absence of the header on every attempt — the way it
   already logs `cert=none` versus a peer CN — so a negative result is evidence rather than an
   absence of evidence.

9. **`agy` is unpinnable.** `verify-agent-clients.sh:247` installs it from a live manifest with no
    version flag (01.1 SF-2, recorded). SF-1's `agy` result is therefore true of the version present
    on the day it ran, and the record states that version explicitly, as criterion 5 does.

## Test Command

```
bash tests/acceptance/verify-pack-composition.sh && bash tests/acceptance/verify-pod-topology.sh && bash tests/acceptance/verify-egress-mediator.sh && bash scripts/lint-policy.sh
```

01.5's composite exactly, unchanged. Every harness this feature touches is in it: SF-2 alone edits
`compose.yaml`, `entrypoint.sh`, `audit-writer.sh`, `compile-policy.sh`, four profiles and two of
these three harnesses, and `verify-pack-composition.sh` is what drives the mediator image build whose
drift check the profile change can break.

**`verify-auth-state.sh` is deliberately not in it.** It is 01.4's harness and it does assert the
`claude` container's environment, which this feature changes — but its header warns at `:15` that
*"PHASE D COSTS THE OPERATOR THEIR HOST CODEX LOGIN"*. A test command is run unattended at feature
close; one that burns a credential is not. It is run once, by the operator, deliberately, at the end
of SF-2 — recorded here as an obligation rather than folded into a command that would otherwise be
run without thinking.

Per DD-12 the operator may adjust this at build time without gate re-approval.

Per DD-12 the operator may adjust this at build time without gate re-approval.

## Test Strategy

**SF-1 produces observations, not assertions.** It follows `verify-agent-clients.sh`'s established
disposition (`:369`): the script prints evidence, and `docs/records/agent-verification.md` carries
the recorded conclusion. There is no `pass`/`fail` helper in that script and this feature does not
add one — a capability probe that reports PASS/FAIL invites the reading that a negative is a defect,
which is exactly wrong here.

**SF-2 through SF-4 assert in `verify-egress-mediator.sh`'s idiom**: `phase`/`pass`/`fail`/`note`,
`set -uo pipefail` with failures accumulating into `FAILED`, `exit "$FAILED"` at the footer. New
assertions land in a new phase rather than being scattered through B and C, so a T34 failure is
legible at the phase boundary.

What is asserted, and why each is not covered by another:

| Assertion | Why it is needed |
|---|---|
| Cert-less connection to the `claude` front listener is refused at the TLS handshake | Replaces the placeholder `pass` at `:341-343`. The one assertion that proves verification is actually on |
| `agy` and `codex` listeners still accept a credential-less client | Proves the enforcement is per-listener and did not leak onto the other two |
| A valid `claude` client certificate is accepted and the connection reaches its allowlisted host | Proves the enabled verification did not break the working path |
| Same-CA certificate with subject `CN=codex` on the `claude` listener is refused | T34, literal case |
| That refusal produces an audit line naming it | The audit trail is the authoritative surface (`:79-82`); a refusal with no record is not a demonstrated control |
| `identity_source` reads `listener+mtls` on `claude` verdict lines and `listener` on the others | Criterion 3 — the positive half |
| **Cert-less connection produces no audit line at all**, and a same-CA wrong-subject connection produces a **front deny line** with `identity_source=listener`, `control=identity`, `reason=subject_mismatch` **and no inner line** | Criterion 3 — the half that does the work. Together these show `listener+mtls` on an inner line is unreachable without a verified, subject-matched certificate. The positive alone would also pass under a derivation uncoupled from enforcement |
| The `user_cert` mismatch deny is rendered ahead of the agent allow rules | Decision 3's first ordering constraint. If it is not, a mismatched certificate is forwarded to the peer and the inner line reads `listener+mtls` on a connection the front should have refused |
| Self-check traffic reads `identity_source: listener`, never `listener+mtls` | Decision 3's second ordering constraint — the shadow listeners share the agent's policy but not its identity |
| Each agent container holds an interface on exactly one `internal: true` network, and no agent holds one on another's | T34, structural case. Enumeration, per the amended method |
| The startup self-check still completes both stages | Edge case 1 — `clientca=` on the wrong listener breaks this and nothing else |
| The 14th logformat field appears on a real audit line | Edge case 4 — a discarded field is otherwise silent |
| `lint-policy.sh` refuses `client_auth: mtls` with `tls: false`, and refuses an absent `client_auth` | Interface Contract 2's validation rules |
| `compile-policy-build.sh` reports no drift after the profile change | The mediator image build refuses an unreviewed resolved artifact (R5.14) |

**Coverage expectation:** the composite Test Command is green end to end, and the three pre-existing
harnesses pass unchanged in intent — every amendment to them is either an inverted placeholder or an
extended expectation, not a relaxed assertion. Any amendment that *weakens* an existing assertion is
called out in the build's deviation record rather than made quietly.

## Documentation

| Document | Change |
|---|---|
| `docs/records/agent-verification.md` | **New criterion section** — proxy-credential capability for `codex` and `agy`, in criterion 5's table shape with fixture-log evidence and a "Consequence for R8.8" block (SF-1) |
| `docs/records/mediator-selection.md` | The DELAYED_AUTH open gap at `:507` is **closed on the record** with Decision 1's disposal — not needed, not fixed (SF-1) |
| `docs/records/workload-identity.md` | **New.** Per-agent identity form, the `identity_source` each produces, the lifecycle, and the Milestone 03 brokering restriction. This is the record the milestone's Definition of Done names (SF-4) |
| `mediator/identity/README.md` | Client-certificate lifecycle added to the existing lifecycle section; the subject-naming table's 01.6 row confirmed as built; the `:128` count forecast corrected (SF-4) |
| `REQUIREMENTS.md` | T34 amendment block and matrix row, per Interface Contract 4 (SF-4) |
| `README.md` | R12.2 denial-troubleshooting section gains edge case 2 — a cert-less refusal leaves no audit line, and what that looks like to an operator (SF-4) |
| `scripts/issue-identity.sh` | Header block documents the `client` mode; the truncated `--help` range is fixed (SF-2) |

**Not this feature's to write.** `.project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md`
records at `:590-620` that identity is not uniform and that "Feature 01.6 owns the resolution", and
its Open Items table carries three rows this feature closes. Updating it is a `/design` refresh, not
an edit made from inside a feature build — and 01.5 already left 20 deviations recommending one. This
feature's deviations join that queue.

## Files to Create/Modify

| File | Action | Changes |
|------|--------|---------|
| `scripts/verify-agent-clients.sh` | Modify | Go fixture gains proxy-credential modes (407, realm, header logging) on both transports; matrix gains `{codex,agy} × {header, userinfo}` (SF-1) |
| `docs/records/agent-verification.md` | Modify | New criterion section: proxy-credential capability, per-agent result table with evidence (SF-1) |
| `docs/records/mediator-selection.md` | Modify | DELAYED_AUTH gap at `:507` closed with the Decision 1 disposal (SF-1) |
| `scripts/issue-identity.sh` | Modify | `client` mode (fifth `case` arm), `client_subject()`, `issue_client()`, `verify_client()`, `status` reports client certs, `--help` range fixed (SF-2) |
| `compose/compose.yaml` | Modify | `claude-client.{crt,key}` secrets with `file:` sources; mounted to `claude` only; `CLAUDE_CODE_CLIENT_CERT`/`_KEY` env; `mediator-credentials` htpasswd secret to the mediator only if SF-3's positive branch (SF-2, SF-3) |
| `profiles/default.yaml` | Modify | `client_auth` on each `listeners.<agent>` entry, `:132` (SF-2, values revised by SF-3) |
| `profiles/test-fixtures.yaml` | Modify | Same key, `:59` — edge case 6 (SF-2) |
| `profiles/test-selfcheck.yaml` | Modify | Same key, `:65` — edge case 6 (SF-2) |
| `profiles/oauth-mount.yaml` | Modify | Same key, `:124` — edge case 6 (SF-2) |
| `scripts/compile-policy.sh` | Modify | `client_auth` in the profile-side listener `has()` loop at `:810-812`; emitted into the per-agent `listener:` map at `:827`; `mtls` requires `tls: true` (SF-2) |
| `scripts/lint-policy.sh` | Modify | `client_auth` present and valid; `mtls` implies `tls: true` (SF-2) |
| `policy/resolved/default.yaml` | Modify | Regenerated — carries `client_auth` (SF-2) |
| `policy/resolved/test-fixtures.yaml` | Modify | Regenerated (SF-2) |
| `mediator/config/errors/ERR_MEDIATOR_IDENTITY` | Create | Error page for the `control=identity` refusal — IC6's 403-with-body path, the route `ERR_MEDIATOR_METHOD` already takes (SF-2) |
| `tests/acceptance/verify-pack-composition.sh` | Modify | Only if the profile-schema change moves an assertion it makes about the compiled artifact or the build's drift check; verified at SF-2 rather than assumed (SF-2) |
| `images/mediator/entrypoint.sh` | Modify | Reads `agents.<agent>.listener.client_auth` and `agents.<agent>.identity`; renders `clientca=` plus `tls-cafile=` on the front `https_port` at `:351` only, never the inner at `:352` or the self-check at `:384-385`/`:418`; renders the `user_cert CN` binding deny **ahead of** the agent allow rules; renders the `idsrc` annotation on the `_real` port sets beside the existing `agent`/`layer` annotations at `:449-452`, `:578-585`, with the `agent=selfcheck` tag's `idsrc=listener` override after it; renders `auth_param`/`proxy_auth` on SF-3's positive branch (SF-2, SF-3) |
| `mediator/config/proxy.conf.tmpl` | Modify | `logformat mediator_raw` gains `%#{idsrc}note` at position 2 (`:243`); the "client-certificate verification is OFF" comment block at `:61-66` is replaced with what is now true (SF-2) |
| `images/mediator/audit-writer.sh` | Modify | `read -r` list gains `idsrc` at position 2 (`:62`); field map at `:29-46` renumbered; `:144` and `:153` emit the variable instead of the `"listener"` literal (SF-2) |
| `tests/acceptance/verify-egress-mediator.sh` | Modify | `assert_verdict`'s `identity_source == "listener"` at `:105` becomes a per-agent expectation; the placeholder `pass` at `:341-343` becomes a real probe; a `probe_client` variant mounting the client key pair; the five cert-less `claude` probes at `:308,315,362,391,445` present a certificate; new T34 phase (SF-2, SF-4) |
| `tests/acceptance/verify-pod-topology.sh` | Modify | Mount-set equality extended for the client secrets — the 01.3 SF-4 precedent (SF-2) |
| `mediator/identity/clients/` | Create | Output directory for client key pairs; covered by the existing `mediator/identity/.gitignore` (SF-2) |
| `docs/records/workload-identity.md` | Create | Per-agent identity form, `identity_source` mapping, lifecycle, Milestone 03 brokering restriction (SF-4) |
| `mediator/identity/README.md` | Modify | Client-certificate lifecycle; 01.6 subject row confirmed; `:128` count forecast corrected (SF-4) |
| `REQUIREMENTS.md` | Modify | T34 amendment block and matrix row, per Interface Contract 4 (SF-4) |
| `README.md` | Modify | R12.2 denial-troubleshooting gains the no-audit-line-on-handshake-refusal case (SF-4) |

## Dependencies

**On earlier features — all landed.**

- **01.1 SF-2** — the per-agent client-certificate capability table
  (`docs/records/agent-verification.md:92-118`) is the evidence this feature's identity forms rest
  on, and SF-1 extends that record rather than starting a new one.
- **01.3 SF-1** — Squid `squid-openssl 6.13-2+deb13u2` is pinned, and P1/P8 are measured. This
  feature builds on both results and re-measures neither.
- **01.3 SF-3** — the CA, its lifecycle and `scripts/issue-identity.sh`. Inherited, extended, not
  duplicated. No second CA.
- **01.3 SF-4** — the Compose secrets seam, the three `internal: true` networks and their static
  mediator addresses.
- **01.3 SF-6/SF-7** — the three-listener surface, the `myportname` selection idiom, the
  `annotate_transaction` tagging idiom and the audit writer.
- **01.5** — the policy compiler and `lint-policy.sh`, which this feature extends with one schema
  key.

**On later features — one, stated as an obligation rather than a risk.** Milestone 03's credential
brokering inherits `docs/records/workload-identity.md` as a gate: only agents recorded there as
cryptographically bound may be brokered to (D6, D13). If Milestone 03 finds that restriction
intolerable, the resolution is a register-level decision at that milestone, not a local relaxation.

**External.** SF-1 needs `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` and `GOOGLE_API_KEY` — the
`verify-agent-clients.sh` preflight exits 64 without all three — and it needs the pinned `codex`
version plus whatever `agy` version the live installer serves on the day (edge case 10). Docker
Desktop on macOS 26, Apple silicon (R11.1, A1), as for every feature in this milestone.

**No dependency on 01.4.** It is complete, and this feature does not change its authentication path.
Its harness is not in the Test Command, for the reason given there, but this feature does change the
`claude` container's environment and secret set — which `verify-auth-state.sh` asserts — so it is run
once by the operator at the end of SF-2 rather than left unrun.

## Architectural Deviations

### Deviation 1: the cascade warm-up is skipped for an `mtls` agent, and its first request after a start may be answered 500
- **What changed:** `images/mediator/entrypoint.sh` excludes any agent whose `client_auth` is
  `mtls` from `P_WARM_TARGETS`, and notes the exclusion and its consequence at every start. On
  today's artifact that is `claude`. The other fronted agent is warmed as before.
- **Originally planned:** Nothing in the plan touched the warm-up. Decision 1 mentions only the
  inner and self-check listeners as the places `clientca=` must not appear, and Interface
  Contract 3 assumes Deviation 10's `connect_accepted` warm-up events keep being produced.
- **Why necessary:** `warm_cascade` reaches its target through that agent's **front**
  `https_port` — `cache_peer_access <agent>peer allow p_<agent>_frontreal` admits nothing else —
  and it connects from inside the mediator, which holds no client key. Under required-mode
  `clientca=` that handshake is refused, so the warm-up would spend its full retry budget
  (20 attempts × 3.5s) failing at every start and then warn. The three alternatives each cost
  more than they buy, and the reasoning is in the code at the exclusion: a loopback warm port
  admitted to the same peer would put `idsrc=listener+mtls` on an inner line with no certificate
  verified anywhere on the path — the exact false attribution criterion 3 exists to prevent, and
  it would also break Decision 3's argument that the inner is reachable only through an
  authenticating front; mounting the agent's client key into the mediator would put the private
  key the Milestone 03 brokering gate rests on into two containers; and warming through the
  inner directly does not revive a peer, which is the finding the warm-up was built on.
- **Impact:** `claude`'s first request after a mediator start may be answered 500 with no peer to
  forward to, and is retried by the client. It is visible on the audit trail as a front line with
  `http_status: 500` and `verdict: allow` — not a policy refusal. Observed at this build that all
  three peers were REVIVED about a second after start when `agy`'s warm-up ran, so the 500 did
  not materialise in that run; the residual is real but not certain, and is stated as "may". SF-4
  documents it in `README.md`'s R12.2 troubleshooting section alongside edge case 2. Milestone
  02.2's adversarial acceptance inherits it. Any future agent flipped to `client_auth: mtls`
  inherits it too, which is why the exclusion is on the field rather than on the agent name.

### Deviation 2: a cert-less refusal is not literally silent on the audit trail
- **What changed:** The harness asserts that a cert-less connection to the `claude` front
  produces no **verdict** line, not that it produces no line. The measured behaviour is one
  `{"event":"proxy_internal","detail":"error:transaction-end-before-headers"}` — Squid logging
  its own aborted transaction — carrying no `agent`, no `dest_host`, no `verdict` and no
  `identity_source`, because there were no request headers to derive any of them from.
- **Originally planned:** Edge case 2 and the Test Strategy both state "a cert-less refusal
  produces no audit line at all" and "**Cert-less connection produces no audit line at all**".
- **Why necessary:** Measured at the SF-2 build against the pinned Squid. The plan's claim is
  false as written; the property it was reaching for — the trail says nothing that identifies the
  attempt — is true and is what is now asserted. An assertion written to the plan's wording would
  have failed on a correct mediator.
- **Impact:** The operator-facing conclusion is unchanged: an operator debugging "claude gets
  nothing" still finds no denial and must read `$AUDIT_DIR/squid-cache.log`. SF-4's
  `mediator/identity/README.md` and `README.md` R12.2 text must say "no verdict line, and one
  anonymous `proxy_internal` event" rather than "no line". `docs/records/workload-identity.md`
  inherits the corrected statement.

### Deviation 3: three resolved artifacts change, not two, and two of them are recompiled on the host
- **What changed:** `policy/resolved/test-selfcheck.yaml` is regenerated alongside
  `default.yaml` and `test-fixtures.yaml`. `default.yaml` came through
  `scripts/compile-policy-build.sh` (the single emitter); the two test-scoped artifacts were
  recompiled on the host with `--allowlist policy/allowlist.test.yaml --denylist
  policy/denylist.test.yaml`, per `policy/resolved/README.md`.
- **Originally planned:** Files to Create/Modify lists `policy/resolved/default.yaml` and
  `policy/resolved/test-fixtures.yaml` only, and Decision 8 item 5 says "both regenerated
  resolved artifacts".
- **Why necessary:** Three artifacts are committed and all three are compiled from a profile
  carrying a `listeners:` block, so a required `client_auth` key invalidates all three. The
  build stage cannot regenerate the two test-scoped ones: their declared bases are deliberately
  outside the mediator's build context, so `compile-stage.sh` CARRIES THEM THROUGH (01.5 SF-4
  Deviation 9) and the drift gate then compares each copy against the file it was copied from.
  Their staleness is therefore invisible to the build and had to be fixed by hand.
- **Impact:** None on the shipped enforcement path. It is a standing property worth naming: a
  schema change to the compiler is gated by the build for `default` only, and the two harness
  artifacts need a host recompile in the same commit or the harnesses run on a policy the
  mediator would refuse to load. `profiles/oauth-mount.yaml` also gained the key and has no
  committed artifact, so nothing regenerates for it.

### Deviation 4: a sixth pre-existing assertion breaks, not five
- **What changed:** `tests/acceptance/verify-egress-mediator.sh`'s control-plane mount check
  gains one exception, scoped by name to the agent's own pair:
  `*/clients/"${agent}"-client.crt|*/clients/"${agent}"-client.key`.
- **Originally planned:** Decision 8 enumerates five shipped assertions that break, "all four
  found on disk" plus the build gate. The control-plane mount check is not among them.
- **Why necessary:** That check walks every agent's `.Mounts[].Source` and flags anything
  matching `*/agent-containerization/mediator*` or `*.key`. A Compose `file:` secret is a bind
  mount, so `claude-client.key` with source `mediator/identity/clients/claude-client.key` trips
  both patterns. An agent's own workload identity is not control plane — it is read-only, it is
  what the agent authenticates with, and holding it is the point.
- **Impact:** The exception is deliberately narrow rather than a `*/clients/*` wildcard: `claude`
  mounting `agy`'s key would still be caught, and so would any other key under `mediator/`. SF-3
  must extend it in the same shape if a positive SF-1 branch delivers a per-agent credential
  file, and SF-4's structural T34 case rests on the same "one agent, one identity" property this
  exception is scoped to.

### Deviation 5: a SEVENTH pre-existing assertion breaks, in the harness the plan said to verify rather than assume
- **What changed:** `tests/acceptance/verify-pack-composition.sh` gains two changes: its
  trust-material preflight lists `mediator/identity/clients/claude-client.{crt,key}`, and its
  Phase G SC-3 check gains an exception for the agent's own client pair, in the same
  name-scoped shape as Deviation 4's.
- **Originally planned:** Files to Create/Modify says this file changes "**only if** the
  profile-schema change moves an assertion it makes about the compiled artifact or the build's
  drift check; verified at SF-2 rather than assumed."
- **Why necessary:** Verified, and the answer is yes — but for neither of the two reasons the
  plan anticipated. It makes no assertion about the resolved artifact's listener line, so the
  schema change is invisible to it. What breaks is the **Compose secret**: the harness runs
  `docker compose up` against `compose.yaml`, so the new `file:` secret source is now required
  and its absence produces a daemon path error rather than this preflight's named remediation;
  and Phase G's SC-3 check walks every agent bind source and fails anything resolving inside the
  solution root, which `mediator/identity/clients/` is. The `mediator-ca.crt` exception beside
  it exists for exactly that reason.
- **Impact:** Together with Deviation 4 this makes **seven** shipped assertions the feature
  breaks, against Decision 8's five. The two additions share one root cause worth carrying
  forward: three separate harnesses each hold their own "is this mount control plane" predicate,
  and generated trust material that legitimately lives under `mediator/` trips all three. A
  fourth agent-mounted secret would trip them again. Consolidating that predicate is a
  `/design` refresh item, not this feature's.

### Deviation 6: mount-set equality breaks in `verify-auth-state.sh` too, which no assertion in the Test Command could have caught
- **What changed:** `tests/acceptance/verify-auth-state.sh`'s `expected_mounts()` helper splits
  `claude` off from `agy`, in the same shape `verify-pod-topology.sh` uses. It is one helper
  behind four call sites, two of which assert against `claude` (Phase A's per-agent loop and
  Phase C's `claude+gitconfig` invocation) and both of which failed.
- **Originally planned:** Decision 8 item 4 anticipated mount-set equality breaking and named
  `verify-pod-topology.sh` alone. The Test Command section names `verify-auth-state.sh` as
  affected but only for the `claude` container's **environment**, and excludes it from the
  composite because its Phase D costs the operator their host codex login.
- **Why necessary:** That file holds its OWN mount-set equality assertion, independent of
  `verify-pod-topology.sh` and not delegating to it. Mounting `claude-client.{crt,key}` breaks
  it exactly as it broke the topology harness. Found by running the harness, which is the only
  way it could have been found: it is excluded from the Test Command by design, so the
  feature-completion gate would have closed green with two latent failures in a harness nobody
  runs unattended.
- **Impact:** This is the THIRD harness carrying its own copy of "what should this agent mount",
  after `verify-pod-topology.sh` and `verify-pack-composition.sh` — the same duplication
  Deviations 4 and 5 named, in its third spelling. It also exposes a standing gap worth naming
  for the milestone rather than this feature: an assertion excluded from the Test Command is an
  assertion the completion gate cannot protect, and `verify-auth-state.sh` is excluded for a
  good reason that does not stop it from rotting. Carrying a cheap mount-set-only mode of that
  harness into the composite is a `/design` refresh candidate. **`claude`'s eight passing
  authentication cells and the whole AUTH_MODE matrix (T24) were unaffected by SF-2**, which is
  what the run confirms beyond the two mount lines.

### Deviation 7: a `proxy_auth` refusal is 407, never 403, so it takes no error-page route at all

- **What changed:** A `client_auth: proxy_auth` listener renders **no** `deny_info` route, no
  `ctl_identity` term and no error page. Its refusal is Squid's own `407 Proxy Authentication
  Required` challenge. `mediator/config/errors/ERR_MEDIATOR_IDENTITY` stays in the tree and stays
  the `mtls` subject-mismatch page; nothing was added beside it.
- **Originally planned:** Interface Contract 3 gives the identity refusal a `control=identity`,
  `reason=subject_mismatch` verdict line and its own error template on "IC6's 403-with-body path,
  the route `ERR_MEDIATOR_METHOD` already takes", and Decision 7's positive branch describes the
  proxy-credential path in the same terms as the certificate one.
- **Why necessary:** Measured, not reasoned about. P9 (`docs/records/mediator-selection.md`, run
  against the shipped mediator image at this build) put a credential-less, a wrong-username and a
  wrong-password request to a plain `http_port` and to three `https_port`s, one of which carried a
  `deny_info`-eligible ACL last. **Every one of the twelve cells returned 407.** A missed
  `proxy_auth` ACL makes Squid answer its own challenge before any rule that could name an error
  page is reached, so a 403 route here would be configuration that never executes.
- **Impact:** The two refusal forms differ in kind on the audit trail and the harness asserts each
  literally. `mtls`: 403, `control=identity`, `reason=subject_mismatch`, a body. `proxy_auth`: 407,
  `control` and `reason` both null, no body. That difference is worth keeping rather than papering
  over — 403 means "policy refused this destination", 407 means "this listener wants a credential",
  and an operator reading the trail needs to be able to tell them apart. SF-4's
  `docs/records/workload-identity.md` must state both shapes, and the R12.2 troubleshooting section
  gains the 407 case alongside SF-2's silent-handshake one.

### Deviation 8: the attribution annotation is baseline-then-upgrade, because the `mtls` idiom does not transpose

- **What changed:** A `proxy_auth` listener renders an **unconditional** `idsrc=listener`
  annotation on the agent's `_real` port set, then **overrides** it to `listener+proxy_auth` on a
  separate rule gated on the credential ACL. The enforcement deny is rendered **bare** —
  `http_access deny p_<agent>_frontid !cred_<agent>` — with no annotation or reason term after the
  negated credential ACL.
- **Originally planned:** Decision 3's table says the front annotates "per request, on SF-1's
  branch: `listener+proxy_auth` gated on `proxy_auth`, else `listener`", and SF-2 built exactly
  that shape for `mtls`: annotate the strong value on the match, override to the weak value on the
  miss path, with `rsn_subject ctl_identity` trailing the same deny line.
- **Why necessary:** That shape produces an audit line with **no attribution value at all**. P9
  measured it directly: on the port carrying the transposed idiom, the 407 line logged `idsrc=-`.
  A `proxy_auth` ACL that misses halts ACL evaluation on its line — Squid raises the
  authentication requirement immediately — so every term after `!cred_<agent>` is unreachable,
  annotations included. The same measurement showed the baseline-then-upgrade port logging
  `idsrc=listener` on its 407s and `idsrc=listener+proxy_auth` on its 200, which is criterion 3's
  requirement met. `annotate_transaction key=value` replaces rather than appends, so last-wins is
  what makes the override an override — the same property SF-2's self-check override relies on.
- **Impact:** Decision 3's soundness argument is unchanged and still holds: `idsrc` and the
  enforcement come from the same `client_auth` field in the same renderer pass. What changes is
  the rule shape, and the inner listener's per-listener annotation now rests on one extra step
  worth naming — Squid does not forward `Proxy-Authorization` to a `cache_peer` parent, so the
  inner cannot re-check the credential and trusts the front. It may, because the bare enforcement
  deny refuses a credential-less request at that front *before* any rule that can forward. Remove
  that deny and the inner annotation becomes false; it is not optional decoration.

### Deviation 9: the cascade warm-up is skipped for a `proxy_auth` agent too, so `agy` joins `claude`

- **What changed:** The warm-up gate widened from `client_auth != mtls` to `client_auth == none`.
  `agy`'s cascade peer is no longer warmed, and the start-up notice names the credential rather
  than the certificate. `codex` is unaffected — a single-listener agent has no cascade to warm.
- **Originally planned:** SF-2's Deviation 1 scoped the skip to `mtls` alone.
- **Why necessary:** The same argument, one credential form over. The warm-up reaches its target
  through that agent's own front listener, because `cache_peer_access <agent>peer` admits nothing
  else — and that listener now demands a credential the mediator cannot produce. The mediator holds
  the **htpasswd**, which is hashes; it cannot construct a credential to answer its own 407 with.
  The three alternatives SF-2 rejected are rejected again for the same reasons: a loopback warm
  port admitted to the peer would log `idsrc=listener+proxy_auth` with nothing authenticated;
  giving this container `agy`'s plaintext would put that agent's entire identity in a second
  container; and warming through the inner directly does not revive the peer.
- **Impact:** `agy`'s first request after a mediator start may be answered 500 and retried, exactly
  as `claude`'s may. Observed at this build — the first credential-bearing `agy` probe returned 500
  — so `verify-egress-mediator.sh` gained `retry_cold_peer`, which retries **only** a 500, at most
  twice, and `note`s each retry. It retries nothing else: a 403 or a 407 is a result, and
  swallowing one would make the assertion a tautology.

### Deviation 10: the credential is delivered by the agent entrypoint, which moved out of the published base image

- **What changed:** Two things, and the second is the consequential one. (1) The proxy credential
  reaches its agent as a Compose secret holding `<username>:<password>`, which
  `images/entrypoint.sh` splices into `HTTPS_PROXY`/`HTTP_PROXY` (and the lowercase pair) at start;
  the URLs in `compose.yaml` stay credential-free, and so does `docker inspect`. (2) To make that
  possible, `COPY images/entrypoint.sh` and the `ENTRYPOINT` instruction **moved from the
  `agent-base` stage to `agent-packs`**.
- **Originally planned:** Interface Contract 5's "Proxy URL" row reads
  `http://<user>:<pass>@172.31.20.2:3128`, which reads most naturally as a literal in
  `compose.yaml`. Nothing in the plan anticipated touching `images/Dockerfile` at all.
- **Why necessary:** Found by building. SF-1 established that neither client exposes a knob for
  supplying a proxy credential and that both construct `Proxy-Authorization` from the proxy URL
  themselves, so the URL is the only surface — but a literal in `compose.yaml` puts a bearer secret
  in a committed file, and compose interpolation would need a second `--env-file` threaded through
  ~15 documented commands and three harnesses and would still land the credential in
  `docker inspect`. The entrypoint was the better home. It then did not work: `agent-base` is
  pulled from GHCR by digest (01.5 SF-6b, D21), BuildKit skips a stage nothing references, so the
  edit reached nothing — all three agents rebuilt and `verify-pod-topology.sh` reported the splice
  had not happened, because the image still carried the published copy. **SF-3 is the first change
  to a base-image file since the digest pin landed**; the pin (2026-09-09) is newer than every
  earlier edit to that file (last 2026-09-08), so no precedent existed. The move follows the one
  that does exist: `SKEL_MARKER` moved out of `agent-base` into `agent-packs` at 01.5 SF-6b, for
  this exact failure mode. **Operator-confirmed at the build.**
- **Impact:** D21 is intact in what it protects — the base an operator runs is still the base CI
  built and attested, and this stage already layers locally-derived content on it (pack-install,
  the profile's packages, `SKEL_MARKER`). What changes is that the pod's start-up logic is now
  repository-versioned rather than digest-pinned, which is the right ceremony for a 145-line shell
  script and the wrong one for a supply-chain base. The entrypoint was **moved, not duplicated**:
  a copy in both stages would leave the published one dead, the local one silently winning, and an
  operator no way to tell which ran. The published base no longer carries an `ENTRYPOINT`, so it is
  not independently runnable — nothing runs it directly, but CI's `--target agent-base` build now
  produces an image that is a rootfs rather than a runnable one, and `README.md`'s
  "What a local build now pulls" section should say so. **CI was checked before the move, not
  after**: `.github/workflows/agent-sandbox-image.yml` holds no `docker run`, no smoke step and no
  `--version` invocation against the built base -- `publish-base` builds and pushes it and nothing
  more -- so removing the `ENTRYPOINT` cannot fail that workflow. **`images/bootstrap-auth.sh` was
  deliberately left in `agent-base`** and carries the same latent property; it is not broken, so
  moving it would be a change nothing asked for. A note at that `COPY` records the trap for the
  next feature that needs to edit it.

### Deviation 11: the credential secret carries the username as well as the password

- **What changed:** `mediator/identity/credentials/<agent>.cred` holds `<username>:<password>` —
  the whole userinfo string — and the entrypoint splices it in verbatim.
- **Originally planned:** Decision 6 and Interface Contract 5 describe "each agent's own
  credential" without saying what is in the file; the natural reading is the secret alone, with the
  username derived at each end.
- **Why necessary:** The username the mediator matches is the **resolved policy's `identity`**, and
  the only token available inside an agent container that resembles it is the image-baked
  `AGENT_NAME`. They are equal in every shipped profile and nothing keeps them equal — an agent
  container cannot read the resolved policy, which is control plane it must not mount. Deriving the
  username there would put a silent wrong-username 407 one profile edit away, on a path whose
  failure mode is "this agent reaches nothing". Issuance writes it; delivery does not guess it, and
  `issue-identity.sh` verifies the file's username against the policy each time it issues.
- **Impact:** None outward. `rebuild_htpasswd` reads the username from the file rather than the
  policy, so the two halves of one credential cannot disagree after a profile edit; `credential
  <agent>` is what re-reconciles them and it checks the policy when it does.
