# `policy/resolved/` — generated output

Everything in this directory is **generated**. Do not hand-edit it.

## Producer

`scripts/compile-policy.sh` (Feature 01.3, SF-2), in its zero-pack form. It reads three inputs and
emits one artifact per profile:

| Input | Owner |
|---|---|
| `policy/allowlist.base.yaml` | Feature 01.1 SF-3 — discovery-derived, per agent, `provisional: true` (D17) |
| `policy/denylist.base.yaml` | Feature 01.1 SF-3, extended by 01.3 SF-2 with `deny_fqdns` (R5.1) |
| `profiles/<profile>.yaml` | Feature 01.2, extended by 01.3 SF-2 with `listeners`, `rate_limits`, `egress_exclusions` and `startup_check` |

```bash
bash scripts/compile-policy.sh                              # compile the default profile
bash scripts/compile-policy.sh --profile <name>             # compile another profile
bash scripts/compile-policy.sh --check                      # is the committed artifact current?
bash scripts/compile-policy.sh --validate <path>            # schema check only
```

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
shows up in a diff rather than inside an image layer. `--check` is the enforcement: it recompiles
from the inputs and fails if the committed file does not match, ignoring only `compiled_at`.

**If you need to change what an agent may reach, edit an input and recompile.** Editing a file here
is reverted by the next compile and caught by the next `--check`.

## Files

| File | Purpose |
|---|---|
| `default.yaml` | The shipped profile's resolved policy. Loaded by the mediator at start |
| `test-fixtures.yaml` | Test-scoped policy allowlisting the acceptance harness's own fixtures (01.3 SF-8). Never loaded by the default profile |

## What the artifact does *not* contain

- **Packs.** `compiled_from.packs` is present and empty. Pack composition is Feature 01.5's (D10),
  which also moves compilation into a build stage of the mediator image. The schema here is what
  01.5 must continue to emit.
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
