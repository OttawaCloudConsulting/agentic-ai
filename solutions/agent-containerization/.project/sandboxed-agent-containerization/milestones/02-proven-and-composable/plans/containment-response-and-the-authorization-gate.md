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

- [x] **SF-1: Inventory completion and the runbook draft.**
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
- [x] **SF-2: T37 — the authorization gate.**
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
- [x] **SF-3: `verify-containment.sh` phases A–D.**
  - Phase A: the static checks. The drill-evidence check is **red until SF-6 by design**, and that
    expected red is recorded, as 02.4 SF-2 did. *(Built: phase A is red in TWO parts — the
    drill-evidence cells until SF-6 and the R14.3 three-route table until SF-7. See Deviation 3.)*
  - Phase B: T40, both forms, for each agent.
  - Phase C: the pod-wide live cut, with recording continuing.
  - Phase D: R12.5.
  - Measures Decision 3's live forms, including whether the mediator tolerates an agent-network
    detach. The runbook commands are corrected to what was measured.
- [x] **SF-4: T41 drill and the T40 MCP half.**
  - Harness **phase E** covers T41's mechanical steps (contaminate, selective discard, rebuild,
    assert dispositions) under the fixture topology with the harness's own project name.
  - The **full drill** is performed once and recorded: identity rotation for the contaminated
    agent, re-bootstrap for all three agents, and the recorder resuming without duplicates.
    *(run 2026-09-30 against the real pod and the `main` pins. Attempt 1 failed at the rotation and
    is recorded as three findings; the runbook was corrected and the drill re-run, per the record's
    own Method. `agy` is not a named gap.)*
  - The **MCP-disable exercise** runs against 02.3's `test-mcp.yaml` and records per Decision 4.
  - The R13.2 and T40 amendment text goes into the drills record.
- [x] **SF-5: T26 drills — pod-local and pack credentials (S1–S3, P1–P2).**
  - Drill each row per Contract 6, and measure `restart` versus `--force-recreate` (inode and
    replay).
  - Correct `mediator/identity/README.md` and the 02.3 README section to the working form.
  - P2 needs a disposable cluster. Without one, P2 is a named gap.
  *(Built 2026-09-30. Read against Deviation 1's row ids, this sub-feature's five rows are S1, S2,
  S3, S4 and S5 — `P1`/`P2` in the bullet above are the plan's provisional names for the two pack
  credentials, which the inventory carries as S2 and S3. All five drilled and all inside their
  stated maxima: S4 00:06, S5 00:14, S1 00:07 (10:00 each), S2 02:21 (15:00), S3 00:11 (30:00),
  every one with identical image IDs before and after. No named gap: a disposable `kind` cluster was
  created for S3 and deleted after it. Two halves not measured, recorded as such rather than
  implied: S2's re-issue (one drill token was minted), and the `restart`-versus-`--force-recreate`
  comparison was measured on the **mount** — in-place versus rename — not on the proxy-credential
  splice. Attempt 1 of S4/S5 was re-run under Edge Case 18.)*
- [ ] **SF-6: T26 drills — provider credentials (E1–E4, V1–V3).**
  - Mint drill credentials, place them in the pod, declare, revoke, and replay both the refresh
    token and the access token.
  - Record the access-token survival findings, and add the compensating action to the runbook where
    one survives.
  - **The drill-evidence part of phase A goes green.** Its R14.3 part does not — that closes at SF-7
    (amended at SF-3; see Deviation 3).
  - **Smallest in code and largest in operator wall-clock.** Some access-token replays have to wait
    hours.
- [ ] **SF-7: T44 and close-out.**
  - **Write the six MUST-REACH-USER-DOCUMENTATION items (D-1 to D-6) into `README.md` and the
    runbook.** Operator-directed at SF-6; the table with destinations and sources is in
    `docs/records/containment-drills.md`. **Close-out is not complete while any of the six is only
    in a drills record**, and the criterion-to-evidence table must name each one.
  - **Revoke the `CLAUDE_CODE_OAUTH_TOKEN` minted for this testing work** and record the date (E4's
    standing obligation, made live 2026-09-30 — see Deviation 2's supersession note).
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
- **MUST REACH USER DOCUMENTATION — six items added at SF-6 (2026-09-30), operator-directed.**
  `docs/records/containment-drills.md` § "MUST REACH USER DOCUMENTATION" carries the table (**D-1**
  to **D-6**) with each item's destination and source. These are **not** drill trivia: each is an
  operator-facing consequence that would otherwise be discoverable only by reading a drills record.
  **SF-7 is not complete until every one is written into `README.md` and/or the runbook**, and the
  criterion-to-evidence table names them. In outline:
  - **D-1** provider revocation does **not** contain a `codex` session — both token halves survive,
    so the pod-side isolate-and-discard ordering is load-bearing for V2, not defence in depth;
  - **D-2** the asymmetry between V1 and V2 — an operator must not generalise across providers;
  - **D-3** a `codex` agent that has run once will not restart until its self-provisioned
    `~/.codex/skills/.system` is cleared (or the inventory declares it, a rebuild and repin);
  - **D-4** a stray `compose run` one-off blocks every volume discard, and `compose down` does not
    clear one-offs — an interactive login leaves exactly such a container;
  - **D-5** "revoked" is not a state to assume: `t1` is a replay that fails, and V2 is the worked
    example of a console action reporting success over a credential that kept working;
  - **D-6** the credential-handling rule for reproducing these drills — never print a credential
    file's contents while inspecting its structure.
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

### Deviation 1: credential-inventory row ids are S4/S5 for the proxy credentials, not S2/S3
- **What changed:** The two proxy credentials are added to `docs/records/credential-inventory.md` as
  new rows **S4** (`codex`) and **S5** (`agy`), in both Table A and Table B. The existing 02.3 rows
  keep their committed ids: S1 = `claude` mTLS client key, S2 = `github-token` PAT, S3 = `kubeconfig`.
  The plan's `P1`/`P2` ids are **not** used at all. Interface Contract 4's column set is applied to
  twelve rows (E1–E4, V1–V3, S1–S5) rather than the eleven the plan enumerated.
- **Originally planned:** Acceptance Criterion 1 enumerates the inventory as "S1–S3: the 01.6
  identity material — `claude`'s client key and the `codex` and `agy` proxy credentials; P1–P2:
  02.3's GitHub token and `kubeconfig`", and SF-1's checklist says "S2/S3 rows ... and P1/P2 checked
  present". Decision 2 and Interface Contract 6 repeat the `S1–S3` / `P1–P2` split.
- **Why necessary:** The plan was written 2026-09-10 and predicted what 02.3 would add. 02.3 landed
  differently: it took **S2 and S3** for the GitHub token and the `kubeconfig` (the plan's P1/P2) and
  gave the proxy credentials no rows at all — only prose at the foot of the document. Independently,
  `P1`–`P4` are already in use in the same file for the **R8.6 transcript-exposure findings**, a
  different kind of row entirely. Adopting the plan's scheme would mean renumbering rows already
  committed by 02.3 and relocating four existing R8.6 findings, to no benefit. Operator decision,
  2026-09-29.
- **Impact:** The row-id vocabulary is `E1–E4, V1–V3, S1–S5`, and every downstream consumer uses it:
  the runbook's § 4 revocation index, the drill records' `### Drill <row id>` headings (Interface
  Contract 6), and `verify-containment.sh` **phase A**, which parses Table B by row. SF-5's scope
  becomes **S1–S5** (five rows, not the plan's "S1–S3 and P1–P2"); SF-6's stays E1–E4 and V1–V3.
  Two credentials that were persisted and mounted but carried **no R4.16 row** now have one, which
  is a completeness gain against R8.4 rather than a renaming exercise. Milestone 03 adds its AWS
  credential as the next free id in this sequence.

### Deviation 2: Edge Case 1 has no pre-drill revocation, because the token it assumes does not exist
- **What changed:** `docs/records/containment-drills.md` records, in place of a revocation date, that
  **no outstanding one-year `CLAUDE_CODE_OAUTH_TOKEN` exists** — it was never minted outside a test
  (operator-confirmed 2026-09-29). Edge Case 1 is closed without a date.
- **Originally planned:** Edge Case 1 states "The leaked one-year token must not wait for this
  feature ... The token is revoked at the provider now, by the operator. It is recorded in
  `containment-drills.md` as a pre-drill revocation, with the date and without the value." The
  Documentation section lists "the pre-drill revocation of the leaked token (date only)" as a
  deliverable of this record, and Decision 2 calls it "the outstanding leaked one-year token".
- **Why necessary:** The premise is false. The `oauth-token` cell was exercised to prove the delivery
  path, not to hold a working credential, and R4.12 makes `oauth-interactive` `claude`'s default
  precisely so that a year-long token is not minted by default. Writing a date here would assert an
  event that did not happen, in a record whose whole value is that its timestamps are real.
- **Impact:** One named deliverable of `containment-drills.md` is replaced by a negative finding. **No
  drill scope changes:** E4 stays in SF-6, which mints a fresh drill token via `claude setup-token`,
  revokes it and replays it, against the same **15:00** stated maximum. The 01.4 SF-3 standing
  obligation to revoke a token minted to prove a test cell now applies to that drill token. E4's
  one-year replay window in the inventory's blast-radius column is unchanged — it describes the
  credential type, not an outstanding instance. The feature's long-pole operator dependency list
  loses its one "do this now, ahead of the build" item.
- **Partly superseded 2026-09-30.** A `CLAUDE_CODE_OAUTH_TOKEN` **is** now outstanding — the operator
  minted one for this testing work, held in the git-ignored `references/.env_keys`. This does not
  reopen Edge Case 1, whose premise was a *leaked* token, but it makes E4's standing obligation live:
  **SF-7 revokes it and records the date.** See `docs/records/containment-drills.md` § Pre-drill
  revocation, "Correction, 2026-09-30".

### Deviation 3: phase A is red in two parts, and it goes fully green at SF-7 rather than SF-6
- **What changed:** `verify-containment.sh` phase A carries Interface Contract 8's R14.3 check
  (`docs/records/third-party-assessments.md` must name an owner and review triggers for the `claude`,
  `codex` and `agy` routes, plus a monitoring cadence) alongside the drill-evidence check. That
  record is written by **SF-7**, so phase A landed with **two independent expected reds**: two
  failures for the inventory's unfilled Measured and Rebuild cells (green at SF-6) and two for the
  absent R14.3 three-route table (green at SF-7). Measured at SF-3: 12 passed, 4 failed. Both parts
  are recorded in `docs/records/containment-drills.md` § "Expected red", which now also states the
  shape SF-7 must write for phase A to read, and SF-6's bullet above is corrected to say that only
  the drill-evidence part goes green there.
- **Originally planned:** Edge Case 17 and the Test Strategy name a single expected red — "its
  drill-evidence part is red until SF-6 and green afterwards" — and SF-6's bullet says flatly
  "Phase A goes green". Contract 8 nonetheless lists the R14.3 assertion under phase A.
- **Why necessary:** the two statements cannot both hold. Dropping the R14.3 assertion would make
  SF-6's text true at the cost of leaving criterion 6's evidence unchecked by any harness; keeping it
  makes phase A's red state two-part and moves its green date to SF-7. The operator chose to keep the
  check and correct the plan text.
- **Impact:** the Test Command is red from SF-3 until SF-7, by design and recorded, not until SF-6 —
  `verify-containment.sh` exits 1 on these four failures. Within that harness everything else is
  green (measured at SF-3: 140 passed, 4 failed, and all four are these expected reds; phases B, C, D
  and F are clean). SF-6 must not treat a still-red phase A as a failure, and SF-7 must write the
  R14.3 table in the shape the drills record now specifies.

### Deviation 4: the T41 drill used the existing credentials and the `apikey` cell, not minted throwaways in the default cell
- **What changed:** the full T41 drill re-bootstrapped all three agents from the keys already in
  `references/.env_keys`, exercising the **`apikey`** cell for every agent — including `claude` and
  `codex`, whose shipped default is `oauth-interactive`. No throwaway keys were minted for it.
- **Originally planned:** criterion 1 and the plan's Dependencies say drills use "dedicated drill
  credentials, never the operator's working credentials", and list "throwaway Anthropic, OpenAI and
  Google API keys" plus fresh `claude` and `codex` OAuth logins among the operator actions.
- **Why necessary:** the operator's decision, taken with the tradeoff stated. T41 **revokes
  nothing** — it discards volumes and re-authenticates — so credential reuse alters no credential's
  lifetime and the exposure is bounded to a pod that was torn down at the end. Minting three
  throwaway keys and driving two interactive logins would have gated the drill on console work for
  no change in what T41 measures.
- **Impact:** two limits on what this drill evidences, both recorded in
  `docs/records/containment-drills.md`. The `oauth-interactive` re-bootstrap path is **not**
  exercised by it — only `apikey` is — so criterion 3's "each agent re-bootstraps authentication" is
  met in the `apikey` cell alone. And the departure does **not** extend to SF-5 and SF-6: those
  drills revoke, so the throwaway rule is load-bearing there and the plan's dependency list stands
  unchanged for them.

### Deviation 5: SF-6 changed image code — the `already_authenticated` shape check for `claude`

- **What changed:** `images/bootstrap-auth.sh`'s `claude` branch of `already_authenticated()` now
  tests the **shape** of the credential, not merely that the file is non-empty. Both arms require a
  non-empty `accessToken`; the undocumented `$HOME/.claude.json` arm is **narrowed rather than
  removed** (Chesterton's Fence — it carries no recorded rationale, the installed claude 2.1.260 was
  measured not to create it, and the cost of narrowing it wrongly is a re-login prompt, never a
  credential treated as valid when it is not).
- **Originally planned:** SF-6 is scoped to *drills* — "Mint drill credentials, place them in the
  pod, declare, revoke, and replay." The plan's Files table contains no image code, and a drills
  sub-feature editing the pod's authentication path is outside what it describes.
- **Why necessary:** drill V1 measured the defect, twice. On a refused refresh the `claude` CLI
  **empties the credential in place** (509 B → 281 B, `accessToken` and `refreshToken` empty,
  `expiresAt` 0), and the old `-s`-only test then reported that file **already authenticated** and
  skipped the re-login — leaving the agent unrecoverable without an operator discarding the state
  volume. That makes T41's "each agent re-bootstraps authentication" (criterion 3, a Milestone 02
  acceptance criterion already measured at SF-4) rest on a presence test. The function's own
  docstring says "Presence and shape only", and the `codex` branch eleven lines below already
  implements the shape half with a comment describing this exact class of failure; the `claude`
  branch never received it. **The operator was offered the choice — fix now, defer to SF-7, or leave
  as a finding — and chose to fix it now as a recorded deviation.**
- **Impact:** all three agent images rebuilt, so **image IDs changed at this point in the feature**.
  Every R8.5 "no rebuild" result recorded for S1–S5, E1–E4 and V1 was measured against the
  *pre-fix* images and each is internally consistent (identical before and after its own drill);
  V2 and V3 will be measured against the post-fix images. Verified in both directions after the
  rebuild: the emptied credential now reports "has no credential yet" with the login instruction,
  and a shaped credential still reports "already authenticated". `verify-auth-state.sh` is the
  harness that covers this function (D22 keeps it out of the composite).

### Deviation 6: the `bootstrap-auth.sh` COPY moved from `agent-base` to `agent-packs`

- **What changed:** `images/Dockerfile` no longer copies `images/bootstrap-auth.sh` in the
  `agent-base` stage; the COPY now sits in `agent-packs`, beside `entrypoint.sh`, `pack-install.sh`
  and `mcp-gate.js`. Moved, not duplicated.
- **Originally planned:** nothing in this plan touches the Dockerfile.
- **Why necessary:** Deviation 5's fix was **inert without it**, and that was found by building, not
  by reasoning. `agent-base` is pulled from GHCR **by digest** (D21) and BuildKit skips a stage
  nothing references, so the edit reached nothing: all three agents were rebuilt and the rebuilt
  image still carried the published copy and the old behaviour. This is the third instance of one
  structural trap — `entrypoint.sh` hit it at 01.6 SF-3 (a credential splice that silently did not
  happen), `pack-install.sh` at 02.3 SF-2 — and the `agent-base` stage carried a note predicting
  it: *"an edit to images/bootstrap-auth.sh does not reach a local build until CI republishes this
  stage and compose/pins.env is repinned. Recorded rather than fixed here; the next feature that
  needs to edit it will have to choose, with this note in front of it."* This is that feature, and
  it chose to move it. Nothing in `tests/`, `scripts/`, `cicd/` or `.github/` asserts the file lives
  in `agent-base` (checked before the move).
- **Impact:** D21 is not weakened, by the argument already recorded in the Dockerfile for
  `entrypoint.sh`: D21 protects that the **base** an operator runs is the base CI built and
  attested, which stays exactly true — this stage already layers locally-derived content onto that
  attested base. The published base will no longer carry `/usr/local/bin/bootstrap-auth` once CI
  next rebuilds it; every agent stage passes through `agent-packs`, so every agent still has it.
  A future edit to this file now takes effect on a local build, which is the point.
