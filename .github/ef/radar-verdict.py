#!/usr/bin/env python3
"""Append the daily radar's verdict to each advisory line read on stdin (doc 06 WS-SH3-2).

    radar-verdict.py <radar-verdicts.json> [today=YYYY-MM-DD] < lines

A line that carries an advisory id (or `pkg` version of a verdict entry) gets « — **not affected**: reason» or
« — **AFFECTED**: reason». No entry, or an entry past its review_by, gets « — **UNVERIFIED**: ...»: unknown is never «not affected».
Lines that are not advisory lines (`- none`, `- (could not read)`) pass through unchanged. Standard library only."""
import datetime, json, re, sys

DAILY = "the daily radar (https://github.com/espaciofuturoio/dev-playbook/pull/783)"
ADV = re.compile(r"(GHSA-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}|EEF-CVE-\d+-\d+|CVE-\d+-\d+)", re.I)


def verdict(line, entries, today):
    low = line.lower()
    pkg = re.search(r"`([^`]+)`", line)
    ids = {m.upper() for m in ADV.findall(line)}
    for e in entries:
        if not ids & {i.upper() for i in e.get("ids", [])}:
            continue
        if e.get("package") and pkg and e["package"] != pkg.group(1):
            continue
        if e.get("versions") and not any(re.search(rf"(?<![\d.]){re.escape(v)}(?![\d.])", line) for v in e["versions"]):
            continue
        if e.get("review_by", "0000") < today:
            return f"**UNVERIFIED**: review of «{e['reason'][:60]}…» expired {e['review_by']}; rerun {DAILY}"
        return f"**{'AFFECTED' if e['affected'] else 'not affected'}**: {e['reason']} (reviewed {e['reviewed']})"
    return f"**UNVERIFIED**: not in the verdict snapshot; see {DAILY}"


def main(path, today):
    entries = json.load(open(path))["verdicts"]
    for line in sys.stdin.read().splitlines():
        if line.startswith("- ") and ADV.search(line):
            line += " — " + verdict(line, entries, today)
        print(line)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else datetime.date.today().isoformat())
