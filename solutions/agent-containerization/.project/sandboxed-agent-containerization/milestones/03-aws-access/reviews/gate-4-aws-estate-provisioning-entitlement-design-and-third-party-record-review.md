# Gate 4 Review -- Feature Plan: AWS estate provisioning, entitlement design and third-party record

**Artifact:** .project/sandboxed-agent-containerization/milestones/03-aws-access/plans/aws-estate-provisioning-entitlement-design-and-third-party-record.md
**Status:** [x] Approved
**Reviewer(s):** Operator (Ottawa Cloud Consulting); external review pass by Codex (gpt-5.3-codex)
**Date:** 2026-10-04

## Checklist

### Structural (pre-checked programmatically)

- [x] Plan file exists at the expected path
- [x] All 12 required sections present (Summary, Acceptance Criteria, Approach, Sub-Features,
      Interface Contracts, Edge Cases, Test Command, Test Strategy, Documentation, Files to
      Create/Modify, Dependencies, Architectural Deviations) -- verified by heading match
- [x] `milestone-status.txt` exists for milestone 03
- [x] Feature 03.1 exists in `milestone-status.txt`, and its `Plan:` line carries this plan's path
- [x] Sub-feature count is 5, matching the `Sub-features: 0/5 complete` line recorded at approval

### Content (static items)

- [x] Does the approach handle known edge cases? -- 10 edge cases, each tied to a criterion or a
      decision. Edge Case 1 (no data perimeter) is an **escalation**, not a gap, per the operator's
      2026-10-04 decision; Edge Case 6 records why phase C is scoped rather than repo-wide; Edge
      Case 9 is the D16-shaped "a green harness is not a proven perimeter" case
- [x] Are the sub-features correctly scoped for single-session work? -- SF-1, SF-3 and SF-4 are
      single-file documentation; SF-2 is an external precondition carrying no build work; SF-5 is
      one harness in an idiom with four worked precedents. None approaches the ~120k guideline
- [x] Is the test command appropriate for this feature? -- `verify-aws-estate.sh && lint-policy.sh`.
      Records-only feature, so static. `lint-policy.sh` is not redundant: it is phase E's actual
      enforcement point. The Milestone 02 composite is deliberately **not** re-run, justified by the
      zero-AWS-strings scan result; 03.3 is where it becomes a regression check again
- [x] Are the files to create/modify correct? -- 2 created (`aws-estate-entitlement.md`,
      `verify-aws-estate.sh`), 2 modified (`third-party-assessments.md`, `README.md`). No gate
      artifact is edited by the build. `REQUIREMENTS.md` was amended **before** the plan, by operator
      acceptance, and is therefore cited rather than listed
- [x] Are interface contracts compatible with existing code? -- Contract 1 and 2 reuse the existing
      `Field | Value` + `id="r141-<party>"` record shapes (HashiCorp/GitHub precedent). Contract 3
      reuses `verify-containment.sh`'s `filled()` and `verify-mcp-inventory.sh`'s `expect` and
      probe-scaffolding conventions. Contract 4 fixes a placeholder vocabulary that phase C's
      patterns are written not to match

### Content-specific ([Auto])

- [x] [Auto] **Verify the anchor assertion names its real enforcement point.** The first draft said
      a probe pack "compiles"; `scripts/lint-policy.sh:260` does the `grep -q "id=\"<anchor>\""` and
      `compile-policy.sh` does not. Verified in the code during review; phase E now asserts the
      positive and the negative against `lint-policy.sh`, following `verify-tool-packs.sh:175`
- [x] [Auto] **Validate that phase C is not red on arrival.** Verified: a repo-wide `[0-9]{12}` scan
      would fail immediately on `policy/allowlist.base.yaml:141`
      (`antigravity-cli-auto-updater-974169037036.us-central1.run.app`, a GCP project number) plus
      six other files. Phase C is scoped to the two AWS records with AWS-specific patterns
- [x] [Auto] **Confirm the blocking/gap-able split is justified per criterion, not uniform.**
      Criterion 4 (data perimeter) blocks because Q1's broad-S3 answer leaves T13 with no other
      control; criterion 5 (permission boundary, destructive denies) is gap-able because the
      read-only default survives their absence. Operator decision 2026-10-04. `GAP:` is accepted
      only under those two sections, and only with a non-empty consequence
- [x] [Auto] **Check that R6.5.2 is not load-bearing under Model B.** R6.5.2's verification clause
      is `aws sso list-accounts` from inside the container, which R6.5.4 forbids and T19 inverts
      under Model B. Criterion 1 rests on R6.3.2; the milestone README's "(R6.3.2, R6.5.2)" citation
      is recorded as an observation against a gate artifact, not silently followed
- [x] [Auto] **Confirm no credential-inventory row is created here.** Verified against
      `verify-containment.sh` phase A: its `^\| [EVS][0-9]+ \|` parser demands `Stated maximum`,
      `Measured` and `Rebuild required` be filled. A pre-created AWS row would take a green harness
      red on landing. The rows belong to 03.2 and 03.5
- [x] [Auto] **Check dependency: SF-2 is external and has a defined blocked state.** The estate work
      is not this repository's to perform. SF-2 carries a BLOCKED state and an explicit stop rule --
      a build session reaching it without an operator report halts rather than proceeding to SF-3 on
      assumptions
- [x] [Auto] **Confirm the R14.1 traffic-path field cannot silently diverge from 03.3.** The field is
      marked provisional and keyed to Q1's endpoint classes, with 03.3 named as the verifier in both
      criterion 9 and Documentation. Edge Case 8 names silent divergence as the failure mode
- [x] [Auto] **Validate that Q1/Q9 are cited from the register, not from a conversation.** Both rows
      in `REQUIREMENTS.md` § Open Questions were amended 2026-10-04 on operator acceptance, with Q1
      carrying the R6.4.3-impractical / T13-rests-on-R6.3.6 consequence. The plan cites the register

## Reviewer Comments

Approved after one external review cycle. Eight findings were raised against the first draft and all
eight are applied; the plan's own **Review Revisions** section carries the mapping. Two of the eight
were verified in the code before being accepted rather than taken on the reviewer's word -- the
`lint-policy.sh` anchor enforcement point and the phase-C false positives -- and both checked out.

Two items are deliberately left outside this feature and are recorded rather than resolved:

1. **R13.2-style carried proposals.** The architecture pointer to the new entitlement record, the
   conditional R6.3.8 attribution-granularity finding, and the R6.5.2 citation observation are all
   carried for an authority that may edit gate artifacts. The build applies none of them.
2. **The feature proves records, not estate behaviour.** T10, T12, T13, T19 and T20 remain 03.4's,
   measured from inside a container against a live broker. Criterion 12 and the harness header both
   state this so a green run here cannot be mistaken for a proven perimeter.
