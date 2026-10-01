#!/usr/bin/env python3
"""Scaffold and check per-control evidence documents.

  python3 scripts/evidence_docs.py scaffold --controls FILE --solution NAME [--out DIR] [--date YYYY-MM-DD]
  python3 scripts/evidence_docs.py check [--controls FILE] [--out DIR] [--strict]

--controls: one control per line, as AC-2, AC-2(1) or AC-2-1 (first ID on the line; other text ignored),
or as a Family | Control | Enhancement table row: | AC | 2 | (1) | (base control: | AC | 2 | - |).
--out defaults to docs/compliance/package/documents.

scaffold writes the Definition and Guidance sections verbatim from assets/cccs-medium-controls.json
and leaves the Evidential Response for the model. On an existing document it only refreshes
Definition/Guidance when the source text changed, and never modifies an APPROVED document.

check validates structure, Status, Date, source-identical Definition/Guidance and requirement
column, and counts PENDING markers. A response beginning "Evidence:" is a placeholder; any other
response is evidence. NOT-STARTED = Description not yet written; DRAFT/APPROVED = Description written. Exit 1 on structural errors (and on PENDING markers with --strict).
Standard library only.
"""
import argparse
import datetime
import json
import re
import sys
from pathlib import Path

SKILL = Path(__file__).resolve().parent.parent
CATALOGUE = SKILL / "assets" / "cccs-medium-controls.json"
DEFAULT_OUT = Path("docs/compliance/package/documents")
STATUSES = ("NOT-STARTED", "DRAFT", "APPROVED")
PENDING_EVIDENCE = "Evidence: PENDING"
PENDING = "<!-- PENDING -->"
NO_GUIDANCE = "No supplemental guidance in source."
HEADINGS = [
    "## Definition:", "### Guidance", "## Evidential Response", "### Description",
    "### Artifacts", "### References", "## Dictionary of Definitions",
]
ID_IN_LINE = re.compile(r"\b([A-Z]{2})-(\d+)(?:\((\d+)\)|-(\d+))?(?!\d)")
ID_IN_TABLE = re.compile(r"^\|\s*([A-Z]{2})\s*\|\s*(\d+)\s*\|\s*(?:-|\((\d+)\))\s*\|")
UPPER = re.compile(r"^\(([A-Z]{1,2})\)\s*")
LOWER = re.compile(r"^\(([a-z]{1,2})\)\s*")


def norm(line):
    return re.sub(r"\s+", " ", line).strip()


def catalogue():
    return {c["id"]: c for c in json.loads(CATALOGUE.read_text())["controls"]}


def parse_controls(path):
    ids = []
    for line in Path(path).read_text().splitlines():
        t = ID_IN_TABLE.match(line)
        m = t or ID_IN_LINE.search(line)
        if m:
            fam, num, enh = (t[1], t[2], t[3]) if t else (m[1], m[2], m[3] or m[4])
            cid = f"{fam}-{num}" + (f"({enh})" if enh else "")
            if cid not in ids:
                ids.append(cid)
    return ids


def doc_id(cid):
    return cid.replace("(", "-").replace(")", "")


def doc_path(out, c):
    slug = re.sub(r"[^A-Za-z0-9]+", "_", c["title"]).strip("_")
    return out / c["id"][:2] / f"{doc_id(c['id'])}-{slug}.md"


def classify(line):
    if UPPER.match(line):
        return "upper"
    if LOWER.match(line):
        return "lower"
    if line.startswith("- "):
        return "dash"
    if "|" in line and line.split("|")[0].strip().isupper():
        return "heading"
    return "text"


def definition_lines(c):
    return [(classify(l), l) for l in (norm(x) for x in c["definition"].splitlines()) if l]


def render_definition(c):
    lines = definition_lines(c)
    has_upper = any(k == "upper" for k, _ in lines)
    out, prev_list = [], False
    for kind, text in lines:
        if kind == "upper" or (kind == "lower" and not has_upper):
            item, is_list = f"- {text}", True
        elif kind == "lower":
            item, is_list = f"  - {text}", True
        elif kind == "dash" and prev_list:
            item, is_list = f"{'    ' if has_upper else '  '}- {text[2:]}", True
        else:
            item, is_list = text, False
        if out and not (is_list and prev_list):
            out.append("")
        out.append(item)
        prev_list = is_list
    return "\n".join(out)


def render_guidance(c):
    paras = [norm(x) for x in c["guidance"].splitlines() if norm(x)]
    return "\n\n".join(paras) if paras else NO_GUIDANCE


def requirements(c):
    lines = definition_lines(c)
    top = "upper" if any(k == "upper" for k, _ in lines) else "lower" if any(k == "lower" for k, _ in lines) else None
    if top is None:
        text = " ".join(t for k, t in lines if k != "heading")
        return [text] if text else []
    reqs = []
    for kind, text in lines:
        if kind == top:
            reqs.append(text)
        elif kind != "heading" and reqs:
            reqs[-1] += "<br>" + text
        elif kind != "heading":
            reqs.append(text)
    return reqs


def cell(text):
    return text.replace("|", "\\|")


def source_block(c):
    return f"## Definition:\n\n{render_definition(c)}\n\n### Guidance\n\n{render_guidance(c)}\n\n"


def render_doc(c, solution, date):
    title_id = doc_id(c["id"])
    rows = "\n".join(f"| **{cell(r)}** | {PENDING_EVIDENCE} |" for r in requirements(c))
    return (
        f"# {title_id} - {c['title']}\n\n"
        f"Family: {c['id'][:2]}\n"
        f"Solution: {solution}\n"
        f"Date: {date}\n"
        f"Status: NOT-STARTED\n\n"
        + source_block(c)
        + "## Evidential Response\n\n"
        f"### Description\n\n{PENDING}\n\n"
        "### Artifacts\n\n"
        "| Control Requirement | Response |\n"
        "| --- | --- |\n"
        f"{rows}\n\n"
        f"### References\n\n{PENDING}\n\n"
        f"## Dictionary of Definitions\n\n{PENDING}\n"
    )


ROW = re.compile(r"^\| \*\*(.*)\*\* \| (.*) \|$", re.M)


def artifact_rows(text):
    m = re.search(r"^### Artifacts\n.*?(?=^### References$)", text, re.M | re.S)
    return ROW.findall(m[0]) if m else []


def refresh_requirements(text, c):
    rows = artifact_rows(text)
    want = [cell(r) for r in requirements(c)]
    if [r for r, _ in rows] == want:
        return text, True
    if len(rows) != len(want):
        return text, False
    for (old, resp), new in zip(rows, want):
        text = text.replace(f"| **{old}** | {resp} |", f"| **{new}** | {resp} |", 1)
    return text, True


def description_written(text):
    m = re.search(r"^### Description\n(.*?)(?=^### Artifacts$)", text, re.M | re.S)
    body = m[1].strip() if m else ""
    return bool(body) and PENDING not in body


def field(text, name):
    m = re.search(rf"^{name}: *(.*)$", text, re.M)
    return m[1].strip() if m else None


def current_source_block(text):
    m = re.search(r"^## Definition:\n.*?(?=^## Evidential Response$)", text, re.M | re.S)
    return m[0] if m else None


def scaffold(args):
    cat = catalogue()
    ids = parse_controls(args.controls)
    unknown = [i for i in ids if i not in cat]
    date = args.date or datetime.date.today().isoformat()
    created = refreshed = unchanged = 0
    held, misaligned = [], []
    for cid in ids:
        if cid in unknown:
            continue
        c = cat[cid]
        path = doc_path(args.out, c)
        if not path.exists():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(render_doc(c, args.solution, date))
            created += 1
            continue
        text = path.read_text()
        old = current_source_block(text)
        new = source_block(c)
        updated, rows_ok = refresh_requirements(text.replace(old, new) if old else text, c)
        if not rows_ok:
            misaligned.append(str(path))
        if updated == text:
            unchanged += 1
        elif field(text, "Status") == "APPROVED":
            held.append(str(path))
        else:
            updated = re.sub(r"^Date: .*$", f"Date: {date}", updated, count=1, flags=re.M)
            path.write_text(updated)
            refreshed += 1
    print(f"controls: {len(ids)}  created: {created}  refreshed: {refreshed}  unchanged: {unchanged}")
    for p in held:
        print(f"APPROVED, source text changed, not modified: {p}")
    for p in misaligned:
        print(f"Artifacts rows differ in number from source requirements, rows not refreshed: {p}")
    for i in unknown:
        print(f"not in CCCS Medium catalogue, no document created: {i}")


def source_text_matches(c, block):
    def words(s):
        return norm(s).split(" ")
    body = re.sub(r"^## Definition:|^### Guidance", "", block, flags=re.M)
    got = [w for w in words(body.replace("\n", " ")) if w != "-"]
    guidance = c["guidance"] if norm(c["guidance"]) else NO_GUIDANCE
    return got == [w for w in words(c["definition"] + " " + guidance) if w != "-"]


def check(args):
    cat = catalogue()
    by_path = {doc_path(args.out, c).resolve(): c for c in cat.values()}
    errors, pending, statuses = [], {}, {}
    rows = {"evidenced": 0, "placeholder": 0}
    files = sorted(args.out.rglob("*.md")) if args.out.exists() else []
    seen = set()
    for f in files:
        c = by_path.get(f.resolve())
        if not c:
            errors.append(f"{f}: name does not match any catalogue control")
            continue
        seen.add(c["id"])
        text = f.read_text()
        if not text.startswith(f"# {doc_id(c['id'])} - {c['title']}\n"):
            errors.append(f"{f}: title line")
        positions = [text.find("\n" + h + "\n") for h in HEADINGS]
        if -1 in positions or positions != sorted(positions):
            errors.append(f"{f}: headings missing or out of order")
        if field(text, "Family") != c["id"][:2]:
            errors.append(f"{f}: Family")
        if not field(text, "Solution"):
            errors.append(f"{f}: Solution empty")
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", field(text, "Date") or ""):
            errors.append(f"{f}: Date not YYYY-MM-DD")
        if field(text, "Status") not in STATUSES:
            errors.append(f"{f}: Status not one of {STATUSES}")
        block = current_source_block(text)
        if not block or not source_text_matches(c, block):
            errors.append(f"{f}: Definition/Guidance differ from source")
        if [r for r, _ in artifact_rows(text)] != [cell(r) for r in requirements(c)]:
            errors.append(f"{f}: Artifacts requirement column differs from source")
        n = text.count(PENDING_EVIDENCE) + text.count(PENDING)
        if n:
            pending[str(f)] = n
        status = field(text, "Status")
        statuses[status] = statuses.get(status, 0) + 1
        responses = [r for _, r in artifact_rows(text)]
        placeholders = sum(1 for r in responses if r.startswith("Evidence:"))
        rows["evidenced"] += len(responses) - placeholders
        rows["placeholder"] += placeholders
        described = description_written(text)
        if status == "NOT-STARTED" and described:
            errors.append(f"{f}: Status NOT-STARTED but Description is written; set DRAFT")
        if status in ("DRAFT", "APPROVED") and not described:
            errors.append(f"{f}: Status {status} but Description is not written")
        if status == "APPROVED" and n:
            errors.append(f"{f}: APPROVED with PENDING markers")
    if args.controls:
        for cid in parse_controls(args.controls):
            if cid in cat and cid not in seen:
                errors.append(f"missing document for {cid}")
    for e in errors:
        print("ERROR", e)
    for p, n in pending.items():
        print(f"PENDING {n}: {p}")
    print(f"documents: {len(files)}  errors: {len(errors)}  with PENDING: {len(pending)}")
    print(f"status: {statuses}  artifact rows: {rows}")
    sys.exit(1 if errors or (args.strict and pending) else 0)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("scaffold")
    s.add_argument("--controls", required=True)
    s.add_argument("--solution", required=True)
    s.add_argument("--out", type=Path, default=DEFAULT_OUT)
    s.add_argument("--date")
    k = sub.add_parser("check")
    k.add_argument("--controls")
    k.add_argument("--out", type=Path, default=DEFAULT_OUT)
    k.add_argument("--strict", action="store_true")
    a = ap.parse_args()
    scaffold(a) if a.cmd == "scaffold" else check(a)


if __name__ == "__main__":
    main()
