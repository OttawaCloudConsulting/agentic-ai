# Proxy-hop trust anchors

The offline CA, the mediator's listener certificates, and — since 01.6 — the agents' own workload
identities: one client certificate and two proxy credentials. All produced by
`bash scripts/issue-identity.sh` on the **operator host** (01.3 SF-3, extended by 01.6 SF-2 and
SF-3). Which agent carries which form, and why, is `docs/records/workload-identity.md`; this file
owns the material and its lifecycle.

Nothing in this directory except this file and `.gitignore` is committed.

## What exists, and where it lives

| Artifact | Path | Reaches the mediator? |
|---|---|---|
| CA private key | `ca/mediator-ca.key` | **Never.** Operator host only — not an image layer, not a volume, not a Compose secret |
| CA certificate | `ca/mediator-ca.crt` | Yes, as a Compose secret — mediator, `claude`, `agy`. **Not `codex`** |
| `claude` listener key pair | `listeners/claude-listener.{crt,key}` | Yes, as a Compose secret — mediator only |
| `agy` listener key pair | `listeners/agy-listener.{crt,key}` | Yes, as a Compose secret — mediator only |
| `codex` **bumping** key pair | `listeners/codex-listener.{crt,key}` | Yes, as a Compose secret — mediator only. **Not a proxy hop** — see below |
| `claude` client key pair (01.6 SF-2) | `clients/claude-client.{crt,key}` | Yes, as a Compose secret — **`claude` alone**. The mediator verifies it against the CA certificate it already holds and never holds this pair |
| Proxy credentials (01.6 SF-3) | `credentials/{codex,agy}.cred` | Yes, as a Compose secret — **each agent its own only**. `<username>:<password>`, spliced into that agent's proxy URL at start |
| Credential htpasswd (01.6 SF-3) | `credentials/htpasswd` | Yes, as a Compose secret — **mediator only**. `apr1` hashes of both credentials; not exempted for any agent |

Keeping the CA private key off the mediator is narrower than
`docs/ARCHITECTURE_AND_DESIGN.md`'s original "CA private key injected at runtime from a secret
manager", and it moves in the safer direction: a mediator compromise yields the certificates the
mediator presents, but not the ability to mint agent identities (criterion 9).

`codex` gets no CA certificate because it opens no TLS to the mediator — 01.1 SF-2 recorded that it
rejects an `https://`-scheme proxy URL at URL-parse time, before any handshake. Its destination TLS
is unaffected: the mediator splices and never terminates it (D4, R5.15).

**`codex` nevertheless has a listener key pair, and it is a different thing from the other two.**
`claude`'s and `agy`'s are *server* certificates for their TLS proxy hops. `codex`'s is Squid's
*bumping* certificate: its listener peeks the ClientHello to enforce the SNI control, and a
`ssl-bump` port with no `tls-cert=` parses cleanly and then silently stops peeking — measured at
01.3 SF-6 (`docs/records/proxy-verification.md`, finding 4). It is never presented on an allowed
path, because peek+splice hands the origin's own chain through untouched, and `codex` neither trusts
nor validates it. Recorded as Deviation 5 on the feature plan, which is where criterion 9's "two
listener key pairs" is corrected to three.

## Subject naming

| Role | Subject | Issued by |
|---|---|---|
| CA | `CN=agent-pod mediator CA` | itself |
| Listener certificate | `CN=mediator-listener-<agent>` | 01.3 SF-3, this script |
| Client certificate | `CN=<agent>` | **01.6 SF-2, built.** The same CA, the `client` mode of this script. `claude` only |

The two leaf forms are deliberately distinct. T34 (01.6) is a refusal to accept one agent's client
subject on another agent's listener; a shared subject form between server and client roles would
make that check ambiguous.

The subject is **not** the agent key: it is the resolved policy's `agents.<agent>.identity` value,
read at issuance and read again by the renderer that emits the `acl <name> user_cert CN <identity>`
binding rule. They are the same token in every shipped profile, and reading the field is what makes
that true by construction rather than by coincidence. A proxy credential's **username** is the same
value, for the same reason — one identity across issuance, policy, enforcement and the audit line's
`agent` field.

## SANs: an IP literal, not a name

Interface Contract 2 points each TLS-hop agent at `https://<mediator addr on that net>:3128` — an
**IP literal**, because Compose `dns:` and the mediator's static addressing work in addresses.
Each listener certificate therefore carries an `iPAddress` SAN for the mediator's static address on
that agent's network. A `dNSName` SAN does not match an IP literal, and a CN alone is not honoured
by modern TLS stacks.

Get this wrong and the proxy hop fails verification at the agent. The tempting repair is to disable
TLS verification at the agent, which would silently give up the server authentication the TLS hop
exists for — so `issue-identity.sh` verifies the chain, the SAN and the `serverAuth` EKU of every
certificate it issues before it reports success, and SF-8 Phase B asserts the handshake succeeds
with no insecure-TLS bypass.

The static addresses are SF-4's (`ipam` blocks in `compose/compose.yaml`). They are **inputs** to
issuance and are never hardcoded in the script. The address used is recorded next to the
certificate so renewal needs no arguments.

If the mediator's static address on a network changes, re-run the `listener` form with the new
`--ip`: issuance re-issues rather than refusing. Renewal (`issue-identity.sh <agent>`) always
reuses the **recorded** address, so it is the wrong command for an address change.

## Trust distribution, per agent (criterion 6)

| Agent | Proxy hop | Mediator CA delivered as | How the agent trusts it |
|---|---|---|---|
| `claude` | `https://` | Compose secret `mediator-ca.crt` | `NODE_EXTRA_CA_CERTS=/run/secrets/mediator-ca.crt` |
| `agy` | `https://` | Compose secret `mediator-ca.crt` | `SSL_CERT_FILE=/run/secrets/mediator-ca.crt` |
| `codex` | `http://` | **not mounted** | nothing to trust — no TLS hop exists |

Both mechanisms are 01.1 SF-2's recorded findings. The environment and secret wiring itself is
SF-4's; the decision and the mapping are recorded here.

This single trust addition is the recorded exception to T28. It anchors the **proxy hop only**. No
mediator CA appears in any destination TLS chain — the mediator splices destination traffic and
holds no destination plaintext (see `REQUIREMENTS.md` T28, amended by this sub-feature).

## Lifecycle

R8.8 requires a defined lifecycle for issued identity. It is defined here because 01.3 issues
first; **01.6 inherits it, does not define a second one, and does not create a second CA.**

**Validity.** CA 730 days. Listener certificates 365 days. Client certificates 365 days, the same
bound and the same CA — 01.6 inherits this lifecycle rather than defining a second one. Bounded, and
short enough that renewal is a routine the operator has performed before it is needed.

**Proxy credentials have no expiry.** They are 192-bit random secrets, not certificates: there is no
validity field to bound and nothing that stops working on a date. Rotation is re-issue, and it is
the operator's to schedule. This is the one piece of trust material here that will not tell you it
has gone stale.

**Bring-up order.** Issuance comes before `docker compose up`: the Compose `secrets:` entries have
`file:` sources pointing into this directory, so the project fails to start if the certificates do
not exist yet.

**Issuance.**

```bash
bash scripts/issue-identity.sh ca
bash scripts/issue-identity.sh listener claude --ip <mediator addr on claude-net>
bash scripts/issue-identity.sh listener codex  --ip <mediator addr on codex-net>
bash scripts/issue-identity.sh listener agy    --ip <mediator addr on agy-net>
bash scripts/issue-identity.sh client     claude
bash scripts/issue-identity.sh credential codex
bash scripts/issue-identity.sh credential agy
bash scripts/issue-identity.sh status
```

`codex` is in the listener list for the bumping certificate described above, not for a proxy hop.
The last three lines are 01.6's, and each refuses to run for an agent whose resolved policy does not
ask for that form — `client` requires `client_auth: mtls`, `credential` requires `proxy_auth`. An
identity with no consumer is refused at issuance rather than issued and left inert.

**Renewal.** Re-issue against the recorded address, then restart the mediator:

```bash
bash scripts/issue-identity.sh claude                                  # listener, recorded address
bash scripts/issue-identity.sh client claude --force                   # client certificate
bash scripts/issue-identity.sh credential codex --force                # proxy credential
docker compose -f compose/compose.yaml restart egress-mediator
```

Renewal reuses the CA. The agents' trust anchor does not change, so no agent needs reconfiguring.

**A renewed agent identity needs the AGENT restarted too, not only the mediator.** The client key
pair and the proxy credential both arrive as Compose secrets that the agent reads **at start** —
the credential is spliced into its proxy URL by the entrypoint, and the certificate is named by
`CLAUDE_CODE_CLIENT_CERT`/`_KEY`. A mediator-only restart after a rotation leaves that agent
presenting the old identity: `403` with `reason=subject_mismatch` for the certificate form, `407`
for the credential form. Re-issuing a credential also rebuilds the htpasswd from every plaintext on
disk, and `basic_ncsa_auth` reads that file at start and caches accepted credentials, so the
mediator restart is not optional either.

**Revocation.** There is no CRL and no OCSP. Revocation is **reissuing the CA and every
certificate under it**, then restarting the mediator and redistributing the CA certificate to
`claude` and `agy`:

```bash
bash scripts/issue-identity.sh ca --force
bash scripts/issue-identity.sh claude
bash scripts/issue-identity.sh codex
bash scripts/issue-identity.sh agy
bash scripts/issue-identity.sh client claude --force
```

**Reissuing the CA does not touch the proxy credentials.** They are not CA-bound — they are random
secrets verified against an htpasswd, and the CA has no part in that path. The two lifecycles are
independent in both directions: a CA reissue leaves `codex` and `agy` authenticating exactly as
before, and rotating either credential leaves every certificate valid. Revoking a **credential** is
its own operation — delete the plaintext, rebuild the htpasswd, restart the mediator, which
`issue-identity.sh credential <agent> --force` does in one step. The rebuild is from scratch every
time and never appended to, so deleting a plaintext actually revokes rather than silently leaving
the old hash in place.

This is a recorded choice, not an oversight. The pod holds **four** certificates under this CA —
three listener certificates and one client certificate, `claude`'s. (The forecast this paragraph
carried before 01.6 said "at most six after 01.6 adds client certificates", on the assumption of one
per agent; only `claude` can present one, and the other two agents' identities are credentials,
which are not certificates and not under the CA at all.) Every consumer of this CA is inside one
Compose project on one host and is restarted by the same command that reissues. A CRL or an OCSP
responder would add a distribution channel and a second failure mode to protect a population that
can be replaced wholesale in a handful of commands. Revisit if the population ever outgrows one pod.

**Compromise of the CA private key** is the case revocation exists for: it is on the operator host
only, so its blast radius is that host. Reissue as above; the old CA is trusted by nothing once the
agents receive the new certificate.
