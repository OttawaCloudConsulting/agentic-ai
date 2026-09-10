# Per-Agent Workload Identity — 01.6

**Feature:** 01.6 Per-agent workload identity
**Date:** 2026-09-09
**Outcome:** R8.8 is closed with **three identity forms across three agents**, each the strongest
form that agent's client actually supports. Every audit line carries the issuing agent and the
**strength** of that attribution in `identity_source`. The Milestone 03 credential-brokering gate is
the cryptographic form alone, so **`claude` only** — recorded here because Milestone 03 inherits it
as a gate rather than rediscovering it.

This is the record the milestone's Definition of Done names. It is the authority on which agent
carries which form; `REQUIREMENTS.md` T34 (amended 2026-09-09) states the property, and
`mediator/identity/README.md` owns the trust material's lifecycle.

## The three forms

| Agent | Form | What is presented | `identity_source` on its verdict lines | Refusal of a wrong identity |
|---|---|---|---|---|
| `claude` | **Cryptographic** | A client certificate, subject `CN=claude`, issued by the mediator CA, `clientAuth` EKU only, no SAN | `listener+mtls` | `403` at the identity ACL, `control=identity`, `reason=subject_mismatch`, `ERR_MEDIATOR_IDENTITY` |
| `codex` | **Credential** | `Proxy-Authorization: Basic`, built by the client from proxy-URL userinfo, over the **plain HTTP** hop | `listener+proxy_auth` | `407` from that listener's own `proxy_auth` ACL |
| `agy` | **Credential** | The same, over the **TLS** hop | `listener+proxy_auth` | `407`, as above |

Underneath all three is the network-derived baseline every agent has carried since 01.3: a
connection is attributed to the agent whose `internal: true` network it arrived on. `listener` alone
is what an audit line reads when nothing stronger was verified on that connection — including on
`claude`'s own subject-mismatch refusal, where no certificate was accepted and the line says so.

**Why the forms differ, and why that is not a gap.** 01.1 SF-2 measured that only `claude` can
present a client certificate at all: `codex` rejects an `https://`-scheme proxy URL at parse time
and never reaches a TLS listener, and `agy` reaches the `CertificateRequest` stage with nothing to
offer. Neither client exposes a credential knob. 01.6 SF-1 then measured that **both** construct
`Proxy-Authorization` from proxy-URL userinfo, preemptively — `codex` on the plain transport, `agy`
on TLS and on plain — which is what the credential form rests on. The evidence is
`docs/records/agent-verification.md` (per-agent capability, criteria 5 and the SF-1 section) and
`docs/records/mediator-selection.md` P8/P9 (the mediator side: `proxy_auth` on an `http_port` and on
an `https_port`, and `basic_ncsa_auth` with `openssl passwd -apr1` hashes on the shipped Squid
build).

## Where each form is enforced

One mechanism per listener, rendered from **one profile field** — `agents.<agent>.listener.client_auth`
(`mtls` | `proxy_auth` | `none`), required-not-defaulted, compiled into `policy/resolved/*.yaml` and
read by `images/mediator/entrypoint.sh` in the same pass that renders the enforcement. The
certificate subject and the credential username are both the resolved policy's `identity` value, so
issuance, enforcement and the audit line's `agent` field carry one token.

- **`mtls`** — `clientca=` and `tls-cafile=` on that agent's **front** `https_port` only, in
  required mode. An `acl <name> user_cert CN <identity>` binding rule denies a chain-valid
  certificate carrying another agent's subject, and the deny is rendered **ahead of** the agent's
  allow rules. The inner and self-check listeners are deliberately untouched: the mediator's own
  cascade traffic reaches the inner listener, and a `clientca=` there would refuse it.
- **`proxy_auth`** — `basic_ncsa_auth` against a single htpasswd held by the **mediator alone**, with
  an `acl <name> proxy_auth <identity>` term per listener. Both agents verify against the same
  file — one file, two usernames — so the per-listener ACL is the whole of the binding, which is
  what T34's credential case asserts.
- **Attribution** — `idsrc` is annotated per layer and appears as the audit line's
  `identity_source`. It is re-derived on the inner layer because the front→inner `cache_peer` hop
  is a new master transaction; a front-only annotation never reaches the verdict line.

Identity is **never** taken from a header the agent controls. Header propagation was rejected as
agent-forgeable; the mechanism is topological — the inner listener binds `127.0.0.1` and
`cache_peer_access` admits only that agent's own front.

## Structural containment, which all three have

Each agent holds exactly one network interface, on its own `internal: true` network, which carries
that agent and the mediator and nothing else. No agent holds an interface on another agent's
network or on `egress-net`. So for every agent — the two carrying a presentable credential
included — there is **no route** over which one agent's identity could be presented to another
agent's listener. The cross-binding refusals above are the second bar, not the only one.

Asserted by enumeration in `tests/acceptance/verify-egress-mediator.sh` Phase H, against the
rendered shipped Compose configuration rather than `compose.yaml` alone, so an override that added
a network could not pass vacuously.

## Lifecycle

Inherited from 01.3, not duplicated. **One CA**, `mediator/identity/`, operator host only. Full
detail — issuance, renewal, revocation, distribution — is in `mediator/identity/README.md`.

| Material | Validity | Rotation | Held by |
|---|---|---|---|
| Mediator CA | 730 days | `issue-identity.sh ca --force`, then reissue everything under it | Operator host |
| Listener certificates (3) | 365 days | `issue-identity.sh <agent>` (renewal reuses the recorded address) | Mediator, as Compose secrets |
| Client certificate (1, `claude`) | 365 days | `issue-identity.sh client claude --force` | `claude` alone, as a Compose secret |
| Proxy credentials (2, `codex`/`agy`) | **No expiry** | `issue-identity.sh credential <agent> --force` — rebuilds the htpasswd from the plaintexts on disk | Each agent its own; the htpasswd is the mediator's alone |

Issuance verifies its own output before reporting success, in every form: chain, subject, EKU and
absence of SAN for a certificate; username-against-policy and hash-accepts-plaintext for a
credential. The tempting repair for a handshake or `407` failure at the agent is to disable
verification, and that is the failure this guards.

**A credential is not CA-bound.** Reissuing the CA revokes every certificate under it and does not
touch the two credentials; rotating a credential does not touch the CA. The two lifecycles are
independent and the revocation section of `mediator/identity/README.md` says so explicitly.

## The Milestone 03 brokering gate

**Only an agent whose identity is `listener+mtls` may be brokered AWS credentials — today that is
`claude` alone.** Milestone 03 inherits this as a gate (D6, D13).

The credential form is a real, verified, per-agent identity and it is not admitted, for a reason
specific to it: `codex`'s credential crosses its plain-HTTP proxy hop **in the clear**. The exposure
is bounded — a two-member `internal: true` network — but the credential is also visible in that
agent's own environment and `/proc`, so an attacker who has the agent has the identity, and there is
no second factor as there is with a private key the agent holds but the network never carries. The
residual is recorded, bounded to `codex`, and deliberately not mitigated; it is the concrete reason
the gate is the cryptographic form alone rather than "any verified identity".

If Milestone 03 finds that restriction intolerable, the resolution is a register-level decision at
that milestone — not a local relaxation of this gate.

## Recorded residuals

1. **The cascade warm-up is skipped for `claude` and `agy`.** The mediator cannot authenticate to
   its own authenticating front — it holds no client key, and only password *hashes* — so the peer
   is not pre-warmed. The first request after a mediator start may be answered `500` and retried;
   Squid revives the peer about a second later. Three alternatives were rejected on identity
   grounds; the reasoning is in `images/mediator/entrypoint.sh`.
2. **A cert-less refusal produces no verdict line.** Required-mode `clientca=` refuses at the
   handshake, before Squid has a request to log. The trail carries one anonymous
   `proxy_internal` event with no agent, destination or verdict — so nothing on it *names* the
   attempt. An operator sees silence where a denial would be; the populated surface is the
   mediator's own `squid-cache.log`.
3. **A `proxy_auth` refusal is `407` and never `403`.** A `proxy_auth` ACL that misses halts ACL
   evaluation on its line, so Squid answers its own challenge: there is no `deny_info` route,
   no `ERR_MEDIATOR_IDENTITY` page and no `control=identity` verdict on that path. Measured, not
   assumed (P9).
4. **`codex`'s credential is plaintext on the wire and in its own environment.** See the gate
   above. Bounded, recorded, not mitigated.

## Verification

`tests/acceptance/verify-egress-mediator.sh` — Phase B for the enforcement inversions (cert-less
refused, credential-less refused `407`, each agent's own identity accepted, the credential-form T34
case) and Phase H for T34's certificate and structural cases. `verify-pod-topology.sh` asserts the
agents' mount sets and runtime proxy environment; `verify-auth-state.sh` asserts the same for the
authentication path and is run by the operator by hand, for the reason its header gives.
