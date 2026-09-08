#!/usr/bin/env python3
"""Collect the raw material for one daily report.

Prints the day's commits across this workspace's writable repositories with
their pushed state, the narratives filed for the date, commits from the two
following days (a fix left uncommitted at day end lands later and is easy to
lose), and the previous report's Tomorrow section.

Run from the workspace root. The first run asks where the repos live and
remembers the answer in `repo_config.json` next to this script -- see
`configure_repos()`.

Usage:
    python3 skills/daily-report/scripts/collect_day.py 2026-08-27
    python3 skills/daily-report/scripts/collect_day.py          # today
"""

import json
import subprocess
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

REPO_ROOT = Path.cwd()
CONFIG_PATH = Path(__file__).resolve().parent / "repo_config.json"


def configure_repos() -> dict:
    """Ask the user where this workspace's git repos live, once."""
    print("Daily report collector: where do this workspace's git repos live?")
    print("  1. The project root itself is a single repo")
    print("  2. Sub-directories of the project root (1st level only)")
    print("  3. Another location, e.g. a bundled `git-repos/` sub-directory")
    choice = input("Choose 1, 2 or 3: ").strip()

    if choice == "1":
        config = {"mode": "root"}
    elif choice == "2":
        config = {"mode": "subdirs"}
    elif choice == "3":
        location = input("Path to that location (relative to project root, or absolute): ").strip()
        config = {"mode": "other", "location": location}
    else:
        print(f"Unrecognised choice {choice!r}, defaulting to option 2.", file=sys.stderr)
        config = {"mode": "subdirs"}

    CONFIG_PATH.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    print(f"Saved to {CONFIG_PATH}. Delete that file to be asked again.")
    return config


def discover_repos(config: dict) -> list[Path]:
    """Find git repos per the configured mode, first directory level only."""
    mode = config.get("mode")

    if mode == "root":
        return [REPO_ROOT] if (REPO_ROOT / ".git").exists() else []

    if mode == "subdirs":
        base = REPO_ROOT
    elif mode == "other":
        location = config.get("location", "")
        base = (REPO_ROOT / location) if not Path(location).is_absolute() else Path(location)
    else:
        return []

    if not base.is_dir():
        return []
    return [d for d in base.iterdir() if d.is_dir() and (d / ".git").exists()]


def load_repos() -> list[Path]:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8")) if CONFIG_PATH.exists() else configure_repos()
    return discover_repos(config)


def git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def commits_between(repo: Path, start: date, end: date):
    """Commits on any branch authored within [start 00:00:00, end 23:59:59].

    The explicit times matter: a bare --since=DATE boundary has produced the
    wrong day's commits in this workspace.
    """
    out = git(
        repo,
        "log",
        "--all",
        "--no-merges",
        f"--since={start.isoformat()} 00:00:00",
        f"--until={end.isoformat()} 23:59:59",
        "--date=short",
        "--pretty=%h\x1f%ad\x1f%s",
    )
    rows = []
    for line in out.splitlines():
        if not line.strip():
            continue
        sha, when, subject = line.split("\x1f", 2)
        rows.append((sha, when, subject))
    rows.reverse()  # chronological, matching the report's Commits section
    return rows


def is_pushed(repo: Path, sha: str) -> bool:
    return bool(git(repo, "branch", "-r", "--contains", sha))


def print_commit_block(repos: list[Path], day: date, start: date, end: date, header: str) -> None:
    print(header)
    any_found = False
    for repo in repos:
        name = repo.name
        for sha, when, subject in commits_between(repo, start, end):
            any_found = True
            state = "" if is_pushed(repo, sha) else "   [LOCAL ONLY, not on any remote]"
            stamp = f" ({when})" if when != day.isoformat() else ""
            print(f"- {name} | {sha} | {subject}{stamp}{state}")
    if not any_found:
        print("  (none)")
    print()


def main() -> int:
    if len(sys.argv) > 2:
        print(__doc__)
        return 2
    if len(sys.argv) == 2:
        day = datetime.strptime(sys.argv[1], "%Y-%m-%d").date()
    else:
        day = date.today()

    print(f"DATE: {day.isoformat()}")
    print(f"REPORT FILE: DailyReports/{day:%Y%m%d}.txt")
    print()

    repos = load_repos()
    print_commit_block(repos, day, day, day, "COMMITS ON THE DAY")
    print_commit_block(
        repos,
        day,
        day + timedelta(days=1),
        day + timedelta(days=2),
        "LATER COMMITS (check whether any belong to this day's work)",
    )

    print("NARRATIVES FOR THIS DATE")
    narratives = sorted((REPO_ROOT / "DailyReports" / "narratives").glob(f"{day:%Y%m%d}-*.md"))
    if narratives:
        for path in narratives:
            print(f"- {path.relative_to(REPO_ROOT)}")
    else:
        print("  (none. Reconstruct from commits, .project/, agents/investigations/, progress.txt)")
    print()

    print("PREVIOUS REPORT")
    reports = sorted(p for p in (REPO_ROOT / "DailyReports").glob("[0-9]" * 8 + ".txt")
                     if p.stem < f"{day:%Y%m%d}")
    if not reports:
        print("  (none)")
        return 0
    previous = reports[-1]
    print(f"- {previous.relative_to(REPO_ROOT)}")
    text = previous.read_text()
    if "\nTomorrow:" in text:
        print("  Its Tomorrow section, each bullet of which this report owes an answer:")
        for line in text.split("\nTomorrow:", 1)[1].splitlines():
            print(f"  {line}" if line.strip() else "")
    return 0


if __name__ == "__main__":
    sys.exit(main())
