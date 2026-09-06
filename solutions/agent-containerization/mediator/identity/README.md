# Proxy-hop trust anchors

The offline CA and the mediator's listener certificates. Produced by
`bash scripts/issue-identity.sh` on the **operator host** (01.3 SF-3).

Nothing in this directory except this file and `.gitignore` is committed.

## What exists, and where it lives

| Artifact | Path | Reaches the mediator? |
|---|---|---|
| CA private key | `ca/mediator-ca.key` | **Never.** Operator host only — not an image layer, not a volume, not a Compose secret |
| CA certificate | `ca/mediator-ca.crt` | Yes, as a Compose secret — mediator, `claude`, `agy`. **Not `codex`** |
| `claude` listener key pair | `listeners/claude-listener.{crt,key}` | Yes, as a Compose secret — mediator only |
| `agy` listener key pair | `listeners/agy-listener.{crt,key}` | Yes, as a Compose secret — mediator only |
| `codex` listener certificate | — | **None by design.** `codex`'s proxy hop is plain HTTP CONNECT |

Keeping the CA private key off the mediator is narrower than
`docs/ARCHITECTURE_AND_DESIGN.md`'s original "CA private key injected at runtime from a secret
manager", and it moves in the safer direction: a mediator compromise yields the certificates the
mediator presents, but not the ability to mint agent identities (criterion 9).

`codex` gets no CA and no certificate because it opens no TLS to the mediator — 01.1 SF-2 recorded
that it rejects an `https://`-scheme proxy URL at URL-parse time, before any handshake. Its
destination TLS is unaffected: the mediator splices and never terminates it (D4, R5.15).

## Subject naming

| Role | Subject | Issued by |
|---|---|---|
| CA | `CN=agent-pod mediator CA` | itself |
| Listener certificate | `CN=mediator-listener-<agent>` | 01.3 SF-3, this script |
| Client certificate | `CN=<agent>` | **01.6**, the same CA, an extended form of this script |

The two leaf forms are deliberately distinct. T34 (01.6) is a refusal to accept one agent's client
subject on another agent's listener; a shared subject form between server and client roles would
make that check ambiguous.

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

**Validity.** CA 730 days. Listener certificates 365 days. Bounded, and short enough that renewal
is a routine the operator has performed before it is needed.

**Issuance.**

```bash
bash scripts/issue-identity.sh ca
bash scripts/issue-identity.sh listener claude --ip <mediator addr on claude-net>
bash scripts/issue-identity.sh listener agy    --ip <mediator addr on agy-net>
bash scripts/issue-identity.sh status
```

**Renewal.** Re-issue against the recorded address, then restart the mediator:

```bash
bash scripts/issue-identity.sh claude
docker compose -f compose/compose.yaml restart egress-mediator
```

Renewal reuses the CA. The agents' trust anchor does not change, so no agent needs reconfiguring.

**Revocation.** There is no CRL and no OCSP. Revocation is **reissuing the CA and every
certificate under it**, then restarting the mediator and redistributing the CA certificate to
`claude` and `agy`:

```bash
bash scripts/issue-identity.sh ca --force
bash scripts/issue-identity.sh claude
bash scripts/issue-identity.sh agy
```

This is a recorded choice, not an oversight. The pod holds two listener certificates today and at
most five after 01.6 adds client certificates; every consumer of this CA is inside one Compose
project on one host and is restarted by the same command that reissues. A CRL or an OCSP responder
would add a distribution channel and a second failure mode to protect a population that can be
replaced wholesale in three commands. Revisit if the population ever outgrows one pod.

**Compromise of the CA private key** is the case revocation exists for: it is on the operator host
only, so its blast radius is that host. Reissue as above; the old CA is trusted by nothing once the
agents receive the new certificate.
