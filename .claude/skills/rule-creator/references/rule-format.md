# Rule Format Patterns

Structural templates extracted from existing rules. Use these as blueprints when generating new rules.

## Infrastructure Best Practices Pattern

Used by: `cdk-best-practices.md`, `terraform-best-practices.md`, `crossplane-v1-best-practices.md`, `crossplane-v2-best-practices.md`, `kubernetes-best-practices.md`.

### Structure

```markdown
# <Technology> Best Practices

> Guidelines for generating correct, safe, and maintainable <technology> code. Prevents <failure modes>.

## <Design Section>

**Bold imperative statement.** Explanation of why. Follow with code example if it adds clarity:

\```yaml
# Good
example: value

# Bad
example: wrong-value
\```

---

## <Architecture Section>

**Bold imperative statement.** Reasoning.

**Bold imperative statement.** Reasoning with specifics.

---

## Security

**Use grant methods / least privilege / encryption.** Specifics.

**Never hardcode secrets.** Use <alternative>. Reference by name or ARN, never by value.

---

## Naming Conventions

**Use `snake_case` / `kebab-case` for all names.** Rationale.

**Name resources by purpose, not type.** Examples:

\```hcl
# Good
resource "type" "primary" { ... }

# Bad
resource "type" "type_primary" { ... }
\```

---

## Testing and Validation

**Required test types:**

- Type 1: description
- Type 2: description

---

## Deployment Safety

**Always run diff/plan before deploy.** Review for destructive changes.

**Use CI/CD pipelines.** Manual applies create inconsistency.

---

## Bad Practices — Never Do These

| Practice | Why It's Dangerous |
| --- | --- |
| Bad practice 1 | Consequence 1 |
| Bad practice 2 | Consequence 2 |

---

## Monitoring and Observability

**Measure everything.** Use native tooling.

---

## Project Hygiene

**One app/config per repository.** Rationale.

**Clean up unused resources.** Rationale.
```

### Key Patterns

- Every section ends with `---` separator
- Bold imperative lead sentence, then explanation
- Code blocks use `# Good` / `# Bad` comments for contrast
- Bad Practices table uses `| --- | --- |` alignment
- 8-15 sections typical for infrastructure rules
- 150-300 lines typical length

## Behavioral/Process Rule Pattern

Used by: `defensive-protocol-v2-anti-slop.md`, `defensive-protocol-v2-epistemology.md`, `defensive-protocol-v2-session-management.md`.

### Structure

```markdown
# <Protocol Name>

> One-sentence purpose. Scope statement.

## Core Principle

**Bold thesis statement.** Brief elaboration.

---

## <Protocol Section>

When <trigger condition>:

1. **Step 1** — action
2. **Step 2** — action
3. **Step 3** — action

\```
STRUCTURED TEMPLATE:
- Field: [value]
- Field: [value]
\```

Rationale sentence. Anti-pattern warning.

---

## <Boundary Section>

**Condition list or checklist:**

\```
CHECK:
- Question 1? [yes/no]
- Question 2? [low/medium/high]
\```

**Trigger conditions:**

- Condition 1
- Condition 2

---

## Claude-Specific Guidance

Your failure mode: <specific failure pattern>.

**Counter this by:**

- Counter 1
- Counter 2

---

## Summary

**Bold one-line summary.** Memorable closing phrase.
```

### Key Patterns

- Shorter than infrastructure rules (60-120 lines typical)
- Structured templates in fenced code blocks (not YAML — plain text)
- Numbered protocols for sequential steps
- Checklists for decision points
- One Core Principle section always present
- Summary section always present
- Claude-Specific Guidance section recommended

## Common Elements

### Title and Description

```markdown
# Rule Title

> One-sentence description. Scope and failure modes it prevents.
```

The blockquote is always a single line. It states what the rule does and what it prevents.

### Section Separators

Every H2 section ends with a horizontal rule (`---`). The last section may omit it.

### Code Examples

Use the language of the technology being described:

- Terraform: `hcl`
- CDK: language-appropriate (`typescript`, `python`)
- Kubernetes/Crossplane: `yaml`
- Bash: `bash`
- Behavioral templates: plain fenced blocks (no language tag)

### Bold Lead Pattern

Every guideline within a section starts with a **bold imperative sentence**, followed by explanation. This creates scannable structure:

```markdown
**Set explicit removal policies.** CDK defaults to `RETAIN` for stateful resources...

**Use generated names, not physical names.** Hardcoded names prevent...
```

### Bad Practices Table

Infrastructure rules include a "Bad Practices — Never Do These" section near the end:

```markdown
## Bad Practices — Never Do These

| Practice | Why It's Dangerous |
| --- | --- |
| Practice description | Consequence description |
```

Behavioral rules typically omit this table, using inline anti-patterns instead.

## File Naming

- `kebab-case` for all rule filenames
- Infrastructure: `<technology>-best-practices.md`
- Behavioral: `<protocol-name>.md`
- Versioned: `<name>-v2-<aspect>.md`
