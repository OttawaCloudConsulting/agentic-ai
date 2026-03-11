# Benchmark: create-prd

**Date**: 2026-03-06
**Skill version**: unversioned
**Evaluator**: Claude (automated benchmark)

---

## Mode 1 — Static Quality Analysis

### Rubric A: Internal Quality Standards

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Conciseness | 4 | SKILL.md is 163 lines — well under the 500-line limit. Language is imperative throughout. A few verbose passages exist (e.g., the Step 4 cross-reference checklist could be tightened), but no bloat or redundancy. The `interview-guide.md` reference is correctly used to offload question banks rather than inlining them. |
| Degrees of Freedom | 4 | High-freedom decisions (terminology, section ordering, which rounds apply) are left open with language like "Adapt to the project" and "Omit sections that are irrelevant." Low-freedom operations (overwrite check, cross-reference verification, feature numbering scheme) are locked down with specific rules. The progress.txt numbering scheme (lines 126–128) is prescriptive where consistency is critical. Slight gap: Step 3 architecture interview areas are listed in SKILL.md rather than delegating fully to the reference — partially redundant with `interview-guide.md`. |
| Progressive Disclosure | 4 | Frontmatter is lean (~100 words). SKILL.md body is 163 lines. Reference files are correctly offloaded: `interview-guide.md` for question banks, template files in `assets/`. Each reference is cited with explicit "when to read" guidance (e.g., "Read `references/interview-guide.md` for the full question bank" before Step 2). Minor issue: Step 3 lists architecture interview areas in SKILL.md body (lines 73–82) that overlap with content in `interview-guide.md`, creating partial duplication between tiers. |
| Structure | 5 | Clear sequential workflow (Steps 1–7). Each step has a defined input, action, and output. Rules section at top with critical constraints. Error handling at bottom. Sections are organized in execution order. Imperative/infinitive form used consistently throughout. The final summary template (lines 137–150) is a concrete, scannable artifact. |
| Resource Appropriateness | 5 | `assets/` correctly holds output templates (`prd-template.md`, `architecture-template.md`, `progress-template.txt`) — files used in output, not loaded into context. `references/interview-guide.md` correctly holds the question bank loaded on demand during Steps 2 and 3. No scripts directory (appropriate — no deterministic/repeatable code logic needed). No forbidden files (README.md, CHANGELOG.md, etc.). |

**Rubric A Score**: 4.4 / 5.0

### Rubric B: Anthropic Best Practices

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Naming | 5 | Folder name `create-prd` is kebab-case, lowercase, no spaces or underscores. `name` field in frontmatter matches folder name exactly. `SKILL.md` is correctly cased. No reserved prefixes (`claude`, `anthropic`) used. |
| Frontmatter | 5 | Both required fields (`name`, `description`) are present. `disable-model-invocation: true` is explicitly set, appropriate for an interactive multi-step interview skill. No XML angle brackets in description. Description is under 1024 characters (~220 chars). YAML delimiters are correctly formed. |
| Trigger Quality | 3 | Description includes what the skill does and several trigger scenarios ("starting a new project, planning a new feature, writing requirements, scoping a project, or creating project documentation from scratch"). However, no negative triggers are present — the description does not clarify that this skill is NOT for updating an existing PRD, not for architecture-only work, and not for implementation. With `disable-model-invocation: true`, auto-triggering is off, which mitigates false-positive risk, but the description alone would be ambiguous when a user is choosing between commands. Also missing specific user-facing phrases (e.g., "I want to plan a new project," "help me write requirements") that would make the trigger more recognizable. |
| Instruction Quality | 5 | Instructions are specific and actionable throughout. Each step names the exact tool to use (`AskUserQuestion`, `Write`, `Edit`, `Bash`), the exact file to read or write, and what to verify after. Verification steps are explicit: "Read the file back and confirm Summary, Goals, and Features sections are populated" (line 42). Critical rules are at the top in a `## Rules` section. Quality bars are called out explicitly (lines 63–64, 84–85). No guesswork required for model execution. |
| Error Handling | 4 | Four failure modes covered: interrupted interview, vague/contradictory answers, project does not fit templates, user wants to skip a round. Each has a specific, actionable response. Missing: handling for asset template files not found (no fallback if `assets/prd-template.md` is missing), and no coverage of tool failures (e.g., Write tool failure when creating output files). |

**Rubric B Score**: 4.4 / 5.0

### Overall Quality Score: 4.4 / 5.0

### Key Findings

- **Strengths**: The step-by-step workflow is exceptionally clear and complete. Resource placement (assets vs. references) is correct. Instruction actionability is high — every step names the exact tool, file, and verification step. Error handling covers the most likely failure modes.
- **Strength**: The progressive disclosure model is implemented correctly: frontmatter is lean, body is well under 500 lines, and reference/asset files are loaded on demand with explicit guidance.
- **Gap**: Description lacks negative triggers. A user seeing `/create-prd` listed alongside other commands cannot easily tell it should NOT be used for updating an existing PRD or for standalone architecture review. Given `disable-model-invocation: true`, this is a usability gap rather than a triggering defect.
- **Gap**: Step 3 in SKILL.md lists the architecture interview areas (lines 73–82) that also exist in `interview-guide.md`. This creates content duplication between SKILL.md and a reference file — a violation of the "information lives in either SKILL.md or references, not both" principle.
- **Minor gap**: No fallback documented if template files in `assets/` are absent. A consuming project that omits the assets directory would fail silently at Step 1.

---

## Mode 2 — Trigger Accuracy Testing

Note: `disable-model-invocation: true` means the skill is always invoked explicitly (e.g., `/create-prd`). Trigger testing here evaluates whether the description is clear enough for a user to understand when to use the skill, and whether a model asked to route between skills would correctly identify this one.

### Test Cases

| # | Prompt | Expected | Predicted | Match | Reasoning |
|---|---|---|---|---|---|
| 1 | "I need to plan a new project from scratch — where do I start?" | TRIGGER | TRIGGER | YES | Matches "starting a new project" trigger condition. |
| 2 | "Help me write requirements for a new microservice we're building" | TRIGGER | TRIGGER | YES | Matches "writing requirements" and "planning a new feature." |
| 3 | "I want to scope out a feature before we start coding" | TRIGGER | TRIGGER | YES | Matches "scoping a project" trigger phrase directly. |
| 4 | "Create a PRD for the authentication module" | TRIGGER | TRIGGER | YES | Explicit PRD creation request matches skill name and description. |
| 5 | "We're starting a new mobile app — help me create project documentation" | TRIGGER | TRIGGER | YES | Matches "creating project documentation from scratch." |
| 6 | "I need to write the architecture and design doc for a new service" | TRIGGER | TRIGGER | YES | Covered by "creating project documentation from scratch" and producing architecture artifacts. |
| 7 | "Let's plan out the features for a new data pipeline" | TRIGGER | TRIGGER | YES | "Planning a new feature" and project scoping covered. |
| 8 | "Help me define acceptance criteria for a new project" | TRIGGER | TRIGGER | YES | PRD creation includes acceptance criteria per feature — new project context clear. |
| 9 | "I want to create a progress tracker for a project I'm about to start" | TRIGGER | TRIGGER | YES | Skill produces progress.txt; "project documentation from scratch" covers this. |
| 10 | "We're spinning up a new API — can you help me think through the design and requirements?" | TRIGGER | TRIGGER | YES | Combines requirements writing and design documentation for a new project. |
| 11 | "Update the PRD to add the new caching feature we discussed" | SUPPRESS | TRIGGER | NO | Description says "creating project documentation from scratch" but does not explicitly exclude updates; a model might still route here. Negative trigger is absent. |
| 12 | "Review my existing architecture document and suggest improvements" | SUPPRESS | SUPPRESS | YES | "Architecture review" with no new project context is not covered by description. |
| 13 | "Start implementing Feature 3 from the PRD" | SUPPRESS | SUPPRESS | YES | Implementation request; description and skill rules explicitly exclude implementation. |
| 14 | "Help me write a technical design doc for a change to an existing system" | SUPPRESS | TRIGGER | NO | "Creating project documentation" is broad enough that a routing model could match this even though it involves an existing system, not a new project. |
| 15 | "Write unit tests for the payment module" | SUPPRESS | SUPPRESS | YES | Implementation/testing task; clearly outside PRD creation scope. |
| 16 | "Refactor the architecture document to split the component section" | SUPPRESS | SUPPRESS | YES | Editing existing doc, not creating from scratch — description's "from scratch" qualifier suppresses this. |
| 17 | "Create a README for this project" | SUPPRESS | SUPPRESS | YES | General documentation task not matching PRD/architecture/progress artifacts. |
| 18 | "I need a risk assessment for the current production system" | SUPPRESS | SUPPRESS | YES | Operational review of existing system, not new project planning. |
| 19 | "Generate a changelog for the last sprint" | SUPPRESS | SUPPRESS | YES | Changelog generation is unrelated to PRD creation. |
| 20 | "Help me break down an existing PRD into implementation tasks" | SUPPRESS | SUPPRESS | YES | Task breakdown from existing doc; "from scratch" qualifier and no new-project context disambiguate. |

### Accuracy Metrics

| Metric | Value |
|---|---|
| True Positive Rate | 10/10 (100%) |
| True Negative Rate | 8/10 (80%) |
| Overall Accuracy | 18/20 (90%) |

### Trigger Analysis

The description performs well for true positive cases — all ten new-project scenarios are correctly identified. The two false positives (tests 11 and 14) both involve modifications to or documentation for existing systems, and both would be suppressed if the description included a negative trigger such as "Do NOT use for updating an existing PRD or for documenting changes to a system already in production." With `disable-model-invocation: true`, these false positives only matter when a user or routing model is choosing between commands — not during auto-triggering. The phrase "from scratch" does some disambiguation work but is insufficient for the update-PRD case (test 11), which is the most likely source of user confusion.

---

## Summary

| Dimension | Score |
|---|---|
| Static Quality (Rubric A) | 4.4/5 |
| Static Quality (Rubric B) | 4.4/5 |
| Trigger Accuracy | 90% (18/20) |

**Benchmark verdict**: `create-prd` is a high-quality, well-structured skill with clear instructions, correct resource placement, and solid error handling. Its primary improvement opportunity is adding negative triggers to the description to disambiguate it from PRD-update and existing-system documentation tasks, and eliminating the partial content duplication between Step 3 in SKILL.md and `interview-guide.md`.
