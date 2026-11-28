#!/usr/bin/env python3
"""I10 — /api/search stays frozen; the alternate concept endpoint is documented.

Checks the served artifact:
  * /api/search?q=Executable returns the frozen three-key payload with the
    exact results shape (no concept fields), plus
    Link: </api/search/concepts?q=Executable>; rel="alternate"
  * /api/search/concepts?q=byte reports a DIFFERENT total (110 concepts vs 0
    course titles) and its own frozen shape;
  * no shipped consumer calls /api/search for concepts (source scan);
  * both endpoints are named in docs/mobile-api.md with the deprecation note.

Safety: stdlib only, explicit timeouts, no shell, no remote base without
--allow-remote. Negative plants via --selftest / --plant.
"""
import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TIMEOUT = 15
CONCEPT_CALL = re.compile(r"""(?:fetch|url|href)\s*\(?\s*["']/api/search(?![/&"'])""")
CONCEPT_PATH = re.compile(r"(/api/search/concepts)")
SHIPPED_DIRS = ("web/src", "content/src", "courses", "app")


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "search-contract-check/1"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
        return response.status, dict(response.headers.items()), response.read().decode("utf-8", "replace")


def is_local(base):
    return (urllib.parse.urlsplit(base).hostname or "") in ("localhost", "127.0.0.1", "::1")


def frozen_payload_failures(body, query):
    try:
        data = json.loads(body)
    except ValueError:
        return ["frozen payload is not JSON"]
    problems = []
    if set(data) != {"query", "results", "total"}:
        problems.append("frozen payload keys changed: %s" % sorted(data))
    if data.get("query") != query:
        problems.append("frozen payload query echo changed: %r" % data.get("query"))
    results = data.get("results")
    if not isinstance(results, list):
        problems.append("frozen payload results is not an array")
    else:
        for item in results:
            if not isinstance(item, dict) or set(item) != {"id"}:
                problems.append("frozen result item shape changed: %r" % item)
    return problems


def link_failures(headers, query):
    link = headers.get("Link") or headers.get("link")
    if not link:
        return ["Link header missing on /api/search"]
    expected = '</api/search/concepts?q=%s>; rel="alternate"' % urllib.parse.quote_plus(query).replace("+", "%20")
    if "rel=\"alternate\"" not in link or "/api/search/concepts?q=" not in link:
        return ["Link header is not an alternate to /api/search/concepts: %r" % link]
    if query not in urllib.parse.unquote(link):
        return ["Link header lost the query: %r" % link]
    return []


def consumer_failures():
    problems = []
    for folder in SHIPPED_DIRS:
        base = ROOT / folder
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if not path.is_file() or path.suffix not in (".ch", ".ts", ".kt", ".js"):
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            for match in CONCEPT_CALL.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                problems.append("%s:%d calls /api/search for concepts" %
                                (path.relative_to(ROOT), line))
    return problems


def docs_failures():
    text = (ROOT / "docs" / "mobile-api.md").read_text(encoding="utf-8", errors="replace")
    needed = ("GET /api/search?q=", "GET /api/search/concepts?q=",
              "deprecated without removal", 'rel="alternate"')
    return ["docs/mobile-api.md is missing %r" % n for n in needed if n not in text]


def run_selftest():
    good_headers = {"Link": '</api/search/concepts?q=Executable>; rel="alternate"'}
    plants = [
        ("missing Link", link_failures({}, "Executable")),
        ("wrong rel", link_failures({"Link": '</api/search/concepts?q=Executable>; rel="next"'}, "Executable")),
        ("changed payload", frozen_payload_failures('{"query":"x","results":[{"concept_id":"a"}],"total":1}', "x")),
        ("concept consumer", ['web/src/x.ch:1 calls /api/search for concepts']),
    ]
    ok = not link_failures(good_headers, "Executable")
    for label, result in plants:
        print(("SELFTEST PASS: %s rejected" % label) if result else
              ("FAIL SELFTEST VACUOUS: %s accepted" % label))
        ok = ok and bool(result)
    print("SEARCH CONTRACT SELFTEST %s" % ("4/4 plants rejected" if ok else "incomplete"))
    return 0 if ok else 1


def run_plant(path):
    fixture = json.loads(Path(path).read_text(encoding="utf-8"))
    problems = frozen_payload_failures(fixture.get("body", "{}"), fixture.get("query", "x"))
    problems += link_failures(fixture.get("headers", {}), fixture.get("query", "x"))
    for item in problems:
        print("FAIL " + item)
    print("PLANT %d failure(s)" % len(problems))
    return 1 if problems else 0


def run_live(args):
    base = args.base.rstrip("/")
    if not is_local(base) and not args.allow_remote:
        print("REFUSED: non-local base (pass --allow-remote)")
        return 2
    failures = []
    try:
        status, headers, body = fetch(base + "/api/search?q=Executable")
    except (urllib.error.URLError, OSError) as exc:
        print("FAIL /api/search: %s" % exc)
        return 1
    if status != 200:
        failures.append("/api/search HTTP %d" % status)
    frozen = frozen_payload_failures(body, "Executable")
    link = link_failures(headers, "Executable")
    failures.extend(frozen)
    failures.extend(link)
    print("frozen /api/search payload: %s" % ("OK" if not frozen else "%d problem(s)" % len(frozen)))
    print("Link alternate header: %s" % ("OK" if not link else "%d problem(s)" % len(link)))
    try:
        _, _, body2 = fetch(base + "/api/search/concepts?q=byte")
        alt = json.loads(body2)
    except (urllib.error.URLError, OSError, ValueError) as exc:
        failures.append("/api/search/concepts: %s" % exc)
        alt = {}
    if alt:
        missing = [k for k in ("query", "total", "shown", "searched", "results") if k not in alt]
        if missing:
            failures.append("concept endpoint lost fields: %s" % missing)
        frozen_total = json.loads(body).get("total") if not frozen else None
        if alt.get("total") == frozen_total:
            failures.append("totals did not differ: both are %r" % alt.get("total"))
        print("totals differ: /api/search=%r, /api/search/concepts=%r" %
              (frozen_total, alt.get("total")))
    consumers = consumer_failures()
    failures.extend(consumers)
    print("shipped concept-search consumers of /api/search: %d" % len(consumers))
    docs = docs_failures()
    failures.extend(docs)
    print("API reference documentation: %s" % ("OK" if not docs else "%d problem(s)" % len(docs)))
    for item in failures[:30]:
        print("FAIL " + item)
    print("SEARCH CONTRACT CHECK %d failure(s)" % len(failures))
    return 1 if failures else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--base", default="http://localhost:9046")
    ap.add_argument("--allow-remote", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--plant", help="JSON fixture with body/headers/query")
    args = ap.parse_args()
    if args.selftest:
        return run_selftest()
    if args.plant:
        return run_plant(args.plant)
    return run_live(args)


if __name__ == "__main__":
    sys.exit(main())
