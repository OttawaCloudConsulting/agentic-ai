# Reproducibility, Provenance and Onboarding — Records

**Requirement.** Feature plan `reproducibility-provenance-and-onboarding.md` §Documentation:
this file carries T45/T18/T39 results, the R10.4 build-allowlist statement, the R11.2 assessment,
the proposed architecture edits, and the criterion → evidence table.

**Status.** This file currently carries only SF-5's runbook, written before the clean-environment
run per Decision 3/Contract 6. The remaining sections (T45 chain and results, R10.4 finding, R11.2
assessment, T18/T39 results, proposed architecture edits, criterion → evidence table) are SF-6's
close-out and land in a later commit.

## Clean-environment procedure (SF-5)

This is the runbook for T18 (clean rebuild) and T39 (fresh operator), run together as one
clean-environment session on a **second physical Mac** (macOS 26, Apple silicon), per criteria 4
and 5 and Decision 3. The run follows this procedure verbatim; a deviation from it is a finding
(Edge Case 12), not a silent adjustment.

**Reference commit X.** X is the commit on `main` that carries this runbook and
`scripts/fingerprint-environment.sh` — the second Mac's `git checkout X` must be able to run the
fingerprint script the procedure calls for. Concretely: X is the merge commit of the PR that lands
this feature's SF-5 changes on `main` (the same operator-gated promotion path SF-4 used), recorded
here once merged. It is **not** the SF-4 commit alone, because SF-4 predates this script.

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
