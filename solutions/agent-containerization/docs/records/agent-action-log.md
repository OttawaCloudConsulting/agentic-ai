# Agent Action Log — 02.1 SF-1 Transcript Source Verification

**Requirement.** Feature plan `audit-completeness-agent-action-log-sink-and-exports.md`, Acceptance
Criterion 1. Measured, not assumed, against one real session per agent run against the operator's
own authenticated state volumes (`sandboxed-agent-pod_claude-state`, `_codex-state`, `_agy-state`).
No login was spent — the operator authenticated `claude` and `codex` via `bootstrap-auth` beforehand;
`agy`'s `apikey` cell needed no interactive step.

Each session ran one non-interactive prompt: run `printenv HTTPS_PROXY`, then create
`/home/agent/sf1-probe.txt` containing `sf1 probe ok`, then confirm both steps.

## Per-agent findings

| | `claude` | `codex` | `agy` |
|---|---|---|---|
| **On-volume path** | `~/.claude/projects/-/<sessionId>.jsonl` | `~/.codex/sessions/<YYYY>/<MM>/<DD>/rollout-<timestamp>-<session-id>.jsonl` | `~/.gemini/antigravity-cli/conversations/<conversation_id>.db` (SQLite) |
| **Write model** | Append-only JSONL. One line per turn/event; `wc -l` grew from 0 to 17 across the session, file never shrank | Append-only JSONL. `session_meta` (ordinal 0) through `task_complete` (ordinal 24); 25 lines total for a 2-tool-call session | **Whole-file rewrite.** SQLite `.db`, rewritten (not appended) each turn — file size changed turn to turn (114688 → 122880 → 143360 bytes across three sessions in this run). This is Decision 3's `record_snapshot` branch |
| **Session identifier location** | `sessionId` field on every JSON line; matches the filename stem exactly | `session_id` and `id` fields inside the `session_meta` line (ordinal 0); matches the filename's trailing UUID | `conversation_id`, in the filename stem; also mirrored in `~/.gemini/antigravity-cli/cache/last_conversations.json` as `{"<cwd>": "<conversation_id>"}` |
| **File owner / mode** | `agent:agent`, `0600` | `agent:agent`, `0644` | `agent:agent`, `0644` |
| **`printenv HTTPS_PROXY` value landed in transcript** | `https://172.31.10.2:3128` — **no credential.** claude authenticates the proxy hop via mTLS client certificate (`CLAUDE_CODE_CLIENT_CERT`/`_KEY`), so its `HTTPS_PROXY` carries no userinfo to leak | **Yes.** `http://codex:<plaintext-password>@172.31.20.2:3128` appears verbatim, twice, in the rollout JSONL (once in the tool-call record, once in the model's echoed confirmation) | **Yes.** `https://agy:<plaintext-password>@172.31.30.2:3128` appears verbatim, 3× raw, inside the SQLite `.db` (`grep -a` on the binary file matched the credential value directly, unencoded) |

## The `agy` branch decision (Decision 3)

`agy` writes a **whole-file SQLite rewrite per turn**, not an append-only file. This settles Decision
3's open branch: the recorder ships a new snapshot line (`record_snapshot`) whenever the file's
`sha256` changes, keeping each version so a retroactive edit shows up as a later snapshot beside the
original, exactly as the plan's fallback describes. `agy`'s `--output-format json` one-shot mode
(`agy --print=... --output-format json`) is real and returns a `status` field (`ERROR` observed, not
yet `success`/`ok`/`completed` — see the compiler/CLI notes below), which resolves the
`agy-run.sh` `UNVERIFIED` marker for the field name; the exact success value was not observed in this
run because both sessions that reached the model completed via `--print` text mode, not
`--output-format json`. **Recorded as still open:** confirm the exact success-state string against a
`--output-format json` run that completes cleanly, before SF-2 builds `RECORDER_MODE=snapshot`
detection around it.

## Privilege-change structural finding (Acceptance Criterion 5)

Measured identically for all three agents, each in its own container:

- `id -u` → `1000` for all three.
- `/proc/self/status`: `CapEff: 0000000000000000`, `NoNewPrivs: 1`, for all three.
- Setuid-binary escalation attempt (`passwd`, present in all three images via the base OS): exits
  **10** (`Authentication token manipulation error`) for all three, after `NoNewPrivs=1` blocks the
  setuid bit from taking effect at exec time. `passwd` never reaches a state where it can write
  `/etc/shadow`.

**Finding:** no privilege-change event is reachable from inside any agent container, matching D15.
The evidence above is the finding; no privilege-change action needs recording because none can occur.

## Compiler measurement (Decision 7 trigger)

`scripts/compile-policy.sh:109` hardcodes `PROFILE_FILE="$REPO_ROOT/profiles/${PROFILE}.yaml"` —
`--profile` takes a bare name resolved under `profiles/` only. **The compiler cannot compile a
profile from outside `profiles/` today.** Decision 7's `--profile-file PATH` fallback is therefore
required for SF-4's T36 harness (four scratch-compiled variants under `.build-scratch/t36/`).

## Recorder posture measurement (Decision 1)

Confirmed directly: a `network_mode: none`, `--user 1000:1000` container mounting an agent's state
volume `:ro` can list and read that agent's mode-0700 home directory and mode-0600 transcript files
(uid match, not a mode bypass), and a write attempt against the same mount fails with `Read-only file
system`. This is the exact posture SF-2's `<agent>-recorder` services need.

## D20 limitation (restated per Acceptance Criterion 6)

Each agent writes its own transcript. The record is complete as written and tamper-evident once
shipped (a retroactive edit to already-shipped bytes does not reach the sink — SF-3 verifies this),
but a compromised agent can still write a false line before it ships. That gap is not closed by this
feature.

## Concurrent-session limitation (Decision 4)

Not separately measured here — recorded per the plan's stated limitation: two concurrent `run --rm`
sessions of the same agent share one identity and one egress listener, so the egress trail cannot
separate them. Single-operator scope makes this rare.

## Credential exposure note

The `codex` and `agy` findings above are the R8.6 finding this feature's acceptance criterion 8
requires; see `docs/records/credential-inventory.md` for the recorded finding and the Decision 8
mitigation (sink stays faithful; redaction applies only on the `agent_action_log` export relay).

Both proxy credentials used in this measurement (`codex.cred`, `agy.cred` — locally issued via
`scripts/issue-identity.sh credential <agent>`, scoped to this pod's `mediator/identity/` tree, not
committed to the repository) were rotated after this record was produced, because their plaintext
values were printed to the operator's terminal and to this session's own tool-call transcript during
the live probe — an exposure surface outside the pod boundary the architecture's "ACCEPTED, NOT
MITIGATED" reasoning (01.6 Decision 4) scopes to the internal Docker network alone.
