#!/usr/bin/env python3
"""Extract official ITSG-33 Annex 3A control text deterministically.

Parts come from the top-level <li> items of the control's "Control:" ordered
list, which Annex 3A styles as list-style-type: upper-alpha. Text extractors
that strip tags drop those CSS-generated A./B./C. markers, which is how a
control comes to look like unlettered prose. Parsing the markup avoids that.

Usage:
  python3 extract-control.py --capture <raw.html> --control AC-7 --out-dir docs/compliance/.control-text
  python3 extract-control.py --url <annex3a-url> --control AC-7 --out-dir docs/compliance/.control-text

Writes (under --out-dir):
  annex3a.raw.html          the raw capture, retained as fabrication evidence
  <FAMILY>.md               cache entry with provenance and verbatim parts
Prints the extracted parts to stdout.
"""
import argparse, datetime, html, io, os, re, sys


def clean(fragment):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", fragment))).strip()


def control_block(doc, control_id):
    m = re.search(r"<h4[^>]*>" + re.escape(control_id) + r" [A-Z0-9][^<]*</h4>", doc)
    if not m:
        return None, None
    title = clean(m.group(0))[len(control_id) + 1:]
    return doc[m.start():m.start() + 20000], title


def split_top_level_li(inner):
    items, depth, buf, k = [], 0, "", 0
    while k < len(inner):
        if inner.startswith("<ol", k):
            depth += 1
        elif inner.startswith("</ol>", k):
            depth -= 1
        elif inner.startswith("<li>", k) and depth == 0:
            if buf.strip():
                items.append(buf)
            buf, k = "", k + 4
            continue
        buf += inner[k]
        k += 1
    if buf.strip():
        items.append(buf)
    return items


def parse_control(doc, control_id):
    seg, title = control_block(doc, control_id)
    if seg is None:
        return None
    m = re.search(r"<p><strong>Control:?</strong>.*?(<ol\b)", seg, re.S)
    if not m:
        return None
    start, depth, j = m.start(1), 0, m.start(1)
    while j < len(seg):
        if seg.startswith("<ol", j):
            depth += 1
            j = seg.index(">", j) + 1
            continue
        if seg.startswith("</ol>", j):
            depth -= 1
            j += 5
            if depth == 0:
                break
            continue
        j += 1
    ol = seg[start:j]
    parts = []
    for item in split_top_level_li(ol[ol.index(">") + 1:-5]):
        nested = re.search(r"<ol\b[^>]*>(.*?)</ol>", item, re.S)
        subs = [clean(x) for x in re.findall(r"<li>(.*?)</li>", nested.group(1), re.S)] if nested else []
        parts.append((clean(re.sub(r"<ol\b.*?</ol>", "", item, flags=re.S)), subs))
    g = re.search(r"<strong>Supplemental Guidance</strong>\s*:?(.*?)(?:<p><strong>Control Enhancements|<h4)", seg, re.S)
    return {"title": title, "parts": parts, "guidance": clean(g.group(1)) if g else None}


def main():
    ap = argparse.ArgumentParser()
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--capture", help="path to an existing raw HTML capture")
    src.add_argument("--url", help="Annex 3A URL to retrieve")
    ap.add_argument("--control", required=True, help="control ID, e.g. AC-7")
    ap.add_argument("--out-dir", default="docs/compliance/.control-text")
    args = ap.parse_args()

    if args.url:
        from urllib.request import urlopen
        doc = urlopen(args.url, timeout=60).read().decode("utf-8", "replace")
        source, method = args.url, "urlopen full-page retrieval"
    else:
        doc = io.open(args.capture, encoding="utf-8", errors="replace").read()
        source, method = args.capture, "local raw capture"

    parsed = parse_control(doc, args.control.upper())
    if not parsed:
        print("ERROR: %s not found in source. Do not write control text from memory; "
              "emit a [VERIFY-SOURCE] marker instead." % args.control, file=sys.stderr)
        return 2

    os.makedirs(args.out_dir, exist_ok=True)
    raw_path = os.path.join(args.out_dir, "annex3a.raw.html")
    io.open(raw_path, "w", encoding="utf-8").write(doc)

    family = args.control.split("-")[0].upper()
    retrieved = datetime.date.today().isoformat()
    lines = [
        "## %s — %s" % (args.control.upper(), parsed["title"]),
        "",
        "**Source:** %s | **Retrieved:** %s | **Catalogue:** ITSG-33 Annex 3A" % (source, retrieved),
        "**Retrieval method:** %s | **Raw capture:** %s" % (method, os.path.basename(raw_path)),
        "**Part count:** %d (top-level list items of the Control block)" % len(parsed["parts"]),
        "", "### Definition", "",
    ]
    for n, (head, subs) in enumerate(parsed["parts"]):
        lines.append("%s. %s" % (chr(65 + n), head))
        lines.extend("    %s. %s" % (chr(97 + i), sub) for i, sub in enumerate(subs))
        lines.append("")
    lines += ["### Supplemental Guidance", "", parsed["guidance"] or "[VERIFY-SOURCE: guidance not parsed]", ""]

    cache_path = os.path.join(args.out_dir, "%s.md" % family)
    with io.open(cache_path, "a", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")

    print("\n".join(lines))
    print("cache: %s\nraw:   %s" % (cache_path, raw_path), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
