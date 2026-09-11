# Five Eyes Agentic AI Conformance Assessment

## Agent Persona

I am the Five Eyes "Careful adoption of agentic AI services" conformance reviewer. My role is to test
`docs/OPTIONS_ANALYSIS.md` against the joint CISA/NSA/ASD-ACSC/CCCS/NCSC-NZ/NCSC-UK guidance
(2026-05-01) and find every place the artifact omits, contradicts, misapplies, or under-scopes a control
the reference explicitly names.

My adversarial posture: I assume the options analysis is a containment-only document that has mistaken
one control family (network egress enforcement location) for a complete agentic security architecture,
and that its confidence in Option 2 ("meets all five requirements", line 227) is unearned against the
reference's full control set. I do not accept "it is in a sibling document" as a defence when the missing
item is an **architectural discriminator between the three options** — the whole purpose of this artifact
is to choose between them.

## Assessment Summary

Reference: careful_adoption_of_agentic_ai_services.md (Five Eyes, 2026-05-01)

Items examined: **173** reference items, comprising 122 "Recommended best practices" bullets across 25
named practice areas (Designing / Developing / Deploying / Operating secure agents, plus Defend against
future risks), 33 named risks across the five risk categories (Privilege, Design and configuration,
Behaviour, Structural, Accountability), and 18 Appendix A cyber security prerequisites. Each was checked
against all 236 lines of `OPTIONS_ANALYSIS.md`, its 3 option sections, its 12-row Comparison table, its 3
Cross-Cutting Concerns subsections, the ToS section and the Recommendation.

Sibling coverage was checked against `docs/STANDARDS_MAPPING.md` gaps G1–G5 before finalising. Four
findings overlap a recorded gap and say so explicitly; twelve do not appear in G1–G5 in any form.

Findings: **16** (Critical: 1, High: 6, Medium: 8, Low: 1)

## Findings

### Finding 1: Option 2 credential brokering has no caller identity, so it hands every agent every brokered credential

- **Severity:** Critical
- **Category:** Misapplication — control asserted as a boundary that is not one (identity management / confused deputy)
- **Observation:** The artifact's headline argument for Option 2 is credential brokering (line 227: "is the
  only one that can broker credentials so tokens never enter the agent container"). The mechanism is
  described at line 115: "long-lived tokens live in the mediator and are injected as upstream headers, so
  the agent container never holds a secret." Nowhere in the artifact does the mediator authenticate
  *which* agent container is making the request. All three agent containers are peers on the same
  `agents-net` (lines 93-99) and all three are clients of the same mediator. A brokered credential
  injected on the basis of "a request arrived from the pod network" is available to every container on
  that network.
- **Evidence:**
  - Artifact line 102: "One container per agent, one state volume per agent. **Claude Code cannot read
    Codex's `auth.json`.**"
  - Artifact line 115: "Optional **credential brokering**: long-lived tokens live in the mediator and are
    injected as upstream headers... `codex-responses-api-proxy` is a ready-made primitive for this on the
    OpenAI side — it forwards only `POST /v1/responses` and 403s everything else." The stated filter is on
    **method and path**, not on caller.
  - Artifact lines 93-99: the topology diagram places `[claude]`, `[codex]` and `[agy]` on one
    `agents-net` with `[egress-mediator]` as the single upstream.
  - Reference line 755: "Verify API caller identity against a user or agent groups".
  - Reference line 756: "Authenticate agents with fresh cryptographic proofs before every privileged call".
  - Reference lines 457-458: "developers should construct each agent as a distinct principal, a
    cryptographically anchored identity with its own unique keys or certificates".
  - Reference lines 462-463: "Authenticate all inter-agent and agent-to-service API calls using mutual
    transport layer security to ensure non-repudiation".
  - Reference lines 466: "Deny access for any agent or cryptographic key that is not present in the trusted
    registry".
  - Reference lines 189-190 name this exact pattern: "This is an example of a 'confused deputy' pattern,
    where a trusted agent is misused to perform unauthorised actions."
- **Impact:** Turning on the feature the recommendation is built around makes credential isolation
  **strictly worse** than the volume-based isolation it replaces. Today a compromised Claude Code container
  cannot read Codex's `auth.json` (line 102's claim). With brokering as described, it does not need to — it
  sends `POST /v1/responses` to the mediator and the mediator attaches the OpenAI token for it. The same
  holds in reverse for the Anthropic credential. The artifact therefore recommends an option on the
  strength of a control that, as specified, collapses the per-agent boundary the same option claims to
  establish. Because the mediator is also the policy decision point, a compromised agent that can direct
  the deputy also produces audit records that attribute its actions to a legitimate credential — reference
  lines 190-192: "the system produces audit logs that appear legitimate and delay detection."
- **Recommendation:** Make per-agent identity at the mediator a hard requirement of Option 2 before it is
  selected, and add it as a Comparison row. Concretely: issue each agent container a distinct client
  certificate or workload identity; require mTLS from agent container to mediator (reference line 462);
  bind each brokered credential to exactly one client identity and refuse cross-binding; record the client
  identity in every audit line. Until that exists, state in the artifact that brokering is mutually
  exclusive with a shared agent network, or that only one agent may be brokered per pod.
- **Sibling coverage:** `STANDARDS_MAPPING.md` G3 (line 135-139) proposes per-agent workload identity, but
  frames it purely as an **attribution** problem ("so actions are attributable to an agent rather than only
  to a container"). The cross-agent credential-theft consequence of brokering without caller identity is
  not recorded anywhere.

### Finding 2: The stated threat is prompt injection, yet the artifact contains no ingress control of any kind

- **Severity:** High
- **Category:** Scope error — threat model states a cause, mitigates only the effect
- **Observation:** Line 32 names the primary threat precisely: "indirect prompt injection from a repository,
  a web page, an MCP server response, or a dependency". Line 34 then says "That threat model has two
  consequences that drive every option below" and both consequences (lines 36-37) are about **egress**. Every
  control in all three options sits downstream of compromise. There is not one control at any of the four
  ingress points the artifact itself enumerates. The reference requires controls on both sides.
- **Evidence:**
  - Artifact lines 30-37 (Threat model): the four injection vectors are named, then abandoned.
  - Artifact line 104 is the only claim of layered defence: "Each agent's own native controls are layered
    inside as defence in depth: `srt` for Claude Code, `features.network_proxy` for Codex, `agy --sandbox`
    for Antigravity." All three are **containment** primitives. None inspects an input.
  - Reference lines 477-478: "Apply security controls at all points where information enters or exits the
    system, including user inputs, tool calls, data pre-processing and model inference."
  - Reference lines 519-525 (Input management): "Implement robust input validation and sanitisation for all
    agent inputs"; "Integrate prompt injection filters and semantic analysis to detect malicious
    instructions"; "Validate context to ensure the system correctly interprets intent before execution."
  - Reference lines 428-437 (Controlled context): "Structure prompt context using a clear instruction
    hierarchy to ensure agent behaviour aligns with intended priorities and constraints."
  - Reference lines 711-712 (Validate outputs): "Validate tool responses to prevent malicious or unsafe
    instructions and standardise tool descriptions to avoid persuasive language."
  - Reference lines 326-327 (Tool use): "Two-way tool integration allows tools to send potentially arbitrary
    instructions back to the LLM." The mediator sits directly on this return path in Option 2 and the
    artifact never proposes using it.
  - Reference lines 475-476: "Avoid reliance on a single security mechanism by implementing multiple,
    overlapping layers of security controls."
- **Impact:** The artifact's "defence in depth" is one-sided: three layers of containment stacked in the
  same direction. Probability of compromise is untouched by any option; only the consequence is bounded.
  This is a real discriminator the Comparison table omits — Option 2's mediator is the only enforcement
  point in the three options that terminates the response path and could host tool-response validation or
  an injection filter, and the artifact never claims that advantage or scopes the work.
- **Recommendation:** Either add an ingress-control row to the Comparison table (which option can inspect
  and constrain *inbound* tool/web/MCP content) and state which controls each option supports, or add an
  explicit non-goal to this document stating that ingress filtering is out of scope with a named reason.
  Silence is the problem, not the choice.
- **Sibling coverage:** Not in G1–G5. `REQUIREMENTS.md` non-goals cover exfiltration through allowlisted
  destinations, not ingress inspection.

### Finding 3: "Audit trail of what a compromised agent attempted" is network-only; agent action and tool-call logging is absent from every option

- **Severity:** High
- **Category:** Omission + unsupported claim (accountability / monitoring)
- **Observation:** Every logging statement in the artifact is about network destinations. Line 227 then
  generalises this into a claim about the agent's behaviour as a whole, which the design does not support.
- **Evidence:**
  - Artifact line 117: "Every attempted **destination** is logged. You see the injection attempt, not just
    the block." (emphasis added — destination, not action)
  - Artifact line 163, Comparison row: "Audit log | Vendor-provided | Full, self-owned | Full, self-owned".
    The row's axis is **ownership**, not content or integrity.
  - Artifact line 227: "is the only one that yields an audit trail of what a compromised agent
    **attempted**". A destination log records what the agent attempted *on the network*. It records nothing
    about file writes inside the mounted project, commands executed, sub-agents spawned, MCP tools invoked,
    or state written to the persistent volume.
  - Reference lines 406-409 (Visibility): "While tools perform many actions for an agentic system, they may
    operate outside of the system's monitoring boundary, making it difficult to account for tool actions.
    Additionally, malicious or compromised agents could use tools as a stealthy way to exfiltrate data."
  - Reference lines 570-571: "Log agent tool usage and ensure results are captured in system logs in a
    human-readable format."
  - Reference line 676: "Monitor all agent operations, including internal processes, not just the inputs and
    outputs."
  - Reference lines 679-681: monitor "user prompts, tool calls, memory interactions, internal reasoning,
    decisions made and actions taken."
  - Reference lines 692-693: "Integrate source checks with agent logs to record which tools the system used
    and what information it retrieved."
  - Reference lines 372-374: "agents may initiate secondary tasks, spawn sub-agents, or follow extended
    delegation chains in ways that are not always visible to operators."
- **Impact:** After an incident, the operator can reconstruct where the agent tried to connect and nothing
  else. Reference lines 386-390 describe exactly this failure — an outcome that cannot be traced to a
  decision. The over-claim at line 227 is load-bearing in the recommendation: it is one of four reasons
  given for choosing Option 2, and it is stated more broadly than the design delivers.
- **Recommendation:** Correct line 227 to "an audit trail of every destination a compromised agent
  attempted to reach". Then add an "Agent action log" row to the Comparison table and evaluate all three
  options on it: where the tool-call/file-write log is written, whether it survives container destruction,
  and whether it is reachable from inside the sandbox.
- **Sibling coverage:** `STANDARDS_MAPPING.md` G1 (lines 121-127) proposes R9.7/R9.8 for exactly this. The
  artifact should carry it because **it is a discriminator between the three options** — the options differ
  in where such a log can be written and who owns it — and instead the artifact makes a stronger claim than
  the design supports. Sibling coverage does not excuse the over-claim at line 227.

### Finding 4: The Suggested Sequence inverts progressive deployment — it starts at maximum permitted access with live credentials

- **Severity:** High
- **Category:** Contradiction of the reference's stated position (progressive deployment / secure by default)
- **Observation:** Step 1 of the recommended sequence runs all three authenticated agents against a real
  repository under a **permissive vendor default preset**, in order to observe what they touch, and only
  then narrows. The reference's position is the exact inverse: start restricted and expand.
- **Evidence:**
  - Artifact lines 233-234: "1. Stand up Option 1 and run the three agents against a representative
    repository. Capture the real set of destinations each agent contacts. 2. Turn that capture into the
    allowlist, and add the denylist overlay..."
  - Artifact line 71 defines the default preset the capture would run under: "`balanced` (default) — default-deny
    plus a **baseline allowlist of AI provider APIs, package managers, code hosts, registries**".
  - Artifact line 64: `sbx policy init balanced` is the initialisation shown.
  - The sequence contains no instruction to use disposable credentials, a scratch repository, a throwaway
    workspace, or an isolated AWS profile. Contrast `REQUIREMENTS.md` R12.4, which does say "run in a
    disposable environment, never against production credentials" — that constraint is absent here.
  - Reference lines 621-622: "Implement phased deployment with **progressively increasing** access and
    autonomy, limiting the action space where required, such as restricted APIs or sandboxing."
  - Reference lines 623-624: "Use graduated autonomy to incrementally increase agent independence whilst
    maintaining human oversight and understanding."
  - Reference line 67: "organisations should only use agentic AI for low-risk and non-sensitive tasks."
  - Reference lines 633-634 (Secure by default): "Set system configurations to fail-safe by default."
- **Impact:** The one moment in the whole plan when the agents run with the widest policy is also the moment
  they run against a real repository with real credentials, unattended, for the purpose of generating
  traffic. Every risk the document exists to mitigate is maximally present during the step designed to
  measure it. A repository containing an injection payload would be executed under `balanced` — which
  permits code hosts and registries by the artifact's own definition.
- **Recommendation:** Rewrite step 1: run the capture under `locked-down` plus an explicit minimal seed
  allowlist and widen only on observed failures; use a disposable workspace and non-production credentials;
  and state that the capture is a discovery exercise, not a production session. Add a step 3.5 that
  verifies the boundary holds (see Finding 5) before the environment is used for real work.
- **Sibling coverage:** Not in G1–G5.

### Finding 5: The Suggested Sequence has no verification step — the boundary is never tested before use

- **Severity:** High
- **Category:** Omission (red teaming / performance monitoring / evaluation)
- **Observation:** The four-step sequence at lines 231-236 is: capture, compose policy, build, defer. No
  step attempts to break out of what was built. The reference asks for this in three separate places, one of
  which is specifically about testing whether the agent can bypass the safeguards you just chose.
- **Evidence:**
  - Artifact lines 231-236 — the complete sequence. Step 4 is "Re-evaluate Option 3 only if the threat model
    changes", which is a deferral, not a verification.
  - Reference line 529: "Deploy sandbox environments to test agent behaviour before production deployment."
  - Reference line 530: "Conduct red teaming exercises to identify potential loopholes and unintended
    behaviour."
  - Reference lines 739-740: "Conduct regular assessments of an agent's ability to bypass safeguards, such
    as communication barriers, guardrails, monitors, human-in-the-loop processes and input filters."
  - Reference lines 702-703: "Conduct regular security assessments, including penetration testing and red
    team exercises specifically targeting agentic behaviours."
  - Reference lines 737-738: "Assess agents' ability to evade security measures particularly in sensitive or
    high-impact systems."
- **Impact:** The document commits to building a self-owned enforcement point ("You own and maintain it",
  line 123) and never asks whether it works. The failure modes the artifact itself flags are exactly the
  ones that need a test: line 127 "Requires care so that a misconfigured `internal: true` does not silently
  become routable" is named as a risk and given no verification step. A silently-routable `internal`
  network defeats the entire architecture with no visible symptom.
- **Recommendation:** Add an explicit verification step between "build" and "use", and reference
  `REQUIREMENTS.md`'s Acceptance Test Matrix (T1–T20) from the Recommendation section so the reader knows
  where the tests live. At minimum name the four that the artifact's own design notes imply: DNS
  exfiltration, `internal: true` routability, post-resolution CIDR deny on a rotating CDN, and policy
  tampering from inside a container.
- **Sibling coverage:** `REQUIREMENTS.md` carries T1–T20, but `OPTIONS_ANALYSIS.md` never points at it and
  its sequence would ship an unvalidated boundary.

### Finding 6: No human oversight or approval dimension anywhere, including for network egress, which the reference names explicitly

- **Severity:** High
- **Category:** Omission (oversight mechanisms / human in the loop)
- **Observation:** The artifact assumes unattended operation throughout and never says so, never records it
  as a deviation, and never evaluates the three options on whether an operator approval checkpoint is even
  possible. The reference names **network egress** — the artifact's entire subject — as a class of action
  warranting a human checkpoint.
- **Evidence:**
  - Artifact: zero occurrences of human approval, operator confirmation, interruption, or hold-and-prompt in
    236 lines. The closest is line 117 ("You see the injection attempt") which is retrospective log reading,
    and line 26, which mentions `--dangerously-skip-permissions` only as a reason the container must be
    non-root.
  - Artifact lines 154-166 (Comparison table): 12 rows, none of them oversight, approval, or interruption.
  - Reference lines 723-724: "Insert human-in-the-loop review or approval checkpoints for actions where the
    cost of error is high, such as system resets, **network egress** or deletion of critical records."
  - Reference lines 719-720: "Ensure decisions about when human approval is required are determined by
    system designers or operators, not delegated to the agentic AI system."
  - Reference lines 446-448: "Include mechanisms to facilitate human control and oversight to ensure that
    agentic AI systems approved for non-sensitive, low-risk tasks cannot autonomously progress into
    higher-risk activities."
  - Reference lines 449-451: "Implement human control points throughout the agent workflow, such as live
    monitoring and interruption during task execution, mandatory human approval for decision-making steps,
    auditing and reversibility following task execution."
  - Reference lines 728-729: "Conduct risk assessments to classify agent actions by potential impact,
    likelihood and reversibility, and apply appropriate safeguards."
- **Impact:** This is an architectural discriminator, not a policy detail. Option 2's self-owned mediator is
  the only one of the three that can hold a connection and prompt an operator on a novel destination;
  Option 1's vendor proxy cannot be extended to do so, and Option 3's `pf`/`nftables` rules cannot. That is
  a genuine and material argument *for* the recommended option, and the artifact does not make it —
  because the dimension is absent entirely.
- **Recommendation:** Add a Comparison row for "Operator approval / interactive hold on novel destination"
  and evaluate all three. Separately, state in the Threat model section that operation is unattended with
  permission prompts bypassed, and record that as a deliberate deviation from the reference's HITL position
  with its compensating controls named.
- **Sibling coverage:** `STANDARDS_MAPPING.md` G2 (lines 129-133) records the HITL tension and proposes
  R12.7. G2 does **not** record the reference's specific naming of network egress as a checkpoint class, and
  does not treat operator-approval capability as an option-selection criterion. The artifact should carry
  the latter because it is the document that selects the option.

### Finding 7: Package registries are allowlisted as a matter of course, opening an untrusted-code inbound channel that no option addresses

- **Severity:** High
- **Category:** Omission + misapplication (third-party components / structural risk)
- **Observation:** The artifact's own example egress policy allowlists whole package registries, and the
  `balanced` preset it recommends starting from allowlists "package managers... registries". A package
  registry is not a data destination — it is an arbitrary-code inbound channel. The reference names dynamic
  package loading as a structural risk and requires an approved-tool allowlist with pinned, verified
  versions. The artifact's Cross-Cutting "Egress policy" section names exactly two traps and this is not
  one of them.
- **Evidence:**
  - Artifact line 65: `sbx policy allow network "api.anthropic.com,*.npmjs.org,*.pypi.org"` — presented as
    the model policy with no caveat.
  - Artifact line 71: `balanced` "(default) — default-deny plus a baseline allowlist of AI provider APIs,
    **package managers**, code hosts, **registries**".
  - Artifact lines 200-203: "Two traps worth repeating here" — stale vendor allowlists, and DNS ownership.
    Neither is the code-supply channel.
  - `RESEARCH_FINDINGS.md` line 126 confirms the channel is live: `registry.npmjs.org` is required for
    "CLI install, plugin installs, **`npx` MCP servers**" — i.e. the allowlist entry permits the agent to
    fetch and execute an arbitrary named package as an MCP server inside the sandbox.
  - Reference line 340: "tools and agents **dynamically loading new packages, increasing exposure to
    untrusted code**."
  - Reference lines 333-334: "malicious actors engaging in tool or agent 'squatting' by publishing malicious
    tools or agents with legitimate or similar names."
  - Reference lines 567-568: "Restrict tool use to an approved allow list of tools and versions that are
    regularly verified as secure."
  - Reference lines 561-563: "Verify all external third-party components originate from trusted sources and
    are up to date before inclusion"; "Maintain a trusted registry of third-party components."
  - Reference lines 230-232: "In cases where allow lists are incomplete or outdated, agents may gain access
    to resources, system calls, or commands beyond their intended privilege."
- **Impact:** A wildcard registry entry is simultaneously (a) an exfiltration destination — a publish
  operation to an attacker-controlled package name is indistinguishable from a fetch at the domain level,
  which is precisely the argument the project makes against `*.amazonaws.com` elsewhere — and (b) an
  arbitrary-code-execution channel that reintroduces third-party code into a sandbox whose contents were
  supposed to be pinned. Because the artifact's step 1 derives the allowlist from observed traffic, and
  observed traffic under `balanced` will include registry calls, the flawed entry propagates by construction
  into the Option 2 policy.
- **Recommendation:** Add a third trap to the Cross-Cutting Egress section stating that package-registry
  allowlisting is an untrusted-code inbound channel and an exfiltration channel, and that it should be
  absent at runtime (packages installed at build time) or narrowed to specific package paths through a
  pull-through cache. Add a note that MCP servers fetched via `npx` inherit the sandbox and are covered by
  every control that applies to the agent.
- **Sibling coverage:** `STANDARDS_MAPPING.md` G4 proposes an MCP/plugin inventory requirement (R7.14). G4
  does not cover the registry-wildcard egress entry, which is the mechanism by which uninventoried code
  arrives.

### Finding 8: Log integrity and agent write-access to logs are never evaluated; the Comparison row measures ownership instead

- **Severity:** Medium
- **Category:** Omission (isolation / accountability)
- **Observation:** The reference makes "no write access to logs" a control distinct from policy-enforcement
  location. The artifact establishes the general principle for *policy* (line 37) and never applies it to
  *logs*, and its Comparison row grades logs on who owns them rather than whether the agent can reach them.
- **Evidence:**
  - Artifact line 163: "Audit log | Vendor-provided | Full, self-owned | Full, self-owned".
  - Artifact line 41-45 (Enforcement point per option table): the "Can a compromised agent modify it?" column
    is asked about **policy** only, never about the log.
  - Reference line 658: "**Isolate agents into enclaves with no write access to logs.**"
  - Reference line 725: "Quarantine requests to delete logs or audit records until reviewed and approved by a
    human."
  - Reference line 356: rogue agents can "bypass controls, exfiltrate data, **alter logs** and propagate
    malicious plans."
- **Impact:** Under Option 1 the artifact has not established where the vendor writes its log or whether the
  guest can reach it — and line 81 records the CLI as closed-source, so this is unverifiable. Under Option 2
  the log lives in the mediator container, which the design supports, but the document never says so, so a
  reader implementing from this document could reasonably write the log to a shared volume.
- **Recommendation:** Change the Comparison row to "Audit log — location and agent reachability" and state
  for each option whether the agent has any write path to it. Add one line to Option 2's Shape section
  stating the log is written inside the mediator, not to a volume shared with agent containers.
- **Sibling coverage:** `REQUIREMENTS.md` R9.2 covers it; the artifact's Comparison table does not, and the
  table is the decision instrument.

### Finding 9: Resource exhaustion, sponge attacks and rate limiting are absent from all three options

- **Severity:** Medium
- **Category:** Omission (structural risk — orchestration and resources)
- **Observation:** No option discusses CPU, memory, PID or disk limits, request rate limits, long-running
  task interruption, or model-API call/cost exhaustion. The reference treats these as a named risk class and
  a named control, and lists rate limiting among the Appendix A prerequisites.
- **Evidence:**
  - Artifact: no occurrence of a resource limit, quota, rate limit, timeout, or cost control in 236 lines,
    including the 12-row Comparison table (lines 154-166).
  - Reference lines 315-319: "Poor configuration could allow denial-of-service, sponge, or similar attacks
    on agentic AI systems. These attacks work by overloading system resources through unexpected inputs or
    unusual behaviour, such as sponge attacks that deliberately consume excessive **compute, memory, or API
    calls** to exhaust system capacity."
  - Reference lines 743-744: "Limit agent resource usage by applying controls, such as **rate-limit
    components to interrupt long-running tasks and disrupt malicious workflows**."
  - Reference lines 901-902 (Appendix A): "Build system infrastructure in a secure, sandboxed environment
    with encryption, **rate limiting** and sanitisation."
- **Impact:** This is a real discriminator the Comparison omits. Option 3's per-agent VMs carry hard
  resource ceilings by construction; Option 2's containers have none unless `deploy.resources` limits are
  declared, which the Shape section (line 101) does not list among its hardening options despite listing six
  others. A compromised agent under Option 2 can therefore exhaust the host, and can burn the operator's
  model-API quota freely because the egress policy allows `api.anthropic.com` unconditionally — the
  "selective, not binary" egress model (line 36) provides no rate dimension at all.
- **Recommendation:** Add resource limits to Option 2's hardening list at line 101 alongside `cap_drop`,
  `no-new-privileges` and read-only rootfs. Add a Comparison row for resource containment. State whether
  the mediator rate-limits upstream model API calls.
- **Sibling coverage:** `REQUIREMENTS.md` R1.10 covers container resource limits; nothing in either document
  covers rate limiting at the enforcement point or model-API call exhaustion. Not in G1–G5.

### Finding 10: No incident response, containment or rollback; the recommended option is the weakest of the three on recovery and the artifact does not say so

- **Severity:** Medium
- **Category:** Omission (threat modelling / resilience)
- **Observation:** The artifact is entirely preventive. There is no kill switch, no containment procedure,
  no credential revocation path, and no mechanism to return a contaminated environment to a known-good
  state. The reference asks for all of these, and the conclusion explicitly ranks reversibility above
  efficiency.
- **Evidence:**
  - Artifact: no occurrence of incident, response, revoke, rollback, snapshot, recovery, or containment
    procedure in 236 lines.
  - Artifact line 102: "One container per agent, **one state volume per agent**" — persistent named volumes.
    Line 194: "Treat every one of these volumes as a secret." A compromised agent writes to that volume, and
    the artifact provides no way to distinguish a contaminated volume from a clean one or to revert it.
  - Artifact line 101: project directories bind-mounted, "`:ro` where the agent does not need to write" —
    implying writable project mounts, with no snapshot or diff-review step named anywhere.
  - Reference lines 602-603: "**Develop and test incident response procedures to detect, contain and recover
    from agent compromise.**"
  - Reference lines 542-543: "Implement versioning and rollback mechanisms to safely revert a system to
    known-good agent behaviours when unpredictability is observed."
  - Reference lines 572-573: "Establish trigger-action protocols that automatically restrict agent
    permissions when unexpected behaviour emerges."
  - Reference line 927 (Appendix A): "Plan and regularly test incident response plans and teams."
  - Reference lines 839-840 (Conclusion): "prioritising **resilience, reversibility** and risk containment
    over efficiency gains."
- **Impact:** On recovery, the three options rank in the opposite order to the artifact's recommendation.
  Options 1 and 3 destroy and recreate a microVM trivially. Option 2 carries persistent named volumes, a
  hand-built mediator with hand-built state, and a self-owned log — the slowest and least certain to return
  to known-good. The recommendation section (lines 219-229) gives four reasons to prefer Option 2 and does
  not mention this trade-off at all.
- **Recommendation:** Add a "Recovery to known-good" row to the Comparison table. Add a short paragraph to
  the Recommendation acknowledging that Option 2 trades recovery simplicity for control, and name the
  compensating step (e.g. volumes are recreated per session; only an explicit credential re-auth persists).
- **Sibling coverage:** Not in G1–G5. Neither `REQUIREMENTS.md` nor `STANDARDS_MAPPING.md` addresses
  incident response or rollback.

### Finding 11: Option 1's policy scope is global by default, contradicting the Comparison table's "Cross-agent isolation: Per sandbox"

- **Severity:** Medium
- **Category:** Internal contradiction against a reference requirement (least-privilege scoping / isolation)
- **Observation:** The artifact states Option 1's egress policy is global by default, then grades Option 1
  as providing per-sandbox cross-agent isolation. Under the default the artifact describes, every agent
  receives the union of all three agents' allowlists.
- **Evidence:**
  - Artifact line 72: "Scope is **global by default**; `--sandbox <name>` scopes a rule to one sandbox."
  - Artifact line 162, Comparison row: "Cross-agent isolation | **Per sandbox** | Per container | Per VM".
  - Artifact lines 63-66 show the worked example using no `--sandbox` flag, i.e. global scope.
  - Reference lines 467-468: "Apply role-based identity management and **limit agent permissions to the
    minimum scope required for approved tasks**."
  - Reference line 657: "Separate high-risk agents into distinct domains."
  - Reference line 904 (Appendix A): "Limit entitlements to the exact resources, operations and timeframes
    needed."
- **Impact:** The Comparison table is the artifact's decision instrument and it overstates Option 1 on an
  isolation axis. If Option 1 is used as the validation ground (which the Recommendation directs, line 221),
  a globally-scoped capture also produces a merged allowlist that is then carried into Option 2 — so the
  scoping error propagates into the durable design as an over-broad per-agent policy.
- **Recommendation:** Correct the row to "Per sandbox for filesystem/VM; **egress policy global unless each
  rule is explicitly `--sandbox` scoped**". Add to step 1 of the sequence that the capture must be run one
  agent at a time with `--sandbox` scoping, so the resulting allowlist is per-agent rather than a union.
- **Sibling coverage:** Not in G1–G5.

### Finding 12: The Option 2 allowlist is derived from a single closed-source observation point with no cross-validation or completeness check

- **Severity:** Medium
- **Category:** Assertion without verification (monitoring / third-party understanding)
- **Observation:** The Recommendation makes Option 1 the authoritative source of ground truth for the
  policy that Option 2 will enforce, while simultaneously recording that Option 1's CLI is closed-source and
  that its proxy terminates HTTP/HTTPS. Nothing checks whether the capture is complete.
- **Evidence:**
  - Artifact line 221: "Build Option 2. **Validate the policy with Option 1 first.**"
  - Artifact line 223: "independently validates the allow/deny list against real agent traffic."
  - Artifact line 81: "CLI is closed-source (the public repo is a release and issue tracker)."
  - Artifact line 73: "**Only HTTP/HTTPS is fully intercepted** through the proxy. Non-HTTP TCP (including
    SSH) can be permitted with a hostname rule." — so any non-HTTP destination is, by the artifact's own
    account, less fully observed.
  - Artifact line 74: UDP and ICMP are blocked entirely under Option 1 — meaning any legitimate UDP
    dependency of an agent is invisible to the capture and will surface as a novel failure under Option 2.
  - Reference lines 688-689: "Use **multiple independent monitoring systems that cross-validate** agent
    reports and system logs."
  - Reference lines 230-232: "In cases where allow lists are incomplete or outdated, agents may gain access
    to resources, system calls, or commands beyond their intended privilege."
  - Reference lines 917-919 (Appendix A): "Enforce application understanding and only incorporate components
    into systems that the owner **fully understands and accepts the risks of** (including possible external
    effects and processes that it may trigger)."
  - Reference lines 153-154: "Gaps in agentic AI cyber security tooling and the immaturity of relevant
    standards further amplify these risks."
- **Impact:** The word "validates" at line 223 asserts more than a single closed-source observation source
  can deliver. Destinations reached by the vendor's own proxy on the agent's behalf, or normalised by it,
  will not appear; UDP dependencies cannot appear; and there is no second source to cross-check against. An
  incomplete allowlist fails loudly at runtime (recoverable), but a *falsely complete* one is treated as
  finished and reviewed no further.
- **Recommendation:** Downgrade the language from "validates" to "seeds". Add a second, independent
  observation source for cross-validation — the agents' own verbose/debug logging, or a `tcpdump` on the
  Option 2 mediator during a shadow run — and state that the allowlist is provisional until both agree.
- **Sibling coverage:** Not in G1–G5.

### Finding 13: Egress control is destination-only with no content layer, and the MITM-versus-splice decision is left unresolved while the option is declared chosen

- **Severity:** Medium
- **Category:** Unresolved decision presented as decided (data loss prevention / defence in depth)
- **Observation:** Option 2's only egress discriminator is the destination. The artifact acknowledges that
  content granularity requires TLS interception, lists it as a con, resolves the question for Antigravity
  only, and leaves it open for Claude Code and Codex — then recommends "Build Option 2" without closing it.
- **Evidence:**
  - Artifact line 124: "Splice-only gives domain granularity; **URL-path rules require TLS MITM and CA
    distribution**."
  - Artifact line 213: "For the Antigravity container, use SNI/CONNECT **splice** — inspect the destination,
    never decrypt." — resolved for one agent of three.
  - Artifact line 129 describes CA distribution mechanics for Claude Code and Codex "if MITM is used",
    without deciding whether it is.
  - Artifact line 221: "**Build Option 2.**" — the option is selected with this decision open.
  - Reference line 541: "Implement **data loss prevention** controls specifically tuned to AI agent
    behaviours."
  - Reference lines 477-478: "Apply security controls at all points where information enters **or exits**
    the system."
- **Impact:** Whether any content-level control exists in the recommended architecture is undecided, and the
  decision drives real work (CA generation, distribution, rotation, and per-agent trust-store configuration)
  that is not scoped in the "Days, not hours" estimate at line 123. It also determines whether Finding 2's
  ingress inspection is even possible. A reader taking "Build Option 2" as the decision has not, in fact,
  been given the design.
- **Recommendation:** Make the MITM/splice decision explicitly per agent in this document, with its
  consequence for content inspection stated. If splice-only is chosen for all three, state plainly that
  content-level DLP is out of scope and that destination narrowing plus audit is the accepted residual
  control.
- **Sibling coverage:** `REQUIREMENTS.md` R5.12 and R5.13 cover CA distribution and the Antigravity
  prohibition; neither decides the Claude/Codex case, and no requirement covers DLP.

### Finding 14: Agent binaries are acquired by unverified install script and global npm install, with no provenance, signing, SBOM or attestation

- **Severity:** Medium
- **Category:** Omission (manage third-party components / supply chain)
- **Observation:** The Design Constraints table records how each agent enters the image and treats the
  acquisition method as a packaging detail. One of the three is an install script — an unauthenticated
  fetch-and-execute — and the artifact records it without comment. Nothing in the artifact addresses image
  or binary provenance.
- **Evidence:**
  - Artifact line 28: "Google Antigravity | `agy` Go binary **via install script**".
  - Artifact line 26: "Claude Code | `npm i -g @anthropic-ai/claude-code` (Node)" — no version pin, no
    integrity check, in a document that elsewhere pins vendor CLI versions (line 55: "v0.38–0.39").
  - Artifact: no occurrence of checksum, signature, SBOM, digest, or attestation in 236 lines.
  - Reference lines 561-562: "Verify all external third-party components **originate from trusted sources
    and are up to date** before inclusion in agentic AI systems."
  - Reference lines 564-566: "Reference CISA's A Shared Vision of Software Bill of Materials (SBOM) for
    Cybersecurity and 2025 Minimum Elements for a Software Bill of Materials (SBOM) when procuring agentic
    AI systems."
  - Reference lines 759-760: "**Require agents to perform cryptographic attestation where agents must prove
    that they are running expected and unmodified code.**"
  - Reference lines 920-922 (Appendix A): "Refer to frameworks, such as the NIST Secure Software Development
    Framework or SLSA's Safeguarding artifact integrity across any software supply chain"; "Use supply chain
    risk management practices for third-party dependencies."
  - This also contradicts the project's own `REQUIREMENTS.md` R7.7, which prohibits `curl | bash` at runtime
    — the `agy` install script is that pattern at build time, recorded here with no mitigation.
- **Impact:** The strongest possible enforcement boundary is worthless if the thing inside it was replaced
  before the boundary existed. The reference treats the supply chain into the sandbox as part of the same
  problem, and this document — which decides what goes into the image — is silent on it.
- **Recommendation:** Add one line to the Design Constraints table's Notes column per agent stating how its
  artifact integrity is verified (pinned npm version plus lockfile integrity hash; released binary plus
  published checksum, not the install script; digest-pinned base image). State explicitly that the `agy`
  install script is not run at build time.
- **Sibling coverage:** `REQUIREMENTS.md` R10.2 and R7.7 cover pinning and prohibit `curl | bash`;
  `OPTIONS_ANALYSIS.md` records an acquisition method that violates R7.7 without flagging the conflict.

### Finding 15: Long-lived refresh tokens are accepted as the design for all three options; ephemeral credentials appear only as an "Optional" feature of one

- **Severity:** Medium
- **Category:** Contradiction of the reference's stated position (Appendix A prerequisites / privileges)
- **Observation:** The artifact states that every agent state volume holds long-lived refresh tokens and
  must be treated as a secret, and treats that as the baseline. The reference's position is that long-lived
  secrets should be **replaced**, not merely protected. Credential brokering — the mechanism that would
  satisfy the reference — is marked "Optional" and available under one option only.
- **Evidence:**
  - Artifact line 194: "**Treat every one of these volumes as a secret.** They hold **long-lived refresh
    tokens**."
  - Artifact line 191: "use `claude setup-token` to mint a **one-year** `CLAUDE_CODE_OAUTH_TOKEN`" — offered
    as a solution, a one-year static bearer token inside the blast radius.
  - Artifact line 115: "**Optional** credential brokering".
  - Reference lines 905-906 (Appendix A): "**Replace static, long-lived secrets with ephemeral credentials
    that expire when the job is complete.**"
  - Reference line 754: "Require **just-in-time credentials** for high-impact or privileged actions."
  - Reference lines 213-214: "Malicious actors can steal these secret keys or tokens when organisations keep
    them **static**, share them across multiple agents, or protect them poorly."
  - Reference line 904: "Limit entitlements to the exact resources, operations and **timeframes** needed."
- **Impact:** The artifact quotes Anthropic's own statement (line 194) that a container "does not prevent a
  malicious project from exfiltrating anything accessible inside the container, including the Claude Code
  credentials" — and then, three lines earlier, recommends minting a one-year token to put inside that
  container. The document identifies the exposure and proposes the thing that maximises its duration,
  without stating the trade-off.
- **Recommendation:** Record the persistence of long-lived refresh tokens as an explicitly accepted risk in
  this document, with its compensating controls named and a stated review trigger. Prefer the shortest
  viable token lifetime over `setup-token`'s one-year default, and state why one year was chosen if it is.
- **Sibling coverage:** `STANDARDS_MAPPING.md` G5 (lines 147-151) records this exact tension and proposes
  R4.12. The artifact should carry it because line 191's one-year-token recommendation is made here and
  nowhere else, and G5 does not address it.

### Finding 16: The Antigravity legal risk is surfaced, left undecided, and assigned to no one

- **Severity:** Low
- **Category:** Omission (governance / accountability)
- **Observation:** The ToS section identifies a documented history of account suspension, offers three
  pieces of guidance, and then disclaims its own authority — without recording a decision, an owner, or a
  review trigger. The reference asks for legal accountability and risk ownership to be defined.
- **Evidence:**
  - Artifact line 207: "Google has **suspended paid accounts** — including AI Ultra subscribers — without
    warning."
  - Artifact line 209: "a TLS-intercepting (MITM) proxy placed in front of Antigravity OAuth traffic is
    **arguably** within the scope of that clause."
  - Artifact line 217: "This guidance is an **interpretation** of the published terms, not an official
    Google position. Google staff declined to clarify the boundary when asked."
  - No decision is recorded: lines 213-215 offer "use splice", "or sidestep via `GEMINI_API_KEY`/Vertex",
    "avoid wrapper tooling" — three options, none selected, and the Recommendation section (219-236) does
    not close it either.
  - Reference line 612: "**Define legal accountability and risk ownership** for agentic AI systems in
    policies."
  - Reference lines 604-605: "Establish regular third-party reviews of privileged architectures... and
    update risk models to reflect emerging malicious trends."
  - Reference lines 726-727: "Clearly assign responsibility and accountability for errors or adverse
    outcomes caused by the system."
- **Impact:** An unresolved risk with a known realised consequence (account suspension) sits in a decision
  document with no decision attached. Because the interpretation is explicitly unofficial and the vendor
  declined to clarify, the risk cannot be closed by analysis — it needs an owner and an accepted position.
- **Recommendation:** Convert the three pieces of guidance into one recorded decision with a named owner
  and a review trigger (e.g. "Decision: Antigravity authenticates by `GEMINI_API_KEY` on our own billing;
  the OAuth path is not used; revisit if Google publishes a clarification"). State which of the three
  routes the recommended architecture assumes.
- **Sibling coverage:** `REQUIREMENTS.md` R5.13 prohibits TLS-intercepting Antigravity OAuth, which closes
  the narrowest form of the question. Neither document assigns ownership or a review trigger.

## Strengths

Assessed against the reference, the artifact gets a small number of things genuinely right, and two of
them are things the reference calls out specifically:

- **Enforcement point outside the blast radius is stated as the governing principle and used as the
  organising axis.** Lines 34-37: "any control the agent process can itself modify is not a control. **The
  enforcement point must sit outside the blast radius.** This is the single axis on which the three options
  differ." This is precisely reference lines 645-646 ("Establish declarative safety contracts with
  constraints and guardrails that agents cannot override") and 656 ("Implement isolation and segmentation
  to limit blast radius"), and the artifact applies it consistently across all three options in the table
  at lines 41-45.
- **The vendor reference devcontainer pattern is explicitly rejected.** Line 47: in-container `iptables`
  requiring `NET_ADMIN`/`NET_RAW` "is weaker than any of the three below, and is why none of the options
  simply adopt it as-is." Rejecting a widely-copied vendor pattern on principle is the correct reading of
  reference lines 224-232 on unvetted third-party components and stale allow decisions.
- **The post-resolution CIDR denylist directly answers the reference's stale-allow-decision risk.** Line
  111: "even for an allowlisted domain, the connection is refused if the resolved IP falls in a blocked
  range. This catches CDN IP rotation and DNS rebinding, which an `ipset` snapshot built at container start
  cannot." This is an exact structural answer to reference lines 226-228 ("if entitlements are evaluated
  only once at system startup rather than at each invocation, a malicious actor can exploit a stale 'allow'
  decision").
- **DNS is treated as a covert channel and closed by construction, not by filtering.** Lines 74, 103 and
  204. Line 103's framing — "DNS tunnelling is structurally impossible rather than merely filtered" — is the
  right distinction between a boundary and a defence-in-depth measure, and the artifact applies it
  correctly.
- **Vendor allowlists are refused rather than copied.** Line 202: "Do not copy the vendor reference
  allowlists. Anthropic's is stale." Reference lines 230-232 warn that incomplete or outdated allow lists
  grant privilege beyond intent; the artifact independently detected an instance of it.
- **Residual risk is stated honestly in at least one place.** Line 194 quotes Anthropic's own admission that
  the container "does not prevent a malicious project from exfiltrating anything accessible inside the
  container, including the Claude Code credentials." Naming an unfixable exposure in the vendor's own words
  is better practice than most architecture documents manage.
- **Unverified items are labelled unverified.** Line 129: "`agy` CA handling is **unverified**". Line 217:
  the ToS reading is labelled an interpretation. The reference's whole posture (lines 146-157, "Evolving
  security as technology matures") depends on practitioners distinguishing what they know from what they
  assume, and the artifact does this in the places it does it at all.
