# Feature Plan: Egress mediator

**Milestone:** 01 - Sandboxed Pod
**Feature:** 01.3: Egress mediator
**Status:** Planned
**Date:** 2026-09-04

## Summary

Builds the single enforcement point (R1.2, D1). One multi-homed `egress-mediator` container joins
all three `internal: true` agent networks and the external network, and becomes the only path out
of the pod. It carries four of the component's five roles: the Layer-7 CONNECT/SNI policy engine
evaluating D5's three controls in order, the authoritative pod resolver (D3), the audit writer
(D12), and per-agent mTLS workload identity (D6, R8.8). The fifth role — upstream credential
brokering — is Milestone 03 and is out of scope here.

01.2 left a pod that starts, is hardened, and has **no route out at all**. 01.3 gives it exactly
one route, default-deny, logged. Until 01.4 lands, no agent can authenticate to a provider, so
this feature is verified against synthetic destinations and the agents' unauthenticated startup
traffic — not against a working agent session. That bound is stated in Test Strategy and is not
claimed anywhere in the acceptance criteria.

## Acceptance Criteria

Restated from the milestone README with implementation detail added. The README is authoritative
where the two differ. Three criteria below record an **interpretation** of a README statement that
cannot be implemented as literally written; each is marked and is a review decision, not a silent
resolution.

1. **Single path out, no management surface (R1.2, § Mediator hardening).** One
   `egress-mediator` service is attached to `claude-net`, `codex-net`, `agy-net` and `egress-net`.
   No agent container is attached to `egress-net` (01.2's assertion, re-run here).

   **Interpretation — "exactly one port to each agent network".** The mediator must also own DNS
   (D3, R5.4, criterion 4), and a resolver is a second listener. The two statements cannot both
   hold literally. The criterion is implemented as the README's own parenthetical: *no management
   port and no metrics port on any agent network*. The permitted listener set per agent network is
   exactly two — the proxy listener and the resolver — and the smoke check asserts that set by
   enumeration, so a third listener is caught rather than assumed absent. **The cost is stated, not
   waved away:** a resolver is a second protocol parser reachable from inside the blast radius, and
   the architecture's one-port rule exists to minimise exactly that. The trade is accepted because
   D3 and R5.4 make owning DNS mandatory and the alternative — leaving Docker's embedded resolver
   pointed at the host's upstreams — is a live exfiltration channel, which is strictly worse than
   one additional parser. Any management, metrics,
   admin or health endpoint binds the loopback interface inside the mediator, never an agent
   network.

2. **Three controls, evaluated in order (D5).** Per connection:
   (1) default-deny allowlist matched on the CONNECT hostname and the TLS SNI (R5.2, R5.5), never
   an IP set resolved once (R5.5's explicit bar); (2) post-resolution deny where **deny wins**
   (R5.3, R5.7) covering CIDRs **and FQDNs** (R5.1 — see criterion 10); (3) per-agent ceilings on
   **concurrent connections, connection rate and byte rate**. Control 3 exists because a runaway
   loop against the model API generates *only allowlisted traffic* and is invisible to controls 1
   and 2 (D5 rationale) — but under D4's splice the mediator counts connections and bytes, never
   requests, which bounds D5's rationale rather than satisfying it. See the Edge Cases entry
   "Control 3 is weaker than D5's rationale assumes".

   The allowlist is keyed **per agent**, never a union (01.1 SF-3's contract). Which agent a
   connection belongs to is therefore an input to control 1, not only to the audit line — see
   criterion 6 and Interface Contract 3.

3. **Non-HTTP protocols (R5.9, R5.10).** `Upgrade` on TCP/443 is available to Codex. Under D4's
   splice-only decision this is structural rather than configured: a CONNECT tunnel is opaque, so
   the WebSocket upgrade is invisible to the mediator and cannot be stripped. The criterion is
   therefore verified **behaviourally** — Codex's default WebSocket transport completes through the
   mediator — not by inspecting a configuration flag. R5.10 (SHOULD) is likewise structural: agent
   networks have no default route, the mediator forwards nothing (`net.ipv4.ip_forward=0`, asserted),
   and the only forwarder is the proxy, which speaks CONNECT. ICMP and arbitrary UDP have no path,
   by construction rather than by rule. Telemetry endpoints are absent from the allowlist and
   disabled at the agent (R5.11; `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` was already set in 01.2).

   **The listener accepts CONNECT only; every other method is refused.** This is not tidiness.
   `HTTP_PROXY` pointing at the mediator means a plain `GET http://host/` would arrive as an
   absolute-URI request inside the proxy-hop TLS, and the mediator would hold that request and its
   response in plaintext — contradicting criterion 5's "holds no plaintext" and creating exactly the
   content-inspection capability D4 states this architecture does not have. Refusing non-CONNECT
   methods is what keeps D4 true, and it tightens R5.10. The compiler additionally flags any
   allowlist entry whose port is not 443: one would be a design question, not a config detail.

4. **The mediator owns DNS (R5.4, D3).** Each agent service declares `dns:` pointing at the
   mediator's static address on its own network. This is the criterion's real content:
   `internal: true` withholds the default route but does **not** remove Docker's embedded resolver
   at `127.0.0.11`, which forwards to the daemon's configured upstreams — a path that leaves the
   host without traversing the container's routing table, and therefore a DNS exfiltration channel
   `internal: true` does not close (observed in 01.2, criterion 1). Setting `dns:` replaces those
   upstreams with the mediator alone.

   The pod resolver is a **closed forwarder**: a query whose name is an exact match for an entry in
   that agent's resolved allowlist is forwarded to a named upstream on `egress-net`; every other
   query returns REFUSED and is forwarded nowhere. It must forward the allowlisted names — it is not
   authoritative for `api.anthropic.com` — and the control is the refusal of everything else. An
   open forwarder reachable only from the pod would still carry arbitrary encoded labels to the
   internet, which is exactly what R5.4 rejects filtering as insufficient against. Note that under
   `HTTPS_PROXY` an agent normally does not resolve its destination at all — the mediator does — so
   answering allowlisted names is a convenience for clients that resolve anyway, and the refusal of
   everything else is the control.

   **The resolver re-originates; it does not proxy the client's packet.** An exact-match allowlisted
   name is still an attacker-controlled query envelope: mixed-case QNAME (0x20 encoding), EDNS
   options including client-subnet, and QTYPE selection all carry bits to an upstream the agent does
   not otherwise reach. The resolver therefore constructs a fresh query from the canonicalised
   (lowercased) name, restricts QTYPE to `A` and `AAAA`, and drops every EDNS option it did not
   originate. Restricting QTYPE also structurally denies `HTTPS`/`SVCB` retrieval, which is what an
   Encrypted ClientHello configuration would arrive in — see the domain-fronting edge case.

   **Every DNS decision is audited** — name, QTYPE, verdict, agent — to the same sink as the egress
   log (R9.1's "every outbound connection attempt", and the detection signal that partly compensates
   for the blind spot in criterion 7). Static addressing requires `ipam` subnets on the three agent networks and
   an `ipv4_address` for the mediator on each — Compose `dns:` takes an address, not a name.

5. **TLS spliced, never terminated for destination traffic (R5.15, R5.13, D4) — T28.** The
   mediator validates the destination at CONNECT/SNI and passes the connection through
   undecrypted. It holds no plaintext. Antigravity traffic is never intercepted.

   **Interpretation — "no mediator CA is presented to any agent".** Criterion 6 requires each agent
   to present a client certificate to the mediator, which requires the agent→mediator proxy hop to
   itself be TLS, which requires the agent to trust the listener's server certificate — issued by
   the mediator's CA. The literal reading of T28 and the R8.8 mechanism are mutually exclusive.
   T28 is implemented as the property it exists to protect: **no mediator CA appears in any
   destination TLS chain.** The agent validates the origin's own certificate for every destination;
   no destination chain terminates at a mediator CA; the mediator holds no destination plaintext.
   The proxy-hop anchor is a separate, single, explicitly recorded trust addition, distributed
   through R5.12's documented per-agent mechanisms (`NODE_EXTRA_CA_CERTS`, `CODEX_CA_CERTIFICATE`).
   **This is not TLS interception** and R5.13's permanent bar on intercepting Antigravity traffic is
   untouched — `agy`'s destination traffic is spliced like every other agent's.

   **Decided at this gate: T28 is amended in `REQUIREMENTS.md`, not merely reinterpreted here.** The
   two statements are both in the authoritative register, and one of them has to give — a plan-local
   reading would leave the register carrying a pass criterion the ratified R8.8 mechanism can never
   meet. T28's pass text becomes: *no mediator CA appears in any destination TLS chain; the mediator
   holds no plaintext; Antigravity traffic is never intercepted* — with the single proxy-hop trust
   anchor recorded as an explicit exception. R8.8 is unchanged. The amendment is a register change
   and is tracked on this feature's review checklist.

6. **Per-agent workload identity (R8.8, D6) — T34.** Identity is established in two layers, and
   the distinction matters because the cryptographic layer depends on an 01.1 result that does not
   yet exist:

   - **Network-derived identity (structural, always available).** Each agent network carries
     exactly one agent container and the networks are disjoint (01.2 criterion 1, re-asserted). A
     connection arriving on the mediator's `claude-net` interface can only be the `claude`
     container. The mediator runs one listener per agent network, so the listener itself selects
     the per-agent allowlist and rate-limit bucket. This layer cannot be forged by another agent
     because no agent has an interface on another agent's network.
   - **Cryptographic identity (mTLS client certificate).** Satisfies R8.8's "distinct workload
     identity with a defined lifecycle, used for authentication to the enforcement point and
     recorded in the audit log". Each agent is issued a distinct certificate; the mediator verifies
     it against the CA and **refuses any connection whose certificate subject does not match the
     listener it arrived on** — that refusal is T34's cross-binding case, exercisable in 01.3 even
     though no brokered credential exists until Milestone 03. The subject is recorded on every
     audit line.

   The two-layer split is deliberate: it keeps controls 1–3 and the audit trail working on
   structural identity regardless of 01.1 SF-2's client-certificate result, while keeping R8.8's
   cryptographic requirement a MUST that is met or is escalated. It is **not** a fallback that
   lets R8.8 go unmet — see Dependencies.

7. **Audit (R9.1, R9.2, R9.3, R9.4, D12) — and T16's input.** Every outbound attempt is logged with
   destination, verdict and timestamp, **blocked attempts included**, to a sink no agent container
   can reach or alter. The sink is a named volume mounted into the mediator only, plus the
   container's stdout; no agent mounts it, asserted by enumeration. Denials are surfaced with a
   clear, actionable message naming the blocked destination (R9.3, R12.2) and rules REJECT rather
   than DROP (R9.4) — for a CONNECT proxy that means an immediate HTTP 403 whose body names the
   destination and the control that refused it, never a silent hang or a dropped packet.

   **R9.1 is satisfied for attempts that reach the mediator, and not for attempts that do not.**
   An agent that unsets its proxy variables and opens a raw socket fails with `ENETUNREACH` inside
   its own network namespace — the packet never reaches the mediator, so no audit line exists. The
   structural control (criterion 3) and the detection control (R9.1) are in tension here: the more
   completely the route is absent, the less there is to observe. R9.1 calls the blocked attempt
   "the detection signal for a compromised agent", so this is a real reduction in detection, not a
   technicality. It is recorded as a residual rather than designed around: closing it would mean
   giving agent networks a default route to the mediator so it can REJECT-and-log non-CONNECT
   traffic, which converts the enforcement point into a router and contradicts criterion 3's
   `ip_forward=0` assertion — a worse trade. The mitigation that *is* taken: the DNS path is logged
   (criterion 4), so an agent probing for destinations is usually visible in the resolver log even
   when its raw connection attempt is not, and Milestone 02's adversarial validation is where the
   size of the blind spot gets measured. See the Edge Cases entry
   "Egress attempts that never reach the mediator are invisible to R9.1".

   **Scope limit.** R9.7's agent action log and its recorder (D20, T35) are not part of this
   feature — the milestone README assigns 01.3 the egress log only. R9.8's session-ID correlation
   is likewise bounded: nothing in the CONNECT protocol carries the agent's session identifier, so
   the egress log correlates by agent identity and timestamp, and session-ID correlation waits on
   the action recorder. Recorded as a known limit, not claimed.

8. **Startup self-checks (R9.5) — T17.** Two stages, with different failure semantics:
   - **Stage 1, unconditional and fatal.** The resolved policy is schema-validated and
     self-consistency-checked before any listener binds. A corrupt or unparseable policy aborts
     startup with a clear error naming the file and the failing field. This is T17.
   - **Stage 2 runs through the rendered proxy, not around it.** The proxy binds first; the check
     then probes *through* it from a self-check listener on the mediator's loopback interface
     (consistent with criterion 1 — never an agent network). Checking before the proxy binds would
     test only a re-implementation of the policy, so a rendering bug in `proxy.conf.tmpl` would pass
     silently while T17 caught nothing but malformed YAML.
   - **Stage 2, reachability.** A known-denied destination must fail **by policy** and a known-allowed
     destination must succeed. The denied target is `169.254.169.254:443` — a denylist hit that is
     resolvable and would otherwise connect; a `.invalid` name would fail on resolution instead and
     prove nothing about the policy. Stage 2 requires working internet at startup; on an offline host it
     would abort a pod that is otherwise correct. It is therefore skippable **only** through an
     explicit `startup_check.offline: true` in the profile, which is recorded in the audit log at
     every start. R9.5 is a SHOULD, which is what makes the recorded exception defensible; the
     stage-1 abort is not skippable.

9. **Secrets and key material (R8.1, § Mediator hardening).** No secret is baked into an image
   layer. The mediator's listener keys and the CA **public** certificate are delivered at runtime
   through Compose `secrets:` with a `file:` source — the available runtime-injection mechanism on
   Docker Desktop, named plainly here rather than described as "a secret manager". Per-agent client
   certificates are delivered the same way, each scoped to exactly one service. Private key
   material is git-ignored.

   **The CA private key never enters the mediator.** Issuance is an offline operator script; the
   mediator holds only the CA certificate it verifies against. This is narrower than the
   architecture document's "CA private key ... injected at runtime from a secret manager" and moves
   in the safer direction — a mediator compromise no longer yields the ability to mint agent
   identities. Recorded here as a decision for review, and carried into the architecture document's
   open-items table by SF-3.

10. **R5.1 gap — `deny_fqdns` (defect found at plan time).** R5.1 is a MUST: *"The policy supports
    denying specific IP addresses, CIDR ranges and FQDNs."* 01.1's approved interface contract for
    `policy/denylist.base.yaml` states the opposite — *"No `deny_fqdns` field: R5.3/R5.7 and D5
    specify post-resolution CIDR deny, and nothing in the register asks for FQDN-level deny."*
    R5.1 does ask. 01.3 carries the correction: the resolved-policy schema and the mediator both
    support FQDN deny with deny-wins precedence, and SF-2 adds the empty `deny_fqdns: []` field to
    `policy/denylist.base.yaml`. Adding an unused-but-supported field is the minimum that closes a
    MUST; no entries are invented for it.

    **Decided at this gate:** 01.1's plan is already approved at Gate 4 and carries a statement that
    is false against R5.1. The operator's decision is to **re-plan 01.1 in revision mode** once this
    gate closes, correcting its Interface Contracts so the approved contract on disk stops
    contradicting a MUST. Tracked as a checklist item here; the re-plan itself is a separate
    `/plan-feature` invocation.

11. **Smoke checks:** T3 (HTTP/HTTPS exfiltration refused and logged), T4 (DNS exfiltration — no
    query arrives at a controlled authoritative server), T5 (raw TCP to a non-allowlisted host and
    port refused), T6 (CDN rotation — a denied domain sharing an allowed domain's IP is refused),
    T7 (`169.254.169.254` refused), T8 (policy tampering from inside all fail). Plus T17, T28 and
    T34 from the criteria above. These are prerequisite checks here; **02.2 owns them as recorded
    adversarial acceptance** and this feature does not claim adversarial validation.

## Approach

### Selection before construction

The architecture names two candidate implementations — `iron-proxy` (Go, Apache-2.0) or Squid in
CONNECT-allowlist mode — and ratifies neither. Every subsequent sub-feature is shaped by that
choice, and three of the six properties below are MUSTs whose absence would not be discovered until
the last sub-feature. SF-1 therefore verifies the selected implementation against all six before
anything is built on it:

| # | Property | Requirement | Why it can fail silently |
|---|---|---|---|
| P1 | Client-certificate verification on the listener, with the subject available to policy and log | R8.8, D6 | Many proxies authenticate clients with `Proxy-Authorization`, not TLS identity |
| P2 | Post-resolution address deny applied to **the address the proxy actually connects to** | R5.7, D5 | A proxy that checks one resolution and connects on another fails rebinding, which is D5's stated reason for control 2 |
| P3 | Per-client **concurrency, connection-rate and byte-rate** ceilings | D5 control 3 | Request-rate limiting is unavailable under splice (see Edge Cases); byte rate is the substitute, and not every proxy exposes it per client |
| P4 | Client identity on every access-log line, allow and deny alike | R9.1, R8.8 | Deny paths frequently log less than allow paths |
| P5 | An immediate, body-bearing refusal naming the destination | R9.3, R9.4, R12.2 | Default proxy error pages name the proxy, not the blocked destination |
| P6 | SNI observable and comparable to the CONNECT host **without decrypting** | R5.5, R5.15 | See the domain-fronting edge case below |

Squid is the primary candidate: CONNECT-allowlist splicing is its native mode rather than a
feature, and it has documented directives that plausibly cover all six (`https_port` with
`clientca=`, `dstdomain`/`dst` ACLs, `acl maxconn` and `delay_pools`, `logformat` with TLS
client-certificate fields, `deny_info`, and `ssl_bump peek`+`splice` for P6). **Every one of those
is a hypothesis to be tested in SF-1, not an asserted capability.** `iron-proxy` is the recorded
fallback. Each property gets a pass/fail and, where it fails, either the alternative implementation
or an explicitly recorded gap — the same discipline 01.1 SF-2 applies to the agent clients, and for
the same reason: cheap to establish here, expensive to discover in SF-6.

### Request path, as built

```text
agent process
  → HTTPS_PROXY=https://<mediator-ip-on-that-net>:3128   (TLS proxy hop, client cert presented)
  → agent-net (internal: true — no other route exists)
  → mediator listener for THAT network
      ├─ TLS: verify client cert against CA; refuse if subject != this listener's agent   (R8.8, T34)
      ├─ select this agent's allowlist and rate bucket from the listener            (per-agent, not union)
      ├─ control 1: CONNECT host on allowlist? and SNI == CONNECT host?             (R5.2, R5.5)
      ├─ resolve via the mediator's own resolver
      ├─ control 2: resolved address in deny_cidrs, or host in deny_fqdns? deny wins (R5.3, R5.7, R5.1)
      ├─ control 3: per-agent concurrency / connection rate / byte rate               (D5)
      ├─ audit line {ts, agent, cert subject, host, port, resolved ip, verdict, control}
      └─ splice: opaque tunnel, no decryption                                        (R5.15, D4)
  → egress-net → destination
```

A refusal at any control writes `verdict=deny` with the refusing control named, and returns HTTP
403 with a body naming the destination. The agent sees an error it can act on rather than a hang.

### DNS path

`dns:` on each agent service redirects Docker's embedded resolver upstream to the mediator. The
mediator's resolver answers only names present in the resolved allowlist for that network's agent
and returns REFUSED otherwise. Container-name resolution continues to be handled by the embedded
resolver locally and never reaches the mediator, so closing the resolver does not break service
discovery within the pod.

### Policy compilation

01.3 needs a resolved policy artifact to exist before 01.5 builds the compiler into the mediator
image. SF-2 therefore ships `scripts/compile-policy.sh` in its degenerate, zero-pack form: it reads
`policy/allowlist.base.yaml` and `policy/denylist.base.yaml` plus `profiles/default.yaml` and emits
`policy/resolved/default.yaml`, the committed SC-6 artifact. 01.5 moves that invocation into a build
stage of the mediator image (D10) and adds pack composition; the artifact's schema is fixed here so
01.5 has a target rather than a blank sheet. The mediator's entrypoint renders its native
configuration from the resolved artifact, so the proxy configuration is generated and never
hand-edited (SC-6).

### Ordering within the feature

SF-1 gates everything. SF-2 (the policy artifact) must precede SF-4 (the resolver reads the
allowlist to know what to answer) and SF-5 (the controls read it). SF-3 puts the container on the
networks. SF-6 adds the cryptographic identity layer on top of the working structural one, so a
negative 01.1 client-certificate result affects one sub-feature rather than the design of five.
SF-7a closes the mediator itself with audit, denial surface and self-checks, and SF-7b is the
harness that proves the whole.

## Sub-Features

- [ ] **SF-1: Mediator implementation selection, verified** — Verify the selected proxy against P1–P6
  above on a throwaway fixture, and record each result in
  `docs/records/mediator-selection.md` whether it passes or fails. Produces a record and a decision,
  not shipped code. Gates SF-2 to SF-7b. Discovery-shaped and small by design; it exists because a
  failure on P1, P2 or P6 changes what SF-5 and SF-6 build rather than how well they build it.
  **Records the exact proxy version every property was verified against**, and SF-3 pins to that
  version — the same discipline R10.3 and R7.18 apply to the agents. A verification against one
  major and an unpinned install of the next silently invalidates the design, because the directives
  these properties rest on are version-scoped.
  Depends on 01.1 SF-2's client-certificate result for P1's agent-side half.

- [ ] **SF-2: Resolved-policy contract and degenerate compiler** — The resolved-policy schema
  (Interface Contract 1), `scripts/compile-policy.sh` in its zero-pack form, the committed
  `policy/resolved/default.yaml`, the schema validator the mediator's stage-1 self-check calls, and
  the `deny_fqdns` addition to `policy/denylist.base.yaml` closing the R5.1 gap. Also adds the
  per-agent `rate_limits` and `startup_check` keys to `profiles/default.yaml`. Depends on 01.1 SF-3
  for the base policy files and on 01.2 for the profile schema.

- [ ] **SF-3: Mediator image, compose seam and hardened runtime** — `images/mediator/Dockerfile` and
  its entrypoint, the `egress-mediator` service on four networks, `ipam` subnets with a static
  mediator address per agent network, the `dns:` and `HTTPS_PROXY`/`HTTP_PROXY`/`NO_PROXY` additions
  to the three agent services, Compose `secrets:` wiring, the audit volume mounted to the mediator
  alone, and `.gitignore` for private key material. Carries the mediator's D15 hardening plus the
  **port-53 binding deviation** — `sysctls: net.ipv4.ip_unprivileged_port_start=0` preferred so
  `cap_drop: ALL` survives, `cap_add: NET_BIND_SERVICE` as the recorded fallback if the sysctl is
  not permitted on Docker Desktop. **Verifies, does not assume, that `dns:` actually redirects Docker's embedded resolver to a
  container address on an `internal: true` bridge** — that redirect is the whole of D3's mechanism,
  and it is confirmed by capture on the mediator, not by reading Compose documentation. The port-53
  binding path is verified the same way.
  **Amends `tests/acceptance/verify-pod-topology.sh`** — 01.2's
  mount-set *equality* assertion fails the moment a client-certificate secret is mounted, so the
  allowed set is extended here rather than left to break. Depends on SF-1 and SF-2.

- [ ] **SF-4: Pod DNS authority** — The closed forwarder: exact-match allowlisted names
  re-originated as canonicalised `A`/`AAAA` queries to a named upstream, everything else REFUSED and
  forwarded nowhere, every decision audited. Rejects wildcard allowlist entries at compile time (see
  Edge Cases). Includes the T4 fixture — a controlled authoritative
  server the test asserts receives no query. Depends on SF-2 and SF-3.

- [ ] **SF-5: The three egress controls** — Control 1 (per-agent allowlist at CONNECT/SNI, with the
  SNI-vs-CONNECT-host comparison per SF-1's P6 result), control 2 (post-resolution `deny_cidrs` and
  `deny_fqdns`, deny wins), control 3 (per-agent concurrency, connection-rate and byte-rate
  ceilings), the CONNECT-only method restriction, and the per-network listener that selects among
  the per-agent policies. Covers T3, T5, T6, T7. Depends on
  SF-3 and SF-4.

- [ ] **SF-6: Per-agent workload identity** — Offline CA and `scripts/issue-identity.sh`, the
  per-network TLS listeners with client-certificate verification, the subject↔listener binding
  refusal, per-agent trust distribution through R5.12's mechanisms, and the certificate lifecycle
  (subject naming, validity, renewal path). Covers T28 and T34. **This sub-feature is where a
  negative 01.1 client-certificate result lands** — see Dependencies. Depends on SF-5.

- [ ] **SF-7a: Audit writer, denial surface and startup self-checks** — The audit line schema
  (Interface Contract 4) and the writer behind it, the 403-with-destination denial surface
  (Interface Contract 6), both stages of the startup self-check, and the loopback self-check
  listener stage 2 probes through. Product code, and the last piece of the mediator itself.
  Depends on SF-5 and SF-6.

- [ ] **SF-7b: Acceptance harness and fixtures** — `tests/acceptance/verify-egress-mediator.sh`
  implementing phases A–G (T3–T8, T17, T28, T34, plus the listener-set, forwarding,
  sink-reachability, control-plane-mount and no-agent-on-`egress-net` assertions), the four fixtures (controlled
  authoritative DNS server, HTTP collector, `Upgrade`-capable endpoint, two names sharing one
  address), and the **test-scoped resolved policy** — `policy/resolved/test-fixtures.yaml` plus
  `compose/overrides/test-egress.yaml` — which allowlists the fixture hosts. Without it T6's "the
  allowed domain succeeds" half has nothing to succeed against, since `default.yaml` allowlists
  provider endpoints and no fixture. Test code; the only unit that needs all prior sub-features
  landed. Depends on SF-7a.

**Sizing note.** Eight sub-features. The milestone README already calls 01.3 the largest feature and
anticipates "one sub-feature per role" — four roles plus selection, policy artifact and pod
plumbing is seven. DD-1's 2–5 ceiling governs features per milestone, not sub-features per feature
(the same reading 01.2 applied at five). Each is judged against DD-1's ~120k-token session
guideline: SF-1 and SF-2 are below it, SF-4 is the smallest shipped unit, and SF-5 and SF-7b are the
two largest.

**SF-7 was flagged `[OVERSIZED]` at plan time and split on the operator's decision.** As one unit it
carried the audit schema and writer, the denial surface, a two-stage self-check, a seven-phase harness
and four test fixtures. It is now SF-7a (product code — audit, denial surface, self-checks) and
SF-7b (test code — fixtures, test-scoped policy, the harness), which also puts the product/test
boundary on a sub-feature boundary. No sub-feature is flagged `[OVERSIZED]` in the current list.

SF-5 is the closest remaining call — three controls in one configuration surface — and is **kept whole**:
the three are evaluated in a single ordered pass over one connection, and splitting them would land
a policy engine knowingly incomplete at the boundary, which is worse than one larger session. If it
runs long at build time, the clean split is control 1+2 (policy correctness) from control 3
(resource ceilings), which share no code path.

## Interface Contracts

### 1. Resolved policy artifact — produced by 01.3 SF-2, consumed by the mediator, replaced by 01.5

`policy/resolved/<profile>.yaml`. Generated, committed, never hand-edited (SC-6). 01.5 moves its
production into a build stage of the mediator image (D10) and adds pack composition; the schema
below is what it must continue to emit.

```yaml
schema: 1
profile: default
compiled_at: <ISO 8601>
compiled_from:
  allowlist: policy/allowlist.base.yaml
  denylist: policy/denylist.base.yaml
  profile: profiles/default.yaml
  packs: []                    # 01.5 populates; empty at this milestone
provisional: true              # inherited from allowlist.base.yaml (D17)
pins: agent-verification.md    # the 01.1 SF-2 pins the capture was taken against (R10.6)

agents:
  claude:
    identity: claude           # certificate subject CN and listener binding key
    listener_port: 3128
    allow_fqdns:
      - {fqdn: api.anthropic.com, port: 443, upgrade: false}
    allow_cidrs: []
    limits: {max_concurrent: 16, connections_per_minute: 120, bytes_per_second: 2000000}
  codex: {identity: codex, listener_port: 3128, allow_fqdns: [], allow_cidrs: [], limits: {...}}
  agy:   {identity: agy,   listener_port: 3128, allow_fqdns: [], allow_cidrs: [], limits: {...}}

deny_cidrs:                    # applied post-resolution to every agent; deny wins (R5.3, R5.7)
  - 169.254.0.0/16
  - 127.0.0.0/8
  - 10.0.0.0/8
  - 172.16.0.0/12
  - 192.168.0.0/16
deny_fqdns: []                 # R5.1 — supported and empty, not absent. See criterion 10

startup_check:
  allowed: {agent: claude, fqdn: api.anthropic.com, port: 443}
  denied:  {ip: 169.254.169.254, port: 443}   # fails on POLICY, not on resolution
  offline: false               # true skips stage 2 only; recorded in the audit log at every start
```

`listener_port` is identical across agents because each listener is on a different network. The
field is present so a per-agent override does not require a schema change.

The `limits` values are **proposals for confirmation at review**, not measurements. They are sized
to be comfortably above an interactive agent session and well below a runaway loop; no traffic has
been observed to derive them from, and 01.1 SF-3's discovery capture is the first data that could.

### 2. Agent-side environment and mounts — produced by 01.3 SF-3, consumed by 01.4

Added to each agent service on top of 01.2's Interface Contract 2:

| Variable / mount | Value | Requirement |
|---|---|---|
| `HTTPS_PROXY`, `https_proxy` | `https://<mediator addr on that net>:3128` | D1, R5.5 |
| `HTTP_PROXY`, `http_proxy` | same | — |
| `NO_PROXY`, `no_proxy` | `localhost,127.0.0.1` | Keeps loopback MCP listeners unproxied (§ Inbound listeners) |
| `dns:` (service key, not env) | `[<mediator addr on that net>]` | R5.4, D3 |
| `NODE_EXTRA_CA_CERTS` (claude) | `/run/secrets/mediator-ca.crt` | R5.12, proxy hop only |
| `CODEX_CA_CERTIFICATE` (codex) | `/run/secrets/mediator-ca.crt` | R5.12, proxy hop only |
| `agy` CA mechanism | per 01.1 SF-2's recorded finding | R5.12 |
| secret `<agent>-client.crt` / `.key` | `/run/secrets/`, scoped to one service | R8.8 |
| secret `mediator-ca.crt` | `/run/secrets/`, all three services | R8.8 |

Both upper- and lower-case forms are set: the three agents' HTTP clients do not agree on which they
read, and 01.1 SF-2's `agy` result governs whether `agy` honours either.

**01.4 consumes this contract, not the reverse.** OAuth endpoints must be present in the resolved
allowlist before `oauth-interactive` can complete — the milestone README's stated reason 01.3
precedes 01.4.

### 3. Workload identity — produced by 01.3 SF-6, consumed by Milestone 03

| Artifact | Location | Notes |
|---|---|---|
| CA private key | **Operator host only.** Never in an image, never in a volume, never in the mediator | Narrower than the architecture document — criterion 9 |
| CA certificate | Compose secret, mediator + all three agents | Verification anchor; the proxy-hop trust addition |
| `<agent>-client.{crt,key}` | Compose secret, scoped to exactly one agent service | Subject `CN=<agent>`; distinct per agent |
| `<agent>-listener.{crt,key}` | Compose secret, mediator only | One listener per agent network |

**Binding rule.** A connection on the listener for network *N* is accepted only if its client
certificate subject CN equals *N*'s agent identity. Any other subject is refused before control 1
runs and is logged with `verdict=deny, control=identity`. This is T34's assertion, and it is
exercisable in 01.3 with no brokered credential in existence: cross-binding is refused at the
listener, and Milestone 03's brokering later attaches to an identity that is already enforced.

Lifecycle (R8.8's "defined lifecycle"): certificates are issued with a bounded validity and the
renewal path is `bash scripts/issue-identity.sh <agent>` followed by a container restart. Revocation
is by reissuing the CA and all four certificates — no CRL or OCSP is introduced, which is
proportionate to a four-certificate pod and is recorded as the chosen mechanism rather than an
oversight.

### 4. Audit line schema — produced by 01.3 SF-7

One JSON object per line, per connection attempt, allow and deny alike (R9.1):

```json
{"ts":"2026-09-04T12:00:00.123Z","agent":"claude","identity_source":"listener+mtls",
 "cert_subject":"CN=claude","dest_host":"api.anthropic.com","dest_port":443,
 "resolved_ip":"203.0.113.10","verdict":"allow","control":null,
 "bytes_out":1234,"bytes_in":5678}
```

`verdict: "deny"` carries `control` as one of `identity`, `allowlist`, `denylist`, `ratelimit`, and
omits `bytes_*`. `identity_source` is `listener+mtls` normally and `listener` only where SF-6
recorded a client that cannot present a certificate — so the log states the strength of its own
attribution rather than implying uniform mTLS. **The field is not a licence to skip mTLS.** It
exists for the *partial* 01.1 outcome: if two agents can present a certificate and one cannot, the
two are held to `listener+mtls`, the third is recorded as `listener`, and the gap is scoped to one
agent. A *total* negative — no agent can present a client certificate at all — leaves R8.8's
mechanism unmet across the pod and is the `/milestone` revision the Dependencies section names, not
a degraded mode this schema absorbs.

**No `session` field.** Nothing in CONNECT carries the agent's session identifier. R9.8's
correlation is by `agent` and `ts` at this milestone; session-ID correlation depends on the agent
action recorder (D20), which this feature does not build.

### 5. Compose seam — extends 01.2's Interface Contract 4

01.2 declared four networks, three agent services, three volumes and a shared `./images` build
context. 01.3 adds: `ipam` subnets and a static `ipv4_address` for the mediator on each of the three
agent networks; the `egress-mediator` service attached to all four; an `audit` named volume mounted
into the mediator only; the six Compose secrets from Interface Contract 3; and the environment and
`dns:` keys from Interface Contract 2 on each agent service. 01.5 replaces the mediator's local
`build:` with a digest-pinned GHCR image and moves policy compilation into its build stage.

### 6. Denial surface — produced by 01.3 SF-7a, consumed by the operator (R12.2)

A refused CONNECT returns HTTP 403 immediately, with a plain-text body naming the destination, the
control that refused it, and the policy file to edit:

```
403 egress denied
destination: collector.example.com:443
control:     allowlist (default-deny; host not present for agent "claude")
policy:      policy/resolved/default.yaml  (edit policy/allowlist.base.yaml, then recompile)
```

Immediate refusal, never a drop (R9.4), and the same body reaches the agent's own error output so a
legitimate gap is distinguishable from an attack (R9.3).

## Edge Cases

**Domain fronting — CONNECT host vs. SNI.** R5.5 permits evaluation "at CONNECT or SNI". If only the
CONNECT hostname is checked, an agent can CONNECT to an allowlisted host and send a different SNI,
reaching a different origin behind a shared front-end. The connection is spliced, so the mediator
cannot see the HTTP `Host` header either. Mitigation: peek at the TLS ClientHello, require SNI to
equal the CONNECT host, and refuse the mismatch — this reads the handshake without decrypting and
does not violate D4 or R5.13. SF-1's P6 establishes whether the selected implementation can do it.
If it cannot, the gap is **recorded explicitly** as a residual against SC-2 rather than left
unstated, in the manner of the architecture's "Controls this architecture does not provide" table.

**Encrypted ClientHello defeats the SNI check.** SNI equality assumes the SNI is readable. With ECH,
the outer ClientHello carries an allowlisted public name while the encrypted inner ClientHello names
a different origin, and the mediator splices a connection whose effective destination is outside the
policy — without decrypting, it cannot tell. The structural mitigation is in the resolver, not the
proxy: ECH configuration is retrieved through `HTTPS`/`SVCB` DNS records, and criterion 4 restricts
the pod resolver to `A` and `AAAA`, so an agent using the pod resolver cannot obtain an ECH config
in the first place. That is a real control, not a complete one — a hardcoded or model-supplied ECH
config needs no lookup. The residual is recorded, and it is the strongest argument in this feature
for the destination-narrowing-plus-audit posture the architecture already accepts: an agent that can
reach an allowlisted CDN can reach things behind it, with or without ECH.

**The control plane must not be inside the project mount.** 01.3 creates `policy/`,
`mediator/config/` and `mediator/identity/` inside `solutions/agent-containerization/`, and 01.2
mounts the profile's project directory **read-write** at `/workspace`. If an operator points the
project mount at this solution tree — the obvious thing to do while developing this solution — a
compromised agent can rewrite `allowlist.base.yaml`, `proxy.conf.tmpl` or the issuance script
through `/workspace`, and the next `docker compose build` compiles agent-authored policy into the
enforcement point. R1.2 says the enforcement point sits outside the agent's blast radius; a mount
can put its *source* back inside it. Two mitigations, both in scope here: the running mediator reads
policy only from its own image layer and its Compose secrets, never from a path any agent can write;
and Phase A asserts that no agent's mount set contains any `policy/`, `mediator/` or identity path,
so the misconfiguration fails the harness instead of shipping. The README additionally states that
the project mount must not be the solution tree. This is the half of T8 the tamper test would
otherwise miss, because the agent never touches the running config — it edits the input to the next
build.

**Egress attempts that never reach the mediator are invisible to R9.1.** Covered in criterion 7:
a raw socket from inside an agent fails locally with `ENETUNREACH`, so no audit line is written for
an attempt R9.1 calls the detection signal. Recorded as a residual with the reason the obvious fix
(routing non-CONNECT traffic to the mediator so it can REJECT-and-log) is rejected. The DNS audit
trail is the partial compensation, and 02.2 is where the blind spot's size gets measured.

**Control 3 is weaker than D5's rationale assumes.** D5 justifies control 3 by the runaway loop
against the model API — a cost-exhaustion failure generating only allowlisted traffic. Under D4 the
mediator sees CONNECTs, not requests, and an SDK that keeps one connection alive (or multiplexes
over HTTP/2) can issue unbounded requests behind a single accepted CONNECT. `max_concurrent` and
`connections_per_minute` therefore bound *connection* behaviour, and `bytes_per_second` is the only
ceiling that tracks request volume at all — indirectly, through payload size. The honest position:
control 3 bounds a runaway loop that opens connections and blunts one that does not; it does not
bound request count, and it cannot while TLS is spliced. Recorded as a residual against D5's stated
rationale rather than presented as satisfying it. Adding request-level limits would require
terminating TLS, which R5.15 forbids and R5.13 permanently bars for one agent.

**Wildcard allowlist entries would reopen DNS exfiltration.** The closed forwarder is safe only
because matching is exact. A wildcard entry such as `*.anthropic.com` would make
`<base64-payload>.anthropic.com` a forwardable query and hand back the channel R5.4 exists to close.
The allowlist schema is exact-`fqdn` today (01.1 SF-3's contract), so this is currently structural —
but 01.5 composes pack-supplied entries into the same field, and a pack could introduce one. SF-2's
compiler therefore **rejects a wildcard entry** rather than passing it through, so the constraint is
enforced where the composition happens instead of relying on nobody writing one.

**A denied CIDR that is also the resolved address of an allowed FQDN.** Deny wins (R5.3, R5.7), so
the connection is refused and logged with `control=denylist`. This is correct and will look like a
bug the first time an operator hits it. The 403 body names the resolved address explicitly for that
reason.

**Resolution consistency between control 2 and the connect.** If the proxy resolves once for the
deny check and again for the connection, the second resolution can differ — the rebinding case D5's
control 2 exists to catch. SF-1's P2 verifies the implementation connects to the address it
checked; a failure there is a correctness defect at the boundary, not a tuning matter, and would
route to `/milestone` rather than being worked around.

**An agent that ignores `HTTPS_PROXY`.** Nothing happens: the network is `internal: true` and there
is no default route, so an unproxied connection fails to connect rather than escaping. This is also
half of T8 — an agent unsetting or repointing its own proxy variables removes its own egress and
gains nothing, because the control is the absent route, not the variable. The other half is that the
resolved policy and the audit volume are on no agent-reachable path.

**Startup on an offline host.** Stage 1 still aborts on a corrupt policy. Stage 2's known-allowed
probe cannot succeed with no internet, so a pod that is entirely correct would fail to start. The
`startup_check.offline` profile key exists for exactly this and is recorded in the audit log at
every start, so an environment running without its reachability check is visible rather than
assumed. Stage 1 is never skippable.

**The mediator is a single point of failure for DNS (D3's stated tradeoff).** Its failure is a full
pod outage, not a degraded mode. Accepted at Gate 2. The operational consequence to document: an
agent's first symptom is name resolution failing, not egress failing, and the runbook should say so.

**`agy` and the whole feature.** If 01.1 SF-2 records that `agy` does not honour `HTTPS_PROXY`, the
`agy` container has no route on an `internal: true` network and no configuration in this feature
changes that. The milestone README calls this a design change under D1 that stops the build for that
agent. 01.3 would then ship two agent networks and two listeners, and the third is a `/milestone`
revision. This is a dependency, not an edge case to handle in code.

**Port 53 under `cap_drop: ALL`.** Binding a privileged port with no capabilities requires
`net.ipv4.ip_unprivileged_port_start=0` as a namespaced sysctl. If Docker Desktop's VM does not
permit it, the fallback is `cap_add: NET_BIND_SERVICE` — a single capability, narrower than the
alternative of running the resolver as root, and a recorded deviation from the D15 baseline either
way. The mediator's hardening is otherwise identical to the agents' (§ Mediator hardening).

**The mediator must not become a router.** It has interfaces on both an agent network and the
external network. Container network namespaces default to `net.ipv4.ip_forward=0` and agents have no
default route, so no agent can route through it — but both facts are asserted in the harness rather
than assumed, because either changing silently converts the enforcement point into a bypass.

**Compose `secrets:` and 01.2's mount-set equality assertion.** Secrets appear as mounts under
`/run/secrets`. 01.2's smoke check requires each agent's mount set to *equal exactly* its allowed
set, so it fails the moment SF-3 lands. Extending that allowed set is explicit work in SF-3, listed
in Files to Create/Modify — not an incidental fix discovered during the build.

**Provisional allowlist (D17).** `policy/allowlist.base.yaml` is marked provisional until 01.1's
capture and cross-validation agree. The resolved artifact propagates that flag, and the mediator
logs it at startup. A provisional policy does not block startup — the milestone's Definition of Done
requires the status be recorded, not resolved.

## Test Command

```
bash tests/acceptance/verify-egress-mediator.sh
```

## Test Strategy

The script brings the pod up with the default profile and the mediator, runs its assertions against
**synthetic destinations it controls**, and tears down with `down -v` under a test-scoped Compose
project name so the operator's real state volumes and audit volume are never touched.

The harness reaches no third-party host. Most bring-ups set `startup_check.offline: true`, so no
reachability probe is aimed at a provider endpoint; stage 1 still runs and still aborts on a corrupt
policy, which is what T17 needs. Phase F is the exception and the reason the exception matters: it
runs stage 2 for real, with the allowed and denied targets repointed at harness fixtures, so a
broken reachability check cannot pass unnoticed behind a permanently-offline harness.

**What this feature can and cannot verify.** No agent is authenticated until 01.4. Every assertion
is therefore made either from a probe container placed on an agent network, or from the agent
containers' unauthenticated startup traffic — never from a working agent session. T3–T8 are executed
against controlled fixtures, not against real provider endpoints. This is a genuine bound on the
evidence and is the reason 02.2 owns these same tests as *recorded adversarial acceptance*: the
smoke run here shows the controls work, not that they withstand an adversary.

Phases:

- **Phase A — topology and posture.** Mediator attached to four networks; no agent on `egress-net`;
  the listener set on each agent network is exactly {proxy, resolver} by enumeration; mediator
  hardening fields present; `net.ipv4.ip_forward=0` in the mediator; no agent has a default route;
  the audit volume is mounted into the mediator and into nothing else; no private key material in
  any image layer (R8.1). **No agent's mount set contains any `policy/`, `mediator/` or identity
  path** — the control-plane-inside-the-project-mount case in Edge Cases. Also re-runs 01.2's
  amended mount-set equality check.
- **Phase B — identity (T34, T28).** A probe presents agent A's certificate to agent B's listener and
  is refused. A probe with no certificate is refused. A valid certificate is accepted and its
  subject appears on the resulting audit line. For T28: the destination certificate chain observed
  from inside each agent container terminates at the origin's own CA, not the mediator's; the
  mediator's process holds no destination plaintext.
- **Phase C — controls (T3, T5, T6, T7).** A non-allowlisted collector is refused with 403 and
  logged. A raw TCP socket to a non-allowlisted host and port fails. An allowlisted domain and a
  denied domain sharing one address: the allowed one succeeds, the denied one is refused —
  demonstrating per-connection L7 evaluation rather than an IP snapshot. `169.254.169.254` is
  refused. Rate and concurrency ceilings refuse past their thresholds with `control=ratelimit`.
- **Phase D — DNS (T4).** A query encoding data in its labels, aimed at a controlled authoritative
  server, produces no query at that server. A non-allowlisted name returns REFUSED. An allowlisted
  name resolves. Docker's embedded resolver forwards only to the mediator.
- **Phase E — tampering and self-check (T8, T17).** T8 names three tamper surfaces and all three are
  exercised. *Proxy config:* unset and repoint the proxy variables — no egress results. *Firewall
  and routing:* attempt to add a route, bring up an interface and load a netfilter rule from inside
  the container — each fails for want of `NET_ADMIN`/`NET_RAW` (R1.5), asserted rather than assumed
  from the absence of the capability. *Mount set:* attempt to remount `/workspace` read-write-exec,
  to mount anything new, and to reach or write the resolved policy, the mediator config and the
  audit sink — all fail, and the mount set is re-enumerated afterwards to confirm it is unchanged.
  Then T17: corrupt the resolved policy and start — startup aborts with an error naming the file and
  field.
- **Phase F — startup reachability self-check (R9.5).** Brings the mediator up with
  `startup_check.offline: false`, pointing `startup_check.allowed` at the harness's own HTTP fixture
  and `startup_check.denied` at `169.254.169.254:443`. Stage 2 therefore executes end to end,
  through the rendered proxy, against fixtures — so the check R9.5 asks for is demonstrated to work
  rather than merely configured, and no third-party host is contacted. A separate bring-up sets
  `offline: true` and asserts stage 2 is skipped and the skip appears on the audit line.
- **Phase G — audit completeness.** After phases C, D and E, every attempt appears in the sink with
  destination, verdict, timestamp and identity — blocked attempts included (R9.1) — and every DNS
  decision appears with name, QTYPE, verdict and agent. This is the input T16 consumes; T16 itself
  is 02.2's. The phase also records the known blind spot honestly: the raw-socket attempt from phase
  E produces **no** audit line, which is criterion 7's residual, and the harness asserts it as an
  expected absence rather than letting it read as a passing case.

Codex's WebSocket transport (criterion 3) is checked behaviourally in phase C against a controlled
`Upgrade`-capable endpoint, since under splice there is no configuration flag to inspect.

## Documentation

- `docs/records/mediator-selection.md` — SF-1's P1–P6 results, the selected implementation, and any
  recorded gap. The record stands whether the properties passed or failed.
- `README.md` — the mediator's role in bring-up, the certificate-issuance step before first start,
  the R12.2 troubleshooting path for a blocked destination (read the 403 body, edit
  `policy/allowlist.base.yaml`, recompile, restart), and the D3 note that a mediator outage presents
  as DNS failure first.
- `docs/ARCHITECTURE_AND_DESIGN.md` — update the Open Items Carried Into Build table with the
  resolved `agy` proxy and MCP-transport rows this feature consumes, and record the three decisions
  narrowing or reinterpreting the ratified text: the mediator exposes two listeners per agent
  network rather than one (criterion 1), T28's pass criterion distinguishes the destination chain
  from the proxy-hop anchor (criterion 5), and the CA private key stays offline (criterion 9).
- `REQUIREMENTS.md` — **amend T28's pass criterion** per criterion 5's recorded decision. This is
  the one change this feature makes to the authoritative register; it is deliberate, approved at
  Gate 4, and made because the alternative is a register that cannot be satisfied. R8.8 is not
  touched. An interpretation recorded in only one of the two documents is drift by construction,
  which is why this lands in the register rather than only in the plan.
- `policy/resolved/README.md` — states that the directory is generated output, names its producer,
  and warns against hand-editing (SC-6 depends on that being true).

## Files to Create/Modify

Paths are relative to `solutions/agent-containerization/`.

| File | Action | Changes |
|------|--------|---------|
| `docs/records/mediator-selection.md` | Create | SF-1's P1–P6 verification results and the selection decision |
| `scripts/compile-policy.sh` | Create | Zero-pack policy compiler: base allow/deny + profile → `policy/resolved/default.yaml`. 01.5 moves this into the mediator image build stage |
| `policy/resolved/default.yaml` | Create | The committed SC-6 artifact. Generated; not hand-edited |
| `policy/resolved/README.md` | Create | Generated-output notice and producer |
| `policy/denylist.base.yaml` | Modify | Add `deny_fqdns: []` — closes the R5.1 MUST that 01.1's contract left out (criterion 10) |
| `profiles/default.yaml` | Modify | Add per-agent `rate_limits` and the `startup_check` block (allowed, denied, `offline`) |
| `images/mediator/Dockerfile` | Create | Selected proxy + resolver + audit writer. Non-root, read-only rootfs layout, no secret in any layer |
| `images/mediator/entrypoint.sh` | Create | Stage-1 schema validation, config render from the resolved policy, stage-2 reachability check, then exec the proxy |
| `mediator/config/proxy.conf.tmpl` | Create | Per-network listeners, client-cert verification, the three controls, log format, `deny_info` body |
| `mediator/config/resolver.conf.tmpl` | Create | Closed resolver: allowlisted names answered, everything else REFUSED, no forwarding |
| `mediator/identity/.gitignore` | Create | Excludes all private key material (R8.7's spirit; nothing secret in version control) |
| `mediator/identity/README.md` | Create | CA layout, subject naming, validity, renewal and revocation path |
| `scripts/issue-identity.sh` | Create | Offline CA creation and per-agent + per-listener certificate issuance. Runs on the operator host; the CA private key never leaves it |
| `compose/compose.yaml` | Modify | `egress-mediator` service on four networks; `ipam` subnets + static mediator `ipv4_address` per agent network; `audit` volume mounted to the mediator only; six Compose secrets; `dns:`, proxy env and CA/client-cert secrets on the three agent services |
| `compose/overrides/default.yaml` | Modify | Profile-selected mediator bits (rate limits, `startup_check.offline`) |
| `policy/resolved/test-fixtures.yaml` | Create | Test-scoped resolved policy allowlisting the harness fixtures. Never loaded by the default profile |
| `compose/overrides/test-egress.yaml` | Create | Test-only override: the four harness fixtures on `egress-net`, the test-scoped policy, `startup_check.offline: true`. Not a shipped profile |
| `tests/acceptance/verify-egress-mediator.sh` | Create | The Test Command. Phases A–F. `#!/usr/bin/env bash`, `set -euo pipefail`, mode 644, invoked as `bash` |
| `tests/acceptance/verify-pod-topology.sh` | Modify | Extend the allowed mount set with `/run/secrets` entries and the expected proxy/DNS environment, so 01.2's equality assertion survives 01.3 |
| `.gitignore` | Create | Private key material and generated secret files outside `mediator/identity/`. **Create, not modify** — `solutions/agent-containerization/` has no `.gitignore` today |
| `README.md` | Modify | Mediator bring-up, issuance step, R12.2 denial troubleshooting, D3 outage note, and the warning that the project mount must not be the solution tree |
| `REQUIREMENTS.md` | Modify | **Amend T28's pass criterion** per criterion 5 (destination chain, not the proxy-hop anchor). The only register change this feature makes; R8.8 untouched |
| `docs/ARCHITECTURE_AND_DESIGN.md` | Modify | Open-items rows resolved by this feature; the two narrowing decisions in criteria 1 and 9 |

## Dependencies

**On Feature 01.1 — build cannot start until these records exist:**

- **01.1 SF-2, client-certificate presentation per agent.** The milestone README states plainly that
  if none of the three agents can present a client certificate to a TLS proxy listener, "R8.8's
  mechanism changes shape and 01.3's largest sub-feature becomes a redesign". This plan localises
  that blast radius to SF-6 by building controls 1–3 and the audit trail on structural,
  network-derived identity (criterion 6) — but it does **not** absorb the failure. A negative result
  leaves R8.8, a MUST, unmet by its ratified mechanism, and that is a `/milestone` revision, not a
  plan-time fallback.
- **01.1 SF-2, `agy` `HTTPS_PROXY` and CA-trust mechanism.** Go/no-go for the `agy` network,
  listener and allowlist. A negative removes one third of this feature's surface and is a design
  change under D1.
- **01.1 SF-2, default MCP transport per agent and per server.** Determines whether any MCP traffic
  crosses the enforcement point at all, and therefore whether the resolved allowlist needs entries
  for it. R7.15's inventory is 01.5's, but the allowlist consequence is this feature's.
- **01.1 SF-3, `policy/allowlist.base.yaml` and `policy/denylist.base.yaml`.** The compiler's only
  inputs. The allowlist arrives marked provisional (D17); that flag propagates rather than blocking.

**On Feature 01.2 — the pod this feature attaches to:**

- `compose/compose.yaml`'s four networks, three agent services and build context.
- `profiles/default.yaml`'s schema, which SF-2 extends rather than replaces.
- `tests/acceptance/verify-pod-topology.sh`, amended by SF-3.

**On later features — deliberately absent here:**

- **No authentication.** 01.4 owns `AUTH_MODE`. Until it lands, no agent reaches a provider through
  the mediator and this feature's tests use controlled fixtures.
- **No policy compiler as a build stage, no packs.** 01.5 owns D10's build-stage compilation and
  pack composition. SF-2 ships the zero-pack script and fixes the artifact schema so 01.5 has a
  target.
- **No credential brokering.** The mediator's fifth role is Milestone 03, blocked on Q1 and Q9.
  SF-6 builds the identity that D6 makes its precondition, and nothing more.
- **No agent action recorder.** R9.7, D20 and T35 are not in this feature's acceptance criteria.
  Criterion 7 records the resulting limit on R9.8 correlation rather than leaving it implied.
- **No off-host log shipping.** R9.6 is a MAY. The audit sink is mediator-local at this milestone,
  which is one of the two shapes D12 permits, and it shares the mediator's fate — D12's stated
  tradeoff, accepted here and recorded.

**External:**

- Docker Desktop on macOS 26, Apple silicon (R11.1, A1). Namespaced-sysctl and `ipam` behaviour are
  properties of its Linux VM and are verified in SF-3, not assumed.
- Upstream package sources reachable at mediator image build time.
- A controlled authoritative DNS server and a controlled HTTP collector for T3, T4 and T6. Both run
  as test fixtures inside the Compose project on the external network — no third-party service is
  used as a test target, and nothing leaves the host.

**Repository state:** greenfield for this component. No proxy, resolver, CA or audit code exists
anywhere in the repository. Shell scripts follow `#!/usr/bin/env bash`, `set -euo pipefail`, mode
644, invoked as `bash script.sh`.

## Architectural Deviations

(none)
