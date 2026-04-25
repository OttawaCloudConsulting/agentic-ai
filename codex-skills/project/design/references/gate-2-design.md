# Gate 2: Design Review

Produces `docs/ARCHITECTURE_AND_DESIGN.md` from an approved PRD and optional codebase assessment. This reference contains the complete Gate 2 specification -- an executor reading only this file can run the full Gate 2 normal-mode flow.

## Input Loading (DES-02, D-07)

Read the primary inputs from disk:

1. **Read `prd.md`** from the project root. This is required -- if it does not exist, report the error and stop.
2. **Read `docs/codebase-assessment.md`** if it exists. This is optional -- it may not exist for greenfield projects. If missing, proceed without it.

Both files are primary inputs per D-07. The PRD provides goals, non-goals, scope, risks, and milestone intent. The codebase assessment (when present) provides existing patterns, architecture, and constraints.

## Architecture Agent Scan (D-05, D-06)

Spawn a sub-agent using Codex sub-agent delegation to perform a deep architecture-focused codebase scan. The agent reads 15-30 files and writes structured findings to a temporary scratch file.

**Always spawn the architecture agent, even for greenfield projects** (D-06). For greenfield projects with minimal files, the agent scans whatever exists (configs, dependencies, boilerplate). The synthesis step leans primarily on PRD goals, non-goals, and risk assessment to propose architecture. For greenfield projects, the architecture is driven by the PRD. The agent scan provides whatever context exists.

### Sub-Agent Prompt

Instruct the agent to:

1. **Survey the project structure:**
   - Run `ls -R` (first 2 levels) for directory overview
   - Run `git log --oneline -20` for recent change patterns

2. **Select 15-30 files to read using architecture-focused heuristics:**
   - **Component Boundaries:** module entry points, barrel files, index files, package manifests for sub-packages
   - **Data Flow Patterns:** API routes, event handlers, middleware, database access layers, message queue consumers/producers
   - **Interface Contracts:** type definition files, API schemas, shared types, protocol buffers, OpenAPI specs
   - **Technology Choices:** config files (tsconfig, webpack, vite, etc.), dependency manifests (package.json, Cargo.toml, go.mod), build configs
   - **Infrastructure:** deployment configs, CI/CD pipelines, Dockerfiles, infrastructure-as-code files

   These heuristics are architecture-focused -- they look at structure and decisions, not coding conventions. This is distinct from Gate 0's convention-focused scan.

3. **Read each selected file** using the Codex file reads.

4. **Write structured findings** to `/tmp/architecture-scan-findings.md` with these sections:
   - **Component Boundaries** -- identified modules, their entry points, how they are organized
   - **Data Flow Patterns** -- how data moves between components, API boundaries, event flows
   - **Interface Contracts** -- shared types, API shapes, contracts between modules
   - **Technology Choices** -- languages, frameworks, libraries, and their configuration
   - **Configuration Patterns** -- how the system is configured, environment variables, config files

### Sub-Agent Tool Access

The agent uses only: Codex file reads, Codex shell commands (for `ls`, `git log`), and file globbing tools.

### Greenfield Handling

For greenfield projects, the agent may find very few files (perhaps only README, .gitignore, a config file, and a dependency manifest). This is expected. The agent should:
- Scan whatever files exist
- Note the absence of application code
- Report on technology choices visible from config/dependency files
- Report the project as greenfield in the findings

The synthesis step compensates by drawing architecture decisions primarily from the PRD.

## Architecture Document Production (DES-03, D-04)

Synthesize the agent's findings and the PRD into `docs/ARCHITECTURE_AND_DESIGN.md`:

1. Read the agent's scratch file (`/tmp/architecture-scan-findings.md`)
2. Read `assets/architecture-template.md` for the document structure
3. Create the `docs/` directory if it does not exist: `mkdir -p docs`
4. **Check whether `docs/ARCHITECTURE_AND_DESIGN.md` already exists on disk.**

### If the file does NOT exist (new document)

Write `docs/ARCHITECTURE_AND_DESIGN.md` from scratch using the template, populating each of the 6 required sections listed below.

### If the file DOES exist (integrate into existing)

The existing document is authoritative. Read it in full before making any changes. Integrate new content into it rather than replacing it:

- **Preserve all existing content** as the baseline. Existing design decisions, components, flows, and other entries represent prior architectural context that must not be lost.
- **Add new entries** for anything the PRD and agent scan findings indicate that is not already captured. For example, add new rows to the Design Decisions table, new components to the Component Inventory, new flows to the Data Flow section.
- **Do not remove or overwrite** existing entries unless they directly contradict the current PRD. If a contradiction is found, note it as a tradeoff callout for the user to resolve during review.
- **Reorganize if needed.** If the existing document uses a different structure than the template's 6 sections, reorganize it to match the template while preserving all original content.
- **Use the Codex editing tools** (not Write) for all updates so the existing file content is the base.
- **Inform the user** after integration: "An existing architecture document was found. New content from this feature's PRD has been integrated. Please review carefully to ensure consistency between prior and new content."

### Required Sections

The following 6 sections must be present and populated in the final document. When integrating into an existing document, these describe what content should be PRESENT -- verify each section exists and is complete, add missing content, but do not replace existing content that is still valid.

   - **Design Decisions** -- numbered table with columns: #, Decision, Rationale, Tradeoff, Alternatives Considered. Capture the key technical choices: framework selection, architecture pattern, data storage, API design, deployment strategy, etc.
   - **Component Inventory** -- table with columns: Component, Responsibility, Interfaces. List every major module/service/package with its role and how it connects to other components.
   - **Data Flow** -- description of how data moves through the system. Include step-by-step flows for key operations (e.g., request handling, data processing pipelines, event propagation).
   - **File Organization** -- target directory structure with annotations for key directories and files.
   - **Deployment & Operations** -- how the system is deployed, monitored, and operated. CI/CD pipeline, environments, observability, scaling considerations.
   - **Security Considerations** -- authentication, authorization, access control, data handling, secrets management.

5. Clean up the scratch file after synthesis: `rm /tmp/architecture-scan-findings.md`

For greenfield projects: lean heavily on the PRD (goals, non-goals, risk assessment) to propose architecture. The Design Decisions section captures proposed choices with rationale. Other sections describe the intended architecture rather than the existing one.

## Tradeoff Callouts (D-09)

After producing the full architecture document, identify 2-4 design decisions with the most significant tradeoffs. Present these to the user before the approval checklist.

**Heuristic for detecting key tradeoffs:**

1. The alternatives are genuinely viable -- not strawman options
2. The tradeoff affects multiple components or long-term evolution of the system
3. Reversal would be expensive (significant rework, data migration, etc.)

Cap at 2-4 callouts to avoid decision fatigue. For each callout, present:
- The decision and chosen approach
- The primary tradeoff (what is gained vs. what is given up)
- The most viable alternative and why it was not chosen

## Review Phase (DES-05, DES-06, D-08, D-10)

Present the architecture document for user review using the produce-then-review cycle:

1. **Present a summary** of the full architecture document. Highlight:
   - Key design decisions and their rationale
   - Component inventory overview
   - Data flow summary
   - Security approach

2. **Present tradeoff callouts** (2-4 key decisions identified above).

3. **Gate 2 review framing** (DD-8): "Here are the technical choices, tradeoffs, component inventory, data flow, and security considerations. Do these align with your constraints? Is anything missing?"

4. **Use a concise user question** with options:
   - **Approve** -- architecture is sound, proceed to checklist validation
   - **Revise** -- architecture needs changes
   - **Partial** -- some sections approved, others need revision

5. **If Partial (D-08):** Present a multiSelect checklist of the 6 architecture sections:
   - [ ] Design Decisions
   - [ ] Component Inventory
   - [ ] Data Flow
   - [ ] File Organization
   - [ ] Deployment & Operations
   - [ ] Security Considerations

   The user checks the sections they approve. For each unchecked section, ask: "What should change in [Section Name]?" Apply the requested changes using the Codex editing tools. Re-present the updated sections for confirmation. Repeat until all sections are approved or the user does a full Approve.

6. **If Revise:** Ask what needs changing. Apply edits to `docs/ARCHITECTURE_AND_DESIGN.md`. Re-present the updated summary. Repeat until the user selects Approve.

7. **If Approve:** Proceed to Checklist Validation.

## Checklist Validation (DES-04, D-11)

Generate and validate the review checklist:

1. Create `docs/reviews/` directory if needed: `mkdir -p docs/reviews`

2. Generate `docs/reviews/gate-2-review.md` using `references/review-checklist-template.md`. Start with the file header:

   ```
   # Gate 2 Review -- Design Review

   **Artifact:** docs/ARCHITECTURE_AND_DESIGN.md
   **Status:** [ ] Pending
   **Reviewer(s):**
   **Date:**
   ```

3. Include the Gate 2 static checklist items:
   - `[ ] Are the design decisions sound? Are tradeoffs acceptable?`
   - `[ ] Is the component inventory complete?`
   - `[ ] Does the data flow match your understanding of the system?`
   - `[ ] Are there security considerations missing?`

4. Add content-specific `[Auto]` items based on actual architecture doc content. Examples:
   - `[ ] [Auto] Verify decision: "{specific decision from Design Decisions table}"`
   - `[ ] [Auto] Confirm component: "{component name}" interfaces are complete`
   - `[ ] [Auto] Review data flow: "{specific flow}" covers error cases`
   - `[ ] [Auto] Validate security: "{specific security measure}" is sufficient`

5. **Codex pre-checks** items it can verify programmatically:
   - File `docs/ARCHITECTURE_AND_DESIGN.md` exists
   - All 6 required sections are present
   - Design Decisions table has at least one entry
   - Component Inventory table has at least one entry

6. **Present remaining unchecked items** to the user for resolution.

7. **All items must be `[x]` (verified) or `[-]` (N/A with reason)** before proceeding. No item may remain as `[ ]`.

8. Update the checklist `**Status:**` to `[x] Approved` with the current date.

## Gate Approval (DES-07)

Record the gate approval in progress.txt:

1. Read `references/progress-format.md` for the exact gate entry format.

2. Update the Gate 2 line in `progress.txt` from:
   ```
   [ ] Gate 2: Design Review
   ```
   to:
   ```
   [x] Gate 2: Design Review  Approved: <YYYY-MM-DD>  docs/ARCHITECTURE_AND_DESIGN.md
   ```
   where `<YYYY-MM-DD>` is the current date.

3. Only `progress.txt` is updated at this step -- no other state files are modified.
