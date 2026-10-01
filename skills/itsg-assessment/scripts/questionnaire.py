#!/usr/bin/env python3
"""Generate and ingest per-family system-owner questionnaires.

  python3 scripts/questionnaire.py generate --mapping FILE --solution NAME [--out DIR] [--date YYYY-MM-DD]
  python3 scripts/questionnaire.py ingest [--out DIR] [--mapping FILE] [--json FILE] [--update-mapping] [--date YYYY-MM-DD]
  python3 scripts/questionnaire.py check [--out DIR] [--mapping FILE]

--mapping defaults to docs/compliance/phase2-control-mapping.md; --out defaults to
docs/compliance/questionnaire.

generate reads the "Controls Requiring System-Owner Input" table (| Control | Question |) from the
mapping (first two columns; a trailing Response column is ignored) and writes one {Family}-questionnaire.md per family, with control titles from
assets/cccs-medium-controls.json and family names from references/cccs-medium-profile.md.
It is merge-safe: an existing file is never rewritten. Controls not yet in it are appended before
"## Submission"; existing entries, responses and the Background paragraph are left as they are.
Controls in a file but no longer in the mapping are reported, not removed. New files carry
<!-- PENDING --> in Background for the model to replace.

ingest parses every questionnaire and reports each entry as answered, partial or unanswered, with
file:line of the response. partial means the response contains a placeholder marker: a
<placeholder> such as <define procedure>, the word TBD or TODO (any case), or ???. Fenced code
blocks in a response are reviewer notes: they are reported separately in the JSON (notes: label,
text, line) and their markers still count, so an open TBD in a note makes the entry partial. With --update-mapping it writes only the script-owned part of the mapping: the Response
column of the input table (added if absent; Control and Question cells untouched) and the
"Questionnaire responses ingested:" line under the heading (added if absent). Nothing is written
when there are parse errors. Folding responses into the per-control entries is the model's work.
Entries are matched with or without bold labels (**Control ID:** or Control ID:).
--json writes the full report, response text included. Exit 1 on parse errors.
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
PROFILE = SKILL / "references" / "cccs-medium-profile.md"
DEFAULT_MAPPING = Path("docs/compliance/phase2-control-mapping.md")
DEFAULT_OUT = Path("docs/compliance/questionnaire")
INPUT_HEADING = "## Controls Requiring System-Owner Input"
INGESTED = "Questionnaire responses ingested:"
STATES = ("answered", "partial", "unanswered")
PENDING = "<!-- PENDING -->"
SUBMISSION = "## Submission"
ROW = re.compile(r"^\|\s*([A-Z]{2}-\d+(?:\(\d+\))?)\s*\|(.*)\|\s*$")
FAMILY = re.compile(r"^## ([A-Z]{2}) — (.+?)\s*$")
CONTROL_LINE = re.compile(r"^\s*(?:\*\*)?Control ID:(?:\*\*)?\s*([A-Z]{2}-\d+(?:\(\d+\))?)")
RESPONSE_LINE = re.compile(r"^\s*(?:\*\*)?Response:(?:\*\*)?\s*(.*)$")
QUESTION_LINE = re.compile(r"^\s*(?:\*\*)?Question:(?:\*\*)?\s*(.*)$")
COMMENT = re.compile(r"<!--.*?-->", re.S)
PLACEHOLDER = re.compile(r"<(?!br\s*/?>|https?://)[^<>\n]+>|\bTBD\b|\bTODO\b|\?{3,}", re.I)
FENCE = re.compile(r"^\s*```(.*)$")
PENDING_MARK = "**Pending system-owner input:**"


def titles():
    return {c["id"]: c["title"] for c in json.loads(CATALOGUE.read_text())["controls"]}


def family_names():
    names = {}
    for line in PROFILE.read_text().splitlines():
        m = FAMILY.match(line)
        if m:
            names[m[1]] = m[2]
    return names


def parse_mapping(path):
    rows, inside = [], False
    for line in Path(path).read_text().splitlines():
        if line.startswith("## "):
            if inside:
                break
            inside = line.strip() == INPUT_HEADING
            continue
        m = inside and ROW.match(line)
        if m:
            rows.append((m[1], m[2].split("|")[0].strip()))
    return rows


def render_entry(cid, title, question):
    return (
        f"**Control ID:** {cid}\n**Description:** {title}\nQuestion: {question}\n"
        "**Response:**\n\n\n\n\n---\n\n"
    )


def render_file(fam, name, solution, date, entries):
    head = (
        f"# ITSG-33 System Owner Questionnaire — {name}\n\n"
        f"**Control Family:** {fam}\n**Project:** {solution}\n**Date:** {date}\n\n"
        f"This questionnaire gathers organizational context, policies, and procedural evidence for the {name} "
        "control family that cannot be derived from code or configuration alone.\n"
        "Responses will complete the Phase 2 control mapping and inform the Phase 3 gap analysis.\n\n"
        "Please provide specific, verifiable answers where possible.\n"
        "Reference organizational policies, procedures, records, or responsible roles by name.\n"
        'If evidence does not exist, state "Not implemented" rather than leaving blank.\n\n'
        f"---\n\n## Background\n\n{PENDING}\n\n---\n\n"
    )
    tail = (
        f"{SUBMISSION}\n\nReturn completed questionnaire to the assessment team.\n"
        "Responses inform the Phase 2 control-mapping status and Phase 3 gap analysis.\n"
    )
    return head + "".join(entries) + tail


def generate(args):
    rows = parse_mapping(args.mapping)
    if not rows:
        print(f"ERROR no rows under '{INPUT_HEADING}' in {args.mapping}")
        sys.exit(1)
    cat, names = titles(), family_names()
    date = args.date or datetime.date.today().isoformat()
    by_family, unknown = {}, []
    for cid, question in rows:
        if cid not in cat:
            unknown.append(cid)
            continue
        by_family.setdefault(cid[:2], []).append((cid, question))
    args.out.mkdir(parents=True, exist_ok=True)
    created = appended = unchanged = 0
    stale = []
    for fam, items in sorted(by_family.items()):
        path = args.out / f"{fam}-questionnaire.md"
        wanted = [cid for cid, _ in items]
        if not path.exists():
            entries = [render_entry(cid, cat[cid], q) for cid, q in items]
            path.write_text(render_file(fam, names.get(fam, fam), args.solution, date, entries))
            created += 1
            continue
        text = path.read_text()
        present = [e["control"] for e in parse_file(path)[0]]
        new = [render_entry(cid, cat[cid], q) for cid, q in items if cid not in present]
        stale += [f"{path.name}: {cid}" for cid in present if cid not in wanted]
        if not new:
            unchanged += 1
            continue
        at = text.find(SUBMISSION)
        text = text + "\n---\n\n" + "".join(new) if at < 0 else text[:at] + "".join(new) + text[at:]
        path.write_text(text)
        appended += 1
    print(f"controls: {len(rows)}  families: {len(by_family)}  created: {created}  appended: {appended}  unchanged: {unchanged}")
    for s in stale:
        print(f"in questionnaire but no longer in mapping, left in place: {s}")
    for i in unknown:
        print(f"not in CCCS Medium catalogue, no entry written: {i}")


def parse_file(path):
    lines = path.read_text().splitlines()
    entries, errors, cur, body = [], [], None, None

    def close():
        if cur["response_line"] is None:
            errors.append(f"{path.name}:{cur['line']}: {cur['control']} has no Response: line")
        text = COMMENT.sub("", "\n".join(body or [])).strip()
        cur["response"] = text
        cur["placeholders"] = PLACEHOLDER.findall(text)
        cur["notes"], note = [], None
        for n, l in enumerate(body or []):
            f = FENCE.match(l)
            if f and note is None:
                note = {"label": f[1].strip(), "line": cur["response_line"] + n, "text": []}
            elif f:
                note["text"] = "\n".join(note["text"]).strip()
                cur["notes"].append(note)
                note = None
            elif note is not None:
                note["text"].append(l)
        cur["status"] = "unanswered" if not text else "partial" if cur["placeholders"] else "answered"
        entries.append(cur)

    for i, line in enumerate(lines):
        m = CONTROL_LINE.match(line)
        if cur is not None and (m or line.strip() == "---" or line.startswith("## ")):
            close()
            cur = body = None
        if m:
            cur = {"control": m[1], "file": path.name, "line": i + 1, "question": "", "response_line": None}
            continue
        if cur is None:
            continue
        if body is not None:
            body.append(line)
            continue
        q, r = QUESTION_LINE.match(line), RESPONSE_LINE.match(line)
        if r:
            cur["response_line"], body = i + 1, [r[1]]
        elif q:
            cur["question"] = q[1].strip()
    if cur is not None:
        close()
    return entries, errors


def update_mapping(path, entries, date):
    status = {e["control"]: e["status"] for e in entries}
    n = {s: sum(1 for e in entries if e["status"] == s) for s in STATES}
    line = f"{INGESTED} {date} — {n['answered']} answered, {n['partial']} partial, {n['unanswered']} unanswered"
    lines = path.read_text().splitlines(keepends=True)
    out, inside, has_line, rows = [], False, False, 0

    def cells(l):
        return l.rstrip("\n").strip().strip("|").split("|")

    def emit(c):
        out.append("| " + " | ".join(x.strip() for x in c) + " |\n")

    for l in lines:
        if l.startswith("## "):
            if inside and not has_line:
                raise SystemExit(f"ERROR {INPUT_HEADING} has no table")
            inside = l.strip() == INPUT_HEADING
            out.append(l)
            continue
        if not inside:
            out.append(l)
            continue
        if l.startswith(INGESTED):
            out.append(line + "\n")
            has_line = True
            continue
        if l.startswith("|") and not has_line:
            out += [line + "\n", "\n"]
            has_line = True
        if not l.startswith("|"):
            out.append(l)
            continue
        c = cells(l)
        m = ROW.match(l.rstrip("\n"))
        three = len(c) >= 3 and (c[-1].strip() in STATES or c[-1].strip() == "Response" or set(c[-1].strip()) <= set("-:"))
        if m:
            value = status.get(m[1], "unanswered")
            c = c[:-1] + [value] if len(c) >= 3 and c[-1].strip() in STATES else c + [value]
            rows += 1
        elif not three:
            c = c + (["---"] if set(c[-1].strip()) <= set("-:") else ["Response"])
        emit(c)
    path.write_text("".join(out))
    print(f"mapping updated: {rows} input-table rows; {line}")


def ingest(args):
    files = sorted(args.out.glob("*-questionnaire.md"))
    if not files:
        print(f"ERROR no questionnaires in {args.out}")
        sys.exit(1)
    entries, errors = [], []
    for f in files:
        e, err = parse_file(f)
        entries += e
        errors += err
    seen = {}
    for e in entries:
        if e["control"] in seen:
            errors.append(f"{e['file']}:{e['line']}: {e['control']} also at {seen[e['control']]}")
        seen[e["control"]] = f"{e['file']}:{e['line']}"
    if args.mapping and Path(args.mapping).exists():
        listed = {cid for cid, _ in parse_mapping(args.mapping)}
        for cid in sorted(listed - set(seen)):
            errors.append(f"{cid} is in the mapping input table but in no questionnaire")
    for e in errors:
        print("ERROR", e)
    print("| Control | Status | Response at | Placeholders |")
    print("|---|---|---|---|")
    for e in entries:
        at = f"{e['file']}:{e['response_line']}" if e["response_line"] else e["file"]
        print(f"| {e['control']} | {e['status']} | {at} | {', '.join(e['placeholders'])} |")
    families = {}
    for e in entries:
        f = families.setdefault(e["control"][:2], {"answered": 0, "partial": 0, "unanswered": 0})
        f[e["status"]] += 1
    count = lambda s: sum(f[s] for f in families.values())
    print(f"\nentries: {len(entries)}  families: {len(families)}  answered: {count('answered')}  "
          f"partial: {count('partial')}  unanswered: {count('unanswered')}  errors: {len(errors)}")
    print("families with no response: " + (", ".join(k for k, f in sorted(families.items())
                                                     if f["answered"] + f["partial"] == 0) or "none"))
    if args.json:
        Path(args.json).write_text(json.dumps({"families": families, "entries": entries}, indent=2) + "\n")
    if errors:
        sys.exit(1)
    if args.update_mapping:
        update_mapping(Path(args.mapping), entries, args.date or datetime.date.today().isoformat())


def anchors(path):
    """Map control ID -> list of text anchors: its ### section and any decision-table row."""
    found, section, inside_input = {}, None, False
    for l in Path(path).read_text().splitlines():
        if l.startswith("## "):
            inside_input = l.strip() == INPUT_HEADING
            section = None
            continue
        if l.startswith("### "):
            m = re.match(r"^### ([A-Z]{2}-\d+(?:\(\d+\))?):", l)
            section = found.setdefault(m[1], []) if m else None
            if m:
                section.append("")
            continue
        if inside_input:
            continue
        r = ROW.match(l)
        if r:
            found.setdefault(r[1], []).append(l)
        elif section is not None:
            section[-1] += l + "\n"
    return found


def check(args):
    entries, errors = [], []
    for f in sorted(args.out.glob("*-questionnaire.md")):
        e, err = parse_file(f)
        entries += e
        errors += err
    status = {e["control"]: e["status"] for e in entries}
    listed = [cid for cid, _ in parse_mapping(args.mapping)]
    found = anchors(args.mapping)
    answered_pending, counts = [], {"pending": 0, "none": 0}
    for cid in listed:
        if cid not in found:
            errors.append(f"{cid}: no ### section or decision-table row in the mapping")
            continue
        n = sum(a.count(PENDING_MARK) for a in found[cid])
        st = status.get(cid, "missing")
        counts["pending" if n else "none"] += 1
        if n > 1:
            errors.append(f"{cid}: {n} pending lines (one expected at most)")
        elif st == "unanswered" and n != 1:
            errors.append(f"{cid}: unanswered but no pending line")
        elif st == "answered" and n == 1:
            answered_pending.append(cid)
    for e in errors:
        print("ERROR", e)
    for cid in answered_pending:
        print(f"answered with a pending line (response does not address the question?): {cid}")
    print(f"controls: {len(listed)}  with pending line: {counts['pending']}  without: {counts['none']}  errors: {len(errors)}")
    sys.exit(1 if errors else 0)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("generate")
    g.add_argument("--mapping", type=Path, default=DEFAULT_MAPPING)
    g.add_argument("--solution", required=True)
    g.add_argument("--out", type=Path, default=DEFAULT_OUT)
    g.add_argument("--date")
    i = sub.add_parser("ingest")
    i.add_argument("--out", type=Path, default=DEFAULT_OUT)
    i.add_argument("--mapping", type=Path, default=DEFAULT_MAPPING)
    i.add_argument("--json")
    i.add_argument("--update-mapping", action="store_true")
    i.add_argument("--date")
    k = sub.add_parser("check")
    k.add_argument("--out", type=Path, default=DEFAULT_OUT)
    k.add_argument("--mapping", type=Path, default=DEFAULT_MAPPING)
    a = ap.parse_args()
    {"generate": generate, "ingest": ingest, "check": check}[a.cmd](a)


if __name__ == "__main__":
    main()
