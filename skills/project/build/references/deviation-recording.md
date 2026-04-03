# Architectural Deviation Recording Specification

Detection and recording of architectural deviations during feature
implementation. An executor reading only this file can handle the complete
deviation flow -- from detection through confirmation to structured recording.

## What Constitutes a Deviation (D-11)

A deviation occurs when the implementation **contradicts** what the feature plan
or `docs/ARCHITECTURE_AND_DESIGN.md` specifies.

### A deviation IS:

- Using a fundamentally different approach than the plan specified (e.g., session
  cookies instead of JWT when the plan specified JWT)
- Skipping a component the plan said to create
- Adding a component the plan said was unnecessary
- Changing the data model or interface contracts from what the plan specified
- Using a different library or framework than the architecture doc selected

### A deviation is NOT:

- Adding implementation detail the plan did not specify (plans describe intent,
  not exact code)
- Using a slightly different API or method name than implied by the plan
- Making reasonable implementation choices within the plan's described approach
- Choosing a specific algorithm when the plan said "implement sorting" without
  specifying which algorithm
- Adding error handling or validation beyond what the plan listed

**Key distinction:** Plans and architecture docs describe *what* and *why*. The
implementation decides *how*. Deviations are when the *what* changes, not when
the *how* is more specific than the plan anticipated.

## Detection and Confirmation Flow (D-11)

When Claude detects a deviation during sub-feature implementation:

### 1. Pause Implementation

Stop writing code at the point where the deviation is detected. Do not continue
implementing the deviating approach without confirmation.

### 2. Present to User

Explain what was detected:

> "This deviates from the plan because X. Record as deviation?"

Be specific about:
- What the plan or architecture doc specified
- What the implementation is doing instead
- Why the change appears necessary

### 3. User Decision

Use `AskUserQuestion` with two options:

- **Record** -- confirm the deviation and write it to the feature plan
- **Dismiss** -- not a real deviation; continue implementation without recording

### 4. Handle Response

**If Record:** Write the structured deviation entry (see below), then continue
implementation with the deviating approach.

**If Dismiss:** Continue implementation without recording. The user has judged
that this is within the plan's intent, not a contradiction.

## Structured 4-Field Entry (D-12)

Each confirmed deviation is written to the feature plan's `## Architectural
Deviations` section in this exact format:

```markdown
### Deviation N: <brief title>
- **What changed:** <what the implementation actually does>
- **Originally planned:** <what the plan or architecture doc specified>
- **Why necessary:** <why the change was required>
- **Impact:** <effect on other components or future work>
```

### Numbering

The deviation number auto-increments from existing entries in the section:

- If the section currently contains `(none)`, replace `(none)` with the first
  deviation entry as `### Deviation 1: ...`
- If existing deviations are present, increment from the highest existing number
  (e.g., if Deviation 2 exists, the next is Deviation 3)

### Field Guidance

- **What changed:** Describe the actual implementation approach. Be concrete --
  reference specific files, functions, or patterns used.
- **Originally planned:** Quote or reference the specific section of the feature
  plan or architecture doc that specified the original approach.
- **Why necessary:** Explain the technical or practical reason the original
  approach could not be followed. This is the most important field for `/design`
  refresh mode.
- **Impact:** Identify which other components, features, or future work is
  affected by this change. Include both immediate effects (broken interfaces,
  changed data shapes) and downstream effects (future features that assumed the
  original approach).

## Immediate Write (D-13)

Write the deviation entry to the feature plan using the Edit tool **as soon as
the user confirms it**. Do not batch deviations for later writing.

The deviation gets committed with the sub-feature that caused it. This ensures:

- Deviations are never lost, even if the session ends unexpectedly
- The git history shows exactly when each deviation was introduced
- The feature plan on disk always reflects the current state of implementation

### Write Mechanics

Use the Edit tool to append the deviation entry to the `## Architectural
Deviations` section of the feature plan file.

**First deviation (replacing `(none)`):**

Old:
```markdown
## Architectural Deviations

(none)
```

New:
```markdown
## Architectural Deviations

### Deviation 1: Switched from JWT to session cookies
- **What changed:** Authentication uses server-side sessions with cookies
- **Originally planned:** JWT-based authentication per ARCHITECTURE_AND_DESIGN.md DD-3
- **Why necessary:** JWT refresh rotation added significant complexity
- **Impact:** Session storage requires server-side state; affects scaling strategy
```

**Subsequent deviations:** Append after the last existing deviation entry.

## Deviation Accumulation Warning

After writing a deviation, check the total count of deviations for the current
feature. If the feature has accumulated **3 or more deviations**, add a note
to the user:

> "Multiple deviations detected (N total). Consider running /design in refresh
> mode after this feature completes to consolidate architectural changes."

This is informational only -- it does not block implementation. The threshold of
3 indicates the architecture doc may be significantly out of date and would
benefit from a refresh to incorporate the deviations.
