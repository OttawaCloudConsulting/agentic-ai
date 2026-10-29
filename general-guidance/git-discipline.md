# Git development discipline

This standard defines how teams organise branches, maintain documentation, and validate and deploy infrastructure changes. It applies to Terraform, Terragrunt, Kubernetes, Helm, Kustomize, and Crossplane repositories.

## 1 Branches and changes

`main` is the default branch and represents the approved repository state. All changes reach `main` through a pull request. Use short-lived branches with lowercase letters, numbers, and hyphens; include a ticket ID when one exists.

```text
<type>/<short-description>
<type>/<ticket-id>-<short-description>
```

| Type | Purpose | Example |
| --- | --- | --- |
| `feat` | New capability or infrastructure | `feat/infra-123-private-endpoints` |
| `fix` | Correct existing behaviour | `fix/helm-values-validation` |
| `docs` | Documentation only | `docs/cluster-recovery` |
| `refactor` | Restructure without intended behaviour changes | `refactor/shared-modules` |
| `chore` | Dependencies and maintenance | `chore/update-providers` |
| `ci` | Validation or deployment automation | `ci/add-kustomize-validation` |
| `poc` | Disposable experiments to test theories and concepts | `poc/crossplane-composition-strategy` |

A `poc/` branch is a short-lived proof of concept used to test a theory, explore an approach, or validate a concept. It may be created and discarded without a pull request or merge. If the experiment produces work worth retaining, prepare it for review through the normal pull request, validation, and approval process before merging into `main`. The final squash commit uses the appropriate commit type for the retained change; `poc` is a branch type only.

Urgent fixes use `fix/` and an expedited review; required validation still applies. Do not use permanent environment branches. Represent environments in directories and deployment configuration, and promote changes through pull requests and deployment approvals.

### Pull request and merge rules

- Keep changes focused and independently reviewable. Explain purpose, affected environments, validation, deployment impact, and rollback.
- Update documentation in the same pull request. Require passing checks, at least one independent approval, and resolved review conversations.
- Require designated owner approval for production, security, or destructive infrastructure changes.
- Use squash merges and delete merged branches. Block direct pushes, force pushes, and deletion of `main`.

### Commit messages and pull request descriptions

A commit message describes the change that commit actually contains. A working commit may represent a partial implementation; it must not imply that the complete feature has been implemented, validated, or deployed.

| Record | Purpose | Required detail |
| --- | --- | --- |
| Working branch commit | Explain one development step | Meaningful summary; rationale when needed to understand the step |
| Pull request | Explain and assess the complete proposed change | Purpose, scope, validation, affected environments, operational impact, and applicable deployment and recovery requirements |
| Final squash commit | Preserve the meaning of the merged change | Conventional Commits subject; durable rationale and compatibility information when needed; relevant references |

Working commits must have meaningful descriptions. Conventional Commits formatting is recommended for them, but is enforced only on the final squash commit entering `main`. Working commits do not require a deployment checklist, complete feature validation, or boilerplate body fields. Whether each working commit must independently build or pass tests is a separate repository policy.

### Final squash commit format

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) for structure and [Google's change description guidance](https://google.github.io/eng-practices/review/developer/cl-descriptions.html) for clear summaries and durable reasoning. Google recommends explaining what changed and why; its published guidance does not mandate Conventional Commits. The requirements below are this organisation's policy.

```text
<type>(<optional-scope>): <summary>

<optional explanation of why and the resulting behaviour>

Refs: <ticket or issue reference, when available>
```

- Use a lowercase type and, when provided, a lowercase scope.
- Write a specific, imperative summary, such as `add`, `correct`, `remove`, or `prevent`.
- Limit the complete subject to 72 characters and omit a trailing full stop.
- Put ticket references in footers rather than the subject.
- Require a body when the rationale or compatibility impact cannot be understood from the subject. A subject alone is sufficient for an obvious, low-impact correction.
- Preserve essential context in the message itself; links provide supporting detail and must not be the only explanation.
- Describe the final merged result. Do not retain raw `WIP`, `fixup`, or review-conversation messages as the squash message.

### Commit types and scopes

| Type | Purpose |
| --- | --- |
| `feat` | Introduce a capability or infrastructure behaviour |
| `fix` | Correct faulty behaviour |
| `docs` | Documentation only |
| `refactor` | Restructure without changing intended behaviour |
| `test` | Add or improve tests |
| `ci` | Change validation or deployment pipelines |
| `build` | Change build or packaging configuration |
| `chore` | Routine maintenance and dependency updates |
| `perf` | Improve performance |
| `revert` | Reverse a previous change |

Choose the type by effect. A dependency upgrade that corrects a defect can use `fix`; an incompatible upgrade also needs a breaking-change declaration. Branch type and final commit type need not match exactly. Commit types extend the branch categories listed above; this does not require additional branch prefixes.

Prefer scopes identifying the affected component, such as `network`, `ingress`, `identity`, or `cluster`. Use `terraform`, `helm`, or `crossplane` when those identify the component more clearly. Each repository should document a small scope vocabulary.

### Breaking changes and operational impact

For breaking changes, require both `!` immediately before the subject's colon and a `BREAKING CHANGE:` footer explaining the incompatibility and required consumer action. This is stricter than Conventional Commits, which permits either marker.

```text
feat(network)!: require explicit subnet identifiers

Remove implicit subnet selection so callers control endpoint placement.

Refs: INFRA-124
BREAKING CHANGE: callers must now supply subnet_ids. Set this input
before upgrading the module.
```

Distinguish compatibility changes from deployment risk. Renaming a required Terraform input is breaking; replacing a resource may cause downtime without changing its consumer interface. Record material migration or operational consequences in the squash body when needed to understand the change, and retain detailed rollout, validation, and recovery procedures in the pull request and linked documentation.

For reverts, identify the original commit and explain the reason and any infrastructure recovery steps. Reverting source configuration does not establish that deployed infrastructure has been restored.

### Working and final commit examples

A partial working commit can be a single line:

```text
feat(network): define private endpoint variables
```

The final squash commit describes the completed change:

```text
feat(network): add private endpoints for storage access

Keep storage traffic on the private network to meet the
workload isolation requirement.

Refs: INFRA-123
```

The pull request carries the complete review information, including affected environments, plan review, deployment dependencies, and recovery procedures. Do not mechanically copy its template or working commit list into the final message.

### Commit message governance

- The author maintains a compliant pull request title and an accurate description as the change evolves.
- Automated checks validate pull request title format, allowed types, and subject length before merge. Working commit formatting must not block iteration in the squash workflow.
- Reviewers assess meaning, rationale, operational consequences, and breaking-change declarations; syntax checks cannot establish these.
- The person merging verifies that the actual squash subject and body meet this standard and preserve the approved explanation. A compliant pull request title alone is insufficient if the merge message is changed.
- Apply the same final-message requirements to bot-generated changes.
- Keep credentials, secret values, and unintended sensitive content out of every commit, including working commits and their messages.

## 2 Documentation

Store maintained project documentation in `<project-root>/docs/`. Keep a short root `README.md` as the entry point. Create directories as needed; empty placeholders are unnecessary.

When a repository contains modules or components, use `docs/modules/<module-name>/` and/or `docs/components/<component-name>/` for their documentation. Each module or component directory includes the documentation categories relevant to it. Root-level documentation under `docs/` covers the project as a whole, shared practices, and records spanning multiple modules or components.

```text
<project-root>/
  README.md
  docs/
    README.md
    getting-started.md
    architecture/
    adr/
      0001-project-architecture.md
    development/
    operations/
      deployment.md
      recovery.md
      troubleshooting.md
    reference/
    modules/                         # Include when modules exist
      <module-name>/
        README.md
        getting-started.md
        architecture/
        adr/
          0001-module-design.md
        development/
        operations/
          deployment.md
          recovery.md
          troubleshooting.md
        reference/
    components/                      # Include when components exist
      <component-name>/
        README.md
        getting-started.md
        architecture/
        adr/
          0001-component-design.md
        development/
        operations/
          deployment.md
          recovery.md
          troubleshooting.md
        reference/
```

The module and component trees show the available categories, not mandatory folders. Include only relevant items for each module or component. A repository may use either or both directories.

| Location | Content |
| --- | --- |
| Root `README.md` | Purpose, ownership, repository layout, quick start, and link to `docs/`. |
| `docs/README.md` | Project documentation index, including links to module and component documentation. |
| `docs/modules/<module-name>/` | Documentation specific to a module, with a `README.md` entry point and relevant categories from the tree above. |
| `docs/components/<component-name>/` | Documentation specific to a component, with a `README.md` entry point and relevant categories from the tree above. |

The following categories apply at the project, module, or component level. Place records at the level that owns their subject; use the project level for shared or cross-cutting records.

| Category | Content |
| --- | --- |
| `getting-started.md` | Prerequisites, authentication approach, and first successful local validation for the relevant scope. |
| `architecture/` | Structure, dependencies, environment boundaries, and diagrams. |
| `adr/` — ADR - Architectural Decision Records | Significant architectural decisions, context, alternatives, and consequences. |
| `development/` | Contribution process, tool versions, and local checks. |
| `operations/` | Deployment, promotion, rollback, recovery, and troubleshooting. |
| `reference/` | Configuration, interfaces, and generated reference material. |

### ADR - Architectural Decision Records

Store numbered ADRs in the `adr/` directory at the appropriate level. Project ADRs record high-level decisions or decisions affecting multiple modules or components. Module and component ADRs record decisions local to that module or component. Link related ADRs across levels instead of duplicating their content.

Each ADR should state the decision's status, context, decision, alternatives considered, and consequences. Number ADRs sequentially within each `adr/` directory and use descriptive filenames, such as `0001-private-endpoint-strategy.md`. Preserve accepted ADRs as historical records; supersede them with a new ADR when the decision changes and link the records in both directions.

### Documentation rules

- Use Markdown, lowercase hyphenated filenames, and relative links for repository content.
- Keep project-level records under the root documentation categories and module or component details under their respective documentation directories.
- Link project documentation to module and component entry points, and link local documentation back to shared guidance where relevant.
- Identify generated documentation and its regeneration command.
- Keep operational instructions executable and specific to their scope. Never include credentials, secret values, or sensitive state contents.
- Keep concise entry-point documentation beside reusable modules, charts, or packages when consumers need it there. Link to the maintained documentation under `docs/` and avoid duplicating it. Clearly identify any generated reference material that must remain beside its source.

## 3 CI and CD

Choose one primary CI/CD delivery approach per repository. Use the following locations and options for pipeline configuration and automation. Shared scripts can support any of the delivery approaches.

| Option | Location or responsibility |
| --- | --- |
| GitHub Actions | Store workflows in `.github/workflows/`. |
| Azure Pipelines | Store pipeline configuration and reusable templates in `.azure-pipelines/`. |
| Shared automation | Store repository-owned scripts in `<project-root>/scripts/` so developers can run the same checks locally where supported. |
| Managed CI/CD | Pipeline configuration and execution are managed outside the repository. The process may be abstracted from the code and unavailable to repository searches or agents. |

```text
GitHub Actions                    Azure Pipelines
.github/workflows/                .azure-pipelines/
  validate.yml                      validate.yml
  deploy.yml                        deploy.yml
                                    templates/

Shared automation                 Managed CI/CD
scripts/                          External managed service or platform
  fmt.sh                          Document the integration under
  validate.sh                     docs/operations/
  test.sh
```

The pipeline layouts above are alternatives. A root Azure pipeline entry file is acceptable when required by existing platform conventions; keep reusable templates under `.azure-pipelines/`.

### Managed CI/CD

Use Managed CI/CD when an external service or platform owns the CI/CD process and its implementation is abstracted from the code, repository, and agent searchability. Repository-owned pipeline files or scripts are not required when the managed platform provides those capabilities.

Document the integration under `docs/operations/`, including the service or platform, responsible owner, repository connection, triggers, target environments, approval controls, and where authorised users can find configuration, run status, logs, and deployment or recovery procedures. Identify any checks that can be run locally and those available only through the managed service. Include links or service identifiers where available, without storing credentials or secrets.

The validation and deployment rules below still apply. Record how the managed service satisfies them and identify any controls that cannot be verified from the repository. An absence of searchable pipeline files does not establish that CI/CD is missing, passing, or configured correctly. Agents must distinguish repository evidence from external controls that require verification by an authorised owner.

### Validation and deployment rules

- Run validation on pull requests and again on merged changes.
- Separate read-only validation from deployment permissions. Pin tool versions and external dependencies.
- Prefer short-lived workload identity credentials and grant each job only the permissions it needs.
- Restrict production deployment to approved changes from protected `main` or protected release tags. A pull request must never automatically deploy to shared production infrastructure.
- Serialize deployments sharing infrastructure state or the same deployment target.
- Record source commit, target environment, outcome, and relevant artifacts. Retain plans and rendered output according to their sensitivity.
- Document deployment and recovery procedures under `docs/operations/`.

### Infrastructure and environment boundaries

- Separate reusable components from environment-specific configuration. Make environment and deployment ownership explicit.
- Pin providers, modules, charts, packages, and images to controlled versions or digests. Commit applicable dependency lock files.
- Keep Terraform state, plan files, local caches, and generated secrets out of Git. Store secret references or approved encrypted secret manifests instead of plaintext secrets.
- Document state locations, locking, recovery, and access requirements without exposing secrets.
- Treat resource replacement, deletion, state manipulation, and Crossplane lifecycle changes as explicit review items.

## 4 Technology validation and completion

Run checks for the changed components and their dependants. Formatting and syntax checks alone are insufficient: reviewers must be able to assess intended infrastructure or workload changes.

### Terraform

Validate formatting, configuration, linting, and security. Initialise without backend access where appropriate and generate plans where credentials are permitted. Use remote state and locking, review destructive changes, and apply a plan tied to the approved commit and target.

### Terragrunt

Validate formatting, configuration, affected units, and dependencies, including the appropriate Terraform checks. Respect dependency ordering and serialize operations sharing state.

### Kubernetes

Render manifests and validate schemas, policies, and relevant tests. Deploy the approved rendered configuration through the repository’s chosen delivery mechanism.

### Helm

Lint charts and render templates for supported values. Validate schemas, policies, and environment-specific values. Pin chart versions and dependencies.

### Kustomize

Build each affected overlay and validate schemas and policies. Promote explicit configuration changes between environment directories.

### Crossplane

Render and validate compositions and resources. Check referenced API versions and package compatibility. Pin packages and review deletion, replacement, and external-resource lifecycle behaviour.

For GitOps repositories, CI validates desired state and the GitOps controller performs reconciliation. Document controller ownership and recovery procedures.

## 5 Definition of Ready

The Definition of Ready is a task-specific checklist used before implementation to establish that developers can begin the planned work. Building and resolving this checklist is part of preparation. Its purpose is to expose dependencies early and give developers clear instructions for resolving them themselves.

Readiness checks establish prerequisites; they do not require implementation or completion evidence that belongs in the Definition of Done. Readiness applies to the work about to start: a proof of concept needs enough preparation to run its experiment, while a production change needs the prerequisites appropriate to its scope and risk.

### Build the readiness checklist

1. Define the intended outcome, scope, acceptance criteria, affected modules or components, and first meaningful development step.
2. Inspect the relevant repository documentation, ADRs, tooling configuration, environment requirements, and delivery process. Identify existing decisions and unresolved questions.
3. Turn each prerequisite or uncertainty into an actionable checklist item. State what must be true, how to verify it, and how the developer can resolve it.
4. Order dependent items so developers can work through them. Identify which items block the next step and which are needed only for a later stage.
5. Record the checklist in the work item or a linked Markdown preparation record under `docs/development/`. Use module or component `development/` documentation for local prerequisites, and link shared setup instructions rather than copying them.
6. Have the developers who will perform the work resolve the checklist and record verification evidence. Update it as new dependencies are discovered.

Each item must include a checkbox, an observable pass condition, verification instructions, and a resolution path. For unresolved external dependencies, also record the responsible owner, request or reference, and the step blocked. Evidence can be a configuration reference, approved decision, successful access check, or link to an external record; it must not contain credentials or secret values.

### Readiness checklist template

Adapt this starting checklist to the work. Split broad items into specific checks for each required tool, system, or dependency. Mark irrelevant items as not applicable with a short reason.

- [ ] **Outcome and scope:** The intended result, acceptance criteria, affected components, and exclusions are understood. Verify against the work item; resolve ambiguity with the accountable owner.
- [ ] **Tool decisions:** Required tools and approaches are selected, existing project standards are identified, and significant new architectural decisions are recorded in an ADR. Resolve open choices through a documented comparison or a scoped proof of concept.
- [ ] **Tool availability:** Required versions, plugins, providers, packages, registries, and licences are available. Verify installation and the relevant basic validation command; follow the documented setup or dependency acquisition instructions to resolve failures.
- [ ] **Repository access:** Developers can read the repository, create a working branch, and use the contribution workflow. Verify the required operations; use the documented access request process for missing permissions.
- [ ] **System access:** Required accounts, roles, authentication, network connectivity, and target environments are identified and usable. Verify access with an appropriate read-only check; record the access request route and owner for gaps.
- [ ] **Infrastructure prerequisites:** Required state backends, locking, clusters, namespaces, CRDs, controllers, external services, and configuration inputs are available where relevant. Verify existence and compatibility; identify provisioning instructions and owners for missing dependencies.
- [ ] **Dependency resolution:** Upstream changes, shared modules, APIs, service capacity, quotas, and external team deliverables are identified. Confirm compatible versions, availability, and ordering; give each unresolved dependency an owner and resolution path.
- [ ] **Validation route:** Developers know which local and CI checks apply, where they run, and how to access results. For Managed CI/CD, identify the service and owner and how externally managed checks can be verified.
- [ ] **Safe development environment:** A suitable environment or test strategy exists, including any restrictions on shared resources. Confirm required permissions and safeguards before any operation that changes infrastructure.
- [ ] **Review and delivery dependencies:** Required reviewers, approval routes, deployment ownership, and any scheduling constraints are known. Resolve prerequisites needed for the next stage and record later-stage dependencies explicitly.

### Resolve dependencies and confirm readiness

Developers should resolve items using the linked setup instructions, approved self-service processes, and documented decisions. Where another owner must act, provide a concrete request and verification step so the developer can track the dependency through to resolution. Checklist authors and agents must identify missing access or decisions rather than assume them, and must not mark a dependency resolved solely because a request was submitted.

The work is ready to begin when all prerequisites blocking the planned implementation are verified, irrelevant items are explained, and any later-stage dependencies have an owner and a resolution point before they are needed. Unresolved blockers keep the dependent work unready; independent preparation or a separately scoped experiment may proceed with its own prerequisites satisfied.

Keep the checklist current when scope, tooling, access, or dependencies change. Record the reason and impact of any accepted exception with the responsible owner. An exception does not grant access or replace a required approval.

## 6 Definition of Done

- The pull request explains the change and its operational impact.
- The final squash commit meets the commit message standard and accurately describes the merged result.
- Relevant validation passes and required reviewers approve.
- Documentation reflects the resulting behaviour.
- Deployment and recovery implications are understood.
- The change is merged into `main` and its branch is deleted.

For deployed changes, completion also requires successful deployment verification or an explicitly recorded follow-up owner and action.
