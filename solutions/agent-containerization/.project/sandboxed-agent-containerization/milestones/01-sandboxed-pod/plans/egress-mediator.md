# Feature Plan: Egress mediator

**Milestone:** 01 - Sandboxed Pod
**Feature:** 01.3: Egress mediator
**Status:** Planned
**Date:** 2026-09-04 (re-planned 2026-09-05 — 2026-09-04 milestone revision split identity out to 01.6)

## Summary

Builds the single enforcement point (R1.2, D1). One multi-homed `egress-mediator` container joins
all three `internal: true` agent networks and the external network, and becomes the only path out
of the pod. It carries three of the component's five roles: the Layer-7 CONNECT/SNI policy engine
evaluating D5's three controls in order, the authoritative pod resolver (D3), and the audit writer
(D12) — plus the agent-facing listener surface those three rest on and the proxy-hop trust anchors
that surface needs. The fourth role, client authentication and identity issuance, was split out to
**Feature 01.6** at the 2026-09-04 milestone revision. The fifth, upstream credential brokering, is
Milestone 03.

**Per-agent identity here is network-derived, not cryptographic.** Each `internal: true` network
carries exactly one agent container, so the listener a connection arrives on *is* the agent's
identity — structural, always available, and sufficient to select that agent's allowlist and rate
bucket. R8.8's cryptographic identity is 01.6's, layered on top of this without changing it.

**The three agent-facing listeners are not identical, because the agents' HTTP clients are not.**
01.1 SF-2 established that `codex` rejects an `https://`-scheme proxy URL at parse time and must be
given plain HTTP CONNECT, while `claude` and `agy` both reach an `https://` listener. That asymmetry
is this feature's tightest constraint on the proxy implementation and is settled in SF-1 before
anything is built on it.

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
   absolute-URI request inside the proxy-hop TLS — or, on `codex-net`, in the clear — and the
   mediator would hold that request and its response in plaintext — contradicting criterion 5's "holds no plaintext" and creating exactly the
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

   **Interpretation — "no mediator CA is presented to any agent".** Two of the three proxy hops are
   themselves TLS (criterion 6: `claude` and `agy` reach an `https://` listener), which requires those
   two agents to trust the listener's server certificate — issued by the mediator's CA. The literal
   reading of T28 and a TLS proxy hop are mutually exclusive. **This survives the 01.6 split:** the
   conflict is caused by the TLS hop, not by client certificates, so moving mTLS to 01.6 does not
   remove it and the amendment stays this feature's. `codex`'s hop is plain HTTP and trusts no
   mediator CA at all.
   T28 is implemented as the property it exists to protect: **no mediator CA appears in any
   destination TLS chain.** The agent validates the origin's own certificate for every destination;
   no destination chain terminates at a mediator CA; the mediator holds no destination plaintext.
   The proxy-hop anchor is a separate, single, explicitly recorded trust addition, distributed to the
   two agents that have a TLS hop through R5.12's per-agent mechanisms — `NODE_EXTRA_CA_CERTS` for
   `claude`, `SSL_CERT_FILE` for `agy` (01.1 SF-2's recorded finding). `codex` receives no mediator CA
   at all. **This is not TLS interception** and R5.13's permanent bar on intercepting Antigravity
   traffic is untouched — `agy`'s destination traffic is spliced like every other agent's.

   **Decided at this gate: T28 is amended in `REQUIREMENTS.md`, not merely reinterpreted here.** The
   two statements are both in the authoritative register, and one of them has to give — a plan-local
   reading would leave the register carrying a pass criterion no TLS proxy hop can ever meet. T28's
   pass text becomes: *no mediator CA appears in any destination TLS chain; the mediator holds no
   plaintext; Antigravity traffic is never intercepted* — with the single proxy-hop trust anchor
   recorded as an explicit exception. R8.8 is unchanged. The amendment is a register change, lands in
   **SF-3** (it was SF-6's before the 01.6 split moved identity out), and is tracked on this feature's
   review checklist. 01.6 carries the separate T34 amendment; that one is not this feature's.

6. **Per-listener transport and per-agent policy selection, on network-derived identity.** The
   three agent-facing listeners are not identical, because the agents' HTTP clients are not. Each
   selects its own agent's policy from the network the connection arrived on.

   | Agent | Proxy hop | Listener | Mediator CA trusted? | 01.1 SF-2 finding |
   |---|---|---|---|---|
   | `claude` | `https://` | TLS, **server-auth only at this feature** | Yes — `NODE_EXTRA_CA_CERTS` | Can also present a client certificate (`CLAUDE_CODE_CLIENT_CERT`/`_KEY`); **01.6 enables verification**, 01.3 does not |
   | `agy` | `https://` | TLS, server-auth only | Yes — `SSL_CERT_FILE` | Reaches `CertificateRequest` and has nothing to present |
   | `codex` | `http://` | Plain HTTP CONNECT | No — no TLS hop exists | Rejects an `https://`-scheme proxy URL **at URL-parse time**, before any handshake |

   **Network-derived identity is structural and always available.** Each agent network carries
   exactly one agent container and the networks are disjoint (01.2 criterion 1, re-asserted). A
   connection arriving on the mediator's `claude-net` interface can only be the `claude` container.
   The mediator runs one listener per agent network, so the listener itself selects the per-agent
   allowlist and rate-limit bucket. It cannot be forged by another agent because no agent holds an
   interface on another agent's network. Controls 1–3, the resolver and the audit trail therefore
   work with no client credential in existence.

   **What 01.3 owns, and what it does not.** 01.3 owns the listener surface, the CA and listener
   certificates the two TLS hops need, per-agent CA trust distribution, and per-agent policy
   selection working without client authentication. **Client authentication, identity issuance, R8.8
   and T34 are Feature 01.6** (2026-09-04 milestone revision). The implementation selected in SF-1
   must nevertheless be *capable* of client-certificate verification per listener even though this
   feature does not enable it — 01.6 builds on the same proxy, and the choice is made here (SF-1,
   P1).

   **`agy`'s TLS hop is kept deliberately.** It buys server authentication on the agent→mediator hop
   and keeps the path open if `agy` grows a client-certificate variable — 01.1 SF-2 records it as one
   unreleased feature from parity with `claude`, not a structural blocker. Dropping it to plain HTTP
   for consistency with `codex` was the alternative; the escalation record asked for this to be
   settled either way and the milestone README's Configuration table settles it this way.

7. **Audit (R9.1, R9.2, R9.3, R9.4, D12) — and T16's input.** Every outbound attempt is logged with
   destination, verdict and timestamp, **blocked attempts included**, to a sink no agent container
   can reach or alter. The sink is a named volume mounted into the mediator only, plus the
   container's stdout; no agent mounts it, asserted by enumeration. Denials are surfaced with a
   clear, actionable message naming the blocked destination (R9.3, R12.2) and rules REJECT rather
   than DROP (R9.4) — a refusal is always immediate, never a silent hang or a dropped packet.

   **Amended 2026-09-06 after SF-1 (Deviation 2).** The pre-SF-1 text read "an immediate HTTP 403
   whose body names the destination and the control that refused it". SF-1 established that a
   verifying HTTPS client cannot receive that body for any verdict decided after the CONNECT is
   accepted, and that accepting the CONNECT is a precondition of observing the SNI at all
   (`docs/records/mediator-selection.md`, P5). Split by decision point:
   - **Refusal decided before the CONNECT is accepted** — the CONNECT host is not on the agent's
     allowlist, is in `deny_fqdns`, or resolves into `deny_cidrs`: the proxy returns **HTTP 403 with
     the plain-text body** of Interface Contract 6. This path is real and is taken wherever the
     verdict does not need the ClientHello.
   - **Refusal decided after the ClientHello** — an SNI that disagrees with the CONNECT host, or any
     other post-peek verdict: the proxy terminates without minting a destination certificate, and a
     verifying client sees a prompt TLS/proxy failure and **no body**. Minting one is the MITM
     capability D4 and criterion 5 forbid.
   In both cases the destination-naming, actionable denial surface R9.3 and R12.2 require is the
   **audit record and the operator-facing message rendered from it** — not guaranteed in-band agent
   output.

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
   layer. The mediator's **two** listener key pairs — `claude-net` and `agy-net`; `codex-net` has no
   TLS hop and needs none — and the CA **public** certificate are delivered at runtime through Compose
   `secrets:` with a `file:` source: the available runtime-injection mechanism on Docker Desktop,
   named plainly here rather than described as "a secret manager". The CA certificate is scoped to the
   mediator and to the two agents that must trust it, and to no path `codex` can read. Per-agent
   **client** certificates are 01.6's and are absent here. Private key material is git-ignored.

   **The CA private key never enters the mediator.** Issuance is an offline operator script; the
   mediator holds only the listener certificates it presents, plus the CA certificate that 01.6 will
   verify client certificates against. This is narrower than the
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

    **R5.1's third term — "specific IP addresses" — is closed by `deny_cidrs`, and that is stated
    rather than assumed.** A single address is expressed as a `/32` (IPv4) or `/128` (IPv6) entry in
    `deny_cidrs`; no separate `deny_ips` field is introduced, because one would be a second spelling
    of the same control and a second place for deny-wins precedence to be got wrong. The compiler
    accepts a bare address and normalises it to `/32`//`128` rather than rejecting it, so an operator
    writing `169.254.169.254` in the denylist gets the behaviour R5.1 promises instead of a schema
    error. SF-8 Phase C asserts a `/32` deny refuses the exact address and does not refuse its
    neighbour — the test that distinguishes a real single-address deny from a mis-sized mask.

    **Decided at this gate:** 01.1's plan is already approved at Gate 4 and carries a statement that
    is false against R5.1. The operator's decision is to **re-plan 01.1 in revision mode** once this
    gate closes, correcting its Interface Contracts so the approved contract on disk stops
    contradicting a MUST. Tracked as a checklist item here; the re-plan itself is a separate
    `/plan-feature` invocation.

11. **Smoke checks:** T3 (HTTP/HTTPS exfiltration refused and logged), T4 (DNS exfiltration — no
    query arrives at a controlled authoritative server), T5 (raw TCP to a non-allowlisted host and
    port refused), T6 (CDN rotation — a denied domain sharing an allowed domain's IP is refused),
    T7 (`169.254.169.254` refused), T8 (policy tampering from inside all fail). Plus T17 and T28
    from the criteria above. **T34 is 01.6's**, with R8.8 — this feature neither runs it nor claims
    it. These are prerequisite checks here; **02.2 owns them as recorded adversarial acceptance**
    and this feature does not claim adversarial validation.

12. **The `agy` auto-updater host is decided in the resolved policy, not inherited by default
    (R10.3 — added at the 2026-09-05 re-plan).** 01.1 SF-2 handed this feature an explicit open item
    and the pre-revision plan did not carry it: `agy` performs a background self-update check "during
    regular runs" that **cannot be independently disabled** — no env var or flag was found in
    `agy --help` or in the binary's strings — and `docs/records/agent-verification.md` records it as
    "a residual, not-fully-closed R10.3 item **for 01.3 to account for in the allowlist**".
    `policy/allowlist.base.yaml` currently seeds that host
    (`antigravity-cli-auto-updater-974169037036.us-central1.run.app`) because discovery observed it on
    every invocation.

    R10.3 is a MUST: *agent auto-updaters are disabled, so a pinned build stays pinned.* An allowlist
    entry that permits the updater to reach its manifest is the opposite of that, and 01.2 could not
    see the conflict because the pod had no egress at all. 01.3 is the first feature where the
    allowlist becomes a live grant, so it is the feature that must decide.

    **Decision, and it is testable rather than asserted.** SF-2 **excludes** the auto-updater host
    from the resolved allowlist for `agy`. Default-deny means this needs no denylist entry — it needs
    the entry *not copied through* from the base allowlist, and the compiler records the exclusion and
    its reason in the resolved artifact rather than dropping it silently. SF-8 Phase C then asserts
    that `agy` still starts, runs a task and exits normally with the host denied, and that the denial
    appears in the audit log. **If `agy` hard-fails without it**, the recorded fallback is to allow the
    host with an explicit residual against R10.3 naming the version-pinning consequence — the same
    disposition 01.1 gives its own verification results. What is not acceptable is the current state:
    the host allowed by inheritance, with no one having decided.

    **The blast radius is probably narrow, and "probably" is the honest word.** `agy` is installed to
    `/usr/local/bin/agy`, root-owned mode 0755, on the read-only root filesystem, and the container
    runs as uid 1000 — so an in-place overwrite of the pinned binary fails twice over. What is **not**
    established is where the updater actually writes: `$HOME` is `/home/agent`, a writable state
    volume that survives restarts (R4.3, D7), and an updater that installs to a home-relative path
    could persist a second copy there and shadow the pinned one on `PATH`. The install script takes a
    `-d/--dir` argument, which is evidence the target is configurable rather than fixed at
    `/usr/local/bin`. **SF-8 Phase C records the updater's actual target path** as part of the
    criterion-12 check, so the residual is sized on evidence. Until then the claim this plan makes is
    the bounded one: the *pinned binary* cannot be overwritten. Whether a shadowing copy can be
    persisted is open, and it is the reason to exclude the host rather than to relax about allowing
    it.

## Approach

### Selection before construction

The architecture names two candidate implementations — `iron-proxy` (Go, Apache-2.0) or Squid in
CONNECT-allowlist mode — and ratifies neither. Every subsequent sub-feature is shaped by that
choice, and several of the properties below are MUSTs whose absence would not be discovered until
the last sub-feature. SF-1 therefore verifies the selected implementation against all eight before
anything is built on it.

**Three of the eight (P1, P7, P8) are verified here but consumed elsewhere or partly so.** The
implementation is pinned by this feature and 01.6 inherits it, so a capability 01.6 needs must be
established before 01.3 commits — the same argument the milestone README makes for the listener
surface being 01.3's and not 01.6's. Verifying a capability is not enabling it: P1 and P8 are tested
against a fixture and left switched off in the shipped configuration.

| # | Property | Requirement | Consumed by | Why it can fail silently |
|---|---|---|---|---|
| P1 | Client-certificate verification **available** per listener, with the subject reachable by policy and log | R8.8, D6 | **01.6** | Many proxies authenticate clients with `Proxy-Authorization`, not TLS identity |
| P2 | Post-resolution address deny applied to **the address the proxy actually connects to** | R5.7, D5 | 01.3 SF-6 | A proxy that checks one resolution and connects on another fails rebinding, which is D5's stated reason for control 2 |
| P3 | Per-client **concurrency, connection-rate and byte-rate** ceilings | D5 control 3 | 01.3 SF-6 | Request-rate limiting is unavailable under splice (see Edge Cases); byte rate is the substitute, and not every proxy exposes it per client |
| P4 | Agent identity on every access-log line, allow and deny alike — **derived from the listener**, with no client credential present | R9.1 | 01.3 SF-7 | Deny paths frequently log less than allow paths, and a log format keyed on a client certificate has nothing to print when there is none |
| P5 | An immediate, body-bearing refusal naming the destination | R9.3, R9.4, R12.2 | 01.3 SF-7 | Default proxy error pages name the proxy, not the blocked destination |
| P6 | SNI observable and comparable to the CONNECT host **without decrypting** | R5.5, R5.15 | 01.3 SF-6 | See the domain-fronting edge case below |
| P7 | **Heterogeneous listeners in one instance** — two TLS listeners and one plain-HTTP CONNECT listener concurrently, each selecting an independent per-agent policy and rate bucket | Criterion 6, D5 | 01.3 SF-6 | A proxy may support both transports but key policy off the client address rather than the listener, or force one TLS mode process-wide |
| P8 | Per-client policy selection from a **proxy credential** (`Proxy-Authorization`, or userinfo in the proxy URL) | R8.8 fallback path | **01.6** | The proxy half of a mechanism 01.6 needs; if the implementation cannot key policy off it, 01.6's only remaining option for `codex`/`agy` is network-derived identity |

**P7 is the new tightest constraint** and it is the direct consequence of 01.1 SF-2: the three
listeners are not identical. A proxy that cannot run a plain-CONNECT listener alongside TLS listeners
in one process fails this feature outright, and that is a selection question, not a configuration
detail.

**P8's split with 01.6 is deliberate and recorded.** The milestone README is internally inconsistent
here — 01.6's feature text assigns the proxy-credential question to 01.6, while the Configuration
table says "if 01.3's verification finds one". The split taken: **01.3 SF-1 verifies the proxy side**
(can the selected implementation key per-client policy off a proxy credential at all?), because the
implementation is pinned here; **01.6 verifies the agent side** (will `codex` or `agy` actually send
one?), because that is a client-capability question of the same shape as 01.1 SF-2's. Flagged for
review; the README's drift is noted rather than silently reconciled.

Squid is the primary candidate: CONNECT-allowlist splicing is its native mode rather than a
feature, and it has documented directives that plausibly cover the set (`http_port` and `https_port`
side by side for P7, `https_port` with `clientca=` for P1, `proxy_auth` ACLs for P8, `dstdomain`/`dst`
ACLs, `acl maxconn` and `delay_pools`, `logformat` with `%>a`/`%la`/`%lp` for P4, `deny_info`, and
`ssl_bump peek`+`splice` for P6). **Every one of those is a hypothesis to be tested in SF-1, not an
asserted capability.** `iron-proxy` is the recorded fallback. Each property gets a pass/fail and,
where it fails, either the alternative implementation or an explicitly recorded gap — the same
discipline 01.1 SF-2 applies to the agent clients, and for the same reason: cheap to establish here,
expensive to discover in SF-6 or, worse, in 01.6 after the implementation is pinned.

### Request path, as built

```text
agent process
  → claude, agy:  HTTPS_PROXY=https://<mediator-ip-on-that-net>:3128   (TLS hop, server-auth only)
  → codex:        HTTPS_PROXY=http://<mediator-ip-on-that-net>:3128    (plain CONNECT — 01.1 SF-2)
  → agent-net (internal: true — no other route exists)
  → mediator listener for THAT network
      ├─ the listener IS the identity: exactly one agent container on this network   (network-derived)
      │    (01.6 adds client authentication on top of this step; 01.3 does not)
      ├─ select this agent's allowlist and rate bucket from the listener            (per-agent, not union)
      ├─ control 1: CONNECT host on allowlist? and SNI == CONNECT host?             (R5.2, R5.5)
      ├─ resolve via the mediator's own resolver
      ├─ control 2: resolved address in deny_cidrs, or host in deny_fqdns? deny wins (R5.3, R5.7, R5.1)
      ├─ control 3: per-agent concurrency / connection rate / byte rate               (D5)
      ├─ audit line {ts, agent, identity_source, host, port, resolved ip, verdict, control}
      └─ splice: opaque tunnel, no decryption                                        (R5.15, D4)
  → egress-net → destination
```

A refusal at any control writes `verdict=deny` with the refusing control named. Where the verdict is
reached before the CONNECT is accepted, the mediator returns HTTP 403 with a body naming the
destination; where it depends on the ClientHello, the connection is terminated and a verifying agent
sees a prompt TLS/proxy failure with no body (SF-1, Deviation 2). Either way the agent gets an
immediate, distinguishable failure rather than a hang, and the destination and refusing control are
named on the audit line.

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

SF-1 gates everything. SF-2 (the policy artifact) must precede SF-5 (the resolver reads the
allowlist to know what to answer) and SF-6 (the controls read it). SF-3 produces the trust
material — CA and the two listener certificates — before SF-4 can mount it and SF-6 can configure
listeners against it. SF-4 puts the container on the four networks and wires the per-agent proxy
schemes. SF-7 closes the mediator itself with audit, denial surface and self-checks, and SF-8 is the
harness that proves the whole.

**Renumbered at the 2026-09-05 re-plan.** The old SF-6 (per-agent workload identity) left with
Feature 01.6, the proxy-hop trust anchors it contained stayed and became the new SF-3, and old
SF-7a/SF-7b became SF-7/SF-8. Nothing was built against the old numbers — 01.3 was 0/8 at the
revision — so this is a renumber, not a migration.

## Sub-Features

- [x] **SF-1: Mediator implementation selection, verified** — Verify the selected proxy against
  P1–P8 above on a throwaway fixture, and record each result in
  `docs/records/mediator-selection.md` whether it passes or fails. Produces a record and a decision,
  not shipped code. Gates SF-2 to SF-8. Discovery-shaped and small by design; it exists because a
  failure on P2, P6 or **P7** changes what SF-6 builds rather than how well it builds it, and a
  failure on P1 or P8 changes what **01.6** can build on an implementation this feature has already
  pinned.
  **Records the exact proxy version every property was verified against**, and SF-4 pins to that
  version — the same discipline R10.3 and R7.18 apply to the agents. A verification against one
  major and an unpinned install of the next silently invalidates the design, because the directives
  these properties rest on are version-scoped.
  01.1 SF-2's client results are **in hand** and are inputs here, not blockers: `claude` presents a
  client certificate, `codex` reaches no TLS listener at all, `agy` reaches the handshake with
  nothing to present.

- [x] **SF-2: Resolved-policy contract and degenerate compiler** — The resolved-policy schema
  (Interface Contract 1), `scripts/compile-policy.sh` in its zero-pack form, the committed
  `policy/resolved/default.yaml`, the schema validator the mediator's stage-1 self-check calls, and
  the `deny_fqdns` addition to `policy/denylist.base.yaml` closing the R5.1 gap. Also adds the
  per-agent `rate_limits`, the per-agent `listener` block (scheme and TLS on/off — criterion 6) and
  the `startup_check` keys to `profiles/default.yaml`. **Excludes the `agy` auto-updater host from
  the resolved allowlist and records the exclusion and its reason in the artifact** (criterion 12,
  R10.3). Depends on 01.1 SF-3 for the base policy files and on 01.2 for the profile schema.

- [x] **SF-3: Proxy-hop trust anchors** — The offline CA and `scripts/issue-identity.sh` in its
  **CA-and-listener-certificate form**: create the CA on the operator host, issue one listener
  certificate for `claude-net` and one for `agy-net` (`codex-net` is plain HTTP and gets none), and
  document the lifecycle R8.8 will inherit — subject naming, validity bound, renewal path, revocation
  path. Also the per-agent CA trust distribution decided in criterion 6 (`NODE_EXTRA_CA_CERTS` for
  `claude`, `SSL_CERT_FILE` for `agy`, nothing for `codex`) and the **`REQUIREMENTS.md` T28
  amendment** (criterion 5) with its matching `docs/ARCHITECTURE_AND_DESIGN.md` entry.
  **Each listener certificate must carry a SAN matching the exact authority its agent's proxy URL
  names.** Interface Contract 2 sets `HTTPS_PROXY` to `https://<mediator addr on that net>:3128` — an
  **IP literal** — so the certificate needs an `iPAddress` SAN for the mediator's static address on
  that network, not a `dNSName` SAN and not a CN alone (CN-only matching is not honoured by modern
  TLS stacks). Get this wrong and the hop fails verification, and the tempting repair is to disable
  verification at the agent — which would silently give up the server authentication the TLS hop
  exists for. SF-8 Phase B verifies the handshake succeeds **without any insecure-TLS bypass**, which
  is the assertion that catches it. The mediator's static addresses come from SF-4's `ipam` blocks,
  so issuance is ordered after those addresses are fixed and `issue-identity.sh` takes them as input
  rather than hardcoding them.
  **This is the boundary against 01.6, and it is where the milestone README puts it:** 01.3's
  acceptance criteria assign this feature "the CA and listener certificates the TLS hops need".
  01.6 extends the same script with per-agent **client** certificates and turns on verification; it
  does not create a second CA. Kept as its own sub-feature rather than folded into SF-4 so that
  boundary is a sub-feature boundary and not a paragraph. Depends on SF-1 (P1 determines the listener
  certificate's required shape for 01.6's sake).

- [ ] **SF-4: Mediator image, compose seam and hardened runtime** — `images/mediator/Dockerfile` and
  its entrypoint, the `egress-mediator` service on four networks, `ipam` subnets with a static
  mediator address per agent network, the `dns:` and **per-agent** `HTTPS_PROXY`/`HTTP_PROXY`/
  `NO_PROXY` additions to the three agent services (`https://` for `claude` and `agy`, `http://` for
  `codex` — Interface Contract 2), Compose `secrets:` wiring for the CA and the two listener key
  pairs, the audit volume mounted to the mediator alone, and `.gitignore` additions for private key
  material. **Repoints `compose/overrides/default.yaml`'s project mount off the solution tree** to a
  git-ignored `workspace/` directory — the control-plane-inside-the-project-mount fix in Edge Cases,
  and a prerequisite for Phase A passing on the default profile rather than failing by construction.
  The directory is **committed with a `.gitkeep`**, not left to Docker: a missing bind source is
  auto-created by the daemon as root-owned, which the `user: "1000:1000"` agent containers cannot
  write to, turning a security fix into a broken demo profile. Also corrects
  `profiles/default.yaml`'s comment, which still says "this profile's Compose override binds `..`".
  Carries the mediator's D15 hardening plus the **port-53 binding deviation** —
  `sysctls: net.ipv4.ip_unprivileged_port_start=0` preferred so `cap_drop: ALL` survives,
  `cap_add: NET_BIND_SERVICE` as the recorded fallback if the sysctl is not permitted on Docker
  Desktop. **Verifies, does not assume, that `dns:` actually redirects Docker's embedded resolver to
  a container address on an `internal: true` bridge** — that redirect is the whole of D3's mechanism,
  and it is confirmed by capture on the mediator, not by reading Compose documentation. The port-53
  binding path is verified the same way. Attaching the mediator to `egress-net` also closes 01.2's
  recorded **Deviation 3** (`egress-net` was not a live Docker resource until a service attached to
  it); the deviation record is updated here.
  **Amends `tests/acceptance/verify-pod-topology.sh`** — 01.2's mount-set *equality* assertion fails
  the moment the CA secret is mounted into `claude` and `agy`, so the allowed set is extended here
  rather than left to break. Depends on SF-1, SF-2 and SF-3.

- [ ] **SF-5: Pod DNS authority** — The closed forwarder: exact-match allowlisted names
  re-originated as canonicalised `A`/`AAAA` queries to a named upstream, everything else REFUSED and
  forwarded nowhere, every decision audited. Rejects wildcard allowlist entries at compile time (see
  Edge Cases). Includes the T4 fixture — a controlled authoritative
  server the test asserts receives no query. Depends on SF-2 and SF-4.

- [ ] **SF-6: The three egress controls and the per-listener transport surface** — The three
  listeners of criterion 6 (two TLS, one plain HTTP CONNECT) in one instance, each selecting its own
  agent's policy from the network it binds — per SF-1's P7 result. Then control 1 (per-agent
  allowlist at CONNECT/SNI, with the SNI-vs-CONNECT-host comparison per P6), control 2
  (post-resolution `deny_cidrs` and `deny_fqdns`, deny wins), control 3 (per-agent concurrency,
  connection-rate and byte-rate ceilings), and the CONNECT-only method restriction. Client
  certificate verification is **configured off** on all three listeners; 01.6 turns it on for the
  listeners whose agent can present one. Covers T3, T5, T6, T7. Depends on SF-4 and SF-5.

- [ ] **SF-7: Audit writer, denial surface and startup self-checks** — The audit line schema
  (Interface Contract 4) and the writer behind it, including `identity_source` emitting `listener`
  for all three agents at this feature and the field being present so 01.6 extends its enumeration
  rather than the schema. The two-path denial surface of Interface Contract 6 — a 403-with-destination
  body on pre-CONNECT verdicts, terminate-without-body plus the operator record on post-ClientHello
  verdicts — both stages
  of the startup self-check, and the loopback self-check listener stage 2 probes through. Product
  code, and the last piece of the mediator itself. Depends on SF-6.

- [ ] **SF-8: Acceptance harness and fixtures** — `tests/acceptance/verify-egress-mediator.sh`
  implementing phases A–G (T3–T8, T17, T28, plus the listener-set, per-agent proxy-hop transport,
  forwarding, sink-reachability, control-plane-mount and no-agent-on-`egress-net` assertions), the
  four fixtures (controlled authoritative DNS server, HTTP collector, `Upgrade`-capable endpoint, two
  names sharing one address), and the **test-scoped resolved policy** —
  `policy/resolved/test-fixtures.yaml` plus `compose/overrides/test-egress.yaml` — which allowlists
  the fixture hosts. Without it T6's "the allowed domain succeeds" half has nothing to succeed
  against, since `default.yaml` allowlists provider endpoints and no fixture. **T34 is not here** —
  it is 01.6's, and 01.6 extends this harness rather than writing a second one. Test code; the only
  unit that needs all prior sub-features landed. Depends on SF-7.

**Sizing note.** Eight sub-features — the same count as the pre-revision plan, by a route worth
stating rather than glossing. The 01.6 split removed one (per-agent workload identity), and the
operator's decision at this re-plan kept the proxy-hop trust anchors it contained as a dedicated
SF-3 rather than folding them into the compose seam. The net is eight, but the composition is
different and the removed work is genuinely gone: no client certificates, no client-certificate
verification, no subject↔listener binding refusal, no T34, no R8.8 closure. The milestone README
still calls 01.3 the largest feature and anticipates "one sub-feature per role"; three roles plus
selection, policy artifact, trust anchors, pod plumbing and the harness is eight. DD-1's 2–5 ceiling
governs features per milestone, not sub-features per feature (the same reading 01.2 applied at
five). Each is judged against DD-1's ~120k-token session guideline: SF-1, SF-2 and SF-3 are below
it, SF-5 is the smallest shipped unit, and **SF-4, SF-6 and SF-8 are the three largest**.

**SF-4 grew twice during review and is re-judged rather than left as first sized.** It now carries the
Dockerfile and entrypoint, the service on four networks, `ipam` and static addressing, per-agent proxy
environment, `dns:`, secrets wiring, the audit volume, D15 hardening, the port-53 binding deviation
with its verification, the `dns:`-redirect verification by capture, 01.2's Deviation 3 closure, the
topology-test amendment, and the default project-mount repoint. It is **kept whole** because the pieces
share one file and one bring-up: `compose.yaml` is edited once, and splitting it would mean two
sub-features racing on the same file with a half-attached mediator in between. If it runs long at
build time, the clean split is the **image** (Dockerfile, entrypoint, hardening, port-53) from the
**compose seam** (networks, addressing, secrets, agent env, mounts, the topology-test amendment),
which touch disjoint files and can land in either order.

**The old SF-7 was flagged `[OVERSIZED]` at the 2026-09-04 gate and split on the operator's
decision** into product code and test code; that split survives the renumber as SF-7 and SF-8, which
keeps the product/test boundary on a sub-feature boundary. No sub-feature is flagged `[OVERSIZED]`
in the current list.

SF-6 is the closest remaining call — three listeners and three controls in one configuration surface,
and it absorbed the per-listener transport work that the old SF-5 did not carry. It is **kept whole**:
the three controls are evaluated in a single ordered pass over one connection, and the listeners are
the thing that selects which policy that pass uses, so splitting them would land a policy engine
knowingly incomplete at the boundary. If it runs long at build time, the clean split is the listener
surface plus controls 1+2 (policy correctness) from control 3 (resource ceilings), which share no
code path.

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
    identity: claude           # listener policy key. NOT a certificate subject at this feature --
                               # 01.6 binds a cert subject to this same value
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
been observed to derive them from. 01.1 SF-3's discovery capture now exists
(`docs/records/egress-discovery.md`) and is the first data that could inform them; it was taken under
`sbx` with UDP and ICMP invisible to the capture, so it bounds request volume loosely rather than
settling these values. Confirmed or adjusted at build time under DD-12 without gate re-approval.

### 2. Agent-side environment and mounts — produced by 01.3 SF-4, consumed by 01.4 and extended by 01.6

Added to each agent service on top of 01.2's Interface Contract 2. **The proxy URL scheme is per
agent, not uniform** — this is the contract's single most important change at the 2026-09-05
re-plan, and it is 01.1 SF-2's finding, not a preference:

| Variable / mount | `claude` | `codex` | `agy` | Requirement |
|---|---|---|---|---|
| `HTTPS_PROXY`, `https_proxy` | `https://<mediator addr>:3128` | **`http://<mediator addr>:3128`** | `https://<mediator addr>:3128` | D1, R5.5 |
| `HTTP_PROXY`, `http_proxy` | same as above | same as above | same as above | — |
| `NO_PROXY`, `no_proxy` | `localhost,127.0.0.1` | same | same | Keeps loopback MCP listeners unproxied (§ Inbound listeners) |
| `dns:` (service key, not env) | `[<mediator addr on that net>]` | same | same | R5.4, D3 |
| Proxy-hop CA trust | `NODE_EXTRA_CA_CERTS=/run/secrets/mediator-ca.crt` | **none — no TLS hop** | `SSL_CERT_FILE=/run/secrets/mediator-ca.crt` | R5.12, proxy hop only |
| secret `mediator-ca.crt` | mounted | **not mounted** | mounted | Criterion 9 |
| secret `<agent>-client.{crt,key}` | **01.6** | **01.6** | **01.6** | R8.8 — absent at this feature |

`codex` gets no `CODEX_CA_CERTIFICATE` and no CA secret: it never opens TLS to the mediator, so there
is no mediator certificate for it to validate. Its destination TLS is unaffected and uses its own
trust store, because the mediator splices rather than terminates (D4, R5.15). `agy`'s mechanism is
`SSL_CERT_FILE`, which is 01.1 SF-2's recorded finding rather than the placeholder the pre-revision
plan carried.

Both upper- and lower-case forms are set: the three agents' HTTP clients do not agree on which they
read. 01.1 SF-2 recorded `agy` honouring `HTTPS_PROXY` for both URL schemes — a **positive** result,
so no agent loses its route on this account.

**01.4 consumes this contract, not the reverse.** OAuth endpoints must be present in the resolved
allowlist before `oauth-interactive` can complete — the milestone README's stated reason 01.3
precedes 01.4.

**01.4's approved plan is now stale against this contract, and that is recorded rather than left to
be discovered at its build.** `plans/agent-authentication-and-state-persistence.md` still expects
`CODEX_CA_CERTIFICATE` on `codex`, a per-agent mTLS client key at `/run/secrets` "that 01.3 issues",
and cites `01.3 SF-7a` — a sub-feature number this re-plan retired. None of the three survives the
01.6 split. **01.4 must be re-planned in revision mode before it is built**, exactly as 01.1 must be
for the `deny_fqdns` correction (criterion 10). 01.4 is `[~] planned, awaiting build`, so nothing has
been built against the stale text; this is a plan-to-plan drift, not a code defect. Tracked on this
feature's review checklist; the re-plan itself is a separate `/plan-feature` invocation and is not a
property of this plan.

### 3. Proxy-hop trust anchors — produced by 01.3 SF-3, extended by 01.6

01.3 produces the CA and the **listener** certificates the two TLS hops need. Client certificates,
verification and the subject↔listener binding rule are 01.6's and are listed here only so the
boundary is explicit rather than inferred.

| Artifact | Location | Owner | Notes |
|---|---|---|---|
| CA private key | **Operator host only.** Never in an image, never in a volume, never in the mediator | 01.3 SF-3 | Narrower than the architecture document — criterion 9 |
| CA certificate | Compose secret: mediator, `claude`, `agy`. **Not `codex`** | 01.3 SF-3 | The proxy-hop trust addition; `codex` has no TLS hop to anchor |
| `claude-listener.{crt,key}` | Compose secret, mediator only | 01.3 SF-3 | Server certificate for the `claude-net` listener |
| `agy-listener.{crt,key}` | Compose secret, mediator only | 01.3 SF-3 | Server certificate for the `agy-net` listener |
| `codex-net` listener | **No certificate** — plain HTTP CONNECT | 01.3 SF-3 | 01.1 SF-2: `codex` rejects an `https://` proxy URL at parse time |
| `<agent>-client.{crt,key}` | Compose secret, scoped to one agent service | **01.6** | Subject `CN=<agent>`; issued by the same CA, by an extended `issue-identity.sh` |
| Client-certificate verification on a listener | Mediator configuration | **01.6** | Configured **off** in 01.3 (SF-6); SF-1's P1 establishes that the implementation can turn it on |
| Subject↔listener binding refusal (T34) | Mediator configuration | **01.6** | Unexecutable here: no client certificate exists to cross-present |

**Lifecycle** (the "defined lifecycle" R8.8 will require, defined here because 01.3 issues first):
certificates are issued with a bounded validity; the renewal path is
`bash scripts/issue-identity.sh <name>` followed by a mediator restart. Revocation is by reissuing
the CA and every certificate under it — no CRL or OCSP is introduced, which is proportionate to a
pod holding two listener certificates now and at most five after 01.6, and is recorded as the chosen
mechanism rather than an oversight. **01.6 inherits this lifecycle; it does not define a second
one, and it does not create a second CA.**

### 4. Audit line schema — produced by 01.3 SF-7

One JSON object per line, per connection attempt, allow and deny alike (R9.1):

```json
{"ts":"2026-09-05T12:00:00.123Z","agent":"claude","identity_source":"listener",
 "dest_host":"api.anthropic.com","dest_port":443,
 "resolved_ip":"203.0.113.10","verdict":"allow","control":null,
 "bytes_out":1234,"bytes_in":5678}
```

`verdict: "deny"` carries `control` as one of `allowlist`, `denylist`, `ratelimit`, and omits
`bytes_*`. (01.6 adds `identity` to that enumeration when a listener can refuse a client credential;
01.3 has no such refusal to log.)

**`identity_source` emits exactly one value at this feature: `listener`.** All three agents are
attributed by the network their connection arrived on, and the field says so on every line — so a
network-derived attribution is never read later as a cryptographic one. The field exists here rather
than in 01.6 because a log written without it would need reinterpreting retroactively once 01.6
lands, and because the milestone README makes "the audit line states the strength of its own
attribution" an acceptance criterion of 01.6 that this schema must be able to carry.

**01.6 extends the enumeration; 01.3 does not pre-declare its values.** What 01.6 adds depends on
its own verification result (whether `codex` or `agy` will send a proxy credential), and inventing
the value names now would be guessing at an outcome that does not exist yet. What 01.3 commits to is
the field, its position, and the fact that `listener` means network-derived.

**No `session` field.** Nothing in CONNECT carries the agent's session identifier. R9.8's
correlation is by `agent` and `ts` at this milestone; session-ID correlation depends on the agent
action recorder (D20), which this feature does not build.

### 5. Compose seam — extends 01.2's Interface Contract 4

01.2 declared four networks, three agent services, three volumes and a shared `./images` build
context. 01.3 adds: `ipam` subnets and a static `ipv4_address` for the mediator on each of the three
agent networks; the `egress-mediator` service attached to all four — which also makes `egress-net` a
live Docker resource for the first time, closing 01.2's recorded Deviation 3; an `audit` named volume
mounted into the mediator only; the **five** Compose secrets from Interface Contract 3
(`mediator-ca.crt`, `claude-listener.crt`/`.key`, `agy-listener.crt`/`.key` — client certificates are
01.6's and add three more); and the per-agent environment and `dns:` keys from Interface Contract 2.
01.5 replaces the mediator's local `build:` with a digest-pinned GHCR image and moves policy
compilation into its build stage.

### 6. Denial surface — produced by 01.3 SF-7, consumed by the operator (R12.2)

**Amended 2026-09-06 after SF-1 (Deviation 2).** The contract was written against a single
client-visible 403 for every refusal. SF-1 established that is unreachable for post-ClientHello
verdicts without terminating destination TLS, so the contract now has an authoritative operator half
and a best-effort client half.

**The authoritative surface is the structured denial record.** Every refused egress attempt that
reaches the mediator emits one, naming `agent`, `identity_source`, destination host and port,
resolved IP where known, `verdict=deny`, the refusing control, the reason, and the policy source and
remediation path. The operator-facing message rendered from that record is the R12.2 denial surface,
and it is what SF-7 must get right:

```
403 egress denied
destination: collector.example.com:443
control:     allowlist (default-deny; host not present for agent "claude")
policy:      policy/resolved/default.yaml  (edit policy/allowlist.base.yaml, then recompile)
```

**The client half is conditional on when the verdict is reached.**

- **Before the CONNECT is accepted** — CONNECT host off the agent's allowlist, in `deny_fqdns`, or
  resolving into `deny_cidrs`: the proxy returns HTTP 403 with the body above, and it reaches the
  agent's own error output. A legitimate gap is distinguishable from an attack in-band (R9.3).
- **After the ClientHello** — SNI disagreeing with the CONNECT host, or any other post-peek verdict:
  the proxy terminates the connection **without minting a destination certificate**, because minting
  one is the MITM capability D4 and criterion 5 forbid. A verifying agent sees a prompt TLS/proxy
  failure naming the mediator's certificate, not the destination. Diagnosis of *which* destination
  was refused requires the operator record.

Immediate refusal or termination in both cases, never a drop and never a hang (R9.4).

## Edge Cases

**`codex`'s proxy hop is plaintext, and that is the escalation record's open question answered.**
`codex` rejects an `https://`-scheme proxy URL at URL-parse time (01.1 SF-2), so its hop to the
mediator is plain HTTP CONNECT. Stated precisely:

- **What is exposed:** the CONNECT `host:port` line, in the clear, on `codex-net`.
- **To whom:** `codex-net` has exactly two members — the `codex` container and the mediator — and is
  `internal: true`. No third party observes it, and the mediator is the party that must read the
  destination anyway, since the destination *is* control 1's input. Nothing is disclosed to anyone
  who did not already have it.
- **What is not exposed:** destination TLS is untouched. The mediator splices (D4, R5.15), so
  `codex`'s traffic to `api.openai.com` is end-to-end encrypted exactly as `claude`'s is. No
  credential, request or response crosses `codex-net` in plaintext.
- **What is genuinely lost:** proxy-hop cryptographic identity for `codex`, and server
  authentication of the mediator to `codex`. The first is R8.8's, is **01.6's** to resolve or record,
  and on today's evidence resolves to network-derived identity for this agent. The second is bounded
  by the same two-member isolated network: to impersonate the mediator on `codex-net` an attacker
  must already be the mediator or hold an interface on that network, and no agent does.

Recorded as an accepted consequence with its scope stated, not as a control gap left implicit. It is
the reason `agy`'s TLS hop is kept rather than dropped for consistency (criterion 6): consistency
downward would give up server authentication on a hop that does not need to give it up.

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
can put its *source* back inside it. This is the half of T8 the tamper test would otherwise miss,
because the agent never touches the running config — it edits the input to the next build.

**This is not hypothetical, and the pre-revision plan understated it.** `compose/overrides/default.yaml`
as shipped by 01.2 binds `../:/workspace:rw` into all three agents — the solution tree itself, read-write.
The override's own comment calls it a demo stand-in for an operator project directory, which was
harmless while the tree held no control plane. **01.3 is the feature that puts a control plane into
that tree**, so the default profile would ship exactly the misconfiguration this entry describes, and
the Phase A assertion below would fail on the default profile rather than catching a mistake. A README
warning does not fix a default that is wrong.

Three mitigations, all in scope here:

1. **SF-4 repoints the default project mount off the solution tree.** `compose/overrides/default.yaml`
   binds a dedicated, git-ignored `workspace/` directory instead of `..`. The demo profile keeps a
   working `/workspace`; it stops being *this* checkout. This is the fix — the other two are defence
   behind it.
2. **The running mediator reads policy only from its own image layer and its Compose secrets**, never
   from a path any agent can write. A live compromise cannot reach the running enforcement point; the
   exposure was always the next build.
3. **Phase A asserts that no agent's mount set contains any `policy/`, `mediator/` or identity path**,
   so a future profile that reintroduces the mount fails the harness instead of shipping. With fix 1
   in place this assertion passes on the default profile, which is what makes it a regression test
   rather than a known-failing check.

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

**And `connections_per_minute` has no native mechanism in the selected implementation.** SF-1
verified two of control 3's three ceilings and found the third absent: `maxconn` bounds concurrency
and `delay_pools` bounds bytes — and, better than assumed, `delay_pools` does shape spliced CONNECT
tunnels — but Squid 6.13 has no per-client connection-rate directive at all
(`docs/records/mediator-selection.md`, P3). The schema field at Interface Contract 1 must not remain
an unimplemented promise. **SF-6 owns the choice and must make it explicitly:** implement the ceiling
with an `external_acl_type` token-bucket helper (this build carries
`--enable-external-acl-helpers`), or drop `connections_per_minute` from the resolved-policy schema
and record the gap here with its mitigation. Shipping the field while enforcing nothing is the one
option ruled out — a policy key that silently does nothing is worse than an absent one, and it is
the same failure shape as the SNI fallback SF-1 found.

**One further SF-1 result lands on control 3's concurrency half:** under peek, a single client
transaction accounts for more than one connection, so the effective ceiling is not the literal number
in the directive. SF-6 must calibrate the threshold empirically and SF-8 must assert the calibrated
value, not the nominal one.

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

**`agy` and the whole feature — resolved positive, no longer an open case.** The pre-revision plan
carried this as the feature's go/no-go: if `agy` did not honour `HTTPS_PROXY` it would have no route
on an `internal: true` network, 01.3 would ship two listeners instead of three, and the third would
be a `/milestone` revision. 01.1 SF-2 recorded a **positive** result — `agy` honours `HTTPS_PROXY`
for both `http://` and `https://` proxy URL schemes. All three networks and all three listeners are
in scope. Retained here as the record of a risk that was closed, not one that is still live.

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
`/run/secrets`. 01.2's smoke check requires each agent's mount set to *equal exactly*
`{/home/agent, /workspace}`, so it fails the moment SF-4 mounts `mediator-ca.crt` into `claude` and
`agy`. Extending that allowed set is explicit work in SF-4, listed in Files to Create/Modify — not an
incidental fix discovered during the build. Note the asymmetry the assertion must now tolerate:
`codex` mounts **no** secret at all, so the three agents no longer share one expected mount set, and
a check written as a single shared constant would fail on `codex` for the opposite reason. 01.6 will
extend the same allowed set again when client certificates land.

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
  path** — the control-plane-inside-the-project-mount case in Edge Cases. **This phase runs against
  the default profile**, so it fails unless SF-4's repointing of `compose/overrides/default.yaml`
  actually landed; that is deliberate, and it is the regression test for the mount fix. Also re-runs
  01.2's
  amended mount-set equality check.
- **Phase B — proxy-hop transport and T28.** The three hops are asserted to be what criterion 6 says
  they are, by observation rather than by reading the Compose file: the `claude-net` and `agy-net`
  listeners complete a TLS handshake and present a certificate chaining to the mediator CA; the
  `codex-net` listener accepts a plain HTTP CONNECT and **does not** speak TLS; each listener serves
  its own agent's policy, verified by requesting a host allowlisted for one agent and not another.
  Client-certificate verification is asserted **off** — a probe presenting no certificate is accepted
  on all three listeners, which is this feature's expected behaviour and is what 01.6 will invert.
  **Every TLS assertion here runs with certificate verification enabled at the client** — no
  `--insecure`, no `NODE_TLS_REJECT_UNAUTHORIZED=0`, no bypass flag. A passing handshake must prove
  the listener certificate's SAN actually matches the proxy URL authority (SF-3), because a bypass
  would make the one check that catches a mis-issued certificate pass unconditionally.
  For T28: the destination certificate chain observed from inside each agent container terminates at
  the origin's own CA, not the mediator's; the mediator's process holds no destination plaintext.
  **T34 is not exercised here** — no client certificate exists to cross-present. It is 01.6's, and
  01.6 extends this phase rather than adding a second harness.
- **Phase C — controls (T3, T5, T6, T7).** Denials are asserted by decision point, per Interface
  Contract 6 as amended. A non-allowlisted collector — a pre-CONNECT verdict — is refused with an
  HTTP 403 **whose body names the destination**, and logged. A post-ClientHello verdict (SNI
  disagreeing with the CONNECT host) is asserted to fail **promptly, with certificate verification
  enabled at the client, with no HTTP body expected**, and to produce a matching `verdict=deny`
  record naming the destination and the refusing control. No assertion anywhere in this phase
  requires a 403 body for a post-peek denial, and none uses an insecure-TLS bypass to obtain one. A raw TCP socket to a non-allowlisted host and port fails. An allowlisted domain and a
  denied domain sharing one address: the allowed one succeeds, the denied one is refused —
  demonstrating per-connection L7 evaluation rather than an IP snapshot. `169.254.169.254` is
  refused. Rate and concurrency ceilings refuse past their thresholds with `control=ratelimit`.
  A `/32` deny entry refuses its exact address and **does not** refuse the neighbouring address —
  the assertion that distinguishes a real single-address deny from a mis-sized mask (criterion 10,
  R5.1). And for criterion 12: with the `agy` auto-updater host excluded from the resolved allowlist,
  `agy` still starts, runs a task and exits normally, and the refused update check appears in the
  audit log — or the recorded R10.3 residual is taken instead, on evidence rather than on
  assumption.
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

- `docs/records/mediator-selection.md` — SF-1's P1–P8 results, the selected implementation and its
  exact version, and any recorded gap. The record stands whether the properties passed or failed.
  **P1 and P8 are recorded for 01.6's benefit** — verified here because the implementation is pinned
  here, consumed there.
- `docs/records/r8-8-identity-mechanism-gap-escalation.md` — **status closed.** The record still
  reads `Status: Open — blocks 01.3 build until resolved by /milestone revision`; the revision
  happened on 2026-09-04 and this plan is its result. Updated to record the resolution (identity split
  to 01.6, network-derived identity accepted for 01.3, `agy` keeps its TLS hop, `codex` hop is plain
  HTTP) so the record does not outlive the block it describes.
- `README.md` — the mediator's role in bring-up, the certificate-issuance step before first start,
  the R12.2 troubleshooting path for a blocked destination (read the mediator's denial record — the
  403 body carries it only for pre-CONNECT verdicts, and a post-ClientHello denial reaches the agent
  as a bare TLS failure; then edit `policy/allowlist.base.yaml`, recompile, restart), and the D3 note
  that a mediator outage presents
  as DNS failure first.
- `docs/ARCHITECTURE_AND_DESIGN.md` — update the Open Items Carried Into Build table with the
  resolved `agy` proxy and MCP-transport rows this feature consumes, and record the four decisions
  narrowing or reinterpreting the ratified text: the mediator exposes two listeners per agent
  network rather than one (criterion 1), T28's pass criterion distinguishes the destination chain
  from the proxy-hop anchor (criterion 5), **the three agent-facing listeners are not a uniform
  `https://` surface — `codex`'s hop is plain HTTP CONNECT** (criterion 6), and the CA private key
  stays offline (criterion 9). Also closes 01.2's Deviation 3: `egress-net` becomes a live Docker
  resource when SF-4 attaches the mediator to it.
- `REQUIREMENTS.md` — **amend T28's pass criterion** per criterion 5's recorded decision, in SF-3.
  This is the one change this feature makes to the authoritative register; it is deliberate, approved
  at Gate 4, and made because the alternative is a register that cannot be satisfied. R8.8 is not
  touched here — 01.6 owns it, and 01.6 carries T34's separate amendment. An interpretation recorded
  in only one of the two documents is drift by construction, which is why this lands in the register
  rather than only in the plan.
- `policy/resolved/README.md` — states that the directory is generated output, names its producer,
  and warns against hand-editing (SC-6 depends on that being true).

## Files to Create/Modify

Paths are relative to `solutions/agent-containerization/`.

| File | Action | Changes |
|------|--------|---------|
| `docs/records/mediator-selection.md` | Create | SF-1's P1–P8 verification results, the pinned proxy version, and the selection decision |
| `docs/records/r8-8-identity-mechanism-gap-escalation.md` | Modify | Status `Open` → resolved by the 2026-09-04 `/milestone` revision. The block it describes no longer exists |
| `scripts/compile-policy.sh` | Create | Zero-pack policy compiler: base allow/deny + profile → `policy/resolved/default.yaml`. 01.5 moves this into the mediator image build stage |
| `policy/resolved/default.yaml` | Create | The committed SC-6 artifact. Generated; not hand-edited. Excludes the `agy` auto-updater host and records why (criterion 12, R10.3) |
| `policy/resolved/README.md` | Create | Generated-output notice and producer |
| `policy/denylist.base.yaml` | Modify | Add `deny_fqdns: []` — closes the R5.1 MUST that 01.1's contract left out (criterion 10). Correct the header comment that asserts nothing in the register asks for FQDN deny |
| `profiles/default.yaml` | Modify | Add per-agent `rate_limits`, the per-agent `listener` block and the `startup_check` block (allowed, denied, `offline`). Correct the `mounts.project.path` comment, which still says the override binds `..` |
| `images/mediator/Dockerfile` | Create | Selected proxy + resolver + audit writer. Non-root, read-only rootfs layout, no secret in any layer |
| `images/mediator/entrypoint.sh` | Create | Stage-1 schema validation, config render from the resolved policy, stage-2 reachability check, then exec the proxy |
| `mediator/config/proxy.conf.tmpl` | Create | The three per-network listeners (two TLS, one plain HTTP CONNECT), per-listener policy selection, the three controls, CONNECT-only method restriction, log format with `identity_source`, `deny_info` body. Client-certificate verification present but **switched off** — 01.6 turns it on |
| `mediator/config/resolver.conf.tmpl` | Create | Closed resolver: allowlisted names answered, everything else REFUSED, no forwarding |
| `mediator/identity/.gitignore` | Create | Excludes all private key material (R8.7's spirit; nothing secret in version control) |
| `mediator/identity/README.md` | Create | CA layout, subject naming, validity, renewal and revocation path — the lifecycle 01.6 inherits |
| `scripts/issue-identity.sh` | Create | Offline CA creation and **listener** certificate issuance for `claude-net` and `agy-net`, each with an `iPAddress` SAN matching that network's static mediator address. Runs on the operator host; the CA private key never leaves it. 01.6 extends the same script with client certificates |
| `compose/compose.yaml` | Modify | `egress-mediator` service on four networks; `ipam` subnets + static mediator `ipv4_address` per agent network; `audit` volume mounted to the mediator only; five Compose secrets (CA + two listener key pairs); `dns:` and **per-agent** proxy env (`https://` for `claude`/`agy`, `http://` for `codex`); the CA secret on `claude` and `agy` only |
| `compose/overrides/default.yaml` | Modify | Profile-selected mediator bits (rate limits, `startup_check.offline`) **and repointing the project mount off the solution tree** — `../:/workspace:rw` becomes a git-ignored `workspace/` dir (Edge Cases: control plane inside the project mount) |
| `policy/resolved/test-fixtures.yaml` | Create | Test-scoped resolved policy allowlisting the harness fixtures. Never loaded by the default profile |
| `workspace/.gitkeep` | Create | Bind source for the repointed default project mount, committed so Docker does not auto-create it root-owned |
| `compose/overrides/test-egress.yaml` | Create | Test-only override: the four harness fixtures on `egress-net`, the test-scoped policy, `startup_check.offline: true`. Not a shipped profile |
| `tests/acceptance/verify-egress-mediator.sh` | Create | The Test Command. Phases A–G. `#!/usr/bin/env bash`, `set -euo pipefail`, mode 644, invoked as `bash` |
| `tests/acceptance/verify-pod-topology.sh` | Modify | Extend the allowed mount set with `/run/secrets` entries and the expected proxy/DNS environment, so 01.2's equality assertion survives 01.3 |
| `.gitignore` | **Modify** | Add private key material and generated secret files under `mediator/identity/`, plus the new `workspace/` project-mount directory. **Changed from Create at the 2026-09-05 re-plan** — 01.2 landed a `.gitignore` in `solutions/agent-containerization/` (verified on disk), so the pre-revision plan's "no `.gitignore` today" is stale |
| `README.md` | Modify | Mediator bring-up, issuance step, R12.2 denial troubleshooting, D3 outage note, and the warning that the project mount must not be the solution tree |
| `REQUIREMENTS.md` | Modify | **Amend T28's pass criterion** per criterion 5 (destination chain, not the proxy-hop anchor). The only register change this feature makes; R8.8 untouched |
| `docs/ARCHITECTURE_AND_DESIGN.md` | Modify | Open-items rows resolved by this feature; the narrowing decisions in criteria 1, 5, 6 and 9; 01.2's Deviation 3 closed |

## Dependencies

**On Feature 01.1 — complete. These records exist and are inputs, not blockers:**

The pre-revision plan listed the first two of these as open go/no-go questions. 01.1 is `[x]` and
they are answered; the answers are what caused the 2026-09-04 milestone revision and this re-plan.

- **01.1 SF-2, client-certificate presentation per agent — answered, and it split the feature.**
  `claude` **yes** (`CLAUDE_CODE_CLIENT_CERT`/`_KEY`, confirmed empirically); `codex` **no,
  structurally** — it rejects an `https://`-scheme proxy URL at parse time and cannot reach a TLS
  proxy listener at all; `agy` **no** — it completes the handshake to `CertificateRequest` and has
  nothing to present. Two of three cannot meet R8.8's ratified mTLS mechanism. That was escalated to
  `/milestone` (`docs/records/r8-8-identity-mechanism-gap-escalation.md`) rather than absorbed as a
  plan-time fallback, and the revision **split identity out to Feature 01.6**. What lands in this
  plan is the consequence: a non-uniform listener surface (criterion 6) and per-agent policy
  selection on network-derived identity. **R8.8 is not closed by this feature and is not claimed by
  it.**
- **01.1 SF-2, `agy` `HTTPS_PROXY` and CA-trust mechanism — answered positive.** `agy` honours
  `HTTPS_PROXY` for both `http://` and `https://` schemes, and trusts a CA via `SSL_CERT_FILE`. All
  three agent networks, listeners and allowlists are in scope; no agent loses its route.
- **01.1 SF-2, default MCP transport per agent and per server.** Determines whether any MCP traffic
  crosses the enforcement point at all, and therefore whether the resolved allowlist needs entries
  for it. R7.15's inventory is 01.5's, but the allowlist consequence is this feature's.
- **01.1 SF-3, `policy/allowlist.base.yaml` and `policy/denylist.base.yaml`.** The compiler's only
  inputs. The allowlist arrives marked provisional (D17); that flag propagates rather than blocking.

**On Feature 01.2 — the pod this feature attaches to:**

- `compose/compose.yaml`'s four networks, three agent services and build context.
- `profiles/default.yaml`'s schema, which SF-2 extends rather than replaces.
- `tests/acceptance/verify-pod-topology.sh`, amended by SF-4.
- 01.2's recorded **Deviation 3** (`egress-net` not a live Docker resource until a service attaches
  to it) is closed by SF-4, not carried forward.

**On later features — deliberately absent here:**

- **No authentication.** 01.4 owns `AUTH_MODE`. Until it lands, no agent reaches a provider through
  the mediator and this feature's tests use controlled fixtures.
- **No policy compiler as a build stage, no packs.** 01.5 owns D10's build-stage compilation and
  pack composition. SF-2 ships the zero-pack script and fixes the artifact schema so 01.5 has a
  target.
- **No client authentication and no R8.8 closure.** **Feature 01.6** owns per-agent workload
  identity, client-certificate verification, the subject↔listener binding refusal and T34. This
  feature ships the listener surface, the CA and the listener certificates 01.6 builds on, and
  per-agent policy selection that works without any of it. SF-1's P1 and P8 are verified here
  precisely because the proxy implementation is pinned here and 01.6 cannot re-open that choice.
  **A register-level question is handed to 01.6 with it, and it is named here so it is not lost:**
  `REQUIREMENTS.md` R8.8 is unchanged and requires a *distinct issued workload identity* used to
  authenticate to the enforcement point. The milestone README accepts "otherwise **network-derived**"
  as the weakest permitted form. Network topology is not an issued credential, so those two texts do
  not agree, and 01.6 must either close R8.8 with a real credential for every agent or amend R8.8 in
  the register the way this feature amends T28. **01.3 neither closes that gap nor widens it** — this
  feature never claimed R8.8 — but the milestone does not close until 01.6 resolves it, and an
  interpretation living only in a milestone README is drift by construction.
- **No credential brokering.** The mediator's fifth role is Milestone 03, blocked on Q1 and Q9. D6
  makes cryptographic identity its precondition, which is 01.6's to establish — and on today's
  evidence may qualify `claude` alone.
- **No agent action recorder.** R9.7, D20 and T35 are not in this feature's acceptance criteria.
  Criterion 7 records the resulting limit on R9.8 correlation rather than leaving it implied.
- **No off-host log shipping.** R9.6 is a MAY. The audit sink is mediator-local at this milestone,
  which is one of the two shapes D12 permits, and it shares the mediator's fate — D12's stated
  tradeoff, accepted here and recorded.

**External:**

- Docker Desktop on macOS 26, Apple silicon (R11.1, A1). Namespaced-sysctl and `ipam` behaviour are
  properties of its Linux VM and are verified in SF-4, not assumed.
- Upstream package sources reachable at mediator image build time.
- A controlled authoritative DNS server and a controlled HTTP collector for T3, T4 and T6. Both run
  as test fixtures inside the Compose project on the external network — no third-party service is
  used as a test target, and nothing leaves the host.

**Repository state:** greenfield for this component. No proxy, resolver, CA or audit code exists
anywhere in the repository. Shell scripts follow `#!/usr/bin/env bash`, `set -euo pipefail`, mode
644, invoked as `bash script.sh`.

## Architectural Deviations

### Deviation 1: self-cascade listener topology for the TLS-fronted agents
- **What changed:** The `claude` and `agy` proxy hops are served by **two** listeners each, not one.
  An agent-facing `https_port` terminates the proxy-hop TLS and forwards the CONNECT, via
  `cache_peer` + `never_direct`, to a **loopback-bound** `http_port ... ssl-bump` listener dedicated
  to that agent, where peek+splice runs and the per-agent policy is evaluated. `codex` is unchanged:
  one plain `http_port ... ssl-bump` listener does both jobs. Per-agent identity survives the hop
  because each fronted agent has its own inner port name, and `myportname` is what selects policy.
- **Originally planned:** The Approach section's request-path diagram routes each agent to a single
  "mediator listener for THAT network" which both accepts the hop and peeks the SNI ("control 1:
  CONNECT host on allowlist? and SNI == CONNECT host?"). SF-6 is written as "the three listeners of
  criterion 6 (two TLS, one plain HTTP CONNECT) in one instance", one per agent.
- **Why necessary:** Squid 6.13 cannot do both on one listener, verified in SF-1. `https_port`
  refuses the `ssl-bump` flag outright (`FATAL: ssl-bump on https_port requires tproxy/intercept
  which is missing`), and `http_port ... tls-cert=` does not terminate client TLS at all — that
  `tls-cert=` is the bumping certificate, and a raw TLS probe against such a port fails with
  `wrong version number`. Proxy-hop TLS therefore requires `https_port`, SNI peek requires
  `ssl-bump`, and the two cannot be the same listener. See `docs/records/mediator-selection.md`,
  P6 and P7.
- **Impact:** SF-6 renders five listeners, not three. Criterion 1's enumeration is **unaffected** —
  the inner listeners bind loopback inside the mediator, which criterion 1 already permits
  ("any management, metrics, admin or health endpoint binds the loopback interface inside the
  mediator, never an agent network"), and the permitted set on each agent network remains exactly
  {proxy, resolver}. SF-8 Phase A's listener enumeration must assert that the inner listeners are
  **not** reachable from any agent network. SF-7 is affected: the front listener logs the tunnel and
  the inner listener logs the verdict, so a denied connection produces a front line reading
  `status=200 squid=TCP_TUNNEL` alongside the inner `status=403 squid=TCP_DENIED`. The audit writer
  must take the verdict from the inner listener or the log will misreport denials for two of three
  agents. SF-7's stage-2 self-check should also warm the cascade — the first request through a cold
  `cache_peer` returned 500 while the peer was still being probed.

### Deviation 2: no client-visible 403 body; the denial surface is operator-facing only
- **What changed:** A refused connection reaches the agent as a **TLS failure**, not as an HTTP 403
  with a body naming the destination. The destination, verdict and refusing control are recorded on
  the audit line and exposed through the mediator's own denial surface; they are not delivered to
  the agent.
- **Originally planned:** Acceptance criterion 5 and the Approach section: "A refusal at any control
  writes `verdict=deny` with the refusing control named, and returns HTTP 403 with a body naming the
  destination. The agent sees an error it can act on rather than a hang." Interface Contract 6
  (Denial surface) is written against that response. SF-1's P5 tests it as a selection property:
  "An immediate, body-bearing refusal naming the destination (R9.3, R9.4, R12.2)".
- **Why necessary:** Structural, and no configuration setting reaches it. A listener that peeks must
  accept the CONNECT before it can see the ClientHello — verified: a raw `CONNECT` to a
  non-allowlisted host returns `HTTP/1.1 200 Connection established`, and the refusal is then
  delivered inside the TLS session the client starts. With `generate-host-certificates=off` — which
  is mandatory, since minting a per-destination certificate is exactly the MITM capability D4 and
  criterion 5 rule out — Squid presents its static listener certificate, whose SAN cannot match the
  destination. Every verifying client aborts there: `SSL: no alternative certificate subject name
  matches target hostname 'agy-only.test'`. The body is unreachable whether or not the agent trusts
  the mediator CA. This follows from splicing rather than from Squid: any proxy that declines to
  decrypt cannot deliver an application-layer error inside a session it declines to terminate, so
  `iron-proxy` inherits the identical failure. See `docs/records/mediator-selection.md`, P5.
- **Impact:** Criterion 5's client-visible half and Interface Contract 6 need rewriting before SF-7
  builds against them; R9.3, R9.4 and R12.2 must be satisfied by the audit log and the operator
  denial surface instead. SF-8's Phase C assertions change shape — a refusal is asserted as a TLS
  failure plus a matching `verdict=deny` audit line, not as a 403 body. The Approach section's claim
  that the agent "sees an error it can act on rather than a hang" survives in weakened form: the
  agent gets a prompt, distinguishable failure, but one that names the mediator's certificate rather
  than the blocked destination, so agent-side diagnosis of *which* destination was refused is not
  possible without the operator reading the audit log. **Direction on the criterion-5 amendment was
  referred to an external review at the operator's instruction; it is not resolved by this record.**
