---
name: project-spike
description: Explicit Project spike phase. Performs adversarial technical research, writes spike docs under docs/spikes, supports follow-ups, and tracks spike state in progress.txt. Use only when the user explicitly invokes $project-spike.
---

# Project Spike

Use this skill only when explicitly invoked as `$project-spike`. It creates or
updates spike artifacts at `docs/spikes/<topic>.md` and tracks open/resolved spike
entries in `progress.txt`.

## Core Rules

- Read `progress.txt` fresh from disk before acting.
- Require a bootstrapped project. If `progress.txt` is missing, tell the user to
  run `$project` first.
- Run research before red-team review in separate Codex sub-agent contexts.
  Do not silently collapse the research and red-team passes into one local
  context. If sub-agent delegation is unavailable, stop and tell the user the
  spike cannot preserve the required adversarial isolation in this environment.
- Preserve original spike findings during follow-up; append dated follow-up
  entries.
- Ask concise chat questions for user choices; use structured input tools when
  available.
- Do not invoke the next skill automatically. Recommend the next explicit skill.
- Read all referenced spike workflow files before creating or updating an
  artifact; they contain required audit-trail and follow-up rules.

## Workflow

1. Gather the research question and available tooling from the user request or
   ask concise follow-up questions.
2. Read `references/spike-format.md` and generate the topic slug.
3. If `docs/spikes/<slug>.md` exists, enter follow-up mode; otherwise create a
   new spike.
4. Read `references/research-agent.md` for the research pass and
   `references/redteam-agent.md` for the red-team pass.
5. Assemble or update the artifact using `references/spike-format.md`.
6. Update `progress.txt` using `references/progress-format.md`. New spikes are
   `[ ]`; resolved spikes are `[x] ... Resolved: <YYYY-MM-DD>`.

## Reference Files

- `references/spike-format.md`
- `references/research-agent.md`
- `references/redteam-agent.md`
- `references/progress-format.md`

## Completion

Report the spike artifact path, state update, follow-up count if any, and
recommend `$project` for status.
