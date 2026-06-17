# Over-Engineering Review

**Source:** `skills/over-engineering-review/`
**Command:** `/over-engineering-review`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "check for over-engineering", "run the discriminator", "gate this for YAGNI/KISS", "is this over-engineered")

## Description

On-demand active pass that runs the 3-clause discriminator over a target artifact and reports classified findings (`safe-remove` / `needs-decision` / `keep` / `harmful-theater`). A thin wrapper that composes `/simplify` and `/code-review` — it adds only the requirement-ledger freeze and the discriminator, and does not reimplement either sub-pass. This is the on-demand active-detect tier of the over-engineering gate; the reviewer agent profile is the isolated diff-model tier, and the dp2 rule is the always-on reminder tier.

## Usage

```
/over-engineering-review [target]
```

| Target | Meaning |
|---|---|
| *(none)* / `diff` | `git diff HEAD` — the current working-tree diff (default) |
| `<file path>` | Read and review the named file |
| `plan` | Review a plan/design doc referenced in conversation context |

If the target is empty (no diff, no file, nothing in context), the skill stops and asks what to review.

## Workflow

### Step 1 — Resolve Target

Parses the argument after `/over-engineering-review` into a diff, file path, or plan/design reference.

### Step 2 — Freeze the Requirement Ledger

Extracts requirements (in priority order) from: explicit user statements, the target artifact itself, source-of-truth docs the target names as authoritative, `prd.md`, and `docs/ARCHITECTURE_AND_DESIGN.md`. Each requirement is tagged `[user-stated]` or `[agent-inferred]`. Agent-inferred requirements that justify nothing are not added to the ledger — an element whose sole justification is such an entry becomes a flag candidate. The frozen ledger is emitted before any element is evaluated; post-hoc requirement invention cannot enter after the fact.

### Step 3 — Run /simplify and /code-review

Invokes `/simplify` (simplification, redundancy) then `/code-review` (correctness, bugs, reuse) as sub-passes. Their outputs feed Step 4 but are not re-emitted verbatim. If either is unavailable, the skill proceeds on the raw target and notes the absence in the summary.

### Step 4 — Run the Discriminator Per Element

Applies the 3-clause discriminator to each element. Modifiers tune the response after the flag, not before: context tunes severity not detection; reversibility licenses a seam not a feature (with a four-field burden of proof and a blast-radius-escape count); cause-agnostic; and clause 3 as the correctness/safety floor via the delete-the-element test. A boundary-case table resolves retries, logging, input validation, and error handling on one rule — trust boundary + reachability + named failure mode.

### Step 5 — Cost-Gate and Optionally Run Counterfactual

Escalates to a **partial** cold counterfactual (re-derive one layer/section from the frozen ledger **by a different model**, original removed from context) only when a qualifying condition is met — design-stage target, diff >200 lines, "production-ready" phrase clusters, ≥3 axes triggered, or safety-inversion risk — **and** the target clears the cost gate. The gate skips when ALL of: diff <100 lines, ≤2 axes, 0 blast-radius-escape triggers. A full counterfactual on a trivial/reversible target is itself axis-8 over-engineering, so the skill cost-gates it. Full rewrite is reserved for axis-2 structural cases where the shape is the excess.

### Step 6 — Classify and Emit Findings

Classifies each finding `safe-remove`, `needs-decision`, `keep`, or `harmful-theater`, emits one line per finding with the cited clause-absence, and ends with a summary block plus surfaced needs-decision items. Findings are flags, never numeric scores.

## Output

| Output | Description |
|---|---|
| Frozen requirement ledger | `[user-stated]` / `[agent-inferred]` entries emitted before review |
| Classified findings | One line each: `path:line  [tag]  HIGH\|MEDIUM\|LOW  axis-N  clauses absent: element. simpler alternative.` |
| Summary block | Counts per classification + surfaced `needs-decision` items for user decision |

## When to Use

- Reviewing the current diff before committing, to catch unjustified complexity you added
- Gating a plan or design doc for YAGNI/KISS before implementation
- Auditing a named file you suspect is over-engineered

## When Not to Use

- As a bug finder — it composes `/code-review` for that; the discriminator targets unjustified complexity, not correctness defects (those *pass* clause 3)
- On a trivial, reversible change where the gate's own pass costs more than the complexity it could catch (axis-8 self-application guardrail)
- To auto-fix findings — the gate detects and reports; remediation is a separate user-driven step

## Related Skills and Artifacts

- **`/simplify`** and **`/code-review`** — composed as sub-passes; this skill adds the ledger freeze and discriminator on top, it does not replace them.
- **Reviewer agent profile** — [`docs/agent-profiles/over-engineering-reviewer.md`](../agent-profiles/over-engineering-reviewer.md): the isolated, diff-model detect tier. Use it when artifact-anchored bias is the concern; use this skill for an in-session active pass.
- **dp2 rule** — [`docs/rules/defensive-protocol-v2-over-engineering.md`](../rules/defensive-protocol-v2-over-engineering.md): the always-on pre-build reminder tier.
- **Design spec** — [`docs/ARCHITECTURE_AND_DESIGN.md`](../ARCHITECTURE_AND_DESIGN.md).
