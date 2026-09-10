# Feature Plan: Containment, response and the authorization gate

**Milestone:** 02 - Proven and Composable
**Feature:** 02.5: Containment, response and the authorization gate
**Status:** Planned
**Date:** 2026-09-10

## Summary

Every feature before this one prevents or detects. This one covers what happens after a
detection. It is the response side of D1's accepted weakness: Option 2 has the worst
recovery-to-known-good of the three options, and D16 is the stated answer to that. The feature does
seven things:

- **T26.** Executes and times the revocation of every credential type the design persists, each
  against a stated maximum.
- **T40.** Proves single-agent isolation, and exercises the MCP-disable path far enough to write the
  R13.2/T40 amendment as tested text.
- **T41.** Drills return-to-known-good against a deliberately contaminated pod, with a stated
  disposition for every persistent volume.
- **R12.5.** Checks that teardown destroys ephemeral state and keeps the named volumes.
- **T37.** Turns the R12.7 profile field from shape-only into an enforced gate.
- **T44.** Runs a tabletop provider-terms-change exercise and inspects the mediator's extension
  points.
- **Runbook.** Ships the containment runbook, with event versus incident defined before go-live.

Most of the feature is drills and records. **T37 is the one piece of build work, and its form is
forced by the architecture.** No component sees an action: `git push` and `terraform apply` are
"unmediated everywhere" (Controls This Architecture Does Not Provide). Anything inside an agent
container is inside the blast radius (R1.2). The mediator sees only a spliced CONNECT (D4) and has no
live reload. So the one enforceable form is **capability absence**. A pack declares which classified
actions it enables. The compiler refuses a profile that classifies an action while loading a pack
that enables it, unless that action carries a recorded waiver.

## Acceptance Criteria

Refined from the milestone README with facts established by the codebase scan and during planning.

1. **T26 — tested revocation of every persisted credential type (R13.1, R8.5, R4.16).**
   - **The inventory is complete before anything is timed.** Every credential type the design
     persists has a row in `docs/records/credential-inventory.md`:
     - E1–E4: the three API keys and the one-year `CLAUDE_CODE_OAUTH_TOKEN`;
     - V1–V3: the OAuth refresh tokens on the state volumes;
     - S1–S3: the 01.6 identity material — `claude`'s client key and the `codex` and `agy` proxy
       credentials;
     - P1–P2: 02.3's GitHub token and `kubeconfig`.

     Today S1 still reads "arrives with 01.6", and no S2/S3 rows exist. 02.3 adds the P rows and
     corrects S1. 02.5 adds whatever is still missing.
   - **Every row carries a stated maximum detection-to-revocation time.** The operator confirms it
     before the drill (review assumption 1), and the drill must come in under it. The maximum is a
     commitment, not a number derived from the drill.
   - **Clock definitions.**
     - `t0` is the moment an incident is declared under the runbook.
     - `t1` is the moment the revoked credential verifiably fails on replay.
     - For an OAuth row, the refresh token **and** the access token are both replayed after
       revocation, and the row's effective time is the later of the two. If the access token
       survives revocation until its own expiry (V1: 8 h; V2: a 10-day JWT that `codex` does not
       verify locally), that survival *is* the measured time. The runbook then names the
       compensating action: isolate the agent and discard its volume.
   - **R8.5 (MUST): no rebuild.** Every revocation, and the re-issue that follows it, completes
     without an image rebuild. The evidence is that every service's image ID is equal before and
     after. Recreating a container is permitted and is not a rebuild. A row that cannot meet this is
     recorded as a **named gap against R8.5**, not folded into the timing.
   - **Drills use dedicated drill credentials, never the operator's working credentials** (see
     Dependencies). A drill that cannot run records its documented procedure and a named gap — for
     example P2 when no disposable cluster is available.
   - **What R13.1 bounds.** It bounds detection to revocation. It does not bound compromise to
     detection, which is unbounded while detection is pull-based (R9.6 stays MAY). This is recorded.
2. **T40 — single-agent isolation (R13.2).**
   - **Stop form.** For each agent X, stop X, then its 02.1 recorder once that recorder has drained.
     The other two agents keep running, their fixture requests through the mediator are still
     allowed, and their egress lines still reach the audit sink. X restarts cleanly.
   - **Disconnect form.** For each agent X, `docker network disconnect` X from its only network.
     X then has no route to anything, and the container is kept for forensics. The other two agents
     are unaffected. The mediator keeps serving: it reads `MEDIATOR_AGENT_NETWORKS` only at start,
     and this is measured, not assumed. Reconnecting restores X.
   - **MCP-disable half.** This is exercised against 02.3's test inventory, because no shipped
     profile carries a server (`servers: []`). The record states:
     - every step;
     - which agents are stopped or recreated;
     - that the shipped path requires a rebuild, because the inventory is baked into the image
       (02.3 Decision 8).

     The proposed amendment text for **R13.2 and T40** is recorded against `REQUIREMENTS.md`.
     **R13.2 stays formally unmet until the amendment is accepted.** Accepting it is the operator's
     decision, and the milestone Definition of Done gates on it.
3. **T41 — return to known-good (R13.3, D16).**
   - **Contamination.** Planted markers go into:
     - `claude-state`: a hook entry in `claude`'s settings;
     - `codex-state`: an `[mcp_servers.*]` entry in `config.toml`;
     - `agy-state`: a settings change;
     - each opt-in build-cache volume, when enabled;
     - the workspace: a marker file.
   - **Recovery.** The runbook's path is executed, and **every persistent volume and host-side
     store gets a stated disposition**, asserted after recovery (Interface Contract 5). At minimum:
     - state volumes are discarded;
     - `audit` and the three 02.1 action-audit volumes are preserved;
     - build caches are discarded;
     - the project mount is reviewed by the operator, not discarded;
     - `compose/generated/` is kept, but its pack credentials are rotated;
     - the contaminated agent's own identity material is rotated and the CA is not touched.
   - **Discarding is not revoking.** A copy of the volume may already have left. T41 therefore
     chains T26's procedures for every credential the contaminated agent held.
   - **After recovery:**
     - no marker remains in any discarded volume;
     - the audit and action-audit volumes still hold their pre-recovery lines, unchanged;
     - the recorder resumes on the fresh volume without duplicating lines;
     - each agent re-bootstraps authentication;
     - the Test Command is green.
   - **The markers are test instrumentation, not detection.** A contaminated volume is still
     indistinguishable from a clean one (D16), and the path discards without trying to tell.
   - The drill runs against the `main`-pinned digest from 02.4.
4. **R12.5 — teardown.**
   - `docker compose down`, without `-v`, removes containers, `tmpfs` (`/tmp`, `/run`) and
     networks, and preserves every named volume, including `audit`. This is asserted with markers.
   - The runbook states that `down -v` destroys the audit volume, so it is never used during an
     incident. T41's discard is selective, `docker volume rm` of the named state volumes only.
5. **T37 — the human authorization gate (R12.7).**
   - **Enforcement is by capability absence** (Decision 1):
     - pack manifests declare `enables_actions`;
     - a profile accounts for every known action as either classified or waived with a reason;
     - the compiler refuses, at exit 3, a classified action that any loaded pack or inventoried MCP
       server enables.
   - **The vocabulary is closed.** Known actions are the union of `enables_actions` across every
     committed pack manifest. An unknown action name exits 2, because a misspelled classification
     enforces nothing.
   - **Per-action waivers.** `authorization.waive: {<action>: <reason>}` sits alongside `classify`.
     The whole-profile `waiver:` form stays for the test profiles.
     - `github` waives `git-push` and still classifies `infrastructure-apply`.
     - `kubernetes` waives `infrastructure-apply` and still classifies `git-push`.
     - Both waiver texts are supplied by the operator (review assumption 3).
     - `default`, `oauth-mount` and `terraform` classify both actions.
   - **MCP.** An inventoried server with `risk_tier: irreversible` must declare a non-empty
     `enables_actions` (exit 2), and the same refusal rule applies to it.
   - **Runtime check under `default`,** from inside each agent, no credential for either classified
     action is reachable:
     - no `GH_TOKEN`, `GITHUB_TOKEN` or `KUBECONFIG`;
     - no `/run/secrets/pack-*`;
     - no `credential.helper`;
     - no `~/.git-credentials`.
   - **Refusal check.** `claude` and `agy` attempt `CONNECT github.com`. It is refused at the
     mediator with a deny line that carries the agent's `identity_source`.
   - **`codex` is the exception.** Its base allowlist already carries `github.com` and
     `api.github.com`, so for `codex` the halt rests on credential absence alone. That is recorded,
     and no live push is attempted, because the harness contacts no third-party host.
   - **"Halts for authorization" is given its operational meaning.** The attempt is refused and
     recorded. Authorization then means the operator performs the action outside the pod, or
     deliberately switches to a waiving profile, which is a committed change. The tension with A2 is
     recorded rather than resolved, as R12.7 itself asks.
   - Every resolved artifact is recompiled and passes `--check` in the same commit as the compiler
     change (01.6 Deviation 3).
6. **T44 — ToS monitoring and the mediation seam (R14.3, R15.2).**
   - **The R14.3 record covers all three provider routes, not just Antigravity.** It names the owner
     and the review triggers for the `claude`, `codex` and `agy` routes. The monitoring mechanism is
     stated as a review cadence plus provider-announcement subscriptions, and the operator confirms
     the cadence (review assumption 5).
   - **Tabletop.** The owner receives a simulated terms change on the Antigravity route and runs the
     re-review checklist. The outcome is recorded, labelled **SIMULATION**: the decision, and the
     containment action it would have triggered.
   - **Mediator seam inspection.** Three things are inspected: `squid -v` on the built image for the
     ICAP and eCAP build flags; the front/inner `cache_peer` cascade; and the template's
     `@GATE_RULES@` and `@PROXY_LISTENERS@` seams. The recorded conclusion names its limits. A
     tool-call layer needs TLS termination, which is a D4 decision and is never available for
     `agy` (R5.13). It never sees stdio (D18). "Without redesign" does not mean "without a
     decision".
7. **The runbook.** `docs/containment-runbook.md` ships with:
   - event and incident defined (review assumption 2);
   - the five containment actions, each with live and durable forms where both exist;
   - evidence preservation;
   - the per-credential revocation index with stated maxima;
   - the R9.6 review trigger handed over by 02.1.

   `README.md` links to it.
8. **Records and proposed edits.**
   - Drill results go in `docs/records/containment-drills.md`.
   - Two edits are recorded for an authority that may apply them, and not applied here:
     - the architecture document's runbook table. "Denylist entry at the mediator" is a rebuild,
       not a live action. The live forms are the network disconnects. The recorder is stopped
       alongside its agent.
     - the R13.2/T40 amendment against `REQUIREMENTS.md`.
9. **The R12.8 notice is not lifted here.** The milestone Definition of Done lifts it, once the
   R13.2/T40 amendment is accepted and the D21 amendment is applied.

## Approach

### The starting position

Read or measured during planning, not assumed:

- **R12.7 is shape-only.**
  - `profiles/default.yaml:50-54` and `oauth-mount.yaml:46-49` classify `git-push` and
    `infrastructure-apply`. The two test profiles carry a whole-profile `waiver`.
  - `scripts/compile-policy.sh:385-412` validates exactly-one-of `classify`/`waiver` (exit 2).
  - Nothing reads the field after that. It is not emitted into any resolved artifact and no harness
    tests it. Both the profile and the compiler say "T37 is 02.5's".
- **The credential inventory predates 01.6.**
  - `credential-inventory.md` Table B has a "Measured detection-to-revocation time (02.5)" column
    that is empty by design. No row states a maximum.
  - Residual 4 says the procedures are "documented, not tested".
  - S1 still says "arrives with 01.6". No rows exist for the `codex` and `agy` proxy credentials.
- **The one-year token is outstanding.** `prd-refresh-drift-2026-09-09.md:106-110` records that the
  `CLAUDE_CODE_OAUTH_TOKEN` minted for the R4.16 cell "additionally leaked in cleartext during the
  first run" and should be revoked. Nothing records that it has been.
- **Identity rotation is restart, not rebuild.**
  - `mediator/identity/README.md:98-186` covers `credential <agent> --force`, `client claude
    --force` and `ca --force`, then restarting the mediator **and** the agent.
  - `rebuild_htpasswd` writes with `cp` (`scripts/issue-identity.sh:420-441`), so the file is
    overwritten in place.
  - The identity README says `restart`, while 02.3's plan says a pack credential swap is "file swap
    plus `--force-recreate`". Which one picks up a replaced Compose `file:` secret is unsettled. It
    depends on whether the inode survives, and it is a timing input.
- **The mediator's policy is baked at build.**
  - The Dockerfile compiles, drift-checks and copies `policy/resolved/` into the image. The
    entrypoint renders `squid.conf` once and traps only TERM and INT.
  - So the architecture runbook's "denylist entry at the mediator" is a recompile plus a rebuild.
    The live cut-egress forms are Docker network operations, and none of them is documented today.
- **The fixtures sit on `egress-net`** (`compose/overrides/test-egress.yaml:46-80`). Detaching the
  mediator from `egress-net` therefore severs exactly the path the probes use.
- **Every harness cleans up with `down -v --remove-orphans`.** That destroys the `audit` volume,
  which is the opposite of what the runbook must do during an incident.
- **The R14.3 owner is Antigravity-only** (`third-party-assessments.md:107-117`): Ottawa Cloud
  Consulting, organisational, three triggers. No owner or trigger is named for the Anthropic or
  OpenAI routes.
- **Nothing 02.5 consumes from 02.1–02.4 exists yet.** Those features are `[~]` planned: no
  recorders, no action-audit volumes, no pack credentials, no `mcp-gate.js`, no `main` digest.

### Decision 1 — T37 is enforced by capability absence *(tradeoff callout 1)*

| Option | What it proves | Cost |
|---|---|---|
| **A. Capability absence, enforced at compile (recommended)** | A profile that classifies an action cannot load anything that enables it unless that action carries a recorded waiver. The classified action is structurally unavailable to an unattended agent, and an attempt is refused where the pod can refuse it | It is not a live approval. "Authorization" means the operator acts outside the pod or deliberately switches to a waiving profile. It also rests on the pack author's `enables_actions` being right, so it is a review-time control on manifests |
| B. Operator hold at the mediator | A classified destination is held until an operator grant arrives | The mediator cannot tell a push from a fetch on a spliced CONNECT (D4), so a hold on `github.com` also blocks `git fetch`. The policy is baked with no reload path. A grant channel would be a new `external_acl_type` helper and an operator-writable file inside the enforcement point: new mechanism on a SHOULD |
| C. In-container hook (`pre-push`, a wrapper `git`) | Nothing. It lives inside the blast radius (R1.2) and `--no-verify` or `-c core.hooksPath=` bypasses it | Cheap, and it would look like a control while not being one |

**Where "enables" lives.** It lives on the pack manifest as `enables_actions`, because the pack
author knows what the pack's credential and egress make possible. The known vocabulary is the union
over **every committed pack**, not only the loaded ones, so a profile can classify an action no pack
it loads enables. A central action registry was considered and rejected: it would be a second place
that has to be kept in step with the manifests. The same field goes on MCP inventory entries,
because R7.14's `irreversible` tier is literally what R12.7 names.

**The schema grows, and it has to.** Today the field is one-of `classify` or `waiver`. `github`
needs `git-push` waived but `infrastructure-apply` still classified. Under one-of it can only waive
everything, or silently drop `git-push` from `classify`. Silent dropping is the quiet omission the
field's own comment says it exists to prevent. So `waive` per action is added, and every known
action must be accounted for. This edits 01.5's field and 02.3's profiles, both named in Files to
Create/Modify.

### Decision 2 — T26 measures effective revocation, not the console click

- **Clock.** `t0` is the incident declaration. `t1` is a replay that fails.
  - An operator console action with no replay proves nothing.
  - For OAuth rows the access token is replayed as well as the refresh token. This is the
    measurement most likely to produce a real finding: a provider may end the session and leave the
    access token valid until it expires.
  - Replays run from the host, against the provider's own endpoint, with the drill credential. The
    E4 replay costs about one minimal `claude -p` call.
- **Rebuild.** The image ID of every service is recorded before `t0` and after the re-issue. Equal
  IDs mean no rebuild.
- **The stated maximum is set before the drill.** A maximum derived from the drill would be a
  tautology.
- **Drill credentials only.** Throwaway API keys, a fresh `claude setup-token`, fresh OAuth logins
  for `claude` and `codex`, a drill PAT on a throwaway repository, and a disposable cluster's
  `kubeconfig`. The operator's working credentials are never revoked to prove a point.
- **The outstanding leaked one-year token is not the drill token.** It should be revoked **now**,
  independently of this feature's build order (Edge Case 1). E4's drill mints and revokes a fresh
  token.
- **Pod-local material (S1–S3) and the pack credentials (P1–P2) are drilled with the documented
  commands.** The drill settles the `restart` versus `--force-recreate` question by measuring. The
  old secret's inode is compared before and after, and the old credential is replayed: `407` for a
  proxy credential, and for the client key a handshake refusal once the CA-level path is used. The
  identity README is corrected to whichever form works.

### Decision 3 — containment keeps the detection signal alive

The blocked attempt is the detection signal (R9.1), so the runbook's live actions are chosen not to
kill it:

| Need | Live form (measured in SF-3) | Durable form |
|---|---|---|
| Cut egress, whole pod | `docker network disconnect <proj>_egress-net <mediator>`. DNS, policy and the audit writer stay up, so attempts are still recorded, and they fail upstream | Denylist or allowlist edit → `compile-policy-build.sh` → `up --build --force-recreate` |
| Cut egress, one agent / isolate one agent | `docker network disconnect <proj>_<agent>-net <agent container>`. The container is kept for forensics | `docker compose stop <agent>`, then its recorder after it drains |
| Disable one MCP server | None exists. This is recorded, and it is the R13.2 amendment | Profile `mcp:` edit → rebuild → recreate every agent that loads it |
| Rotate credentials | Per inventory row, with its stated maximum | — |
| Return to known-good | — | Interface Contract 5 |

`docker compose stop egress-mediator` is recorded as the last resort. It cuts everything, and it
also stops the recording.

### Decision 4 — the T40 MCP half is exercised and proposed, not built *(tradeoff callout 2)*

| Option | Outcome | Cost |
|---|---|---|
| **A. Exercise the current path and propose the amendment (recommended, and what the milestone README states)** | T40's register text is met as written: "the MCP disable path is exercised and its current rebuild requirement recorded". R13.2 gets tested amendment text instead of speculative text | **R13.2 stays formally unmet until the operator accepts the amendment.** The milestone DoD will not lift the R12.8 notice until then. The plan cannot resolve that gate |
| B. Build a live targeted disable | R13.2 met without an amendment | A stdio server has no enforcement point at all (D18). Its only disable is config plus inventory at the next start, which restarts that agent. An HTTP server's egress could be cut live only with a mediator reload path that does not exist. It is new mechanism in the enforcement point, sized as a feature in its own right |

**What the exercise will show,** predicted here and measured in SF-4:

- On the shipped path the inventory is image content. Disabling a server is a profile edit plus a
  rebuild, and the canonical `up --build --force-recreate` recreates **every** service, the mediator
  included.
- Recreating only the affected agents (`up --build --force-recreate <agent>…`) narrows that. It is
  still a restart of each agent that loads the server.
- Removing the server from the inventory alone makes `mcp-gate` refuse that agent at its next start
  (exit 3), because the agent's own config entry is still there. The config entry must be removed as
  well. That entry lives on the agent's state volume, inside the blast radius.
- A compromised agent that re-adds the entry meets the gate at its next start and does not start.
  That is containment-safe, and it is recorded.

### Decision 5 — T41 disposition is per store, and discarding is not revoking

The recovery path covers every persistent store the rendered Compose configuration declares, and
every host-side store an agent can read. Each gets exactly one disposition: `discard`, `preserve`,
`rotate` or `review` (Interface Contract 5). A static check in the harness fails if a volume in any
shipped profile's `docker compose config` has no row. A future volume cannot arrive without a stated
recovery disposition.

"Rebuild containers from the pinned digest" is safe against workspace contamination only if
`workspace/` stays outside the build context. The deny-all `.dockerignore` never admits it today, and
the harness asserts that it still does not.

### Decision 6 — T44's monitoring is a cadence, and the simulation is a tabletop

"Monitored for change" needs a stated mechanism. A named owner reviewing on a cadence and subscribed
to provider announcements is honest and minimal. **Not built:** a hash monitor of terms pages.
Rendered pages churn for reasons unrelated to the terms, and a monitor that raises false alarms
trains its owner to ignore it. The review trigger for building one is recorded: a missed terms change
discovered after the fact.

### Decision 7 — the runbook is written first, and the drills time it

As with 02.4 SF-5, a drill measures a procedure only if the procedure existed before the clock
started. SF-1 writes the runbook and the inventory rows. Every drill afterwards follows them. A
deviation during a drill is a finding, fixed in the runbook and re-drilled. It is not absorbed into
the timing.

## Sub-Features

The order is load-bearing: procedures before drills, the compiler change early because it forces a
recompile, and the operator-heavy drills last.

- [ ] **SF-1: Inventory completion and the runbook draft.**
  - `credential-inventory.md`:
    - S2/S3 rows, the S1 correction if 02.3 has not landed it, and P1/P2 checked present;
    - Table B gains "Stated maximum" and "Rebuild required" columns (Contract 4);
    - the operator-confirmed maxima are entered.
  - `docs/containment-runbook.md` drafted per Contract 7:
    - event and incident definitions;
    - the five actions with commands;
    - the evidence-preservation rule;
    - the disposition table (Contract 5);
    - the R9.6 trigger.
  - `docs/records/containment-drills.md` skeleton, with the drill template (Contract 6).
  - Documentation only, 3 files.
- [ ] **SF-2: T37 — the authorization gate.**
  - `compile-policy.sh`:
    - the `authorization` rules (Contract 2);
    - `enables_actions` accepted on pack manifests and MCP entries (Contracts 1 and 3);
    - the vocabulary built from every committed manifest.
  - `packs/github-cli/pack.yaml` gains `enables_actions: [git-push]`, and
    `packs/kubernetes/pack.yaml` gains `[infrastructure-apply]`.
  - `github` and `kubernetes` profiles gain their per-action `waive` entries, with the operator's
    text.
  - Probe profiles under `tests/fixtures/authorization/`.
  - `verify-containment.sh` is created with **phase F** (compile negatives and the runtime checks).
  - Every resolved artifact is recompiled on the host and passes `--check` in the same commit.
  - `packs/README.md` documents the field.
  - The composite is green.
  - Size: 6-8 files, one coherent compiler change.
- [ ] **SF-3: `verify-containment.sh` phases A–D.**
  - Phase A: the static checks. The drill-evidence check is **red until SF-6 by design**, and that
    expected red is recorded, as 02.4 SF-2 did.
  - Phase B: T40, both forms, for each agent.
  - Phase C: the pod-wide live cut, with recording continuing.
  - Phase D: R12.5.
  - Measures Decision 3's live forms, including whether the mediator tolerates an agent-network
    detach. The runbook commands are corrected to what was measured.
- [ ] **SF-4: T41 drill and the T40 MCP half.**
  - Harness **phase E** covers T41's mechanical steps (contaminate, selective discard, rebuild,
    assert dispositions) under the fixture topology with the harness's own project name.
  - The **full drill** is performed once and recorded: identity rotation for the contaminated agent,
    re-bootstrap for all three agents, and the recorder resuming without duplicates.
  - The **MCP-disable exercise** runs against 02.3's `test-mcp.yaml` and records per Decision 4.
  - The R13.2 and T40 amendment text goes into the drills record.
- [ ] **SF-5: T26 drills — pod-local and pack credentials (S1–S3, P1–P2).**
  - Drill each row per Contract 6, and measure `restart` versus `--force-recreate` (inode and
    replay).
  - Correct `mediator/identity/README.md` and the 02.3 README section to the working form.
  - P2 needs a disposable cluster. Without one, P2 is a named gap.
- [ ] **SF-6: T26 drills — provider credentials (E1–E4, V1–V3).**
  - Mint drill credentials, place them in the pod, declare, revoke, and replay both the refresh
    token and the access token.
  - Record the access-token survival findings, and add the compensating action to the runbook where
    one survives.
  - Phase A goes green.
  - **Smallest in code and largest in operator wall-clock.** Some access-token replays have to wait
    hours.
- [ ] **SF-7: T44 and close-out.**
  - `third-party-assessments.md`:
    - R14.3 owner and triggers for all three routes;
    - the cadence;
    - the tabletop outcome, labelled SIMULATION.
  - Seam inspection recorded.
  - Runbook finalised, and the README section linked.
  - The two proposed edits recorded as exact replacement text.
  - The criterion-to-evidence table.
  - Full composite green.

No sub-feature is oversized. SF-2 is the only one with real code, and it is one compiler rule plus
the manifests and profiles it touches. SF-6's length is waiting, not work.

## Interface Contracts

### 1. Pack manifest: `enables_actions`

This is additive, so the schema stays at `1`. It is a new key in 02.3's unknown-keys-refused set.

```yaml
enables_actions: [git-push]    # optional; default []. Each ^[a-z][a-z0-9-]*$, unique.
```

It is declared when the pack's credential, egress or binaries let an unattended agent perform the
action. `terraform` declares nothing: it carries no provider credential until Milestone 03, whose
AWS pack will declare `infrastructure-apply`.

### 2. Profile `authorization` and the compiler rules

```yaml
authorization:
  classify: [infrastructure-apply]
  waive:
    git-push: >-
      <operator-supplied reason: why unattended push is acceptable under this profile, and the
      PAT's repository scope that bounds it>
# or, test profiles only in practice:
# authorization:
#   waiver: <whole-profile reason>
```

| Condition | Exit | Message names |
|---|---|---|
| `waiver` present together with `classify` or `waive` | 2 | the profile. The whole-profile waiver stands alone |
| An action in `classify` or `waive` not in the vocabulary | 2 | the action, and "no committed pack declares it — a misspelled classification enforces nothing" |
| An action in both `classify` and `waive` | 2 | the action |
| A known action in neither (and no whole-profile `waiver`) | 2 | the action, and the manifests that declare it |
| Empty `waive` reason, or a `waive` that is not a map | 2 | the key |
| A classified action enabled by a loaded pack or an inventoried MCP server | **3** | the action, the pack or server, and both remedies: remove it, or move the action to `waive` with a reason |

- The existing rules stay: non-empty `classify` elements, and a non-blank whole-profile `waiver`.
- Nothing is emitted into the resolved artifact. The profile file is the record R12.7 asks for, and
  the resolved schema the mediator validates is unchanged. The recompile is still mandatory, because
  the compiler changed (01.6 Deviation 3).

### 3. MCP inventory entry: `enables_actions`

These fields are added to 02.3's Interface Contract 5 entry:

```yaml
risk_tier: irreversible
enables_actions: [git-push]   # required non-empty iff risk_tier is irreversible (exit 2)
```

A `write`-tier server may declare it and is not required to. The Contract 2 refusal applies to every
inventoried server whatever its tier.

### 4. `credential-inventory.md` Table B columns

The new column order:

`# | Compensating controls | Documented revocation procedure | R4.16 review trigger | Stated maximum
(operator-confirmed) | Measured detection-to-revocation (02.5) | Rebuild required`

- **Measured** is either `mm:ss` (or `h:mm:ss`) with a link to the drill, or `GAP: <reason>`.
- **Rebuild required** is `no` (image IDs equal) or `GAP (R8.5): <reason>`.
- Harness phase A parses these two columns and the stated maximum, and fails on an empty cell.

### 5. The disposition table (runbook § Return to known-good)

| Store | Kind | Disposition | Action |
|---|---|---|---|
| `claude-state`, `codex-state`, `agy-state` | Named volume | `discard` | `docker volume rm <proj>_<name>` after `down` without `-v` |
| `audit` | Named volume, mediator only | `preserve` | Evidence. No agent can write it (D12) |
| `claude-action-audit`, `codex-action-audit`, `agy-action-audit` | Named volume, recorder only (02.1) | `preserve` | Evidence |
| per-agent build cache (`build-cache.yaml`) | Named volume, agent-writable | `discard` | As the state volumes |
| project mount (`workspace/` or the profile's path) | Host bind | `review` | The operator reviews it with `git status` and `git diff`, and removes untracked content. It is never discarded by the path |
| `compose/generated/` | Host staging, `:ro` in the agents | `rotate` | Kept, but every pack credential staged there that the agent held is revoked and re-staged per T26 |
| `mediator/identity/` | Host | `rotate` | The contaminated agent's own client key or proxy credential is re-issued. The CA is untouched, because no agent ever held its key |

- The harness reads the first column. Every volume `name` in `docker compose config`, across every
  shipped profile and every opt-in fragment, must match a row.
- Names are compared after stripping the Compose project prefix.

### 6. The drill record (per row, in `containment-drills.md`)

```
### Drill <row id> — <credential type>
- Drill credential: <how it was minted>; never the working credential; no value recorded
- Stated maximum: <mm:ss>
- t0 (incident declared, UTC): <ISO-8601>
- Steps: <numbered, exactly as the runbook states them; any deviation is marked FINDING>
- t1 (replay refused, UTC): <ISO-8601> — evidence: <HTTP status / 407 / TLS alert; no credential material>
- Access-token replay (OAuth rows): <status at t1, and at each later check until refused or expired>
- Measured: <mm:ss>   Within maximum: yes | no
- Image IDs before / after: <service: 12-hex prefix, each>   Rebuild: no | GAP (R8.5)
- Re-issue: <new credential in place; agent authenticated; image IDs unchanged>
```

The repository is public. No credential value, OAuth code or token prefix longer than the provider's
public type prefix (`sk-ant-`, `ghp_`) ever enters the record.

### 7. `docs/containment-runbook.md` structure

1. **Event and incident.**
   - An *event* is any deny verdict, an identity refusal (`403 subject_mismatch` / `407`), an
     `mcp-gate` REFUSED or DRIFT, a failed startup self-check, or an R8.6 redaction hit. It is
     triaged. Containment is not required.
   - An *incident* is any of:
     - a deny not explained by a known policy gap;
     - an attempt against the metadata endpoint, RFC1918 or a refused DNS name that no allowed
       workflow produces;
     - a cross-binding identity attempt;
     - DRIFT on a server the operator did not change;
     - an action-log line showing a classified action attempted;
     - a credential value found in a transcript;
     - a write to a capability-declaration file.

     An incident starts `t0`.
   - The operator confirms the list (review assumption 2).
2. **First rule: preserve evidence.** Never `down -v`. Never `docker volume prune`.
3. **The five actions** (Decision 3), each with commands, the expected result, and how to confirm
   it.
4. **The revocation index.** One line per inventory row: the procedure link and the stated maximum.
5. **Return to known-good.** The ordered path, with Contract 5 embedded.
6. **After the incident.** The R9.6 review trigger (a blocked attempt going unnoticed long enough to
   matter) and the drill cadence.

### 8. `tests/acceptance/verify-containment.sh`

House idiom:

- `set -euo pipefail`, with `ROOT` resolved from the script;
- `phase`, `pass`, `fail` and `note`;
- `PROJECT="containment-$$"`;
- the fixture topology (`test-egress.yaml`), so no phase spends model tokens or a login;
- `trap cleanup EXIT`, where `down -v --remove-orphans` runs **only** in the trap, under its own
  project.

| Phase | Asserts |
|---|---|
| A — static | The disposition table covers every volume (Contract 5). Every inventory row has a procedure, a stated maximum, a measured value or `GAP:`, and a rebuild cell (Contract 4). The runbook carries both definitions and the five action sections. The R14.3 record names an owner and triggers for the three routes. `.dockerignore` admits nothing under `workspace/` |
| B — T40 | For each agent X, stop form: X stopped (and its recorder); the other two are `running`, a fixture allow succeeds through the mediator from each, and each produces a fresh egress line; X restarts. Disconnect form: the same, with X `running` but unable to reach the mediator |
| C — pod-wide cut | The mediator is detached from `egress-net`. From every agent an allowed fixture request fails, **and** a line for each attempt still reaches the audit sink. Reattach and allow succeeds again |
| D — R12.5 | Markers in `/tmp` and `/home/agent`. `down` (no `-v`), then `up`. The `/tmp` marker is gone, the state marker is present, and the audit line count has not decreased |
| E — T41 mechanical | Contaminate (Criterion 3 markers). `down`, then `volume rm` of the discard rows, then `up --build --force-recreate`. No marker remains. The audit and action-audit volumes are byte-identical in their pre-recovery prefix. Recorder output for the new session is present and not duplicated |
| F — T37 | Compile negatives, one per Contract 2 row, against probe profiles in a scratch copy. Every shipped profile compiles. Runtime under `default`: the credential-absence checks in each agent, and `CONNECT github.com` from `claude` and `agy` refused, with each deny line carrying `agent` and `identity_source` |

Exit `0` when everything passes, `1` otherwise. There is no skip variable, following the same
reasoning as `retry_cold_peer`.

## Edge Cases

1. **The leaked one-year token must not wait for this feature.** 02.5's build waits on 02.1–02.4.
   The token is revoked at the provider now, by the operator. It is recorded in `containment-drills.md`
   as a pre-drill revocation, with the date and without the value. E4's timed drill uses a fresh
   drill token.
2. **Access tokens outliving revocation.** If V1's 8-hour or V2's 10-day access token still works
   after the session is revoked, the row's measured time is that survival. The runbook's action for
   that row becomes: isolate the agent (disconnect) **and** discard its volume at `t0`, before
   revoking. The finding is recorded against R13.1's "stated maximum" honestly rather than hidden
   behind the console time.
3. **Provider revocation granularity.** Anthropic may offer only "log out all sessions" rather than
   revoking one token. The drill records the granularity observed. An all-or-nothing revocation also
   ends the operator's own sessions, which is recorded against R4.17.
4. **`restart` versus `--force-recreate` for a replaced `file:` secret.** A Compose `file:` secret is
   a bind mount. `cp` over the file keeps the inode and a restart sees the new content. `mv` or an
   editor's write-then-rename leaves the container on the old inode (the same trap as R4.14). SF-5
   measures both and the README states the working form.
5. **`basic_ncsa_auth`'s credential cache.** Until the mediator restarts, a revoked proxy credential
   still works (`mediator/identity/README.md`). `t1` is measured after the restart, so the restart is
   part of the procedure, not an afterthought.
6. **S1 is revoked by reissuing the CA.** `mediator/identity/README.md` states that there is no
   CRL and no OCSP. A reissued client certificate with the same subject under the same CA is still
   accepted, so revocation means running `ca --force`, reissuing the three listener certificates
   and the client certificate, restarting the mediator, and restarting `claude` and `agy` so they
   receive the new CA certificate. S1's measured time, and the 10-minute maximum it must beat, cover
   that whole path. The drill confirms that the old certificate is refused at the handshake.
7. **Detaching an agent network from under the mediator.** SF-3 measures the agent-side disconnect,
   which leaves the mediator untouched. Detaching the **mediator** from one agent network is not in
   the runbook, because the mediator validates its network set at start only. It is recorded as
   untested rather than recommended.
8. **A pod-wide cut still resolves.** With `egress-net` detached, dnsdist still decides and audits,
   and unbound's upstream fails (SERVFAIL). Attempts remain visible, which is the property Decision 3
   wants.
9. **The recorder during isolation.** Stopping the agent first and letting the recorder drain before
   stopping it keeps the tail of the transcript in the sink. Stopping the recorder first loses it.
   The runbook orders the two.
10. **The recorder after a discard.** A fresh state volume carries no transcript directory. 02.1's
    recorder is stated to survive this (02.1 plan:127). Phase E asserts that it resumes and does not
    re-ship the old session.
11. **A new named volume with no disposition.** Phase A fails. That is the point: every volume
    arrives with a recovery decision.
12. **Contamination of the project mount.** It is host content and the operator's repository, so the
    path reviews it and never deletes it. An agent can write there by design (R2.1). T41 records
    that this store is not returned to known-good by the path, and why.
13. **Mediator compromise is outside T41.** The threat model is a compromised agent. A suspected
    mediator compromise is recorded in the runbook as: rebuild the mediator, reissue the CA and every
    certificate, rotate every proxy credential. It is not drilled here.
14. **A new action in any pack.** Every non-waiver profile fails to compile until it classifies or
    waives the new action. The failure is deliberate and loud, and the message names the manifest.
    Milestone 03's AWS pack declaring `infrastructure-apply` adds nothing new, because the name is
    already known.
15. **A pack that under-declares.** `enables_actions` is only as good as its author. Pack review
    (R7.3 and R12.3's PR path) is where it is checked, and `packs/README.md` states the question to
    ask: "with this pack's credential and egress, can an unattended agent do X?".
16. **`codex` and `github.com`.** `codex`'s base allowlist carries `github.com` for reasons recorded
    at 01.1. Under `default` its only barrier to `git-push` is the absent credential. That is
    recorded, and a repository-embedded credential in the project mount (a token in
    `.git/config`) is named as the residual it leaves.
17. **The drill evidence phase is red until SF-6.** It is an expected red, recorded when SF-3 lands,
    and it is not skipped.
18. **Operator absence mid-drill.** A drill whose clock is interrupted is re-run, not annotated.
    `t0` to `t1` is only meaningful without a gap.

## Test Command

```
bash tests/acceptance/verify-pack-composition.sh && bash tests/acceptance/verify-pod-topology.sh && bash tests/acceptance/verify-egress-mediator.sh && bash tests/acceptance/verify-audit-completeness.sh && bash tests/acceptance/verify-tool-packs.sh && bash tests/acceptance/verify-mcp-inventory.sh && BOUNDARY_PROFILES="default terraform kubernetes github" bash tests/acceptance/validate-boundary.sh && bash tests/acceptance/verify-reproducibility.sh && bash tests/acceptance/verify-containment.sh && bash scripts/lint-policy.sh
```

This is 02.4's composite with `verify-containment.sh` added. The whole chain is kept because SF-2
changes the policy compiler and the pack manifests, and every harness that compiles or composes a
profile is therefore a regression check here. No phase spends model tokens or a login.
`verify-auth-state.sh` stays out, by the D22 precedent.

The T26 drills and the full T41 drill are **not** run by this command. They spend real credentials
and operator time, and they are recorded in SF-4 to SF-6. Phase A is what keeps their evidence from
going missing. Per DD-12 the operator may adjust this command at build time without gate
re-approval.

## Test Strategy

- **Phase F (T37)** is proven in both directions. There is one compile negative per Contract 2 row,
  and every shipped profile compiles. One negative control is run once and recorded: removing
  `git-push` from `github`'s `waive` makes the compile exit 3.
- **Phases B–E** run under the fixture topology. Each has a single recorded negative control, run
  once and not left in the suite:
  - B: stopping the mediator instead of an agent fails the "others unaffected" assertion.
  - C: an attempt with the cut in place is shown absent from the audit when the audit writer is
    deliberately stopped, which proves the assertion can fail.
  - D: `down -v` fails the preservation assertion.
  - E: skipping the `volume rm` leaves the markers, and the phase fails.
- **Phase A** is static. Its drill-evidence part is red until SF-6 and green afterwards, and both
  states are recorded.
- **Drills** follow the runbook verbatim (Contract 6). A deviation is a finding. A finding is fixed in
  the runbook and the drill is re-run, not annotated.
- **Regression:** the full composite after SF-2 (the compiler change) and again at close-out.
- **Coverage:** `containment-drills.md` carries the criterion-to-evidence table, mapping every
  numbered criterion to a phase, a drill or a record section.

## Documentation

- `docs/containment-runbook.md` (new), per Contract 7.
- `docs/records/containment-drills.md` (new):
  - the pre-drill revocation of the leaked token (date only);
  - the T26 drills;
  - the `restart` versus `--force-recreate` measurement;
  - T40 (both forms) and the MCP-disable exercise;
  - T41 with its per-store outcomes;
  - R12.5 and T37 results;
  - the T44 seam inspection;
  - the two proposed edits as exact replacement text;
  - the criterion-to-evidence table.
- `docs/records/credential-inventory.md`: the S2/S3 rows and the S1 correction if still needed; the
  new Table B columns; the maxima; the measured values; Residual 4 rewritten from "documented, not
  tested" to its measured state.
- `docs/records/third-party-assessments.md`: R14.3 for all three routes, the cadence, and the
  SIMULATION outcome.
- `mediator/identity/README.md`: the rotation command corrected to the measured form.
- `packs/README.md`: the `enables_actions` field and the review question.
- `README.md`:
  - a short "Containment and response" section linking to the runbook;
  - the revocation section pointed at the inventory's measured maxima;
  - the credential-rotation form corrected.
- **Not edited here:** `docs/ARCHITECTURE_AND_DESIGN.md` (its runbook table),
  `REQUIREMENTS.md` (R13.2/T40), `prd.md`. They are carried as proposed edits, as 02.3 and 02.4 do.

## Files to Create/Modify

Paths are relative to the solution root.

| File | Action | Changes |
|------|--------|---------|
| `scripts/compile-policy.sh` | Modify | `authorization` rules (Contract 2); `enables_actions` on packs and MCP entries (Contracts 1, 3); vocabulary from every committed manifest |
| `packs/github-cli/pack.yaml` | Modify | `enables_actions: [git-push]` |
| `packs/kubernetes/pack.yaml` | Modify | `enables_actions: [infrastructure-apply]` |
| `packs/README.md` | Modify | Field and review question |
| `profiles/github.yaml`, `profiles/kubernetes.yaml` | Modify | Per-action `waive` with operator text |
| `profiles/default.yaml`, `profiles/oauth-mount.yaml`, `profiles/terraform.yaml` | Modify | Comment only: "SHAPE ONLY" replaced by the enforcement statement. Classification unchanged |
| `policy/resolved/*.yaml` | Regenerate | Recompiled on the host and checked with `--check` in the SF-2 commit |
| `tests/fixtures/authorization/` | Create | Probe profiles and a probe pack manifest for the Contract 2 negatives |
| `tests/acceptance/verify-containment.sh` | Create | Phases A–F (Contract 8) |
| `docs/containment-runbook.md` | Create | Contract 7 |
| `docs/records/containment-drills.md` | Create | Per Documentation |
| `docs/records/credential-inventory.md` | Modify | Rows, columns, maxima, measurements |
| `docs/records/third-party-assessments.md` | Modify | R14.3 extension and SIMULATION |
| `mediator/identity/README.md` | Modify | Measured rotation form |
| `README.md` | Modify | Per Documentation |
| `.project/.../milestone-status.txt` | Modify (by `/build`) | Sub-feature progress |

## Dependencies

- **Features 02.1–02.4 complete (`[x]`).** Today they are `[~]` planned, not built.
  - 02.1: the recorders, the action-audit volumes, and the R9.6 trigger for the runbook.
  - 02.2: the fixture topology this harness reuses unchanged.
  - 02.3: the pack credentials P1 and P2, the `github`/`kubernetes`/`terraform` profiles, the MCP
    inventory, `mcp-gate` and `test-mcp.yaml`.
  - 02.4: the `main`-pinned digest T41 rebuilds from.
- **Operator actions.** These are this feature's long pole.
  - **Revoke the leaked one-year `CLAUDE_CODE_OAUTH_TOKEN` now** (Edge Case 1).
  - Confirm the stated maximum per inventory row before SF-5.
  - Confirm the event and incident definitions.
  - Supply the `waive` reasons for `github` and `kubernetes`.
  - Confirm the R14.3 cadence, and whether Ottawa Cloud Consulting owns all three routes.
  - Mint the drill credentials:
    - throwaway Anthropic, OpenAI and Google API keys;
    - a fresh `claude setup-token`;
    - fresh `claude` and `codex` OAuth logins;
    - a fine-grained PAT on a throwaway repository;
    - a disposable cluster and a scoped `kubeconfig` (or accept P2 as a named gap).
  - Perform the provider-console revocations.
- **External.** The three providers' consoles and APIs (replay endpoints); GitHub; a disposable
  Kubernetes cluster.
- **Downstream.**
  - The milestone Definition of Done needs the R13.2/T40 amendment **accepted**, or a live disable
    path built, before the R12.8 notice lifts. This feature supplies tested amendment text; it does
    not accept it.
  - Milestone 03 re-runs T26 for the AWS credential and adds its row to the disposition table.

## Architectural Deviations

(none)
