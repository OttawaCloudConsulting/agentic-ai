# Third-Party and Provider Governance Records

Feature 01.1, SF-1. Satisfies R14.1 (every third party on the agent traffic path), R14.2 (per-model-provider
detail), and R14.3 (ToS monitoring owner). Inspected by T42 and T43 (`REQUIREMENTS.md:461-462`).

Record schema fixed by the Gate-4 plan's Interface Contracts section
(`plans/pre-build-verification-provider-governance-and-egress-discovery.md`). Per R14.1: "Where an
assessment cannot be completed, the resulting constraint on use is recorded rather than left implicit" —
applied per-field below, not only at the whole-record level, because for two of the four parties some
fields are independently sourced and others are not.

Verified 2026-09-04 against vendor documentation and the RESEARCH_FINDINGS.md technical baseline (verified
2026-09-02/03). Version-pinned facts in this space go stale within weeks — re-check before relying on this
record past the next agent version bump (R10.6).

## Contents

- [R14.1 — Docker Sandboxes (`sbx`)](#r141--docker-sandboxes-sbx)
- [R14.1 + R14.2 — Anthropic](#r141--r142--anthropic)
- [R14.1 + R14.2 — OpenAI](#r141--r142--openai)
- [R14.1 + R14.2 — Google (Gemini API / Antigravity `agy`)](#r141--r142--google-gemini-api--antigravity-agy)
- [R14.3 — Antigravity ToS Monitoring Owner](#r143--antigravity-tos-monitoring-owner)
- [R14.1 — HashiCorp](#r141--hashicorp)
- [R14.1 — GitHub](#r141--github)
- [R14.1 — Kubernetes (posture)](#r141--kubernetes-posture-not-a-filled-record--feature-023-sf-5-decision-6)
- [Summary Table](#summary-table)

---

## R14.1 — Docker Sandboxes (`sbx`)

| Field | Value |
|---|---|
| Party | Docker Sandboxes (`sbx`), Docker Inc. |
| Role on the traffic path | **Discovery-seeding tool only (D17), not part of the built architecture.** D1 rejected `sbx` as the durable enforcement point (Antigravity unsupported, closed-source, macOS/Windows-only, vendor sits on the traffic path unassessed). Retained solely so SF-3's discovery run can observe egress before the mediator exists. Placed on the traffic path for the duration of that run only, against a synthetic repository with throwaway credentials (D17, R12.4) |
| What it can observe | **Unconfirmed whether it observes payload content at all.** Docker's own isolation docs state the product "doesn't monitor sessions, read your prompts, or access your code" and describe the egress path as routing only ("All outbound TCP traffic passes through a proxy... that enforces the network access policy"), not decryption or inspection. This contradicts the assumption `OPTIONS_ANALYSIS.md`/D17 carry forward — that the proxy terminates HTTP/HTTPS and therefore sees decrypted prompts, source, and credential-bearing headers. Both readings are plausible from the published material; neither is confirmed. At minimum, connection metadata (destination host, port, timing) is observed by any egress-mediating proxy |
| Stated retention | **Not published.** Checked Docker's isolation and FAQ pages directly — neither states a retention period for any traffic or data the proxy handles |
| Deletion terms | **Not published.** `sbx rm` deletes the local VM and its contents — that is local cleanup on the operator's machine, not a data-handling commitment from Docker as a service provider for anything the proxy itself may have observed or logged server-side |
| Breach-notification path | **Not published.** No breach-notification commitment found on the isolation, FAQ, or local-policy pages |
| Assessment status | **Incomplete** |
| Resulting constraint on use | Confirms Open Decision 3 (`ARCHITECTURE_AND_DESIGN.md:481`) and D17's existing mitigation: the SF-3 discovery run uses a **synthetic repository and throwaway credentials only**, `locked-down` mode (never `balanced`), one agent at a time. No production credential, real repository content, or secret may reach `sbx` under any circumstance, because whether it retains what it observes — or observes payload content at all — is unestablished either way. This constraint is unconditional on the "does it decrypt" question above: the mitigation holds regardless of which reading is correct |
| Date | 2026-09-04 |
| Source | [Isolation layers](https://docs.docker.com/ai/sandboxes/security/isolation/) (no page date) · [FAQ](https://docs.docker.com/ai/sandboxes/faq/) · [Local policy](https://docs.docker.com/ai/sandboxes/security/policy/) |

---

## R14.1 + R14.2 — Anthropic

| Field | Value |
|---|---|
| Party | Anthropic |
| Role on the traffic path | Model API provider for the Claude Code agent. Permanent production traffic, present from first release. TLS is **spliced, never terminated** to Anthropic (D4) — the mediator validates destination at CONNECT/SNI and passes the connection through undecrypted, so Anthropic receives full prompt and completion content exactly as the agent sends it; the mediator itself never sees plaintext |
| What it can observe | Full prompt and completion content, by necessity of being the model provider — this is not reducible by anything in this architecture (D4: "no content-level DLP anywhere in the architecture") |
| Stated retention | **Not independently confirmed against Anthropic's own canonical page.** Anthropic's retention article (privacy.claude.com) states the training-opt-out position but points to the Trust Center for retention specifics rather than stating a figure directly. Third-party-hosted copies of Anthropic's DPA report a 7-day default / 30-day opt-in retention window and an enterprise Zero Data Retention option, but those pages are not on an Anthropic-owned domain and are **not treated as verified** here |
| Deletion terms | Not confirmed on Anthropic's own domain for standard commercial/API retention. Feedback data explicitly submitted via thumbs-up/down is retained up to 5 years per the same retention article — that figure **is** on-domain and confirmed |
| Breach-notification path | **Not addressed** in Anthropic's own retention article. Third-party-hosted DPA copies report inconsistent figures (48h in one, 72h in another, both "without undue delay" framing) — not confirmed against Anthropic's own canonical DPA |
| Assessment status | **Incomplete** — retention period and breach-notification path unconfirmed on-domain; training opt-out and what-it-observes are confirmed |
| Resulting constraint on use | Do not rely on the unsourced 7-day/30-day/48–72h figures as contractual. Before this route carries data under a retention or breach-notification obligation the operator is contractually bound to elsewhere (e.g., a client engagement with its own SLA), obtain Anthropic's current DPA directly through the operator's own account/enterprise agreement rather than from this record |
| Version-pinning capability | **Present, and strong.** Anthropic's own model-overview page states plainly: "Every Claude model ID is a pinned snapshot, including the dateless IDs used from the 4.6 generation on." Pre-4.6 models expose an alias that resolves to a dated snapshot ID; from the 4.6 generation forward the dateless ID **is** the pinned snapshot itself, not a rolling pointer |
| History-retention setting in use | Not independently confirmed on-domain (see Stated retention above) |
| Training-opt-out setting in use | **Default off** (not used for training) for commercial products — API, Claude for Work, Enterprise, Gov — confirmed on Anthropic's own domain (privacy.claude.com). Contractual default, not an operator-set toggle. Exception: content explicitly submitted via thumbs-up/down feedback |
| Data classification permitted to leave | **Unrestricted by any technical control in this architecture.** No vendor-side classification restriction found; nothing at the network layer inspects or filters content (D4). Whatever the agent is given filesystem/tool access to can reach Anthropic verbatim. Classification control must be enforced upstream of the mediator — by what the agent is permitted to read — not assumed to exist here |
| Date | 2026-09-04 |
| Source | [privacy.claude.com — data retention](https://privacy.claude.com/en/articles/7996868-how-long-do-you-store-my-organization-s-data) (article dated "over 2 weeks ago" relative to fetch, i.e. mid/late-Aug 2026) · [platform.claude.com — Models overview](https://platform.claude.com/docs/en/models/overview) (fetched 2026-09-04) |

---

## R14.1 + R14.2 — OpenAI

| Field | Value |
|---|---|
| Party | OpenAI |
| Role on the traffic path | Model API provider for the Codex agent. Permanent production traffic. TLS spliced, never terminated (D4) — full prompt/completion content reaches OpenAI unmodified |
| What it can observe | Full prompt and completion content |
| Stated retention | **Confirmed, on-domain.** Default abuse-monitoring logs retained 30 days "unless longer retention is required by law" (developers.openai.com/api/docs/guides/your-data) |
| Deletion terms | Zero Data Retention (ZDR) available per-endpoint for eligible organizations — excludes customer content from abuse-monitoring logs on covered endpoints (chat/completions, responses, images, embeddings, audio, moderations, realtime). Endpoints holding server-side state (assistants, threads, vector_stores, conversations) may retain state even with ZDR enabled — deletion there depends on the operator actively deleting those objects, not on the ZDR setting alone |
| Breach-notification path | Confirmed on OpenAI's own domain: the DPA (openai.com/policies/data-processing-addendum) commits to notification "without undue delay" after OpenAI becomes aware of a Personal Data Breach. No fixed hour figure is published |
| Assessment status | **Complete** — all fields sourced from OpenAI-owned domains |
| Resulting constraint on use | None beyond the general one below — this record's fields are as fully sourced as the vendor publishes |
| Version-pinning capability | **Present, but weaker guarantee than Anthropic's.** OpenAI publishes named-snapshot model IDs (e.g. `gpt-5.6-sol`) distinct from an unsuffixed rolling alias (`gpt-5.6`) that routes to the current snapshot. The fetched documentation does **not** state that the named snapshot itself is immutable, and explicitly does not guarantee the unsuffixed alias's routing target stays fixed over time ("The `gpt-5.6` alias routes requests to GPT-5.6 Sol" — present-tense description, not a permanence commitment). No dated-ID convention (`model-YYYY-MM-DD`) was found for current models. **Mitigation available: pin Codex's configured model to the full named-snapshot ID, never the bare alias** — this is the closest thing to a pin OpenAI's current docs support, though snapshot immutability itself is not contractually confirmed from what was checked |
| History-retention setting in use | 30-day default (abuse monitoring), or Zero Data Retention if the operator's org is eligible and has it configured per-endpoint — not confirmed which applies to this deployment; record as **operator-dependent**, default assumed (30 days) absent explicit ZDR configuration |
| Training-opt-out setting in use | **Default on** (i.e., NOT used for training) since 2023-03-01 for API data, confirmed on OpenAI's own domain |
| Data classification permitted to leave | Same structural finding as Anthropic: no vendor-side classification restriction found; full content leaves, unfiltered by anything in this architecture (D4) |
| Date | 2026-09-04 |
| Source | [developers.openai.com — Your data](https://developers.openai.com/api/docs/guides/your-data) · [OpenAI DPA](https://openai.com/policies/data-processing-addendum/) · [developers.openai.com — Models](https://developers.openai.com/api/docs/models) · [developers.openai.com — gpt-5.6-sol](https://developers.openai.com/api/docs/models/gpt-5.6-sol) |

---

## R14.1 + R14.2 — Google (Gemini API / Antigravity `agy`)

| Field | Value |
|---|---|
| Party | Google |
| Role on the traffic path | Model API provider for the Antigravity (`agy`) agent, reached via the `GEMINI_API_KEY` route (D9) — Antigravity OAuth never enters a container; TLS interception is **permanently barred** for this route (R5.13). Backend host per `RESEARCH_FINDINGS.md:283-284`: `daily-cloudcode-pa.sandbox.googleapis.com` for account-auth mode, but the `GEMINI_API_KEY` route (this record's subject) uses the separate public Gemini Developer API surface |
| What it can observe | Full prompt and completion content |
| Stated retention | **Confirmed, on-domain, but tier-dependent.** Paid tier: prompts/responses not used for product improvement by default; logs retained default max 55 days, configurable to 7/14/28/55. Free tier (AI Studio, no billing attached): content **is** used to improve Google products and may be reviewed by humans — a materially different regime. EEA/Switzerland/UK users get paid-tier terms applied even on the free tier |
| Deletion terms | No zero-retention option on the Gemini Developer API itself (7-day minimum even at the shortest configurable window). A separate zero-retention option exists on Vertex AI Gemini, but that is a different auth path (Cloud/Vertex billing) than the `GEMINI_API_KEY` route Antigravity uses under D9 |
| Breach-notification path | **Not confirmed for this specific access route.** No breach-notification commitment on the Gemini-specific logging-policy page. Google Cloud's general Data Processing Addendum states notification "promptly and without undue delay," but that document's scope (Cloud/Workspace, billed usage) is not confirmed to cover the public Gemini Developer API `GEMINI_API_KEY` route used here |
| Assessment status | **Incomplete** — breach-notification path unconfirmed for this route; retention/training-use terms are confirmed but are **conditional on a fact this record cannot establish: which tier the operator's key is on** |
| Resulting constraint on use | **Before this route carries any non-synthetic data: confirm the `GEMINI_API_KEY` in use is a billed (paid-tier) key, not an unbilled AI Studio (free-tier) key.** Both key formats are indistinguishable at the credential level. If the key is unbilled, prompts and completions are used for product improvement and may be human-reviewed by default — a training-opt-out failure relative to what D9's cost analysis assumed ("routes to the public Gemini API on the operator's own billing"). This is an operator action item, not something `/build` can verify from inside this session. Separately: do not assume the Cloud DPA's breach-notification commitment applies to this route without written confirmation from Google, since its scope is not established for the Developer API |
| Version-pinning capability | **Present, moderate guarantee.** Google publishes "stable" version IDs (e.g. `gemini-3.6-flash`) that per Google's own documentation "usually don't change" — weaker language than Anthropic's "pinned snapshot," closer to a soft commitment. "Preview" versions carry date suffixes (e.g. `gemini-2.5-flash-preview-09-2025`) with a minimum 2-week deprecation notice. Unsuffixed `-latest` aliases are explicitly documented as hot-swapped on every release with no backward-compatibility commitment. **Mitigation: pin to a stable-tier versioned ID, never a `-latest` alias** |
| History-retention setting in use | Depends on tier (see Stated retention). Paid tier default: max 55 days, configurable. Not confirmed which tier this deployment's key uses — see Resulting constraint |
| Training-opt-out setting in use | **Tier-dependent, unconfirmed for this deployment.** Paid tier: default off (not used for training). Free/AI Studio tier: default on (content used, human review possible) unless the account is in a jurisdiction (EEA/CH/UK) where paid-tier terms are force-applied |
| Data classification permitted to leave | Same structural finding as the other two providers (no vendor-side classification restriction; full content leaves, unfiltered by this architecture), **compounded by the tier ambiguity above** — on an unbilled key, that unrestricted content is additionally eligible for human review |
| Date | 2026-09-04 (Gemini logs-policy page itself last updated 2026-09-04 per its own timestamp) |
| Source | [Gemini API — Data logging and sharing](https://ai.google.dev/gemini-api/docs/logs-policy) (page states "last updated 2026-09-04") · [Gemini API — Zero data retention](https://ai.google.dev/gemini-api/docs/zdr) · [Google Cloud DPA](https://cloud.google.com/terms/data-processing-addendum) · [Gemini API — Models](https://ai.google.dev/gemini-api/docs/models) |

---

## R14.3 — Antigravity ToS Monitoring Owner

| Field | Value |
|---|---|
| Owner | **Ottawa Cloud Consulting** (organizational owner — no individual named; operator-supplied per Gate 2 open item, 2026-09-04) |
| What is monitored | The Antigravity Additional Terms §6 position underlying D9 (`ARCHITECTURE_AND_DESIGN.md:48`) — that headless/container use via `GEMINI_API_KEY` does not fall under the third-party-tooling prohibition Google has enforced against OAuth-wrapping proxies. This reading is explicitly Anthropic-adjacent research's own interpretation, not an official Google position; Google staff declined to clarify the boundary on the developer forum |
| Review trigger | Re-review fires on any of: (1) Google clarifies the §6 boundary publicly or in direct correspondence; (2) the Antigravity Additional Terms change; (3) public-API (`GEMINI_API_KEY`) billing becomes material enough that Google's enforcement posture toward it is plausibly different from a hobbyist/low-volume key. Matches the trigger already recorded at `ARCHITECTURE_AND_DESIGN.md:482` |
| Downstream test ownership | T44 (`ARCHITECTURE_AND_DESIGN.md:464`) — the simulated-terms-change exercise — is owned by Milestone 02, Feature 02.5, and runs under the owner named here. This record supplies the owner as an input; it does not itself constitute T44 |
| Date | 2026-09-04 |

---

## R14.1 — HashiCorp

<a id="r141-hashicorp"></a>

| Field | Value |
|---|---|
| Party | HashiCorp, Inc. |
| Role on the traffic path | Placed by `packs/terraform/pack.yaml` (Feature 02.3 SF-3). `releases.hashicorp.com` serves the pinned Terraform CLI archive (build time) and provider binaries the CLI may fetch outside the registry proxy (runtime). `registry.terraform.io` serves provider and module metadata and binaries at `terraform init` time (runtime). Both are `runtime_install: true` destinations under R7.6 |
| What it can observe | Connection metadata common to any HTTPS destination (source IP as seen by the mediator's egress, requested provider/module name and version, timing) via GET requests for provider indices and binaries. This is metadata about *which tools the agent fetches*, not agent prompt or source content — Terraform's own traffic to this host carries no workspace file content, only provider/module resolution requests |
| Stated retention | **Not published for this traffic.** HashiCorp's general privacy policy states only that "Personal Information" is kept "for as long as necessary to achieve the purpose for which the information was originally collected," with no stated period, and does not address download/registry infrastructure logs (`releases.hashicorp.com`, `registry.terraform.io`) specifically |
| Deletion terms | **Not published for this traffic.** The general policy describes an account-erasure request path ("if you wish to delete or suspend your account...we may retain certain information as required by law or for legitimate business purposes"), which does not apply to unauthenticated CLI/registry fetches — there is no HashiCorp account in this architecture |
| Breach-notification path | **Not published.** No breach-notification commitment specific to this infrastructure was found |
| Assessment status | **Incomplete** |
| Resulting constraint on use | The registry/release infrastructure is a checksum-verified binary source, not a data sink this architecture sends workspace content to. The mitigation is upstream of retention/breach terms: `CHECKPOINT_DISABLE=1` (the pack's `env`, Decision 1) suppresses Terraform's separate telemetry call to `checkpoint-api.hashicorp.com`, which is not allowlisted and would otherwise appear as a denied attempt on every run. No credential is sent to either host. Providers hosted outside `releases.hashicorp.com` (third-party providers on GitHub) fail to install — intended, recorded in `packs/terraform/pack.yaml`'s blast radius |
| Date | 2026-09-10 |
| Source | [HashiCorp Privacy Policy](https://www.hashicorp.com/en/privacy) · [Terraform SHA256SUMS, v1.16.2](https://releases.hashicorp.com/terraform/1.16.2/terraform_1.16.2_SHA256SUMS) |

---

## R14.1 — GitHub

<a id="r141-github"></a>

| Field | Value |
|---|---|
| Party | GitHub, Inc. (a Microsoft subsidiary) |
| Role on the traffic path | Placed by `packs/github-cli/pack.yaml` (Feature 02.3 SF-4). `github.com` and `api.github.com` serve `gh` CLI operations (repository content, issues, pull requests, releases) at runtime, both `runtime_install: true` destinations under R7.6 because `github.com` also serves source and `gh extension install` traffic. `codex`'s base already carries both hosts (`allowlist.base.yaml:80-87`); this pack widens reach only for `claude` and `agy` (Decision 4's overlap case) |
| What it can observe | Whatever the fine-grained PAT's scope permits `gh` to read or write — repository content, issue/PR text, metadata — plus connection metadata common to any HTTPS destination. This is a genuine content-carrying party, not a binary-fetch-only one like HashiCorp: a `gh issue view` or `gh pr create` call sends and receives the operator's actual repository content, not just package-resolution metadata |
| Stated retention | **Not published for this specific traffic.** GitHub's general Privacy Statement states data is retained "as needed to fulfill contractual obligations, comply with legal requirements, resolve disputes, and enforce agreements," with no fixed period, and does not separately address API (`api.github.com`) request logs |
| Deletion terms | **Not published for this traffic.** The general statement describes account-level data-subject rights (access, correction, deletion requests under applicable law), which is a different mechanism than API request-log retention for an org's own repositories accessed via a PAT |
| Breach-notification path | **Not confirmed for this specific route.** GitHub's general security practices reference incident response, but no fixed notification-window commitment specific to API/CLI traffic was found in what was checked |
| Assessment status | **Incomplete** |
| Resulting constraint on use | Unlike HashiCorp, this party **does** receive real repository content by design — that is the pack's purpose. The mitigation is scope, not avoidance: the credential is a fine-grained PAT limited to named repositories (Interface Contract 1), never an account-wide classic token, and its blast radius is bounded to that scope (`packs/github-cli/pack.yaml`'s `blast_radius`). `GH_NO_UPDATE_NOTIFIER=1` (the pack's `env`) suppresses an unreviewed background check; it does not change what `gh`'s invoked operations themselves send. Git-over-HTTPS wiring through the token is **not built** (Decision 7), so `git push`/`git fetch` traffic does not additionally cross this party through this pack |
| Date | 2026-09-10 |
| Source | [GitHub General Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement) · [gh_2.100.0_checksums.txt](https://github.com/cli/cli/releases/download/v2.100.0/gh_2.100.0_checksums.txt) |

---

## R14.1 — Kubernetes (posture, not a filled record — Feature 02.3 SF-5, Decision 6)

This entry is a **recorded posture**, not a standard filled R14.1 row like HashiCorp's or GitHub's:
the shipped `packs/kubernetes/pack.yaml` declares `egress.runtime: []`, so it reaches no third
party at all, and R14.1 applies only to a party actually on the traffic path. There is nothing to
assess for the shipped pack — no HTTPS destination, no privacy policy, no retention terms.

**What the pack ships and what it does not.** `kubectl` and `helm` are checksum-verified binaries
from `dl.k8s.io` and `get.helm.sh` (build-time-only egress, `egress.build`, never entering the
resolved runtime policy). At runtime the pack grants no cluster reach: the cluster API endpoint is
operator-specific and cannot be declared statically in a shipped, reviewed manifest.

**The split that keeps R14.1 mechanical.** A cluster is reached by loading a *separate*,
per-cluster egress-only pack (`packs/k8s-cluster-<name>/`, not shipped in this feature). That pack
carries its own `egress.runtime` (the cluster's API server FQDN, and any Helm repository hosts) and
its own `third_parties` record naming the party that hosts the cluster (a cloud provider's managed
Kubernetes service, or the operator's own infrastructure). `lint-policy.sh`'s R14.1 anchor check
(criterion 3) refuses that pack at load time if its record does not resolve — so the mechanism this
architecture already has for HashiCorp and GitHub applies unchanged to whatever party actually ends
up hosting a cluster; there is nothing kubernetes-specific left to build for R14.1 to hold.

**Constraint recorded, not closed (criterion 14).** Reach is **public-FQDN cluster endpoints
only**. `allow_cidrs` is refused at the mediator render (`policy/denylist.base.yaml` denies RFC1918
post-resolution regardless), so a `kind` cluster, Docker Desktop's cluster, or any
private/IP-address-only endpoint is unreachable through this mechanism. The `kubeconfig` credential
is also constrained to one context using token or client-certificate auth (Decision 6) — an `exec`
or `auth-provider` credential plugin would invoke a binary this pack's image does not carry, so
such a kubeconfig fails at first use, not at compile time.

**Date:** 2026-09-10.

---

## Summary Table

| Party | R14.1 status | R14.2 applicable | Primary constraint |
|---|---|---|---|
| Docker Sandboxes | Incomplete | No (not a model provider) | Synthetic repo + throwaway credentials only, for the SF-3 discovery run |
| Anthropic | Incomplete (retention, breach-notification unconfirmed on-domain) | Yes — pinning strong, training opt-out confirmed off | Don't rely on unsourced retention/breach figures for contractual obligations |
| OpenAI | Complete | Yes — pinning present but weaker guarantee, training opt-out confirmed off | Pin to full named-snapshot model ID, not bare alias |
| Google | Incomplete (breach-notification, tier unconfirmed) | Yes — pinning moderate, training opt-out tier-dependent | **Confirm `GEMINI_API_KEY` is billed (paid tier) before real use** |
| HashiCorp | Incomplete (retention, deletion, breach-notification not published for this infrastructure) | No (not a model provider) | Checksum-verified binary source only, no credential or workspace content sent; `CHECKPOINT_DISABLE=1` suppresses the unrelated telemetry call |
| GitHub | Incomplete (retention, deletion, breach-notification not published for API/CLI traffic) | No (not a model provider) | Real repository content crosses this party by design; mitigation is PAT scope (fine-grained, named repositories), not avoidance |
| Kubernetes (shipped pack) | N/A — no runtime egress, no party on the traffic path | No (not a model provider) | Cluster reach requires a separate per-cluster egress pack, which carries its own R14.1 record before it can be loaded; public-FQDN endpoints only |
