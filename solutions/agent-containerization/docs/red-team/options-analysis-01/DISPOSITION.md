# Disposition — Red-Team Findings, `options-analysis-01`

Triage of all 28 consolidated findings from [`CONSOLIDATED-REPORT.md`](./CONSOLIDATED-REPORT.md).

**Date:** 2026-09-03. Line numbers in the Target column refer to the **2026-09-02 revision** of `OPTIONS_ANALYSIS.md` as cited in the consolidated report; the revision has since moved them.

**Scope decision:** revise and re-justify. Option 2 remains the recommendation; the grounds for it are rewritten. Nothing in the findings flips the choice — F8, F10 and F16 each identify an argument *for* Option 2 that the artifact failed to make, and F7 is the one genuine counter (Option 2 is worst on recovery-to-known-good), now recorded as a trade-off rather than omitted.

**Actions:** `Fix` corrects a false or overstated claim · `Add` introduces missing content · `Record` accepts a risk explicitly · `Owner` needs a human decision · `Defer` out of scope this iteration.

| # | Sev | Action | Target |
|---|---|---|---|
| 1 | Critical | Fix + Add | `OPTIONS_ANALYSIS.md` §Threat model — restate primary threat as exfiltration and lateral reach; state no option mitigates injection itself; add ingress-filtering non-goal |
| 2 | Critical | Fix | `OPTIONS_ANALYSIS.md` §Option 2 — new Preconditions subsection: per-agent identity at mediator, mTLS, credential bound to one client; brokering mutually exclusive with shared network until then |
| 3 | Critical | Fix | `OPTIONS_ANALYSIS.md` §Option 2 Shape + comparison — per-agent networks with multi-homed mediator; new "Agent-to-agent reachability" row |
| 4 | Critical | Add | `OPTIONS_ANALYSIS.md` §Design Constraints — stdio MCP executes inside the blast radius under all three options; §Controls no option provides |
| 5 | High | Fix | `OPTIONS_ANALYSIS.md` L117, L163, L227 — "Egress audit log", destination-level, correct the superlative |
| 6 | High | Fix | `OPTIONS_ANALYSIS.md` L37 — "single axis" → "weighed most heavily"; name what it does not cover |
| 7 | High | Add | `OPTIONS_ANALYSIS.md` §Cross-Cutting "If an agent is compromised" + "Containment and recovery" comparison row |
| 8 | High | Add + Record | `OPTIONS_ANALYSIS.md` §Credential lifecycle — rotation, revocation, review trigger; long-lived tokens recorded as accepted risk. Cross-ref `STANDARDS_MAPPING.md` G5 |
| 9 | High | Add | `OPTIONS_ANALYSIS.md` §Egress policy — third trap: a registry allowlist is not a software allowlist; new "Runtime MCP install blockable" row |
| 10 | High | Add | `OPTIONS_ANALYSIS.md` §Cross-Cutting MCP and tool governance. Cross-ref `STANDARDS_MAPPING.md` G4 |
| 11 | High | Add | `OPTIONS_ANALYSIS.md` §Configuration integrity — capability declarations on agent-writable volumes |
| 12 | High | Add | `OPTIONS_ANALYSIS.md` §Suggested sequence — new adversarial validation step pointing at `REQUIREMENTS.md` T1–T20 / SC-1–3 |
| 13 | High | Fix | `OPTIONS_ANALYSIS.md` §Suggested sequence step 1 — `locked-down` seed, disposable workspace, non-production credentials |
| 14 | High | Add + Owner | `OPTIONS_ANALYSIS.md` §Option 1 — service-provider paragraph; sequence step 0. Assessment incomplete, step 1 constrained accordingly |
| 15 | High | Fix + Add | `OPTIONS_ANALYSIS.md` L165 → "Tooling vendor dependency"; new §Provider governance |
| 16 | High | Add | `OPTIONS_ANALYSIS.md` §Threat model — unattended operation stated as deliberate deviation; oversight folded into extensibility row |
| 17 | Medium | Fix + Owner | `OPTIONS_ANALYSIS.md` §Cross-Cutting — splice-only proposed for all three agents; content-level DLP recorded out of scope |
| 18 | Medium | Add | `OPTIONS_ANALYSIS.md` §Option 2 — mediator hardening paragraph matching agent-container specificity |
| 19 | Medium | Add | `OPTIONS_ANALYSIS.md` §Auth and state — FileVault, backup and VCS exclusion, teardown, retention posture |
| 20 | Medium | Fix | `OPTIONS_ANALYSIS.md` §Design Constraints Notes — provenance per agent; conflict with `REQUIREMENTS.md` R7.7 / R10.2 flagged |
| 21 | Medium | Fix | `OPTIONS_ANALYSIS.md` comparison — audit row states agent reachability; log written inside the mediator |
| 22 | Medium | Add | `OPTIONS_ANALYSIS.md` §Option 2 hardening + mediator controls + "Resource containment" row |
| 23 | Medium | Fix | `OPTIONS_ANALYSIS.md` L162 + sequence step 1 — Option 1 egress policy is global unless `--sandbox` scoped |
| 24 | Medium | Fix | `OPTIONS_ANALYSIS.md` L221, L223 — "validates" → "seeds"; second observation source |
| 25 | Medium | Fix | `OPTIONS_ANALYSIS.md` L32 — MCP surface is tool descriptions and schemas at capability negotiation, results, and `listChanged` |
| 26 | Medium | Fix | `OPTIONS_ANALYSIS.md` L115, L127, L227 — brokering qualified as model-provider API only |
| 27 | Low | Owner | `OPTIONS_ANALYSIS.md` §Security Warning — one recorded decision, owner, review trigger |
| 28 | Low | Add | `OPTIONS_ANALYSIS.md` §Option 2 hardening — MCP HTTP listeners bind `127.0.0.1`, Origin validation, SDK rebinding protection on |

## Beyond the 28 findings

Two items surfaced during the update that are not in the consolidated report.

| Item | Action | Target |
|---|---|---|
| **Five Eyes quotations do not verify against the primary text.** Five of six block quotes in `STANDARDS_MAPPING.md` §Key positions return zero or non-matching occurrences in `references/careful_adoption_of_agentic_ai_services.md`. They are CSA secondary-analysis paraphrase presented as direct quotation. | Fix | `STANDARDS_MAPPING.md` §Key positions — replace with verbatim primary text; convert the L96 caveat into a recorded correction |
| **Stale CIS inventory** — `STANDARDS_MAPPING.md` states two companion guides; `references/` holds three (the MCP guide was a full review lens in this run). | Fix | `STANDARDS_MAPPING.md` L23, L51–52, L173–174, L188–190 |

## Open decisions requiring an owner

Carried into the documents marked **proposed — needs owner**, not silently resolved.

1. **TLS interception posture.** Splice-only proposed for all three agents; consequence is that no content-level DLP exists in the recommended architecture (F17).
2. **Antigravity access route.** `GEMINI_API_KEY` / Vertex ADC proposed, which sidesteps the ToS clause entirely; needs an accepted position and a review trigger (F27).
3. **Docker Sandboxes provider assessment.** Retention and data-handling terms for intercepted traffic are not established; step 1 of the sequence is constrained pending it (F14).
