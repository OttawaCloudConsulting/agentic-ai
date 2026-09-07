# Credential Inventory — 01.4 SF-3

**Requirement.** R8.4: *every* credential the agent can obtain is enumerated with its blast-radius
contribution stated. R4.16: each persisted long-lived credential names its compensating controls
individually, its revocation path, and a review trigger. This is the **inventory half of T26**;
tested revocation with a measured detection-to-revocation time is Feature 02.5's, and the column
that would carry it is present and deliberately empty.

**Produced by** Feature 01.4 SF-3 (Interface Contract 7). **Consumed by** Feature 02.5.

**Scope is "can obtain", not "is configured".** A credential appears here if some supported cell of
the Interface Contract 1 matrix puts it inside a container, whether or not the default profile
selects that cell. `oauth-mount` is listed although SF-4 has not yet built it, because the inventory
is what SF-4 builds against.

## Delivery paths

| Path | Populated at this milestone |
|---|---|
| Environment-delivered | Yes — three API keys and one long-lived OAuth token |
| Volume-persisted | Yes — OAuth refresh tokens, per agent |
| Secret-mounted | **Not yet populated.** See the note below — this row is present so its emptiness is visible rather than an omission |

**The secret-mounted path is empty, and the CA certificate is not a counterexample.** `claude` and
`agy` mount `mediator-ca.crt` at `/run/secrets`. That is a **public** key, mounted so the agent can
validate the proxy hop; it authenticates the mediator to the agent and grants its holder nothing.
The per-agent mTLS client **key** — the first real credential on this path — arrives with Feature
01.6 (R8.8), which 01.3 deferred. Until then this path has no members.

## Row index

Eleven columns do not fit one readable table. Table A carries identity, lifetime and blast radius;
Table B carries controls, revocation, review trigger and the 02.5 column, keyed by the same row id.

### Table A — identity, lifetime, blast radius

| # | Agent | Delivery path | Producing `AUTH_MODE` | Credential type | Location | Stated lifetime | Blast-radius contribution (R8.4) |
|---|---|---|---|---|---|---|---|
| E1 | `claude` | Environment | `apikey` | Provider API key | `ANTHROPIC_API_KEY` in the container environment | **No expiry** — valid until revoked at the provider | Full API access to the Anthropic account at the key's scope, billable, indefinitely. Readable by the agent process from its own `/proc/self/environ` (edge case 12) — inherent to the mode, removed only by R8.3 brokering |
| E2 | `codex` | Environment | `apikey` | Provider API key | `OPENAI_API_KEY` in the container environment | **No expiry** | As E1, for the OpenAI account |
| E3 | `agy` | Environment | `apikey` (its only offered cell, D9) | Provider API key | `GEMINI_API_KEY` in the container environment | **No expiry** | As E1, for the Google account. `agy` has no OAuth cell, so this is the whole of its credential surface |
| E4 | `claude` | Environment | `oauth-token` | Long-lived OAuth token, minted by `claude setup-token` | `CLAUDE_CODE_OAUTH_TOKEN` in the container environment | **One year** | **The widest replay window in this inventory (R4.16).** Environment-delivered, so agent-readable like E1–E3, but unlike an API key it carries the operator's OAuth session rather than a separately scoped key, and a year is long enough that a leak is unlikely to be outlived |
| V1 | `claude` | Volume-persisted | `oauth-interactive` (default) | OAuth refresh token + 8 h access token | `.credentials.json` on `claude-state`, mode `0600` | Refresh token **~28 days from the original login and not extended by a refresh**; access token 8 h. Measured — see `agent-verification.md`, 01.4 SF-3 | Mints access tokens for the operator's Anthropic session until the family expires. Bounded at ~28 days from login, which is the outer limit on how long a stolen volume is useful unaided. Not in the environment, but readable from the volume by the agent that owns it |
| V2 | `codex` | Volume-persisted | `oauth-interactive` (default) | OAuth refresh token + 10-day access token + 1 h `id_token` | `.codex/auth.json` on `codex-state`, mode `0600` | Refresh token **not stated** by the provider — `auth.json` carries no expiry for it; access token 10 days. Measured — same record | As V1, for the ChatGPT session, and **worse in one respect: no stated refresh-token expiry**, so nothing bounds it the way V1's 28 days bounds claude. The 10-day access token is itself a long-lived bearer credential on the volume |
| V3 | `codex` | Volume-persisted | `oauth-mount` (**built, 01.4 SF-4**) | Same as V2 — the credential type is identical; only its provenance differs | Copied from the operator's host `~/.codex/auth.json` into `codex-state` during a one-shot bootstrap | Same as V2 | Same as V2 **plus two measured host-side consequences.** SF-3: codex rolls its refresh token, so the container's first refresh supersedes the host's copy. SF-5, measured by replay (`docs/records/agent-verification.md`, "Refresh-token replay"): **the superseded copy still redeems** — two runs refreshed successfully from the same parent token — so the host login is *not* lost, and, far more importantly, **rotation is not a revocation mechanism**: a refresh token captured from this volume stays valid after the legitimate client refreshes past it. Age is not mitigation; only explicit revocation at the provider ends it. Recorded in `profiles/oauth-mount.yaml`'s `accepted_risk.rotation`. The host file also carries `OPENAI_API_KEY` alongside the OAuth set; `scripts/stage-oauth-mount.sh` strips it and `bootstrap-auth.sh` refuses a source that still carries it, so E2's blast radius is not silently added to this row |
| S1 | all | Secret-mounted | — | **Not yet populated** | `/run/secrets` — per-agent mTLS client key | — | Arrives with Feature 01.6 (R8.8). Recorded as absent, not omitted |

### Table B — controls, revocation, review trigger

| # | Compensating controls (R4.16, named individually) | Documented revocation procedure | R4.16 review trigger | Measured detection-to-revocation time (02.5) |
|---|---|---|---|---|
| E1 | Not persisted to a volume, so R4.3/R4.7/R8.7 do not apply. **R8.5** — revocable at the provider without rebuilding the environment; the key is injected, never baked into a layer (R8.1). **R8.7** — `references/.env_keys` is git-ignored | Revoke the key in the Anthropic Console's API-keys view. **Unsetting the variable is not revocation** — it removes the container's copy, not the provider's | R8.3 brokering (gated on R8.8, Feature 01.6; scheduled Milestone 03) | *(empty by design — 02.5)* |
| E2 | As E1 | Revoke the key in the OpenAI platform's API-keys view. Same caveat | As E1 | *(empty by design — 02.5)* |
| E3 | As E1 | Delete the key in Google AI Studio. Same caveat | As E1 | *(empty by design — 02.5)* |
| E4 | As E1, plus: the mode is a **documented fallback, not the default** — R4.12 makes `oauth-interactive` claude's default precisely so a year-long token is not minted by default | Revoke the token at the Anthropic account that minted it; removing the variable does not. **SF-5 carries a standing obligation to revoke the token it mints at feature close** — a one-year credential minted to prove a test cell is not left outstanding | As E1 — and this is the row the trigger was written for | *(empty by design — 02.5)* |
| V1 | **R4.3** — `claude-state` is claude's alone; no volume is shared between agents. **R4.7** — the volume is handled as secret material. **R8.5** — revocable without an image rebuild. **R8.7** — the volume is excluded from backups leaving the trust boundary (`tmutil` procedure in `README.md`) and no credential path is committable (`.gitignore`). Bounded additionally by the measured ~28-day family expiry | Delete `.credentials.json` from the volume to remove the container's copy, **and** revoke the session at the Anthropic account to invalidate it provider-side. Local deletion alone leaves a valid refresh token in any copy of the volume | As E1 | *(empty by design — 02.5)* |
| V2 | As V1, on `codex-state`. **No lifetime bound applies** — unlike V1 there is no stated refresh-token expiry, so the compensating controls carry the whole weight | `codex logout` removes the stored credentials in-container (verified present in 0.152.1), **and** revoke the session at the OpenAI account. Same caveat as V1 | As E1 | *(empty by design — 02.5)* |
| V3 | As V2, plus the three structural controls SF-4 built and verified: the host source is mounted `:ro` (R4.13, asserted from `/proc/self/mountinfo` rather than trusted from the fragment) as a **dedicated directory** rather than the credential file (R4.14); **only during the one-shot bootstrap** — at steady state there is no host mount at all (R4.15), so an agent that deletes its own credential finds no source to re-copy from and **fails its next container start**; and the R4.17 record must be present in the staged directory or the copy is refused (exit 3) | As V2. The host side turned out **not** to need re-establishing: SF-5 measured that the superseded host copy still redeems (see V3's blast-radius column), so `codex login` on the host keeps working. The revocation path is therefore the only thing that retires a leaked copy — `codex logout` is local removal, not revocation | As E1 | *(empty by design — 02.5)* |
| S1 | — | — | — | *(not yet applicable — 01.6)* |

## Residuals recorded rather than solved

1. **Volumes are secret material that nothing encrypts (R4.7, R8.7, edge case 14).** Docker Desktop
   stores every named volume inside one VM disk image, so there is no per-volume backup exclusion to
   apply; the R8.7 exclusion is necessarily whole-path and host-side. The `tmutil` invocation is in
   `README.md`. The residual is that an operator who excludes nothing backs up every refresh token
   in this inventory.

2. **Environment-delivered credentials are readable by the agent that holds them (edge case 12).**
   E1–E4 are visible in the agent's own `/proc/self/environ`. This is inherent to the delivery path,
   not a defect of the implementation, and R8.3 brokering is what removes it — a mediator role gated
   on R8.8 and scheduled for Milestone 03. E4 is the widest instance.

3. **Per-session refresh-token revocation remains unverified (R4.17), though narrowed.** SF-3
   measured that both providers *roll* the refresh token on refresh. It did **not** measure whether
   a superseded token is actively rejected, because the only test is replaying a rotated token
   against the operator's live account — an operator decision at build, recorded in
   `agent-verification.md`. R4.17's register text stands, with its scope reduced to the rejection
   question alone.

4. **Revocation here is documented, not tested.** Every procedure in Table B is the vendor-published
   path, written down so an incident does not begin with a search. **T26's tested revocation with a
   stated maximum detection-to-revocation time is Feature 02.5's**, and its column above is empty on
   purpose.
