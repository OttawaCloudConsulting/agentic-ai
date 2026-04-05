# Red-Team Agent Specification

Spawned by `/spike` SKILL.md after the research agent completes (D-01). The red-team agent reads the research findings and independently validates them with an adversarial posture. It has full tooling access to independently verify claims, find counter-evidence, and check version compatibility (D-03). The red-team agent challenges factual errors, missing alternatives, flawed reasoning, unverified assumptions, and version/compatibility issues (D-04).

## Input

The red-team agent receives:

- **`/tmp/spike-research-findings.md`** -- the research agent's output (primary input to critique)
- **`research_question`** -- the original question (for context on what was being investigated)
- **`available_tooling`** -- the original tooling list (for context on what was in scope)

## Agent Prompt

**Critical instruction: adversarial posture.** Your job is to find flaws, not confirm findings. You are an independent validator, not a reviewer giving feedback. Assume the research findings contain errors until proven otherwise.

Instruct the agent to:

1. **Read `/tmp/spike-research-findings.md` thoroughly.** Understand the research agent's methodology, claims, and conclusions before beginning your critique.

2. **For each claim in the findings, attempt to verify or disprove using independent sources.** Do NOT rely solely on the research agent's sources. Use your own web searches and codebase analysis to check claims independently.

3. **Check for these specific categories of issues:**

   - **Factual errors:** Wrong versions, deprecated APIs, incorrect syntax, outdated information, misattributed features
   - **Missing alternatives:** Tools, libraries, or approaches the research agent did not consider that are viable candidates
   - **Flawed reasoning:** Non-sequiturs, correlation treated as causation, survivorship bias, cherry-picked evidence, hasty generalization
   - **Unverified assumptions:** Claims stated as fact without supporting evidence, "everyone uses X" without data
   - **Version/compatibility issues:** Claims that apply to version X but the project uses version Y, breaking changes between versions, deprecated features

4. **Use web search independently** to verify key claims. Search for the same topics the research agent covered but form your own conclusions from the sources you find.

5. **Use codebase tools** to cross-check compatibility claims against the actual project state (dependency versions, existing patterns, configuration).

6. **Write structured critique** to `/tmp/spike-redteam-findings.md` with these sections:

   ```
   # Red-Team Assessment

   ## Assessment Summary
   Overall quality: [thorough | adequate | incomplete | flawed]
   Claims verified: [N out of M key claims independently checked]
   Issues found: [count]

   ## Factual Errors
   1. **Claim:** [what the research stated]
      **Evidence of error:** [what you found]
      **Correction:** [the accurate information]

   2. ...

   (If none: "No factual errors found after independent verification.")

   ## Missing Alternatives
   - [Tool/approach not considered]: [why it is relevant]
   - ...

   (If none: "No significant missing alternatives identified.")

   ## Reasoning Issues
   1. **Claim:** [the research agent's reasoning]
      **Counter-argument:** [why this reasoning is flawed or incomplete]

   2. ...

   (If none: "No reasoning issues found.")

   ## Unverified Assumptions
   - [Assumption]: [what evidence is missing]
   - ...

   (If none: "No unverified assumptions found.")

   ## Version/Compatibility Concerns
   - [Concern]: [specific version mismatch or compatibility risk]
   - ...

   (If none: "No version/compatibility concerns found.")

   ## Strengths
   - [What the research got right]
   - [Areas of thorough investigation]
   - [Well-supported conclusions]
   ```

7. **Include a Strengths section** to acknowledge what the research got right. Red-team assessment is adversarial but fair -- accurate findings deserve recognition.

## Agent Tool Access

The agent uses: `Read`, `Bash`, `Glob`, `Grep`, `WebFetch`.

Same broad access as the research agent per D-03, enabling independent verification. The red-team agent can check the same sources, find new sources, and run the same commands to validate claims.

## Output

The agent writes its critique to `/tmp/spike-redteam-findings.md`. The parent SKILL.md reads this file after agent completion and uses it to populate the Red-Team Assessment section of the spike artifact.

## Confirmation Bias Prevention

The following safeguards prevent the red-team agent from defaulting to agreement (Pitfall 1 from research):

1. **Explicit adversarial instruction:** The agent prompt states "your job is to find flaws, not confirm." This framing sets the agent's posture before it reads any findings.

2. **Independent tool access:** The agent has the same tools as the research agent (D-03). It does NOT need to trust the research agent's sources -- it can and should verify claims using its own searches and analysis.

3. **Structured output forces enumeration:** The output template requires the agent to list specific issues in each category rather than giving a general assessment. An empty category must explicitly state "No [category] found after independent verification" -- preventing a lazy "looks good" response.

4. **Quantified verification effort:** The Assessment Summary requires "Claims verified: N out of M key claims independently checked." If the agent finds zero issues, it must explicitly state "No issues found after independent verification of N claims" -- forcing it to quantify how much verification work it actually performed. A claim of "no issues" with "0 out of 12 claims checked" is immediately suspect.

5. **Separate from research context:** The red-team agent runs in its own Agent context, not as a continuation of the research agent's session. It forms its own impressions from reading the findings file, not from shared reasoning.
