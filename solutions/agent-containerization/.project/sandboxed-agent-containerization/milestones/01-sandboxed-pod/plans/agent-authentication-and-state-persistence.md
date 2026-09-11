# Feature Plan: Agent authentication and state persistence

**Milestone:** 01 - Sandboxed Pod
**Feature:** 01.4: Agent authentication and state persistence
**Status:** Planned
**Date:** 2026-09-04
**Re-planned:** 2026-09-07 — against Feature 01.3 **as built**. Four things this plan consumed do
not exist in the form it assumed: 01.3 issues **no client certificates** (they left with R8.8 for
Feature 01.6 at the 2026-09-04 milestone revision, and this plan was written the same day against
the pre-revision shape); `CODEX_CA_CERTIFICATE` is not set on `codex`, which has no TLS hop to
anchor and receives no CA at all; `agy`'s CA mechanism is `SSL_CERT_FILE`; and the mediator's audit
sub-feature renumbered from SF-7a to SF-7. The revision is confined to Interface Contract 6,
criterion 7, Contract 7's inventory table, the Dependencies section and the repository-state note —
Approach, Sub-Features, Test Command and Test Strategy are unchanged, because none of them turned
on the identity material.

## Summary

Makes all three agents authenticate headlessly inside the pod and keep that authentication, plus
their session state, across a container restart and an image rebuild (R4.1, R4.2, SC-4 — **T9**).
It owns the authentication *semantics* that sit on the volume and environment wiring 01.2 already
produced: a per-agent `AUTH_MODE` dispatcher covering `apikey`, `oauth-interactive`, `oauth-token`
and `oauth-mount` with the safest supported mode as each agent's default (R4.12, D8 — **T24**), the
structurally-constrained `oauth-mount` bootstrap (R4.13–R4.15, R4.17 — **T25**), the host git
configuration scrub (R2.9 — **T22**), and the long-lived refresh-token inventory with per-provider
rotation semantics established rather than assumed (R4.16, R8.4, and the Gate 2 open item the
milestone README names as "the failure most likely to make a host-credential mount unworkable in
daily use").

This feature adds no new enforcement. Every control it relies on — network isolation, the single
egress path, the mediator's allowlist — is built by 01.2 and 01.3. It **extends three contracts
those features own**, each named explicitly in Interface Contracts below and each listed in Files to
Create/Modify: 01.2's Compose seam, 01.2's profile schema, and 01.2's mount-set equality assertion.
Its only widening of the boundary is a `:ro` credential-source directory that exists **for the
duration of a one-shot bootstrap invocation and is absent from steady state** — the accepted risk
R4.17 already records, constrained further in shape than R4.13–R4.15 require.

## Acceptance Criteria

Restated from the milestone README with implementation detail added. The README is authoritative
where the two differ.

1. **`AUTH_MODE` is selectable per agent, with the safest supported mode as the default (R4.12,
   D8) — T24.** The four modes are not uniformly available: the agents are asymmetric and the
   register says so. The authoritative per-agent support matrix is Interface Contract 1 below —
   **seven supported cells across three agents** — and it is what T24 iterates.
   `images/agent-base/bootstrap-auth.sh` implements exactly those cells and **fails closed with a
   named error** on any other — an unsupported cell must not degrade to a working-but-different
   mode, because that would silently defeat "the default is the safest mode that agent supports".
   Verified by running each supported cell and by asserting a non-zero exit with the expected
   message on a representative unsupported cell per agent.

2. **Per-agent state volumes carry the authentication surface (R4.3–R4.6, D7).** 01.2 already
   sets `HOME=/home/agent`, `CLAUDE_CONFIG_DIR=/home/agent/.claude`, `CODEX_HOME=/home/agent/.codex`
   and the `agy` home at `/home/agent/.gemini`, all on the per-agent named volume (01.2 Interface
   Contract 2). 01.4 asserts those values on the running containers rather than re-deciding them,
   and adds the one setting 01.2 did not: `cli_auth_credentials_store = "file"` in
   `$CODEX_HOME/config.toml`.

   **R4.5 requires that setting unconditionally, not only under `oauth-mount`.** The architecture's
   component table attaches it to `oauth-mount`; the register does not, and the reason is
   mechanical — the `keyring` store hard-fails with no D-Bus, and there is no D-Bus in any of these
   containers under any mode. The register wins. Verified by reading the effective value inside the
   container in every Codex mode, not by reading the Dockerfile.

   Also verified explicitly: Claude Code's `~/.claude.json`, which R4.4 singles out as living
   *outside* `CLAUDE_CONFIG_DIR` and holding the OAuth account, resolves to `/home/agent/.claude.json`
   and is therefore on the volume. Under 01.2's read-only root filesystem it would otherwise be
   unwritable, so this is a pass/fail property of the wiring rather than an incidental one.

3. **State volumes are treated as secret material (R4.7, R8.7).** No state volume is shared between
   two services (D7), no credential material is committable, and the backup exclusion is a **named,
   executable operator procedure** rather than an instruction to be careful. Verified by asserting
   each named volume appears in exactly one service, and by a `.gitignore` check.

   **What is and is not enforced, stated rather than implied.** The version-control half of R8.7 is
   enforced by this solution: `.gitignore` plus the absence of any export path it creates. The
   backup half is not enforceable from inside a container — Docker Desktop stores every named volume
   inside one VM disk image on the host, so no per-volume exclusion exists to make. `README.md`
   therefore carries the concrete host procedure (`tmutil addexclusion` against the Docker Desktop
   data path, named in full) and the **residual is recorded**: an operator who does not run it has
   refresh tokens inside a host backup, and nothing in this solution can detect that. R8.7 is met on
   the half this solution controls and carried by a documented host control on the other; the plan
   does not claim more.

4. **Every agent has a fully headless authentication path (R4.9).** R4.9 defines the headless path
   by enumeration — "paste-back code, device code, or a pre-minted token" — and requires only that
   no browser exist inside the container. All seven supported cells meet R4.9.

   **T24 as written cannot pass alongside R4.12, and the conflict is a register defect, not a plan
   choice.** T24's pass criterion is "each authenticates with **no interactive terminal**". Two of
   the three modes R4.9 names as headless — paste-back and device code — require an interactive
   terminal by construction, and `oauth-interactive` is the R4.12 default for both Claude Code and
   Codex per the PRD Configuration table. Read literally, T24 fails the two cells the register
   mandates as defaults.

   **Operator decision at this gate (2026-09-04): an interactive terminal is permitted.** T24 is
   amended in `REQUIREMENTS.md` to the property it protects — *each authenticates with **no browser
   inside the container**, and the default is the safest mode that agent supports* — which is R4.9's
   own definition of headless. R4.9 and R4.12 are unchanged, and no supported cell is removed. This
   follows the disposition Gate 4 already applied to T28 in Feature 01.3: the conflict is a register
   defect, the amendment is recorded with an owner and a landing point, and **this plan does not
   redefine the test on its own authority**.

   The amendment lands in **SF-2**. `REQUIREMENTS.md` and `docs/ARCHITECTURE_AND_DESIGN.md` are both
   listed in Files to Create/Modify, because an interpretation landing in one document and not the
   other is drift by construction. Verified at this gate as **decided and scheduled, not executed** —
   the edits are `/build`'s.

   The Codex callback forward is **documented, not enabled by default**: port 1455, fallback 1457,
   redirect `http://localhost:1455/auth/callback`, published as `127.0.0.1:1455:1455`. It ships as a
   layerable fragment, because the default path is paste-back and R2.8's default-off posture argues
   against publishing a host port the documented headless path does not need.

5. **`oauth-mount` is constrained in shape, and the host mount is absent from steady state
   (R4.13–R4.15, R4.17) — T25.** A dedicated **directory** is mounted, never the credential file
   (R4.14); `:ro` always (R4.13); copied into the state volume for bootstrap only (R4.15).

   **"Bootstrap only" is implemented as a separate invocation, not as a guard inside a
   permanently-mounted path.** The credential source is mounted by
   `compose/overrides/oauth-mount.bootstrap.yaml`, which is layered for a one-shot
   `docker compose ... run --rm codex` and for nothing else. Steady-state `up` never layers it, so
   the architecture's "steady state runs with no host mount" holds literally rather than by
   convention. At steady state with the volume already populated, `bootstrap-auth.sh` is a no-op; at
   steady state with the volume **empty or its credential deleted**, it exits `3` naming the
   bootstrap command. An agent that deletes its own credential therefore fails its next start rather
   than triggering a silent re-copy from a host source that is not there to copy from.

   Verified by inspecting the mount mode and kind during the bootstrap invocation; recording the
   host file's checksum; forcing a refresh; asserting the refreshed credential is on the state volume
   and the host file's checksum is unchanged; then asserting no host mount is present in the
   steady-state container at all.

   **File modes are not a control here** — Docker Desktop's VirtioFS fakes file ownership, so `0600`
   means nothing inside the container and `:ro` is the only real control (R4.13). The test asserts
   the mount mode, not the file mode.

6. **The host git configuration is scrubbed before it is mounted, not after (R2.9) — T22.** R2.9
   says the `credential.helper` entry "is removed **first**", and T22 inspects the mounted file
   itself. `scripts/scrub-gitconfig.sh` therefore runs **on the host, before `docker compose up`**,
   reading the operator's gitconfig and writing a filtered artifact into
   `compose/generated/gitconfig.d/`. That generated directory is what is mounted `:ro`. The
   operator's real gitconfig is never mounted into any container, so there is no unfiltered copy for
   a compromised agent to read.

   **The scrub removes `include.path` and `includeIf` as well as `credential.helper`**, because an
   include is a pointer that can re-introduce a helper from a file this solution never mounted —
   removing only the literal key would satisfy R2.9 in letter and defeat it in fact. Verified by
   asserting, inside the container, that `git config --global --get-all credential.helper` is empty,
   that no include directive survives in the mounted file, and that the mount is `:ro`.

7. **Every credential the agent can obtain is inventoried (R8.4), and every persisted long-lived
   one carries its compensating controls (R4.16)** — the inventory half of **T26**.
   `docs/records/credential-inventory.md` covers all three delivery paths, not only the persisted
   ones: environment-delivered (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`,
   `CLAUDE_CODE_OAUTH_TOKEN`), volume-persisted (OAuth refresh tokens under every OAuth mode), and
   and — **when 01.6 lands, not before** — the per-agent mTLS client key at `/run/secrets`. 01.3
   issues no client certificates; the inventory records that path as *not yet populated* rather than
   listing a file that does not exist. Each row states its blast-radius
   contribution (R8.4), and each persisted row additionally names its compensating controls
   individually (R4.3, R4.7, R8.5, R8.7), its documented revocation path, and R4.16's review trigger.

   **Tested revocation with a stated maximum detection-to-revocation time is 02.5's**, and the record
   says so in the column that would otherwise be read as missing.

8. **Refresh-token rotation semantics are verified per provider** (Gate 2 open item, carried into
   build). For each provider: does a refresh roll the refresh token, and does a refresh in one
   client invalidate the token held by another? Recorded in `docs/records/agent-verification.md`
   alongside 01.1 SF-2's findings. The acceptance criterion is that each result is **recorded**, not
   that each is favourable — a rolling token makes `oauth-mount` a one-shot bootstrap that costs the
   operator their host login, which is a consequence to record against R4.17, not a build failure.

9. **Restart persistence (R4.1, R4.2, SC-4) — T9.** Every agent is still authenticated with session
   state intact after a restart. R4.1 says "container restart **and image rebuild**"; T9 says
   restart. Both are exercised: `docker compose restart`, and `down` (without `-v`) → `build` → `up`.
   The second is the one that catches state written into an image layer rather than onto the volume,
   and it is the cheaper failure to find here than in 02.

## Approach

**The wiring already exists; this feature is the semantics on top of it.** 01.2 Interface Contract 2
fixes the mount set and the environment, and states in terms that "01.4 owns the authentication
semantics that sit on top of it. The contract is stated below so 01.4 does not re-decide it." 01.4
asserts that contract rather than restating it. Where it must go beyond consuming — the Compose
seam, the profile schema, the mount-set equality assertion — it says so as a named contract
extension, matching the discipline 01.3 used when it added `/run/secrets`.

**Ordering inside the feature is driven by one dependency that is easy to get backwards.**
The obvious order is mode-by-mode: `apikey`, `oauth-interactive`, `oauth-token`, `oauth-mount`. That
order discovers rotation semantics at T25, after `oauth-mount` is already built against an
assumption. The order taken instead is: wire the surface (SF-1), build the three modes that need no
host credential (SF-2), use those now-authenticated containers to **measure** rotation per provider
(SF-3), then build `oauth-mount` against a measured answer (SF-4). SF-3 is cheap precisely because
SF-2 produced a live credential to refresh.

**Two controls are moved from runtime guards to structural absence.** Both were guards in an earlier
draft of this plan and both were defeated by a compromised agent taking an action the guard did not
anticipate. The host git configuration is scrubbed **before** it is mounted, so there is no
unfiltered file inside the container to read (criterion 6). The `oauth-mount` credential source is
mounted **only during a one-shot bootstrap invocation**, so an agent that deletes its own credential
finds no host source to re-copy from (criterion 5). In both cases the control is that the material
is not there, not that a script declines to use it.

**Fail closed, and fail with the destination named.** An unsupported `(agent, mode)` cell exits `2`
naming the cell and that agent's supported set. A missing credential exits `3` naming what to supply
and, under `oauth-mount`, the bootstrap command to run. An OAuth flow whose provider endpoint is
absent from the resolved allowlist exits `4` naming the FQDN — mirroring R9.3 and R12.2's posture at
the mediator, where a legitimate policy gap must be distinguishable from an attack.

**01.4 owns the OAuth endpoint allowlist entries, and derives them the way R5.8 requires.** Neither
01.1's seed allowlist nor 01.3's resolved-policy example enumerates a provider authentication
endpoint — 01.3's example shows `api.anthropic.com:443` and no token or authorize endpoint — and
01.1's plan does not cover OAuth behaviour at all. Leaving the gap unowned would let SF-2 exit `4`
forever with nothing scheduled to close it. SF-2 therefore closes it, and the derivation satisfies
R5.8 and D17 rather than bypassing them: running the OAuth flow **is** an observation of the minimal
destination set, and the mediator's own audit log of the blocked attempt (01.3 SF-7) is the
independent second source D17 requires for cross-validation. The entries are added to
`policy/allowlist.base.yaml` marked provisional on the same terms as the rest of that file, with the
observed FQDNs recorded in `docs/records/agent-verification.md`.

**`agy` stays `apikey`-only by decision, not by omission.** D9 selects `apikey`; the architecture
records `oauth-token` as "explicitly unsupported" for `agy`; and an `agy` OAuth relationship reopens
the Antigravity ToS question the PRD carries as unresolved and R5.13 permanently bars interception
for. Building an OAuth fallback for `agy` here would be speculative scope walking into an open
governance question. The matrix records those cells as *not offered by decision* with the trigger
that would change it, and R4.12 is satisfied — it requires an API-key **or** an OAuth configuration
per agent, not both.

## Sub-Features

- [x] **SF-1: Authentication surface on the state volume, and the pre-mount git-config scrub** —
  asserts 01.2's environment contract on the running containers; seeds `$CODEX_HOME/config.toml`
  with `cli_auth_credentials_store = "file"` (R4.5, all modes) using merge-not-overwrite semantics;
  ships the host-side `scripts/scrub-gitconfig.sh` and the `compose/generated/gitconfig.d/` mount
  shape (R2.9, T22); adds the `.gitignore` entries, the `tmutil` exclusion procedure and the
  volume-exclusivity assertion (R4.7, R8.7, D7); and extends 01.2's mount-set equality assertion for
  the two optional mounts this feature introduces. Depends on 01.2 only.

- [x] **SF-2: `AUTH_MODE` dispatcher, the three host-credential-free modes, and the OAuth allowlist
  entries** — `images/agent-base/bootstrap-auth.sh` implementing the Interface Contract 1 matrix for
  `apikey`, `oauth-interactive` and `oauth-token`, with per-agent defaults, headless paste-back,
  fail-closed exits and the allowlist precondition check. Observes each provider's authentication
  endpoints during the flow, cross-validates against the mediator audit log, and adds them to
  `policy/allowlist.base.yaml`. Extends `profiles/default.yaml`'s `auth_mode` enum surface (01.2
  Interface Contract 3) and adds the documented callback-forward fragment. **Carries the T24
  register amendment** (criterion 4) into `REQUIREMENTS.md` and `docs/ARCHITECTURE_AND_DESIGN.md`,
  subject to the operator decision recorded at this gate. Depends on SF-1.

- [x] **SF-3: Refresh-token rotation semantics and the credential inventory** — using the live
  credentials SF-2 produces, establishes per provider whether a refresh rolls the refresh token and
  whether a refresh in one client invalidates another's; records the results in
  `docs/records/agent-verification.md`; and produces `docs/records/credential-inventory.md` covering
  every credential the agent can obtain (R8.4) with the compensating controls named for each
  persisted one (R4.16). **Gates SF-4** — its result decides whether `oauth-mount` is a durable mode
  or a one-shot bootstrap that costs the operator their host login. Depends on SF-2.

- [x] **SF-4: `oauth-mount` bootstrap invocation and its shape constraints** — the fourth dispatcher
  branch plus `compose/overrides/oauth-mount.bootstrap.yaml`: dedicated `:ro` directory (R4.14,
  R4.13), copy-to-volume during a one-shot invocation only, steady state with no host mount at all
  (R4.15), the exit-`3` behaviour on an emptied volume, and the R4.17 accepted-risk record carrying
  SF-3's measured rotation consequence. Codex only — the matrix has no other supported cell.
  Depends on SF-3.

  **Host precondition, verified 2026-09-07 (Gate 4).** `~/.codex/auth.json` exists on the operator's
  Mac, mode `0600`, and is **file-backed rather than Keychain-backed** — `cli_auth_credentials_store`
  is unset in `~/.codex/config.toml`, and this Codex install's default writes to file. So R4.5's
  setting is required inside the container but is already satisfied on the host side, and SF-4's
  precondition is met without an extra host login step.

  **The staged copy must strip `OPENAI_API_KEY`, and this is a test-validity control before it is a
  security one.** The host file's top-level keys are `OPENAI_API_KEY`, `auth_mode`, `last_refresh`
  and `tokens` — one file carrying *both* an OAuth token set and a raw API key. Mounted as-is, the
  `oauth-mount` cell could authenticate off the API key and pass green while the OAuth path is
  broken, which is precisely the cell this sub-feature exists to prove. R4.14 already requires a
  dedicated **directory** rather than the credential file itself; the staging step that builds that
  directory therefore copies `auth.json` with `OPENAI_API_KEY` removed, and SF-5 asserts the key is
  absent from the mounted source. It also narrows what the container holds: `~/.codex` itself is a
  54-entry directory of sessions, archived sessions and global state, none of which has any business
  crossing the boundary.

- [x] **SF-5: Acceptance harness** — `tests/acceptance/verify-auth-state.sh` implementing T24 across
  all seven supported cells, T22, T25 including the steady-state no-host-mount assertion, and T9 in
  both its restart and its rebuild form. **Runs against the operator's real provider accounts
  (decision, Gate 4, 2026-09-07)** -- superseding this line's original "throwaway credentials only".
  The three API keys already exist in `references/.env_keys`; the four OAuth cells use the
  operator's live Anthropic and ChatGPT accounts. Two obligations follow from that choice and are
  part of this sub-feature's close, not advice:

  - **Revoke the `claude setup-token` credential at feature close.** The `oauth-token` cell mints a
    **one-year** `CLAUDE_CODE_OAUTH_TOKEN` (the R4.16 risk this plan already records). A year-long
    token for a live account, minted to prove a test cell, is not something to leave outstanding
    once the cell has passed.
  - **The harness must not print credential material.** It iterates live credentials, so any
    diagnostic echoing an environment value or a credential file is a leak into CI logs and terminal
    scrollback. Assert on presence, shape and exit status, never on value.

  - **Owed by SF-1: the R4.5 check in EVERY Codex mode.** Criterion 2 requires the effective
    `cli_auth_credentials_store` value to be read inside the container "in every Codex mode, not by
    reading the Dockerfile". SF-1 added that read to `verify-pod-topology.sh` check 4d, but that
    harness only ever brings the pod up on the **default** profile, so it proves the property for
    one mode. SF-5 iterates the modes and must re-assert it per Codex cell — otherwise the
    criterion is met for `oauth-interactive` alone and the `apikey` and `oauth-mount` cells are
    unverified against the register's unconditional reading.

  Depends on SF-1 to SF-4.

Sizing note: five sub-features, each judged a single reviewable unit against DD-1's ~120k-token
session guideline. The git-config scrub (SF-1) is small enough on its own — one host-side script and
one assertion — that a separate sub-feature would be ceremony; it is folded into SF-1 because it
shares the volume-and-mount surface and the same mount-set-equality amendment. SF-2 is the largest
and is kept whole: the dispatcher branches share one argument parser, one precondition check and one
fail-closed path, and splitting by mode would duplicate all three. Its split condition, if `/build`
finds it runs long, is SF-2a (dispatcher skeleton, precondition check, `apikey`) and SF-2b (the two
OAuth branches plus the allowlist entries). None is flagged `[OVERSIZED]`.

## Interface Contracts

### 1. Agent × `AUTH_MODE` support matrix — produced by 01.4, iterated by T24

This is what "the safest mode that agent supports" (R4.12) resolves to, per cell. It is the
authoritative statement of the supported set; `bootstrap-auth.sh` implements exactly these cells and
`verify-auth-state.sh` iterates exactly these cells. **Seven cells are supported.**

| Agent | `apikey` | `oauth-interactive` | `oauth-token` | `oauth-mount` |
|---|---|---|---|---|
| **claude** | Supported — `ANTHROPIC_API_KEY` via env | **Default** (R4.12, PRD) — paste-back, no browser in container | Supported, documented fallback — `claude setup-token` mints a **one-year** `CLAUDE_CODE_OAUTH_TOKEN` (R4.16 risk) | **Unsupported.** The host credential is macOS-Keychain-resident and not portable to a Linux container regardless of policy (R4.8) |
| **codex** | Supported — `OPENAI_API_KEY` via env | **Default** (R4.12, PRD) — paste-back; callback forward documented (1455 / 1457) | **Unsupported.** No OAuth env-var equivalent exists (arch § Authentication bootstrap) | Supported — `auth.json` is plain JSON under `CODEX_HOME`; requires `cli_auth_credentials_store = "file"` (R4.5) |
| **agy** | **Default** (D9, R4.12) — `GEMINI_API_KEY` **and** `"modelProvider": "gemini"` in settings; the env var alone is a documented no-op. **Conditional on 01.1 SF-2** | **Not offered by decision** — see below | **Unsupported.** Explicitly unsupported (arch § Authentication bootstrap) | **Not offered by decision** — see below |

Supported cells: claude ×3, codex ×3, agy ×1 = **7**.

**"Not offered by decision" is distinct from "unsupported".** D9 selects `apikey` for `agy` and
states that no Antigravity OAuth credential enters any container; an `agy` OAuth relationship
reopens the ToS question the PRD records as unresolved, with R5.13 permanently barring interception
of that traffic. The technical feasibility of an `agy` OAuth flow is not established here and is not
needed: R4.12 requires an API-key **or** an OAuth configuration per agent. **Review trigger:** 01.1
SF-2 reporting the `GEMINI_API_KEY` route non-functional, or Google clarifying the ToS boundary
(R14.3). The first of those leaves `agy` with no supported cell at all, which is a `/milestone`
rescope under D1, not a failed sub-feature.

`bootstrap-auth.sh` exits non-zero on any cell not marked Supported or Default, naming the cell and
the supported set for that agent. It never substitutes a different mode.

### 2. `images/agent-base/bootstrap-auth.sh` — produced by 01.4

```
bash bootstrap-auth.sh <agent>          # agent ∈ claude | codex | agy
```

| Input | Source | Notes |
|---|---|---|
| `AUTH_MODE` | env, per-agent, set by Compose from the profile | No default in the image — an unset value is an error, not a fallback |
| `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` / `GEMINI_API_KEY` | env | `apikey` mode only |
| `CLAUDE_CODE_OAUTH_TOKEN` | env | `oauth-token` mode, Claude Code only |
| `OAUTH_MOUNT_SRC` | env, path to the `:ro` mounted **directory** | `oauth-mount` mode, **present only during the bootstrap invocation**. Default `/run/oauth-src` |
| `HOME`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME` | env, set by 01.2 | Asserted, not set |

| Exit | Meaning |
|---|---|
| `0` | The agent is authenticated, or already was (idempotent re-run) |
| `2` | Unsupported `(agent, AUTH_MODE)` cell, or `AUTH_MODE` unset |
| `3` | Required credential material absent. Under `oauth-mount` at steady state the message names the bootstrap command to run |
| `4` | Precondition failed — a required provider endpoint is absent from the resolved allowlist. The message names the FQDN |

**Idempotency and the bootstrap boundary.** Re-running with a populated state volume is a no-op that
exits `0`. Under `oauth-mount` the copy from `$OAUTH_MOUNT_SRC` happens only in the one-shot
bootstrap invocation, where that path is mounted; at steady state the path does not exist, so a
missing credential exits `3` rather than re-copying. This is what makes T9 pass across both restart
and rebuild, and what makes "bootstrap only" (R4.15) structural rather than conventional.

Invoked by `images/agent-base/entrypoint.sh` after 01.2's home-skeleton seed. The ordering is
load-bearing: the skeleton seed must not overwrite a credential.

**Departure from the architecture's file tree, recorded.** `docs/ARCHITECTURE_AND_DESIGN.md`
§ File Organization places `bootstrap-auth.sh` under `scripts/`. It ships at
`images/agent-base/bootstrap-auth.sh` instead, because 01.2's build context is `./images`, a file
under `scripts/` cannot be `COPY`'d into the image, and the copy-to-volume it performs must run
inside the container where both the `:ro` source and the state volume are mounted. 01.2 set the
precedent by placing `entrypoint.sh` at `images/agent-base/entrypoint.sh` for the same reason. The
file-tree correction lands in SF-2 and `docs/ARCHITECTURE_AND_DESIGN.md` is listed in Files to
Create/Modify. `scripts/scrub-gitconfig.sh` is **not** a departure — it runs on the host and belongs
in `scripts/` exactly as the tree states.

### 3. Profile schema extension — extends 01.2 Interface Contract 3, consumed by 01.5

01.2 declared the `auth_mode` block with the three defaults and no enum surface for the other two
values. 01.4 completes it. The `oauth_mount` block is **absent** from `profiles/default.yaml` and
appears only in a profile that enables the mode.

```yaml
auth_mode:                     # R4.12 defaults. Enum is per agent — see Interface Contract 1
  claude: oauth-interactive    # apikey | oauth-interactive | oauth-token
  codex: oauth-interactive     # apikey | oauth-interactive | oauth-mount
  agy: apikey                  # apikey
mounts:
  host_git_config: false       # R2.9 — mounts compose/generated/gitconfig.d/ :ro, produced by
                               # scripts/scrub-gitconfig.sh BEFORE up. Never the operator's own file
oauth_mount:                   # Required when any agent is oauth-mount. Absent otherwise
  codex:
    host_dir: <host path>      # A dedicated directory, never a credential file (R4.14).
                               # Mounted only by overrides/oauth-mount.bootstrap.yaml
    accepted_risk:             # R4.17. 01.5's compiler refuses the build if absent — T27
      file: <the credential this directory holds>
      mount_mode: ro           # The only permitted value (R4.13)
      revocation_path: <documented procedure>
      blast_radius: <stated consequence on container compromise>
      rotation: <SF-3's measured result for this provider>
```

**T27 — refusing to build when `accepted_risk` is absent — is 01.5's**, not 01.4's. 01.4 defines the
shape the compiler validates and enforces the same constraint at bootstrap time
(`bootstrap-auth.sh` exits `3` if the source is mounted without the record); 01.5 moves the refusal
to build time where T27 requires it.

### 4. Compose seam — extended a third time, by 01.4

01.2 Interface Contract 4 names 01.3 as the seam's extender and does not anticipate a third. This
contract states 01.4's extension explicitly so the seam has a complete ownership record.

01.4 adds to `compose/compose.yaml` exactly one thing: a per-agent `AUTH_MODE` environment entry
sourced from the profile. It adds **no** service, **no** network, **no** volume, **no** default
mount and **no** published port.

**`GIT_CONFIG_GLOBAL` is deliberately not set in `compose.yaml` or in any image.** The git-config
mount is optional, so an unconditional value would point at an absent path under
`profiles/default.yaml` — every `git config --global` the agent ran would fail, or land on `tmpfs`
and vanish at restart. It is set only by `compose/overrides/host-gitconfig.yaml`, the same fragment
that supplies the mount, so the variable and its target appear and disappear together.

Both optional mounts and the callback publish live in layerable override fragments that
`profiles/default.yaml` never selects.

### 5. Container filesystem and environment — consumed from 01.2 Interface Contract 2

01.4 asserts, and does not set: `HOME=/home/agent`; `CLAUDE_CONFIG_DIR=/home/agent/.claude`;
`CODEX_HOME=/home/agent/.codex`; the `agy` home at `/home/agent/.gemini`; `/home/agent` as the
per-agent named volume. It sets `GIT_CONFIG_GLOBAL` conditionally — see the note below the table.

01.4 introduces **two optional mounts** on top of 01.2's mount set, which 01.2's smoke check asserts
as exhaustive by equality. Both target paths sit under `/run`, following the precedent 01.3 set with
`/run/secrets` — 01.2 already declares `/run` as `tmpfs`, so a mount that vanishes with the
container is the correct shape for material that must not persist onto the state volume:

| Target in container | Source | Mode | Present when |
|---|---|---|---|
| `/run/oauth-src` | `oauth_mount.<agent>.host_dir` | `:ro` | The one-shot bootstrap invocation only, via `compose/overrides/oauth-mount.bootstrap.yaml`. **Never at steady state** |
| `/run/gitconfig` | `compose/generated/gitconfig.d/` — the scrubbed artifact, never the operator's file | `:ro` | `mounts.host_git_config: true`, via `compose/overrides/host-gitconfig.yaml` |

**`GIT_CONFIG_GLOBAL=/run/gitconfig/.gitconfig` is set by that same fragment and by nothing else.**
Under `profiles/default.yaml` the variable is unset and git behaves normally, reading
`~/.gitconfig` on the state volume as it would in any container. Where the mount is enabled, the
global config is `:ro` and a `git config --global` write fails — correct under R2.3 and R2.9, but
a behaviour change the operator sees, so `README.md` states it rather than leaving it to be
discovered.

Neither is present under `profiles/default.yaml`, so **T21** (optional mounts default-off; only the
project directory and the state volume present) is unaffected — it runs on the default profile,
where 01.4 adds nothing. Extending 01.2's allowed set for the two phases that do enable them is
explicit work in SF-1 and is listed in Files to Create/Modify, following the discipline 01.3
established when it added `/run/secrets`.

### 6. Agent-side proxy and identity — consumed from 01.3 Interface Contract 2 (as built)

01.4 consumes this contract unchanged. 01.3 states the direction explicitly: "01.4 consumes this
contract, not the reverse." What 01.3 **actually** delivers, verified on the running pod by its
acceptance harness, is not uniform across the three agents — and the asymmetry is a finding about
the agents' own HTTP clients (01.1 SF-2), not a preference:

| Agent | Proxy URL | CA trust | Client certificate |
|---|---|---|---|
| `claude` | `https://172.31.10.2:3128` — TLS proxy hop | `NODE_EXTRA_CA_CERTS=/run/secrets/mediator-ca.crt` | **None at 01.3** |
| `codex` | `http://172.31.20.2:3128` — **plain** HTTP CONNECT | **None.** No CA certificate is mounted and `CODEX_CA_CERTIFICATE` is **not set** | **None at 01.3** |
| `agy` | `https://172.31.30.2:3128` — TLS proxy hop | `SSL_CERT_FILE=/run/secrets/mediator-ca.crt` | **None at 01.3** |

Plus `NO_PROXY=localhost,127.0.0.1` and `dns:` pointing at the mediator's address on that agent's
network, on all three.

**Three corrections to this plan as first written, all in the same direction — there is less
identity material here than it assumed:**

- **No per-agent client certificate or key exists under `/run/secrets`.** Client certificates,
  client-certificate *verification* and R8.8 left 01.3 for **Feature 01.6** at the 2026-09-04
  milestone revision. 01.3 ships the CA and the three listener certificates only, and configures
  client-certificate verification explicitly **off** — a listener carrying `clientca=` would refuse
  `agy`, which has no certificate to present. Anything in 01.4 that reads as depending on a client
  key is depending on 01.6.
- **`codex` gets no CA certificate and no `CODEX_CA_CERTIFICATE`.** Its hop is plaintext because it
  rejects an `https://`-scheme proxy URL at URL-parse time, so there is nothing for it to anchor; a
  CA it cannot use is a mount it should not have. 01.2's mount-set equality assertion enforces the
  absence, and 01.3's harness asserts `codex` carries none of `NODE_EXTRA_CA_CERTS`,
  `SSL_CERT_FILE` or `CODEX_CA_CERTIFICATE`.
- **`agy`'s mechanism is `SSL_CERT_FILE`,** per 01.1 SF-2's finding, not an unnamed "`agy` CA
  mechanism".

**An allowlist edit is inert until the policy is recompiled AND the mediator image is rebuilt.**
Since 01.3 the mediator reads `policy/resolved/default.yaml` **from its own image layer**, never
from a bind mount, and startup stage 1 validates that file's *schema*, not its currency. So SF-2's
addition of the provider OAuth endpoints to `policy/allowlist.base.yaml` takes effect only after
`bash scripts/compile-policy.sh` regenerates `policy/resolved/default.yaml` **and**
`docker compose build egress-mediator` (or `up --build`) bakes it in. Editing the base file and
bringing the pod up produces `control=allowlist` / `reason=host_not_allowlisted` on the very
endpoint just added, with no warning that the policy is stale — SF-2's flow must run the compile
and the rebuild between observing the endpoints and re-testing them.

**What this changes for 01.4, concretely.** Any mount 01.4 adds must extend
`tests/acceptance/verify-pod-topology.sh`'s allowed mount set for that agent — the assertion is
equality, and 01.3 SF-4 already had to extend it once for the CA secret. Identity-derived
authorization (an `AUTH_MODE` that depends on the agent proving *which* agent it is) is not
available until 01.6 and must not be planned against here.

### 7. `docs/records/credential-inventory.md` — produced by 01.4, consumed by 02.5

Covers **every credential the agent can obtain** (R8.4), across all three delivery paths:

| Path | Members |
|---|---|
| Environment-delivered | `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN` |
| Volume-persisted | OAuth refresh tokens under `oauth-interactive` and `oauth-mount`, per agent |
| Secret-mounted | **Empty at this milestone.** The CA *certificate* mounted into `claude` and `agy` is a public key and not a credential. The per-agent mTLS client **key** arrives with Feature 01.6; the row exists so its absence is visible rather than an omission |

Columns: agent; delivery path; producing `AUTH_MODE`; credential type; location; stated lifetime;
**blast-radius contribution (R8.4)**; compensating controls named individually where persisted
(R4.3, R4.7, R8.5, R8.7); documented revocation procedure; R4.16 review trigger; and a column 02.5
fills — measured detection-to-revocation time (**empty at this gate, by design**).

## Edge Cases

1. **A re-copy on every start clobbers a refreshed token.** Under a permanently-mounted credential
   source, an entrypoint that copies on every start overwrites the token the container refreshed
   with the stale host copy — presenting as intermittent re-authentication, not as a crash.
   Structurally impossible here: the source is mounted only during the bootstrap invocation.

2. **An agent deletes its own credential to force a re-copy from the host.** With a permanently
   mounted source this defeats any guard, because the guard's condition is exactly what the agent
   controls. Structurally impossible here for the same reason: at steady state there is no source to
   copy from, and the start fails with exit `3`. Re-bootstrapping is a deliberate operator act.

3. **A rolling refresh token makes `oauth-mount` one-shot.** If a provider rolls the refresh token
   on use, the container's first refresh invalidates the host's copy and the operator's host CLI
   breaks. Measured in SF-3 before SF-4 builds; if it rolls, `oauth-mount` is documented as a
   bootstrap that costs the host login, recorded in the R4.17 `accepted_risk.rotation` field.

4. **`config.toml` is a file the agent also writes.** Overwriting it to set
   `cli_auth_credentials_store = "file"` destroys agent-written settings; leaving it to the home
   skeleton means 01.2's never-overwrite seed skips it once the agent has written the file. Handled
   by assert-and-merge on the single key at every start.

5. **A provider's OAuth endpoint is absent from the resolved allowlist.** 01.1's discovery run
   captured API traffic; nothing guarantees it captured an authentication flow, and neither 01.1's
   seed allowlist nor 01.3's resolved-policy example enumerates one. `oauth-interactive` then hangs
   or fails opaquely. Handled by the exit-`4` precondition check naming the FQDN, and closed by SF-2
   owning the addition under the R5.8/D17 derivation described in Approach.

6. **`include.path` / `includeIf` re-introduce a credential helper by reference.** Stripping only
   the literal `credential.helper` key satisfies R2.9 in letter while an include still points into
   host credential storage. Removed by the scrub, and asserted absent inside the container.

7. **The operator forgets to run the scrub before `up`.** `compose/generated/gitconfig.d/` does not
   exist, and the Compose mount of a missing source fails the bring-up. Fail-closed by construction;
   the alternative — Compose creating an empty directory — is why the mount source is a directory
   this solution generates rather than a path under the operator's home.

8. **The scrubbed artifact goes stale.** It is a point-in-time copy; a later host gitconfig change is
   not reflected until the scrub is re-run. Recorded rather than solved — a freshness check would be
   machinery for a file that changes rarely, and the failure mode is a missing git setting, not a
   credential leak.

9. **The callback forward is a host-side publish, not container egress.** `127.0.0.1:1455:1455`
   publishes a port on the host and does not give the container a route out; the browser runs on the
   host. Documenting it as "the browser-based option" without saying this invites the reading that
   `internal: true` has been relaxed. It has not.

10. **`~/.claude.json` outside `CLAUDE_CONFIG_DIR` on a read-only root filesystem.** R4.4 warns the
    OAuth account record lives outside the config directory. With `HOME=/home/agent` on the volume it
    lands on the volume — but if `HOME` were ever anywhere else the write would fail against 01.2's
    read-only rootfs and authentication would not survive a restart. Asserted as a property, per
    criterion 2.

11. **A partially populated state volume.** A bootstrap interrupted mid-copy, or a volume carrying a
    config directory but no credential, must not read as authenticated. The dispatcher's "already
    authenticated" test is the presence of a **valid** credential for that mode, not the presence of
    the directory; a partial state exits `3`.

12. **API keys and `oauth-token` are visible to the agent process.** Both modes deliver the
    credential through the environment, so the agent can read it from its own `/proc/self/environ`.
    Inherent to the mode, not a defect of the implementation: R8.3's brokering is what removes it,
    and brokering is a mediator role gated on R8.8 and scheduled for Milestone 03. Inventoried under
    R8.4 with the one-year `CLAUDE_CODE_OAUTH_TOKEN` replay window named as the widest instance
    (R4.16).

13. **Credentials pasted into an interactive login land in the session transcript.** R8.6 asks that
    transcripts be checked for captured credential values, and `oauth-interactive`'s paste-back is
    precisely a credential typed into the agent's terminal. Checked once per agent during SF-2 and
    recorded; a positive finding is recorded as a residual against R8.6 rather than fixed here,
    because the transcript format is the agent vendor's.

14. **Volumes are secret material that nothing encrypts, and no per-volume backup exclusion
    exists.** Docker Desktop stores all named volumes inside one VM disk image, so the R8.7 backup
    exclusion is necessarily whole-path and host-side. Stated in the inventory record and in
    `README.md` with the concrete `tmutil` invocation, and the residual recorded per criterion 3.

15. **`agy` has one supported cell, and it is conditional.** If 01.1 SF-2 reports the
    `GEMINI_API_KEY` route non-functional, `agy` has no supported mode. That is a `/milestone`
    rescope under D1, not a failed sub-feature — the same disposition the milestone README gives the
    `HTTPS_PROXY` result.

16. **T24 needs throwaway credentials for all seven supported cells.** Anthropic and OpenAI each
    need a throwaway account with both an API key and an OAuth login; Google needs an API key only,
    because D9 admits no Antigravity OAuth credential into any container. All are throwaway under
    R12.4 and R14.1 — this milestone's environment carries the not-for-real-work notice (R12.8), and
    running T24 against the operator's real provider accounts would contradict it.

## Test Command

```
bash tests/acceptance/verify-auth-state.sh \
  && bash tests/acceptance/verify-pod-topology.sh \
  && bash tests/acceptance/verify-egress-mediator.sh
```

**Composite, ratified at Gate 4 on 2026-09-07.** The two harnesses that already exist must still
pass at this feature's close, and the operator decision was that the obligation belongs in the test
command rather than in sub-feature prose: the test command is what actually runs at close, a prose
obligation is what gets skipped. A failure in any of the three fails the feature; attribute it
before fixing, since the later two are pre-existing and a break in them is a regression this
feature caused.

`verify-pod-topology.sh` matters here specifically because SF-1 and SF-4 amend its mount-set
equality assertion (`/run/oauth-src`, `/run/gitconfig`); `verify-egress-mediator.sh` matters because
SF-2 changes the compiled policy the mediator enforces.

## Test Strategy

`#!/usr/bin/env bash`, `set -euo pipefail`, mode 644, invoked as `bash` — the repository convention
01.1, 01.2 and 01.3 all state identically. A test-scoped Compose project name (`-p`) throughout, so
no phase touches the operator's real state volumes.

- **Phase A — surface assertions (criteria 2, 3).** Default profile. Asserts the 01.2 environment
  contract on each running container, `cli_auth_credentials_store = "file"` read from inside the
  container in every Codex mode, `/home/agent/.claude.json` resolving onto the volume, each named
  volume appearing in exactly one service, and the `.gitignore` entries.

- **Phase B — `AUTH_MODE` matrix, T24.** Iterates all seven Supported/Default cells of Interface
  Contract 1, asserting each authenticates with no browser spawned in the container. Then asserts
  the fail-closed path on one representative unsupported cell per agent — exit `2`, message naming
  the cell — because criterion 1 is as much about what does not happen as what does.

- **Phase C — git config scrub, T22.** Runs `scripts/scrub-gitconfig.sh` against a fixture gitconfig
  carrying a `credential.helper` and an `includeIf`, then layers
  `compose/overrides/host-gitconfig.yaml`. Asserts the mount is `:ro` at `/run/gitconfig`, that the
  **mounted file itself** contains no `credential.helper` and no include directive, that
  `GIT_CONFIG_GLOBAL` resolves to it, and that `git config --global --get-all credential.helper` is
  empty inside the container. Also asserts that **without** the fragment `GIT_CONFIG_GLOBAL` is
  unset, so the default profile does not carry a dangling pointer. Its own phase because it adds a
  mount, and criterion 4's mount-set equality check in phase A would fail with it layered.

- **Phase D — `oauth-mount` shape and bootstrap boundary, T25.** Two stages. **D1, bootstrap:** layer
  `compose/overrides/oauth-mount.bootstrap.yaml` for a one-shot `run --rm codex`; assert the source
  is a directory and `:ro`; record the host file's checksum; force an OAuth refresh; assert the
  refreshed credential is on the state volume and the host checksum is unchanged. **D2, steady
  state:** bring up without the fragment; assert **no host mount is present in the container at
  all**; delete the volume credential and assert the next start exits `3` naming the bootstrap
  command rather than re-copying. D2 is the edge-case-2 assertion and is the part T25 as written does
  not reach.

- **Phase E — persistence, T9.** Two forms. `docker compose restart`, then each agent runs and is
  still authenticated with session state intact. Then `down` (no `-v`) → `build` → `up`, and the same
  assertions. R4.1 requires survival across image rebuild and T9 states restart; the rebuild form is
  the one that catches state written into an image layer, and it is cheap here.

Throwaway provider accounts only, in every phase (R12.4, R14.1, R12.8).

**Not covered here, by design:** T27's build-time refusal (01.5), T26's measured revocation time
(02.5), T21's default-off enumeration (01.2, unaffected — 01.4 adds nothing to the default profile),
and adversarial acceptance of any of the above (02.2). Each is named in the script's header comment
so a reader does not mistake a scope boundary for a gap.

## Documentation

- **`README.md`** — first-run authentication per agent per supported mode; the paste-back headless
  path and what "headless" means; the `oauth-mount` **bootstrap invocation** as a distinct documented
  step from steady-state bring-up; the `scripts/scrub-gitconfig.sh` prerequisite when
  `host_git_config` is enabled, **and that the mounted global config is `:ro`, so a
  `git config --global` write fails while the mount is active**; the documented callback-forward
  option and its host-side nature; the
  concrete `tmutil addexclusion` backup-exclusion procedure and its residual (R8.7); and the
  revocation pointers (R12.6).
- **`docs/records/credential-inventory.md`** — new. The R8.4 / R4.16 inventory, per Interface
  Contract 7.
- **`docs/records/agent-verification.md`** — appended. Per-provider refresh-token rotation semantics,
  and the provider OAuth endpoint FQDNs observed during bootstrap with their cross-validation source.
- **`REQUIREMENTS.md` and `docs/ARCHITECTURE_AND_DESIGN.md`** — the T24 amendment (criterion 4) and
  the `bootstrap-auth.sh` file-tree correction. Both documents, because an interpretation landing in
  one and not the other is drift by construction — the reading 01.3's Gate 4 applied to T28.
- **`profiles/default.yaml`** — inline comments carrying the per-agent enum, since the enum is
  per-agent rather than global and a reader of the profile alone would otherwise assume all four
  values are available everywhere.

**Not documented here:** session-transcript retention (R4.10, SHOULD). Transcripts live on the state
volumes this feature makes durable, so the adjacency is real, but R4.10 is not in this feature's
acceptance criteria and a retention policy is a project-level artifact. Named as a pointer so the
adjacency is not mistaken for coverage.

## Files to Create/Modify

Paths are relative to `solutions/agent-containerization/`.

| File | Action | Changes |
|------|--------|---------|
| `images/agent-base/bootstrap-auth.sh` | Create | The `AUTH_MODE` dispatcher. Interface Contract 2 — four branches, per-agent matrix enforcement, fail-closed exits, allowlist precondition check, bootstrap boundary |
| `scripts/scrub-gitconfig.sh` | Create | **Host-side.** R2.9 — reads the operator's gitconfig, writes `compose/generated/gitconfig.d/.gitconfig` with `credential.helper`, `include.path` and `includeIf` removed. Run before `up`; the operator's own file is never mounted |
| `images/agent-base/entrypoint.sh` | Modify | Invoke `bootstrap-auth.sh` after 01.2's home-skeleton seed. Ordering is load-bearing |
| `images/agent-base/Dockerfile` | Modify | `COPY` the dispatcher. Declare `AUTH_MODE` with no default so an unset value fails rather than falls back. **Does not set `GIT_CONFIG_GLOBAL`** — see Interface Contract 4 |
| `images/codex/Dockerfile` | Modify | Seed the `$CODEX_HOME/config.toml` skeleton carrying `cli_auth_credentials_store = "file"` (R4.5, all modes) |
| `compose/compose.yaml` | Modify | Interface Contract 4 — per-agent `AUTH_MODE` from the profile, and nothing else. No service, network, volume, default mount, published port or `GIT_CONFIG_GLOBAL` |
| `compose/overrides/oauth-mount.bootstrap.yaml` | Create | Layered for the one-shot bootstrap `run --rm` only: the dedicated `:ro` credential-source directory, plus the optional `127.0.0.1:1455:1455` callback publish. Never layered at steady state |
| `compose/overrides/host-gitconfig.yaml` | Create | Layered when `mounts.host_git_config: true`: mounts `compose/generated/gitconfig.d/` at `/run/gitconfig` `:ro` and sets `GIT_CONFIG_GLOBAL`. The variable and its target appear together or not at all |
| `compose/generated/.gitignore` | Create | The scrub's output directory is generated, never committed (R8.7) |
| `profiles/default.yaml` | Modify | Per-agent `auth_mode` enum comments; the `oauth_mount` block shape documented as absent by default; `mounts.host_git_config` left `false` |
| `tests/acceptance/verify-auth-state.sh` | Create | The Test Command. Phases A–E covering T24, T22, T25 (both stages), T9 (both forms) |
| `tests/acceptance/verify-pod-topology.sh` | Modify | Extend 01.2's mount-set equality allowed set for the two optional mounts, in the phases that enable them only |
| `policy/allowlist.base.yaml` | Modify | Provider OAuth endpoint entries observed during SF-2's flow and cross-validated against the mediator audit log, marked provisional on the same terms as the rest of the file (R5.8, D17) |
| `docs/records/credential-inventory.md` | Create | R8.4 / R4.16 inventory, Interface Contract 7. The 02.5 revocation-time column is present and empty |
| `docs/records/agent-verification.md` | Modify | Append per-provider rotation semantics and the observed OAuth endpoint FQDNs with their cross-validation source |
| `REQUIREMENTS.md` | Modify | The T24 amendment (criterion 4), subject to the operator decision recorded at this gate. Lands in SF-2 |
| `docs/ARCHITECTURE_AND_DESIGN.md` | Modify | The same T24 reading, and the `bootstrap-auth.sh` file-tree correction. Lands in SF-2 |
| `README.md` | Modify | First-run auth per agent per mode, headless definition, bootstrap invocation, scrub prerequisite, `tmutil` exclusion and its residual, revocation pointers (R12.6) |
| `.gitignore` | Modify | Credential material and generated artifacts non-committable (R8.7). 01.3 creates the file |

## Dependencies

**On Feature 01.1 — records that gate this feature:**

- **`agy` `GEMINI_API_KEY` result** (`docs/records/agent-verification.md`): go/no-go for `agy`'s only
  supported cell. A negative leaves `agy` with no `AUTH_MODE` at all and is a `/milestone` rescope
  under D1, not a failed sub-feature.
- **Version pins**: T24 runs against the pinned versions, and authentication behaviour is
  version-specific.
- 01.1 does **not** cover refresh-token rotation, long-lived-token inventory, or any OAuth behaviour.
  Verified against its approved plan — SF-2 stops at mTLS client-certificate capability, the `agy`
  proxy/API-key/CA checks, and MCP transport. That scope is entirely 01.4's, with no prior claim.

**On Feature 01.2 — the surface this feature builds on and extends:**

- Interface Contract 2 (container filesystem layout and environment), consumed. 01.2 states the
  handoff explicitly: "01.4 owns the authentication semantics that sit on top of it."
- Interface Contract 3 (profile schema), **extended** — see Contract 3 above.
- Interface Contract 4 (Compose seam), **extended** — see Contract 4 above. 01.2 names only 01.3 as
  an extender; 01.4 is the third and says so rather than inheriting silently.
- `tests/acceptance/verify-pod-topology.sh`'s mount-set equality assertion, **amended** in SF-1.
- The home-skeleton seeding entrypoint and its never-overwrite semantics, which `bootstrap-auth.sh`
  runs after and inherits.

**On Feature 01.3 — the reason 01.3 precedes 01.4:**

- Interface Contract 2 (proxy environment, DNS, CA trust), consumed unchanged — **and it carries no
  per-agent client certificate**; see Contract 6 above.
- **The mediator's audit log** (01.3 SF-7) is the independent second source SF-2 cross-validates
  the observed OAuth endpoints against, per D17. Its shape is now fixed and can be matched on
  directly: one JSON object per line, and a refused authentication endpoint appears as
  `{"verdict":"deny","control":"allowlist","reason":"host_not_allowlisted","dest_host":"<fqdn>"}`
  with the agent named by `agent` and the attribution strength by `identity_source`. SF-2 should
  select on those fields rather than grepping text.
- An agent on an `internal: true` network cannot complete an OAuth flow until the mediator resolves
  and permits the provider's authentication endpoints. Those entries do not exist yet in any
  approved plan; **01.4 SF-2 owns adding them**, derived per R5.8 as described in Approach. This is
  a scope addition relative to the milestone README's wording for 01.4 and is called out here rather
  than absorbed silently.

**On later features — deliberately absent here:**

- **T27's build-time refusal** — 01.5's policy compiler. 01.4 defines the `accepted_risk` shape and
  enforces it at bootstrap time; the build-time gate T27 tests is 01.5's.
- **T26's measured revocation** — 02.5. 01.4 produces the inventory half only.
- **Credential brokering (R8.3)** — a mediator role, gated on R8.8 and scheduled for Milestone 03.
  01.4 does not touch secret-manager plumbing; API keys and pre-minted tokens arrive through the
  environment per the architecture's authentication-bootstrap table.
- **Adversarial acceptance** — 02.2 owns T9, T22, T24 and T25 as recorded adversarial acceptance.
  Here they are prerequisite checks.

**External:**

- Docker Desktop on macOS 26, Apple silicon (R11.1, A1).
- Provider authentication endpoints reachable through the mediator (A4).
- A host browser available to complete `oauth-interactive` paste-back. The container never has one
  (R4.9).
- **Throwaway provider accounts.** Anthropic and OpenAI each need one carrying both an API key and an
  OAuth login; Google needs an API key only, because D9 admits no Antigravity OAuth credential into
  any container. Required by R12.4, R14.1 and this milestone's not-for-real-work notice (R12.8).
  This is the external dependency most likely to be underestimated: T24 iterates seven cells.

**Repository state (re-checked 2026-09-07): no longer greenfield.** Features 01.1, 01.2 and 01.3
are **complete and on disk**: `compose/`, `images/`, `profiles/`, `scripts/`, `policy/`,
`mediator/`, `tests/acceptance/` and `tests/fixtures/` all exist, and the pod brings up and enforces.
Every file this plan lists as Modify now exists and must be **extended**, not created — in
particular `compose/compose.yaml` (seven secrets already declared), `profiles/default.yaml`,
`policy/allowlist.base.yaml`, `.gitignore` and `tests/acceptance/verify-pod-topology.sh`, whose
mount-set assertion is equality and breaks the moment a mount is added without extending it.
Two harnesses already exist and must both keep passing: `verify-pod-topology.sh` (01.2) and
`verify-egress-mediator.sh` (01.3, 77 assertions). Shell scripts follow `#!/usr/bin/env bash`, `set -euo pipefail`,
mode 644, invoked as `bash script.sh`.

## Architectural Deviations

### Deviation 1: image-tree paths corrected to 01.2's single multi-stage Dockerfile
- **What changed:** Every `images/agent-base/…` path in this plan resolves to `images/…` in the
  implementation, and `images/codex/Dockerfile` does not exist as a file. Concretely:
  `bootstrap-auth.sh` ships at `images/bootstrap-auth.sh`; the entrypoint modified in SF-1 is
  `images/entrypoint.sh`; the Dockerfile modified is `images/Dockerfile`; and the Codex
  `config.toml` skeleton carrying `cli_auth_credentials_store = "file"` (R4.5) is seeded in the
  **`codex` stage** of that same multi-stage `images/Dockerfile` rather than in a per-agent
  Dockerfile of its own.
- **Originally planned:** Interface Contract 2 titles the dispatcher
  `images/agent-base/bootstrap-auth.sh` and justifies the location with "01.2 set the precedent by
  placing `entrypoint.sh` at `images/agent-base/entrypoint.sh`". The Files to Create/Modify table
  lists `images/agent-base/bootstrap-auth.sh` (Create), `images/agent-base/entrypoint.sh` (Modify),
  `images/agent-base/Dockerfile` (Modify) and `images/codex/Dockerfile` (Modify).
- **Why necessary:** No `images/agent-base/` directory exists and none of those four paths is real.
  Feature 01.2 recorded its own Deviation 1 — "single multi-stage `images/Dockerfile` with `target:`
  selection" — because Compose does not resolve cross-service build order when one service's
  Dockerfile `FROM`s another service's image tag. 01.2 therefore shipped one shared `agent-base`
  stage plus one final stage per agent (`claude`, `codex`, `agy`) in `images/Dockerfile`, with the
  entrypoint at `images/entrypoint.sh`. The 2026-09-07 re-plan of 01.4 was made against 01.3 as
  built and did not propagate 01.2's deviation into these paths. The **reason** Interface Contract 2
  gives for the location is unaffected and still binding: the build context is `../images`, so a
  file under `scripts/` cannot be `COPY`'d into the image, and the copy-to-volume must run inside
  the container. `images/bootstrap-auth.sh` satisfies that reason exactly; only the directory
  segment was wrong.
- **Impact:** No contract, exit code, mount or behaviour changes — this is a path correction, not a
  design change. Two consequences for later work: (a) SF-2's file-tree correction to
  `docs/ARCHITECTURE_AND_DESIGN.md` must record the dispatcher at `images/bootstrap-auth.sh`, not at
  the plan's `images/agent-base/bootstrap-auth.sh`, or the doc acquires a second wrong path in place
  of the first; and (b) 01.5's build pipeline and `.dockerignore` allowlist extension must
  allowlist `images/bootstrap-auth.sh` under the `./images` context. `scripts/scrub-gitconfig.sh`
  is unaffected — it runs on the host and stays in `scripts/` exactly as the plan and the
  architecture file tree state.

### Deviation 2: an absent credential warns at container start, and is fatal only on explicit invocation
- **What changed:** `bootstrap-auth.sh` takes an `--at-start` flag, which `entrypoint.sh` passes on
  the every-start pass. In that pass an **absent credential warns on stderr and exits `0`**, so the
  container starts unauthenticated. Exit `3` is reserved for the operator's explicit invocation.
  Three properties do **not** relax: an unset or unsupported `AUTH_MODE` is exit `2` in both passes;
  `oauth-mount` on an emptied volume is exit `3` in both, so criterion 5's "an agent that deletes
  its own credential fails its next start" holds literally; and `oauth-interactive` never launches a
  login at start, where there is no TTY.
- **Originally planned:** Interface Contract 2 states exit `3` as "required credential material
  absent", unconditionally, with `bootstrap-auth.sh` "invoked by `entrypoint.sh` after 01.2's
  home-skeleton seed" — i.e. one behaviour on every start.
- **Why necessary:** The flat reading makes `docker compose up` fail on a fresh volume under **the
  default profile**, which is the profile every existing harness uses. `profiles/default.yaml` sets
  `claude` and `codex` to `oauth-interactive` — unauthenticated by definition before the first
  interactive login — and `agy` to `apikey`, while Interface Contract 4 restricts 01.4 to adding
  *only* `AUTH_MODE` to `compose.yaml`, so no API key is wired in by Compose at all. All three
  agent containers would therefore exit non-zero at start, and
  `tests/acceptance/verify-pod-topology.sh` — a **pre-existing 01.2 harness that this feature's own
  composite test command requires to still pass** — asserts against running containers. The
  alternative was editing that harness to supply credentials or override `AUTH_MODE`, which changes
  an 01.2 acceptance artifact to accommodate 01.4. Operator decision, 2026-09-07: warn, do not
  block. Verified after the change: `verify-pod-topology.sh` reports ALL CHECKS PASSED with the
  dispatcher wired into the entrypoint.
- **Impact:** A container can now run unauthenticated, and the agent inside it fails at first use
  rather than at start. That is the intended first-run shape for `oauth-interactive`, whose
  credential is obtained by a later `run --rm` invocation. Consequences for later work: SF-5's
  harness must assert the **explicit** invocation's exit codes, not the start-time pass's, or it
  will read every missing-credential case as a pass; and the `--at-start` contract is a second
  entry point that 01.5's compiler and any future caller must not confuse with the strict one.
  No exit code, mount, or matrix cell changed.

### Deviation 3: criterion 8's cross-client invalidation question is recorded as unmeasured, not answered

- **What changed:** SF-3 measured the first half of criterion 8 for both providers — a refresh
  **rolls** the refresh token, for Anthropic and for OpenAI alike, cross-validated against the
  mediator audit log. It did not measure the second half: whether a refresh in one client
  invalidates the token held by another. That result is recorded as *unmeasured, with its reason*
  in `docs/records/agent-verification.md` and as residual 3 in `docs/records/credential-inventory.md`.
- **Originally planned:** criterion 8 poses both questions per provider, and SF-3's sub-feature line
  makes both its scope: "establishes per provider whether a refresh rolls the refresh token **and
  whether a refresh in one client invalidates another's**".
- **Why necessary:** the only test that answers the second question is replaying a superseded
  refresh token against a live provider account. A provider that treats replay as evidence of
  compromise may revoke the whole session family, and Gate 4 put SF-5 on the operator's **real**
  Anthropic and ChatGPT accounts rather than on the throwaways edge case 16 assumed — so the cost of
  a revocation lands on the operator's own host CLI logins, not on a disposable account. The
  operator's decision at build (2026-09-07) was to stop at the rolling measurement.
- **Impact:** R4.17's register text — "per-session refresh-token revocation is unverified for all
  three providers" — is **narrowed but not closed**: the rolling behaviour is now measured, the
  rejection behaviour is not. SF-4 must therefore write `accepted_risk.rotation` against the
  conservative reading (treat `oauth-mount` as a one-shot bootstrap that costs the operator their
  host codex login) rather than against a measured one; being wrong in that direction costs a
  documented re-login, being wrong in the other breaks the host CLI without warning. Nothing else
  moves: no exit code, mount, matrix cell or allowlist entry changed, and both SF-3 deliverables
  ship complete. If the question is wanted later, the cheap way to buy it is a throwaway provider
  account, which is a `/milestone` scope item and not a re-plan of 01.4.

### Deviation 4: the callback publish ships as its own fragment, not inside the bootstrap fragment

- **What changed:** `compose/overrides/oauth-mount.bootstrap.yaml` carries the `:ro` credential
  mount and the `AUTH_MODE: oauth-mount` override, and **publishes no port**. The
  `127.0.0.1:1455:1455` callback forward ships as a separate layerable fragment,
  `compose/overrides/codex-callback.yaml`, invoked with `run --rm --service-ports codex codex login`
  — the CLI directly, because `bootstrap-auth` hard-codes `--device-auth`.
- **Originally planned:** Files to Create/Modify makes one file of both: "the dedicated `:ro`
  credential-source directory, **plus the optional `127.0.0.1:1455:1455` callback publish**."
- **Why necessary:** "optional" is not expressible inside a Compose fragment — a fragment is layered
  whole or not at all, so a publish carried there would open a host port on every bootstrap
  invocation, which is the one invocation that is *not* an interactive login. The two also belong to
  different modes: the callback is an `oauth-interactive` concern, and `oauth-mount` performs no
  login at all. Under R2.8's default-off posture, publishing a port the device-code path never uses
  is the wrong default. Operator decision at the SF-4 build (2026-09-07), choosing the separate
  fragment over both omitting it and folding it in.
- **Impact:** the callback forward is now reachable without editing a file, which the "documented
  only" reading of SF-2 did not give. It is honest but currently inert through `bootstrap-auth`:
  using it means invoking `codex login` directly, and the fragment says so. SF-5's T25 assertions
  read the bootstrap fragment's mount set, which is unchanged and now free of a published port that
  would have had to be asserted absent at steady state. If a future feature gives the dispatcher a
  callback branch, this fragment is where its port already lives.

### Deviation 5: the `accepted_risk` record reaches the container through a staged file, produced by two files the plan does not list

- **What changed:** two files not in Files to Create/Modify. `profiles/oauth-mount.yaml` — a
  complete profile (it compiles: `bash scripts/compile-policy.sh --profile oauth-mount`) carrying
  `auth_mode.codex: oauth-mount` and Interface Contract 3's `oauth_mount.codex.accepted_risk` block
  with the five fields populated, `rotation` quoting SF-3's conservative reading. And
  `scripts/stage-oauth-mount.sh` — host-side, the counterpart of `scrub-gitconfig.sh`: it validates
  those five fields, refuses a Keychain-backed host install, strips `OPENAI_API_KEY` from
  `~/.codex/auth.json`, and writes `auth.json` plus `accepted-risk.yaml` into
  `compose/generated/oauth-src/`. `bootstrap-auth.sh` then refuses to copy a credential from a
  source lacking that record or any of its five fields (exit 3).
- **Originally planned:** Interface Contract 3 assigns the bootstrap-time half of T27 to 01.4 —
  "`bootstrap-auth.sh` exits `3` if the source is mounted without the record" — and Files to
  Create/Modify lists neither a staging script nor a profile that enables the mode. The plan states
  the requirement and not the mechanism.
- **Why necessary:** the profile does not exist inside the container, so the record has to travel
  with the material to be checkable at bootstrap time at all. Staging it from the profile is what
  connects Contract 3's schema to the runtime check instead of leaving two disconnected shapes — and
  it is the same schema 01.5's compiler will validate for T27. The staging script was needed
  independently: the `OPENAI_API_KEY` strip that SF-4's own sub-feature text requires is a
  test-validity control, and leaving it a manual step would put the cell's validity in the
  operator's hands. `.gitignore` already reserved `compose/generated/oauth-src/` at SF-1, so the
  staged directory's location was anticipated even though its producer was not. Operator decision at
  the SF-4 build (2026-09-07).
- **Impact:** SF-5 gains a named profile to iterate the `oauth-mount` cell against and a scriptable
  staging step, rather than hand-built fixtures; it should also assert `OPENAI_API_KEY` absent from
  the mounted source, which the staging script's own self-check now makes a second line of defence
  rather than the only one. 01.5's T27 has a real profile to refuse the build against, and the
  `accepted_risk` shape is now exercised by a producer rather than only documented. Two new files
  join the repository's host-side script surface, and `README.md` documents the three-step sequence.

### Deviation 6: the harness seeds its state volumes from the operator's, and phase D therefore spends a real refresh

- **What was built:** `tests/acceptance/verify-auth-state.sh` creates its own project-scoped state
  volumes and then **copies** the operator's `sf3_claude-state` and `sf3_codex-state` into them
  (`SEED_CLAUDE_VOLUME` / `SEED_CODEX_VOLUME`), rather than obtaining credentials itself. Phase D
  stages a copy of the seeded codex credential through `scripts/stage-oauth-mount.sh` and forces a
  real refresh.
- **Originally planned:** the Test Strategy says only "a test-scoped Compose project name (`-p`)
  throughout, so no phase touches the operator's real state volumes", and Gate 4 replaced
  "throwaway credentials only" with the operator's real accounts without saying how the harness
  obtains them.
- **Why necessary:** four of the seven supported cells need a working OAuth credential, and no
  unattended test can mint one — `oauth-interactive` is a paste-back or device-code flow by
  construction. Seeding is the only mechanism that keeps the test-scoped-project rule intact while
  giving those cells something real to assert against. Operator decision at the SF-5 build
  (2026-09-07), taken against the two alternatives of running the cells directly against the
  operator's live volumes or asserting only the bootstrap path.
- **Impact:** the harness is **destructive to credential state by design**, and says so in its
  header and before phase D runs. Because codex rolls its refresh token, each run supersedes the
  seed volume's copy. The properties T25 asks for — the refreshed credential lands on the state
  volume, the `:ro` host source is unchanged — cannot be asserted without spending exactly that.
  Whoever runs this harness should expect the seed volume to be one refresh behind afterwards.

### Deviation 7: `set -uo pipefail`, and phase D runs last

- **What was built:** the harness uses `set -uo pipefail` and runs its phases in the order
  A, B, C, E, D.
- **Originally planned:** the Test Strategy specifies `set -euo pipefail` and lists the phases
  A through E in order.
- **Why necessary:** `-e` aborts at the first failing assertion, which for a five-phase harness
  means one failure hides every later one — 01.3's `verify-egress-mediator.sh` is the closer
  precedent and uses `-uo` for the same reason, while 01.2's single-pass harness can afford `-e`.
  The phase order is a consequence of Deviation 6: phase D forces a refresh and then **deletes the
  volume credential** to prove the steady-state exit `3`, so running it before E would leave E
  asserting the persistence of a credential D had just destroyed.
- **Impact:** none on coverage — every assertion the plan lists is made. The harness reports all
  failures in one run rather than the first.

### Deviation 8: `references/.env_keys` is parsed, not sourced — after sourcing it leaked a credential

- **What was built:** the harness reads the credential file with a `sed` matcher for `NAME=VALUE`
  lines. A line that is not one reads as an **absent variable**, and the diagnostic names the
  variable without ever holding its value.
- **Originally planned:** nothing — the plan does not say how the harness obtains the API keys.
  The first implementation did the obvious thing and sourced the file.
- **Why necessary:** **found by running.** The operator's pasted `CLAUDE_CODE_OAUTH_TOKEN` line was
  missing its `=`, so `set -a; . references/.env_keys` made bash treat the whole line as a command
  and **echo the token in cleartext** into the terminal and the run log. The failure mode is
  general: sourcing an operator-edited credential file executes it, and one malformed line prints
  whatever is on it. This is precisely the leak the sub-feature's own "must not print credential
  material" obligation exists to prevent, arriving through the one path that obligation did not
  cover — the harness's *input*, not its output. The affected token is scheduled for revocation at
  feature close, as this sub-feature already required.
- **Impact:** the harness never executes operator-supplied content. A malformed credential line now
  fails the precondition check by name. The same reasoning applies to any future script reading
  that file, and the comment in the harness says so.

### Deviation 9: criterion 6's third assertion could not be made as written — no agent image contains `git`

- **What was built:** the harness asserts `git config --global --get-all credential.helper` is empty
  inside the container **when `git` exists**, and otherwise asserts the absence of the binary and
  emits a named FINDING. It does not add `git` to any image.
- **Originally planned:** criterion 6 and the Test Strategy both state the assertion unconditionally
  — "asserting, inside the container, that `git config --global --get-all credential.helper` is
  empty".
- **Why necessary:** **found by running.** All three agent images are built from `node:22-slim`
  (01.2) and none installs `git`; the first pass failed with
  `exec: "git": executable file not found in $PATH`. The property R2.9 protects still holds, and
  holds *more* strongly than the original assertion would have shown — with no git binary, no
  credential helper is resolvable by anything — and the mounted-file assertion is what carries T22
  either way.
- **Impact:** a real gap is now named rather than hidden by a passing test. **`mounts.host_git_config`
  currently mounts a configuration nothing in the container can read**, and an agent asked to run
  git cannot. Whether `git` belongs in the images is a scope question for 01.5's pack composition
  (R7), not a change to make from inside an acceptance test. R2.9 and T22 are met; their *utility*
  is contingent on that later decision.
