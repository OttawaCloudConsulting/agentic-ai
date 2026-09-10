# Feature Plan: Audit completeness — agent action log, sink and exports

**Milestone:** 02 - Proven and Composable
**Feature:** 02.1: Audit completeness — agent action log, sink and exports
**Status:** Planned
**Date:** 2026-09-10

## Summary

Milestone 01 built the egress half of the audit trail: one JSON object per connection attempt, on
the `audit` volume, which only the mediator mounts, with the agent's identity on every verdict line
since 01.6. This feature builds the half no network control can produce. R9.7 (MUST) needs tool
invocations, file modifications and privilege changes recorded outside the agent's blast radius.
D20 settled the only available source: each agent's own session transcript, shipped off-container
in real time so that a later edit on the volume cannot reach the copy. The feature adds an **agent
action recorder** and the **action half of the audit sink**. It makes the two trails correlatable
by agent, session and timestamp (T35). It wires the four export toggles every profile already
declares, which nothing reads today, so that disabling an export never disables recording (T36).
It checks the shipped transcripts for credential values (R8.6). It ships ahead of 02.2 because
R12.8's blocked / logged / attributable record needs two parts that only this feature supplies.
T16 is recorded in 02.2's run, not here.

## Acceptance Criteria

1. **Each agent's transcript source is measured before anything is built on it.** Nothing in the
   repo records transcript paths yet: a scan for `jsonl`, `projects/`, `sessions/`, `rollout` and
   `sessionId` finds nothing, and `images/agy/agy-run.sh:7-12` marks the `agy` JSON shape
   UNVERIFIED. For each agent, record in `docs/records/agent-action-log.md`:
   - the on-volume path;
   - the write model: append-only JSONL, whole-file rewrite, or stdout only;
   - where the session identifier lives;
   - file owner and mode;
   - whether a deliberate `printenv` tool call puts a credential value into the transcript.

   The criterion is that each result is recorded. Any particular result is acceptable, and this
   plan says what gets built on each branch.
2. **The agent action recorder ships each agent's native transcript to the sink in real time,
   append-only** (R9.7, D20). "Real time" has a stated bound: one poll interval. The recorder
   reads the agent's state volume **read-only**. It writes only to its own sink volume and its own
   stdout, and it has **no network**. It never writes a path any agent container can reach.
3. **The audit sink is two trails, and both sit outside every agent's reach** (R9.2, D12).
   - The egress trail is unchanged: the `audit` volume, mounted by the mediator alone.
   - The action trail is new: one recorder-owned volume per agent.
   - No agent service mounts either trail. The harness checks this in two ways. It enumerates the
     rendered Compose config, and it probes each trail's path from inside each agent container.
     The second check extends T8's existing reach check at `verify-egress-mediator.sh:964-969` to
     the new volumes.
4. **T35 passes.** In a session, one tool invocation and one file modification both appear in the
   action trail. Each action line carries three things:
   - `agent`: the resolved-policy `identity` token. This is the same token the egress `agent` field
     carries (01.6 Decision 2).
   - `identity_source: "state_volume"`.
   - `session_id`.

   A join on agent, session and recorder-clock window returns the egress lines that session
   produced, and no line from any other agent. After shipping, an edit to the on-volume transcript
   does **not** reach the sink. That is tamper-evidence, the property D20 claims, not
   tamper-resistance.
5. **R9.7's privilege-change limb is covered by a recorded structural finding, with evidence from
   inside each agent container.** The harness asserts, per agent:
   - uid 1000;
   - `CapEff: 0000000000000000`;
   - `NoNewPrivs: 1`;
   - a setuid-binary escalation attempt fails.

   The finding is that no privilege-change event is reachable (D15). The criterion is the finding
   plus the evidence behind it, not an event line.
6. **D20's limitation is stated in the shipped documentation.** The agent writes its own
   transcript, so the record is complete as written and tamper-evident. A compromised agent can
   write a false line before it ships. This feature states that limitation. Closing it is out of
   scope.
7. **Each of the four exports can be disabled on its own, and recording continues in every case**
   (R9.9, D11, T36):
   - Every export has exactly one defined channel.
   - Disabling an export stops that channel and nothing else.
   - At start the mediator writes one `export_config` event into the egress trail, recording the
     state of all four toggles.
   - T36 runs as the register states it: each export disabled in turn.
8. **R8.6: the sink is scanned for credential values.** The scan looks for the literal proxy
   passwords of `codex` and `agy`, the proxy-URL userinfo pattern, and known provider token
   prefixes. Any leak is recorded in `docs/records/credential-inventory.md` together with its
   mitigation.
9. **Detection stays pull-based by decision.** R9.6 push alerting is not built. The runbook
   records the review trigger: a blocked attempt that goes unnoticed long enough to matter.
10. **The existing harnesses stay green.** The recorder services, the new volumes, the profile
    schema change and the mediator relay change each break assertions shipped in Milestone 01. The
    feature closes on the composite Test Command, not on its own harness alone.

## Approach

### The starting position

The codebase scan established these facts. The design follows from them.

- **No session identifier exists anywhere.** Egress, DNS and event lines carry `ts`, `agent`,
  `identity_source` and destination fields, and nothing that names a session
  (`images/mediator/audit-writer.sh:159,168`; `mediator/config/resolver-policy.conf.tmpl:108`).
  TLS is spliced (D4), so the mediator cannot see a session header inside the tunnel. **The egress
  trail cannot carry a session id, and this feature does not try to add one.**
- **The export toggles are declared and inert.** All four profiles carry `exports:` with four
  booleans (`profiles/default.yaml:204-208`, and the equivalent block in the other three).
  `scripts/compile-policy.sh` accepts the key and drops it, and `policy/resolved/*.yaml` has no
  `exports` key. Nothing consumes the toggles, which is why the drift gate has never noticed them.
- **The mediator already has D12's two sinks.** `entrypoint.sh:992-994` relays `egress-audit.log`
  and `dns-audit.log` to stdout with `tail -n 0 -F`, and `squid-cache.log` to stderr. The
  fail-closed supervisor at `:1266-1271` takes the mediator down if a relay dies.
- **State volumes are strictly per-agent, and a harness asserts it literally.**
  `verify-pod-topology.sh:110-130` fails if any named volume is mounted by two services. Its own
  comment (`:105-109`) gives the reason: sharing a state volume "would put one agent's OAuth
  refresh token inside another's blast radius".
- **Agent homes are private to uid 1000.** Each is `chown agent:agent && chmod 700`
  (`images/Dockerfile:117-122`), with `user: "1000:1000"` (`compose.yaml:146-155`). Any process
  that reads a transcript must run as uid 1000.
- **Agent containers exit immediately.** Each image's `CMD` is `--version`, and real sessions run
  under `docker compose run --rm`. The pod is brought up with `up -d`. No service declares
  `depends_on`.

### Decision 1: one recorder sidecar per agent, with no network and a read-only mount of that agent's state volume

The component inventory already names the shape: the recorder reads the transcript "via the
container logging driver or a sidecar tail" (architecture, Component Inventory). This decision
takes the sidecar and makes it **per-agent**. Four alternatives were rejected:

| Option | Why not |
|---|---|
| One recorder mounting all three state volumes | Puts all three agents' refresh tokens in one container (the recorder must be uid 1000 to read mode-700 homes). The D7 comment names exactly this concentration as the thing it prevents |
| One recorder with volume `subpath` mounts of the transcript directories only | Engine 28.3.2 and Compose 2.38 support `subpath`, but a subpath must exist when the volume is mounted. On a fresh volume (T18 clean rebuild, T41 discard-and-re-bootstrap) the recorder would fail before any agent had created the directory. Nothing in Compose can order "agent populates, then recorder mounts" without a dependency cycle through `run` |
| In-agent shipper that sends lines to the mediator | The shipper runs as the agent's uid inside the agent's container, so a compromised agent can kill it and stop recording silently. It also needs a third mediator port on each agent network, which breaks the "exactly {proxy, resolver}" enumeration the harness sweeps for |
| Docker logging driver on agent stdout | stdout is `stream-json` event output, not the native transcript the acceptance criterion names. `run --rm` also deletes a `json-file` log when the container exits |

With one recorder per agent, no container ever holds two agents' credentials, so D7's rationale
holds exactly. Each recorder has `network_mode: none` and a **read-only** mount of its own agent's
state volume. Its outputs are its sink volume and its stdout. It can read its own agent's
credential, but it has no route to send it anywhere. It processes agent-written content with `jq`,
which is covered in Edge Cases.

**Each agent service gets `depends_on: <agent>-recorder`**, which makes `docker compose run --rm
claude` start the recorder if it is down. This is the first `depends_on` in the pod. Without it,
the documented entry point could start an agent session with nothing recording it in real time.

**What D7's harness check becomes.** The rule "no named volume is mounted by two services" narrows
to two rules:

- No state volume is mounted by two **agent** services.
- A state volume's only other mounter is **its own** recorder, read-only, with `network_mode: none`.

This implements the component inventory row. It is not a design change. It is recorded as a harness
amendment, with the reasoning quoted from the check's own comment.

### Decision 2: the action trail is recorder-owned volumes, one per agent

D12's wording is "inside the mediator or shipped directly off-host". Its operative clause is
"never to a volume an agent container can reach", and the inventory row for the audit sink reads
"written by the mediator (egress) and by the agent-action recorder. Never a volume shared with an
agent container". Having recorders write into the mediator's `audit` volume was rejected. It would
trip the D7 check. It would also need a uid-1000 directory inside a uid-13, mode-750 tree. And it
would create a cross-writer channel into the egress evidence.

Each recorder therefore owns one volume: `claude-action-audit`, `codex-action-audit` and
`agy-action-audit`. One volume per agent, rather than a single shared action volume, stops a
compromised recorder from rewriting another agent's action log. It also keeps the D7 check simple:
no action volume has a second mounter. **The D12 reading is written into the record and into this
plan's Architectural Deviations if `/build` confirms it. The architecture document is not edited
here.**

### Decision 3: shipping by byte offset, complete lines only, with offsets persisted on the sink volume

The recorder polls its source directory once per `RECORDER_POLL_SECONDS`, default 1. For each
transcript file it tracks `(inode, offset)` and appends every newly completed, `\n`-terminated line
to the action log. It never re-reads a range it has already shipped. **That is what makes a
retroactive edit fail to propagate:** the sink keeps the bytes as first shipped.

The tamper-evidence window is the poll interval. An edit made before the next poll is
indistinguishable from an original line, and the record says so.

The offsets live on the recorder's sink volume, not in tmpfs. If they were lost on a recorder
restart, the recorder would re-ship each file from offset 0. That duplicates lines, and it would
also ship a retroactively edited file as fresh content, which blurs the property T35 tests.

Four behaviours pass the correctness floor, because the agent controls the file on a reachable
path:

- **File shrinks** (size < offset): emit `transcript_truncated`, reset to 0, and ship the new
  content as new lines. The lines already shipped stay in the sink.
- **Inode changes** (file replaced by rename): emit `transcript_replaced` and treat the file as new.
- **Line is not valid JSON**: ship it as a string in `record_raw`. The recorder must not crash on
  agent-written input, because a crashed recorder records nothing.
- **Partial trailing line**: hold it back until its `\n` arrives.

On first start, when there is no offsets file, any existing transcript content is shipped with one
`backfill` event naming the files and sizes. Those lines were not shipped in real time, and the
event keeps anyone from reading them as tamper-evident.

**SF-1 decides the branch for `agy`.** If `agy` writes an append-only on-volume transcript, it uses
the same path as the other two. If it rewrites a whole JSON file per turn, the recorder ships a new
snapshot line whenever the file's `sha256` changes (`record_snapshot`). Each version is kept, and a
retroactive edit shows up as a later snapshot beside the original. If `agy`'s only output is
end-of-run JSON on stdout, then "real time" cannot be met for `agy`. In that case `agy-run.sh`
(already the wrapper) tees its stdout to a file on `agy-state`, the recorder tails that file, and
the limitation is recorded: one record per run, shipped at run end. This last branch is itself a
design choice and is surfaced at SF-1 close.

### Decision 4: correlation joins on agent and a recorder-clock window, not on a shared session id

The action line carries `session_id`, taken from the transcript file name, or from the first line
where SF-1 finds that is where the id lives. The egress line carries `agent` and `ts`. The join has
three steps:

1. Choose a `session_id`.
2. Take that session's window: `[min(ts), max(ts)]` over its action lines, using the **recorder's**
   `ts`.
3. Select the egress and DNS lines where `agent` matches and `ts` falls in the window widened by
   the slack.

Two correctness points:

- **The window uses the recorder's clock, never the agent's timestamps.** The agent writes its own
  transcript (D20), so a timestamp it wrote is a claim. The recorder and the mediator run on the
  same Docker Desktop VM kernel clock.
- **Slack is at least 1 s plus the poll interval.** DNS lines have whole-second timestamps
  (`resolver-policy.conf.tmpl:108`), egress lines have millisecond timestamps, and a shipped line
  is up to one poll interval later than the action it records.

**Stated limitation:** two concurrent `run --rm` sessions of the **same** agent share one listener
and one identity, so the egress trail cannot separate them. Single-operator scope makes this rare.
It is recorded, not engineered around.

The join is a documented `jq` recipe in the README and a function in the harness. No separate
correlation script is shipped. R9.8 asks for the trails to be correlatable, and T35 demonstrates
it. An operator tool beyond the recipe has no requirement behind it.

### Decision 5: the action line attributes structurally, and says so in its own token

`agent` is read from the resolved artifact's `.agents.<agent>.identity`: one token across issuance,
policy, enforcement, egress audit and now action audit (01.6 Decision 2). The milestone README says
the identity was "issued in 01.3". The token is R8.8's, and the mechanism landed in 01.6.

`identity_source` on an action line is `state_volume`, a new value that is deliberately not one of
the three `listener*` forms. The attribution is **structural**: the narrowed D7 check asserts the
volume is mounted into exactly one agent service. It is weaker than `listener+mtls`, and the token
means it can never be read as a cryptographic attribution. Identity binds a connection to an agent,
not a transcript line to one. That stays in Controls This Architecture Does Not Provide.

### Decision 6: each export has one channel; toggles reach the pod through the resolved artifact

| Export | Channel (produced by default) | Toggle read by | When disabled |
|---|---|---|---|
| `egress_audit_log` | Mediator stdout relay of `egress-audit.log` and `dns-audit.log` (D12's second sink) | `images/mediator/entrypoint.sh` | Those two relays are not started. The supervisor does not expect them. `squid-cache.log` → stderr is diagnostics, not an export, and stays |
| `agent_action_log` | Each recorder's stdout relay of its action log | `recorder.sh` | The relay is not started |
| `resolved_policy` | Copy to `exports/<profile>/resolved-policy.yaml` | `scripts/export-artifacts.sh`, called at the end of `scripts/build.sh` | Not copied. The `MANIFEST` line says `disabled` |
| `image_digest_sbom` | Copy of the build record (`.build-scratch/build/<profile>.images.txt`) plus any SBOM that exists, to `exports/<profile>/` | same | same |

**The stdout relays are the log exports**, because they are the only path by which either log
leaves the pod for outside consumption (`docker compose logs`, and any logging driver R9.6 might
ship through). A toggle that disabled some other copy while the relay kept streaming would have no
effect. **Recording is unaffected by construction.** The audit writer's FIFO → volume append and
the recorder's volume append do not read the toggle, so no profile setting can reach them (D11).
The fail-closed supervisor is changed so that a relay which is disabled by config is **absent**,
not dead. The writer and the non-export relay stay supervised exactly as before.

**Toggles reach the pod through the resolved artifact.** The compiler emits `exports` into
`policy/resolved/<profile>.yaml`. A missing block resolves to all four `true`, emitted explicitly.
An unknown key or a non-boolean exits 2, and `--validate` requires the block. The mediator reads it
from its baked artifact. Recorders read the same artifact through a Compose `configs:` mount, so
there is a single source. **All three committed resolved artifacts (`default`, `test-fixtures`,
`test-selfcheck`) are recompiled in the same commit.** That is 01.6 Deviation 3's standing property, and the drift gate exits 4 otherwise.

**It is recorded in the sink.** At startup the mediator writes one
`{"event":"export_config",...}` line into `egress-audit.log`, listing all four states. The line
does not depend on any toggle, so the record exists whatever is disabled.

The image-digest export ships what exists. Today that is a local image ID, plus digest and SBOM for
the CI-published base only (`prd.md` § Outputs, "Partial"). A complete SBOM and provenance
verification are 02.4 (T45).

### Decision 7: T36 runs in turn, against scratch-compiled variants, without committed test profiles

The register's method is "disable each of the four exports in turn". Four committed test profiles
would each need a committed resolved artifact, recompiled on every future compiler change. That is
the recompile burden 01.6 Deviation 3 describes.

Instead the harness does four things:

1. Derives four variants of `default`, each with exactly one toggle `false`, under
   `.build-scratch/t36/`.
2. Compiles each with the real compiler.
3. Mounts the variant, through `compose/overrides/test-exports.yaml`, over the mediator's baked
   policy path and the recorders' `configs:` source. The mediator still runs `--validate` against
   it at start.
4. Runs `export-artifacts.sh` against the same variant.

**SF-1 measures whether the compiler can compile a profile from outside `profiles/`.** Today
`--profile` takes a name. If it cannot, the fallback is a narrow `--profile-file PATH` flag,
recorded as a compiler interface change. The fallback is not four committed profiles, and not
amending T36's method.

### Decision 8: R8.6 mitigation default is a faithful sink with redaction on the export channel only

SF-1's `printenv HTTPS_PROXY` probe is expected to show that a transcript captures whatever a tool
call prints. `images/entrypoint.sh:134` puts the plaintext proxy password in `HTTPS_PROXY` for
`codex` and `agy`.

If it does, the default mitigation keeps the **sink faithful**. The sink is outside the blast
radius and holds nothing the agent's own volume did not already hold. **Redaction applies only on
the `agent_action_log` stdout relay**, where the value would leave the host. The redaction patterns
are proxy-URL userinfo and known token prefixes. Each redacted line carries a `redacted` count.
This keeps T35's byte comparison exact and keeps credential values out of any off-host consumer.

The alternative is to redact in the sink. The sink would then no longer match the transcript as
written, and every tamper-evidence comparison would have to compare redacted forms. The finding
and the chosen mitigation are recorded together.

### Decision 9: the regression surface is scheduled, not discovered

Following 01.6 Decision 8, these known breakages are fixed in the SF that causes them:

| Breaks | Cause | SF |
|---|---|---|
| `verify-pod-topology.sh:110-130` D7 exclusivity | Recorders mount state volumes | SF-2 (narrowed per Decision 1) |
| Any harness that enumerates services and expects exactly four | Three new services | SF-2 (grep `services` enumerations in all harnesses first) |
| `verify-pod-topology.sh:281-283` agent mount sets | Should **not** break, because agent mounts are unchanged. Asserted rather than assumed | SF-2 |
| `verify-egress-mediator.sh:964-969` T8 reach | Extended to the three action volumes | SF-2 |
| Drift gate on three resolved artifacts | `exports` emitted | SF-4 (same commit) |
| Mediator fail-closed supervisor | Relay may be absent by config | SF-4 |
| `verify-egress-mediator.sh` Phase G whole-sink schema | New `export_config` event line | SF-4 (it is an event, with `event` and no `verdict`, so Phase G should accept it; assert rather than assume) |

## Sub-Features

- [ ] **SF-1: Transcript source verification.** Observations, not assertions, following 01.6 SF-1's
  disposition. Run one real session per agent against the operator's existing authenticated
  volumes. This spends model tokens but no login. Each session makes one tool call, one file edit
  and a `printenv HTTPS_PROXY` probe. Record, per agent: transcript path, write model, session-id
  location, owner and mode, and whether the probe's value landed in the transcript. Also measure
  two things: that a `read_only`, uid-1000, `network_mode: none` container can mount a state
  volume read-only and read the transcript; and whether `compile-policy.sh` can compile a profile
  from outside `profiles/`. Output: `docs/records/agent-action-log.md`. **Closes with the `agy`
  branch decision (Decision 3) surfaced to the operator.**
- [ ] **SF-2: Recorder and action sink.** Build `images/recorder/Dockerfile` on the mediator's
  pinned base digest, adding only pinned `jq`. Write `images/recorder/recorder.sh` (Decision 3
  shipping; per-agent source spec from SF-1). Add three `<agent>-recorder` services on the
  `x-hardened` anchor with `network_mode: none`, three `<agent>-action-audit` volumes, a `configs:`
  mount of the resolved artifact, and `depends_on` from each agent to its recorder. Harness
  changes: narrow the D7 check and add recorder posture assertions (read-only state mount, no
  network, sink volume not mounted elsewhere); extend T8 to the action volumes. Composite green.
- [ ] **SF-3: T35, correlation and the privilege-change limb.** New
  `tests/acceptance/verify-audit-completeness.sh` in the house idiom. Phases:
  - A: recorder mechanics, driven by synthetic native-format appends made from inside the agent
    container (complete, partial, invalid JSON, truncate, replace).
  - B: T35 correlation, with a synthetic action line and a real egress request in the same window;
    another agent's traffic must be excluded.
  - C: retroactive edit, then byte-compare the sink against the volume.
  - D: the privilege-change structural evidence, per agent.
  - L: one live session per agent, gated by `AUDIT_LIVE_SESSION=1` following the
    `AUTH_SKIP_PHASE_D` precedent. The operator runs it once at SF close and records it.
  Add the README `jq` join recipe.
- [ ] **SF-4: Exports and T36.** Compiler: emit and validate `exports`, then recompile all three
  resolved artifacts in the same commit. Mediator: relay gating, the `export_config` event and the
  supervisor change. Recorder: relay gating. Add `scripts/export-artifacts.sh` and call it from
  `build.sh`. Add `compose/overrides/test-exports.yaml`. Harness phase E: four variants in turn,
  each asserting that recording continues, the disabled channel is absent, the other three are
  present, and `export_config` names the disabled export. Add `exports/` to `.gitignore`.
- [ ] **SF-5: R8.6, documentation and close.** Harness phase F: scan every action volume for the
  literal proxy passwords (read from the Compose secret files), the userinfo pattern and the token
  prefixes. Apply the mitigation that SF-1's finding selects (Decision 8 default: redaction on the
  export relay). Record the finding and mitigation in `credential-inventory.md`. README audit
  section: sink layout, D20 limitation, R9.6 pull-based review trigger, R4.10 retention for the
  action volumes and `exports/`. Finalize the record. Composite plus the one-off live phase green.

**Sizing.** SF-2 is the largest: a new image, a new script, three services, three volumes and two
harness amendments. It sits within one session because the recorder is a small poll loop and the
compose change repeats through an anchor. SF-4 is second, because it touches the compiler, three
artifacts, the mediator entrypoint's supervisor, the recorder and the exporter. **Named split if
SF-4 runs long:** SF-4a (compiler, recompile, mediator gating, event) and SF-4b (recorder gating,
exporter, T36 harness). No sub-feature is flagged `[OVERSIZED]`.

## Interface Contracts

### 1. Action-log line: one JSON object per line on `/var/log/actions/action-audit.log`

A record line has a `record`, `record_raw` or `record_snapshot` key and never an `event` key. An
event line is the reverse. This is the same discipline Phase G enforces between `verdict` and
`event` on the egress trail.

```json
{"ts":"2026-09-10T14:03:07.412Z","agent":"claude","identity_source":"state_volume",
 "session_id":"<id per SF-1>","source":"<path relative to the agent home>",
 "offset":18234,"length":912,"line_sha256":"<hex>","record":{ ...transcript line verbatim... }}
```

- `ts`: the recorder's clock at ship time, UTC, milliseconds. It matches the egress `ts` format.
- `record_raw` (string) replaces `record` when the line is not valid JSON.
- `record_snapshot` replaces `record` on the whole-file branch only (Decision 3).
- `session_id` is `null` when the source cannot yield one. SF-1 records any such case.
- Event values:
  - `recorder_start`: `{agent, poll_seconds, first_run}`
  - `backfill`: `{files:[{source,size}]}`
  - `transcript_truncated`: `{source, old_offset, new_size}`
  - `transcript_replaced`: `{source, old_inode, new_inode}`
  - `recorder_error`: `{detail}`

### 2. Recorder service configuration (per `<agent>-recorder`)

| Env | Value | Source |
|---|---|---|
| `RECORDER_AGENT` | `claude` \| `codex` \| `agy` | compose |
| `RECORDER_SOURCE_GLOB` | Transcript glob under `/src`, the read-only state mount | SF-1 record |
| `RECORDER_SESSION_ID` | `filename:<regex>` or `line1:<jq path>` | SF-1 record |
| `RECORDER_MODE` | `append` \| `snapshot` | SF-1 record (`agy` branch) |
| `RECORDER_POLL_SECONDS` | `1` | default |

`agent` in each line is read from `/etc/recorder/resolved.yaml` `.agents.$RECORDER_AGENT.identity`.
The recorder exits non-zero at start if that value is missing. The same file supplies
`.exports.agent_action_log`.

### 3. Compose: recorder service shape (one per agent, via an anchor)

```yaml
claude-recorder:
  <<: *hardened                   # user 1000:1000, cap_drop ALL, no-new-privileges, read_only, tmpfs
  image: ${RECORDER_IMAGE}
  network_mode: none
  volumes:
    - claude-state:/src:ro
    - claude-action-audit:/var/log/actions
  configs:
    - source: resolved_policy     # file: ../policy/resolved/${AGENT_PROFILE:-default}.yaml
      target: /etc/recorder/resolved.yaml
  restart: on-failure
claude:
  depends_on: [claude-recorder]
```

### 4. `exports` in the profile and in the resolved artifact

Profile: unchanged from what is already declared. Resolved artifact: a new top-level key, emitted
`LC_ALL=C` sorted:

```yaml
exports:
  agent_action_log: true
  egress_audit_log: true
  image_digest_sbom: true
  resolved_policy: true
```

Compiler rules:

- A missing profile block resolves to all four `true`.
- An unknown key or a non-boolean exits **2**.
- `--validate` requires exactly the four keys.

### 5. `export_config` event: one line in `egress-audit.log` at mediator start, after stage 1

```json
{"ts":"...","event":"export_config","profile":"default",
 "exports":{"agent_action_log":true,"egress_audit_log":false,"image_digest_sbom":true,"resolved_policy":true}}
```

### 6. `scripts/export-artifacts.sh`

```
bash scripts/export-artifacts.sh --resolved PATH --out DIR
```

It copies the enabled file artifacts into `DIR` and writes `DIR/MANIFEST`, one line per artifact:
`<export> enabled <sha256> <file>` or `<export> disabled`. Exit codes: 0 ok, 1 usage, 2 unreadable
or invalid resolved artifact. `build.sh` calls it with `--out exports/<profile>` by default.

### 7. D7 check: amended assertion text in `verify-pod-topology.sh`

- `pass "volume exclusivity: no state volume is mounted by two agent services (D7, R4.7)"`
- `pass "recorder posture: <agent>-recorder mounts only <agent>-state (ro) and <agent>-action-audit, network_mode none"`
- `pass "action sink: no <agent>-action-audit volume is mounted by any other service"`

## Edge Cases

| Case | Handling |
|---|---|
| Agent truncates or rewrites its transcript | Decision 3: shipped lines stay in the sink; `transcript_truncated` or `transcript_replaced` event; no corruption |
| Agent edits a shipped range in place (same length) | Not detected by the recorder. The evidence is the sink/volume comparison, which is T35's check. Stated in the record |
| Edit lands before the next poll | Indistinguishable from an original line. The window is one poll interval, stated in the D20 documentation |
| Agent writes non-JSON or very large lines | Non-JSON goes to `record_raw`. Large lines are shipped whole; `jq -c` has no line cap. SF-3 phase A includes a large line |
| Hostile content aimed at the recorder's `jq` parse | The recorder has no network, a read-only source and a read-only rootfs. Its worst case is writing false lines into its own agent's action log, which the agent could already do (D20). Recorded, not mitigated further |
| Recorder down while an agent runs | `depends_on` restarts it on `run`, and `restart: on-failure` covers a crash. Lines written while it was down are shipped late from the persisted offsets. The `recorder_start` event marks the gap. The tamper-evidence window widens for that interval, which is recorded |
| First start over months of Milestone 01 transcripts | `backfill` event, then the history is shipped. Those lines are not claimed as real-time |
| Concurrent same-agent sessions | Egress side not separable (Decision 4). Recorded limitation |
| `session_id` not derivable for an agent | `null`, and the join falls back to agent plus a window taken from that file's line range. Recorded per agent in SF-1 |
| Offsets file lost or corrupt | Treated as a first run: `backfill`, which can duplicate lines. Duplicates carry the same `source`, `offset` and `line_sha256`, so they are detectable. Never silent re-shipping |
| Export disabled, relay absent | The supervisor treats it as configured, not dead (Decision 6). The writer is still supervised |
| `oauth-mount` profile's `exports` block | Never read. `oauth-mount` is a one-shot bootstrap (`compose/overrides/oauth-mount.bootstrap.yaml`) with no committed resolved artifact, and the running pod loads `default`. The compiler still validates the block if the profile is compiled. The README says toggles take effect only in a profile the mediator loads |
| Resolved artifact lacks `exports` (a pre-02.1 artifact) | `--validate` fails at mediator start (T17's path) and the recorder exits non-zero. No silent default |
| `agy` stdout-only branch | One record per run, shipped at run end. Real time is unattainable and recorded (Decision 3) |
| Credential value in a transcript | Faithful in the sink, redacted on the export relay (Decision 8). Recorded in `credential-inventory.md` |
| Action-log contents are plaintext conversation history | R4.10: retention policy documented; `exports/` gitignored; action volumes excluded from backup under the same `tmutil` procedure as state volumes (R8.7) |

## Test Command

```
bash tests/acceptance/verify-pack-composition.sh && bash tests/acceptance/verify-pod-topology.sh && bash tests/acceptance/verify-egress-mediator.sh && bash tests/acceptance/verify-audit-completeness.sh && bash scripts/lint-policy.sh
```

This is 01.6's composite with the new harness added. `verify-audit-completeness.sh` runs phases
A–F unattended with synthetic transcript writes and costs no model tokens. **Phase L** is one live
session per agent, gated by `AUDIT_LIVE_SESSION=1`. It spends model tokens against the operator's
authenticated volumes, so it is left out of the unattended command, run once by the operator at
SF-3 close, and recorded. The same precedent excludes `verify-auth-state.sh`.

Per DD-12 the operator may adjust this at build time without gate re-approval.

## Test Strategy

- **SF-1 records observations with no pass/fail verdicts**, in the disposition of
  `verify-agent-clients.sh` and 01.6 SF-1. A negative is a finding, not a defect.
- **SF-2 through SF-5 assert** in `verify-egress-mediator.sh`'s idiom: `phase`, `pass`, `fail`,
  `note`, `set -uo pipefail`, a private project name, and `trap cleanup EXIT` with
  `down -v --remove-orphans`.
- **Synthetic transcript lines use each agent's native format as SF-1 records it** and are appended
  from inside the agent container as uid 1000. That exercises the real mount, uid and mode path
  rather than a fixture that bypasses them.
- **T35 correlation is asserted in both directions.** The session's egress line is present in the
  join. An egress line from a different agent in the same window is absent.
- **T35 tamper-evidence is a byte comparison.** Take the `line_sha256` of the shipped range, edit
  the volume copy, and confirm the sink's line and hash are unchanged while the volume's differ.
- **T36 per variant**:
  - the egress and action trails both gain lines after traffic (recording continues);
  - the disabled channel is absent (`docker compose logs` shows no relayed lines, or the `MANIFEST`
    line reads `disabled`);
  - the other three channels are present;
  - `export_config` names the disabled export `false`.
- **Privilege-change evidence** is read from `/proc/self/status` inside each agent container, plus
  one setuid attempt that must fail.
- **Regression**: the composite Test Command, plus the Decision 9 table checked row by row.

## Documentation

- `docs/records/agent-action-log.md` (new): SF-1 measurements per agent, the `agy` branch decision,
  the privilege-change structural finding with evidence, the D12 reading (Decision 2), the D20
  limitation and the tamper-evidence window, and the concurrent-session limitation.
- `docs/records/credential-inventory.md`: R8.6 row. Whether transcripts capture credential values,
  from which source, and the mitigation.
- `README.md`: an audit section covering the sink layout (egress trail and action trails), how to
  read each, the correlation `jq` recipe, the four exports and their channels, and what disabling
  one does and does not do. Also: the D20 limitation in plain terms; the runbook note that detection
  is pull-based, with the R9.6 review trigger; and R4.10 retention for the action volumes and
  `exports/`.
- **Not edited here:** `docs/ARCHITECTURE_AND_DESIGN.md`. Its Observability status table ("Agent
  action log: Not built"), the D12 reading and the D7 harness narrowing are carried as
  Architectural Deviations for the milestone's consolidation pass, as 01.5 and 01.6 were.

## Files to Create/Modify

| File | Action | Changes |
|------|--------|---------|
| `images/recorder/Dockerfile` | Create | Mediator's pinned base digest, plus pinned `jq`; `USER 1000:1000` |
| `images/recorder/recorder.sh` | Create | Poll loop: offsets, complete lines, events, relay gating, redaction on relay |
| `compose/compose.yaml` | Modify | Three recorder services, three action-audit volumes, `configs:` resolved policy, agent `depends_on` |
| `compose/pins.env` | Modify | `JQ_VERSION` for the recorder image (if not already implied by the base) |
| `compose/overrides/test-exports.yaml` | Create | Mounts a T36 variant over the mediator policy path and the recorder config |
| `scripts/compile-policy.sh` | Modify | Emit and validate `exports`; `--profile-file` only if SF-1 finds it needed |
| `policy/resolved/{default,test-fixtures,test-selfcheck}.yaml` | Regenerate | `exports` block, same commit as the compiler change |
| `images/mediator/entrypoint.sh` | Modify | Read `exports.egress_audit_log`; gate two relays; supervisor treats an absent relay as configured; `export_config` event |
| `scripts/export-artifacts.sh` | Create | File-artifact exports plus `MANIFEST` |
| `scripts/build.sh` | Modify | Call `export-artifacts.sh`; build the recorder image |
| `images/agy/agy-run.sh` | Modify (conditional) | Tee to `agy-state` only on SF-1's stdout-only branch |
| `tests/acceptance/verify-audit-completeness.sh` | Create | Phases A–F plus gated L |
| `tests/acceptance/verify-pod-topology.sh` | Modify | D7 check narrowed; recorder posture; action sink exclusivity; any service enumeration |
| `tests/acceptance/verify-egress-mediator.sh` | Modify | T8 reach extended to the action volumes; any service enumeration; Phase G checked against `export_config` |
| `.gitignore` | Modify | `exports/` |
| `README.md` | Modify | Audit section (see Documentation) |
| `docs/records/agent-action-log.md` | Create | See Documentation |
| `docs/records/credential-inventory.md` | Modify | R8.6 row |

## Dependencies

- **Milestone 01, complete.** 01.3's `audit` volume and writer; 01.5's compiler, drift gate and
  `build.sh`; 01.6's identity token in the resolved artifact and `identity_source` enumeration;
  01.4's authenticated state volumes, which SF-1 and phase L need.
- **Operator time and model tokens** for SF-1 and phase L: one short session per agent, twice. No
  login is spent.
- **Docker Engine 28.3.2 / Compose 2.38.2**, as installed. Compose `configs:` from `file:` and
  `depends_on` are both long-standing, and `network_mode: none` is standard.
- **Downstream:** 02.2 consumes the sink for T16 and T38's logged and attributable parts. 02.5's
  containment runbook references the recorder (stop an agent and its recorder together) and T41's
  discard step, which must state what happens to the action volumes. That decision belongs to
  02.5, not here.

## Architectural Deviations

(none)
