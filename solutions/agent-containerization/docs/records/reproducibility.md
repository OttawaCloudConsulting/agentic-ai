# Reproducibility, Provenance and Onboarding — Records

**Requirement.** Feature plan `reproducibility-provenance-and-onboarding.md` §Documentation:
this file carries T45/T18/T39 results, the R10.4 build-allowlist statement, the R11.2 assessment,
the proposed architecture edits, and the criterion → evidence table.

**Status.** This file carries SF-5's runbook, the first clean-environment run (§ SF-5 run results,
**T18 not passed**), the revised procedure (§ Clean-environment procedure — revision 2) and the
re-run (§ SF-5 re-run results, 2026-09-28). **T18 passed on the re-run**: four clean fingerprint
diffs and the Test Command at `composite exit=0`, both from captured output, across a two-version
Docker/Compose gap. **T39 is closed on operator attestation**, not on step-log evidence — the
recording was lost and an off-README command was run; see F-a, F-g (ii) and F-h. **SF-6 closed the
file out** (2026-09-29): the T45 chain measured green on the build host, the R10.4 finding and its
review trigger, the R11.2 assessment, the two proposed architecture edits as replacement text, the
carried findings' disposition, and the criterion → evidence table. Feature 02.4 is complete; the two
architecture edits are recorded here for the milestone consolidation pass and are **not** applied.

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

**Status (2026-09-13).** Item 1 is done as § Clean-environment procedure — revision 2 (SF-5d),
below. Item 2 is done as mechanism: SF-5a (F1's two script gaps, F3), SF-5b and SF-5c (F2), with
`agent-base` republished from `main` and repinned (PR #45, PR #46). Item 3 is the SF-5 re-run.

## Clean-environment procedure — revision 2 (SF-5d)

This procedure replaces the pre-run procedure above for the SF-5 re-run. The pre-run procedure
stays as written, because the first run was measured against it. Revision 2 fixes F1 and F4–F10 as
runbook. F1's two script gaps, F2 and F3 are fixed as mechanism by SF-5a–SF-5c (feature plan,
Decision 8).

**What changed from the pre-run procedure:**

| Finding | Revision 2 |
|---|---|
| F1 | Every profile, `default` included, is built with `AGENT_PROFILE` set. `fingerprint-environment.sh` (schema 2) exits 4 on images built for another profile |
| F4 | Profiles are built with `build`, never `up`. Fingerprinting reads built images and never needs a running pod |
| F5 | The pod is brought down before the Test Command |
| F6 | Teardown removes only git-ignored material (`git clean -fdX`) |
| F7 | Each Test Command script's output is captured with `2>&1 \| tee`, under `pipefail`, with every exit code written to a file |
| F8 | README steps are referenced here by section and step number, never restated (rule below) |
| F9 | Build output goes to per-profile files, not the terminal, and a documented command cleans the session log |
| F10 | Teardown runs only after the build host confirms it has received every carried-back file |
| — | Stage 2 output is captured to a file and carried back, not attested |

**Rule for this procedure (F8).** Decision 3 makes the README the contract. Every README step below
is named by its README section and step number, and the operator carries it out from `README.md`
itself. Nothing here restates a README command. The blocks written out below are **test
instrumentation** only: checkout, capture, per-profile build and fingerprint, pod down, the Test
Command wrapper, log cleaning, carry-back and teardown. Do not make a derived operator copy that
merges the two. If a README step is not enough to proceed, that is a T39 finding (Edge Case 12).
Log it; this procedure does not fill the gap.

**Reference commit X₂.** X₂ is a `main` commit carrying SF-5a–SF-5d and SF-5c's `main`-pinned
`AGENT_BASE_DIGEST` (`b3e17bb`, PR #46). This procedure lands on `main` by pull request, so X₂ is at
least that PR's merge commit, and is recorded here when the re-run starts. The first run's schema-1
references are void. All four references are regenerated at X₂ (Contract 5 revision 2).

**Shell.** Every block runs in `bash`. macOS 26's default login shell is `zsh`, so start `bash`
first. Commands piped through `tee` rely on `set -o pipefail`.

**One `:local` tag for all profiles.** Every profile build writes to the same
`sandboxed-agent/<agent>:local` and `sandboxed-agent/mediator:local` tags, and
`fingerprint-environment.sh` reads only those. So each profile is built and then fingerprinted
before the next profile is built. The loops below keep that order; the script's exit 4 is a
backstop, not the ordering.

**No pack credential is staged for the builds.** None of the compose files gives a `build:` block
any `secrets:`, and the profile overrides have no `build:` key. The `github` and `kubernetes`
overrides read their `file:` secrets from `${PACK_CREDENTIALS_DIR:-…}`. Measured on the build host
(Compose v2.38.2, 2026-09-13): with `AGENT_PROFILE=github` and `PACK_CREDENTIALS_DIR` set to an
empty directory, `docker compose … -f compose/overrides/github.yaml build claude` exits 0
(`claude Built`). That build reused cached layers, so it shows Compose does not require the
secret file to build, not a from-scratch build. If a build fails on the second Mac for want of a
credential, that is a finding. The Test Command's `validate-boundary.sh`
stages its own dummy files in a `mktemp -d` directory.

### Stage 1 — Reference, on the build host (revision 2)

At X₂, with no modified tracked files:

```bash
git checkout <X2>
git diff --quiet HEAD && echo "tracked tree clean"
mkdir -p /tmp/sf5-ref
( set -euo pipefail
  for p in default terraform kubernetes github; do
    AGENT_PROFILE="$p" docker compose --env-file compose/pins.env -f compose/compose.yaml \
      -f "compose/overrides/$p.yaml" build --no-cache > "/tmp/sf5-ref/build.$p.log" 2>&1
    bash scripts/fingerprint-environment.sh "$p" > "/tmp/sf5-ref/ref.$p.json"
  done )
jq -r '[.profile, .schema, .commit, .docker_version, .compose_version] | @tsv' /tmp/sf5-ref/ref.*.json
```

`--no-cache` makes the reference what a from-scratch build produces, as the second Mac's build is.
Apt resolves from frozen snapshots, but npm transitive dependencies are not locked (Decision 6), so
a cached `npm install -g` layer would show up as an `npm_tree_sha256` diff caused by the build
host's cache. Build the references as close in time to Stage 3 as practical.

The last command must show four rows: `schema` 2, `commit` X₂, each row's `profile` matching its
file name. Carry the four `ref.<profile>.json` files to the second Mac out-of-band (AirDrop or USB).
They hold versions and hashes only. Do not commit them before the run.

### Stage 2 — Clean-state attestation, on the second Mac (revision 2)

The criteria are unchanged from the pre-run Stage 2 (macOS 26.x, `arm64`, Docker Desktop freshly
installed or factory-reset, no images, volumes or build cache, no clone). Revision 2 captures the
evidence to a file. From the home directory, before any README step:

```bash
bash
set -o pipefail
mkdir -p ~/sf5-run
{ date -u; sw_vers; uname -m; docker version; docker compose version
  docker images; docker volume ls; docker buildx du; docker system df
  ls -d ~/agentic-ai; } 2>&1 | tee ~/sf5-run/stage2.txt
```

`ls -d ~/agentic-ai` must report `No such file or directory`. `stage2.txt` is carried back and
includes the Docker and Compose versions.

### Stage 3 — T39 + T18, on the second Mac (revision 2)

1. **Session log (Edge Case 16).** Set the key before recording starts, so it never reaches the
   screen or the log, then record the session:
   ```bash
   read -rs GEMINI_API_KEY; export GEMINI_API_KEY
   script -q ~/sf5-run/raw-session-1.log bash
   ```
   A second terminal, if one is used, runs the same two lines (`read -rs` first, then `script` to
   `raw-session-2.log`), so the key is never typed into a recorded shell. The raw logs
   hold the OAuth paste-back code and the device code, so they never leave the second Mac.
2. **README Bring-Up, step 2** (clone and enter the solution directory), from `~`. Then, as
   instrumentation, inside the solution directory: `git checkout <X2>`.
3. **README Bring-Up, steps 3–7**, verbatim, including § First-run authentication for `claude`,
   `codex` and `agy`. Log every command run, every deviation and every wait.
4. **Stop the pod (F5).** Stop the foreground `up` from step 5 of Bring-Up (Ctrl-C), then:
   ```bash
   docker compose --env-file compose/pins.env -f compose/compose.yaml \
     -f compose/overrides/default.yaml down
   docker ps
   ```
   Without `-v`: the state volumes keep first-run authentication. `docker ps` must list no
   containers. The static `ipam` subnets allow one Compose project at a time (F5).
5. **Build and fingerprint every profile (F1, F4).** Build output goes to files, not the recorded
   terminal (F9):
   ```bash
   ( set -euo pipefail
     for p in default terraform kubernetes github; do
       AGENT_PROFILE="$p" docker compose --env-file compose/pins.env -f compose/compose.yaml \
         -f "compose/overrides/$p.yaml" build > ~/sf5-run/build."$p".log 2>&1
       bash scripts/fingerprint-environment.sh "$p" > ~/sf5-run/clean."$p".json
     done )
   echo "build+fingerprint exit=$?"
   jq -r '[.profile, .schema, .commit, .docker_version, .compose_version] | @tsv' ~/sf5-run/clean.*.json
   ```
   The exit must be 0, with four rows as in Stage 1. The build logs stay on the second Mac unless a
   build fails, in which case the failing profile's log is carried back.
6. **Test Command (F7).** The same scripts, in the same order, with the same `&&` gating as § Test
   Command. Only output capture is added, as a DD-12 operator adjustment, not a deviation. Under
   `pipefail`, a failing script stops the chain even though its output passes through `tee`:
   ```bash
   bash -c '
   set -uo pipefail
   : > ~/sf5-run/test-exit.txt
   run() { local name="$1"; shift; echo "=== $name"
           "$@" 2>&1 | tee ~/sf5-run/test."$name".log; local rc=$?
           echo "$name exit=$rc" | tee -a ~/sf5-run/test-exit.txt; return "$rc"; }
   run verify-pack-composition bash tests/acceptance/verify-pack-composition.sh &&
   run verify-pod-topology bash tests/acceptance/verify-pod-topology.sh &&
   run verify-egress-mediator bash tests/acceptance/verify-egress-mediator.sh &&
   run verify-audit-completeness bash tests/acceptance/verify-audit-completeness.sh &&
   run verify-tool-packs bash tests/acceptance/verify-tool-packs.sh &&
   run verify-mcp-inventory bash tests/acceptance/verify-mcp-inventory.sh &&
   run validate-boundary env BOUNDARY_PROFILES="default terraform kubernetes github" bash tests/acceptance/validate-boundary.sh &&
   run verify-reproducibility bash tests/acceptance/verify-reproducibility.sh &&
   run lint-policy bash scripts/lint-policy.sh
   echo "composite exit=$?" | tee -a ~/sf5-run/test-exit.txt
   '
   ```
   Measured with stand-in scripts (exit 0, exit 3, then a third): the chain stopped after the
   failing script, the third never ran, and `test-exit.txt` recorded `composite exit=3`.
7. **End the recording.** `exit` from the recorded shell in each terminal.
8. **Clean the session log (F9)**, on the second Mac:
   ```bash
   for f in ~/sf5-run/raw-session-*.log; do
     LC_ALL=C perl -pe 's/\e\][^\a\e]*(?:\a|\e\\)//g; s/\e\[[0-?]*[ -\/]*[@-~]//g; s/\e[@-_]//g;
                        s/\r\n/\n/g; s/.*\r//; s/[^\t\n\x20-\x7e]//g' "$f" \
       | grep -Ev '^#[0-9]+ |^ *=> |^\[\+\] (Building|Running)' \
       | perl -pe 's/AIza[0-9A-Za-z_-]{20,}/<REDACTED>/g; s/sk-[A-Za-z0-9_-]{16,}/<REDACTED>/g;
                   s/gh[pousr]_[A-Za-z0-9]{20,}/<REDACTED>/g; s/github_pat_[A-Za-z0-9_]{20,}/<REDACTED>/g;
                   s/eyJ[A-Za-z0-9_-]{20,}(?:\.[A-Za-z0-9_-]+)*/<REDACTED>/g'
   done > ~/sf5-run/session-clean.log
   grep -nE 'AIza|sk-|gh[pousr]_|github_pat_|eyJ' ~/sf5-run/session-clean.log
   ```
   The perl passes strip OSC and CSI terminal sequences, keep only the last carriage-return rewrite
   of each line, and drop non-printable bytes. The `grep -v` drops BuildKit progress lines. The
   last perl pass redacts provider key and token shapes. The final `grep` must find no match outside
   `<REDACTED>`. The claude paste-back code and the codex device code have no fixed shape, so the
   operator reads the cleaned log and redacts them by hand before it leaves the machine. The
   command was verified against a synthetic log (escape sequences, carriage-return progress,
   BuildKit lines, binary bytes, a key shape and a token shape), not against a real session log. A
   real log it does not clean is a finding.

### Stage 4 — Compare and record, on the build host (revision 2)

Carry back out-of-band: `stage2.txt`, `clean.<profile>.json` ×4, `test.<script>.log` ×9 (fewer if
the chain stopped), `test-exit.txt` and `session-clean.log`. The raw session logs and passing build
logs are not carried back.

```bash
for p in default terraform kubernetes github; do
  echo "== $p"
  diff <(jq -S 'del(.commit, .docker_version, .compose_version)' "ref.$p.json") \
       <(jq -S 'del(.commit, .docker_version, .compose_version)' "clean.$p.json") && echo "clean"
done
jq -r '[.profile, .commit, .docker_version, .compose_version] | @tsv' ref.*.json clean.*.json
cat test-exit.txt
```

Record both commits and both Docker/Compose version pairs for each profile. **T18 passes only if**
all four diffs are clean **and** `test-exit.txt` shows every script and the composite at
`exit=0`. The findings loop is unchanged from the pre-run Stage 4. A README-only fix changes only
`commit`, which the comparison excludes.

### Stage 5 — Teardown, on the second Mac (revision 2)

Start only after the build host confirms it has received every Stage 4 file (F10). Findings that
need a section re-run are re-run before teardown where possible, so identity material is not
re-issued. From the solution directory:

```bash
docker compose --env-file compose/pins.env -f compose/compose.yaml \
  -f compose/overrides/default.yaml down -v
git clean -fdX mediator/identity/
git clean -fdX compose/generated/
git status --short mediator/identity/
rm -f ~/sf5-run/raw-session-*.log
unset GEMINI_API_KEY
```

`git clean -fdX` removes only git-ignored files, and `git status` must show no deleted tracked
file. Dry-run on the build host (`git clean -ndX mediator/identity/`): it removes `ca/`,
`clients/`, `credentials/` and `listeners/`, and keeps the tracked `README.md` and `.gitignore`.
`compose/generated/` is git-ignored by its own `.gitignore`. Then, outside the shell:

1. Revoke the Claude and Codex sessions the run created, at each provider.
2. Factory-reset Docker Desktop.

Record each teardown step and its outcome, including the revocation.

## SF-5 re-run results (2026-09-28)

**Run date.** 2026-09-28 (UTC 2026-09-28T23:54Z through 2026-09-29T01:00Z). Followed
§ Clean-environment procedure — revision 2.

**Reference commit X₂ = `028ff4ac362c3fecc16760b944269ae433ecd1a6`** (PR #48 on `main`). Both sides are
at X₂. The references were regenerated on the build host at 2026-09-28 19:47 EDT from `--no-cache`
builds, immediately before the run. They came out byte-identical to a set built at the same commit
on 2026-09-13, so the pinned package sets and the npm tree held for fifteen days across two
from-scratch builds.

**Hosts.**

| | Build host | Second Mac |
|---|---|---|
| OS | macOS 26, Apple silicon | macOS 26.6.1 (25G76), `arm64` |
| Docker | 28.3.2 | Engine 29.6.2, Desktop 4.83.0 |
| Compose | v2.38.2-desktop.1 | v5.3.1 |

The Compose gap is deliberate: v5.3.1 against v2.38.2 is the exact difference that produced F3 in
the first run. SF-5a's normalised render is what this run tests.

### Verdicts

| Test | Result | Basis |
|---|---|---|
| **T18** — clean rebuild | **Passed** | Both halves of criterion 4, from captured output: four clean fingerprint diffs, and the Test Command at `composite exit=0` with all nine scripts at `exit=0` on the second Mac |
| **T39** — fresh operator | **Closed on operator attestation** | The step log was lost (F-a), part of Stage 3 ran from the assisting session's shell rather than the recorded operator shell (F-g ii), and an off-README `up -d` was run (F-h). The operator vouched for the functionality and accepted the run; recorded as attestation, **not** as step-log evidence |
| **R11.1** | **Discharged** | By T18 passing on macOS 26 / Apple silicon. The T39 evidence caveat above applies to the conduct of the run, not to the rebuild result |

### Clean-state attestation (Stage 2)

Captured to `stage2.txt` and carried back, which the first run did not do. Docker Desktop was
factory-reset by the operator before capture. `docker images`, `docker volume ls` and
`docker buildx du` all empty, `docker system df` all zero, and `ls -d ~/agentic-ai` reported no such
file. Stage 2 passed with no failed check.

### Fingerprint diffs (Stage 4)

`diff <(jq -S 'del(.commit, .docker_version, .compose_version)' ref.<p>.json) <(… clean.<p>.json)`
— **clean for all four profiles**. Every field matched, so the values below are both sides'.

| Profile | `compose_config_sha256` | `pack_roots_sha256` | `npm_tree_sha256` | mediator `dpkg_sha256` |
|---|---|---|---|---|
| `default` | `e2fcaaa9…` | `f5c19659…` | `744e0973…` | `e98336d5…` |
| `terraform` | `36f6bc00…` | `51dfb59f…` | `744e0973…` | `e98336d5…` |
| `kubernetes` | `1b75fdc2…` | `d369eabf…` | `744e0973…` | `e98336d5…` |
| `github` | `5d683826…` | `6cd19ca7…` | `744e0973…` | `e98336d5…` |

Against the first run's three causes:

- **F1 fixed.** Each profile carries its own `pack_roots_sha256`, and all four differ. In the first
  run `terraform` was indistinguishable from `default`.
- **F2 fixed.** The mediator package hash matched on a machine that had never built these images,
  and matched again fifteen days after the 2026-09-13 reference build.
- **F3 fixed.** `compose_config_sha256` matched across Compose v2.38.2 and v5.3.1. In the first run
  every profile differed on this field alone.

### Test Command on the second Mac

Run as one chain under `pipefail` with each script's output teed to its own file (F7), exit codes in
`test-exit.txt`. **Every script `exit=0`, `composite exit=0`.**

| Script | Result |
|---|---|
| `verify-pack-composition.sh` | 109 PASS, 0 FAIL — all phases passed |
| `verify-pod-topology.sh` | ALL CHECKS PASSED |
| `verify-egress-mediator.sh` | ALL PHASES PASSED |
| `verify-audit-completeness.sh` | ALL PHASES PASSED |
| `verify-tool-packs.sh` | 41 passed, 0 failed |
| `verify-mcp-inventory.sh` | 44 passed, 0 failed |
| `validate-boundary.sh` (`default terraform kubernetes github`) | ALL CHECKS PASSED, carrying only the two recorded T6 known gaps |
| `verify-reproducibility.sh` | 25 passed, 0 failed — phases A–D, including phase C (T45) green against the `main` pin |
| `lint-policy.sh` | OK |

All nine have captured output. In the first run six rested on operator attestation.

### Findings

**F-a — the session recording was lost. Test-conduct defect; removes the T39 evidence.**
`raw-session-1.log` was 3.7 MB at 20:13, 115 bytes at 20:21, and 141 bytes at carry-back: a shell
prompt and `exit`. `session-clean.log` is 55 bytes. The step 8 cleaning command ran and its
secret-shape grep found no match, so the cleaning path is untested against a real log. Probable
cause, **not verified**: a second `script` invocation reused `raw-session-1.log` (revision 2 gives a
second terminal `raw-session-2.log`), or the recorded shell was restarted onto the same name.
Revision 2 should require the recording to be confirmed non-empty before the run proceeds.

**F-b — the clone landed in the operator's working tree.** `~/Documents/tools/git-repos/occ/agentic-ai`,
not `~`. README step 2 gives `git clone <repository-url>` without a location, and revision 2 says
"from `~`". Stage 2's `ls -d ~/agentic-ai` ran before the clone, so the attestation stands. No
effect on the result; the runbook and README disagree about where the clone goes.

**F-c — all three agent containers exited 0 within one second of `up`.** At 00:07:56Z, with the
mediator and recorders staying up. `claude` logged
`bootstrap-auth: WARNING -- (claude|codex, oauth-interactive) has no credential yet.` The README
says containers "start unauthenticated rather than failing" but does not say whether they should
then stay running. Whether F-h's detached `up` was involved was not established. **Unresolved, and a
real README/behaviour question for SF-6 or `/milestone`.**

**F-d — the codex auth label is wrong.** `bootstrap-auth` printed
`(codex, oauth-interactive) starting paste-back login.` and then ran device-code login. The README
and the implementation both say codex uses device code; the message names the wrong flow. A
one-line message fix.

**F-e — `agy`'s key validity was not verified. Accepted as a pass by operator decision, 2026-09-28.**
`bootstrap-auth` printed `(agy, apikey) ready -- credential supplied by environment (GEMINI_API_KEY
set)`, which checks only that the variable is set. The operator's account was that the key "should
have been valid, but it may have expired". The evidence is that the variable was set; the key's
validity is unverified. Recorded as accepted on that basis, not as a verified pass.

**F-f — every profile build printed a `CODEX_HOME` warning.** `WARNING: proceeding, even though we
could not create PATH aliases: CODEX_HOME points to "/home/agent/.codex", but that path does not
exist`. Build exit 0. Also seen on the build host's reference builds, where
`fingerprint-environment.sh` inspects images with no state. Cosmetic, but it appears in every clean
build and should either be suppressed or explained.

**F-g — deviations from revision 2.**
  1. The runbook and README were read via `gh api` into `/tmp/sf5-read` before the clone, to keep the
     machine clone-free for Stage 2. Accepted as instrumentation; same content at X₂.
  2. Stage 3 steps 4–6 (pod down, the four profile builds and fingerprints, the Test Command) ran
     from the assisting session's shell, not the operator's recorded shell. This is part of why T39
     has no step log.
  3. The assisting session's first `compose down` was refused by its own safety classifier; its user
     instructed it directly and it ran once, without `-v`. Correctly authorised in that session.

**F-h — an off-README `up -d` was run. Confirmed by the operator.** README step 5 gives a foreground
`up --build --force-recreate`, and revision 2 says to Ctrl-C it. The operator ran both the foreground
`up` and a detached `up -d`. Order and timing are unknown (`~/.bash_history` has no timestamps), so
whether it explains F-c is **unresolved**. This is the finding that would have been caught by a step
log, and it is the reason T39 is recorded as attestation rather than evidence.

**F-i — `down -v` lines in shell history predate the run.** The operator states only a plain `down`
was run. Stage 2 recorded zero volumes before the run started, which is consistent. Not verifiable
from untimestamped history; recorded as resolved-by-attestation, and nothing in the results depends
on it.

### Evidence that does not exist

Stated plainly, because the verdicts above rest on what remains:

- there is no step log for this run;
- `~/.bash_history` shows a final command block whose every entry matches a README command, in
  README order, but it is untimestamped, has no ordering across runs, and is missing `git clone`;
- the operator's step 6 and 7 terminal output exists only in the assisting session's transcript and
  carries a one-time codex device code, so it was not carried back;
- six of the first run's nine scripts rested on attestation; this run's nine all have captured
  output, so the Test Command half of T18 is fully evidenced.

### Teardown (Stage 5)

Approved 2026-09-29 after all carried-back files were confirmed received: pod down with volumes,
`git clean -fdX` on `mediator/identity/` and `compose/generated/`, raw session logs deleted, key
unset, Claude and Codex sessions revoked at each provider by the operator, Docker Desktop
factory-reset. The teardown confirmation is the assisting session's final report.

### What this closes

- **T18 passed** — criterion 4, both halves, including the 2026-09-13 clarifications (per-profile
  fingerprints, date-independent package sets, renderer-independent comparison).
- **T39 closed on operator attestation**, with F-a, F-g (ii) and F-h named as the reasons it is not
  step-log evidenced.
- **R11.1 discharged.**
- **Carried into SF-6 or `/milestone`:** F-c (unresolved), F-d, F-f, the revision 2 amendment from
  F-a (confirm the recording is live before proceeding), and F-b's clone-location disagreement.

## T45 — the provenance chain, measured in both directions (SF-6)

T45 is criterion 1: the digest the pod consumes resolves to a `main`-built, CI-published image
carrying an SBOM. It is checked mechanically by `tests/acceptance/verify-reproducibility.sh`
phase C, which walks one chain and asserts seven facts along it:

```
compose/pins.env AGENT_BASE_DIGEST
  -> ghcr.io index (anonymous pull)
     -> SPDX SBOM attestation          (>= 1 package)
     -> SLSA provenance attestation    (runDetails.builder.id names a run of
                                        OttawaCloudConsulting/agentic-ai;
                                        materials carry vcs:revision)
        -> api.github.com /actions/runs/<id>
           -> path        == .github/workflows/agent-sandbox-image.yml
           -> event       in {push, workflow_dispatch}
           -> conclusion  == success
           -> head_sha    == the provenance's vcs:revision
           -> head_branch == main
```

**Red, measured during planning (2026-09-10).** `AGENT_BASE_DIGEST` then pointed at the base
published by run `34376295042`, whose `head_branch` is `feature/containerization`. The chain held
at every other link — SBOM, provenance, workflow path, event, conclusion, `head_sha` — and failed
on `head_branch` alone. That is the assertion the whole D21 promotion exists to flip, and it is the
control that keeps a branch-triggered test publish from being consumed (criterion 3).

**Green, measured now (2026-09-29, on the build host).** Full run output below, from
`bash tests/acceptance/verify-reproducibility.sh`:

| Assertion | Result |
|---|---|
| SPDX SBOM on the pinned index | **327 packages** |
| `runDetails.builder.id` names a run of `OttawaCloudConsulting/agentic-ai` | run **34799978913** |
| provenance `vcs:revision` | `f3a7d2f3643cc3b13d55d730cdd6c6428363805d` |
| run `path` | `.github/workflows/agent-sandbox-image.yml` |
| run `event` | `push` |
| run `conclusion` | `success` |
| run `head_sha` == provenance `vcs:revision` | agrees (`f3a7d2f…`) |
| run `head_branch` | **`main`** |

Consumed digest: `sha256:e3ae687e1b432fb2e2fd78620f199b59692e776d7368948ea4196a729d266824`
(`compose/pins.env:167`), the **index** digest, so the SBOM and provenance manifests stay reachable
from what is pinned rather than hanging off a platform manifest the pin does not name.

**T45 — passed.** The whole suite reports **25 passed, 0 failed** across phases A–D, so the T45
result is not read in isolation: phase A holds that no `FROM` and no rendered profile `image:`
resolves to a mutable tag, phase B holds the build-allowlist containment below, and phase D holds
T39's static half. The same run passed on the second Mac on 2026-09-28 (§ SF-5 re-run results,
Test Command table), so the chain is verified from two hosts.

**Publish history, for the record.** Run `34652870008` (02.4 SF-4, PR #39) was the first
`main`-triggered publish and the point at which T45 first went green. Run `34799978913` (02.4 SF-5c,
PR #45) is the currently pinned one — the republish that moved `agent-base`'s OS packages onto the
dated bookworm main + security snapshots. Branch-triggered publishes continue and are for testing
only; `compose/pins.env:139-167` records that rule beside the pin it governs.

## R10.4 — the declared build allowlist, and the enforcement finding (SF-6)

**What is declared.** `images/build-allowlist.yaml` names every host the image builds reach
*outside* pack manifests, each with how the fetch is verified and which files reach it:

| Host | `verified_by` | Reached from |
|---|---|---|
| `registry-1.docker.io` | digest | `images/Dockerfile`, `images/mediator/Dockerfile`, `images/recorder/Dockerfile` |
| `ghcr.io` | digest | `images/Dockerfile`, `.github/workflows/agent-sandbox-image.yml` |
| `github.com` | sha256 | all three Dockerfiles (`yq` release asset) |
| `snapshot.debian.org` | gpg | all three Dockerfiles + `images/apt-pinned.sh` |
| `registry.npmjs.org` | version-only | `images/Dockerfile` |
| `storage.googleapis.com` | sha512 | `images/Dockerfile` (`agy` archive) |

Pack build hosts are **not** duplicated here; they stay in each pack's
`egress.build.allow_fqdns`. `deb.debian.org` was removed at 02.4 SF-5c, when `agent-base`'s
bootstrap — the last live-archive fetch site — moved onto the dated snapshot.

**What is checked.** `verify-reproducibility.sh` phase B asserts three things, and reports them
green today:

1. every build-time fetch site extracted from the Dockerfiles, `compose/pins.env` and the pack
   manifests resolves to a host in the **union** of this file and the selected packs' declared
   build hosts;
2. every declared host has at least one fetch site — no dead entries;
3. every `apt-get install` runs after the default apt sources have been replaced by the dated
   snapshot (Interface Contract 7) or via `images/apt-pinned.sh`.

Each direction carries a negative control that was run once and recorded: an undeclared host is
refused by the containment check, and an `apt-get install` placed ahead of the snapshot step is
refused by the snapshot-first check.

**The finding (R10.4, SHOULD — recorded, not closed).**

> **Builds are not network-confined to the declared list.** `images/build-allowlist.yaml` is a
> declaration checked statically against what the build *files* name. It is not compiled, and
> nothing enforces it at build time: builds run on the host build network (`packs/README.md:69-70`).
> A fetch the build files do not name — an `npm` lifecycle script reaching a fourth host, a
> transitive dependency's `postinstall` — is not caught by this mechanism and would not fail the
> build.

**The named enforcing mechanism, recorded as the review trigger** (feature plan Decision 5,
tradeoff callout 2). Option B, not built here: a `docker-container` buildx builder on an
`internal: true` network whose only route out is an allowlisting proxy seeded from this same file.
Its cost is a second proxy configuration, a builder lifecycle to manage, and proxy trust wired into
`apt`, `npm` and BuildKit's own `ADD` — real build work for a SHOULD on a one-workstation scope.

**Review trigger — build option B when either fires:**

1. **Q2 changes.** A second operator, a team or a CI-distributed artifact raises R10 from SHOULD
   toward MUST (`prd.md:247` names the same trigger).
2. **A build-time fetch is found outside the declared list** — by an SBOM diff, a proxy log, or a
   phase B failure that turns out to be a real undeclared reach rather than a stale declaration.

The list lives in `images/`, not `policy/`. `policy/` is compiler input and mediator build context,
and build-time egress must never reach `policy/resolved/` — `packs/README.md` states the same
separation as "`egress.build` is not `egress.runtime`".

## R11.2 — Linux-host portability assessment (SF-6)

R11.2 is a SHOULD: *runs on Linux hosts without architectural change*. Q2 settled deployment scope
as one workstation, so it is **assessed here, not exercised** — nothing in this project has been
run on a Linux host. What follows is a static reading of the tree, by construct, with file:line.
It is grounded in the sweeps actually run (`host.docker.internal`/`host-gateway`, `Darwin`/`uname`,
`brew`/`xcode-select`, BSD-vs-GNU shell idioms, `linux/arm64`/`TARGETARCH`, Docker Desktop and
VirtioFS references, Keychain references, `user:`/uid declarations in `compose/compose.yaml`), not
a line-by-line read of every file.

**Headline: the blocker is architecture, not operating system.** On an **arm64** Linux host the
tree is close to portable. On an **x86_64** Linux host it is not, and the gap is a pinning problem
rather than a design problem — every item in group A is a second, separately verified pin.

### A. Single-architecture pins (blocking on x86_64, no change on arm64)

| Construct | Location | What must change |
|---|---|---|
| `agy` archive is `linux-arm/cli_linux_arm64.tar.gz`, pinned by one SHA-512 | `compose/pins.env:17-19` | A second URL + SHA-512 for `linux_amd64`, selected by `TARGETARCH` |
| `git` `.deb` pinned by one SHA-256, the arm64 one | `compose/pins.env:134` | A second `.deb` hash; `images/apt-pinned.sh` verifies against the container's own dpkg architecture, so an amd64 build fails at that comparison (D21 already records this) |
| `gh` tarball path `gh_<version>_linux_arm64/` | `images/pack-install.sh:171,173,174` | Architecture-templated path + a second pack checksum (`packs/github-cli/pack.yaml:33`) |
| `helm` tarball path `linux-arm64/` | `images/pack-install.sh:188,190,191` | Same, against `packs/kubernetes/pack.yaml` |
| `terraform` `_linux_arm64.zip` | `packs/terraform/pack.yaml:34` | Second URL + checksum |
| node / go `linux-arm64` archives | `packs/language-runtimes/pack.yaml:44-45` | Second URLs + checksums |
| Published base is a **linux/arm64-only** index | `compose/pins.env:167`; `.github/workflows/agent-sandbox-image.yml:180` | An x86_64 host cannot consume the pinned digest **at all** — the index carries no matching platform. Needs `platforms:` widened *after* the pins above, not before (D21) |
| Publish runner | `.github/workflows/agent-sandbox-image.yml:114` (`ubuntu-24.04-arm`) | A matrix or a second job; this is the *last* change, not the first |

Two constructs are already architecture-correct and need nothing: `yq` selects by `TARGETARCH`
against two committed checksums (`images/Dockerfile:52-58`, and the same block in the mediator and
recorder Dockerfiles), and `NODE_BASE_DIGEST` is an **index** digest
(`compose/pins.env:141`), so `node:22-slim` resolves per platform rather than being narrowed to
arm64.

### B. Host toolchain — already portable, no change

`scripts/install-deps.sh` branches on `uname -s` at `:15,:21` and installs via Homebrew on Darwin
(`:25-27`) or `apt` on Linux (`:43`), including the Linux `sbx` path — `docker-sbx` package, Docker
Engine install, and the `kvm` group note (`:72-84`). This script is portable as written; it was
built that way rather than fixed here.

### C. Docker Desktop assumptions (one real behaviour change, the rest are narrative)

1. **Bind-mount ownership — the one item that changes behaviour.** Docker Desktop's VirtioFS fakes
   file ownership, which is why `:ro` is recorded as the only real control on the mounted host
   credential (R4.13, `README.md:293`, `images/bootstrap-auth.sh:330`,
   `compose/overrides/oauth-mount.bootstrap.yaml:32-33`). On Linux the bind mount carries the real
   host uid/gid, and the agent containers run as `user: "1000:1000"`
   (`compose/compose.yaml:163`). A Linux operator whose uid is not 1000 gets permission errors on
   the project mount. **Fix shape:** a `UID`/`GID` pair in `compose/pins.env` interpolated into
   `user:`, or a documented `--user "$(id -u):$(id -g)"`. This is the one place where R11.2's
   "without architectural change" is arguable — it is a new input, not a new component.
2. **Host modes become a control, which strengthens the design rather than breaking it.** R11.4
   (`REQUIREMENTS.md:313`) and R4.13 (`:142`) both reason from VirtioFS faking ownership. On Linux
   the host's mode bits are real inside the container, so the `:ro` mount gains a second control it
   does not have on macOS. No code change; the recorded rationale needs a Linux clause.
3. **Volume backup narrative.** `README.md:607-609` explains that no per-volume exclusion is
   possible because Docker Desktop keeps every named volume in one VM disk image; the same
   reasoning sits in `tests/acceptance/verify-pod-topology.sh:178`. On Linux, volumes are
   directories under `/var/lib/docker/volumes`, so a per-volume exclusion **is** possible. The
   assertion still holds, the reason changes.
4. **Bind-source reporting.** `tests/acceptance/verify-pack-composition.sh:1004` already accepts
   both the plain host path and Docker Desktop's `/host_mnt` prefix. No change.
5. **Default-route measurement.** `tests/acceptance/verify-egress-mediator.sh:396` asserts a
   property measured against "this Docker Desktop". It needs re-measuring on Linux Engine, not
   rewriting.
6. **Namespaced sysctl.** `compose/compose.yaml:245-261` prefers
   `net.ipv4.ip_unprivileged_port_start` over `cap_add: NET_BIND_SERVICE` so `cap_drop: ALL`
   survives. The sysctl is namespaced and supported by Linux Engine directly; the comment's
   "fallback if Docker Desktop's VM refuses it" clause is what becomes moot. No change.

### D. Credential narrative (a decision reopens, not a mechanism)

`claude`'s host credential is macOS-Keychain-resident and therefore *not portable* into a Linux
container — recorded as settled at `README.md:187,256-258`, `images/bootstrap-auth.sh:300`,
`REQUIREMENTS.md:142` (R4.8), `docs/RESEARCH_FINDINGS.md:98` and `docs/OPTIONS_ANALYSIS.md:296,357`.
On a **Linux host** that credential is a plain file (`~/.claude/.credentials.json`, mode 0600), so
"not portable" stops being true and mode D (mount the host credential) becomes technically
available for `claude`. R4.8 would then need a recorded per-agent decision rather than being
foreclosed by the platform. Nothing to change in code; a settled decision would have to be re-taken.

### E. Documentation (mechanical)

`README.md:87-89` states the prerequisite as macOS 26 on Apple silicon with Docker Desktop
installed by hand. A Linux bring-up needs its own prerequisites block (Docker Engine + the Compose
plugin, `install-deps.sh` without the Homebrew path).

### Verdict

**R11.2 is not met today, and the distance is measurable rather than architectural.** On arm64
Linux: one real change (C1, the uid/gid input) plus documentation. On x86_64 Linux: eight
second-pin changes (group A) in the order D21 states — pins first, `platforms:` second, runner
label last — plus C1 and the documentation. No component is redesigned, no boundary moves, and the
enforcement architecture (mediator, resolver, policy compiler, audit sink) is Linux-native already
since it runs inside the containers.

## Proposed architecture edits — recorded, not applied (SF-6)

`/build` does not edit Gate artifacts, so both edits below are recorded here as exact replacement
text for an authority that may apply them — the milestone consolidation pass or `/milestone`
revision. Neither is applied by this feature. Same convention 02.3 used for its proposed T32
amendment (`docs/records/mcp-inventory.md`).

### Edit 1 — D21's promotion trigger is Milestone 02, not project completion

**APPLIED 2026-09-30, by the operator's instruction, after Feature 02.5's close-out.** All three
anchors below were replaced verbatim in `.project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md`
(the D21 row's `Decision` and `Alternatives` cells, and § Reproducibility). This feature recorded the
text and did not apply it; the design authority did.

**Why.** D21 and § Reproducibility both say the workflow moves to `main` "on project completion".
The Gate 3 amendment moved that trigger to Milestone 02, and 02.4 SF-4 executed it: the workflow
has published from `main` since run `34652870008`, with the project far from complete. The document
now describes a state that is two milestones out of date, and T45 — which asserts `head_branch ==
main` — would read as premature against it.

**Anchor 1: `.project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md:69`, the D21
row, `Decision` cell.** Current text (first sentence of the cell):

> **The base image is built by GitHub Actions and published to GitHub Packages (GHCR), consumed by
> digest.** Builds run from the working branch during the project and move to `main` on completion.

Replacement text:

> **The base image is built by GitHub Actions and published to GitHub Packages (GHCR), consumed by
> digest.** Builds ran from the working branch until Milestone 02; the promotion trigger is
> **Milestone 02, not project completion** (Gate 3 amendment, executed at 02.4 SF-4). The workflow
> publishes from `main`; branch-triggered publishes continue **for testing only**, and T45
> (`tests/acceptance/verify-reproducibility.sh` phase C, asserting the pinned digest's run has
> `head_branch: main`) is the control that keeps one from being consumed.

**Anchor 2: same file, the D21 row, `Alternatives` cell, final sentence.** Current text:

> The promotion to `main` is the stated completion trigger

Replacement text:

> The promotion to `main` was originally the project-completion trigger; the Gate 3 amendment moved
> it to Milestone 02

**Anchor 3: same file, `### Reproducibility`, second sentence.** Current text:

> During the project the workflow builds from the working branch and those images are for testing
> only; on project completion the workflow moves to `main`, which is the point at which a published
> digest becomes usable for real work.

Replacement text:

> The workflow built from the working branch until Milestone 02 and those images were for testing
> only; the Gate 3 amendment moved the promotion trigger to **Milestone 02**, executed at 02.4
> SF-4. The workflow now publishes from `main`, which is what makes a published digest usable for
> real work. Branch-triggered publishes continue for testing; nothing consumes one, and T45 is the
> mechanical control on that.

### Edit 2 — the GitHub CLI pack exists; the inventory and file tree still say it does not

**Why.** 02.3 built all three remaining packs. The component inventory still says only
`language-runtimes` is built, and the file tree omits `packs/github-cli/` entirely — an operator
reading the tree would not know the directory exists.

**Anchor 1: same file, line 87, the `Tool packs` inventory row, `Responsibility` cell, final
sentence.** Current text:

> Only `language-runtimes` is built (01.5 SF-1); Terraform, Kubernetes and GitHub CLI arrive at 02.3
> and AWS CLI at 03.3

Replacement text:

> `language-runtimes` was built at 01.5 SF-1; `terraform`, `kubernetes` and `github-cli` were built
> at 02.3, each backing a named use-case profile. AWS CLI arrives at 03.3

**Anchor 2: same file, the file tree `packs/` block (lines 350-356).** Current text:

> ```
> ├── packs/
> │   ├── README.md                  # manifest schema; the no-runtime-egress decision; the checksum
> │   │                              #   residual (01.5 Deviation 13) and what the removals cost
> │   ├── language-runtimes/pack.yaml # BUILT (01.5 SF-1). Node, Python, Go; build-time only
> │   ├── terraform/pack.yaml        # (not yet built — 02.3)
> │   ├── kubernetes/pack.yaml       # (not yet built — 02.3)
> │   └── aws-cli/pack.yaml          # (not yet built — 03.3)
> ```

Replacement text:

> ```
> ├── packs/
> │   ├── README.md                  # manifest schema; the no-runtime-egress decision; the checksum
> │   │                              #   residual (01.5 Deviation 13) and what the removals cost
> │   ├── language-runtimes/pack.yaml # BUILT (01.5 SF-1). Node, Python, Go; build-time only
> │   ├── terraform/pack.yaml        # BUILT (02.3). terraform CLI; runtime egress to
> │   │                              #   registry.terraform.io + releases.hashicorp.com
> │   ├── kubernetes/pack.yaml       # BUILT (02.3). kubectl + helm; NO runtime egress -- cluster
> │   │                              #   reach needs a separate, not-shipped, per-cluster pack
> │   ├── github-cli/pack.yaml       # BUILT (02.3). gh CLI; runtime egress to api.github.com +
> │   │                              #   github.com, extended from codex's 01.1 base to all three
> │   └── aws-cli/pack.yaml          # (not yet built — 03.3)
> ```

## Carried findings — disposition (SF-6)

Operator decision, 2026-09-29: SF-6 records only. No code or README behaviour edit lands under a
records close-out; each item below is routed rather than patched.

| Finding | Disposition |
|---|---|
| **F-a** — session recording lost; revision 2 should require the recording to be confirmed live before the run proceeds | **Routed to `/milestone`** as a procedure amendment. Not applied here: the amendment belongs with the procedure the next clean-environment or drill run actually follows, and no such run is scheduled under this feature |
| **F-b** — README step 2's `git clone` gives no location; runbook revision 2 says "from `~`" | **Routed.** A one-line README clarification. No result depends on it (Stage 2's `ls -d ~/agentic-ai` ran before the clone, so the clean-state attestation stands) |
| **F-c** — all three agent containers exited 0 within one second of `up`, mediator and recorders staying up | **Unresolved, routed to `/milestone` as a real README/behaviour question.** The README says containers "start unauthenticated rather than failing" but does not say whether they then stay running. Whether F-h's detached `up -d` was involved was never established. This is the one carried item that may be a defect rather than a wording gap |
| **F-d** — `bootstrap-auth` prints `(codex, oauth-interactive) starting paste-back login.` and then runs device-code login (`images/bootstrap-auth.sh:261`, against `codex login --device-auth` at `:278`) | **Routed.** A one-line message fix. The README and the implementation both say device code; only the message is wrong, so no behaviour is at issue |
| **F-e** — `agy`'s key validity unverified; `bootstrap-auth` checks only that `GEMINI_API_KEY` is set | **Closed on the operator's accepted-as-pass decision of 2026-09-28**, recorded as accepted on that basis, not as a verified pass. No further action here |
| **F-f** — every profile build prints a `CODEX_HOME` path warning; build exit 0 | **Routed.** Cosmetic, but it appears in every clean build. A fix touches the image and would invalidate the fingerprint references taken at X₂, which is why it is not done under a records close-out |
| **F-g**, **F-h**, **F-i** — run-conduct deviations | **Closed as recorded.** They are why T39 is attestation rather than step-log evidence (§ SF-5 re-run results, Verdicts). Nothing further to do; the T39 caveat carries them |

## Criterion → evidence

Feature 02.4's eleven acceptance criteria, each against what actually shows it.

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | T45 — consumed base resolves to a `main`-built, CI-published, SBOM'd digest | **Met** | § T45 above: phase C, 8/8 assertions, run `34799978913`, `head_branch: main`, 327-package SBOM. Red direction measured at planning against run `34376295042` |
| 2 | No profile consumes a mutable tag (T45, R10.2) | **Met** | `verify-reproducibility.sh` phase A, 6/6 including the negative control that refuses an unpinned `FROM node:22-slim`. `NODE_BASE_DIGEST` (`compose/pins.env:141`) pins `images/Dockerfile:44,82`; the workflow uses buildx's own `sbom: true` rather than an external scanner action |
| 3 | D21 promotion (Gate 3 amendment) | **Met** | `feature/containerization` landed on `main` by PR #39 (D21 promotion, operator-merged — `/build` prepared it and did not merge it), repinned by PR #40 and closed out by PR #41. The SF-5c republish and its repin landed as PR #45 and PR #46. `compose/pins.env:139-167` names the run, ref and commit. The D21 trigger amendment is recorded above as proposed text, not applied by this feature; **the operator applied all three of its anchors on 2026-09-30** |
| 4 | T18 — clean rebuild, no manual steps | **Met** | § SF-5 re-run results (2026-09-28): four clean fingerprint diffs across a Compose v2.38.2 → v5.3.1 gap, and the Test Command at `composite exit=0` with all nine scripts green on a factory-reset second Mac. Both halves of the criterion, from captured output. R11.1 discharged |
| 5 | T39 — fresh operator, `docker compose` the only entry point | **Partly met — statically yes, operationally on attestation** | Static half: `verify-reproducibility.sh` phase D, green (one recorded exception, `scripts/run-shadow-run-sf5.sh`, a boundary-verification harness). Operator half: **closed on operator attestation, not step-log evidence** — see F-a, F-g (ii), F-h |
| 6 | Onboarding covers first-run auth for all three agents (R12.6) | **Met** | `README.md` § First-run authentication: `claude` paste-back, `codex` device code, and `agy`'s `exec -e GEMINI_API_KEY` / `run --rm -e` path with the paid-tier constraint carried. Exercised live on the second Mac for all three, with F-d (wrong label) and F-e (validity unverified) recorded against it |
| 7 | R12.3 — allowlist change procedure, naming the reviewer | **Met** | `README.md` § "Changing the allowlist (R12.3)": the six-step chain (R14.1 record → edit → `compile-policy-build.sh` → drift gate → mediator rebuild → `validate-boundary.sh`), landing on `main` by PR reviewed by the **security reviewer** role. Recorded there as a documented procedure, not a mechanism — no CODEOWNERS, no branch protection |
| 8 | R10.6 — agent version update path | **Met** | `README.md` § "Updating an agent version (R10.6)": the six-step procedure including `agy`'s by-hand manifest resolution and the mandatory `BOUNDARY_SHADOW_RUN=1` re-verification. `docs/records/agent-verification.md` carries the pointer; `check_pin_agreement()` in `verify-pod-topology.sh` enforces the pins/record agreement |
| 9 | R10.4 — declared build allowlist, statically checked | **Met as declared + checked; enforcement recorded as absent** | § R10.4 above. `images/build-allowlist.yaml` + phase B (7/7, both negative controls). The finding and its two-part review trigger are recorded, per Decision 5 option A |
| 10 | Records | **Met by this sub-feature** | This file: T45 chain and results, R10.4 finding and trigger, R11.2 assessment, the two proposed architecture edits as replacement text, and this table. T18/T39 results in § SF-5 re-run results |
| 11 | The R12.8 notice is **not** lifted here | **Held (and later lifted elsewhere)** | Held as stated at 02.4: `README.md:17-19` read "**This pod is not yet cleared for real work**", naming 02.5 alone as outstanding. **The operator lifted the notice for every non-AWS profile on 2026-09-30**, after 02.5 closed out and after both amendments were accepted and applied — not by this feature, and not by 02.5 either. It stands for AWS-loading profiles, which wait on Milestone 03 |

**Not edited by this feature** (feature plan § Documentation, explicit):
`.project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md`, `REQUIREMENTS.md`,
`prd.md`. `prd.md` § Outputs "Image digest + SBOM" status is left for the milestone consolidation
pass for the same reason.
