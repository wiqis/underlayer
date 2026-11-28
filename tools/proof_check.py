#!/usr/bin/env python3
"""G8 — server-rendered public proof of work, no JS, honouring visibility.

Evaluates the SERVED HTML, not the source:
  * no "Loading..." shell and no client-only numbers;
  * completed courses, mastered concepts and minutes are present as text;
  * issued certificates link to /certificates/:id;
  * a private profile is not published (404, never a data-bearing page);
  * the page names the existing /api/progress/shared/:token surface and does
    not introduce a social graph (no follow/feed/message endpoints).

With --seed the tool registers a disposable shadow learner on a local server,
sets a username, flips visibility, and probes the real route. With --db it can
also insert one certificate row into that throwaway database to assert the
certificate link on the served page.

Safety: stdlib only, explicit timeouts, no shell, no remote base without
--allow-remote. Negative plants via --selftest / --plant.
"""
import argparse
import json
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

TIMEOUT = 15
SHELL = re.compile(r'id="displayName">\s*Loading\.{3}', re.I)
CERT_LINK = re.compile(r'href="/certificates/([^"]+)"')
STAT_VALUE = re.compile(r'class="proof-value">([^<]+)<')


def fetch(url, data=None, headers=None, method=None):
    raw = json.dumps(data).encode("utf-8") if data is not None else None
    hdrs = {"User-Agent": "proof-check/1"}
    if data is not None:
        hdrs["Content-Type"] = "application/json"
    hdrs.update(headers or {})
    req = urllib.request.Request(url, data=raw, headers=hdrs, method=method)
    with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
        return response.status, response.read().decode("utf-8", "replace"), dict(response.headers.items())


def is_local(base):
    return (urllib.parse.urlsplit(base).hostname or "") in ("localhost", "127.0.0.1", "::1")


def evaluate(html, expected=None):
    problems = []
    expected = expected or {}
    if SHELL.search(html):
        problems.append("page still contains the Loading... shell")
    if 'class="proof-stats"' not in html:
        problems.append("no server-rendered statistics section")
    values = STAT_VALUE.findall(html)
    if len(values) < 3:
        problems.append("expected three statistic values, found %d" % len(values))
    for label in ("Courses completed", "Concepts mastered", "Minutes studied"):
        if label not in html:
            problems.append("missing statistic label %r" % label)
    cert_ids = CERT_LINK.findall(html)
    wanted_cert = expected.get("certificate_id")
    if wanted_cert and wanted_cert not in cert_ids:
        problems.append("issued certificate %s is not linked" % wanted_cert)
    if "No certificates have been issued" not in html and not cert_ids:
        problems.append("certificate section has neither links nor an honest empty state")
    wanted_name = expected.get("display_name")
    if wanted_name and wanted_name not in html:
        problems.append("display name %r is not in the served HTML" % wanted_name)
    if "/api/progress/shared/:token" not in html:
        problems.append("page does not name the existing progress-share surface")
    for forbidden in ("/api/users/follow", "/api/feed", "/api/messages"):
        if forbidden in html:
            problems.append("social surface introduced: %s" % forbidden)
    return problems


def run_selftest():
    good = ('<main><h1>Proof Learner</h1>'
            '<section class="proof-stats">'
            '<span class="proof-value">1</span><span>Courses completed</span>'
            '<span class="proof-value">4</span><span>Concepts mastered</span>'
            '<span class="proof-value">35</span><span>Minutes studied</span>'
            '</section><a href="/certificates/abc">certificate</a>'
            '<code>/api/progress/shared/:token</code></main>')
    ok = not evaluate(good, {"certificate_id": "abc", "display_name": "Proof Learner"})
    plants = {
        "client shell": good.replace("<h1>Proof Learner</h1>", '<h1 id="displayName">Loading...</h1>'),
        "certificate not linked": good.replace("/certificates/abc", "/certificates/other"),
        "no statistics": good.replace('class="proof-stats"', 'class="empty"'),
        "social graph": good + '<a href="/api/users/follow">follow</a>',
    }
    for label, html in plants.items():
        bad = evaluate(html, {"certificate_id": "abc", "display_name": "Proof Learner"})
        print(("SELFTEST PASS: %s rejected" % label) if bad else
              ("FAIL SELFTEST VACUOUS: %s accepted" % label))
        ok = ok and bool(bad)
    print("PROOF SELFTEST %s" % ("4/4 plants rejected" if ok else "incomplete"))
    return 0 if ok else 1


def run_plant(path):
    fixture = json.loads(Path(path).read_text(encoding="utf-8"))
    problems = evaluate(fixture.get("html", ""), fixture.get("expected", {}))
    for item in problems:
        print("FAIL " + item)
    print("PLANT %d failure(s)" % len(problems))
    return 1 if problems else 0


def seed_learner(base):
    suffix = str(int(time.time() * 1000))
    email = "proof-%s@example.test" % suffix
    username = "proof_" + suffix[-8:]
    status, body, _ = fetch(base + "/api/auth/register",
                            {"email": email, "password": "proof-pass-123",
                             "name": "Proof Learner"})
    if status != 200:
        return None, None, "register HTTP %d: %s" % (status, body[:200])
    token = json.loads(body).get("session_token", "")
    status, body, _ = fetch(base + "/api/user/profile",
                            {"username": username, "visibility": "public"},
                            {"Authorization": "Bearer " + token}, method="PUT")
    if status != 200:
        return None, None, "profile update HTTP %d: %s" % (status, body[:200])
    return username, token, None


def insert_certificate(db_path, token, course_id="elf"):
    conn = sqlite3.connect(db_path, timeout=10)
    try:
        row = conn.execute(
            "SELECT learner_id FROM auth_sessions WHERE token_hash = ? LIMIT 1",
            (__import__("hashlib").sha256(token.encode()).hexdigest(),)).fetchone()
        if not row:
            return None
        learner_id = row[0]
        cert_id = "proofcert" + str(int(time.time() * 1000))
        conn.execute(
            "INSERT OR REPLACE INTO certificates "
            "(id, learner_id, course_id, learner_name, course_title, completion_date, certificate_url, created_at) "
            "VALUES (?, ?, ?, ?, ?, date('now'), ?, strftime('%s','now'))",
            (cert_id, learner_id, course_id, "Proof Learner", "Executable and Linkable Format",
             "/certificates/" + cert_id))
        conn.commit()
        return cert_id
    finally:
        conn.close()


def run_live(args):
    base = args.base.rstrip("/")
    if not is_local(base) and not args.allow_remote:
        print("REFUSED: non-local base (pass --allow-remote)")
        return 2
    failures = []
    if not args.seed:
        print("live proof: SKIPPED (pass --seed to register a disposable learner)")
        return 0
    username, token, err = seed_learner(base)
    if err:
        print("FAIL " + err)
        return 1
    cert_id = None
    if args.db:
        cert_id = insert_certificate(args.db, token)
        print("seeded certificate: %s" % (cert_id or "none"))
    try:
        status, html, _ = fetch(base + "/u/" + username)
    except (urllib.error.URLError, OSError) as exc:
        print("FAIL /u/%s: %s" % (username, exc))
        return 1
    print("GET /u/%s -> %d" % (username, status))
    if status != 200:
        failures.append("public profile HTTP %d" % status)
    else:
        failures.extend(evaluate(html, {"certificate_id": cert_id,
                                        "display_name": "Proof Learner"}))
    # Visibility is the existing toggle: private must not publish the record.
    _, _, _ = fetch(base + "/api/user/profile",
                    {"visibility": "private"},
                    {"Authorization": "Bearer " + token}, method="PUT")
    try:
        status2, html2, _ = fetch(base + "/u/" + username)
    except urllib.error.HTTPError as exc:
        # 404 is the CORRECT answer for a private profile — the route handler
        # honours the visibility toggle. Older checkers treated any HTTPError
        # as a transport failure, which made a correct 404 look like a red.
        if exc.code != 404:
            failures.append("private profile probe: HTTP %d" % exc.code)
        status2, html2 = exc.code, ""
    except (urllib.error.URLError, OSError) as exc:
        failures.append("private profile probe: %s" % exc)
        status2, html2 = 0, ""
    if status2 == 200 and "class=\"proof-stats\"" in html2:
        failures.append("private profile still renders proof data")
    elif status2 not in (404, 200):
        failures.append("private profile returned %d, expected 404 or a non-data 200" % status2)
    print("private profile -> %d (data-bearing page: %s)" %
          (status2, "yes" if 'class="proof-stats"' in html2 else "no"))
    for item in failures:
        print("FAIL " + item)
    print("PROOF CHECK %d failure(s)" % len(failures))
    return 1 if failures else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--base", default="http://localhost:9046")
    ap.add_argument("--allow-remote", action="store_true")
    ap.add_argument("--seed", action="store_true")
    ap.add_argument("--db", help="throwaway DB path for certificate seeding")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--plant", help="JSON fixture with html and expected fields")
    args = ap.parse_args()
    if args.selftest:
        return run_selftest()
    if args.plant:
        return run_plant(args.plant)
    return run_live(args)


if __name__ == "__main__":
    sys.exit(main())
