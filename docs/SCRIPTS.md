# Scripts Reference

Scripts are repo tooling bundles — shell scripts and supporting assets that perform automated workflows. Unlike commands and skills, scripts are not drop-in Claude Code content; they are copied into a repository's `scripts/` directory and invoked directly from the shell.

For Claude Code commands (slash-command markdown files), see [COMMANDS.md](COMMANDS.md).
For Claude Code skills (SKILL.md bundles), see [SKILLS.md](SKILLS.md).

## Quick Reference

| Script Bundle | Purpose | Details |
|---|---|---|
| Benchmark | Measure whether a skill produces better output than a baseline or previous version; issue a scored promotion verdict | [View](scripts/benchmark/README.md) |

## How Scripts Work

- Script bundles live in `scripts/<name>/` at the repository root
- Consumers copy the entire bundle to `scripts/<name>/` in their target repository
- Each bundle contains shell scripts plus a `README.md` entry point
- Scripts are invoked directly with an explicit interpreter — never via `./` or executable bit:

```bash
bash scripts/<name>/<script>.sh [flags]
```

### Bundle Structure

```
scripts/<name>/
├── README.md          ← entry point: quick start, modes, link to docs/
├── *.sh               ← shell scripts (portable, bash 4+)
└── docs/              ← detailed documentation (setup, lifecycle, reference, rubric)
    ├── README.md
    ├── SETUP.md
    ├── LIFECYCLE-GUIDE.md
    ├── USER-GUIDE.md
    ├── REFERENCE.md
    └── RUBRIC-GUIDE.md
```

## Benchmark

Validates and compares Claude Code skills using a scored rubric. Runs a skill definition against three standardised test briefs, scores outputs across seven dimensions (max 63 points), and produces a `decision.md` with a threshold-based verdict.

**Scripts:** `run-benchmark.sh`, `run-variance.sh`
**Documentation:** [scripts/benchmark/README.md](scripts/benchmark/README.md)

### Modes at a Glance

| Mode | Use when |
|------|----------|
| Baseline | New skill — does it improve on the unguided model? |
| Git main comparison | Revised skill on a branch — compare against the last committed version |
| Champion vs. Challenger | Compare any two explicit skill files |

### Verdicts at a Glance

| Verdict | Meaning |
|---------|---------|
| `PROMOTE` | Skill clears the threshold above the unguided baseline |
| `NO VALUE` | No measurable improvement over the unguided model |
| `REJECT` | Unguided model outperforms the skill |
| `SWITCH RECOMMENDED` | Challenger meaningfully beats the current version |
| `NO CHANGE` | Delta below threshold — insufficient evidence to switch |
| `CHAMPION CONFIRMED` | Current version outperforms the challenger |

For full documentation — setup, lifecycle, flags, scoring, and rubric customisation — see [docs/scripts/benchmark/](scripts/benchmark/).
