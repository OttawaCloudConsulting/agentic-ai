# Reproducibility, Provenance and Onboarding — Records

**Requirement.** Feature plan `reproducibility-provenance-and-onboarding.md` §Documentation:
this file carries T45/T18/T39 results, the R10.4 build-allowlist statement, the R11.2 assessment,
the proposed architecture edits, and the criterion → evidence table.

**Status.** This file carries SF-5's runbook, written before the clean-environment run per
Decision 3/Contract 6, and the results of that run (§ SF-5 run results). **T18 did not pass**: the
Test Command passed on the second Mac (six of its nine scripts by operator attestation), but the
fingerprint diff is not clean. SF-5 stays open
pending the findings below. The remaining sections (T45 chain and results, R10.4 finding, R11.2
assessment, proposed architecture edits, criterion → evidence table) are SF-6's close-out and land
in a later commit.

## Clean-environment procedure (SF-5)

This is the runbook for T18 (clean rebuild) and T39 (fresh operator), run together as one
clean-environment session on a **second physical Mac** (macOS 26, Apple silicon), per criteria 4
and 5 and Decision 3. The run follows this procedure verbatim; a deviation from it is a finding
(Edge Case 12), not a silent adjustment.

**Reference commit X = `5b133b25581f6574167bbe578912ab75cd9c1835`.** PR #42
(`feature/containerization` → `main`, squash-merged) landed this runbook and
`scripts/fingerprint-environment.sh` on `main` as this commit. It is **not** the SF-4 commit
(`79e2888`, PR #41) alone, because SF-4 predates this script — the second Mac's
`git checkout 5b133b2` is the first `main` commit that can run it.

### Stage 1 — Reference, on the build host

At commit X, on the build host (this machine):

1. For each shipped profile (`default`, `terraform`, `kubernetes`, `github`):
   ```
   docker compose --env-file compose/pins.env -f compose/compose.yaml \
     -f compose/overrides/<profile>.yaml build
   bash scripts/fingerprint-environment.sh <profile> > /tmp/ref.<profile>.json
   ```
2. Carry the four `ref.<profile>.json` files to the second Mac **out-of-band** (AirDrop or USB).
   They hold only versions and hashes — no secret material. Do **not** commit them at this stage;
   committing would move `main` past X before the clean run has happened.

### Stage 2 — Clean-state attestation, on the second Mac

Before any README step, record (this is test instrumentation, not a README step):

- `sw_vers` shows macOS 26.x and `uname -m` shows `arm64`.
- Docker Desktop is freshly installed or factory-reset; its version is recorded.
- `docker images`, `docker volume ls` and `docker buildx du` are empty.
- There is no existing clone and no `mediator/identity/` directory. The build host's CA key is
  never copied across — fresh identity issuance is part of the test (Edge Case 11).

A clean environment that fails any of the above checks is not clean; fix the environment, not the
check.

### Stage 3 — T39 + T18, on the second Mac

1. Start the session log (Edge Case 16): `script` records the raw terminal session locally on the
   second Mac only — it will contain the OAuth paste-back code and the device code, so it is never
   carried off that machine. `GEMINI_API_KEY` is set with `read -rs` before recording starts, so it
   never appears on screen or in the log.
2. `git clone` the repository, then `git checkout X`. The checkout is test instrumentation, not a
   README step.
3. Follow `README.md` Bring-Up **verbatim**, top to bottom: prerequisites, `install-deps.sh`, all
   eight `issue-identity.sh` commands, the one canonical `up` form, first-run auth for all three
   agents in the second Mac's browser. Log every command run, every deviation (each one is a
   finding — Edge Case 12), and every wait.
4. Build every shipped profile with the README's profile-switch recipe and fingerprint each one:
   ```
   bash scripts/fingerprint-environment.sh <profile> > /tmp/clean.<profile>.json
   ```
5. Run the feature's **Test Command** (below) on the second Mac and capture its output.

### Stage 4 — Compare and record, on the build host

Carry back the four `clean.<profile>.json` files, the cleaned step log and the Test Command
output, so the second Mac never needs GitHub credentials for this stage.

For each profile:
```
diff <(jq -S 'del(.commit)' ref.<profile>.json) <(jq -S 'del(.commit)' clean.<profile>.json)
```
Record both commits (the reference build's and the clean run's) alongside each diff. A clean diff
plus a passing Test Command on the second Mac is what T18 requires (criterion 4); neither alone is
sufficient.

**Findings loop:**
- A README-only fix lands via PR; only the affected section is re-run on the second Mac, because
  the references still hold.
- A mechanism defect is recorded and routed to `/milestone` revision rather than patched in place.
  It then needs new references and a full factory-reset re-run.

### Stage 5 — Teardown, on the second Mac

Mandatory after the run (Edge Case 16), because first-run auth leaves live OAuth refresh tokens on
the second Mac's state volumes:

1. `docker compose down -v`.
2. Delete `mediator/identity/`.
3. Revoke the Claude and Codex sessions the run created, at each provider.
4. Unset `GEMINI_API_KEY`.
5. Factory-reset Docker Desktop.

Record that teardown completed, including the revocation step.

## Test Command

```
bash tests/acceptance/verify-pack-composition.sh && bash tests/acceptance/verify-pod-topology.sh && bash tests/acceptance/verify-egress-mediator.sh && bash tests/acceptance/verify-audit-completeness.sh && bash tests/acceptance/verify-tool-packs.sh && bash tests/acceptance/verify-mcp-inventory.sh && BOUNDARY_PROFILES="default terraform kubernetes github" bash tests/acceptance/validate-boundary.sh && bash tests/acceptance/verify-reproducibility.sh && bash scripts/lint-policy.sh
```

## SF-5 run results

**Run dates.** 2026-09-12 (first session) and 2026-09-13 (re-run of the incomplete Test Command
scripts). **Second Mac:** macOS 26, Apple silicon. **Reference build host:** this machine, Docker
Compose `v2.38.2-desktop.1`.

**Commits.** Reference fingerprints: X = `5b133b25581f6574167bbe578912ab75cd9c1835`. Clean
fingerprints: the same X (every `clean.<profile>.json` carries it). Both sides are at X, so no
README fix landed between them.

### Verdicts

| Test | Result | Basis |
|---|---|---|
| **T18** — clean rebuild | **Not passed** | Test Command passed on the second Mac (three scripts logged, six by operator attestation); fingerprint diff is **not clean** on any profile (F1–F3). Criterion 4 needs both halves |
| **T39** — fresh operator | **Findings recorded, not closed** | Seven findings (F4–F10), none a boundary failure. F4, F5, F6 and F9 are runbook defects; F7, F8 and F10 record how the run was carried out |
| **R11.1** | **Not discharged** | It is discharged by a passing T18 |

### Clean-state attestation (Stage 2)

Performed by the operator before Stage 3 and attested verbally. The command output (including the
Docker Desktop version) was **not carried back**. The operator reported the second Mac's Docker
Compose version afterwards: **v5.3.1** (the build host runs v2.38.2). This version gap is the
verified cause of F3.

### Fingerprint diffs (Stage 4)

`diff <(jq -S 'del(.commit)' ref.<profile>.json) <(jq -S 'del(.commit)' clean.<profile>.json)`.
Every field not listed matched: base digests, `resolved_policy_sha256`, agent versions, agent
`dpkg_sha256`, `bin_sha256`, `npm_tree_sha256` (no npm transitive drift, Edge Case 10), mediator
daemon versions.

| Field | `default` | `terraform` | `kubernetes` | `github` | Finding |
|---|---|---|---|---|---|
| `compose_config_sha256` | `4fd2b91c…` → `f6cb472f…` | `4fd2b91c…` → `f6cb472f…` | `86afda52…` → `8190a4e1…` | `d88864c7…` → `8369c578…` | F3 |
| `agents.*.pack_roots_sha256` | match | match (both default packs, F1) | `de1d9344…` → `70995756…` | `de1d9344…` → `9095d5c3…` | F1 |
| `mediator.dpkg_sha256` | `faf39982…` → `800c5839…` | same | same | same | F2 |

### Test Command on the second Mac

The Test Command did not run as one composite (F5, F7). Results by script:

| Script | Result | Evidence |
|---|---|---|
| `verify-pack-composition.sh` | Pass | Phases A–C logged passing in the first session; the harness bring-up after Phase C hit F5. Remainder attested |
| `verify-pod-topology.sh` | Pass | Operator attestation, no captured output |
| `verify-egress-mediator.sh` | Pass | Operator attestation, no captured output |
| `verify-audit-completeness.sh` | Pass | Operator attestation, no captured output |
| `verify-tool-packs.sh` | Pass | Operator attestation, no captured output |
| `verify-mcp-inventory.sh` | Pass | Operator attestation, no captured output |
| `validate-boundary.sh` (`BOUNDARY_PROFILES="default terraform kubernetes github"`) | Pass | Logged: `ALL CHECKS PASSED`, 416 PASS, 0 FAIL. Carries the two recorded known gaps (T6 cold-peer 500, `resolved_ip` on deny) and the stdio-MCP blind spot |
| `verify-reproducibility.sh` | Pass | Logged: `20 passed, 0 failed`, on the second Mac's existing checkout after restoring `mediator/identity/README.md` (F6, F7). Phases A–D are static file checks and remote registry/API queries, so the result does not depend on local Docker state |
| `lint-policy.sh` | Pass | Logged: `lint-policy: OK` |

**Operator attestation.** Six scripts rest on the operator's statement that they ran without
error, accepted by the operator in place of a re-run. Their output was not captured.

### Findings

Classified per the findings loop: **README/runbook** fixes re-run only the affected section,
because the references still hold. **Mechanism** defects are routed to `/milestone` and need new
references plus a factory-reset full re-run.

**F1 — Stage 1 omits `AGENT_PROFILE`, so three of the four references fingerprint default packs.
Runbook defect; invalidates the references.**
- Stage 1 builds each profile with `-f compose/overrides/<profile>.yaml build` alone. Packs are
  selected only by `AGENT_PROFILE` (`PROFILE` build arg, `compose.yaml:396/473/539`), and the
  `terraform` override is identical to `default`'s. The README's switching recipe sets
  `AGENT_PROFILE=<profile>`.
- Evidence: the reference `pack_roots_sha256` for `kubernetes` and `github` equals `default`'s
  (`de1d9344…`). The clean images, built with `AGENT_PROFILE` set, carry their packs
  (`70995756…`, `9095d5c3…`).
- The second Mac set `AGENT_PROFILE` for `kubernetes`/`github` but **not** for `terraform`. So the
  `terraform` match is two default-pack images matching, not a test of the `terraform` pack.
- Two gaps in `fingerprint-environment.sh` let this go undetected. Both are candidates for
  `/milestone`:
  - it does not check that the built images belong to the profile it was given;
  - its own `docker compose config` call never passes `AGENT_PROFILE`, so `compose_config_sha256`
    renders every profile with `PROFILE`/`MEDIATOR_PROFILE` set to `default` and cannot tell
    profiles apart by pack selection. On the second Mac, `AGENT_PROFILE=<profile>` was a prefix on
    the `up` command only, so the fingerprint on the next line rendered with it unset, as on the
    build host. The `compose_config_sha256` differences for `kubernetes`/`github` are therefore
    F3, not this finding. Fix: `AGENT_PROFILE="$PROFILE" docker compose … config`.
- Fix: Stage 1 and Stage 3 step 4 use `AGENT_PROFILE=<profile>` for every non-default profile.

**F2 — The mediator's transitive packages float with the live Debian archive. Mechanism defect.**
- Cause verified: a no-cache rebuild of `egress-mediator` on the build host on 2026-09-13
  reproduces the second Mac's `800c5839…`. The package-list diff against the reference image
  (built 2026-09-11 22:17Z) is one line: `libcom-err2 1.47.2-3+b11` → `1.47.2-3+b12`.
- `libcom-err2` is not in `debian:trixie-slim@${MEDIATOR_BASE_DIGEST}`. It is auto-installed as a
  dependency of `libkrb5-3`/`libgssapi-krb5-2` (reached through the unpinned bootstrap
  `apt-get install ca-certificates curl gpgv`) and of `squid-openssl`. It survives the
  `purge --auto-remove curl gpgv`.
- The snapshot is fixed at `20260910T203409Z` and cannot give two versions on two dates. So the
  changing version comes from the live archive during the bootstrap install.
  `apt-pinned.sh` pins the four named packages, not their dependency closure.
- This is the drift Decision 6 attributed to SF-1b for `agent-base`. SF-1c moved the mediator's
  named packages onto the snapshot but left the bootstrap step's transitive closure on live sources.
- Route to `/milestone`: the mediator bootstrap needs its dependency closure resolved from the
  snapshot, or the pinned set widened. Either is a mechanism change, so it needs new references.

**F3 — `compose_config_sha256` hashes the Compose renderer's output format, not the
configuration. Mechanism defect.**
- Both sides rendered `default` with `AGENT_PROFILE` unset at commit X. The build host still
  reproduces the reference `4fd2b91c…` today, and its rendered config has no host path left after
  `<ROOT>` normalisation.
- `GEMINI_API_KEY` is ruled out: it is not interpolated anywhere in the rendered files, and
  setting it does not change the hash.
- A host-only env file is ruled out: no compose file uses `env_file:`, so
  `references/.env_keys` (present on the build host, absent from a fresh clone) never reaches the
  rendered config, and that config carries no key-like variable names.
- **Cause verified: the Docker Compose version.** The second Mac ran Compose v5.3.1; the build
  host runs v2.38.2. On the build host, at X, the standalone Compose v5.3.1 binary (checksum
  verified against the release's published sha256) renders all four profiles with exactly the
  second Mac's hashes: `default`/`terraform` `f6cb472f…`, `kubernetes` `8190a4e1…`, `github`
  `8369c578…`. v2.38.2 on the same tree gives exactly the reference hashes. The same inputs
  produce different output under different Compose versions.
- So the field is only comparable between hosts running the same Compose release. The README's
  prerequisite is "Docker Desktop", which an operator installs at whatever version is current and
  cannot pin, so this field will differ on essentially every clean run.
- Route to `/milestone`. Candidate fixes: hash a version-independent form of the configuration
  (for example selected, sorted fields extracted with `jq`), or record the Compose version as a
  fingerprint field and compare `compose_config_sha256` only when it matches.

**F4 — Stage 3 step 4's `up` blocks the fingerprint that follows it. Runbook defect.**
- The README's canonical form, `up --build --force-recreate`, runs in the foreground, and phase D
  of `verify-reproducibility.sh` requires exactly that form. A fingerprint command placed after it
  in one terminal never runs.
- Fingerprinting needs built images only (`fingerprint-environment.sh` never starts the pod), so
  the runbook step should `build` each profile, not `up` it.

**F5 — The Test Command cannot run while the operator's pod is up. Runbook defect.**
- The operator procedure left the `default` pod running before the Test Command.
  `verify-pack-composition.sh` failed at its own bring-up: `another Compose project already holds
  this pod's subnets`.
- The harnesses isolate by project name (`-p sf7-verify-$$` and similar), but `compose.yaml` gives
  the networks static `ipam` subnets (`172.31.10/20/30.0/24`), which the listener certificate SANs
  depend on. Docker does not allocate one subnet to two networks, whatever the project name.
- Fix: the runbook brings the pod down before the Test Command.

**F6 — Stage 5 step 2 ("Delete `mediator/identity/`") deletes a tracked file. Runbook defect.**
- `mediator/identity/README.md` and `.gitignore` are committed. Deleting the directory removed the
  README, and a later `verify-reproducibility.sh` exited 2 at phase D.4, whose `awk` reads that
  file under `set -euo pipefail`.
- Restoring the file (`git checkout -- mediator/identity/README.md`) and re-running gave 20/20.
- Fix: delete only the generated material (`git clean -fdX mediator/identity/`).

**F7 — The Test Command ran in pieces across two sessions.**
- After F5, the incomplete scripts were re-run from a truncated runbook:
  - Part A: the other scripts, on the second Mac's existing checkout, after re-issuing identity
    material that Stage 5 had removed;
  - Part B: `verify-reproducibility.sh` alone, on the same checkout. Its first attempt exited 2
    (F6); it passed after the README was restored. A re-clean was planned for Part B, but there is
    no evidence it happened, and phases A–D do not depend on it.
- Consequences: six scripts have attestation rather than captured output, and no Stage 2 output
  exists for Part B.
- A re-run should capture every script's output with `2>&1 | tee`.

**F8 — The operator worked from a derived runbook, not the README verbatim.** Decision 3 makes the
README the contract. The operator followed an operator-facing copy of this procedure with the
commands written out, including the dummy-credential staging for `kubernetes`/`github`. F1's
`terraform` omission and F4's blocking `up` came from that copy. The step log therefore does not
show that the README alone was sufficient (Test Strategy: "no command absent from the README").

**F9 — The raw `script` log reached 1.83 GB.** BuildKit's progress output is captured in full, so
the log cannot be carried back or reviewed. The first cleaning pass also let a binary segment
through. A cleaned log (command, outcome, deviation; redacted for key and token shapes) was
produced for the Part A session. The Edge Case 16 cleaning step needs a documented command that
strips terminal control sequences and drops build progress lines.

**F10 — Identity material had to be re-issued for the Part A re-run.** This follows from F6/F7:
the first session's teardown removed it before the incomplete scripts were re-run. It is not a
separate defect.

### Teardown (Stage 5)

Attested by the operator as completed on the second Mac after the final session: pod down with
volumes, identity material removed, Claude and Codex sessions revoked at each provider,
`GEMINI_API_KEY` unset, Docker Desktop factory-reset.

### What closes SF-5

1. Fix F1, F4, F5 and F6 in the runbook above, plus F9's cleaning command. The runbook is left
   here as the pre-run version on purpose: it is what this run was measured against.
2. Route F2 and F3 to `/milestone`, along with F1's two `fingerprint-environment.sh` gaps.
3. After the mechanism fixes land at a new X: regenerate all four references with
   `AGENT_PROFILE` set, then do a factory-reset full re-run that follows the README verbatim
   (F8), captures every Test Command script's output (F7), and carries back the Stage 2 output.
