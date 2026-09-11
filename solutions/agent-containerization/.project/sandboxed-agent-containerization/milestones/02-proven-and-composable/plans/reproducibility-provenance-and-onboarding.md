# Feature Plan: Reproducibility, provenance and onboarding

**Milestone:** 02 - Proven and Composable
**Feature:** 02.4: Reproducibility, provenance and onboarding
**Status:** Planned
**Date:** 2026-09-10

## Summary

This feature turns SC-8 from a claim into evidence, and makes the pod usable by an operator who did
not build it. It pins the build inputs that still move. The main one is `FROM node:22-slim`, which
every local agent build currently resolves by mutable tag, so T45 fails today. It then **promotes
D21's publish workflow to `main`** under the amendment approved at Gate 3. `main` carries none of
this solution yet, so in practice that means landing `feature/containerization` on `main`,
republishing the base from there, and repinning `compose/pins.env` to that digest.

T45 is verified mechanically. The pinned digest's provenance names the GitHub Actions run that
built it, and the GitHub API names that run's trigger branch — both measured against today's pin
during planning. T18 (clean rebuild) and T39 (fresh operator) run as **one clean-environment
session**. A new operator follows the README verbatim on macOS 26 / Apple silicon, which discharges
R11.1 as an owned check. "Functionally identical" is shown by diffing an environment fingerprint
rather than image digests.

The onboarding gaps the codebase scan found are fixed as documentation, not new mechanism:

- three identity commands missing from Bring-Up;
- two conflicting entry-point forms;
- no `agy` key path under `up`;
- no reviewer in the allowlist procedure;
- no agent-version update path.

R10.4 gets a declared, statically checked build allowlist. R11.2 is assessed, not exercised. Two
architecture edits are recorded for an authority that may apply them.

## Acceptance Criteria

Refined from the milestone README with facts established by the codebase scan and by measurement
during planning.

1. **T45 — the consumed base resolves to a `main`-built, CI-published digest with an SBOM.** For
   `AGENT_BASE_DIGEST` in `compose/pins.env`, `verify-reproducibility.sh` checks:
   - the index carries an SPDX SBOM with at least one package;
   - it carries SLSA provenance whose `runDetails.builder.id` is a run of
     `OttawaCloudConsulting/agentic-ai`;
   - the GitHub API reports that run as:
     - `path` `.github/workflows/agent-sandbox-image.yml`;
     - `head_branch` `main`;
     - `event` `push` or `workflow_dispatch`;
     - `conclusion` `success`;
     - `head_sha` equal to the provenance's `vcs:revision`.

   **Measured today:** run `34376295042` reports `head_branch: feature/containerization`, so T45
   fails on exactly that assertion until SF-4.
2. **No profile consumes a mutable tag (T45, R10.2).**
   - Every `FROM` in `images/Dockerfile` and `images/mediator/Dockerfile` is one of: `scratch`, a
     stage name, or a digest-pinned reference whose digest ARG has a `sha256:` value in
     `pins.env`.
   - `node:22-slim` at `images/Dockerfile:40` (`pack-plan`, built locally on every agent build) and
     `:78` (`agent-base`, built by CI) is pinned by `NODE_BASE_DIGEST`.
   - Every Compose `image:` in every rendered profile is either paired with `build:` (a local
     `:local` output, never pulled) or digest-pinned.
   - The SBOM generator the publish job runs (`docker/buildkit-syft-scanner@stable-1`, measured in
     today's provenance materials) is pinned by digest. The job holds `packages: write`, and the
     workflow's own rule is that nothing it runs is consumed by movable tag.
3. **D21 promotion (Gate 3 amendment).**
   - `feature/containerization` lands on `main` by pull request. This is an operator action; `/build`
     prepares the PR and does not merge it.
   - The workflow publishes from `main`.
   - `pins.env` is repinned to that digest, and its comment block names the run ID, commit and ref.
   - Branch-triggered publishes continue, **for testing only**, and T45 is the control that keeps
     one from being consumed.
   - The D21 trigger amendment is recorded as proposed text for an authority that may edit
     `docs/ARCHITECTURE_AND_DESIGN.md`.
4. **T18 — clean rebuild, no manual steps (SC-8, R10.1, R11.1).**
   - The rebuild runs on a **second physical Mac** (macOS 26 / Apple silicon) in a clean state: no
     images, no build cache, no volumes, no identity material, fresh clone of `main`. It follows the
     runbook written before the run (SF-5).
   - It covers every shipped profile, the final 02.3 pack set.
   - **T18 passes only if both hold:**
     - the `fingerprint-environment.sh` output for each profile diffs clean against the reference
       taken on the build host at commit X. The comparison excludes the `commit` field, and the
       record lists both commits;
     - the **Test Command passes on the second Mac**. A matching fingerprint shows the same things
       are installed; the passing composite shows the pod behaves the same way.
   - **A manual step is defined (Decision 3)** as any action that is not a copy-pasteable command
     documented in the README, any hand-edit of a committed file, or any use of knowledge the README
     does not supply.
   - Secret material (identity issuance, provider credentials, first-run login) is an
     operator-supplied input by design. The CA key is never committed. Each such input is a
     documented command, not an exemption.
   - R11.1 is recorded as discharged by this run.
5. **T39 — fresh operator, `docker compose` the only entry point (R12.9, R12.1).**
   - Performed in the same session as T18.
   - Statically, no committed script outside `tests/` invokes `docker compose … up|start|run`.
   - The README carries exactly one `up` form: `--env-file compose/pins.env -f compose/compose.yaml
     -f compose/overrides/<profile>.yaml up --build --force-recreate`.
6. **Onboarding covers first-run authentication for all three agents (R12.6).**
   - `claude` paste-back and `codex` device code each get a command block.
   - `agy`'s default `apikey` cell gets its delivery path under the running pod. Compose wires no
     `GEMINI_API_KEY` (`images/bootstrap-auth.sh:43`), so the README documents `exec -e
     GEMINI_API_KEY` / `run --rm -e`, taken from the host environment and never written to a file.
   - The paid-tier constraint from `third-party-assessments.md` is carried.
   - The AWS SSO half is Milestone 03.
7. **R12.3 — allowlist change procedure, naming the reviewer.** The README procedure chains:
   - the R14.1 record for any new third party (02.3's `lint-policy.sh` anchor check);
   - the edit;
   - `compile-policy-build.sh`;
   - the drift gate;
   - the mediator rebuild;
   - re-validation (`validate-boundary.sh` for the affected profile).

   The change lands on `main` by pull request reviewed by the named reviewer role. There is no
   schema field and no CODEOWNERS — CODEOWNERS is unenforced without branch protection.
8. **R10.6 — agent version update path.** A documented procedure:
   1. Bump `pins.env`.
   2. Update `docs/records/agent-verification.md`, which `check_pin_agreement` enforces.
   3. For `agy`, resolve the manifest URL and SHA-512 by hand — it has no version flag.
   4. Rebuild.
   5. **Re-verify the policy** with 02.2's `BOUNDARY_SHADOW_RUN=1 validate-boundary.sh`.
   6. Amend the allowlist through the R12.3 procedure where the shadow run shows a new host.
9. **R10.4 — declared build allowlist, statically checked (Decision 5).**
   - `images/build-allowlist.yaml` declares every host the image builds reach outside pack
     manifests: registries, Debian archives, npm, GitHub releases and the `agy` bucket.
   - Every fetch site in the Dockerfiles, `pins.env` and the pack manifests resolves to a host in
     the union of that file and the selected packs' `egress.build.allow_fqdns`.
   - Every declared host has at least one fetch site.
   - **That builds are not network-confined to that list is recorded as a finding**, with the
     enforcing mechanism named as its review trigger.
10. **Records.**
    - An R11.2 assessment: every construct needing change on a Linux host, with file:line.
    - The two proposed architecture edits: the D21 trigger amendment, and the GitHub CLI pack in
      the component inventory and file tree.
    - T45, T18 and T39 results.

    All in `docs/records/reproducibility.md`.
11. **The R12.8 notice is not lifted here.** 02.2 SF-6 owns its current-state wording, and the
    milestone Definition of Done lifts it.

## Approach

### The starting position

Measured or read during planning, not assumed:

- **The workflow already triggers on `main`** (`.github/workflows/agent-sandbox-image.yml:38-41`),
  but `main` contains no `.github/` and no `solutions/agent-containerization/`.
  - `feature/containerization` is 113 commits ahead and 0 behind.
  - `main` is unprotected, has no tags and no CODEOWNERS.
  - The repository is public, and so is the GHCR package, so a clean machine pulls anonymously.
- **Today's pin is a branch build.** `pins.env:99` → run `34376295042`, commit `bdabf72`. Anonymous
  `imagetools inspect` shows:
  - `runDetails.builder.id =
    https://github.com/OttawaCloudConsulting/agentic-ai/actions/runs/34376295042/attempts/1`;
  - `vcs:revision = bdabf72…`;
  - label `org.opencontainers.image.version = feature-containerization`;
  - an SPDX-2.3 SBOM with 327 packages;
  - resolved dependency `node@22-slim` → `sha256:83f487e0…` (arm64).

  `api.github.com/…/actions/runs/34376295042` returns `head_branch: feature/containerization`,
  `event: push`.
- **Mutable or moving inputs:**

  | Input | Location | Consumed |
  |---|---|---|
  | `FROM node:22-slim` | `images/Dockerfile:40` | Locally, every agent build |
  | `FROM node:22-slim` | `images/Dockerfile:78` | By CI |
  | Unpinned `apt-get install ca-certificates curl bubblewrap iproute2 xz-utils` from the rolling sources | `images/Dockerfile:82-84` | In `agent-base`, before `apt-pinned` swaps sources |
  | Mediator packages from the live trixie archive — version-pinned, but point releases supersede in place | `images/mediator/Dockerfile:163` | Mediator build |
  | `npm install -g` pins the top-level version only | `images/Dockerfile:239`, `:266` | Agent builds |

- **Onboarding drift:**
  - README Bring-Up (`:87-93`) lists five of the eight identity commands; `client claude` and
    `credential codex|agy` appear only in `mediator/identity/README.md:123-125`.
  - The entry point appears as `up --build --force-recreate` (`:14-16`) and as `up -d --build`
    (`:105-107`).
  - The status paragraph (`:4-10`) predates 01.3.
  - `agy` has no key path under `up`.
  - `install-deps.sh:87` always installs `sbx`, which needs `sbx login` — an account-gated step the
    runtime does not need (R11.3).

### Decision 1 — promotion is a merge of the working branch into `main` *(tradeoff callout 1)*

"Promote the workflow to `main`" cannot be a workflow edit: the workflow already lists `main`, and
`main` has nothing for it to build. The alternatives:

| Option | What it proves | Cost |
|---|---|---|
| **A. PR `feature/containerization` → `main` (recommended)** | The published base is built from the reviewed default branch. T45's `head_branch == main` becomes meaningful, and R12.3's reviewed-PR procedure has a branch to target | An outward-facing merge of 113 commits into a public default branch. It includes every solution change on the branch, so the operator reviews the diff. Work on 02.5 continues on the branch and merges again |
| **B. Release tag on the working branch** (`agent-sandbox/v*`) with publish gated on tag pushes | "Equivalent release ref" as the milestone README permits. No merge | A tag marks a commit; it does not mean the commit was reviewed. T45 would check `head_branch` equal to a tag, a weaker claim than "the default branch", and D21's stated end state stays unmet |

**Sequence under A.**
1. SF-1–SF-3 land on the branch.
2. The operator opens and merges the PR.
3. `main`'s push publishes a new base.
4. The operator copies that digest into `pins.env`, recording run ID, commit and ref.
5. The repin reaches `main` through a second PR. This is the operator's call — a direct commit is
   possible because `main` is unprotected, but it bypasses the R12.3 review path.

The repin push republishes again. Nothing auto-repins, so that is registry noise, not a loop.

Branch-triggered publishes are **kept** for testing. SF-1's own base change must be exercised before
it can reach `main`. T45 makes consumption of a branch build fail rather than relying on a workflow
restriction.

### Decision 2 — T45 binds digest → run → trigger branch

The chain uses only what the registry and GitHub already publish:

- The pinned index digest gives the provenance attestation reachable from it.
- The attestation gives `runDetails.builder.id`, the run URL.
- The public runs API gives `head_branch`, `event`, `path`, `conclusion` and `head_sha`.

`head_sha` is cross-checked against the provenance `vcs:revision`. Binding by **run** rather than by
commit is deliberate. A fast-forwarded commit is built twice, once by the branch push and once by
the `main` push, producing two digests from one commit. Only the `main` run's digest passes.

The provenance is unsigned (workflow `:118-125`). Its integrity rests on `packages: write` being
held only by that job. This is recorded, not changed, because R10.7's signing is a MAY.

Rejected alternatives:
- **The `image.version` label alone** — it is a metadata-action convenience, not a trigger fact.
- **`git merge-base --is-ancestor`** — cannot distinguish the two builds of a fast-forwarded
  commit.

### Decision 3 — "no manual steps" gets an operational definition, and T18 and T39 share one run

Without a definition, T18 cannot be falsified. Identity issuance and first-run login cannot be
committed, because the CA key and credentials never enter version control.

The definition in criterion 4 makes the **README the contract**. A step is manual if it is:
- undocumented;
- a hand-edit of a committed file;
- dependent on knowledge the README does not give.

T39 asks the same question from the operator's side, so one clean-environment session answers both.
The operator (review assumption 2) follows the README top to bottom and logs:
- every command run;
- every deviation, each of which is a finding;
- every wait.

A finding is fixed in the README and the affected section re-run. It is not waived.

**Docker Desktop and `git` (via the Xcode command-line tools)** are the stated prerequisites of a "clean machine".
Docker Desktop cannot be installed by script (`install-deps.sh:43`). The machine is otherwise empty.

### Decision 4 — "functionally identical" is a fingerprint diff

Local image layers are not bit-reproducible: they carry timestamps, and npm writes metadata. A
digest comparison would fail for reasons SC-8 does not care about. `agent-base` needs no comparison,
because it is pulled by digest.

For each profile, `scripts/fingerprint-environment.sh` emits a normalised JSON document covering:
- agent and tool versions;
- sorted `dpkg-query` output hash;
- hashes of `/usr/local/bin` and the pack install roots;
- `npm ls -g --all` tree hash;
- mediator daemon versions and package hash;
- resolved-policy hash;
- hash of the rendered `docker compose config`, with the checkout root normalised to `<ROOT>`.

The fingerprint half of T18 passes when the build host's and the second Mac's documents diff clean
with the `commit` field excluded (`jq -S 'del(.commit)'`). The record lists both commits. Excluding
it lets a README-only fix land between the reference and the re-run without invalidating the
references, since build inputs are unchanged. A mechanism change needs new references and a full
clean re-run (SF-5). The fingerprint is half of T18; the other half is the Test Command passing on
the second Mac (criterion 4). The npm tree hash is what surfaces floating transitive dependencies. They are recorded as a
finding if they differ, not pre-emptively locked.

### Decision 5 — R10.4 is declared and statically checked, and enforcement is recorded as absent *(tradeoff callout 2)*

Builds run on the host build network (`packs/README.md:69-70`). The only declared build list is one
pack's data-only `egress.build.allow_fqdns`, which nothing enforces.

| Option | What it proves | Cost |
|---|---|---|
| **A. Declare + static check (recommended)** | Every fetch site the build files name resolves to a declared host, and the list has no dead entries | Does not stop an undeclared fetch at run time. A `postinstall` script reaching elsewhere would not be caught. Recorded as a finding against a SHOULD |
| **B. Enforce** | A `docker-container` buildx builder on an `internal: true` network whose only way out is an allowlisting proxy seeded from the same file | A second proxy config, a builder lifecycle, and proxy trust for `apt`/`npm`/`ADD` inside BuildKit. It is real build work on a feature the milestone sized as small, for a SHOULD on a one-workstation scope (Q2) |

Under A the review trigger for B is recorded: a second operator (Q2 changing), or a build-time fetch
found outside the list. The list lives in `images/`, not `policy/`. `policy/` is compiler input and
mediator build context, and build-time egress must never reach `policy/resolved/`
(`packs/README.md`, "`egress.build` is not `egress.runtime`").

### Decision 6 — pins ride the republish; two reproducibility fixes were offered as cuttable and kept

Pinning `node:22-slim` at `:78` changes `agent-base`, so it must precede the `main` publish or it
forces a second promotion cycle. Two further items are real reproducibility defects but are **not**
demanded by a stated criterion. Each was offered as a separately cuttable item, and **both were kept at Gate 4** (review assumption 4):

- **(kept at Gate 4) SF-1b — base apt onto the snapshot.** `:82-84` installs five packages from rolling
  sources before `apt-pinned` swaps them. Each republish can differ, and the fingerprint would show
  it only as a diff with no cause. `apt-pinned` already exists, so the move is small, and it rides
  the same republish.
- **(kept at Gate 4) SF-1c — mediator apt onto a dated trixie snapshot.** Version pins against the live
  archive mean a future clean rebuild **fails** once a point release supersedes the pinned version.
  It fails rather than drifts, because the pin is exact. This is a T18 defect on a reachable path,
  but only in the future. Cutting it records the risk and T18 still passes today.

`npm` transitive pinning is **not** included. Decision 4's fingerprint detects it, and a lockfile
per agent is a mechanism change no criterion asks for.

### Decision 7 — onboarding is documentation; nothing new is wired

- **`agy` key:** documented as `docker compose … exec -e GEMINI_API_KEY agy …` and `run --rm -e
  GEMINI_API_KEY agy bash /usr/local/bin/bootstrap-auth agy`, from the host shell. A Compose secret
  would be 02.3's credential-delivery pattern applied to a provider key, which is a mechanism change
  outside this feature.
- **Reviewer (R12.3):** a named *role* recorded in the README and `docs/records/reproducibility.md`
  (review assumption 3). No schema field.
- **`sbx`:** `install-deps.sh` installs it only with `--with-sbx`. It is a discovery tool (D17), not
  a runtime dependency, and its `sbx login` would be a manual, account-gated step on a clean machine
  (R11.3).
- **Identity commands:** the README lists all eight in order, with the listener IPs copied from
  `compose.yaml`'s `ipam` blocks. `verify-reproducibility.sh` checks both agreements: the README
  against `mediator/identity/README.md`, and the README IPs against `compose.yaml`. No `all`
  subcommand is added.

## Sub-Features

Order is load-bearing: pins before the `main` publish, docs before the merge, the clean run after
the repin.

- [x] **SF-1: Pin the remaining mutable inputs; branch republish for testing.**
  - `NODE_BASE_DIGEST` (the index digest) in `pins.env`, consumed at `images/Dockerfile:40` and
    `:78`. The global ARG has no default, like `AGENT_BASE_DIGEST`.
  - Compose `build.args` for the three agent services pass it, and the workflow's pin-loading loop
    and `build-args` carry it.
  - ~~The workflow's `sbom:` input pins the syft scanner by digest.~~ Not applicable as
    written: the workflow already uses buildx's own `sbom: true` attestation (01.5
    SF-6b, Edge Case 13), not `docker/buildkit-syft-scanner`. No third-party scanner
    reference exists to pin. `verify-reproducibility.sh` phase A asserts this fact
    instead, so a future switch to an external scanner does not silently go unpinned.
  - **SF-1b (kept at Gate 4):** base apt onto the snapshot through `apt-pinned`.
  - **SF-1c (kept at Gate 4):** mediator apt onto a dated trixie snapshot.
  - Push; the branch publishes; repin `pins.env` to the branch digest *for testing*; run the
    composite.
  - Create `verify-reproducibility.sh` with **phase A** (pins and mutable tags).
  - Size: 4-5 files plus one CI round trip.
- [x] **SF-2: `verify-reproducibility.sh` phases B-C, and the declared build allowlist.**
  - Phase B: `images/build-allowlist.yaml` and the static fetch-site check.
  - Phase C: T45 per Decision 2 — SBOM, provenance, run API.
  - SF-2 closes with phase C failing **only** on `head_branch` (and the label), and that expected
    red is recorded. Every other T45 assertion must pass against the SF-1 branch digest.
- [x] **SF-3: Onboarding and procedures.**
  - README Bring-Up rewritten as one ordered sequence: prerequisites → `install-deps.sh` → the
    eight identity commands → the one `up` form → first-run auth for three agents.
  - The status paragraph is corrected to current state without lifting the R12.8 notice. It is
    coordinated with 02.2 SF-6's wording.
  - Add the R12.3 allowlist procedure with the reviewer role, and the R10.6 agent-update path.
  - `install-deps.sh --with-sbx`.
  - `verify-reproducibility.sh` **phase D**: no wrapper, a single `up` form, the identity-command
    and IP agreement, and `--env-file` on every README Compose invocation.
  - Documentation-heavy, 3 files.
- [ ] **SF-4: Promotion to `main` (operator-gated) and repin.**
  - `/build` prepares the PR description: scope, the D21 amendment, and what merging publishes.
  - **The operator merges.** Capture the `main` run's digest.
  - Repin `pins.env` with a run/commit/ref comment, through PR per Decision 1.
  - Phase C goes green, and the full composite is re-run against the `main` digest.
  - Record the D21 proposed amendment text.
  - Little code; the long pole is operator wall-clock.
- [ ] **SF-5: T18 + T39 clean-environment run on a second physical Mac.**
  - `scripts/fingerprint-environment.sh`.
  - **Write the runbook first.** Before the run, `docs/records/reproducibility.md` gains a
    "Clean-environment procedure" section. The run follows it, and a deviation from it is a
    finding. It covers five stages:
    1. **Reference, on the build host.** At the SF-4 commit X, build every shipped profile and
       fingerprint each one. Carry the JSON files to the second Mac out-of-band (AirDrop or USB).
       They hold only versions and hashes. Do not commit them first, because that would move `main`
       past X.
    2. **Clean-state attestation, on the second Mac** (test instrumentation, not README steps):
       - `sw_vers` shows macOS 26.x and `uname -m` shows `arm64`;
       - Docker Desktop is freshly installed or factory-reset, and its version is recorded;
       - `docker images`, `docker volume ls` and `docker buildx du` are empty;
       - there is no existing clone and no `mediator/identity/`. The build host's CA key is never
         copied across; fresh identity issuance is part of the test.
    3. **T39 + T18.**
       1. Start the session log under the rules in Edge Case 16.
       2. `git clone`, then `git checkout X`. The checkout is test instrumentation.
       3. Follow README Bring-Up verbatim, including first-run auth for all three agents in the
          second Mac's browser.
       4. Build every profile with the README's profile-switch recipe and fingerprint each one.
       5. Run the **Test Command** on the second Mac.
    4. **Compare and record, on the build host.** Carry back the fingerprints, the cleaned step log
       and the Test Command output, so the second Mac never needs GitHub credentials. Diff with
       `diff <(jq -S 'del(.commit)' ref.json) <(jq -S 'del(.commit)' clean.json)`, and record both
       commits.
    5. **Teardown**, per Edge Case 16.
  - **Findings loop:**
    - a README-only fix lands via PR, and only the affected section is re-run on the second Mac,
      because the references still hold;
    - a mechanism defect is recorded and routed to `/milestone` revision rather than patched. It
      then needs new references and a factory-reset full re-run.
  - **T18 passes only if** the fingerprint diff is clean **and** the Test Command passes on the
    second Mac.
  - Record T18, T39 and R11.1.
  - **Largest by wall-clock, small by code.** Its risk is findings, not size.
- [ ] **SF-6: Records close-out.**
  - `docs/records/reproducibility.md`:
    - the R11.2 assessment;
    - the R10.4 finding and its review trigger;
    - the two proposed architecture edits as exact replacement text;
    - T45, T18 and T39 results.
  - The README "What Now Exists" section.
  - `prd.md` § Outputs "Image digest + SBOM" status is left for the milestone consolidation pass,
    because `/build` does not edit Gate artifacts.

No sub-feature is oversized. SF-1 is the widest by file count and stays one coherent change: every
edit serves one republish.

## Interface Contracts

### 1. `compose/pins.env` additions

```
# node:22-slim, pinned by INDEX digest (multi-platform), so R11.2 is not narrowed further.
# The base published by run 34376295042 resolved linux/arm64 -> sha256:83f487e0... .
NODE_BASE_DIGEST=sha256:<64 hex>

# (SF-1c only) dated trixie snapshot for the mediator's apt source
MEDIATOR_SNAPSHOT_URL=https://snapshot.debian.org/archive/debian/<YYYYMMDDTHHMMSSZ>/
```

The `AGENT_BASE_DIGEST` comment block gains one line: `Published by run <id> (<ref>) from commit
<sha>.` The harness reads the run from provenance, not from this comment. The comment is for a
human reviewing the repin.

### 2. Dockerfile form

```dockerfile
ARG AGENT_BASE_DIGEST
ARG NODE_BASE_DIGEST          # no default: an unset digest must never resolve to a tag
FROM node:22-slim@${NODE_BASE_DIGEST} AS pack-plan
...
FROM node:22-slim@${NODE_BASE_DIGEST} AS agent-base
```

Every target now needs `NODE_BASE_DIGEST` set. The file tree notes already record that a defaultless
ARG in any `FROM` constrains every target, because pruning happens after parsing.

### 3. `images/build-allowlist.yaml`

```yaml
schema: 1
# Hosts the image builds reach OUTSIDE pack manifests. Pack build hosts stay in each
# pack's egress.build.allow_fqdns. Not compiled, not enforced -- see docs/records/reproducibility.md.
hosts:
  - fqdn: registry-1.docker.io      # node, debian base images, by digest
    verified_by: digest
    used_by: [images/Dockerfile, images/mediator/Dockerfile]
  - fqdn: ghcr.io
    verified_by: digest
    used_by: [images/Dockerfile]
  # ... snapshot.debian.org (gpg), deb.debian.org (gpg, until SF-1b/1c), registry.npmjs.org
  #     (version only -- transitive deps unpinned), github.com (sha256), storage.googleapis.com (sha512)
```

`verified_by` ∈ `digest | sha256 | sha512 | gpg | version-only`. The value states what a fetch from
that host is checked against. It is not a policy.

### 4. `tests/acceptance/verify-reproducibility.sh`

House idiom: `set -euo pipefail`, `ROOT` resolved from the script, `phase`/`pass`/`fail`/`note`,
preflight `command -v docker jq yq curl`, exit `0` all pass / `1` otherwise.

| Phase | Asserts | Needs |
|---|---|---|
| A — pins | Every `FROM` is `scratch`, a stage name, or `…@${X_DIGEST}` / `@sha256:`. Each referenced `X_DIGEST` is `sha256:[0-9a-f]{64}` in `pins.env`. For each `compose/overrides/<profile>.yaml` that is a profile override, the rendered `docker compose config` has no `image:` without `build:` unless it is digest-pinned. The workflow `sbom:` generator is digest-pinned | Local only |
| B — build allowlist | Fetch hosts extracted from `FROM` registries, `ADD` URLs, `*_URL`/`*_SOURCE` in `pins.env`, apt sources, `npm install` and pack archive URLs ⊆ allowlist ∪ selected packs' `egress.build.allow_fqdns`. Every declared host is used | Local only |
| C — T45 | Criterion 1's chain. Owner compared case-insensitively, because the provenance URL says `OttawaCloudConsulting` and the image path is lowercase | Anonymous `ghcr.io` and `api.github.com`. Sends `GH_TOKEN` as a bearer if set. An HTTP 403/429 is a **FAIL naming the rate limit**, never a pass or skip |
| D — entry point | No script under `scripts/` or `images/` runs `docker compose … (up\|start\|run)`. README `up` forms are all the canonical one. Every README `docker compose` line carries `--env-file compose/pins.env`. The README identity commands ⊇ `mediator/identity/README.md` issuance list. README listener `--ip` values equal the `compose.yaml` `ipam` mediator addresses | Local only |

There is no skip variable. A network-dependent phase that cannot reach its source fails. That is the
same reasoning as `retry_cold_peer`: a swallowed result makes the assertion a tautology.

### 5. `scripts/fingerprint-environment.sh`

```
bash scripts/fingerprint-environment.sh <profile>   # stdout: one JSON document; exit 0 / 1
```

It requires the profile's images to be built already. It inspects them with `docker run --rm
--entrypoint /bin/sh` and never starts the pod, so it is an inspection tool, not an entry point
(R12.9). Output:

```json
{ "schema": 1, "profile": "default", "commit": "<sha>",
  "agent_base_digest": "sha256:…", "mediator_base_digest": "sha256:…", "node_base_digest": "sha256:…",
  "resolved_policy_sha256": "…", "compose_config_sha256": "…",
  "agents": { "claude": { "version": "2.1.260", "dpkg_sha256": "…", "bin_sha256": "…",
                          "npm_tree_sha256": "…", "pack_roots_sha256": "…" }, "codex": {…}, "agy": {…} },
  "mediator": { "squid": "6.13-2+deb13u2", "unbound": "…", "dnsdist": "…", "dpkg_sha256": "…" } }
```

Excluded as volatile: image IDs, created timestamps, and container IDs. `compose config` is rendered
with the checkout root replaced by `<ROOT>` before hashing. The comparison is `diff <(jq -S 'del(.commit)' ref)
<(jq -S 'del(.commit)' clean)`. `commit` is excluded so that a README-only fix between the reference
and a re-run does not register as a difference, and the record lists both commits.

### 6. README Bring-Up order (the T18/T39 contract)

1. Prerequisites: macOS 26 on Apple silicon, Docker Desktop, `git`.
2. `git clone` → `cd solutions/agent-containerization`.
3. `bash scripts/install-deps.sh`.
4. The eight `issue-identity.sh` commands.
5. The canonical `up`.
6. First-run auth per agent.
7. Verifying (`status`, the startup self-check).

Optional sections (oauth-mount, host gitconfig, pack profiles with staged credentials) follow and
are not on the T18 path, except that every profile is **built** and fingerprinted.

## Edge Cases

1. **Every `main` push touching the solution republishes a base.** Nothing auto-repins, so the pin
   stays on the run the operator chose. GHCR accumulates versions, which is recorded, not pruned.
2. **The repin itself triggers a publish** whose digest nobody pins. Harmless; stated in the
   README republish section so it is not mistaken for drift.
3. **A fast-forwarded commit built by both runs** → two digests. Only the `main` run's passes
   (Decision 2).
4. **`builder.id` absent or reshaped** by a future `build-push-action` → phase C fails naming the
   field. The action is SHA-pinned, so this only happens on a deliberate bump.
5. **Anonymous GitHub API rate limit (60/h).** Phase C makes one call and fails loudly on 403/429.
   `GH_TOKEN` is used if present.
6. **The PR carries more than this solution.** 113 commits include every change on the branch; the
   operator reviews the full diff before merging. Untracked working-tree content is not in the
   merge.
7. **`NODE_BASE_DIGEST` moves `agent-base`.** A changed node digest is a CI republish plus a repin,
   per the rule "anything in `agent-base` is CI-built". SF-1 does it once, before promotion.
8. **Index vs platform digest.** Pinning the index keeps a future second architecture open. The
   arm64 manifest that the current base used is recorded, so the change is traceable.
9. **Upstream availability ≠ integrity.** A checksum protects content, not presence. Several fetches
   can disappear or throttle and fail a clean rebuild:
   - `agy`'s manifest-resolved URL;
   - `snapshot.debian.org`;
   - the live trixie archive (if SF-1c is cut).

   Named as T18 availability risks in the record.
10. **npm transitive drift** between the reference build and the clean build → a
    `npm_tree_sha256` diff. Recorded as a T18 finding with the differing packages. It is not a pass
    by exception.
11. **A clean environment that is not clean.** Checked at the session start and recorded:
    - `docker system df` is zero;
    - `docker volume ls` is empty;
    - `mediator/identity/` is absent.

    The second Mac's Docker Desktop must be freshly installed or factory-reset. Any leftover image,
    cache or volume invalidates the run.
12. **Off-README knowledge in T39.** If the operator uses anything the README does not say, it is a
    finding even when the step succeeds. This is why review assumption 2 asks who performs it.
13. **The `agy` key via `exec -e`** reads the host environment variable. If it is unset, `exec -e
    GEMINI_API_KEY` passes an empty value and `bootstrap-auth` exits 3 naming it. The README states
    the paid-tier check.
14. **The README notice.** SF-3 corrects stale status lines only. If 02.2 SF-6's wording has
    landed, SF-3 keeps it verbatim.
15. **`install-deps.sh` callers expecting `sbx`.** `--with-sbx` is documented where discovery is
    described (D17), and running without it prints how to get it.
16. **Session-log hygiene and credential teardown on the second Mac.**
    - **Keep secrets out of the record.** The repository is public.
      - `GEMINI_API_KEY` is set with `read -rs` **before** recording starts, so it never appears on
        screen or in the log.
      - The raw terminal recording (`script`) stays local to the second Mac. It contains the OAuth
        paste-back code and device code.
      - Only a **cleaned** log is committed: command, outcome and any deviation.
    - **Teardown is mandatory.** First-run auth leaves live OAuth refresh tokens on the second Mac's
      state volumes. They stay valid until the provider revokes them; rotation does not end them
      (01.4 SF-5). After the run:
      - `docker compose down -v`;
      - delete `mediator/identity/`;
      - revoke the Claude and Codex sessions the run created at each provider;
      - unset the key;
      - factory-reset Docker Desktop.

      The teardown is recorded. The revocation step is the same procedure 02.5's T26 later times.

## Test Command

```
bash tests/acceptance/verify-pack-composition.sh && bash tests/acceptance/verify-pod-topology.sh && bash tests/acceptance/verify-egress-mediator.sh && bash tests/acceptance/verify-audit-completeness.sh && bash tests/acceptance/verify-tool-packs.sh && bash tests/acceptance/verify-mcp-inventory.sh && BOUNDARY_PROFILES="default terraform kubernetes github" bash tests/acceptance/validate-boundary.sh && bash tests/acceptance/verify-reproducibility.sh && bash scripts/lint-policy.sh
```

This is 02.3's composite with `verify-reproducibility.sh` added. The whole composite is kept
because SF-1 republishes the base every agent image sits on, and SF-1b/1c move package sources, so
every earlier assertion is a regression check here. No phase spends model tokens or a login.
`verify-reproducibility.sh` phase C needs anonymous `ghcr.io` and `api.github.com`.

T18 and T39 are **not** run by this command on the build host. They need a clean environment and a
fresh operator, and are recorded manually in SF-5. The command **is** run on the second Mac as part of
T18 — T18 passes only if it passes there (criterion 4). Per DD-12 the operator may adjust this command at build time without
gate re-approval.

## Test Strategy

- **Phases A, B and D** are static and run on every invocation. Each gets one **negative control**
  during SF-1–SF-3, run once and recorded, not left in the suite:
  - A — a temporary unpinned `FROM` is refused;
  - B — an `ADD` from an undeclared host is refused;
  - D — a second `up` form in a README scratch copy is refused.
- **Phase C** is proven in both directions against real artifacts:
  - red against today's branch pin (expected, recorded in SF-2);
  - green against the `main` pin (SF-4).

  No mock registry: the claim is about the published artifact.
- **Regression:** the full composite after SF-1's branch repin and again after SF-4's `main` repin.
  Both digests are recorded.
- **T18:** a clean fingerprint diff for every shipped profile, **and** the Test Command passing on
  the second Mac, plus the step log, which must contain no command absent from the README.
- **T39:** the step log with deviations classified as README-fixed or recorded.
- **R10.6** is walked once as a dry run. Bump nothing; follow the procedure to the point of the
  shadow run, which 02.2 already exercises. This confirms every referenced command exists.
- **Coverage:** every numbered criterion maps to a phase, a record section or the SF-5 run. The
  record carries that mapping table.

## Documentation

- `README.md`:
  - Bring-Up rewritten (Contract 6);
  - the status paragraph corrected, notice not lifted;
  - first-run auth for three agents, including `agy`'s `exec -e` path and paid-tier note;
  - "Changing the allowlist" (R12.3) with reviewer role;
  - "Updating an agent version" (R10.6);
  - the republish section updated for `main` promotion, the repin-via-PR step and Edge Cases 1–2;
  - `install-deps.sh --with-sbx`;
  - "What Now Exists".
- `docs/records/reproducibility.md` (new):
  - T45 chain and results (branch red, `main` green);
  - build allowlist statement and the R10.4 finding with review trigger;
  - the **"Clean-environment procedure" runbook** (SF-5), written before the run;
  - T18 fingerprint diffs with both commits, the second-Mac Test Command output, the
    clean-environment attestation, teardown and revocation, and availability risks;
  - T39 step log and findings;
  - R11.1 discharge;
  - R11.2 assessment;
  - the two **proposed architecture edits** as replacement text:
    - D21 row and § Reproducibility: the promotion trigger is Milestone 02, not project completion;
    - Component inventory and file tree: add `packs/github-cli/`.
  - the criterion → evidence table.
- `docs/records/agent-verification.md`: a pointer to the R10.6 procedure. It already states the
  re-verification requirement at `:37`.
- `packs/README.md`: one line pointing build-time hosts at `images/build-allowlist.yaml` for
  non-pack fetches.
- **Not edited here:** `docs/ARCHITECTURE_AND_DESIGN.md`, `REQUIREMENTS.md`, `prd.md`. Carried for
  the milestone consolidation pass or an authority that may apply them, as 02.3 does.

## Files to Create/Modify

Paths are relative to the solution root, except the workflow, which is at the **repository root**.

| File | Action | Changes |
|------|--------|---------|
| `compose/pins.env` | Modify | `NODE_BASE_DIGEST`. `AGENT_BASE_DIGEST` repinned twice (branch in SF-1, `main` in SF-4) with a run/ref/commit comment. `MEDIATOR_SNAPSHOT_URL` if SF-1c |
| `images/Dockerfile` | Modify | Global `ARG NODE_BASE_DIGEST`; `FROM node:22-slim@${NODE_BASE_DIGEST}` at `:40` and `:78`. SF-1b: `:82-84` through `apt-pinned` |
| `images/mediator/Dockerfile` | Modify | SF-1c only: apt sources → dated snapshot |
| `compose/compose.yaml` | Modify | `NODE_BASE_DIGEST` in the three agent services' `build.args` |
| `/.github/workflows/agent-sandbox-image.yml` (repo root) | Modify | `NODE_BASE_DIGEST` in the pin-loading loop (`:145`) and `build-args`. `sbom:` generator pinned by digest. Comment on branch publishes being testing-only and T45 as the control |
| `images/build-allowlist.yaml` | Create | Contract 3 |
| `tests/acceptance/verify-reproducibility.sh` | Create | Contract 4, phases A–D |
| `scripts/fingerprint-environment.sh` | Create | Contract 5 |
| `scripts/install-deps.sh` | Modify | `sbx` only with `--with-sbx` |
| `README.md` | Modify | Per Documentation |
| `docs/records/reproducibility.md` | Create | Per Documentation |
| `docs/records/agent-verification.md` | Modify | Pointer to the R10.6 procedure |
| `packs/README.md` | Modify | Pointer to `images/build-allowlist.yaml` |
| `.project/.../milestone-status.txt` | Modify (by `/build`) | Sub-feature progress |

## Dependencies

- **Features 02.1, 02.2, 02.3 complete (`[x]`).** Today they are `[~]` planned, not built. 02.4's
  build does not start until 02.3 is `[x]`:
  - T18 must cover the final pack set;
  - the Test Command is 02.3's composite;
  - R10.6's re-verification uses 02.2's `BOUNDARY_SHADOW_RUN`;
  - R12.3's procedure uses 02.3's R14.1 anchor lint.
- **Operator actions**, which are this feature's long pole:
  - merge the PR to `main`;
  - decide how the repin reaches `main`;
  - provide the **second physical Mac** (macOS 26, Apple silicon) and perform T39 on it;
  - name the R12.3 reviewer role.
- **External:**
  - GitHub Actions `ubuntu-24.04-arm` runners;
  - GHCR public package;
  - the public `api.github.com` runs endpoint;
  - `snapshot.debian.org`;
  - Docker Hub for the node and debian digests.
- **Host class:** macOS 26 on Apple silicon with Docker Desktop (R11.1, A1). A Linux runner does not
  substitute for T18.
- **Downstream:**
  - 02.5 runs its return-to-known-good (T41) against the `main`-pinned digest this feature produces.
  - The milestone DoD needs the D21 amendment **applied** to the architecture document; this feature
    records it, it does not apply it.
  - Milestone 03 re-runs `verify-reproducibility.sh` after adding the AWS pack's build hosts to the
    allowlist.

## Architectural Deviations

(none)
