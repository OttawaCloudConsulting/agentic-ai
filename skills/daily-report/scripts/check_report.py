#!/usr/bin/env python3
"""Check a daily report before filing it.

Catches the mechanical failures this skill is prone to: missing or
out-of-order sections, a Date field disagreeing with the filename,
malformed commit lines, em-dashes, emojis, a missing WorkItems entry, and
workspace-local planning identifiers surviving into prose.

Usage:
    python3 skills/daily-report/scripts/check_report.py DailyReports/20260827.txt
"""

import re
import sys
from pathlib import Path

SECTIONS = ["Today:", "Commits:", "WorkItems:", "Tomorrow:"]

# Identifiers that resolve only against .project/. Prose only: the Commits
# section is verbatim and real commit subjects contain SF-N.
VERNACULAR = [
    (r"\bM0\d\b", "milestone number"),
    (r"\bMilestone \d+", "milestone number"),
    (r"\bFeature \d+\.\d+", "feature number"),
    (r"\bfeature \d+\.\d+", "feature number"),
    (r"\bGate \d", "gate number"),
    (r"\bSF-\d", "sub-feature marker"),
    (r"\bFL-\d", "local finding reference"),
    (r"\bEC-\d", "local edge-case reference"),
]

EM_DASH = re.compile(r"[—–]")
EMOJI = re.compile(
    "[\U0001F300-\U0001FAFF\U00002600-\U000027BF\U0001F1E6-\U0001F1FF⬀-⯿]"
)
COMMIT_LINE = re.compile(r"^- \S+ \| [0-9a-f]{7,40} \| .+")
WORKITEM_LINE = re.compile(r"^- [A-Z][A-Z0-9]+-\d+\s*$")


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    path = Path(sys.argv[1])
    if not path.exists():
        print(f"ERROR: {path} does not exist")
        return 1

    lines = path.read_text().splitlines()
    errors: list[str] = []
    warnings: list[str] = []

    # Filename and Date field.
    if not re.fullmatch(r"\d{8}", path.stem):
        errors.append(f"filename {path.name} is not YYYYMMDD.txt")
    if not lines or not lines[0].startswith("Date: "):
        errors.append("first line is not 'Date: YYYY-MM-DD'")
    else:
        stated = lines[0][len("Date: "):].strip()
        if re.fullmatch(r"\d{8}", path.stem) and stated.replace("-", "") != path.stem:
            errors.append(f"Date field {stated} disagrees with filename {path.name}")

    # Sections present and in order.
    positions = {}
    for i, line in enumerate(lines):
        if line.strip() in SECTIONS and line.strip() not in positions:
            positions[line.strip()] = i
    for section in SECTIONS:
        if section not in positions:
            errors.append(f"missing section '{section}'")
    ordered = [positions[s] for s in SECTIONS if s in positions]
    if ordered != sorted(ordered):
        errors.append("sections are out of order; expected Today, Commits, WorkItems, Tomorrow")

    def body(section: str) -> list[tuple[int, str]]:
        if section not in positions:
            return []
        start = positions[section] + 1
        later = [p for p in positions.values() if p > positions[section]]
        end = min(later) if later else len(lines)
        return [(i + 1, lines[i]) for i in range(start, end) if lines[i].strip()]

    today = body("Today:")
    commits = body("Commits:")
    workitems = body("WorkItems:")
    tomorrow = body("Tomorrow:")

    if not today:
        errors.append("Today section is empty")
    if not tomorrow:
        warnings.append("Tomorrow section is empty; a work day normally owes a next step")

    # Length. Warnings, not errors: a genuinely dense day can justify going
    # over, but it has to be a decision rather than an accident. The bullet
    # ceiling is set above the 60-to-70 words a described defect needs.
    today_words = sum(len(t.split()) for _, t in today)
    if today_words > 220:
        warnings.append(
            f"Today is {today_words} words against a 150 to 200 target; "
            "check for line counts, proof apparatus or review history"
        )
    for n, t in today:
        if t.startswith("- ") and len(t.split()) > 65:
            warnings.append(
                f"line {n}: bullet is {len(t.split())} words against 20 to 30; "
                "only a defect being described should run this long"
            )

    # Commits: either commit lines, or a stated reason for zero.
    if not commits:
        errors.append("Commits section is blank; state 'none' and why instead")
    else:
        # A bullet is either a commit line or an explanation (a zero-commit day,
        # a commit that landed later, work that produced no commit). Only a
        # bullet shaped like a commit line and getting it wrong is an error.
        malformed = [
            (n, t) for n, t in commits
            if t.startswith("- ") and " | " in t and not COMMIT_LINE.match(t)
        ]
        for n, t in malformed:
            errors.append(f"line {n}: commit line is not '- repo | sha | subject': {t.strip()!r}")
        if not any(COMMIT_LINE.match(t) for _, t in commits) and not re.search(
            r"\b(none|no commits)\b", " ".join(t for _, t in commits), re.I
        ):
            errors.append("Commits has no commit lines and no stated reason for zero")

    # WorkItems: at least one tracker ID.
    if workitems and not any(WORKITEM_LINE.match(t) for _, t in workitems):
        warnings.append("WorkItems has no '- PROJ-123' entry; establish it from docs/<TRACKER-ID>_*")

    # House style, whole file.
    for n, line in enumerate(lines, 1):
        if EM_DASH.search(line):
            errors.append(f"line {n}: em-dash or en-dash character")
        if EMOJI.search(line):
            errors.append(f"line {n}: emoji")

    # Vernacular, prose sections only.
    for n, line in today + workitems + tomorrow:
        for pattern, label in VERNACULAR:
            if re.search(pattern, line):
                match = re.search(pattern, line).group(0)
                errors.append(
                    f"line {n}: {label} {match!r} is resolvable only inside this workspace; "
                    "replace with descriptive text"
                )
    for n, line in commits:
        if line.startswith("- ") and COMMIT_LINE.match(line):
            continue  # commit subjects are verbatim
        for pattern, label in VERNACULAR:
            if re.search(pattern, line):
                match = re.search(pattern, line).group(0)
                errors.append(f"line {n}: {label} {match!r} in a Commits explanation line")

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    if errors:
        print(f"\n{len(errors)} error(s). Not ready to file.")
        return 1
    print(f"OK. {len(warnings)} warning(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
