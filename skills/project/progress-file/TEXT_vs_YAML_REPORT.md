# TEXT vs YAML: Comparative Analysis Report

> Impartial review of CASE_FOR_YAML.md and CASE_FOR_TEXT.md against REQUIREMENTS.md as source of truth.

---

## 1. Executive Summary

Plain text is the better format for this use case, but not by as wide a margin as the text paper claims. The decisive factors are UR-2, UR-4, UR-5, and NFR-2: the file is hand-edited by humans under pressure, read by LLMs that do not run YAML parsers, and loaded into a constrained context window on every skill invocation. YAML's structural advantages — named key paths, explicit schema, validated hierarchy — are real benefits when a typed runtime parser is the consumer; they are substantially diminished when the consumer is an LLM reading raw text. The text paper is correct that plain text wins, but overstates the margin by inflating its own scores on expressiveness and parsability, and by treating YAML's UR-5 brittleness as catastrophic when the actual reader is error-tolerant by design. The YAML paper, to its credit, is more honest about YAML's weaknesses than the text paper is about plain text's, but it consistently underweights the token cost and the compounding risk of model-generated write-back corruption.

---

## 2. Requirement-by-Requirement Comparison

### FR-1: Gate tracking

**YAML paper claims:** YAML wins. Named keys (`gates.gate_1.status`) give the model an unambiguous address; plain text requires pattern-matching a prose line.

**Text paper claims:** Plain text wins. One line per gate with a checkbox and trailing date is faster to scan and simpler to update. The "machine" consumer is an LLM, not a parser, so named keys offer no structural advantage.

**Assessment: Narrow plain text advantage.**
The text paper is largely right that the consumer is an LLM, not `yaml.safe_load()`. However, the YAML paper makes a genuinely valid point that YAML's key paths make skill instructions more precise and location-independent. The real risk for YAML here is write-back: when the model updates a gate status inside a three-level hierarchy, indentation error risk is non-trivial. For reading, the formats are roughly equivalent for an LLM. For writing, plain text's single-line pattern (`Gate 1: [ ]` → `Gate 1: [x]`) is safer. The YAML paper overstates the fragility of plain text gate lines — "find the line starting with `Gate 1:` and update the checkbox" is not ambiguous. Plain text wins narrowly on UR-5 grounds (write safety), not because YAML keys are hard to find.

---

### FR-2: Milestone grouping

**YAML paper claims:** YAML wins. Milestone status has no natural home in plain text; YAML's `status:` field is explicit and unambiguous.

**Text paper claims:** Plain text wins. The `## Milestone 1: Core Auth [in-progress]` pattern answers the question at a glance; YAML requires skipping past `id`, `name`, `status`, `gate_3`, `readme` before the features appear.

**Assessment: Genuine tie, with a real gap each paper ignores.**
The YAML paper's point about milestone status is its strongest argument in this entire document. The plain text example co-locates milestone status as a bracketed tag — but the text paper itself shows the GATES section also has per-milestone gate entries (`[~] Gate 3: Milestone 1 — approved`), which means milestone status is encoded in *two places*. That is a synchronization problem the text paper never acknowledges. The YAML paper's point that a reader "must infer" status from gate state and feature status in plain text is an overstatement given the bracketed tag convention — but the duplication risk is real. On the other side, YAML's milestone block is genuinely harder to scan quickly because valued keys (id, name, status) precede the features list. This is a real readability cost. Score this a draw with a note: the plain text format must be defined to treat the milestone header's bracketed tag as the canonical status field and remove the duplicate GATES entries for Gate 3, or the duplication problem is real.

---

### FR-3: Feature status tracking

**YAML paper claims:** YAML wins. Status is a named field; the `|` block literal handles multi-line notes cleanly; changing status does not require modifying a character inside a compound expression.

**Text paper claims:** Plain text wins. Checkbox notation is compact; YAML's block literal (`|`) is syntax most developers don't have memorized; forgetting `|` or mis-indenting silently corrupts the field.

**Assessment: Plain text wins, but the YAML paper's critique of checkbox editing is weak.**
The text paper is correct that YAML block literal syntax is a real hazard for hand-editing under UR-2 and UR-5. The YAML paper's claim that changing `[ ]` to `[x]` is "error-prone" is significantly overstated — it is literally a one-character change. The actual risk in plain text is misattributed notes (a note indented at the wrong level attaches visually to the wrong feature), but this risk is real only if the format spec does not define a clear delimiter between features. If feature blocks are separated by blank lines and a consistent header prefix, the misattribution risk is low. YAML's `|` block literal is a more concrete and recurring hazard because it fires every time a developer adds a multi-line note.

---

### FR-4: Ordering

**YAML paper claims:** YAML wins. YAML lists are ordered by definition; numbering conventions can be violated in plain text.

**Text paper claims:** Plain text wins. Visual order is dependency order; no extra fields needed; YAML requires trusting list order or adding redundant sequence numbers.

**Assessment: Draw — both papers overstate.**
The YAML paper's claim that "plain text encodes order through numbering conventions that can be violated" is technically true but practically weak — the violation would be visually obvious. The text paper's counter-claim that YAML "requires trusting list order (fragile to reordering during merges)" is also weak — YAML list order is well-defined and merge conflicts in list-structured files are no worse than merge conflicts in plain text files. Both formats meet FR-4. Neither has a meaningful advantage. The requirement specifically says "make the order visually obvious without requiring parsing logic" — plain text's visual ordering satisfies this slightly more directly, but it is not a decisive gap.

---

### FR-5: Artifact cross-references

**YAML paper claims:** YAML wins. Named keys (`artifacts.prd`, `milestones[0].readme`) give skills a direct address; plain text paths must be found by scanning.

**Text paper claims:** Plain text wins. Paths are human-readable and visually co-located; YAML's artifact blocks become repetitive boilerplate at scale.

**Assessment: Draw.**
Both formats satisfy FR-5. The YAML paper's claim that plain text paths are "fragile if the path format changes" is weak — path formats change rarely and the update would be equally mechanical in either format. The text paper's claim that YAML creates "repetitive boilerplate" is accurate but minor. For a skill that needs to extract the PRD path, `artifacts.prd: prd.md` is marginally more reliable than scanning for a line that looks like `PRD: prd.md`. Neither paper makes a compelling case for a large gap here.

---

### FR-6: Session resilience

**YAML paper claims:** YAML wins substantially. Named fields make the file interpretable without convention recall; a new session can answer structural questions directly from key paths.

**Text paper claims:** Draw, with marginal plain text advantage because the structure is easier to read at a glance.

**Assessment: Genuine draw.**
The YAML paper's claim that YAML is more reliably interpretable across context gaps is plausible but not demonstrated. Both formats are fully self-contained. An LLM starting a new session can extract project state from either format without external context. The YAML paper's argument rests on the model needing to "understand a formatting convention" for plain text — but "find the `##` milestone header" is not a difficult convention. The text paper's marginal advantage claim is similarly weak. Both formats meet FR-6 adequately.

---

### UR-1: Human-readable at a glance

**YAML paper claims:** Draw (score 4/4). YAML with flow-style formatting is as scannable as plain text.

**Text paper claims:** Plain text wins (score 5/3).

**Assessment: Plain text wins, and the YAML paper's concession undercuts its own scoring.**
The YAML paper's own example requires careful layout discipline (flow-style blocks, aligned colons, summary block at top) to approach the readability of plain text. That discipline is not enforced by the format — it must be re-established on every write. Plain text's checkbox prefix works regardless of layout discipline because the status symbol is always the first character of a feature line. The YAML paper concedes this is "the strongest argument for plain text" and then scores it a draw without fully justifying why careful YAML layout is equivalent to structurally enforced plain text readability. The text paper's score of 5 is appropriate; YAML deserves a 3, not a 4.

---

### UR-2: Human-editable with any text editor

**YAML paper claims:** Plain text wins (score 5/3). Honest concession.

**Text paper claims:** Plain text wins (score 5/2).

**Assessment: Plain text wins. Both papers agree. The YAML paper's mitigation argument is insufficient.**
The YAML paper's mitigation — "the edit operations UR-2 names are simple scalar changes" — is partially true. Changing a status value is a scalar change. But adding a multi-line note requires understanding block literal syntax, and manually adjusting gate status inside a nested milestone structure requires navigating past multiple sibling keys. These are not edge cases; they are the primary operations UR-2 explicitly calls out. The YAML paper's stronger point — that YAML failures are visible (parse error) vs. plain text failures being silent — is real but does not satisfy UR-2, which asks about safety for a developer *without* YAML knowledge. A parse error is only useful if the developer knows to look for it.

---

### UR-3: Diff-friendly

**YAML paper claims:** YAML wins (with disciplined formatting). Status changes touch one line; notes append to block scalar.

**Text paper claims:** Plain text wins. YAML serializers may re-emit the entire document; indentation cascades through diffs.

**Assessment: Plain text wins, and the text paper identifies a risk the YAML paper ignores.**
The YAML paper's analysis assumes hand-written, line-targeted edits. In practice, if any skill re-serializes the YAML document after loading it (a common behavior in YAML toolchains), every invocation produces a full-document diff. The text paper correctly flags this. Even with disciplined line-targeted writes, YAML's indentation structure means a single level-change (adding a new milestone, reorganizing features) cascades whitespace changes through the diff. Plain text diffs are inherently more surgical because the format does not use whitespace as structure.

---

### UR-4: Low cognitive overhead for skill authors

**YAML paper claims:** YAML wins decisively (score 5/2). Key paths provide unambiguous addresses.

**Text paper claims:** Plain text wins (score 4/3). LLMs parse text patterns as reliably as YAML keys; plain text is safer to write back.

**Assessment: Plain text wins, but narrowly — the YAML paper's read-side argument is legitimate.**
The YAML paper's core claim — that `gates.gate_1.status` is more precise than "find Gate 1 in the GATES section" — is true for a deterministic parser and plausible for an LLM on reads. The critical asymmetry the text paper correctly identifies is *write-back*. When a skill must update the file, the LLM is writing YAML it must keep syntactically valid. A two-space indent error on write produces a broken file. The equivalent plain text write (replacing one character, appending one line) has no syntax to corrupt. Since skills both read and write this file (FR-1 through FR-3 involve writes by `/milestone` and `/build`), the write-safety advantage of plain text is decisive for UR-4. The YAML paper scores YAML 5/5 here without addressing write-back risk at all — that is a significant omission.

---

### UR-5: Tolerant of minor formatting errors

**YAML paper claims:** YAML's intolerance is a feature (explicit failure vs. silent corruption). Skills reading the file are LLMs that can handle minor malformations.

**Text paper claims:** Plain text wins cleanly (score 5/2). YAML's indentation-sensitivity fails this requirement under realistic editing conditions.

**Assessment: Plain text wins, and the YAML paper's "feature not a bug" argument fails against the requirement definition.**
UR-5 explicitly asks that "the skills reading the file should still function" after minor human edits. The YAML paper's response is that YAML intolerance produces visible errors, which is better than silent corruption. That argument addresses a different goal — debugging correctness — not the stated requirement. UR-5 is asking whether the system *continues to function* despite minor errors, not whether errors are detectable. YAML fails UR-5 as written. The YAML paper's secondary argument — that LLMs can handle minor YAML malformations — is the stronger one, but it is contradicted by the paper's own argument for UR-4 (that YAML's precision matters). The YAML paper cannot simultaneously claim that YAML precision aids UR-4 and that LLM tolerance covers UR-5.

---

### NFR-1: Backward compatibility with progress.txt patterns

**YAML paper claims:** Substantially met (score 3/5). Checkbox concept preserved in spirit; visual notation changes.

**Text paper claims:** Plain text wins by design (score 5/1).

**Assessment: Plain text wins. The YAML paper's score of 3 is generous to YAML.**
NFR-1 explicitly names the checkbox notation (`[ ]`, `[~]`, `[x]`, `[-]`) as established and says it "should be preserved where applicable." YAML does not preserve it — it replaces `[x]` with `status: complete`. The YAML paper's argument that the "conceptual model survives" is correct but misses the point of NFR-1, which is about notation familiarity, not concept survival. The text paper's score of 1 for YAML is too punitive — YAML does preserve the status vocabulary — but a 5 for itself and a 3 for YAML (rather than 1) would be fair. NFR-1 favors plain text significantly.

---

### NFR-2: Token efficiency

**YAML paper claims:** Approximately neutral; YAML eliminates format-description overhead in skill instructions.

**Text paper claims:** Plain text wins significantly (~57% more verbose per feature in YAML; 400–500 extra tokens per invocation for a 10-feature project).

**Assessment: Plain text wins. The YAML paper's token neutrality argument is weak and the text paper's concrete measurement is credible.**
The YAML paper's claim that YAML eliminates format-description overhead in skill instructions is a real point — skill instructions for plain text do need to describe the format. However, this overhead is paid once per skill definition, not once per invocation. The progress file is loaded on *every invocation*, so file verbosity compounds continuously. The text paper's ~57% verbosity estimate is plausible (the YAML example in the text paper is 11 lines vs. 6 lines for plain text for equivalent feature information). For a 10-feature project, the compounding effect is real and non-negligible under NFR-2. The YAML paper scores YAML 3/5 and plain text 4/5 — this is the most honest scoring in the YAML paper and roughly correct.

---

### NFR-3: Single file

**Assessment: Draw. Both formats trivially satisfy this requirement.** Neither paper disagrees.

---

## 3. Scoring Reconciliation

### Why the scores diverge so sharply

The YAML paper scores YAML 23/30 vs. plain text 22/30 (near-tie). The text paper scores plain text 29/30 vs. YAML 17/30 (landslide). The divergence has three main sources:

**1. The parsability disagreement is the biggest driver.** The YAML paper scores YAML 5/5 and plain text 2/5 on parsability. The text paper scores plain text 4/5 and YAML 3/5. This single criterion accounts for 6 of the 12-point gap between the papers on YAML's score. The disagreement turns on whether the consumer is a typed runtime parser or an LLM — the text paper is correct about the consumer, so the text paper's parsability scores are more defensible. However, the text paper's own score of 4/5 for plain text parsability still overstates the case: the LLM write-back risk is real for both formats, and plain text's simpler syntax makes it less risky, not zero-risk.

**2. The YAML paper inflates YAML's expressiveness score.** Both papers score expressiveness 5/5 for YAML. The text paper scores plain text 5/5 for expressiveness. The YAML paper scores plain text 2/5. This is the YAML paper's most indefensible score — the plain text example in both papers satisfies FR-1 through FR-6. The YAML paper's argument that milestone status "has no place" in plain text is contradicted by the text paper's example, which uses a bracketed tag on the milestone header. Expressiveness is not meaningfully differentiated by format; this is a 5/5 for both.

**3. The text paper inflates plain text's familiarity and deflates YAML's.** The text paper scores YAML 1/5 on familiarity (NFR-1). The YAML paper scores plain text 5/5 and YAML 3/5. The text paper's score of 1/5 for YAML is too low — YAML preserves the status vocabulary and does allow checkbox-style content in string fields. A fair score is 3/5 for YAML and 5/5 for plain text, as the YAML paper has it.

### Which scoring is more defensible?

The YAML paper's scoring is more intellectually honest overall — it concedes genuine losses (editability: 3/5 for YAML, expressiveness: 2/5 for plain text is the main exception). The text paper's scoring is more outcome-motivated: it awards itself 5/5 across four criteria and gives YAML 1/5 on familiarity, which is not supportable.

A more defensible scoring against the actual requirements:

| Criterion | Dimensions | Plain text | YAML |
|---|---|:---:|:---:|
| Readability | UR-1 | 5 | 3 |
| Editability | UR-2, UR-5 | 5 | 2 |
| Parsability (read + write) | UR-4 | 4 | 3 |
| Expressiveness | FR-1 – FR-6 | 5 | 5 |
| Conciseness | NFR-2 | 5 | 3 |
| Familiarity | NFR-1 | 5 | 3 |
| **Total** | | **29/30** | **19/30** |

Plain text wins, but by 29 to 19, not 29 to 17 as the text paper claims, and not 23 to 22 as the YAML paper claims.

---

## 4. Concrete Example Comparison

Both papers include complete examples for the same scenario: two milestones, five features, all gates tracked.

### Readability

The plain text example answers "where are we?" in under three seconds via the GATES section and the first `[~]` symbol in the feature list. The YAML example requires locating `active_milestone: M1`, then scrolling to the M1 block, then scanning features for the first non-`complete` status. The YAML paper's own concession (UR-1: "the strongest argument for plain text") is accurate. The plain text example is more readable for the stated use case.

### Token count (estimate)

The YAML example runs approximately 98 lines with substantial per-field overhead (id, title, status, gate_4, plan, deliverables, notes per feature). The plain text example runs approximately 65 lines with tighter per-feature representation. Estimated token counts for the full examples: YAML ~520 tokens, plain text ~340 tokens. This is a ~53% verbosity difference, consistent with the text paper's per-feature estimate. Over 10 features the difference grows to 400–600 tokens per invocation — significant under NFR-2.

### Editability

For the single most common edit (marking a feature complete):
- Plain text: change one character (`[ ]` to `[x]`) at a visually prominent location (first character of the line).
- YAML: find `status: pending` under the correct feature entry — which requires navigating past `id`, `title`, `gate_4`, `plan`, and `deliverables` entries that have similar visual weight — and change the word.

The YAML edit is not hard but is distinctly less safe under UR-2's explicit constraint ("without specialized tooling, YAML knowledge, or risk of breaking the file's structure"). The `status:` key change itself is safe, but it normalizes opening the YAML block in a context where a second edit — adding a note — requires block literal syntax.

### Satisfaction of FR-1 through FR-6

**Plain text example:** Satisfies FR-1 (GATES section with checkbox and date), FR-2 (## headers with bracketed status), FR-3 (checkbox, bullets, NOTES field), FR-4 (visual order), FR-5 (ARTIFACTS section + per-feature Plan lines), FR-6 (self-contained). One gap: the per-milestone Gate 3 status appears in both the GATES section and the milestone header — a duplication that the text paper does not address and which could diverge.

**YAML example:** Satisfies FR-1 (gates: block with status and date per gate), FR-2 (milestones: list with explicit status), FR-3 (status field, deliverables list, notes block literal), FR-4 (list order), FR-5 (artifacts: block and per-milestone/feature path fields), FR-6 (self-contained). No duplication issue. However, the YAML example includes `notes: ""` for empty features, which is noise that the plain text example handles more cleanly with just `NOTES:`.

Both examples satisfy all six functional requirements. The plain text example has the duplication problem; the YAML example has verbosity and write-safety problems.

---

## 5. Risks Each Paper Underweights

### What the YAML paper minimizes

**Write-back corruption risk (UR-4, UR-5).** The YAML paper discusses indentation risk briefly in UR-5 but frames it as "the model can recover." The deeper risk is that the model *produces* malformed YAML when writing, not just that it *encounters* malformed YAML from humans. Skills that write to the file (particularly `/build` updating feature status and notes) must reconstruct syntactically valid YAML with correct indentation after every write. This is a failure mode that fires on every invocation, not just when a human edits casually. The YAML paper does not model this risk.

**Token cost compounding.** The YAML paper's NFR-2 analysis claims near-neutrality by counting format-description savings in skill instructions. This conflates a one-time cost (skill definition) with a per-invocation cost (file load). The token overhead in the file itself fires on every invocation by every skill. The YAML paper's own example is visibly longer than the plain text example, and the paper does not quantify the actual difference.

**UR-5 as an LLM-write problem, not an LLM-read problem.** The YAML paper argues that LLMs can tolerate minor YAML malformations on read. This is plausible. It does not address whether LLMs produce syntactically valid YAML on write under all conditions, which is the more important question for a file that is continuously updated by agents.

### What the text paper minimizes

**Milestone status duplication.** The text paper's example puts milestone status in both the GATES section (as per-milestone Gate 3 entries) and the milestone header (as a bracketed tag). These can diverge. The text paper never acknowledges this synchronization risk or proposes a resolution. The YAML paper's explicit `status:` field on the milestone object is a genuine structural advantage the text paper ignores.

**Implicit schema as a skill instruction burden.** The YAML paper's point about skill instructions carrying format-description overhead is partially valid. For a plain text format, skill instructions must specify: what the GATES section looks like, what checkbox syntax means, where NOTES lives relative to deliverables, how milestone status is encoded in the header, and what the ARTIFACTS block looks like. None of this is free. The text paper's parsability score of 4/5 for itself and 3/5 for YAML on UR-4 does not account for the instruction-authoring burden that plain text's implicit schema imposes.

**Parsability risk in milestone header syntax.** The text paper acknowledges this risk briefly ("YAML mitigates this by constraining values to a defined enum — but that constraint lives in the skill instruction") but then dismisses it with "include it in the file header." The `[in-progress]` vs. `[~]` inconsistency is a real risk for a format with two separate status notations (brackets on milestones, checkboxes on features). The text paper does not resolve which notation takes precedence or why two systems are needed.

---

## 6. Recommendation

**Plain text wins, with one structural fix required.**

Against the stated requirements, plain text is the better format on five of six evaluation criteria: readability (UR-1), editability (UR-2, UR-5), token efficiency (NFR-2), and backward compatibility (NFR-1). The sixth criterion — parsability by skill agents (UR-4) — is where YAML's theoretical advantage is largest, but where the actual consumer (an LLM performing text writes) reduces YAML's advantage significantly and exposes a write-back risk the YAML paper does not adequately address.

**The tiebreaker requirements** are UR-4 and UR-5 taken together. YAML's structured key paths aid read-side parsability but introduce indentation-sensitive write-back risk. Plain text's simpler structure is slightly less precise on read but dramatically safer on write. Since skills write to this file continuously (FR-1, FR-2, FR-3 all involve writes), write safety dominates. Plain text wins on the tiebreakers.

**The required structural fix** is the milestone status duplication problem that the text paper ignores. The extended plain text format must designate a single canonical location for milestone status. The recommended resolution: milestone status lives in the milestone header's bracketed tag (`## Milestone 1: Core Auth [in-progress]`) and the GATES section tracks only project-level and feature-level gates. Gate 3 (per-milestone) should either be folded into the milestone header or given a dedicated sub-section inside each milestone block — not duplicated across both the GATES section and the milestone header.

**The text paper's score of 29/30 is inflated** — primarily due to the 1/5 for YAML on NFR-1 and the 5/5 for plain text on expressiveness without acknowledging the status duplication problem. A defensible score is plain text 29 vs. YAML 19 when expressiveness is adjusted for duplication risk and NFR-1 is scored fairly.

**The YAML paper's score is more honest** but its 2/5 for plain text on expressiveness is indefensible — the plain text example satisfies all six functional requirements. YAML also earns an accurate 3/5 (not 5/5) on UR-4 once write-back risk is counted.

Plain text, extended with labelled sections, checkbox notation, and co-located cross-references, is the correct format. The format should specify exactly one canonical status notation per entity type and resolve the milestone status duplication before deployment.
