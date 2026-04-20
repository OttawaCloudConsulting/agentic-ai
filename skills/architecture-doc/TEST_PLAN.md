# architecture-doc Skill — Test Plan

> Execution and evaluation plan for the `architecture-doc` skill, using
> isolated sub-agents as both the runner and the judge so no pre-existing
> session context leaks into the results.

## 1 — Goals

Validate that the skill, as authored in
`skills/architecture-doc/SKILL.md`, can be successfully executed by an
agent that has **no prior context** about how the skill was designed,
and that the artifacts it produces are faithful to the source repo
under test.

Three orthogonal things are being tested:

| Axis | Question |
|---|---|
| **Legibility** | Can a cold-start agent read `SKILL.md` and execute it without stumbling on ambiguity? |
| **Correctness** | Does the produced `docs/ARCHITECTURE_AND_DESIGN.md` match the repo it was generated from? |
| **Mode isolation** | Do Create and Audit paths both work, and does Audit preserve user-authored content as promised? |

Anything that fails one of these axes is a bug in the skill — either in
the prose of `SKILL.md`, in the referenced prompt templates, or in the
orchestration shape.

## 2 — Test Fixtures

Two locally cloned repos under `temp/`:

| Fixture | Path | Initial state |
|---|---|---|
| `app-config` | `temp/occ-k8s-app-config/` | No `docs/` dir, no architecture doc. Contains bootstrap, platform-shared, application-sets, removed, documents/xmr-rig subtree, `README.md`, `CHANGELOG.md`. |
| `cluster-config` | `temp/occ-k8s-cluster-config/` | No `docs/` dir, no architecture doc. Contains bootstrap, app-of-apps, application-sets, application-sets-system, removed, `README.md`, `TODO.md`. |

Both are clean slates — first run hits **Create** mode, second run on
the same repo hits **Audit** mode. Both look like multi-app
ArgoCD/Kubernetes GitOps repos, so the monorepo heuristic may fire in
the scan agent. The test brief must handle that deterministically.

**Fixture hygiene.** Neither fixture repo is checked into this repo's
tree — they live under `temp/` which is gitignored. Any artifacts the
skill writes (`docs/ARCHITECTURE_AND_DESIGN.md`,
`docs/.architecture-doc/`) must be cleaned up between runs. The
cleanup procedure is spelled out in §6.

## 3 — Sub-Agent Runner Strategy

The skill is normally invoked via the `Skill` tool, which loads
`SKILL.md` into the caller's context. Sub-agents spawned via the
`Agent` tool do **not** have the `Skill` tool available — but they
**can** `Read` the `SKILL.md` file directly and execute its prose,
which is functionally the same thing. This is the substrate the test
plan exploits.

### 3.1 — Runner brief structure

Each runner sub-agent receives a brief with these fixed sections:

1. **Context reset.** "You are a fresh agent. You have no prior
   knowledge of the `architecture-doc` skill or how it was designed.
   Treat `skills/architecture-doc/SKILL.md` as a specification you
   must execute verbatim."
2. **Entry point.** Absolute path to `SKILL.md` and the `target_path`
   the skill must be run against.
3. **Non-interactive decisions.** Pre-committed answers for every
   `AskUserQuestion` branch the skill might hit. The runner treats
   these as "the user said X" without actually calling
   `AskUserQuestion`. This is necessary because a sub-agent's
   `AskUserQuestion` routing is not a reliable test surface.
4. **Success reporting.** The runner must report, at return time:
   - The resolved `target_path` and `mode` it ran in.
   - Whether `docs/ARCHITECTURE_AND_DESIGN.md` was produced.
   - Whether all six canonical sections are present.
   - The contents of `docs/.architecture-doc/run.log` verbatim.
   - Any step where it had to make a judgment call the prose
     did not cover, and what it chose. (This is the legibility
     signal — these are bugs in `SKILL.md`.)
5. **Boundaries.** The runner must not touch anything outside
   `target_path`, must not modify source code in the fixture, and
   must not invoke other skills.

### 3.2 — Pre-committed decisions

For every `AskUserQuestion` branch the skill might reach, the brief
pre-commits an answer:

| Decision point | Answer in brief | Why |
|---|---|---|
| Mode selection (Step 2, doc exists and is Markdown) | `Audit` on the second run of a given fixture; N/A on first run | Exercises both paths across the two runs. |
| Mode selection (Step 2, doc exists but not plausibly Markdown) | `Overwrite` | Not expected to fire on these fixtures, but covered defensively. |
| LS enrichment opt-in (Step 4.0) | `Skip` | Keeps baseline path under test. No LS MCP is known to be present in the test session. |
| Monorepo warning (Step 4.7) | `Continue` | Both fixtures look monorepo-shaped; we want the scan to proceed. |
| Diagram enrichment opt-in (Step 8.3) | `Skip` | Keeps baseline path under test. Mermaid MCP may or may not be present in the test session; skipping isolates the text-synthesis path. |
| Review-loop decision (Step 9) | `Accept` on first pass | Review loop is a separate test dimension; see §4.4. |

### 3.3 — Judge sub-agent

For each run, a **separate** judge sub-agent is spawned after the
runner returns. The judge has never seen `SKILL.md`, the runner's
brief, or the scratch directory — it sees only:

- The fixture repo (`target_path`)
- The produced `docs/ARCHITECTURE_AND_DESIGN.md`

and is asked to score the document against a rubric (§5). Isolation
is enforced by spawning the judge from the main session, not from
the runner.

## 4 — Test Cases

### 4.1 — TC-1: Create on `app-config`

- **Runner target:** `temp/occ-k8s-app-config/`
- **Expected mode:** `Create` (no doc exists)
- **Expected scan return:** `success` (monorepo warning possible → Continue)
- **Expected synthesis return:** `success` with non-zero decisions and components counts
- **Expected artifacts:**
  - `temp/occ-k8s-app-config/docs/ARCHITECTURE_AND_DESIGN.md` exists, non-empty, contains all six canonical sections.
  - `temp/occ-k8s-app-config/docs/.architecture-doc/run.log` exists and contains, at minimum: `session start`, a `probe` summary line, `scan spawn`, `scan return status=success`, `synthesis spawn mode=Create`, `synthesis return status=success`, `synthesis template_ok`, `synthesis structural_validation ok`.
- **Judge pass criteria:** See §5. Document must reference the fixture's actual top-level components (`bootstrap`, `application-sets`, `platform-shared`, etc.) — not invented ones.

### 4.2 — TC-2: Create on `cluster-config`

- **Runner target:** `temp/occ-k8s-cluster-config/`
- **Expected mode:** `Create`
- **Expected scan return:** `success`
- **Expected synthesis return:** `success`
- **Expected artifacts:** same shape as TC-1, but scoped to `cluster-config`'s tree.
- **Judge pass criteria:** Document must reference `bootstrap`, `app-of-apps`, `application-sets`, `application-sets-system`, and must not conflate this repo with `app-config`. Cross-fixture contamination is a red-flag bug.

### 4.3 — TC-3: Audit on `app-config`

Runs **after** TC-1 has produced a doc.

- **Runner target:** `temp/occ-k8s-app-config/`
- **Pre-step:** Runner must first append a clearly user-authored paragraph to the existing `docs/ARCHITECTURE_AND_DESIGN.md` — a marker sentence like `USER PRESERVATION SENTINEL: do not remove.` placed in the `## Deployment & Operations` section. This lets the judge verify Audit's preservation guarantee.
- **Expected mode:** `Audit` (runner answers `Audit` to the mode prompt)
- **Expected synthesis return:** `success` with `new_decisions`, `findings`, `contradictions` counts (any value)
- **Expected artifacts:**
  - `docs/ARCHITECTURE_AND_DESIGN.md` still contains the user preservation sentinel verbatim.
  - `run.log` contains `synthesis spawn mode=Audit` and `synthesis return status=success mode=Audit`.
- **Judge pass criteria:** Preservation sentinel survived. If there are `findings` rows, they must cite real files in the repo, not fabricated paths. If `contradictions > 0`, each contradiction must be defensible against the actual source.

### 4.4 — TC-4: Audit on `cluster-config` with forced drift

Runs **after** TC-2 has produced a doc.

- **Pre-step:** Runner edits the produced doc to introduce **deliberate drift** — e.g., rename `app-of-apps` to `app-of-oranges` in the Component Inventory table, and change a Design Decision row's Status from `Accepted` to `Superseded` with a fabricated reason.
- **Expected mode:** `Audit`
- **Expected Audit behaviour:** The audit should detect the drift and log at least one `contradiction`-type finding. Per `audit-mode.md`, it must not silently "fix" the drift — the user is the authority on what stays; the audit only reports.
- **Judge pass criteria:** At least one contradiction in the Audit Findings block naming the forced-drift item. No silent overwrite.

### 4.5 — TC-5: Preflight abort on empty directory

- **Runner target:** `temp/occ-empty-test/` (test harness creates this directory empty before the run, removes it after)
- **Expected scan return:** `preflight_abort reason=empty`
- **Expected artifacts:** No `docs/ARCHITECTURE_AND_DESIGN.md` produced. `run.log` contains the preflight abort line. Scratch dir cleaned up by Step 10.
- **Judge pass criteria:** Runner reports the abort cleanly and does not fabricate a document.

### 4.6 — TC-6: Invalid `target_path`

- **Runner target:** `temp/occ-does-not-exist/`
- **Expected behaviour:** Step 1 aborts with a one-line error. No scratch dir created, no sub-agents spawned.
- **Judge pass criteria:** Error message names the failing check (nonexistent / not a directory) and the resolved path. No partial artifacts.

## 5 — Judge Rubric

The judge sub-agent scores each produced `docs/ARCHITECTURE_AND_DESIGN.md`
along five dimensions, using the fixture repo as ground truth. Each
dimension is Pass / Flag / Fail.

| # | Dimension | Pass | Fail |
|---|---|---|---|
| 1 | **Structural** | All six canonical sections present with correct ATX headers. | Any canonical section missing or misnamed. |
| 2 | **Component fidelity** | Every row in the Component Inventory names a real directory or file that exists in the fixture. | Any fabricated or hallucinated component. |
| 3 | **Decision grounding** | Every Design Decision either cites a real file, or is derivable from the repo's stated purpose. | Any decision that contradicts observable repo structure. |
| 4 | **File citation discipline** | Every file path mentioned in the body exists under `target_path`. | Any cited path does not resolve. |
| 5 | **Scope containment** | The document describes only `target_path` and does not leak content from the other fixture or from the host agentic-ai repo. | Cross-fixture contamination, references to unrelated repos, or copy-paste from `skills/**`. |

A **Flag** is a soft warning — factually correct but unclear,
redundant, or stylistically off. Multiple flags do not fail a test
case on their own, but they accumulate as skill-quality signal.

The judge must output its findings as a small Markdown block per
dimension with a concrete example from the document for each Fail or
Flag. No prose preamble.

## 6 — Execution Procedure

The following runs sequentially from the main session. Each sub-agent
invocation is a single `Agent` call; the parent session chains them.

1. **Pre-run cleanup.** Remove `docs/` from both fixture repos if
   it exists, so every run starts from a known clean state. Create
   `temp/occ-empty-test/` for TC-5 and confirm `temp/occ-does-not-exist/`
   does not exist.
2. **TC-1 runner.** Spawn runner sub-agent with the brief from §3.1
   targeting `app-config`. On return, capture the runner's report.
3. **TC-1 judge.** Spawn judge sub-agent with no knowledge of the
   runner or `SKILL.md`. Capture rubric output.
4. **TC-2 runner + judge.** Same, targeting `cluster-config`.
5. **TC-3 pre-step.** Inject the user preservation sentinel into
   the TC-1 output doc from the main session (not from the runner —
   this is fixture setup).
6. **TC-3 runner + judge.** Runner is briefed to answer `Audit` at
   the mode prompt.
7. **TC-4 pre-step.** Main session edits the TC-2 output doc to
   introduce the deliberate drift described in §4.4.
8. **TC-4 runner + judge.**
9. **TC-5 runner.** Targets `temp/occ-empty-test/`. No judge needed —
   the test is pass/fail on whether preflight abort fires cleanly.
10. **TC-6 runner.** Targets `temp/occ-does-not-exist/`. No judge
    needed — the test is pass/fail on the Step 1 error.
11. **Post-run cleanup.** Remove `docs/` from both fixture repos,
    remove `temp/occ-empty-test/`. Fixtures return to their
    pre-test state.

## 7 — Success Criteria

The test plan passes if, and only if:

- TC-1 through TC-4 each produce rubric outputs where every dimension is Pass or Flag (no Fails).
- TC-5 and TC-6 terminate cleanly at the expected abort point.
- Across all six test cases, the **combined** runner "judgment calls the prose did not cover" list is empty, OR contains only items the reviewer judges too minor to cause execution divergence between agents.

A single Fail in any dimension, or a runner report that an earlier
step of the prose was ambiguous enough to block execution, is a skill
bug and must be fixed in `SKILL.md` (or the referenced prompt
templates / heuristics) before the skill is considered shippable.

## 8 — Out of Scope for This Plan

The following are intentionally **not** covered here and should be
tested separately if needed:

- Language-server MCP enrichment (Step 4.0 accept path) — requires an
  LS MCP loaded into the session.
- Diagram MCP enrichment (Step 8 accept path) — requires a Mermaid-class
  MCP loaded into the session.
- Review loop iterations beyond a single Accept (Step 9 Revise / Partial
  / Reject paths) — these are higher-surface interactive behaviours that
  need their own test fixtures.
- Redaction pass hits (Step 4.9, Step 6.7, Step 7.7) — requires a
  fixture that deliberately embeds a matching secret pattern. Do not
  pollute the real fixture repos with fake secrets; build a dedicated
  redaction fixture if this axis needs coverage.
- Symlink path-boundary escape attempts (Decision #9) — requires a
  synthetic fixture with symlinks pointing outside the target tree.
