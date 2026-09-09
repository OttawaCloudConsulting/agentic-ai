# `policy/resolved/` — generated output

Everything in this directory is **generated**. Do not hand-edit it.

## Producer

`scripts/compile-policy.sh` (Feature 01.3 SF-2; pack composition added at 01.5 SF-3). It reads
three inputs plus the profile's selected packs, and emits one artifact per profile:

| Input | Owner |
|---|---|
| `policy/allowlist.base.yaml` | Feature 01.1 SF-3 — discovery-derived, per agent, `provisional: true` (D17) |
| `policy/denylist.base.yaml` | Feature 01.1 SF-3, extended by 01.3 SF-2 with `deny_fqdns` (R5.1) |
| `profiles/<profile>.yaml` | Feature 01.2, extended by 01.3 SF-2 with `listeners`, `rate_limits`, `egress_exclusions` and `startup_check` |

| `packs/<name>/pack.yaml` | Feature 01.5 SF-1 — composed into the per-agent egress sets and recorded, with its content hash, in `compiled_from.packs` |

```bash
bash scripts/compile-policy.sh                              # compile the default profile
bash scripts/compile-policy.sh --profile <name>             # compile another profile
bash scripts/compile-policy.sh --check                      # is the committed artifact current?
bash scripts/compile-policy.sh --validate <path>            # schema check only
```

Exit codes: `0` success or no drift, `1` invocation error, `2` malformed input, `3` a refusal gate
tripped (a recorded policy decision, not a syntax error), `4` `--check` found drift.

## The refresh procedure (01.5 SF-4)

**The authoritative compile happens inside the mediator image**, in a build stage — R7.4 and D10
require the policy to be composed by the build rather than by an operator step. So the command that
refreshes this directory runs the host invocation *through* that same stage, which is what keeps
there being exactly one emitter:

```bash
bash scripts/compile-policy-build.sh    # builds --target artifact and writes the result here
# review the diff, then commit it
```

Running `scripts/compile-policy.sh` directly still works and is still the right thing on a fresh
clone with no Docker — it just compiles with whatever `yq` the host happens to have. The two were
measured as byte-identical on this schema (host `yq` v4.53.6 versus the image's pinned v4.47.2,
packs included, 2026-09-08), so the difference this closes is latent rather than active.

`compile-policy-build.sh` leaves an artifact alone when only `compiled_at` would move, so
`git status` stays a usable answer to "did the policy actually change?".

## The test-scoped artifacts

`test-fixtures.yaml` and `test-selfcheck.yaml` are compiled from **different bases** — the
acceptance harness (01.3 SF-8) drives its assertions against fixtures it owns, and those
hostnames must not enter `policy/allowlist.base.yaml`, which is discovery-derived and carries
`provisional: true` against `docs/records/agent-verification.md`. `--allowlist` and `--denylist`
select the bases; every artifact records which ones it was built from in `compiled_from`, and its
own header repeats the invocation that re-verifies it:

```bash
bash scripts/compile-policy.sh --profile test-fixtures \
  --allowlist policy/allowlist.test.yaml --denylist policy/denylist.test.yaml
```

`policy/denylist.test.yaml` deliberately omits `172.16.0.0/12`, which the shipped denylist
carries and R5.6 requires — Docker's bridges are RFC 1918, so the harness's own fixtures sit
inside that range and no allowed-path assertion could pass with it loaded. The file says so at
the top. `bash scripts/lint-policy.sh` checks the **base** denylist for all five ranges and is
unaffected.

## Why the output is committed

SC-6: the mediator's configuration is generated from this artifact and never hand-authored, and the
artifact itself is reviewable in version control — so a change to what the pod is allowed to reach
shows up in a diff rather than inside an image layer.

**The build fails on drift, it does not warn** (Interface Contract 4, R5.14). The mediator image's
`drift` stage compares what the build just compiled against the committed copy here, ignoring only
`compiled_at`, and refuses to continue if they differ — and the runtime stage reaches the policy
only *through* that gate, so the refusal is mechanical rather than advisory. A warning in a build
log is not a reviewed policy change; warning instead would produce a mediator running a policy no
reviewer has seen, and would make this directory decorative, since nothing would ever force it to
be true. `bash scripts/compile-policy.sh --check` is the same comparison run on the host, at
exit 4.

**If you need to change what an agent may reach, edit an input and recompile.** Editing a file here
is reverted by the next refresh, caught by the next `--check`, and fails the next build.

## Files

| File | Purpose |
|---|---|
| `default.yaml` | The shipped profile's resolved policy. Loaded by the mediator at start |
| `test-fixtures.yaml` | Test-scoped policy allowlisting the acceptance harness's own fixtures (01.3 SF-8). Never loaded by the default profile |
| `test-selfcheck.yaml` | Test-scoped policy for the startup self-check assertions (01.3 SF-8). Never loaded by the default profile |

The two test-scoped artifacts are the one exception to "the build compiles it": their bases
(`policy/allowlist.test.yaml`, `policy/denylist.test.yaml`) are deliberately kept out of the
mediator's build context, so the compile stage carries the committed copies through unchanged and
says so in the build log (01.5 SF-4 Deviation 9). The shipped `default.yaml` can take no such path
— an artifact whose declared base is missing from the context and is *not* a `.test.yaml` fixture
fails the build.

## What the artifact does *not* contain

- **Anything a pack cannot supply.** `compiled_from.packs` is populated as of 01.5 SF-3, and a
  pack contributes runtime FQDNs and CIDRs and nothing else: pack-supplied mounts, environment
  variables and credentials are *refused* at compile rather than composed (SF-3 Deviation 5), and
  build-time egress never enters this artifact at all.
- **Anything secret.** No keys, no tokens, no certificates. Identity material lives under
  `mediator/identity/` and is git-ignored.

## Two fields worth reading before you trust the file

- **`provisional: true`** is inherited from `policy/allowlist.base.yaml` and means exactly what it
  says: the seed allowlist was built from a single discovery capture and several entries are not yet
  cross-validated against a second source. Read `docs/records/egress-discovery.md` before treating
  any entry as settled.
- **`exclusions:`** lists entries that are present in the base allowlist and deliberately **not**
  granted, each with its reason. An excluded host is refused by default-deny; it is recorded here so
  the decision is auditable rather than looking like an oversight. At this milestone it carries
  `agy`'s auto-updater host (R10.3).
