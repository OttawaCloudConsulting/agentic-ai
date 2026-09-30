# Containment Runbook — Feature 02.5

**Feature:** `containment-response-and-the-authorization-gate.md` (SF-1 draft; corrected by SF-3's
measurements and finalised at SF-7)
**Requirements:** R13.1, R13.2, R13.3, R12.5, R12.7, D16, and the R9.6 review trigger handed over
by Feature 02.1.
**Status:** **DRAFT.** Event and incident definitions and every stated maximum are
operator-confirmed (2026-09-29). The **live containment forms (§ 3.1, § 3.2)**, the **teardown
guarantee (§ 2)**, the **MCP disable path (§ 3.3)** and the **mechanical recovery path (§ 5.1, § 5.2)**
are all measured — SF-3 and SF-4, 2026-09-30, `verify-containment.sh` phases B–E and the MCP-disable
exercise, recorded in `docs/records/containment-drills.md`. Still **not measured**: the revocation
procedures (§ 3.4, § 4), which SF-5 and SF-6 drill, and § 5's live half — identity rotation and
re-bootstrap — which the operator's full T41 drill covers. The **revocation procedures (§ 3.4, § 4) are not yet
measured**; SF-5 and SF-6 drill them. Written before the drills, deliberately (Decision 7) — a drill
measures a procedure only if the procedure existed before the clock started. Commands still marked
**UNMEASURED** are corrected to their measured form in SF-5/SF-6.
A deviation observed during a drill is a **finding**: it is fixed here and the drill is re-run, not
annotated (Test Strategy, Edge Case 18).

Every command assumes the Compose project name `sandboxed-agent-pod` (`compose/compose.yaml:1`)
and the solution root as the working directory.

---

## 1. Event and incident

The distinction exists so that containment is not spent on routine denials. **Detection is
pull-based** (R9.6 stays MAY): nothing here pushes an alert, so both triage and declaration are
operator actions.

### An event is triaged. Containment is not required.

- any mediator **deny verdict** in the egress trail;
- an **identity refusal** — `403 subject_mismatch` (mTLS) or `407` (proxy credential);
- an `mcp-gate` **REFUSED** or **DRIFT** result at an agent's start;
- a **failed startup self-check**;
- an **R8.6 redaction hit** on the `agent_action_log` relay (the `redacted` count is non-zero).

### An incident starts `t0`. Declaring it is the operator's act.

`t0` is the moment the incident is declared — not the moment the signal was produced, and not the
moment the console button is pressed (Decision 2).

An incident is any of:

1. a **deny not explained by a known policy gap**;
2. an attempt against the **metadata endpoint**, an **RFC1918** address, or a **refused DNS name**
   that no allowed workflow produces;
3. a **cross-binding identity attempt** — an agent presenting another agent's identity material;
4. **DRIFT on an MCP server the operator did not change**;
5. an **action-log line showing a classified action attempted** (R12.7 / T37);
6. a **credential value found in a transcript** beyond what R8.6 already records as known
   (`docs/records/credential-inventory.md` § R8.6, rows P1–P4);
7. a **write to a capability-declaration file** — a pack manifest's `enables_actions`, a profile's
   `authorization` block, or the MCP inventory.

**Confirmed by the operator 2026-09-29** (review assumption 2), as drafted from the plan's text —
nothing added, nothing struck. The R8.6 redaction hit was weighed for promotion to an incident and
deliberately left an **event**: incident item 6 already covers a credential value reaching a
transcript, and the redaction hit is the relay-side signal for the same condition, so promoting it
would make every relay-side catch an incident while the sink-side finding stays triage. SF-7 may
still revise this list before go-live.

**What R13.1 does not bound.** R13.1 bounds **detection to revocation**. It does not bound
**compromise to detection**, which is unbounded while detection is pull-based. Nothing in this
runbook changes that, and no maximum below should be read as covering it.

---

## 2. First rule: preserve evidence

**Never `docker compose down -v`. Never `docker volume prune`.**

`down -v` destroys the `audit` volume and the three action-audit volumes — the entire record of what
the agent did. R12.5's teardown is `down` **without** `-v`, which removes containers, the `tmpfs`
mounts (`/tmp`, `/run`) and the networks, and preserves every named volume.

**MEASURED 2026-09-30** (SF-3 phase D, and its negative control). `down` kept all seven named
volumes and every marker on a state volume, and the audit trail did not shrink. The same state under
`down -v` lost all seven volumes, every state marker, and took the audit trail from 46 lines to 2.
That 46 → 2 is the concrete cost this rule exists to prevent.

The discard in § 5 is **selective**: `docker volume rm` of the named state volumes only, by name,
after `down`.

A container kept for forensics is more useful than a container restarted. Prefer the **disconnect**
form (§ 3.2) over `stop` when the question is still "what did it do".

---

## 3. The five containment actions

Chosen so that containment **keeps the detection signal alive** (Decision 3): the blocked attempt is
the detection signal (R9.1), so the live forms leave DNS, policy and the audit writer running.

### 3.1 Cut egress, whole pod

**Live form** — **MEASURED 2026-09-30** (SF-3 phase C; `docs/records/containment-drills.md` § The pod-wide cut):

```bash
docker network disconnect sandboxed-agent-pod_egress-net sandboxed-agent-pod-egress-mediator-1
```

- **Expected result.** Every agent's allowed request now fails upstream, and the mediator stays
  `running` — measured for all three agents. **Attempts stay visible**, which is the property this
  form is chosen for (Edge Case 8): the policy decision is unchanged, so the audit line reads
  `"verdict":"allow"` with `"http_status":503`, `bytes_out: 0` and `bytes_in: 0`. Read the 503 and the
  zero byte counts, not the verdict — the request was accepted, attributed and evaluated, and then
  had nowhere to go.
- **Measured refinement of the DNS expectation.** Edge Case 8 expected the failure to surface as a
  `SERVFAIL` from unbound's dead upstream. With the name already in unbound's cache — the normal case,
  since a cut follows traffic — no query leaves the mediator at all, `dns-audit.log` stays silent for
  that name, and the attempt fails at the TCP leg instead. Either way the attempt is on
  `egress-audit.log`. **Look there first, not at `dns-audit.log`.**
- **Confirm it.** From any agent, an allowed request fails; a line for that attempt still reaches the
  audit sink. Re-attach and the same request succeeds — note that the reattach gives the mediator a
  **dynamically assigned** `egress-net` address rather than the one it had, which nothing depends on
  but which makes the reattach an approximate, not exact, restoration:

```bash
docker network connect sandboxed-agent-pod_egress-net sandboxed-agent-pod-egress-mediator-1
```

**Durable form.** Edit the allowlist or add a denylist entry, then
`bash scripts/compile-policy-build.sh` and `docker compose up --build --force-recreate`. The policy
is baked into the mediator image and there is **no live reload** (D4), so a policy edit is a rebuild,
not a live action.

**Last resort.** `docker compose stop egress-mediator` cuts everything — and it also **stops the
recording**. Use it only when the recording is worth less than the cut.

### 3.2 Cut egress from one agent / isolate one agent

**Live form, container kept for forensics** — **MEASURED 2026-09-30** (SF-3 phase B, disconnect form; `docs/records/containment-drills.md` § T40):

```bash
docker network disconnect sandboxed-agent-pod_claude-net sandboxed-agent-pod-claude-1
```

(substitute `codex` / `agy` and their `<agent>-net`)

- **Expected result.** The agent has no route to anything — it is on that one network only. Measured
  for all three agents: the probe returns
  `curl: (7) Failed to connect to 172.31.<10|20|30>.2 port 3128 after 0 ms`. The container keeps
  running and its filesystem and process state are intact. The other two agents are unaffected, and
  the mediator keeps serving — **measured, not assumed**: it reads `MEDIATOR_AGENT_NETWORKS` **at
  start only**, so detaching an *agent* leaves it untouched.
- **Take the forensic note BEFORE reconnecting.** Reconnect allocates the agent a **fresh** address
  from the network's `ip_range` (measured: `claude` returned on `172.31.10.129`), so anything that
  records "the container's address" must be captured while it is detached.
- **Confirm it.** The isolated agent cannot reach the mediator. The other two still complete an
  allowed request and each still produces a fresh egress line. Reconnect restores the agent:

```bash
docker network connect sandboxed-agent-pod_claude-net sandboxed-agent-pod-claude-1
```

> **Do not detach the mediator from a single agent's network.** The mediator validates its network
> set at start only, so the effect of removing one is untested. It is recorded as untested rather
> than recommended (Edge Case 7).

**Durable form — stop, and the order matters** (Edge Case 9):

```bash
docker compose stop claude          # the agent first
# wait for its recorder to drain (RECORDER_POLL_SECONDS)
docker compose stop claude-recorder # the recorder second
```

Stopping the **agent first** and letting the recorder drain keeps the tail of the transcript in the
sink. Stopping the recorder first loses it.

- **Expected result — MEASURED 2026-09-30** (SF-3 phase B, stop form). The agent and its recorder are
  `exited`; the other two agents are `running`, their requests are still allowed, and their egress
  lines still reach the sink. Measured for all three agents.
- **Confirm it.** `docker compose ps`, then `docker compose start claude claude-recorder` — the
  agent restarts cleanly and reaches the mediator again. Measured for all three.

### 3.3 Disable one MCP server

**There is no live form.** This is recorded, not worked around, and it is the substance of the
**R13.2/T40 amendment** (Decision 4). The amendment text is carried in
`docs/records/containment-drills.md`; **R13.2 stays formally unmet until the operator accepts it**,
and the milestone Definition of Done gates on that.

**Durable form — MEASURED 2026-09-30** (SF-4; `docs/records/containment-drills.md` § MCP-disable
exercise):

1. remove the server from the profile's `mcp:` list and recompile;
2. remove the corresponding entry from the agent's own config **on its state volume** — that file is
   inside the blast radius (R1.2), and without this step `mcp-gate` refuses the agent at its next
   start (exit 3, measured);
3. rebuild and recreate every agent that loads it:

```bash
docker compose up --build --force-recreate claude   # narrower than recreating the whole pod
```

> **Step 2 must be done from OUTSIDE the agent.** `docker compose exec`/`run` into the refused agent
> and editing the file **does not work**: `images/entrypoint.sh` runs `mcp-gate` *before* it execs
> anything you asked for, so a refused gate exits 3 and your edit never runs. Measured at SF-4. Use
> a helper container that mounts the state volume directly, built on **that agent's own image** —
> the volume is owned by that image's runtime uid, and a container on a different base is refused at
> the filesystem:
>
> ```bash
> docker run --rm -v sandboxed-agent-pod_codex-state:/s --entrypoint sh sandboxed-agent/codex:local \
>   -c 'sed -i "/mcp_servers.<name>/,+1d" /s/.codex/config.toml'
> ```

The inventory is **image content** (02.3 Decision 8), so this path requires a rebuild. The canonical
`up --build --force-recreate` with no service argument recreates **every** service, the mediator
included; naming the affected agents narrows it to a restart of those agents.

A compromised agent that re-adds the config entry meets the gate at its next start and **does not
start**. That is containment-safe — measured at SF-4, twice: once by re-adding the entry directly,
and once as the side effect of recovering a contaminated pod without discarding its state volume.

### 3.4 Rotate credentials

Per inventory row, against that row's stated maximum — see § 4. Two rules override convenience:

- **Discarding is not revoking** (Decision 5). Removing a credential from a volume removes the
  container's copy, not the provider's grant. A copy of the volume may already have left. Every
  discard in § 5 therefore **chains the revocation procedure** for every credential the contaminated
  agent held.
- **No rebuild** (R8.5, MUST). Every revocation and the re-issue that follows it completes without an
  image rebuild. Recreating a container is permitted and is **not** a rebuild. Confirm by comparing
  each service's image ID before and after:

```bash
docker compose images --quiet   # before t0 and after re-issue; the IDs must be equal
```

**One special case: a proxy credential survives until the mediator restarts** (Edge Case 5).
`basic_ncsa_auth` caches credentials, so a revoked `codex` or `agy` proxy credential still works
until `docker compose restart egress-mediator`. The restart is **part of the procedure**, not an
afterthought, and `t1` is measured after it. **Measured at 02.5 SF-5:** immediately after
`issue-identity.sh credential <agent> --force`, and before the restart, the revoked credential still
returned `verdict=allow` for both `codex` and `agy`.

**After the restart, wait for the proxy to answer before you conclude anything.** A replay that
fails while Squid is still binding its listeners returns *failed to connect* and leaves **no line on
the audit trail** — indistinguishable from a successful revocation. Confirm the proxy is serving
(one request with the **new** credential) and only then replay the old one. A revocation confirmed
against a not-yet-listening proxy is not confirmed (02.5 SF-5, attempt 1).

**How a replaced `file:` secret reaches a container** (Edge Case 4, measured at 02.5 SF-5). Write
**in place** — which is what `issue-identity.sh` does (`> "$cred"`, and `cp` for the htpasswd). The
running container then sees the new content with no restart at all. Do **not** replace the file with
`mv`, and do not edit it with an editor that saves by rename: the mount breaks rather than going
stale — `stat` inside the container still reports the old inode and size, while a read fails with
`No such file or directory`. It fails closed (the agent is refused with a 407), but the healthy-
looking `stat` will mislead you. Recreating the agent is still required for a **proxy credential**,
because the value is spliced into `HTTPS_PROXY` at the entrypoint, not re-read per request.

### 3.5 Return to known-good

See § 5. It is durable-only; there is no live form.

---

## 4. The revocation index

One line per inventory row. The procedure itself lives in `docs/records/credential-inventory.md`
Table B — this index exists so that an incident does not begin with a search.

**Stated maxima are commitments made before the drills, not numbers derived from them**
(Decision 2). **Confirmed by the operator 2026-09-29** (review assumption 1). SF-5 drills the
pod-local and pack rows (S1–S5) and SF-6 the provider rows (E1–E4, V1–V3); each must come in under
the value below, and a row that cannot is recorded as a named gap rather than having its maximum
moved to fit.

| Row | Credential | Procedure | Stated maximum |
|---|---|---|---|
| E1 | `claude` Anthropic API key | Anthropic Console → API keys → revoke | **15:00** |
| E2 | `codex` OpenAI API key | OpenAI platform → API keys → revoke | **15:00** |
| E3 | `agy` Google API key | Google AI Studio → delete key | **15:00** |
| E4 | `claude` one-year `CLAUDE_CODE_OAUTH_TOKEN` | Revoke at the Anthropic account that minted it. **It is an OAuth grant, not an API key — it is NOT on the API-keys page where E1 lives.** Measured 2026-09-30 (02.5 SF-6): the revoke is **single-grant**, with no account-wide logout and no effect on the operator's own sessions; most of that drill's 04:39 was spent finding the page, and an incident is a worse time to search | **15:00** |
| V1 | `claude` OAuth refresh + 8 h access token | Delete `.credentials.json` from `claude-state` **and** revoke the session at the provider | **10:00** *(containment clock)* |
| V2 | `codex` OAuth refresh + 10-day access token | `codex logout` **and** revoke the session at the provider | **10:00** *(containment clock)* |
| V3 | `codex` OAuth set, host-provenance (`oauth-mount`) | As V2. Rotation is **not** revocation — a captured refresh token stays valid after the legitimate client refreshes past it | **10:00** *(containment clock)* |
| S1 | `claude` mTLS client certificate + key | `bash scripts/issue-identity.sh ca --force`, reissue the three listener certificates and the client certificate, restart the mediator, restart `claude` and `agy` so they take the new CA certificate | **10:00** |
| S2 | `github-token` fine-grained PAT | `https://github.com/settings/personal-access-tokens` → revoke. Rotation is a Compose secret-file swap plus `--force-recreate` | **15:00** |
| S3 | `kubeconfig` context credential | Delete the ServiceAccount token / client certificate at the cluster. Rotation as S2 | **30:00** |
| S4 | `codex` proxy credential (`codex-proxy-credential`) | `bash scripts/issue-identity.sh credential codex --force`, then `docker compose restart egress-mediator` (Edge Case 5). **`--force` is required** — the bare form refuses to overwrite an existing credential (`scripts/issue-identity.sh:72`); corrected 2026-09-30 from the script's own contract, and measured for the `client` case at SF-4. SF-5 measures this one | **10:00** |
| S5 | `agy` proxy credential (`agy-proxy-credential`) | As S4, for `agy` — including `--force` | **10:00** |

**Two clock rules that change what a row's number means:**

- `t1` is a **replay that fails**, not a console click. An operator console action with no replay
  proves nothing (Decision 2).
- **What a failed replay must show, per row.** S4 and S5 produce a deny line naming the agent:
  `verdict=deny, http_status=407, squid=TCP_DENIED`, with `identity_source` degraded from
  `listener+proxy_auth` to `listener`. **S1 does not.** Its rejection happens in the TLS handshake,
  before Squid has a request to log, so the trail carries only
  `{"event":"proxy_internal","detail":"error:transaction-end-before-headers"}` — no agent, no
  destination — and `squid-cache.log` carries nothing at the shipped debug level. For S1, confirm
  revocation from the replay's own client-side failure (`curl` exit 56) **plus** the certificate
  sha256 and serial before and after. Do not look for an S1 refusal on the audit trail; it is not
  there (02.5 SF-5).
- **S2 and S3 leave no mediator-side signal either, for a different reason: the refusal happens at
  the third party.** A revoked pack credential's replay is on the trail as
  `verdict=allow, http_status=200, squid=TCP_TUNNEL` — indistinguishable from a successful request,
  because the mediator does not terminate TLS on this path (D18) and never sees the inner 401.
  Confirm from the replay's own HTTP status, run from inside the agent (S2) or from the host (S3,
  whose credential has no route from the pod at all — the shipped `kubernetes` pack declares
  `egress.runtime: []`). Measured at 02.5 SF-5: **S2 02:21, HTTP 401; S3 00:11, HTTP 401.**
- **Expect a short survival window, and know which one you are in.** Measured at 02.5 SF-5:
  S4/S5 survive until the mediator restarts (Edge Case 5); S3 survived **~10 s** past the
  ServiceAccount delete, in the API server's authentication path, where no operator action shortens
  it; S2 showed **no measurable survival**. Replay until refused — a single replay immediately after
  the revoking action can report a credential still working when it is already revoked.
- For an OAuth row (V1, V2, V3), the **refresh token and the access token are both replayed**, and
  the row's effective time is the **later of the two**. If the access token survives revocation until
  its own expiry, **that survival is the measured time** (Edge Case 2).
- **The V rows' 10:00 is a containment clock, not a provider clock** (operator decision,
  2026-09-29). It bounds the action that actually contains: **isolate the agent (§ 3.2, disconnect)
  and discard its volume at `t0`, *before* revoking.** The access token's survival past revocation
  (V1: 8 h; V2/V3: a 10-day JWT `codex` does not verify locally) is measured by SF-6 and recorded as
  a **named finding against R13.1** — it is not folded into this commitment, and the commitment is
  not widened to 8 h or 10 days to make the row pass.

---

## 5. Return to known-good

The threat model is a **compromised agent** (R13.3, D16). A suspected **mediator** compromise is not
this path — see § 5.4.

**A contaminated volume is indistinguishable from a clean one.** D16 accepts that. This path
therefore **discards without trying to tell**. It does not inspect; it does not diff.

### 5.1 The ordered path

1. **Declare the incident.** `t0`. Record it.
2. **Isolate the contaminated agent** — § 3.2, disconnect form, container kept.
3. **If the agent holds an OAuth credential whose access token may outlive revocation** (V1, V2, V3),
   **discard its volume now, before revoking** — Edge Case 2.
4. **Revoke every credential the agent held** — § 4, chained per § 3.4. Discarding is not revoking.
5. **`docker compose down`** — without `-v`. Never `-v`.
6. **Discard, selectively, by name:**

```bash
docker volume rm sandboxed-agent-pod_claude-state
# plus sandboxed-agent-pod_claude-build-cache if the build-cache fragment is enabled
```

7. **Rebuild from the pinned digest** (the `main`-pinned digest from 02.4) and recreate:

```bash
docker compose up --build --force-recreate
```

   **The whole-pod form is deliberate here**, and it is the one place it is. § 3.3 narrows to
   `--force-recreate <agent>` because disabling one MCP server should not restart the mediator; a
   return-to-known-good wants the opposite — every container replaced from the pinned digest,
   the mediator included, because the question "which containers are clean" is exactly what D16
   says cannot be answered by inspection.

8. **Re-bootstrap authentication** for each agent.
9. **Assert every disposition in § 5.2.**
10. **Run the Test Command.** It must be green.

### 5.2 Disposition table

Every persistent store gets **exactly one** disposition. A new named volume with no row here **fails
the harness** — that is the point: a volume cannot arrive without a stated recovery decision
(Edge Case 11). Names are compared after stripping the `sandboxed-agent-pod_` project prefix.

| Store | Kind | Disposition | Action |
|---|---|---|---|
| `claude-state`, `codex-state`, `agy-state` | Named volume | `discard` | `docker volume rm sandboxed-agent-pod_<name>` after `down` without `-v` |
| `audit` | Named volume, mediator only | `preserve` | Evidence. No agent service mounts it (D12) |
| `claude-action-audit`, `codex-action-audit`, `agy-action-audit` | Named volume, recorder only (02.1) | `preserve` | Evidence. Exactly one mounter each: that agent's own recorder |
| `claude-build-cache`, `codex-build-cache`, `agy-build-cache` | Named volume, agent-writable (`compose/overrides/build-cache.yaml`, opt-in) | `discard` | As the state volumes |
| project mount (`workspace/`, or the profile's path) | Host bind | `review` | The operator reviews it with `git status` and `git diff` and removes untracked content. **It is never discarded by this path** |
| `compose/generated/` | Host staging, `:ro` in the agents | `rotate` | Kept, but every pack credential staged there that the agent held is revoked and re-staged per § 3.4 |
| `mediator/identity/` | Host | `rotate` | The contaminated agent's own client key (S1) or proxy credential (S4/S5) is re-issued. **The CA is untouched** — no agent ever held its private key. The commands are `bash scripts/issue-identity.sh client <agent> --force` and `bash scripts/issue-identity.sh credential <agent> --force`; **`--force` is required and its absence is a hard refusal**, measured at SF-4 — see the note below |

> **`--force` is not optional, and its absence is silent about what it cost you.** Measured at
> SF-4: `bash scripts/issue-identity.sh client claude` with an existing certificate exits non-zero
> with `already exists. Re-issue it with: ... --force` and rotates **nothing**. Run mid-recovery,
> in sequence with commands that do not fail, that refusal is easy to step past — and the pod comes
> back up on the **same** identity material the contaminated agent held. Check it:
>
> ```bash
> shasum -a 256 mediator/identity/clients/<agent>-client.crt   # before and after; it MUST change
> shasum -a 256 mediator/identity/ca/mediator-ca.crt           # before and after; it MUST NOT
> ```
>
> Rotate **before** the `up --build --force-recreate` in § 5.1, so the recreated container takes the
> new material in the same step.

**Why the project mount is reviewed and not discarded** (Edge Case 12). It is host content and the
operator's own repository, and an agent can write there by design (R2.1). This path does not return
it to known-good, and it says so rather than pretending otherwise. `workspace/` also stays **outside
the build context** — the deny-all `.dockerignore` never admits it — which is what makes step 7's
rebuild safe against workspace contamination (Decision 5).

### 5.3 After recovery, assert

- **no marker remains** in any discarded volume;
- the `audit` and three action-audit volumes still hold their **pre-recovery lines, unchanged**;
- the recorder **resumes on the fresh volume without duplicating lines** — a fresh state volume
  carries no transcript directory, and the recorder is stated to survive that (Edge Case 10);
- each agent **re-bootstraps** authentication;
- the **Test Command is green**.

### 5.4 Suspected mediator compromise — not this path, and not drilled

Outside T41's threat model (Edge Case 13). If the mediator itself is suspected: **rebuild the
mediator, reissue the CA and every certificate, and rotate every proxy credential** (S1, S4, S5).
This is recorded here so an incident does not begin with a search. It is **not drilled** by this
feature.

---

## 6. After the incident

### The R9.6 review trigger (handed over by Feature 02.1)

Detection is **pull-based**. Nothing pushes an alert, so review is an operator action. The trigger
for building a push path — a SIEM or alerting pipeline, R9.6's MAY — is:

> **a blocked attempt going unnoticed long enough to matter.**

Until then, R9.6 stays MAY and the unbounded compromise-to-detection interval named in § 1 stands
as a recorded residual, not a solved problem.

A second review trigger, from Decision 6: **a provider terms change discovered after the fact**
is the trigger for building a terms-page monitor. Both are reviewed at the cadence below.

### Drill cadence

> **OPERATOR-CONFIRM.** The cadence for re-running the T26 revocation drills and the T41
> return-to-known-good drill is set at SF-7, alongside the R14.3 review cadence (review
> assumption 5).

Every drill result — with its `t0`, its `t1`, its measured time and its image-ID comparison — is
recorded in `docs/records/containment-drills.md` per that record's template.
