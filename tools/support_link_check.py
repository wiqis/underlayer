#!/usr/bin/env python3
"""I11 — the public support channel is reachable and linked exactly once.

Checks the served artifact, not just the source:
  * GET /support is 200 and names the channel, a named owner, a published
    response-time target and a mailto: support@wiqis.com link;
  * every public page that draws the shared web nav footer has exactly ONE
    href="/support" (the footer is the single insertion point);
  * F0's /privacy names the same channel — consistency is checked, the legal
    page itself is not edited here.

Usage:
    python tools/support_link_check.py --base http://localhost:9044
    python tools/support_link_check.py --base http://localhost:9044 --plant plant.json
    python tools/support_link_check.py --selftest

Safety: stdlib only, explicit timeouts, no shell. A non-local base is refused
unless --allow-remote is passed explicitly.
"""
import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

TIMEOUT = 15
SUPPORT_HREF = re.compile(r'href=["\']/support["\']')
CONTENT = re.compile(r'href=["\']mailto:support@wiqis\.com["\']')
PAGES = ('/', '/courses', '/learning-path', '/search', '/settings')
REQUIRED = ('Supported channels', 'Waqas Tahir', 'two business days',
            'mailto:support@wiqis.com')


def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'support-link-check/1'})
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        return response.status, response.read().decode('utf-8', 'replace')


def link_failures(html):
    """Return a list of reasons this page is not a good support-footer page."""
    problems = []
    count = len(SUPPORT_HREF.findall(html))
    if count != 1:
        problems.append('expected exactly 1 href="/support", found %d' % count)
    if not CONTENT.search(html):
        problems.append('no mailto:support@wiqis.com in the footer')
    return problems


def support_page_failures(html):
    problems = []
    for needle in REQUIRED:
        if needle not in html:
            problems.append('/support is missing %r' % needle)
    return problems


def is_local(base):
    host = urllib.parse.urlsplit(base).hostname or ''
    return host in ('localhost', '127.0.0.1', '::1')


def run_live(args):
    base = args.base.rstrip('/')
    if not is_local(base) and not args.allow_remote:
        print('REFUSED: non-local base %s (pass --allow-remote to override)' % base)
        return 2
    failures = []
    try:
        status, html = fetch(base + '/support')
    except (urllib.error.URLError, OSError) as exc:
        print('FAIL /support: %s' % exc)
        return 1
    if status != 200:
        failures.append('/support HTTP %s' % status)
    else:
        for problem in support_page_failures(html):
            failures.append(problem)
        print('/support: 200, %d required facts present' %
              (len(REQUIRED) - len(support_page_failures(html))))
    checked = 0
    for path in PAGES:
        try:
            page_status, page_html = fetch(base + path)
        except (urllib.error.URLError, OSError) as exc:
            failures.append('%s: %s' % (path, exc))
            continue
        if page_status != 200:
            failures.append('%s HTTP %s' % (path, page_status))
            continue
        page_problems = link_failures(page_html)
        failures.extend('%s: %s' % (path, p) for p in page_problems)
        if not page_problems:
            checked += 1
    print('shared footer on public pages: %d/%d with exactly one support link'
          % (checked, len(PAGES)))
    # F0 owns pages_legal.ch; this package must not edit it. The consistency
    # probe is therefore a visible WARNING by default and a hard gate only with
    # --require-privacy-channel, so a known upstream gap cannot silently vanish
    # but also cannot block a package that does not own the file.
    try:
        _, privacy = fetch(base + '/privacy')
        if 'support@wiqis.com' not in privacy:
            message = ('/privacy does not name support@wiqis.com (it currently '
                       'says "Privacy questions can be raised through the Help page")')
            if args.require_privacy_channel:
                failures.append(message)
            else:
                print('WARNING ' + message + ' — F0/pages_legal.ch owns the fix')
        else:
            print('/privacy channel consistency: OK (read-only)')
    except (urllib.error.URLError, OSError) as exc:
        failures.append('/privacy: %s' % exc)
    for item in failures:
        print('FAIL ' + item)
    print('SUPPORT LINK CHECK %d failure(s)' % len(failures))
    return 1 if failures else 0


def run_selftest():
    good = ('<a href="/support">Contact support</a> '
            '<a href="mailto:support@wiqis.com">support@wiqis.com</a>')
    planted = [
        ('missing link', '<a href="mailto:support@wiqis.com">mail</a>'),
        ('duplicate link', good + ' <a href="/support">again</a>'),
        ('missing mailto', '<a href="/support">Contact support</a>'),
    ]
    ok = not link_failures(good)
    for label, html in planted:
        failed = bool(link_failures(html))
        print(('SELFTEST PASS: %s rejected' % label) if failed else
              ('FAIL SELFTEST VACUOUS: %s accepted' % label))
        ok = ok and failed
    print('SUPPORT LINK SELFTEST %s' % ('3/3 plants rejected' if ok else 'incomplete'))
    return 0 if ok else 1


def run_plant(path):
    fixture = json.loads(open(path, encoding='utf-8').read())
    html = fixture.get('html', '')
    problems = (support_page_failures(html) if fixture.get('kind') == 'support-page'
                else link_failures(html))
    for item in problems:
        print('FAIL ' + item)
    print('PLANT %d failure(s)' % len(problems))
    return 1 if problems else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--base', default='http://localhost:9044')
    ap.add_argument('--allow-remote', action='store_true',
                    help='explicit opt-in for a non-local base URL')
    ap.add_argument('--require-privacy-channel', action='store_true',
                    help='fail when /privacy does not name support@wiqis.com')
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--plant', help='JSON fixture with an html field')
    args = ap.parse_args()
    if args.selftest:
        return run_selftest()
    if args.plant:
        return run_plant(args.plant)
    return run_live(args)


if __name__ == '__main__':
    sys.exit(main())
