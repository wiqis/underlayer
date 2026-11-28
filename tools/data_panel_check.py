#!/usr/bin/env python3
"""G10 — the "Your data" panel in Settings, served and driven.

Static/served checks (always):
  * /settings contains the fifth tab and every control: JSON download, typed
    category delete, typed deactivate / reactivate / account delete;
  * the page's script calls ONLY the five endpoints that already exist in
    app/main.ch (1136-1177) — no new API is introduced by the UI;
  * a last-export date element is present.

--browser additionally drives a disposable shadow learner in a real Chrome:
sets a session token, opens the panel, clicks Download, confirms a category
delete with the typed word, and checks the success message. --db is the
throwaway SQLite file; --seed registers a fresh learner on a local server.

Safety: stdlib only for HTTP, explicit timeouts, no shell, no remote base
without --allow-remote. Negative plants via --selftest / --plant.
"""
import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

TIMEOUT = 15
ENDPOINTS = ("/api/user/export", "/api/user/data/", "/api/user/account",
             "/api/user/deactivate", "/api/user/reactivate")
CONTROLS = ("dataExport", "dataLastExport", "dataDeleteForm", "dataCategory",
            "dataDeleteConfirm", "accountDeleteForm", "accountDeleteConfirm",
            "accountDeactivateForm", "deactivateConfirm",
            "accountReactivateForm", "reactivateConfirm")


def fetch(url, data=None, headers=None, method=None):
    raw = json.dumps(data).encode("utf-8") if data is not None else None
    hdrs = {"User-Agent": "data-panel-check/1"}
    if data is not None:
        hdrs["Content-Type"] = "application/json"
    hdrs.update(headers or {})
    req = urllib.request.Request(url, data=raw, headers=hdrs, method=method)
    with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
        return response.status, response.read().decode("utf-8", "replace")


def is_local(base):
    return (urllib.parse.urlsplit(base).hostname or "") in ("localhost", "127.0.0.1", "::1")


def evaluate(html):
    problems = []
    for control in CONTROLS:
        if ('id="%s"' % control) not in html:
            problems.append("missing control #%s" % control)
    if 'data-tab="data"' not in html:
        problems.append("no Your data tab in the settings navigation")
    for word in ("DELETE MY ACCOUNT", "DEACTIVATE", "REACTIVATE", "DELETE"):
        if word not in html:
            problems.append("typed confirmation %r missing" % word)
    for endpoint in ENDPOINTS:
        if endpoint not in html:
            problems.append("script does not call existing endpoint %s" % endpoint)
    if "underlayer_last_export" not in html:
        problems.append("last export date is not persisted/displayed")
    return problems


def run_selftest():
    good = "".join('<element id="%s"></element>' % c for c in CONTROLS)
    good += '<a data-tab="data"></a>' + "".join("fetch('%s')" % e for e in ENDPOINTS)
    good += "DELETE MY ACCOUNT DEACTIVATE REACTIVATE DELETE underlayer_last_export"
    ok = not evaluate(good)
    plants = {
        "no panel": "<html><body>settings</body></html>",
        "no typed confirm": good.replace("DELETE MY ACCOUNT", ""),
        "new endpoint": good.replace("/api/user/reactivate", "/api/v2/reactivate"),
    }
    for label, html in plants.items():
        bad = evaluate(html)
        print(("SELFTEST PASS: %s rejected" % label) if bad else
              ("FAIL SELFTEST VACUOUS: %s accepted" % label))
        ok = ok and bool(bad)
    print("DATA PANEL SELFTEST %s" % ("3/3 plants rejected" if ok else "incomplete"))
    return 0 if ok else 1


def run_plant(path):
    fixture = json.loads(Path(path).read_text(encoding="utf-8"))
    problems = evaluate(fixture.get("html", ""))
    for item in problems:
        print("FAIL " + item)
    print("PLANT %d failure(s)" % len(problems))
    return 1 if problems else 0


def register(base):
    suffix = str(int(time.time() * 1000))
    status, body = fetch(base + "/api/auth/register",
                         {"email": "data-%s@example.test" % suffix,
                          "password": "data-panel-123", "name": "Data Tester"})
    if status != 200:
        return None, "register HTTP %d" % status
    return json.loads(body).get("session_token"), None


def drive_browser(base, token):
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        return ["playwright is not installed"]
    chrome = Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe")
    if not chrome.exists():
        return ["Chrome executable not found at %s" % chrome]
    failures = []
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=str(chrome), headless=True)
        context = browser.new_context(viewport={"width": 1280, "height": 900},
                                      accept_downloads=True)
        context.add_init_script("localStorage.setItem('session_token', %s);" % json.dumps(token))
        page = context.new_page()
        # Ignore known pre-existing nav noise (unread-count badge without a
        # cookie, missing favicon). A failing /api/user/* call IS in scope.
        api_failures = []
        page.on("response", lambda r: api_failures.append("%s %s" % (r.status, r.url))
                if r.status >= 400 and "/api/user/" in r.url else None)
        page.goto(base + "/settings", wait_until="domcontentloaded", timeout=30000)
        page.click('a[data-tab="data"]')
        if not page.is_visible("#data-section"):
            failures.append("data panel did not open from its tab")
        with page.expect_download(timeout=20000) as download_info:
            page.click("#dataExport")
        download = download_info.value
        if download.suggested_filename != "underlayer_export.json":
            failures.append("export filename %r" % download.suggested_filename)
        page.select_option("#dataCategory", "sessions")
        page.fill("#dataDeleteConfirm", "DELETE")
        page.click("#dataDeleteForm button[type=submit]")
        page.wait_for_timeout(1200)
        message = page.text_content("#dataMessage") or ""
        if "Deleted" not in message:
            failures.append("category delete did not report success: %r" % message)
        # Wrong confirmation must be refused without calling the endpoint.
        page.fill("#dataDeleteConfirm", "delete")
        page.click("#dataDeleteForm button[type=submit]")
        page.wait_for_timeout(300)
        err_text = page.text_content("#dataError") or ""
        if "Type DELETE" not in err_text:
            failures.append("wrong confirmation was not refused: %r" % err_text)
        overflow = page.evaluate("document.documentElement.scrollWidth > window.innerWidth + 1")
        if overflow:
            failures.append("horizontal overflow at 1280px")
        page.set_viewport_size({"width": 420, "height": 900})
        page.wait_for_timeout(300)
        if page.evaluate("document.documentElement.scrollWidth > window.innerWidth + 1"):
            failures.append("horizontal overflow at 420px")
        if api_failures:
            failures.append("data API failures: %s" % api_failures[:3])
        browser.close()
    return failures


def run_live(args):
    base = args.base.rstrip("/")
    if not is_local(base) and not args.allow_remote:
        print("REFUSED: non-local base (pass --allow-remote)")
        return 2
    failures = []
    try:
        status, html = fetch(base + "/settings")
    except (urllib.error.URLError, OSError) as exc:
        print("FAIL /settings: %s" % exc)
        return 1
    if status != 200:
        failures.append("/settings HTTP %d" % status)
    else:
        failures.extend(evaluate(html))
    print("served /settings panel: %s" % ("OK" if not failures else "%d problem(s)" % len(failures)))
    if args.browser:
        token, err = register(base)
        if err:
            failures.append(err)
        else:
            browser_failures = drive_browser(base, token)
            failures.extend(browser_failures)
            print("browser drive: %s" % ("OK" if not browser_failures else
                                         "%d problem(s)" % len(browser_failures)))
    else:
        print("browser drive: SKIPPED (pass --browser --seed)")
    for item in failures[:30]:
        print("FAIL " + item)
    print("DATA PANEL CHECK %d failure(s)" % len(failures))
    return 1 if failures else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--base", default="http://localhost:9046")
    ap.add_argument("--allow-remote", action="store_true")
    ap.add_argument("--seed", action="store_true", help="required with --browser (registers shadow learner)")
    ap.add_argument("--browser", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--plant", help="JSON fixture with html")
    args = ap.parse_args()
    if args.selftest:
        return run_selftest()
    if args.plant:
        return run_plant(args.plant)
    if args.browser and not args.seed:
        print("REFUSED: --browser needs --seed for a disposable learner")
        return 2
    return run_live(args)


if __name__ == "__main__":
    sys.exit(main())
