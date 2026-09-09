# Feature Plan: Pack composition, policy compiler and build pipeline

**Milestone:** 01 - Sandboxed Pod
**Feature:** 01.5: Pack composition, policy compiler and build pipeline
**Status:** Planned
**Date:** 2026-09-04

**Re-planned:** 2026-09-07 — against Feature 01.3 **as built**. Three of this plan's assumptions
were overtaken by what 01.3 actually shipped: the compiler now has a CLI (this plan proposed a
different, incompatible one), the mediator's build context is already the solution root with a
deny-all `.dockerignore` (this plan scheduled that work), and the compiler already carries the
validation this plan describes as inherited — plus refusals this plan does not mention. One new
obligation arrives from the Gate 2 refresh: a compile-time warning for RFC 6761 special-use TLDs.
The revision touches the inherited-validation section, Contracts 5 and 6, SF-4 and the Files to
Create/Modify table; the acceptance criteria, the composition model, the pack manifest contract and
the refusal gates are unchanged — no criterion described the build context or the old CLI, so none
needed editing.

## Summary

This feature is the composition mechanism SC-6 and SC-8 are measured against. It defines the pack
manifest schema (R7.3, R7.11), extends 01.3's degenerate zero-pack `scripts/compile-policy.sh` into
a pack-composing compiler, relocates that compiler into a build stage of the mediator image so it
is never an operator step (R7.4, D10), installs pack-declared OS packages at image build only with
the package manager left uninvocable at runtime (R7.18, R7.19), adds the profile-side build-refusal
gates (R4.17/T27, R2.8/T21, R2.10/T23, R12.7), and introduces this repository's first CI workflow —
`.github/workflows/agent-sandbox-image.yml` at the repository root — which publishes the base image
to GHCR with an SBOM for consumption by digest (D21, R10.2, R10.7). It is exercised with the
`language-runtimes` reference pack, which by deliberate decision declares **no runtime egress**.

## Acceptance Criteria

Restated from the milestone README with implementation detail. The README wins where they differ.

1. **Pack manifest schema.** `packs/<name>/pack.yaml` declares, at minimum: packages with pinned
   versions and checksums; required egress FQDNs and CIDRs; required mounts and their modes;
   required environment variables; required credentials; whether the pack needs write access; and
   the pack's blast-radius contribution (R7.3, R7.11). A manifest missing any mandatory field fails
   validation with the file and the failing field named.

2. **The compiler composes and runs as a build stage.** `scripts/compile-policy.sh` composes the
   resolved egress policy from `policy/allowlist.base.yaml` + `policy/denylist.base.yaml` +
   `profiles/<profile>.yaml` + the profile's selected packs, and continues to emit exactly the
   schema 01.3 Interface Contract 1 fixed — now with `compiled_from.packs` populated. It runs as a
   build stage of the mediator image, not as an operator step (R7.4, D10). The output is a
   committed, reviewable artifact under `policy/resolved/` (see Interface Contract 4 for how both
   halves of R7.4 are satisfied at once).

3. **No residue on pack removal.** Removing a pack from a profile removes its egress entries,
   mounts, environment variables and credentials from the recomposed policy and from the rebuilt
   images, with no residue (R7.5) — **T14**, exercised by loading and unloading `language-runtimes`.

4. **The reference pack declares no runtime egress.** `language-runtimes` is build-time-only under
   R7.18 and adds no package-registry entry to the resolved policy. A pack granting runtime registry
   egress (`registry.npmjs.org`, PyPI, the Go proxy) would enable arbitrary `npx <server>` and break
   **T31** on every profile loading it; R7.6 keeps runtime-install egress off by default and
   explicitly declared where used. **Accepted consequence:** T14 here exercises OS-package and mount
   composition only, and the *egress* half of the composition delta is re-exercised in 02.3 by
   Terraform, the first pack carrying unique entries and needing no credential.

5. **Packages are build-time only — every kind of package.** Pack OS packages are version-pinned,
   checksummed, sourced from the snapshot repository the profile declares, and installed at image
   build only. The agent process cannot invoke a package manager at runtime (R7.18, R7.19, D10) —
   **T33** and **T15**. R7.19 says *packages*, not *OS packages*: the reference pack ships Node,
   Python and Go, so the language-level installers are covered too, and the plan states which layer
   refuses which attempt rather than claiming the filesystem controls cover all of them.

6. **The profile carries R12.7's classification.** The profile schema carries the classification of
   irreversible or high-impact actions, or an explicit recorded waiver. Shape is validated here;
   verification of the gate itself (**T37**) belongs to 02.5.

7. **`oauth-mount` without a recorded decision refuses to build.** A profile enabling `oauth-mount`
   without an `accepted_risk` record naming the file, mount mode, revocation path and blast radius
   refuses to build or start (R4.17) — **T27**. 01.4 enforces the same constraint at bootstrap
   (`bootstrap-auth.sh` exit 3); this feature moves the refusal to build time where T27 requires it.

8. **Optional mounts are default-off and enumerable.** Mounts beyond the project directory and the
   per-agent state volumes are optional, disabled by default, and only those enumerated in R2 are
   available to enable — forwarded sockets including `SSH_AUTH_SOCK` are not among them (R2.8) —
   **T21**. A build cache, where enabled, is per-agent (R2.10) — **T23**.

9. **CI builds and publishes the base image.** A GitHub Actions workflow at the repository root
   builds the base image and publishes it to GHCR with its digest and SBOM; compose consumes it
   **by digest, never by tag**; branch-built images are consumed by testing only (D21, R10.2,
   R10.7). Provenance verification (**T45**) and the clean-rebuild proof (**T18**) belong to 02.4.

## Approach

### The composition model

The compiler is a pure function of committed inputs:

```text
policy/allowlist.base.yaml  ─┐
policy/denylist.base.yaml   ─┤
profiles/<profile>.yaml     ─┼─→ compile-policy.sh ─→ policy/resolved/<profile>.yaml
packs/<selected>/pack.yaml  ─┘                        (schema fixed by 01.3 IC1)
```

Three properties make it a *composition* rather than a merge, and each is enforced rather than
assumed:

- **Per-agent keying is preserved end to end.** 01.1 SF-3 keys the capture per agent precisely so
  the compiler inherits a per-agent policy rather than a union (`01.1:98-100`). Pack entries are
  applied to every agent the profile enables the pack for, and never flattened across agents.
- **Deny wins, post-resolution.** `deny_cidrs` and `deny_fqdns` are copied to the resolved artifact
  unmodified. No pack may remove or narrow a deny entry; a pack manifest containing a `deny_*` key
  is a validation failure, not a merge.
- **A pack cannot widen policy at runtime** (R7.4). Every pack-derived entry enters the artifact at
  compile time and is baked into the mediator image layer. The running mediator reads policy only
  from its own image layer and its Compose secrets (`01.3:581-582`).

### Validation the compiler inherits from 01.3

01.3 SF-2 built these and they are **on disk, not proposed**. They are extended to pack-supplied
entries, never reimplemented — and the list is longer than this plan first assumed:

- **Wildcard allowlist entries are rejected.** `*.anthropic.com` from a pack fails the build. The
  allowlist schema is exact-`fqdn`; a pack is the only realistic way a wildcard could appear.
- **Any allowlist entry whose port is not 443 is flagged.** One is a design question, not a config
  detail — and a pack introducing one is exactly the case worth surfacing.
- **`provisional:` propagates** from `allowlist.base.yaml` into the resolved artifact. A pack cannot
  clear it.
- **Hostnames and agent keys are shape-checked at the boundary.** Both are interpolated into the
  mediator's *Lua* DNS policy and into `squid.conf`, so a name carrying a quote, an escape or a
  newline would become policy **code**. The compiler enforces a hostname regex and an identifier
  regex, and — this is the part that matters for 01.5 — **the mediator re-enforces both at render
  time**, precisely because pack composition makes the artifact a channel from third-party content
  into that render. Guarding only at the producer would put the check on the wrong side of the
  boundary this feature opens.
- **`connections_per_minute` is refused outright.** Squid 6.13 has no per-client connection-rate
  directive; the compiler rejects an artifact that declares the key rather than emitting one that
  enforces nothing (01.3 Deviation 4). A pack must not be able to reintroduce it.

**New obligation from the Gate 2 refresh (2026-09-07): warn on RFC 6761 special-use TLDs.**
`unbound` — the mediator's re-originating stage — carries built-in local zones for `test.`,
`invalid.`, `localhost.` and `example.`: it answers such names itself and never forwards them,
whatever the policy says. An allowlist entry under one of those TLDs compiles, is audited as
`allow`, and still never resolves; every surface reports success and the only signal is the absent
answer. The architecture document assigns the warning here, because this is where the allowlist is
validated. A warning rather than a refusal: the operator may have a local resolver that does serve
one. See the addendum in `docs/records/resolver-verification.md`.

### The refusal gates

Three build-time refusals, all in the compiler because that is the single point every profile
passes through before an image exists:

| Gate | Trigger | Requirement |
|---|---|---|
| `oauth-mount` accepted-risk | any agent at `AUTH_MODE=oauth-mount` without a complete `accepted_risk` record | R4.17, **T27** |
| Mount-key allowlist | any `mounts.*` key not in the enumerated R2 set — fail closed, never ignore | R2.8, **T21** |
| Runtime-install egress | a pack declaring `egress.runtime` without `runtime_install: true` and a recorded reason | R7.6, **T31** |
| Project-mount containment | `mounts.project.path` resolving to the solution root, an ancestor of it, or any descendant exposing `policy/`, `packs/`, `profiles/`, `compose/`, `images/`, `mediator/`, `scripts/` or `.dockerignore` | SC-3, R5.14 |

The first three gates run inside the compiler, which executes in the mediator build stage. The
project-mount gate cannot: it resolves a host path and runs host-side before the build, in
`scripts/lint-policy.sh` — see Edge Case 18.

The project-mount gate is this feature's debt to 01.3, not a new idea. 01.3's Phase A asserts that no
agent's *runtime mount set* contains a control-plane path, and its stated threat is a read-write
project mount aimed at the solution tree: an agent that can rewrite `allowlist.base.yaml`,
`mediator/config/*.tmpl` or `scripts/compile-policy.sh` widens its own policy at the next build. This
feature makes that threat sharper by turning those same files into build inputs, so the gate that
refuses the mount belongs here.

The mount-key gate must **fail closed**. Silently ignoring an unrecognised key is how R2.8 gets
defeated in practice: a profile that asks for `ssh_auth_sock: true` and is quietly ignored looks
identical to one that was correctly refused, right up to the day the key is implemented.

### Where pack OS packages land, and why not in the base image

D21's "base image" is singular: `images/agent-base` is what CI builds and publishes. D10 says a
profile drives the build and "each profile pins to a distinct image digest, so 'the image' is
per-profile rather than universal." These are only compatible one way:

- **`images/agent-base`** — profile-independent, CI-built, GHCR-published, consumed by digest.
- **`images/{claude,codex,agy}`** — built locally `FROM ghcr.io/...@sha256:<base digest>`, and the
  layer where the profile's pack OS packages are installed. This is the per-profile digest D10
  names.
- **`images/mediator`** — built locally, retains its `build:`, and hosts the policy compile stage.
  Its content is profile-dependent by construction, so it cannot be a CI-published universal image.

Reading `01.3:534-535` ("01.5 replaces the mediator's local `build:` with a digest-pinned GHCR
image") as *the mediator's `FROM` becomes digest-pinned* rather than *the mediator becomes a
CI-published image* is the only reading consistent with D10, with the compile stage, and with
ARCH:243-244 ("the CI-published base image and its pinned digest, with `build.sh` retained for local
per-profile layering"). **This is an interpretation and is flagged for the gate**, not asserted.

### R7.19: two classes of package manager, and only one the filesystem can stop

R7.19 is a MUST NOT and it says *packages*, not *OS packages*. The reference pack installs Node,
Python and Go — three language-level installers that touch no path `apt` uses. Treating R7.19 as an
`apt` problem is the failure this feature is most likely to ship. Treating it as fully solvable is
the second.

**The system-level manager — stopped by the runtime.** Three conditions, the first two inherited
from 01.2's hardened runtime:

1. **No privilege** — `cap_drop: ALL`, `no-new-privileges`, non-root `agent` (uid 1000). `apt` needs
   `CAP_DAC_OVERRIDE`/root to write `/var/lib/dpkg`.
2. **No write access** — read-only root filesystem. `/var/lib/dpkg`, `/var/cache/apt` and `/usr/lib`
   are on the image layer, not on a writable mount.
3. **No binary** — `apt`, `apt-get` and `dpkg` are removed in the final stage of each agent image
   after the build-time install completes.

T33's wording — "fails for want of both privilege and write access" — is OS-manager-shaped, and
conditions 1-3 satisfy it.

**The language-level managers — not stopped by the filesystem, and the plan says so.** 01.2 makes
`/home/agent` and `/workspace` writable, with `/tmp` and `/run` as `tmpfs`. `pip install --user`, a
venv install, `npm install` into a project `node_modules`, and `go install` into `GOPATH` write only
to paths the agent already owns. R7.19's filesystem clause — no write access to the paths the
manager would modify — is **structurally unsatisfiable** for these while `/home/agent` is writable,
and SC-4 requires it writable, because that is where session state and credentials live. The two
requirements pull against each other; this plan records the tension rather than papering over it.

4. **Installer packages removed, best-effort.** `pip` and `ensurepip` are removed from the Python
   installation and the bundled `npm` tree from the Node installation — the packages, not only the
   `bin` symlinks, so `python3 -m pip` and a direct `npm-cli.js` invocation fail too. This raises the
   cost. It does not close the class: an agent that vendors or writes an installer still has a
   writable target.
5. **No registry egress — the control that actually holds.** The reference pack declares none, so
   every install attempt surviving condition 4 fails at the mediator with an audited denial.

**What is claimed and what is not.** **T15** ("blocked and logged") is claimed for the
language-level managers, and condition 5 is what makes the *logged* half true — the filesystem
controls fail an install silently as far as the audit log is concerned, because nothing reaches the
enforcement point. **T33 is claimed for the OS manager only.** Recording R7.19 as fully met for
language-level installers would be an assertion this design cannot support, and 02.2 is where that
would surface expensively.

An earlier draft of this plan added a `go` wrapper refusing install-shaped subcommands and a set of
installer-hostile environment variables. Both are dropped: the real `go` binary must remain for
`go build` so the wrapper is bypassed by calling it directly, and the plan's own text conceded the
agent can unset any of the variables. Neither changed what an attacker can do.

## Sub-Features

Seven, dependency-ordered. Each is a single reviewable unit judged against DD-1's ~120k-token
session guideline; DD-1's 2-5 ceiling governs features per milestone, not sub-features per feature.
The milestone README's own split point — "01.5 splits cleanly at compiler versus CI pipeline" — is
the SF-1..SF-5 / SF-6 boundary.

- [x] **SF-1: Pack manifest schema and the `language-runtimes` reference pack** -- Define
  `packs/<name>/pack.yaml` covering all seven R7.3 fields plus R7.11's blast-radius contribution.
  Write `packs/language-runtimes/pack.yaml` declaring Node, Python and Go toolchains as build-time
  only with an empty runtime egress set, and `packs/README.md` recording why the reference pack
  grants no registry egress and what that costs an operator at runtime. Ships the manifest validator
  as a function of `scripts/lint-policy.sh` (01.1's Test Command), which is where policy-file
  well-formedness already lives.

- [x] **SF-2: Profile schema extension and the build-refusal gates** -- Extend 01.2 Interface
  Contract 3 additively: `packs:` becomes a populated list, `authorization:` carries R12.7's
  classification or its recorded waiver, and `mounts.build_cache` gains its per-agent shape. Implement
  the three refusal gates in the compiler's validation pass (T27, T21's mount-key allowlist, R7.6's
  runtime-install declaration). No composition logic here — this sub-feature is the input contract
  and the gates that reject bad input.

- [x] **SF-3: Pack composition in the compiler** -- Extend `scripts/compile-policy.sh` from its
  degenerate zero-pack form to compose pack-supplied FQDNs, CIDRs, mounts, environment variables and
  credentials into 01.3's fixed resolved schema, populating `compiled_from.packs`. Preserve
  per-agent keying, deny-wins precedence and `provisional:` propagation; extend the wildcard
  rejection and the port≠443 flag to pack-supplied entries. Make the output **deterministic** —
  stable key order, sorted entry lists — because the drift check in SF-4 is meaningless otherwise.

- [x] **SF-4: Build-stage relocation and the drift check** -- Move the compiler invocation into a
  stage of `images/mediator/Dockerfile` so it is never an operator step (D10, R7.4), and implement
  the committed-artifact drift check per Interface Contract 4. **Re-scoped 2026-09-07: the build
  context work is already done.** 01.3 SF-4 moved the mediator's context to the solution root and
  wrote the deny-all `.dockerignore`; what remains is extending that allowlist with the compiler's
  inputs, added above the file's trailing deny block. **Ratified at Gate 4, 2026-09-07 -- the exact
  four lines, and the reason for their shape:**

  ```
  !profiles
  !packs                        # inert until this feature creates the directory
  !policy/allowlist.base.yaml
  !policy/denylist.base.yaml
  ```

  The two base policy files are named **individually rather than as `!policy`**, because
  `policy/` also holds `allowlist.test.yaml` and `denylist.test.yaml` -- 01.3's harness fixtures,
  which have no business in a shipped mediator image. All four go **above** the trailing-deny block
  the file's own comment marks; placed below it they would still be admitted, but the next entry
  added after them would inherit the wrong position and re-admit `mediator/identity/`. The agent images keep the `images/` context and are now one multi-stage Dockerfile
  (01.2 Deviation 1), so there is no four-Dockerfile change to make.
  Extend `images/mediator/entrypoint.sh` only where the policy path changes — note it already
  copies `scripts/compile-policy.sh` into the image for stage-1 validation, so the compile stage
  and the validate call must agree on one script, not two.
  Also implement the exit-code contract of Interface Contract 6 and **re-run both existing
  harnesses**: `verify-pod-topology.sh` and `verify-egress-mediator.sh` (77 assertions) must still
  pass, since this sub-feature changes an image the second one drives end to end.
  *Split condition:* if it runs long, SF-4a is the compile stage plus `.dockerignore` extension and
  SF-4b is the drift check plus exit codes.

- [x] **SF-5: Build-time OS packages, package-manager removal, and the per-agent build cache** --
  Install the profile's composed pack package set in `images/{claude,codex,agy}/Dockerfile` at build
  time only, from the snapshot repository the profile declares, version-pinned and
  checksum-verified. Remove `apt`/`apt-get`/`dpkg`; remove the `pip`, `ensurepip` and bundled `npm`
  *packages* rather than their `bin` symlinks, so R7.19 is addressed for language-level installers
  as far as the filesystem can reach it, with the residual recorded rather than claimed away
  (Approach, conditions 3-5). Add
  `compose/overrides/build-cache.yaml` as a layerable per-agent fragment `profiles/default.yaml`
  never selects (R2.10). Extend `tests/acceptance/verify-pod-topology.sh`'s mount-set equality
  assertion — this is its **fourth** extension, after 01.3's `/run/secrets` and 01.4's
  `/run/oauth-src` and `/run/gitconfig`.

- [ ] **SF-6: GitHub Actions base-image publish, per-profile build artifacts, and the CI drift job**
  -- Create `.github/workflows/agent-sandbox-image.yml` at the **repository root** — this
  repository's first workflow. Build `images/agent-base`, publish to GHCR with an SBOM via buildx
  attestation, and tag branch builds so nothing consumes them by default. Pin the three agent
  Dockerfiles to the published digest via `AGENT_BASE_DIGEST` in `compose/pins.env`. Ship
  `scripts/build.sh` — the per-profile image build the ratified file tree names — recording each
  profile image's digest and emitting its SBOM (R9.9, Edge Case 19). Add the CI job that fails on
  resolved-policy drift. Document the first-publish bootstrap (Edge Case 11).

- [ ] **SF-7: Acceptance harness** -- `tests/acceptance/verify-pack-composition.sh`, phases A-G
  covering T14, T15, T21, T23, T27, T31 and T33, following the harness conventions all four siblings
  share: test-scoped Compose project name, `down -v` teardown, assertions against `docker inspect`
  on running containers rather than against the Compose YAML, and no third-party service as a test
  target.
  **Assert the CA private key is absent from the mediator build context by name, not merely that the
  context is small** (operator decision, Gate 4, 2026-09-07). Edge Case 1 sizes the context; a size
  ceiling cannot catch a 1.7 KB private key, which is the exact failure the solution-root
  `.dockerignore`'s own comment warns about when a future `!` entry lands below its trailing-deny
  block. The assertion enumerates the context and requires `mediator/identity/ca/mediator-ca.key`
  and `references/` to be missing from it.

No sub-feature carries the `[OVERSIZED]` flag. SF-4 and SF-5 are the closest calls; SF-4 carries a
stated split condition and SF-5 is kept whole because the package install, the binary removal and
the T33 assertion that ties them together are one change to one file per agent.

## Interface Contracts

### Contract 1: Pack manifest — `packs/<name>/pack.yaml` (produced here, consumed by the compiler)

New in this feature. No sibling fixes any part of this shape.

```yaml
name: language-runtimes
description: Node, Python and Go toolchains, build-time only
schema: 1

blast_radius: |                  # R7.11 — what a compromised agent gains when this pack loads
  Language interpreters and compilers inside the container. No new egress, no new credential,
  no new mount. The gain is local execution capability, not reach.

needs_write_access: false        # R7.3 — whether the pack needs write access

packages:                        # R7.3, R7.18 — pinned versions WITH checksums, both kinds
  apt:
    repository: profile          # resolves to profiles.<p>.package_repository (R7.18)
    items:                       # sha256 is the .deb hash from the signed Packages index
      - {name: python3, version: "3.11.2-6+deb12u5", sha256: <64 hex>}
      - {name: python3-venv, version: "3.11.2-6+deb12u5", sha256: <64 hex>}
  archives:                      # direct downloads, where apt has no acceptable pin
    - {name: node, version: "20.18.1", url: <url>, sha256: <64 hex>}
    - {name: go, version: "1.23.4", url: <url>, sha256: <64 hex>}

egress:                          # R7.3 — required FQDNs and CIDRs
  runtime:
    allow_fqdns: []              # EMPTY BY DECISION — see Acceptance Criterion 4 and T31
    allow_cidrs: []
  build:                         # consumed by the image build only; never enters resolved policy
    allow_fqdns:                 # every build-time destination, R10.4
      - {fqdn: snapshot.debian.org, port: 443}
      - {fqdn: nodejs.org, port: 443}
      - {fqdn: go.dev, port: 443}
      - {fqdn: dl.google.com, port: 443}

runtime_install: false           # R7.6 — true requires a recorded reason and registry egress above

mounts: []                       # R7.3 — required mounts and their modes. Keys must be in the R2 set
env: []                          # R7.3 — required environment variables
credentials: []                  # R7.3 — required credentials
```

Two fields need their reasoning stated because neither is obvious:

- **`egress.build` is not `egress.runtime`.** Build-time egress is consumed by the image build,
  which runs on the host build network, and never enters `policy/resolved/`. Conflating them is how
  a pack would silently acquire runtime registry reach.
- **Every package carries a checksum, because R7.3 is a MUST and says so without qualification.**
  Direct downloads carry a SHA-256 of the archive. `apt` items carry the `.deb` SHA-256 taken from
  the signed `Packages` index and re-verified at build. An earlier draft of this plan argued the
  signed `Release` made a per-package hash redundant; that is an argument for `apt` being *safe*,
  not for the manifest being *pinned*, and it does not survive the reproducibility half of R7.18.
- **The repository must be a snapshot, not a suite.** `suite: bookworm` plus `name=version` is not
  reproducible over time: Debian rotates the archive and drops superseded versions, so a clean
  rebuild months later fails to resolve the pin — and SC-8 measures exactly that rebuild. The
  profile therefore declares a `snapshot.debian.org` URL carrying a timestamp, plus the keyring
  fingerprint that signs it.

### Contract 2: Profile schema extension (extends 01.2 IC3 and 01.4 IC3, additively)

Every key 01.2 and 01.4 defined is unchanged. Three additions:

```yaml
packs:                           # 01.2 shipped this as `packs: []`. Now populated
  - language-runtimes

package_repository:              # R7.18 — the repository pack apt items are sourced from
  apt:
    url: https://snapshot.debian.org/archive/debian/<timestamp>/   # pinned in time, not a suite
    suite: bookworm
    signed_by: images/agent-base/keyrings/debian-archive.gpg   # version-controlled, in the build context
    fingerprint: <full 40-hex key fingerprint>     # asserted at build; a key swap fails the build

authorization:                   # R12.7. Exactly one of `classify` or `waiver` is required
  classify:                      # actions requiring human authorization when unattended
    - git-push
    - infrastructure-apply
  # waiver: <recorded reason this profile waives R12.7>

mounts:
  build_cache: false             # 01.2 already declares this key. Per-agent where enabled (R2.10)
```

`authorization` is validated for shape here and enforced nowhere in this milestone — **T37 is
02.5's**. Requiring `waiver` as the explicit alternative to `classify` is what stops the field from
being quietly omitted for a year.

### Contract 3: Resolved policy — unchanged schema, populated `packs`

01.3 Interface Contract 1 is the target and it does not change. This feature populates two things
that were empty:

```yaml
compiled_from:
  allowlist: policy/allowlist.base.yaml
  denylist: policy/denylist.base.yaml
  profile: profiles/default.yaml
  packs:                         # was `[]`. Now the selected pack manifests, with their content hash
    - {name: language-runtimes, path: packs/language-runtimes/pack.yaml, sha256: <64 hex>}

agents:
  claude:
    allow_fqdns: [...]           # base entries + pack `egress.runtime.allow_fqdns`, per agent
    allow_cidrs: [...]           # base entries + pack `egress.runtime.allow_cidrs`, per agent
```

For the `default` profile with `language-runtimes` loaded, `allow_fqdns` and `allow_cidrs` are
**byte-identical to the zero-pack output** — that is the point of Acceptance Criterion 4, and
asserting the zero is what T14 checks here.

`schema: 1` is unchanged: adding entries to `compiled_from.packs` is what the field was declared
for. The per-pack `sha256` is what makes `compiled_from` a provenance record rather than a list of
names — it is what tells a reviewer that a resolved artifact was compiled from *this* manifest and
not a later edit of it.

### Contract 4: How both halves of R7.4 hold at once

R7.4 and D10 require the compiler to run **as a build stage, not as an operator step**. The
milestone README requires the resolved policy to be **a committed, reviewable artifact under
`policy/resolved/`**. A Docker build stage cannot write to the repository, so these are only
compatible with an explicit resolution:

| Where | Behaviour |
|---|---|
| Mediator image build stage | **Compiles authoritatively.** Emits to the image layer. This is the policy the mediator runs |
| Local build and CI alike | **Fail on drift.** The compiled output must equal the committed `policy/resolved/<profile>.yaml`, comparing every field except `compiled_at` |
| Operator, when policy inputs change | `bash scripts/compile-policy.sh --profile <profile>`, then reviews the diff and commits it — a version-controlled, reviewed policy change |

**The build fails on drift rather than warning.** R5.14 requires policy changes to be
version-controlled and reviewed, and a warning printed into a build log is neither. A local build
that merely warns produces a mediator running a resolved policy no reviewer has seen, which is the
property SC-3 exists to prevent — and it makes the committed artifact decorative, since nothing
would ever force it to be true.

This does not cost SC-6. SC-6 is measured as "switch use-case profile; confirm egress policy
**recomposes** automatically", and it does: the operator never hand-edits a policy file, the
compiler composes it from the profile and its packs. "Automatically" qualifies *recomposes*, not
*is committed*. The one deliberate manual act is reviewing and committing the recomposed artifact —
which is what R5.14 asks for, not the step D10 forbids. The prohibition on the *compilation* being
an operator step is D10's and the milestone README's, not R7.4's — R7.4 verbatim requires only that
the effective policy be composed from base plus selected packs and that a pack cannot widen it at
runtime. Compilation happens in the build stage, unattended, every time.

**`compiled_at` is excluded from the drift comparison.** It is in 01.3's schema and it changes on
every compile, so a byte-diff would always fail. The comparison is over every field except
`compiled_at`; `compiled_at` in the committed copy records when it was last refreshed.

**The documented entry point must rebuild, or none of this runs.** 01.2 fixes the single documented
start command as `docker compose --env-file compose/pins.env -f compose/compose.yaml -f
compose/overrides/default.yaml up` — with no `--build`. Once the compiler lives in a build stage,
that command reuses whatever image is cached and the policy never recomposes: SC-6 fails while
appearing to pass, because switching profiles changes the Compose files and nothing else. This
feature therefore amends the documented command to `up --build`, keeping R12.1's single documented
start command and D10's "a profile change that touches packages is a rebuild, not a restart" both
true. `PACK_SET_HASH` (Edge Case 4) is what makes the rebuild cheap when nothing has changed and
mandatory when it has. The amendment lands in `README.md` and in 01.2's entry-point text, and SF-7
Phase C proves it: change a pack, run **only** the documented command, and assert both the mediator
and the agent images were rebuilt.

### Contract 5: Build context (modifies 01.2's Compose seam — the fourth extension)

**Mostly already done by 01.3 SF-4 — this contract shrinks to one addition.** The mediator's build
context *is* the solution root today, with `dockerfile: images/mediator/Dockerfile` and a
solution-root `.dockerignore` that is deny-all plus an explicit allowlist (`images/mediator`,
`policy/resolved`, `mediator/config`, `scripts/compile-policy.sh`), with trailing re-denies for
`references/` and `mediator/identity/`. The three **agent** images still build from the `images/`
tree, and after 01.2's Deviation 1 they are **one multi-stage Dockerfile selected by `target:`**,
not four — so this plan's "four locally built images" and "four Dockerfiles" no longer describe the
tree.

What remains for 01.5: **extend the existing allowlist** so the compile stage can read the
compiler's inputs — `profiles/`, `packs/`, `policy/allowlist.base.yaml` and
`policy/denylist.base.yaml` — and add those entries **above** the trailing deny block, where that
file's own comment says new entries go. The agent images' context does not change.

The original reasoning, kept because it is why the context is what it is: 01.2 fixed a single
shared context at `images/`, which cannot satisfy D10 — the compiler's inputs and
`mediator/config/*.tmpl` sit **outside** `images/`, and a build stage can only read its context.

```yaml
services:
  egress-mediator:
    build:
      context: ..                # the solution root, relative to compose/compose.yaml
      dockerfile: images/mediator/Dockerfile
  claude:
    build:
      context: ..
      dockerfile: images/claude/Dockerfile
      args: [...]                # 01.2's pins.env args, unchanged
  # codex, agy identical
```

Consequences, each handled rather than noted:

- **`images/.dockerignore` no longer applies.** Docker resolves `.dockerignore` at the context root.
  Its rules are folded into a new solution-root `.dockerignore` written as an **allowlist** —
  `*` followed by `!` re-includes for `images/`, `policy/`, `profiles/`, `packs/`, `mediator/config/`,
  `images/agent-base/keyrings/` and `scripts/compile-policy.sh`. A denylist would ship `docs/artifacts/` —
  several large PDFs — and `.project/` into the daemon on every build. The keyring is in the list
  because Contract 2's `signed_by` resolves against the build context; omitting it makes every
  `apt` step in every agent image fail.
- **The allowlist is a security boundary, not a size optimisation.** It must never re-include
  `mediator/identity/`, `compose/generated/` or `compose/pins.env`. The CA private key is never
  committed (01.3), but a build context is the **working tree**, and 01.3 places that key under
  `mediator/identity/` on the operator's disk — a `!mediator/` re-include instead of
  `!mediator/config/` would ship it to the daemon on every build. Re-including `mediator/config/`
  rather than `mediator/` is therefore a property to assert, not a path that happens to be right:
  SF-7 Phase A enumerates the context's contents and fails if any of those three paths appears.
- **In the context is not in the image**, and the rule is checkable rather than promised. No
  Dockerfile uses `COPY . .`. The mediator image copies `policy/`, `profiles/`, `packs/` and
  `mediator/config/`. The agent images copy `packs/` and `profiles/` — which they need to resolve
  their own package set — and **never `policy/`, `mediator/` or any identity path**. SF-7 Phase A
  asserts that against the built images, not against the Dockerfiles. 01.3's Phase A assertion — no
  agent's *runtime mount set* contains a control-plane path — is about mounts and is unaffected; the
  same argument now covers `packs/`, and the assertion set is extended to name it.
- **Two consumers read the pack manifests, and only one of them is the policy compiler.** The
  mediator's build stage composes the resolved *egress policy*; each agent image separately resolves
  its *package set* from the same manifests. The second is a selection, not a composition, and it
  has to live in the agent image because that is where the packages install — the compiler's output
  is baked into the mediator layer and is not reachable from another image's build. The consequence
  for `/build`: a change to the manifest schema in Contract 1 touches both readers, and SF-1 owns
  the schema for both.
- **This is a departure from the ratified file organisation's implied single context** and is
  recorded in `docs/ARCHITECTURE_AND_DESIGN.md`, following the precedent 01.4 set when it relocated
  `bootstrap-auth.sh` into `images/agent-base/` and recorded the departure rather than letting the
  tree drift silently.

**Alternative considered and rejected:** BuildKit named additional build contexts
(`additional_contexts:`), leaving 01.2's context untouched. Rejected on a stronger ground than
novelty. `additional_contexts:` is a **Compose** key, and two of this feature's own deliverables —
`scripts/build.sh` and the CI drift job — invoke `docker build`/buildx directly, where the
equivalent is hand-mirrored `--build-context name=path` flags. That is a second implementation of
the compiler's input surface maintained in parallel, and Contract 4's drift check is only meaningful
while there is exactly one. It also buys less isolation than it appears to: a named context is a
whole directory the build may `COPY --from`, so the agent images would still see `packs/` and
`profiles/` and the mediator would still see `policy/`. The control-plane threat is the runtime
project mount, which the project-mount gate handles independently and which this option does not
touch. Its behaviour on the pinned Docker Desktop is additionally UNVERIFIED — 01.1 SF-2 could
establish that cheaply if the option is ever wanted, but nothing here needs it.

### Contract 6: `scripts/compile-policy.sh` CLI — **extended**, not defined

**This plan originally proposed a CLI that 01.3 has since made incompatible.** The built signature
uses `--profile` and writes by default; the proposed one used a positional profile and required
`--write`. Adopting the proposal now would break every caller that exists: the README, both
acceptance harnesses, and the mediator's own stage-1 self-check, which invokes this script inside
the image. The built form is therefore authoritative and this feature **adds to it**:

```
bash scripts/compile-policy.sh [--profile NAME] [--out PATH]
                               [--allowlist PATH] [--denylist PATH]   # shipped by 01.3
bash scripts/compile-policy.sh --validate PATH                        # shipped by 01.3
bash scripts/compile-policy.sh --check [--profile NAME] [...]         # shipped by 01.3

  (default)    compile profiles/<profile>.yaml -> policy/resolved/<profile>.yaml
  --out        write elsewhere (used by --check's temp compile)
  --allowlist  alternate allow base; the artifact records which base it came from
  --denylist   alternate deny base
  --validate   schema check only -- what the mediator calls at start (T17)
  --check      recompile and diff against the committed artifact, ignoring compiled_at
```

**What 01.5 adds:** pack composition (the profile's `packs:` list becomes
`compiled_from.packs`), the refusal gates below, and the exit-code contract — which is a real
addition, because the shipped script exits 1 for everything:

```
Exit codes
  0  success, or --check with no drift
  1  usage error (unknown flag, missing flag value) -- the shipped `fail()` catch-all,
     narrowed to invocation errors only
  2  input validation failure (malformed profile, pack manifest or policy file)
  3  refusal gate tripped (T27 accepted_risk, R2.8 mount key, R7.6 runtime egress,
     SC-3 project-mount containment)
  4  --check found drift
```

Exit 3 is distinct from exit 2 because a refusal is a *recorded policy decision the operator must
make*, not a syntax error, and the acceptance harness distinguishes them. Exit 1 is retained rather
than reassigned so that a mistyped flag -- the shipped `fail "unknown argument"` path -- keeps the
shell-conventional code callers already assume, and 2/3/4 carry only meanings the compiler is
actually asserting (**operator decision, Gate 4, 2026-09-07**).

**Caller impact, verified against disk on 2026-09-07 rather than assumed.** The gate reviewed this
by reading each caller, and the earlier draft of this paragraph was wrong about one of them:

| Caller | Invocation | Effect of the change |
|---|---|---|
| `images/mediator/entrypoint.sh:180` | `if ! bash "$POLICY_VALIDATOR" --validate ...` | None -- tests non-zero, not a value |
| `tests/acceptance/verify-egress-mediator.sh` | **Does not invoke the compiler at all.** Reads `policy/resolved/default.yaml` directly (`:497`) | None |
| `README.md:132` | Documented operator command | None -- exit code not surfaced to a human caller |

No caller inspects a specific exit value, so no caller breaks. The obligation on SF-4 to re-run
`tests/acceptance/verify-egress-mediator.sh` **stands, but for a different reason than first
stated**: that harness is not an exit-code caller, it is an end-to-end driver of the mediator image
this feature rebuilds.

## Edge Cases

1. **The build context change ships the repository into the daemon.** `docs/artifacts/` holds
   several large PDFs and `.project/` holds the full planning tree. A denylist `.dockerignore` will
   miss one of them. Handled by writing the solution-root `.dockerignore` as `*` plus explicit
   `!` re-includes, and by asserting the context size in SF-7.

2. **Drift check defeated by non-determinism.** Unordered map emission or unsorted entry lists make
   the compiled output differ from the committed copy on every run. Handled by fixing key order and
   sorting every list in SF-3, and by asserting in SF-7 that two consecutive compiles are
   byte-identical.

3. **`compiled_at` always differs.** In 01.3's schema, changes every compile. Excluded from the
   drift comparison (Contract 4). Stated because a naive `diff` would make the CI job permanently
   red and the obvious fix — removing the field — would break 01.3's schema.

4. **Pack removal leaves image residue.** Recomposing the policy is not enough: a previously built
   agent image still carries the removed pack's OS packages, and Compose will reuse it. R7.5 says
   "no residue" and T14 tests load *and unload*. Handled by making the composed pack set a build
   argument — `PACK_SET_HASH` — so a changed pack set produces a different image, and by asserting
   in SF-7 that the unloaded pack's binaries are absent from the rebuilt container rather than only
   absent from the policy.

5. **T14's egress delta is zero.** Because the reference pack declares no runtime egress, "gains and
   loses exactly that pack's entries" is satisfied by an empty set. The test asserts the zero
   explicitly — the allowlist section byte-identical across load and unload — while packages and
   mounts do change. This is the honest exercise the milestone README accepts, and it doubles as
   T31's negative proof: there is no registry entry for `npx <server>` to use.

6. **Two different things are called `limits`.** The profile's `limits` is `{cpus, memory, pids}`
   (01.2, container ceilings); the resolved artifact's per-agent `limits` is
   `{max_concurrent, connections_per_minute, bytes_per_second}` (01.3, egress ceilings), whose
   profile-side name is `rate_limits`. The compiler reads both and must not cross them. Named here
   because the collision sits exactly on the compiler's input/output boundary.

7. **`accepted_risk` has five keys in 01.4 and four in T27.** 01.4 IC3 adds `rotation` — SF-3's
   measured per-provider result — to T27's `file`, `mount_mode`, `revocation_path`, `blast_radius`.
   All five are required, and `rotation` must carry 01.4 SF-3's **measured** value. An earlier draft
   allowed it to record "unverified" in case 01.4's measurement was outstanding; the milestone's
   ordering puts 01.4 before 01.5, so that case does not arise, and permitting it would let a
   profile record an accepted risk whose central unknown is still unknown — which is the opposite of
   what R4.17 makes the operator accept. If 01.4 SF-3 has genuinely not run, the gate refuses the
   `oauth-mount` profile rather than accepting a hollow record.

8. **A suite pin is not reproducible; a snapshot pin is.** `suite: bookworm` plus `name=version`
   resolves today and fails in six months, because Debian rotates the archive and drops superseded
   versions — and SC-8 measures precisely the rebuild that happens later. Handled by pinning
   `snapshot.debian.org` with a timestamp and asserting the signing key's full fingerprint, so the
   pin is stable in time and a key substitution fails the build. Every package carries a SHA-256,
   `apt` items included; R7.3 is a MUST and says "checksums" without qualification.

9. **The language-runtimes pack is deliberately half-useful, and fails at two different layers.**
   Node, Python and Go interpreters are installed; the `pip`, `ensurepip` and bundled `npm` packages
   are removed, so an install attempt usually fails at the filesystem with no audit line. Where an
   installer survives — a vendored copy, a script the agent writes itself, `go install` from the
   toolchain the pack must keep for `go build` — it fails at the mediator instead, with the audited
   denial T15 requires. An operator will read either as a bug. Handled in `packs/README.md`, which
   states which layer refuses what, and by 01.3's denial surface naming the blocked destination.

10. **The mount-key allowlist must fail closed.** A profile asking for `ssh_auth_sock: true` that is
    silently ignored is indistinguishable from one correctly refused — until the key is implemented.
    Unknown `mounts.*` keys are exit 3, not a warning.

11. **First publish is a chicken-and-egg.** The three agent Dockerfiles pin
    `FROM ghcr.io/...@sha256:<digest>`, but no digest exists until the workflow has run once.
    Handled by documenting the bootstrap in SF-6: the first CI run builds and publishes from the
    working branch, and its digest is committed to `compose/pins.env` as a deliberate edit.
    `AGENT_BASE_DIGEST` has no default, so an unset value fails the build rather than resolving to
    `latest` — the same discipline 01.2 applies to the agent pins.

12. **Branch-built images must not leak into use.** D21 restricts branch builds to testing. Handled
    by tagging branch builds distinctly and by consuming only the committed digest — nothing
    resolves a tag at build time, so a branch image can only be used by explicitly pinning it.
    T45 verifies this properly in 02.4.

13. **SBOM tooling is not established anywhere in the repository.** Handled by using buildx's own
    SBOM attestation rather than adding a scanner to the toolchain — adding a third-party binary to
    satisfy a MAY would be more supply chain, not less. **Attestation on *local* Compose builds is
    UNVERIFIED** on the pinned Docker Desktop, unlike the CI path where it is routine. If it does
    not hold, `scripts/build.sh` records digests only and R10.7's SBOM half stays with CI-published
    `agent-base`. Recorded the way 01.1 SF-2 records an unverified capability: established before it
    is built on, not during.

    **RESOLVED 2026-09-09 at SF-6a, and it does NOT hold.** Measured on the pinned Docker
    Desktop (buildx v0.25.0-desktop.1, BuildKit v0.23.2, default `docker` driver):
    `docker buildx build --sbom=true --load` returns `ERROR: failed to build: Attestation is
    not supported for the docker driver.` The fallback this edge case pre-authorised is taken:
    `scripts/build.sh` records image identity only and R10.7's SBOM half stays with the
    CI-published `agent-base`, where buildx's `sbom: true` is routine. Neither way around it is
    worth its cost -- a `docker-container` builder drops the attestation again on `--load`
    because the classic image store cannot hold one, and an OCI-tarball export would attest an
    image Compose could not then run. Turning on the containerd image store is the one change
    that would reopen this.

14. **The per-agent build cache may already be satisfied.** 01.2 places `/home/agent/.cache` on the
    per-agent state volume, so caching is already per-agent and T23 would pass trivially. The
    `build_cache` option therefore means a *separate, larger* dedicated per-agent volume. SF-5
    states which of the two T23 is asserted against so the test proves the property rather than
    restating 01.2's volume layout.

15. **The schema validator is not chosen here.** 01.3 SF-2 promises "the schema validator the
    mediator's stage-1 self-check calls" but names no tool or library. This feature's manifest and
    profile validation reuses whatever 01.3 selects. If 01.3 has not yet built when this feature
    starts, the constraint recorded for `/build` is: it must run inside the mediator image at
    stage 1, and it must not add a language runtime the images do not already carry. Naming a tool
    here would pre-empt a decision that belongs to 01.3.

16. **R12.7's classification is declared and enforced by nothing.** T37 is 02.5's. A field validated
    for shape but never exercised drifts. Recorded as a residual with its landing point named,
    rather than presented as satisfying R12.7.

17. **The host compile and the build stage must produce byte-identical output.** The authoritative compile
    runs inside the mediator image; the same script run on the host (`--profile NAME`, writing by default) produces the committed artifact. The drift check compares the two, so
    any difference in validator version, YAML emitter or key ordering makes the check fire on
    identical policy. Two resolutions and `/build` picks one: pin the compiler's toolchain
    identically on both sides, or make the host invocation run *through* the build stage
    (`docker build --target compile` and extract the artifact) so there is only one implementation.
    The second is more robust and slower; naming the choice here rather than discovering it as a
    permanently red CI job.

    **RESOLVED AT BUILD, 2026-09-07 — the second option (run the host invocation through the
    build stage).** This edge case says "/build picks one"; this is the pick, recorded here rather
    than discovered at SF-4.

    *Evidence gathered before deciding.* The same script was run on both sides against the same
    inputs with `COMPILED_AT` fixed to remove the one legitimately-varying field — host
    (`yq` v4.53.6, bash 5.3.15, darwin/arm64) versus the built mediator image (`yq` v4.47.2,
    bash 5.2.37, linux/arm64). The outputs were **byte-identical**: no quoting, ordering or
    numeric-formatting divergence between those two `yq` versions on this schema. So the risk this
    edge case describes is **latent, not active** — there is no red check waiting today.

    *Why the first option was rejected anyway.* Codex adversarial pass, 2026-09-07, four sections.
    The measurement establishes that the divergence is currently zero; it does not establish that
    a version **assertion** is a workable mechanism, and that is where the first option fails —
    structurally, not probabilistically:

    - The host `yq` is Homebrew-managed, so it cannot be pinned, only asserted. An assertion is a
      clearer error message on the same underlying skew, not a fix for it.
    - SF-6's CI drift job runs on GitHub's `ubuntu-latest`, which currently ships `yq` 4.53.6 —
      already different from the `v4.47.2` this repository pins at `images/mediator/Dockerfile:31`
      and `compose/pins.env`. The runner image moves on its own schedule, so the assertion would
      need maintenance against a third party's release cadence.
    - A **global** assertion would reach the mediator's own stage-1 self-check, which calls this
      same script with `--validate` at `images/mediator/entrypoint.sh:180` and is fatal before the
      listeners bind. That turns a host-side emitter concern into a runtime startup failure. A
      **scoped** assertion no longer covers the path it was added for.
    - `policy/resolved/README.md` tells a fresh-clone operator to run the compiler directly. An
      exact-version assertion turns a routine refresh into "first install this exact external
      binary."
    - The measurement's scope is narrower than the decision: `profiles/default.yaml` carries
      `packs: []` and the compiler refuses a non-zero pack list today, so **SF-3's emitter surface
      — populated `compiled_from.packs`, stable key order, sorted lists — has never been compared
      across the two versions at all.**

    *What SF-4 must therefore build.* Not merely "move the compiler into a stage":

    1. **The host invocation runs through the build stage.** Whether `scripts/compile-policy.sh`
       itself becomes the wrapper that shells out to `docker build`, or a new wrapper script calls
       it and the compiler stays the inner implementation, is **SF-4's call**. The second preserves
       Contract 6's shipped CLI surface intact and is the default reading; a change to that host
       surface would be a deviation and is recorded when the code is written, not pre-recorded here.
    2. **`REPO_ROOT` is derived from `BASH_SOURCE`** (`scripts/compile-policy.sh:28`) and the
       runtime image copies the script to `/usr/local/bin/mediator-compile-policy`, which would
       resolve `REPO_ROOT` to `/usr/local`. The **compile stage** must therefore lay its inputs out
       under a root where the script sits at `<root>/scripts/` — copy into `/src`, `WORKDIR /src`,
       invoke `bash scripts/compile-policy.sh`. The runtime `--validate` path is unaffected: that
       mode reads only the file it is handed.
    3. **The final image must consume the compile stage's artifact.** `images/mediator/Dockerfile`
       currently does `COPY policy/resolved/ /etc/mediator/policy/` — the **committed** copy, not
       a compiled one. Contract 4 already says the stage's output is what the mediator runs; the
       Dockerfile predates the contract and SF-4 makes it mechanically true (`COPY --from=`).
    4. **Extraction is UNVERIFIED on the pinned Docker Desktop.** A `FROM scratch` artifact stage
       plus `--output type=local` is the intended shape. Establish that it works **before** building
       on it, the way Edge Case 13 treats buildx SBOM attestation — not during.

    *One recommendation from the same pass DECLINED, with its reason, rather than silently dropped:*
    making the drift comparison **structural** (parse both, compare trees) instead of byte-wise.
    Under the chosen option there is exactly one emitter, so the skew that motivated it is gone —
    and a byte comparison is not merely sufficient here, it is **stronger**. A committed artifact
    that someone hand-edited into a different key order but the same structure is precisely what
    SC-6 forbids, and a byte diff catches it where a structural compare would pass it. The
    emitter-determinism property Codex wanted separated out already exists as its own check
    (Edge Case 2, asserted in SF-7). No requirement traces to the structural comparison once the
    single-emitter property holds, so it is not built.

18. **The project-mount containment gate cannot run in the build stage.** It resolves
    `mounts.project.path`, a host path, through `realpath` — which a Docker build stage cannot see.
    It therefore runs host-side in `scripts/lint-policy.sh` before the build, and is asserted again
    at test time against `docker inspect` on the running container. Stated because the Approach
    lists it beside three gates that *do* run in the compiler, and an implementer would otherwise
    put it where it cannot work. Its D19 consequence is worth recording: the copied sandbox tree
    must be a **sibling** of the project directory, never inside it.

19. **The per-profile digest and SBOM are a second artifact, not a by-product of CI.** CI publishes
    `agent-base` and attests it. But R9.9 and the PRD's Outputs table make "image digest + SBOM" a
    default-produced artifact, and the ratified file tree names `scripts/build.sh` as the
    per-profile image build that emits them. Locally built per-profile images have digests that no
    CI run ever sees. Handled by shipping `scripts/build.sh` in SF-6 to build each profile's images,
    record their digests and emit an SBOM per image. T18 and T45 verify the property properly in
    02.4; this feature produces the artifact they will verify.

20. **This plan contradicts 01.3's Interface Contract 5 and must say so.** 01.3 states that 01.5
    "replaces the mediator's local `build:` with a digest-pinned GHCR image". This plan keeps the
    mediator's local `build:` and pins its `FROM` instead, because the compile stage makes the
    mediator image profile-dependent. That is a contract change, not a reading difference. Recorded
    as **decided and scheduled** with a single landing point: **01.3 is re-planned in revision mode
    before 01.3 builds**, batched with the 01.1 re-plan its own gate already scheduled. The ordering
    is load-bearing — 01.3 builds before 01.5, so leaving IC5 as written means `/build` implements
    the contract this plan contradicts. Following the precedent 01.3's gate set for its T28 register
    amendment. `Architectural Deviations` stays `(none)`: that section is populated by `/build`, not
    by `/plan-feature`.

21. **RESIDUAL, opened at SF-3: pack-supplied `allow_cidrs` compile but do not load.** Interface
    Contract 3 says SF-3 composes a pack's `egress.runtime.allow_cidrs` into the per-agent
    `allow_cidrs`, and it does. The shipped mediator render, however, **refuses a non-empty
    `allow_cidrs` at start** (`images/mediator/entrypoint.sh`): a CIDR allow has no name for the
    SNI equality control (control 1b) to compare a ClientHello against, so honouring one would
    punch through that control silently. 01.3 put that refusal on the CONSUMER side deliberately
    and its comment names 01.5's composition as the reason. Both are therefore correct as built,
    and a pack declaring a CIDR would produce an artifact the mediator will not load.

    **Resolved as compose-and-warn, not refuse-at-build** (operator escalation, 2026-09-08). The
    compiler emits the entry per Contract 3 and `validate_resolved` WARNS that the shipped render
    will refuse it. Refusing at build was rejected on consistency: `validate_resolved` has never
    refused a non-empty `allow_cidrs` from the BASE allowlist either (it checks presence only,
    line ~143), so a build-time refusal scoped to pack-supplied entries would give one field two
    behaviours. It would also put a *render limitation* into the producer, which is the wrong side
    of the boundary this feature opens.

    **Landing point: none, and that is the record.** Extending the render is a deliberate change
    to a security control, not a sub-feature of 01.5. Until it happens, a pack needing a CIDR
    destination must express it as an `allow_fqdns` entry. Recorded as a residual the way R12.7/T37
    is -- declared, enforced by nothing yet, with the gap named rather than implied.

## Test Command

```
bash tests/acceptance/verify-pack-composition.sh \
  && bash tests/acceptance/verify-pod-topology.sh \
  && bash tests/acceptance/verify-egress-mediator.sh
```

**Composite, ratified at Gate 4 on 2026-09-07.** The two harnesses that already exist must still
pass at this feature's close, and the operator decision was that the obligation belongs in the test
command rather than in sub-feature prose: the test command is what actually runs at close, a prose
obligation is what gets skipped. A failure in any of the three fails the feature; attribute it
before fixing, since the later two are pre-existing and a break in them is a regression this
feature caused.

SF-4 is the sub-feature that makes the third one non-optional: it rebuilds the mediator image that
`verify-egress-mediator.sh` (77 assertions) drives end to end.

## Test Strategy

Eight phases, following the harness conventions all four siblings share: a test-scoped Compose
project name, teardown with `down -v` so operator state volumes are never touched, assertions
against `docker inspect` on **running containers** rather than against the Compose YAML, and no
third-party service as a test target.

| Phase | Covers | Asserts |
|---|---|---|
| A — Manifest and profile validation | R7.3, R7.11 | A manifest missing each mandatory field in turn fails with exit 2 naming the field. Every package entry, `apt` included, carries a SHA-256. A well-formed manifest passes |
| B — Refusal gates | R4.17/**T27**, R2.8, R7.6, SC-3 | `oauth-mount` without a complete five-field `accepted_risk` exits 3; an unknown `mounts.*` key exits 3; a pack with `egress.runtime` entries and `runtime_install: false` exits 3; `mounts.project.path` set to the solution root, an ancestor, and a control-plane-exposing descendant each exit 3 |
| C — Composition and determinism | R7.4 | Two consecutive compiles are byte-identical. Per-agent keying preserved. A pack-supplied wildcard is rejected; a pack-supplied non-443 port is flagged. `--check` exits 4 on drift, and a drifted committed artifact fails the **local** build, not only CI |
| D — Rebuild on the documented command | SC-6, R12.1, D10 | Change the profile's pack set, refresh with `bash scripts/compile-policy.sh --profile <profile>`, review and commit the recomposed artifact, then run **only** the documented start command (`up --build`). Both the mediator and the agent images rebuild — `PACK_SET_HASH` having changed — and the resolved policy in the running mediator reflects the change. Asserted separately: omitting the recompile fails the build rather than silently running stale policy |
| E — Load/unload | R7.5/**T14** | With `language-runtimes` loaded then unloaded: package set and mounts change; the resolved `allow_fqdns`/`allow_cidrs` sections are **byte-identical in both states**. Rebuilt container has no residue of the unloaded pack's binaries. Each state needs its own committed artifact under the fail-on-drift rule, so the phase uses 01.3's `policy/resolved/test-fixtures.yaml` for the loaded state rather than mutating the operator's committed `default.yaml` |
| F — Build-time only, both manager classes | R7.18, R7.19/**T33**, **T15** | Installed versions match the profile pins and the snapshot repository. **T33 (OS manager):** as the `agent` user, `apt`/`apt-get`/`dpkg` are absent and an install attempt fails for want of privilege and write access. **T15 (language managers):** `pip`, `ensurepip` and the bundled `npm` tree are absent, and `python3 -m pip` and a direct `npm-cli.js` path both fail; then a *deliberately vendored* installer is run to prove the residual — it reaches the network, is denied at the mediator, and the denial appears in the audit log |
| G — Mounts | R2.8/**T21**, R2.10/**T23** | On `default`: only the project directory and that agent's state volume; no socket forwarded. With the build cache enabled for two agents: distinct paths, neither writable by the other |
| H — Registry reach | **T31** | `npx <server>` from inside an agent fails, and the resolved policy contains no package-registry entry for any agent |

**Not covered here, by design:** T37 (02.5), T45 provenance verification and T18 clean rebuild
(02.4), and the egress half of the composition delta, which 02.3 re-exercises with Terraform.

## Documentation

- `packs/README.md` — **create.** The manifest schema field by field, and why the reference pack
  grants no runtime egress, including what fails at runtime as a result (Edge Case 9).
- `policy/resolved/README.md` — **extend** 01.3's generated-output notice with the drift-check
  contract and the recompile-and-commit refresh procedure.
- `README.md` — **extend.** Adding and removing a pack, the profile fields this feature adds, the
  CI workflow, the first-publish bootstrap for `AGENT_BASE_DIGEST`, the amended `up --build` entry
  point, and the recompile-and-commit refresh procedure an operator runs when policy inputs change.
- `docs/ARCHITECTURE_AND_DESIGN.md` — **extend.** Record the build-context departure from the
  ratified file organisation (Contract 5), the D21 reading that CI publishes `agent-base` only while
  the mediator retains a local `build:` (Approach), and the amended entry point. Following 01.4's
  precedent, a departure is recorded in the design document rather than left as tree drift.

## Files to Create/Modify

| File | Action | Changes |
|------|--------|---------|
| `packs/language-runtimes/pack.yaml` | Create | The reference pack. Node, Python, Go; build-time only; empty runtime egress |
| `packs/README.md` | Create | Manifest schema and the no-runtime-egress decision |
| `.dockerignore` (solution root) | Modify | **Exists (01.3 SF-4)** — deny-all + allowlist. Add `!profiles`, `!packs` and the two base policy files **by name** (not `!policy` — that would ship the `.test.yaml` fixtures) **above** the trailing deny block. Exact form ratified in SF-4 |
| `.github/workflows/agent-sandbox-image.yml` | Create | **Repository root.** Builds `images/agent-base`, publishes to GHCR with SBOM; policy-drift job |
| `tests/acceptance/verify-pack-composition.sh` | Create | Phases A-H |
| `scripts/build.sh` | Create | Per-profile image build; records digests, emits SBOM per image (R9.9) |
| `images/keyrings/debian-archive.gpg` | Create | Committed signing key for the snapshot repository; fingerprint asserted at build. Under `images/` — the agent build context — since there is no `images/agent-base/` directory |
| `policy/resolved/default.yaml` | Modify | Recomposed with `compiled_from.packs` populated; runtime egress sections byte-identical |
| `scripts/compile-policy.sh` | Modify | Pack composition, refusal gates, CLI and exit codes, deterministic output, `--check` |
| `scripts/lint-policy.sh` | Modify | Pack manifest well-formedness (01.1's Test Command host) |
| `profiles/default.yaml` | Modify | `packs`, `package_repository`, `authorization`; `mounts.build_cache` shape |
| `images/mediator/Dockerfile` | Modify | Policy compile stage; copies compiler inputs from the new context |
| `images/mediator/entrypoint.sh` | Modify | Policy path only, where the build stage changes it |
| `images/Dockerfile` | Modify | **One multi-stage file, not four (01.2 Deviation 1).** `agent-base` stage: `FROM ...@sha256:` and the CI-publish surface; the `claude`/`codex`/`agy` stages: pack OS package install and package-manager removal |
| `images/.dockerignore` | Modify | Governs the AGENT context, which does not move — extend only if a pack input must reach it |
| `compose/compose.yaml` | Modify | `PACK_SET_HASH` and `AGENT_BASE_DIGEST` build args. The contexts are already correct — mediator `context: ..`, agents `context: ../images` + `target:` |
| `compose/overrides/default.yaml` | Modify | Keeps the Compose counterpart aligned with the extended profile |
| `compose/overrides/build-cache.yaml` | Create | Per-agent build cache fragment, never selected by `default` |
| `compose/pins.env` | Modify | `AGENT_BASE_DIGEST`, no default |
| `policy/resolved/README.md` | Modify | Drift-check contract and recompile-and-commit refresh |
| `tests/acceptance/verify-pod-topology.sh` | Modify | Mount-set equality extended for the build cache — the fourth extension |
| `tests/acceptance/verify-egress-mediator.sh` | Modify | Control-plane assertion set extended to name `packs/` |
| `README.md` | Modify | Pack add/remove, new profile fields, CI, bootstrap, and the `up --build` entry-point amendment |
| `docs/ARCHITECTURE_AND_DESIGN.md` | Modify | Build-context departure; D21 reading |

## Dependencies

**Blocking, in-milestone.** All four siblings are `[~] planned, awaiting build`; none has been
built. Every dependency below is on a plan, not on code:

- **01.1** — `policy/allowlist.base.yaml` and `policy/denylist.base.yaml` are the compiler's base
  inputs; `docs/records/agent-verification.md` carries the pins. Note the allowlist is **not frozen
  at 01.1's version**: 01.4 adds provider OAuth endpoints to it. 01.1's approved plan also denies
  `deny_fqdns`, which 01.3 records as a defect against R5.1 and schedules a re-plan for; the
  compiler must handle `deny_fqdns` present-and-empty.
- **01.2** — the profile schema this feature extends additively; the Compose seam; the `images/`
  tree; `pins.env`; `verify-pod-topology.sh`.
- **01.3** — `scripts/compile-policy.sh` in its zero-pack form, the resolved-policy schema this
  feature must continue to emit, `images/mediator/Dockerfile` and `entrypoint.sh`, and the schema
  validator whose selection this feature inherits (Edge Case 15). **01.3's Interface Contract 5 is
  contradicted by this plan** and the amendment is decided and scheduled, not executed — see Edge
  Case 20.
- **01.2's entry point is amended by this feature.** The documented start command gains `--build`
  (Contract 4). The amendment lands in `README.md`, which is listed in Files to Create/Modify;
  01.2's plan text carries the old form and is **superseded, not edited** — recorded as decided and
  scheduled in the same manner as Edge Case 20, because this feature does not edit sibling plans.
- **01.4** — the `oauth_mount.<agent>.accepted_risk` shape T27's gate validates.

**Ordering.** SF-1 → SF-2 → SF-3 → SF-4 → SF-5 → SF-7 is strict. SF-6 depends only on SF-5 for the
agent Dockerfiles' `FROM` lines and is the clean split point if the feature runs long.

**Cross-cutting, outside the solution directory.** `.github/workflows/` is at the **repository
root**. This repository has no `.github/` directory today; D21 introduces its first workflow, and CI
becomes a build-time dependency the repository did not previously have.

**External.** GitHub Actions availability and a GHCR namespace under `OCC-github/agentic-ai`, with
`packages: write` granted to the workflow. Docker Desktop on macOS 26, Apple silicon (R11.1, A1).

**Not a dependency.** Nothing here depends on Milestone 02 or 03. The AWS, Terraform, Kubernetes and
GitHub CLI packs are 02.3 and 03.3; this feature ships the mechanism and one reference pack.

## Architectural Deviations

### Deviation 1: The reference pack pins Node to the base image's version, not to 20.18.1
- **What changed:** `packs/language-runtimes/pack.yaml` declares `node` at **22.23.2**, the exact
  version `node:22-slim` ships as of 2026-09-07, fetched as a checksum-verified archive from
  `nodejs.org`.
- **Originally planned:** Interface Contract 1 declares `{name: node, version: "20.18.1", url: <url>,
  sha256: <64 hex>}` in `packages.archives`.
- **Why necessary:** 01.2 built all three agent stages `FROM node:22-slim` (01.2 Deviation 1, one
  multi-stage Dockerfile), so Node 22 and its bundled npm are already in `agent-base` — and the
  `claude` and `codex` stages *use* that npm at build time to install their CLIs. Installing Node
  20.18.1 alongside it leaves two runtimes on `PATH`, and whichever wins decides what the agent
  CLIs execute against. The plan was written before 01.2 built and could not have known the base
  image's Node version. Operator decision, 2026-09-07: keep Node as an explicit checksummed
  manifest entry (rather than treating it as base-provided) so the pin is verified rather than
  riding the moving `node:22-slim` tag, but pin it to what the base actually carries.
- **Impact:** SF-5's install step overwrites `/usr/local` with the same Node version rather than
  adding a second one, so no `PATH` ordering decision is needed. The pin now has a **coupling to
  the base image** that the plan's version did not: if `node:22-slim` moves and `agent-base` is
  rebuilt, the manifest's Node version and the base's diverge until the pin is refreshed. SF-6
  digest-pins `agent-base` via `AGENT_BASE_DIGEST`, which bounds that drift to a deliberate
  digest bump. Contract 1's shape is otherwise unchanged — no field was added or removed.

### Deviation 2: `git` is installed in the `agent-base` stage, not supplied by a pack
- **What changed:** `git` is installed in the `agent-base` stage of `images/Dockerfile` (SF-5),
  version-pinned and checksummed against the same snapshot repository the packs use. It is not a
  member of `language-runtimes` and is not a pack of its own.
- **Originally planned:** The plan does not mention `git` at all. Feature 01.4 Deviation 9 found
  that no agent image contains it, recorded that `mounts.host_git_config` therefore mounts a
  config nothing in the container can read, and assigned the decision to this feature as "01.5's
  pack-composition call". The plan's own composition model implies capability arrives through
  packs.
- **Why necessary:** Operator decision, 2026-09-07. R2.9's `host_git_config` mount and
  `scripts/scrub-gitconfig.sh` are **profile-level** features built in 01.4, and they are inert
  without a `git` binary. Making them depend on which packs a profile happens to select would
  mean a profile can enable `host_git_config: true`, pass every gate, and still mount a file
  nothing reads — the exact failure 01.4 Deviation 9 recorded. Putting `git` in the base makes
  the profile-level feature unconditional, like the mount it serves.
- **Impact:** Every profile gets `git` regardless of pack selection, which is a departure from
  the composition model this feature exists to demonstrate — recorded rather than hidden. It adds
  **no egress**: `github.com` is not in the resolved allowlist, so `git` works for local commits
  under `/workspace` and is denied at the mediator on fetch or push. It re-enables 01.4's
  criterion 6 assertion (`git config --global --get-all credential.helper`), which 01.4 SF-5
  could not make as written; SF-7 Phase G is the place to add it. It also enlarges `agent-base`
  and therefore the CI-published image SF-6 attests.

### Deviation 3: the SC-3 project-mount gate runs in the compiler, not in `lint-policy.sh`
- **What changed:** The project-mount containment gate is built in `scripts/compile-policy.sh`
  (SF-2) and exits **3**, alongside the other three gates. It compares `mounts.project.path`
  against the solution root **lexically** -- not through `realpath` -- so it behaves identically
  on the host and inside the compile stage. An absolute path that is the solution root, an
  ancestor of it, or a descendant whose first segment is `policy`, `packs`, `profiles`,
  `compose`, `images`, `mediator`, `scripts` or `.dockerignore` is refused; a non-absolute path
  produces a NOTE saying the gate did not run.
- **Originally planned:** Edge Case 18 states the gate "cannot run in the build stage ... It
  therefore runs host-side in `scripts/lint-policy.sh` before the build", resolving the path
  through `realpath`.
- **Why necessary:** Operator decision, 2026-09-07, on a three-way choice. Two parts of the plan
  disagree: Edge Case 18 says `lint-policy.sh`, while Contract 6 and Test Strategy Phase B both
  require **exit 3** -- a code `lint-policy.sh` does not have -- and SF-1's shipped
  `lint-policy.sh` header already records the gate as the compiler's. Writing the check lexically
  removes the premise the edge case rests on: only `realpath` needs a host filesystem, and a
  lexical containment test does not, so the gate is not confined to the host after all.
- **Impact:** Phase B's fourth assertion needs no re-scoping -- all four gates exit 3 from one
  script. **Residual, recorded rather than claimed away:** every shipped profile carries the
  literal placeholder `mounts.project.path: <host path>` and the mount that actually exists comes
  from `compose/overrides/<profile>.yaml`, so on today's profiles this gate has nothing to judge
  and warns. It also cannot see a symlink or a relative path resolving into the tree. The mount
  that exists is asserted at **SF-7 Phase A** against `docker inspect` on the running container,
  extending 01.3's control-plane assertion; SF-7 must carry that assertion rather than treating
  Phase B's exits as full SC-3 coverage.

### Deviation 4: exit codes 2 and 3 are implemented at SF-2, not SF-4
- **What changed:** `scripts/compile-policy.sh` gained `invalid()` (exit 2) and `refuse()`
  (exit 3) at SF-2, and the 31 existing content-validation failures in `validate_resolved` and
  the compile path moved from exit 1 to exit 2. Exit 1 is now invocation errors only (unknown
  flag, missing `yq`). Exit 4 stays unbuilt.
- **Originally planned:** SF-4 carries "the exit-code contract of Interface Contract 6"; SF-2 is
  described as the input contract and the gates only.
- **Why necessary:** A refusal gate cannot be built without the code that expresses a refusal.
  Test Strategy Phases A and B assert exit **2** for a malformed manifest or profile and exit
  **3** for each of the four gates, and both phases test SF-2's surface. Splitting the contract
  so the gates land without their exit codes would ship gates the harness cannot distinguish
  from validation errors.
- **Impact:** SF-4's remaining exit-code work is exit **4** only, alongside the `--check` drift
  comparison it belongs to. No caller breaks: Contract 6's caller table was re-verified against
  disk -- `entrypoint.sh:180` tests non-zero, `verify-egress-mediator.sh` does not invoke the
  compiler, and `README.md` documents an operator command. Same shape as Edge Case 17's early
  resolution: an SF-4 decision taken at the sub-feature that needs it, recorded here.

### Deviation 5: pack `mounts`, `env` and `credentials` are refused, not composed

- **What changed:** `scripts/compile-policy.sh` validates all three manifest fields as lists,
  gates a pack mount entry's key against the closed R2 set (`project`, `build_cache`,
  `host_git_config`, exit 3), and then **refuses a populated list** in any of the three at exit 3,
  naming a different landing point for each.
- **Originally planned:** SF-3's own bullet says the compiler composes "pack-supplied FQDNs,
  CIDRs, mounts, environment variables and credentials into 01.3's fixed resolved schema".
- **Why necessary:** those two halves cannot both be true. Interface Contract 3 states the
  resolved schema is **unchanged** and names exactly two things packs populate --
  `compiled_from.packs`, and the per-agent `allow_fqdns`/`allow_cidrs`. 01.3 Interface Contract 1
  has no field for a mount, an environment variable or a credential, so "compose them into the
  fixed schema" names no destination. Inventing one would also put content the mediator's stage-1
  validator does not know about into the artifact it gates. Contract 3 is the authority and the
  prose is what gives way. Refused rather than ignored for the reason Edge Case 10 gives for the
  profile's own mount keys: a declared requirement that is silently dropped is indistinguishable
  from one correctly refused, right up to the day the field is implemented.
- **The three landing points differ**, and are recorded separately rather than blanket-assigned:
  `mounts` lands at **SF-5**, which builds the per-agent build cache and extends the mount-set
  assertion; `env` has **no contract** -- per-variable delivery today is a hand-authored Compose
  fragment under `compose/overrides/` and extending one to pack content is a decision no
  sub-feature of 01.5 owns; `credentials` likewise, and **R8 bars baking a secret into an image**,
  so a build argument is not the mechanism either.
- **Impact:** none on the reference pack, which declares all three empty. `packs/README.md`
  carried the same contradiction as SF-3's prose (it listed `mounts`, `env` and `credentials`
  among what the compiler reads) and is corrected in the same commit rather than left to drift.
- **Provenance:** operator referred both this and Deviation 6 to a **Codex adversarial pass**
  (2026-09-08) before either was written. Codex returned *adopt-with-modification* on both. Two
  modifications were taken: the landing points were split per field rather than all assigned to
  SF-5, and the pack mount entry shape was kept to the minimum the R2.8 gate needs (a key, as a
  scalar or a single-key map) with source/target/mode semantics deliberately left to the
  composition that will consume them. That discharges the obligation SF-2's own Codex pass
  deferred here as declined item (a).

### Deviation 6: an `upgrade` collision is refused, and the reason recorded is not the one first proposed

- **What changed:** when the base allowlist and a selected pack supply the same
  `(agent, fqdn, port)` with a **different** `upgrade` value, the compiler refuses at exit 3 and
  names both sources. Identical tuples dedup silently.
- **Originally planned:** the plan says only that composition preserves "deny-wins precedence";
  it does not say what happens when two allow entries collide.
- **Why necessary:** the alternatives all lose information. Base-wins silently drops a pack's
  declared need; pack-wins and OR let third-party content overwrite the base record for a
  destination the base already governs (R5.14).
- **The recorded reason is narrower than the one first drafted.** The first framing was "OR-ing
  lets a pack widen policy at runtime (R7.4)". Codex's pass showed that claim is not true of the
  shipped system: `upgrade` is R5.9 metadata and the mediator's renderer reads only `fqdn` and
  `port` from `allow_fqdns` (`images/mediator/entrypoint.sh:459-508`), so an OR would produce a
  **contradictory policy record**, not a live enforcement widening. The refusal stands; its error
  message says "conflicting R5.9 upgrade metadata for the same resolved destination" and does not
  claim a consequence the code does not currently have.
- **Accepted friction, stated:** a future pack needing `upgrade: true` on a host the base lists at
  `false` cannot express that without an edit to the base allowlist. That is the intended
  direction -- the base is the canonical record for a destination it already governs -- but the
  schema has no way to represent a legitimately pack-specific difference on an identical
  host/port, and that is a real gap rather than an oversight.

### Deviation 7: every emitted list is sorted, so the three committed artifacts are regenerated

- **What changed:** per-agent `allow_fqdns` and `allow_cidrs`, `deny_cidrs`, `deny_fqdns`,
  `exclusions` and `compiled_from.packs` are all emitted `LC_ALL=C` sorted and deduplicated.
  `policy/resolved/default.yaml`, `test-fixtures.yaml` and `test-selfcheck.yaml` are regenerated
  in this commit and their line ORDER changes.
- **Originally planned:** Edge Case 2 asks for "fixing key order and sorting every list in SF-3",
  so the sorting itself is planned. What is recorded here is its blast radius: it was not obvious
  from the edge case that three already-committed, harness-consumed artifacts move.
- **Why necessary:** SF-4's drift check is a byte comparison (Edge Case 17 declined a structural
  one), and an emitter whose output depends on the order its inputs happened to be written in
  makes that check fire on identical policy. `LC_ALL=C` specifically because the host is macOS
  and the compile stage is Debian.
- **Verified, not assumed:** the three regenerated artifacts were proved to be **ordering-only**
  changes -- each file's sorted content is byte-identical to the committed version's, so no entry
  was added, dropped or altered. The mediator image was rebuilt and its stage-1 `--validate`
  accepts the populated artifact, and `tests/acceptance/verify-egress-mediator.sh` was re-run
  against the reordered artifact rather than assumed unaffected.

### Deviation 8: the SF-3 Codex adversarial pass, and the base-allowlist regression it found

Recorded here rather than folded into Deviations 5-7, because one of the seven findings is a
**regression SF-3 itself introduced into a path it did not set out to touch**, and that is worth a
record of its own. Pass run 2026-09-08, after the SF-3 commits, following 01.3's and SF-2's
precedent. Seven findings, **all seven confirmed by reproduction and all seven fixed** -- none
declined, which is itself a departure from SF-2's pass (6 of 11) and from Edge Case 17's (1 of 1).

**The regression, and why it is one.** The composition accumulator encodes each entry as
`fqdn|port|upgrade|source`, one per line. Pack-supplied ports and `upgrade` values were shape-checked
before being appended; **base-supplied ones were not**, because that branch predates the encoding
and previously interpolated its values straight into an emitted line. A base allowlist entry whose
`port` is the block scalar `443|false\nevil.example.com|443` therefore did not merely emit one
malformed entry -- it emitted a second, **well-formed, allowed destination the base allowlist never
contained**, the compile exited 0, and `validate_resolved` accepted the artifact. Reproduced before
fixing and re-run after. The lesson generalises past this bug: **introducing an internal encoding
retroactively makes every value that flows into it security-relevant**, including values that were
safe under the previous representation.

**The second silent-in-the-permissive-direction finding.** A profile writing `egress_exclusions` as
a map rather than a list makes `.egress_exclusions[]` iterate the map's VALUES, so the per-entry
select matches nothing and **every exclusion lapses** -- including the R10.3 auto-updater exclusion
`profiles/default.yaml` carries. The compile did fail, but 400 lines later and with
`startup_check.offline must be true or false, found 'null'`, naming neither the field nor the cause.
The field is now shape-checked at itself, with its entries' `agent`, `fqdn` and `reason` each
required and `agent` checked against the base allowlist's agent set.

**The remaining five.** (3) The exclusion comparison was not case-folded although SF-3 had begun
case-folding allow entries, so an uppercase `fqdn:` in a profile silently stopped excluding
anything. (4) The three deferred-surface refusals ran inside the pack resolution loop, which
precedes the R7.6 gate, so a pack tripping both was told to fix the wrong thing -- and the
milestone record claimed an ordering the code did not have; the refusals moved into their own loop
after the gate. (5) `validate_resolved` checked the provenance block's fields by their RENDERED
text, and `name: null` renders as "null", which `PACK_RE` matches -- tags are now checked, and a
pack name that is a YAML boolean, null or all-digit literal is refused at the producer so the
artifact can never carry one. (6) `exclusions` was sorted without `-u`, contradicting Deviation 7's
own claim. (7) The collision-source lookup built an ERE from a key containing a pipe and escaped
only the dots, making it an alternation; replaced with an awk field comparison.

**Verification.** 12 new probes written from Codex's own reproductions, run alongside the original
41: **53 probes, 0 failures**, all throwaway artifacts removed. Emitter output is byte-identical
before and after all seven fixes, so no committed artifact moves; all three remain `--check`
current; `oauth-mount` compiles; `lint-policy.sh` exits 0; the mediator image was rebuilt and its
stage-1 `--validate` still accepts the populated artifact; and the host/image byte-identity
established for Edge Case 17 still holds. Two of the twelve new probes initially failed for
**probe** defects rather than code defects -- a profile splice that truncated the file at
`egress_exclusions`, and a sequencing error that left the wrong pack selected -- both fixed and
re-run rather than accepted as passes.

**Postscript, 2026-09-08: the portability fix is now MEASURED rather than argued.** The
`${var,,}` removal was justified on the claim that stock macOS `/bin/bash` is 3.2 and would fail,
but it was never exercised -- `bash` on this host is Homebrew 5.3.15, and the Claude Code tool
shell's own `$BASH_VERSION` is 3.2.57 only because it is `/bin/bash`, which the compiler is never
invoked through. Running the compiler explicitly as `/bin/bash scripts/compile-policy.sh`:
compile exits 0, `--validate` exits 0, and with `COMPILED_AT` fixed the output is **byte-identical
to the 5.3.15 output**. That is a THIRD axis of the byte-identity Edge Case 17 rests on -- host
versus compile stage (two `yq` versions, two platforms) and now two `bash` versions on one host.

### Deviation 9: the two test-scoped artifacts are carried through the compile stage, not compiled by it
- **What changed:** `images/mediator/compile-stage.sh`'s `emit` branch recompiles an artifact when
  the bases its own `compiled_from` names are present in the build context, and otherwise — when
  the missing base is a `*.test.yaml` fixture — copies the committed artifact through unchanged,
  saying so in the build log. `policy/resolved/test-fixtures.yaml` and `test-selfcheck.yaml` take
  that second path; `default.yaml` takes the first.
- **Originally planned:** Interface Contract 4 says without qualification that the mediator image
  build stage "compiles authoritatively" and that the stage's output is the policy the mediator
  runs.
- **Why necessary:** the two test artifacts are compiled from `policy/allowlist.test.yaml` and
  `policy/denylist.test.yaml`, which the `.dockerignore` allowlist **ratified by this sub-feature**
  deliberately excludes — the two base files are named individually rather than as `!policy`
  precisely so 01.3's harness fixtures never enter a shipped mediator image. So the stage cannot
  recompile them. Dropping them instead is not available either: `compose/overrides/test-egress.yaml`
  runs the mediator on `test-fixtures`, and `verify-egress-mediator.sh` drives 77 assertions
  through it. Operator decision, 2026-09-08, ratified before the code was written; the two
  alternatives put to the operator were admitting the `.test` bases to the context (contradicting
  a Gate 4-ratified decision) and making the image profile-specific via a build ARG (which would
  break the one-image-serves-every-profile property `MEDIATOR_PROFILE` rests on).
- **Impact:** carrying a copy through is a hole in Contract 4 — an artifact nothing recompiled —
  so the branch is written to make that hole impossible to open silently for a shipped profile.
  The test is **file presence, not profile name**: an artifact whose declared base is absent and
  is not a `.test.yaml` fixture **fails the build** (exit 2), so deleting
  `!policy/allowlist.base.yaml` from `.dockerignore` produces a loud failure rather than a quietly
  uncompiled `default`. Probed in both directions, host-side: with the `.test` bases admitted to a
  staged context all three artifacts are compiled and still match their committed copies
  byte-for-byte, which also demonstrates they remain genuinely reproducible; with the base
  allowlist removed, `default` fails rather than being carried. SF-7 Phase A should assert the
  build log names exactly the two carried-through artifacts and no more.
- **The predicate is a CODE CONSTANT, and the first version's was not** (Codex adversarial pass,
  finding 1, HIGH). `emit` originally decided carry-through from the artifact's own
  `compiled_from.allowlist`, testing only that the declared path was missing and ended in
  `.test.yaml`. That let the artifact choose its own branch: adding one spoofed provenance line to
  a hand-edited `policy/resolved/default.yaml` sent the **shipped** profile down the copy path, and
  the drift gate then compared the copy against the file it was copied from and passed.
  Reproduced end to end before fixing — `docker build` succeeded and the image enforced the
  tampered policy, which is precisely the edit this gate exists to catch, and precisely what the
  bullet above claimed was impossible. The predicate cannot live in the file the gate protects, so
  the carried-through profile set, and both fixture base paths, are now constants in
  `compile-stage.sh`; the artifact must additionally agree with them and name its own profile.
  A carried artifact is also run through `--validate`, the same check the mediator makes at stage
  1, since nothing else looks at one.
- **The hole this leaves, stated rather than left to be found.** The build's drift gate is
  *trivially satisfied* for the two carried-through artifacts: they are compared against the copy
  they were made from. Nothing automatic enforces their currency -- `verify-egress-mediator.sh`
  does not invoke the compiler and `lint-policy.sh` does not run `--check`. Nothing enforced it
  before SF-4 either, but before SF-4 nothing *claimed* the build enforced drift. **SF-7 Phase C
  must run `--check` on both fixture artifacts explicitly**, with their `.test` bases, since that
  is the only place their drift can be caught.
- **Contract 5's image-contents sentence is now stale for the runtime stage.** It says "the
  mediator image copies `policy/`, `profiles/`, `packs/` and `mediator/config/`". After SF-4 only
  the *compile* stage sees `profiles/` and `packs/`; the runtime stage carries the compiled policy
  and `mediator/config/` and nothing else. That is a narrowing, not a widening -- but SF-7 Phase
  A's assertion against the built image must be written to the narrower truth or it will fail on
  a correct image.

### Deviation 10: the drift gate is a separate stage from the artifact-extraction target
- **What changed:** the mediator Dockerfile has five stages — `base`, `compile`, `artifact`,
  `drift`, `runtime`. `compile` emits and refuses nothing; `artifact` (`FROM scratch`) depends on
  `compile` alone and is what `scripts/compile-policy-build.sh` extracts from; `drift` is
  `FROM compile` and runs the comparison; `runtime` reaches the policy only via
  `COPY --from=drift`.
- **Originally planned:** Contract 4 states the behaviour ("the mediator image build stage compiles
  authoritatively"; "local build and CI alike fail on drift") as though it were one place, and
  Edge Case 17 resolved the host invocation to run "through the build stage" without saying which
  stage.
- **Why necessary:** the two halves are in direct conflict if they share a stage. The host wrapper
  exists to REGENERATE the committed artifact when the inputs have changed — which is exactly the
  condition the drift gate refuses. A gate inside the emitting stage would fail on the only
  occasion the wrapper is ever run. Splitting them is what lets both halves of Contract 4 hold at
  once, and it is not merely a convenience: `runtime` copying the policy *out of the drift stage*
  is what makes fail-on-drift mechanical rather than a build step someone could reorder away.
- **Impact:** proved by probe rather than asserted — a hand-edit to the committed
  `policy/resolved/default.yaml` fails a plain `docker build` at the `drift` stage with exit 4, and
  `scripts/compile-policy-build.sh` regenerates that same hand-edited artifact successfully.
  SF-6's CI drift job builds the default target and therefore passes through the gate with no
  extra step. SF-7 Phase C's "a drifted committed artifact fails the LOCAL build" is satisfied by
  this stage rather than by a separate check.

### Deviation 11: the agent build context moves to the solution root, resolving a contradiction inside Contract 5
- **What changed:** The three agent services build with `context: ..` and
  `dockerfile: images/Dockerfile` (was `context: ../images`). The solution-root `.dockerignore`
  gains `!images` above its trailing-deny block, every `COPY` in `images/Dockerfile` is rewritten
  to an `images/`-prefixed path, and `images/.dockerignore` is deleted -- Docker resolves
  `.dockerignore` at the context root, so a file at `images/` no longer governs anything.
- **Originally planned:** Contract 5 says two incompatible things. Its re-plan preamble ("The
  agent images' context does not change") and the Files to Create/Modify table (`compose.yaml` --
  "the contexts are already correct -- mediator `context: ..`, agents `context: ../images`";
  `images/.dockerignore` -- "governs the AGENT context, which does not move") say one thing. Its
  own YAML block (`claude: build: context: ..`), its consequences bullets ("`images/.dockerignore`
  no longer applies"; "The agent images copy `packs/` and `profiles/` -- which they need to
  resolve their own package set"; "Two consumers read the pack manifests") and its
  rejected-alternative paragraph on `additional_contexts:` all say the other.
- **Why necessary:** Mechanism, not preference. `packs/` and `profiles/` sit outside `images/`,
  and a build stage can only read its own context -- a `.dockerignore` selects *within* a context
  and cannot admit a path outside one, so the table's "extend only if a pack input must reach it"
  describes an operation that does not exist. SF-5 is unbuildable under the `../images` reading:
  the agent image cannot resolve the profile's pack set from manifests it cannot see. The
  preamble was written to record that 01.3 SF-4 had already moved the *mediator*, and was not
  reconciled with the agent-side half below it. Operator decision, 2026-09-08, taken before any
  code was written.
- **Impact:** `images/.dockerignore` is deleted rather than left inert, so no one maintains a file
  that governs nothing. Edge Case 1's context-size concern now applies to the agent builds too,
  and SF-7 Phase A's context enumeration -- already required to prove
  `mediator/identity/ca/mediator-ca.key` and `references/` are absent -- covers both build
  contexts rather than one. The root `.dockerignore`'s own comment ("`images/.dockerignore`
  governs the AGENT builds ... both files are needed") is now false and is corrected in the same
  commit.

  **A correction to the sentence above, and an obligation it creates for SF-7.** There are no
  longer *two* contexts for Phase A to cover -- there is ONE, shared by both builds, and that
  changes what Phase A can prove. The single context legitimately contains `images/mediator/`,
  `mediator/config/`, `policy/` and `scripts/compile-policy.sh` alongside `packs/` and
  `profiles/`, because the mediator build needs them; none is a secret, and the trailing-deny
  block still keeps `mediator/identity/` and `references/` out. So Contract 5's rule -- "the agent
  images copy `packs/` and `profiles/` ... and **never** `policy/`, `mediator/` or any identity
  path" -- is no longer separable at the context level and **must be asserted against the built
  IMAGE**, which is what Contract 5 already says Phase A does ("SF-7 Phase A asserts that against
  the built images, not against the Dockerfiles"). The division of labour for SF-7 Phase A is
  therefore: the CONTEXT assertion (the CA private key and `references/` are absent) is now one
  assertion covering both builds rather than two, and the IMAGE assertion is what discriminates
  agent from mediator. Written down because the obvious reading -- "the context no longer contains
  control-plane paths, so the agent images cannot have them" -- was true before this deviation and
  is false after it. `!images` sits above the trailing-deny block, so `mediator/identity` and `references`
  stay denied. SF-6's `scripts/build.sh` and CI job must use the root context for agent builds as
  well as for the mediator, which is one context for the whole solution rather than two.

### Deviation 12: `PACK_SET_HASH` is not shipped; the `COPY` layer is the cache-invalidation mechanism
- **What changed:** No `PACK_SET_HASH` build argument exists in `compose/compose.yaml`,
  `compose/pins.env` or `images/Dockerfile`. Edge Case 4's property -- a changed pack set produces
  a different image -- is carried by the `pack-plan` stage's `COPY packs/ profiles/`, whose layer
  cache is keyed on the content of those trees.
- **Originally planned:** Edge Case 4 ("Handled by making the composed pack set a build argument
  -- `PACK_SET_HASH` -- so a changed pack set produces a different image") and the Files to
  Create/Modify entry for `compose.yaml` ("`PACK_SET_HASH` and `AGENT_BASE_DIGEST` build args").
- **Why necessary:** The argument has no producer. The documented entry point is `up --build`
  (Contract 4, amended at SF-4), and Compose interpolates build args only from the environment and
  `--env-file compose/pins.env`; nothing in the solution computes a pack-set hash into either.
  Shipping the argument would ship a value that is either absent or hand-maintained, and a
  hand-maintained hash that is not recomputed is exactly the stale-cache failure Edge Case 4
  exists to prevent -- it would report "unchanged" while the manifests had changed. Content-
  addressed `COPY` invalidation cannot go stale, because BuildKit hashes the files themselves.
  Operator decision, 2026-09-08, taken before any code was written.
- **Impact:** SF-7 Phase D asserts the rebuild by comparing image IDs across a pack-set change,
  not by reading a build argument's value. The property is strengthened, not weakened: a hash
  argument would have covered only the manifests an operator remembered to hash, while the `COPY`
  covers every file in `packs/` and `profiles/`. SF-6's `scripts/build.sh` needs no hash-producing
  step. `AGENT_BASE_DIGEST`, the other half of that table entry, is untouched and stays SF-6's.

### Deviation 13: `apt` checksums are asserted for the declared items only; the transitive closure rides the signed index
- **What changed:** The build downloads the manifest's declared `apt` items, verifies each
  `.deb` against its recorded `sha256` before installing, and installs the remaining transitive
  dependencies through `apt-get` under the pinned snapshot repository, whose `InRelease` signature
  and full key fingerprint are asserted at build. `packs/README.md` records the gap as a residual
  against R7.3.
- **Originally planned:** Interface Contract 1 and Edge Case 8 both state the rule without
  qualification -- "Every package carries a SHA-256, `apt` items included; R7.3 is a MUST and says
  'checksums' without qualification" -- and `packs/language-runtimes/pack.yaml` repeats it.
- **Why necessary:** Measured, not assumed. `apt-get install --no-install-recommends python3
  python3-venv git` against the pinned snapshot resolves to **40** packages on this base; the
  manifest declares 3. The 37 others are a dependency closure `apt` computes, and their integrity
  comes from the same chain that makes the declared hashes trustworthy in the first place: the
  `bookworm` archive key's `gpgv` signature over `InRelease`, whose `VALIDSIG` line carries
  `B8B80B5B623EAB6AD8775C45B7C5D7D6350947F8` -- the fingerprint `profiles/default.yaml` pins --
  and the per-`.deb` hashes in the signed `Packages` index it covers. Enumerating the closure in
  the manifest would be literal compliance that re-breaks on every snapshot bump and on any
  profile whose base image differs, and it would not add a trust anchor the fingerprint does not
  already provide. Operator decision, 2026-09-08, taken before any code was written.
- **Impact:** R7.3 is met for declared packages and met *by a different mechanism* for their
  closure; the distinction is recorded rather than claimed away, in the same posture the Approach
  takes on R7.19's language-level installers. SF-7 Phase A's "every package entry, `apt` included,
  carries a SHA-256" is an assertion about the **manifest**, not about the installed set, and
  stays true as written. If a future pack needs closure-level pinning, the mechanism is a
  `.deb`-level lockfile, which is a manifest-schema change and therefore SF-1's, not an install-
  step change.

  **`jq` is a fourth package in this category, and it moved into it at SF-5.** The `agy` stage
  installs `jq` for `agy-run.sh`'s status-field gating (01.2), and it is declared by no manifest
  and carries no recorded hash. Before SF-5 it came from the rolling `deb.debian.org` archive;
  `images/apt-pinned.sh` makes the pinned snapshot the image's ONLY apt source, so `jq` now comes
  from the snapshot and rides exactly the chain described above -- strictly more reproducible than
  it was, and still not manifest-pinned. Named here so the count is honest: three packages are
  hash-declared (`python3`, `python3-venv`, `git`) and everything else in the image, `jq`
  included, is covered by the signature and the signed index.

### Deviation 14: the GHCR namespace is `ottawacloudconsulting/agentic-ai`, not `OCC-github/agentic-ai`

- **What changed:** `.github/workflows/agent-sandbox-image.yml` publishes to
  `ghcr.io/ottawacloudconsulting/agentic-ai/agent-sandbox-base`.
- **Originally planned:** Dependencies, "External": "a GHCR namespace under `OCC-github/agentic-ai`".
- **Why necessary:** `OCC-github` is a directory on the operator's workstation, not a GitHub owner.
  `git remote -v` gives `https://github.com/OttawaCloudConsulting/agentic-ai.git`, and GHCR path
  components must be lowercase, so the namespace is `ottawacloudconsulting/agentic-ai`. The planned
  name has no owner behind it and a push to it would fail authentication.
- **Impact:** The image reference is hardcoded in the workflow's `env.IMAGE` and will be hardcoded
  again in `images/Dockerfile`'s `FROM` at SF-6b -- two places that must agree, and neither derives
  from `${{ github.repository }}`, deliberately: a fork must not silently redirect the base image
  the agent stages pin. Anything in Milestone 02 or 03 that names the published image (T45's
  provenance check in 02.4) inherits this name.

### Deviation 15: the published base image is single-architecture, `linux/arm64`

- **What changed:** The publish job runs on `ubuntu-24.04-arm` and passes `platforms: linux/arm64`.
  The drift job stays on the x86 runner and is unconstrained.
- **Originally planned:** Neither the plan nor D21 names an architecture. D21 says only "the base
  image is built by GitHub Actions and published to GHCR", which reads as architecture-neutral and
  would default to the `ubuntu-latest` amd64 runner.
- **Why necessary:** MECHANISM, not preference, and it fails loudly rather than subtly.
  `images/apt-pinned.sh` verifies `git` by hashing the `.deb` that `apt-get download` fetches, and
  `apt-get download` fetches for the container's own dpkg architecture. `compose/pins.env` carries
  ONE `GIT_SHA256`; it is the arm64 hash, evidenced by SF-5's three images having built on this
  Apple silicon host. On an amd64 runner the fetched `.deb` is a different file and `apt-pinned.sh`
  exits at "checksum mismatch". Adding an amd64 pin to go multi-arch would mean deriving a hash
  nobody has verified against the signed index, which is the discipline SF-1 established against.
  The pod's only stated target is Docker Desktop on Apple silicon (R11.1, assumption A1).
- **Impact:** D21's "the base image" is single-architecture for as long as A1 holds. An operator on
  an x86 workstation cannot consume the published base -- SF-6b's digest pin would resolve to an
  index with no matching platform. Making the pod multi-architecture is a `pins.env` change (a
  second, separately verified `GIT_SHA256`) plus a `platforms:` line, in that order; it is not a
  runner-label change. The drift job is unaffected: the mediator's base digest is a multi-platform
  index (measured: 8 platforms) and the compile stage's `yq` is pinned for both architectures.

### Deviation 16: `AGENT_PROFILE` now selects the mediator's runtime profile too

- **What changed:** `compose/compose.yaml` sets `MEDIATOR_PROFILE: ${AGENT_PROFILE:-default}` on
  the `egress-mediator` service, so one variable selects both the agents' pack set and the policy
  the mediator enforces. `scripts/build.sh` prints the matching run command.
- **Originally planned:** SF-5's review pass recorded the divergence as a residual and assigned it
  here -- "the mediator's runtime profile and the agent build's PROFILE arg can diverge... unifying
  them is the per-profile build assigned to SF-6" -- without saying the unification would be a
  Compose change rather than something `build.sh` does on its own.
- **Why necessary:** `build.sh` builds; it cannot constrain a later `docker compose up`. Before this
  line the base Compose file never set `MEDIATOR_PROFILE` and `images/mediator/entrypoint.sh:64`
  defaulted it to `default`, so `AGENT_PROFILE=oauth-mount docker compose up --build` built agent
  images for one profile's pack set while enforcing another profile's policy, with no surface
  reporting the mismatch. Inert only because the two shipped profiles select identical pack sets.
- **Impact:** `AGENT_PROFILE` widens from a build-time selector to the pod's profile selector. It is
  NOT renamed to `POD_PROFILE`: renaming touches the three agent build blocks that already read it,
  and a second name for one selection is how the divergence returns. `compose/overrides/test-egress.yaml`
  still wins for the acceptance harness because later `-f` files layer over the base -- probed in
  both directions: with `AGENT_PROFILE=default MEDIATOR_TEST_PROFILE=test-selfcheck`, the base alone
  resolves `default` and the harness override resolves `test-selfcheck`. SF-7's Phase D, which
  changes a profile's pack set and re-runs the documented command, now exercises one selector rather
  than two.
