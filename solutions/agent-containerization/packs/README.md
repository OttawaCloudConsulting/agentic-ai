# Packs

A **pack** is a declared, composable bundle of capability: OS and language packages, the egress
it needs, the mounts and environment it requires, and a statement of what a compromised agent
gains when it loads. A profile selects packs by directory name; `scripts/compile-policy.sh`
composes the selected manifests into `policy/resolved/<profile>.yaml`, and the agent image build
resolves the same manifests into its package set.

Two consumers read these files, and only one of them is the policy compiler:

| Consumer | Reads | Produces |
|---|---|---|
| `scripts/compile-policy.sh`, in the mediator image's compile stage | `egress.runtime`, `mounts`, `env`, `credentials` | the resolved egress policy the mediator enforces |
| the agent image build (`images/Dockerfile`) | `packages`, `egress.build` | the installed toolchain in that agent's image layer |

A change to the schema below therefore touches both readers.

## Manifest schema — `packs/<name>/pack.yaml`

Every field is mandatory. `scripts/lint-policy.sh` refuses a manifest missing any of them, naming
the file and the failing field. Absence is never treated as a default: a pack that forgets to
declare `credentials` is a pack whose author did not answer the question, which is not the same
as a pack that needs none.

| Field | Requirement | Meaning |
|---|---|---|
| `name` | must equal the pack's directory name | how a profile selects it |
| `description` | — | one line, for a human reading a profile |
| `schema` | must be `1` | manifest format version |
| `blast_radius` | R7.11 | what a compromised agent gains when this pack loads. Prose, and it is meant to be read before a pack is added to a profile |
| `needs_write_access` | R7.3 | whether the pack requires write access |
| `packages` | R7.3, R7.18 | `apt.items[]` and `archives[]`, each pinned to an exact version **and carrying a SHA-256** |
| `egress.runtime` | R7.3 | `allow_fqdns` / `allow_cidrs` composed into the resolved policy. This is reach the running agent gains |
| `egress.build` | R10.4 | `allow_fqdns` the **image build** reaches. Never enters `policy/resolved/` |
| `runtime_install` | R7.6 | `true` requires `runtime_install_reason` **and** non-empty `egress.runtime`. Both directions are enforced |
| `runtime_install_reason` | R7.6 | mandatory **only** where `runtime_install: true`; absent otherwise, as in this pack. Must be TEXT: an empty list or map is refused, because yq renders both as printable strings and a `[]` here would record nothing while looking filled in |
| `mounts` | R7.3 | required mounts and their modes. Keys must be in the enumerated R2 set |
| `env` | R7.3 | required environment variables |
| `credentials` | R7.3 | required credentials |

`runtime_install` and its reason are refused in **both** directions (01.5 SF-2). Runtime egress
with `runtime_install: false` is a widening R7.6 requires declared; `runtime_install: true` with
no reason is a default flipped rather than a decision taken; and `runtime_install: true` with no
`egress.runtime` records a widening the resolved policy does not carry. `scripts/lint-policy.sh`
fails on the missing reason (well-formedness, exit 1); `scripts/compile-policy.sh` refuses all
three at **exit 3**, because which packs a profile may load is a policy decision, not a typo.

A pack may **not** declare `deny_fqdns` or `deny_cidrs`. The denylist is copied from
`policy/denylist.base.yaml` unmodified and deny wins after resolution; a pack-supplied deny key
would appear to narrow or widen it and would in fact do neither. The linter rejects it.

### `egress.build` is not `egress.runtime`

Build-time egress is consumed by the image build, which runs on the host build network, and never
reaches `policy/resolved/`. Conflating the two is exactly how a pack would silently acquire
runtime registry reach — the pack fetches Go from `go.dev` at build, and an agent then reaches
`go.dev` at runtime for the rest of the image's life.

### Every package carries a checksum, `apt` items included

R7.3 is a MUST and says "checksums" without qualification. The argument that a signed `Release`
makes a per-package hash redundant is an argument for `apt` being *safe*; it is not an argument
for the manifest being *pinned*, and SC-8 measures a clean rebuild months later, which is where
an unpinned resolve fails.

The repository must also be a **snapshot, not a suite**. `suite: bookworm` plus `name=version`
resolves today and fails in six months, because Debian rotates the archive and drops superseded
versions. The profile declares a `snapshot.debian.org` URL carrying a timestamp, plus the
fingerprint of the key that signs it.

## How these hashes were obtained

Stated because a checksum whose provenance nobody recorded is a number, not a pin. Verified on
2026-09-07, in this order:

1. `debian-archive-bookworm-automatic.gpg` was taken from the base image's own
   `/usr/share/keyrings/`. Primary key fingerprint
   `B8B80B5B623EAB6AD8775C45B7C5D7D6350947F8`, uid *Debian Archive Automatic Signing Key
   (12/bookworm)*.
2. `gpgv` against that keyring reports a **good signature** on the snapshot's
   `dists/bookworm/InRelease` at `20260901T000000Z`.
3. The SHA-256 of the downloaded `main/binary-arm64/Packages.xz` **matches the value in that
   signed `InRelease`**.
4. The per-`.deb` SHA-256 values in `language-runtimes/pack.yaml` are read from that verified
   index.
5. The Node and Go archive hashes come from `nodejs.org/dist/v22.23.2/SHASUMS256.txt` and the
   `go.dev` release index respectively.

Steps 1-3 are the part worth repeating when a pin changes: without them, step 4 copies numbers
from a file an attacker could have served.

## The reference pack grants no runtime egress, and that is the point

`language-runtimes` declares `egress.runtime.allow_fqdns: []`. A pack granting runtime registry
egress — `registry.npmjs.org`, PyPI, the Go module proxy — would enable arbitrary `npx <server>`
and break **T31** on every profile that loads it. R7.6 keeps runtime-install egress off by
default and explicitly declared where it is used.

**What this costs an operator, stated plainly.** Inside a running agent container, `pip install`,
`npm install` and `go install` do not work. That is deliberate, and it fails at **two different
layers** depending on what is attempted — an operator who does not know this will read either as
a bug:

| Attempt | Where it fails | What the operator sees |
|---|---|---|
| `pip install X`, `npm install X` | the **filesystem** — `pip`, `ensurepip` and the bundled `npm` tree are removed from the image | "command not found" or a missing-module error. **No audit line**, because nothing reached the mediator |
| `python3 -m pip`, a direct `npm-cli.js` path | the filesystem, same reason | as above |
| `go install`, or a vendored/self-written installer | the **mediator** — the destination is not in the resolved allowlist | a connection failure, **and an audited denial naming the blocked destination** |

The second row is why `go` is a genuinely different case: the real `go` binary must remain for
`go build`, so the toolchain keeps a working installer. The control that holds there is the
absence of egress, not the absence of a binary — and it is the control that produces the log line
**T15** requires.

**What is claimed and what is not.** T33 (package manager "fails for want of both privilege and
write access") is claimed for the **OS** manager only: `apt`/`apt-get`/`dpkg` are removed, the
root filesystem is read-only, and the agent is a non-root uid with `cap_drop: ALL`. For the
**language-level** managers the filesystem clause of R7.19 is structurally unsatisfiable while
`/home/agent` and `/workspace` are writable — and SC-4 requires them writable, because that is
where session state lives. Removing the installer packages raises the cost; it does not close the
class. The residual is recorded here rather than claimed away.

## Notes on the reference pack's contents

- **Node is pinned to the version the base image already carries** (`22.23.2`, from
  `node:22-slim` as of 2026-09-07) rather than to a different major. Two Node runtimes on `PATH`
  would leave the winner deciding what the agent CLIs execute against. Declaring it in the
  manifest rather than treating it as base-provided is an operator decision: the pin becomes
  explicit and checksum-verified instead of riding a moving tag.
- **`git` is not in this pack.** It is installed in the `agent-base` stage of `images/Dockerfile`,
  by operator decision, because `mounts.host_git_config` (R2.9) and `scripts/scrub-gitconfig.sh`
  are profile-level features that must work regardless of which packs a profile selects — Feature
  01.4 Deviation 9 found the mount was inert with no `git` binary present. It adds no egress:
  `github.com` is not in the resolved allowlist, so `git` works for local commits under
  `/workspace` and is denied at the mediator on fetch or push.
- **The archive URLs are `linux-arm64`.** A1/R11.1 pin the platform to Apple silicon and the agent
  images are built locally per profile, never by CI, so one architecture is the entire supported
  surface. A second architecture means a second manifest or a schema keying hashes by
  architecture; neither is needed yet and neither is invented here.
