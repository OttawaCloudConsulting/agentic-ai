"""Mechanical checks on a session narrative before filing.

Covers only what a script can settle: house style characters, the shape of the
metadata block, the filename convention, and whether cited workspace paths
resolve. Everything else -- whether the title is a finding, whether a section
earns its place, whether the numbers are real -- is the writer's job.

Usage:
    python3 skills/narrative/scripts/check_narrative.py <file.md>

Run from the workspace root (the directory narrative paths are relative to).
The first run asks where your git repos live and remembers the answer in
`repo_config.json` next to this script; see `configure_repos()`.

Exit 0 when clean, 1 when findings, 2 on a usage error.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

WORKSPACE = Path.cwd()
CONFIG_PATH = Path(__file__).resolve().parent / "repo_config.json"

# Directories a cited path may be relative to: the workspace root itself, or
# any discovered git repo. Repos are found at runtime (see discover_repos),
# so there is no project-specific prefix list to keep in sync here.
WORKSPACE_PREFIXES = (
    ".project/",
    ".claude/",
    "agents/",
    "DailyReports/",
    "docs/",
    "scratch/",
    "git-repos/",
    "temp/",
)


def configure_repos() -> dict:
    """Ask the user where git repos live, once, and remember the answer.

    Runs only when repo_config.json does not exist yet. Stored relative to
    this script (in the skill's own scripts/ directory) so the answer travels
    with the skill install rather than living in the workspace being narrated.
    """
    print("Narrative checker: where do this workspace's git repos live?")
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
    """Find git repos per the configured mode.

    Only checks the first directory level under the configured location for a
    `.git` entry, per the config's own scope -- no recursive search.
    """
    mode = config.get("mode")

    if mode == "root":
        return [WORKSPACE] if (WORKSPACE / ".git").exists() else []

    if mode == "subdirs":
        base = WORKSPACE
    elif mode == "other":
        location = config.get("location", "")
        base = (WORKSPACE / location) if not Path(location).is_absolute() else Path(location)
    else:
        return []

    if not base.is_dir():
        return []
    return [d for d in base.iterdir() if d.is_dir() and (d / ".git").exists()]


def load_repos() -> list[Path]:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8")) if CONFIG_PATH.exists() else configure_repos()
    return discover_repos(config)

FILENAME_RE = re.compile(r"^\d{8}-[a-z0-9]+(?:-[a-z0-9]+)*\.md$")
BACKTICK_RE = re.compile(r"`([^`\n]+)`")
EMOJI_RE = re.compile(
    "["
    "\U0001f300-\U0001faff"
    "\U00002600-\U000027bf"
    "\U0001f1e6-\U0001f1ff"
    "\U00002b00-\U00002bff"
    "\U0000fe0f"
    "]"
)
DASHES = {"—": "em-dash", "–": "en-dash"}


def check_filename(path: Path, out: list[str]) -> None:
    if not FILENAME_RE.match(path.name):
        out.append(f"filename: {path.name} does not match YYYYMMDD-slug.md")
    if path.parent.name != "narratives":
        out.append(f"location: parent directory is {path.parent.name!r}, expected 'narratives'")


def check_characters(lines: list[str], out: list[str]) -> None:
    for n, line in enumerate(lines, 1):
        for char, name in DASHES.items():
            if char in line:
                out.append(f"line {n}: {name} character, house style uses '--'")
        if EMOJI_RE.search(line):
            out.append(f"line {n}: emoji")


def check_shape(lines: list[str], out: list[str]) -> None:
    if not lines or not lines[0].startswith("# "):
        out.append("line 1: expected an H1 title")

    head = "\n".join(lines[:10])
    if "**Date:**" not in head:
        out.append("metadata: no **Date:** field in the first 10 lines")
    if not any(f"**{f}:**" in head for f in ("Repo", "Artifacts", "Code changed")):
        out.append(
            "metadata: none of **Repo:**, **Artifacts:** or **Code changed:** present. "
            "State 'Code changed: none' explicitly when nothing was committed."
        )

    sections = [(n, ln.strip()) for n, ln in enumerate(lines, 1) if ln.startswith("## ")]
    titles = [t for _, t in sections]
    if not sections:
        out.append("structure: no '## ' sections")
        return

    if titles[0] != "## Summary":
        out.append(f"line {sections[0][0]}: first section is {titles[0]!r}, expected '## Summary'")
    if "## Repository and commits" not in titles:
        out.append(
            "structure: no '## Repository and commits' section. State 'none' and why "
            "when nothing was committed, rather than omitting it."
        )
    if "## What we did" not in titles:
        out.append("structure: no '## What we did' section")
    else:
        # Summary and the commit list are the scan layer; the prose starts at
        # What we did, so anything else ahead of it has jumped the queue.
        before = titles[: titles.index("## What we did")]
        stray = [t for t in before if t not in ("## Summary", "## Repository and commits")]
        if stray:
            out.append(f"structure: {stray} appears before '## What we did'")


def check_length(lines: list[str], out: list[str]) -> None:
    """Flag prose that has outgrown the corpus.

    Measured from `## What we did` so Summary and the commit list, which are
    additional by design, are not counted against the target. The ceiling exists
    because length drift is this document's observed failure mode: a rich session
    reconstructed at 1817 words covered the same ground the 1174-word reference
    covers, and the excess was restatement rather than new material.
    """
    try:
        start = next(i for i, ln in enumerate(lines) if ln.strip() == "## What we did")
    except StopIteration:
        return
    words = len(re.findall(r"\S+", "\n".join(lines[start:])))
    if words > 1700:
        out.append(
            f"length: {words} prose words, over the 1700 ceiling. The corpus runs 873 to 1174. "
            "Cut the section a reader would not need to trust the conclusion."
        )
    elif words < 400:
        out.append(f"length: {words} prose words. Thin is fine if the session was; confirm it was.")


def resolve(candidate: str, repos: list[Path]) -> bool:
    """Try the workspace root and every discovered repo.

    Routing by prefix alone is wrong because a directory like `docs/` or
    `scripts/` can exist both at the workspace root and inside a repo. Checking
    both is cheap and removes the ambiguity.
    """
    if (WORKSPACE / candidate).exists():
        return True
    return any((repo / candidate).exists() for repo in repos)


def check_paths(lines: list[str], out: list[str], repos: list[Path]) -> None:
    seen: set[tuple[int, str]] = set()
    for n, line in enumerate(lines, 1):
        for token in BACKTICK_RE.findall(line):
            token = token.strip()
            if " " in token or "/" not in token:
                continue
            candidate = token.split(":")[0].rstrip("/")  # drop a :LINE suffix
            if not candidate.startswith(WORKSPACE_PREFIXES):
                continue
            # Narratives legitimately cite path patterns rather than files:
            # `packages/*/src`, `.project/.../docs/x.md`, `scripts/v.{py,sh}`.
            # Nothing to resolve, and flagging them trains the writer to ignore
            # the checker, which costs more than the check is worth.
            if any(ch in candidate for ch in "*?{}[]") or "..." in candidate:
                continue
            if (n, candidate) in seen:
                continue
            seen.add((n, candidate))
            if not resolve(candidate, repos):
                out.append(f"line {n}: cited path does not resolve: {candidate}")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    path = Path(argv[1]).resolve()
    if not path.is_file():
        print(f"not a file: {path}", file=sys.stderr)
        return 2

    lines = path.read_text(encoding="utf-8").splitlines()
    findings: list[str] = []
    check_filename(path, findings)
    check_characters(lines, findings)
    check_shape(lines, findings)
    check_length(lines, findings)
    check_paths(lines, findings, load_repos())

    if not findings:
        print(f"OK  {path.name}: {len(lines)} lines, no mechanical findings.")
        print("Still to do by hand: re-check every file and line citation against source.")
        return 0

    print(f"FINDINGS  {path.name}: {len(findings)}")
    for f in findings:
        print(f"  {f}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
