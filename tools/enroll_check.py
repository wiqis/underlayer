#!/usr/bin/env python3
"""enroll_check.py -- the Enrol control has to be RIGHT in all four states.

P1 7.1.23 said "enrollments API has no UI consumer". This checks that it now has
one, and that the control tells the truth in every state a reader can be in.

FOUR STATES, because the control is not a button with one behaviour:

  1. SIGNED OUT      no control at all.  The sign-in advisory on the page already
                     says why, and saying it twice teaches the reader to skip it.
  2. SIGNED IN, NOT ENROLLED   the button, plus the script that asks can-enroll
                     before enabling itself.
  3. SIGNED IN, ENROLLED       the STATE, not the button -- and no script, because
                     there is nothing to press.  A page carrying a click handler
                     for a button it does not have is how dead JS accumulates.
  4. PREREQUISITE UNMET        the button DISABLED and the reason shown, naming
                     the course and the bar.

State 4 is the one that only works because of a second fix, and both were needed:

  * the button shipped with no prerequisite feedback at all, which is half of
    what P1 7.1.23 asks for; and
  * `course_prerequisites` held ZERO rows even though 32 of 34 manifests declare
    `dependencies`, so GET /api/courses/:id/can-enroll answered
    `{"can_enroll": true}` for every course on the platform.  A shipped feature
    that always says yes is worse than an absent one, because the checklist says
    it exists.

So this asserts the button's copy AND that the table behind it is populated --
because the second bug was invisible from the UI and only the table showed it.

AND IT EXECUTES THE SCRIPT, for the same reason as every other check in this
repository that matters: state 4 is decided in JavaScript, and a page that
contains the right elements proves nothing about what the reader sees.  The
inline <script> is extracted from the served HTML and run in node against the
real endpoints, then the DOM is read back.

Usage:
    python3 tools/enroll_check.py [--port 9000] [--selftest-only]
"""
import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.environ.get('UL_DB', os.path.join(ROOT, 'underlayer.db'))

checks = 0
failures = []
section = ''


def sec(name):
    global section
    section = name
    print('\n' + '=' * 74)
    print(name)
    print('=' * 74)


def ok(name, cond, detail=''):
    global checks
    checks += 1
    if cond:
        print('  PASS  ' + name)
    else:
        failures.append(section + ' / ' + name)
        print('  FAIL  ' + name + (('  -- ' + detail) if detail else ''))


def clear_rate_limits():
    try:
        c = sqlite3.connect(DB, timeout=20)
        c.execute('DELETE FROM rate_limits')
        c.commit()
        c.close()
    except Exception:
        pass


def http(method, path, port, token=None, body=None):
    url = 'http://localhost:%d%s' % (port, path)
    data = None
    headers = {}
    if body is not None:
        data = json.dumps(body).encode()
        headers['Content-Type'] = 'application/json'
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            return r.status, r.read(600000).decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        return e.code, e.read(200000).decode('utf-8', 'replace')
    except Exception as e:  # noqa: BLE001
        return 0, 'TRANSPORT: %s' % e


def register(port, tag):
    clear_rate_limits()
    email = 'enrolchk-%s-%d@t.com' % (tag, int(__import__('time').time()))
    st, body = http('POST', '/api/auth/register', port, body={
        'email': email, 'password': 'password123', 'name': 'Enrol ' + tag})
    if st != 200:
        return None, 'HTTP %s %s' % (st, body[:120])
    return json.loads(body).get('session_token'), email


def courses_with_deps():
    out = []
    for d in sorted(os.listdir(os.path.join(ROOT, 'courses'))):
        mf = os.path.join(ROOT, 'courses', d, 'manifest.json')
        if not os.path.isfile(mf):
            continue
        m = json.load(open(mf, encoding='utf-8'))
        if m.get('dependencies'):
            out.append((m['id'], m['dependencies']))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=9000)
    args = ap.parse_args()
    port = args.port

    st, _ = http('GET', '/api/health', port)
    if st != 200:
        print('FAIL: no server on %d.  NOT a pass.' % port)
        return 2

    deps = courses_with_deps()

    # ---------------------------------------------------------------- 1
    sec('1. the table behind the feedback is actually populated')
    # Invisible from the UI: can-enroll answered true for everything because the
    # table was empty. A button that always enables is not a bug a reader reports.
    try:
        c = sqlite3.connect(DB, timeout=20)
        rows = c.execute('SELECT COUNT(*) FROM course_prerequisites').fetchone()[0]
        pcts = [r[0] for r in
                c.execute('SELECT DISTINCT min_mastery_pct FROM course_prerequisites')]
        c.close()
    except Exception as e:  # noqa: BLE001
        rows, pcts = -1, []
        ok('course_prerequisites is readable', False, str(e))
    declared = sum(len(d) for _, d in deps)
    ok('prerequisites were seeded from the manifests', rows > 0,
       'table holds %d rows; %d courses declare %d dependencies'
       % (rows, len(deps), declared))
    ok('every manifest dependency has a row', rows >= declared,
       '%d rows for %d declared dependencies' % (rows, declared))
    ok('every seeded bar is the documented 70%%', pcts == [70],
       'distinct values: %r (repository/src/prerequisites_seed.ch)' % (pcts,))

    # ---------------------------------------------------------------- 2
    sec('2. can-enroll answers NO, and names the course and the bar')
    tok, _ = register(port, 'pre')
    if not tok:
        ok('could register a learner', False, 'cannot test without a session')
        return 1
    blocked = [cid for cid, d in deps if d]
    target = blocked[0] if blocked else 'elf'
    st, body = http('GET', '/api/courses/%s/can-enroll' % target, port, token=tok)
    try:
        j = json.loads(body)
    except Exception:  # noqa: BLE001
        j = {}
    ok('a course with prerequisites says can_enroll:false for a fresh learner',
       j.get('can_enroll') is False,
       '%s -> %s' % (target, body[:160]))
    missing = j.get('missing') or []
    ok('and names what is missing', len(missing) >= 1, 'missing=%r' % (missing,))
    ok('including the mastery bar it demands',
       bool(missing) and 'min_mastery_pct' in missing[0],
       'missing[0]=%r' % (missing[0] if missing else None))

    # A course with no prerequisites must still say yes, or the control would
    # disable enrolment everywhere and nobody would notice until every button on
    # the platform was greyed out.
    noc = [cid for cid in os.listdir(os.path.join(ROOT, 'courses'))
           if os.path.isfile(os.path.join(ROOT, 'courses', cid, 'manifest.json'))
           and not json.load(open(os.path.join(ROOT, 'courses', cid,
                                                'manifest.json'),
                                  encoding='utf-8')).get('dependencies')]
    if noc:
        st, body = http('GET', '/api/courses/%s/can-enroll' % noc[0], port,
                        token=tok)
        try:
            j2 = json.loads(body)
        except Exception:  # noqa: BLE001
            j2 = {}
        ok('a course with NO prerequisites still says true',
           j2.get('can_enroll') is True, '%s -> %s' % (noc[0], body[:120]))

    # ---------------------------------------------------------------- 3
    sec('3. the control, in the three states a reader can be in')
    free = noc[0] if noc else 'elf'

    # -- signed out: nothing at all
    st, page = http('GET', '/courses/%s' % free, port)
    ok('a signed-out course page has NO enrol control',
       'enroll-btn' not in page and 'enroll-state' not in page,
       'signed-out reader sees a button they cannot use')
    ok('and no orphaned enrol script',
       'can-enroll' not in page,
       'a script for a control that is not there is dead JavaScript')

    # -- signed in, not enrolled: the button AND the script
    st, page = http('GET', '/courses/%s' % free, port, token=tok)
    ok('a signed-in, not-enrolled reader gets the button',
       'id="enroll-btn"' in page, 'no #enroll-btn in the markup')
    ok('and the script that wires it', 'can-enroll' in page,
       'a button with no handler')
    ok('the reason element ships HIDDEN',
       re.search(r'id="enroll-why"[^>]*\shidden', page) is not None,
       'it must not show an excuse before there is one')
    ok('the course page is still a whole document',
       page.rstrip().endswith('</html>') and len(page) > 5000,
       '%d bytes, ends with </html>: %s' % (len(page),
                                            page.rstrip().endswith('</html>')))

    # -- signed in, enrolled: the STATE, and no script
    st, _ = http('POST', '/api/courses/%s/enroll' % free, port, token=tok)
    st, page = http('GET', '/courses/%s' % free, port, token=tok)
    ok('after enrolling the control becomes the STATE',
       'id="enroll-state"' in page and 'id="enroll-btn"' not in page,
       'enrolled reader still gets a button')
    m = re.search(r'id="enroll-state"[^>]*>([^<]*)<', page)
    ok('and the state says when', bool(m) and 'since' in m.group(1).lower(),
       'state text: %r' % (m.group(1) if m else None))
    ok('and there is no script for a control that is gone',
       'can-enroll' not in page,
       'the button is gone but its handler is still on the page')

    # ---------------------------------------------------------------- 4
    sec('4. the script actually disables the button and explains why')
    # States 1-3 are MARKUP. This state is decided in JavaScript, and a page
    # containing the right elements proves nothing about what the reader sees.
    # So the served <script> is extracted and run in node against the real API,
    # and the resulting DOM is read back.
    st, page = http('GET', '/courses/%s' % target, port, token=tok)
    m = re.search(r'<script>(.*?enroll-btn.*?)</script>', page, re.S)
    if not m:
        ok('the enrol script could be extracted', False,
           'no <script> containing enroll-btn on /courses/%s' % target)
    else:
        ok('the enrol script could be extracted', True,
           '%d bytes of inline script' % len(m.group(1)))
        # The script goes in ITS OWN FILE and the runner reads it with
        # fs.readFileSync.  Two earlier versions embedded it in the runner's
        # source -- once by interpolating it raw, and once inside a template
        # literal with hand-written escaping.  Both reported failures about the
        # ENROL BUTTON that were really failures of the harness:
        #
        #   * raw interpolation produced `const COURSE = a64abi,` and died
        #     immediately, because a bare identifier is not a string;
        #   * doubling backslashes to survive a template literal turned the
        #     script's own `\'enroll-state\'` into `\'enroll-state\'`, which
        #     JS reads as a backslash followed by the end of the string.
        #
        # Reading a file needs no escaping at all, and the script under test is
        # then byte-for-byte what the browser gets.
        script_path = os.path.join('/tmp', 'ul_enrol_script.js')
        with open(script_path, 'w', encoding='utf-8') as f:
            f.write(m.group(1))
        runner = os.path.join('/tmp', 'ul_enrol_run.js')
        with open(runner, 'w', encoding='utf-8') as f:
            f.write(ENROL_RUNNER
                    .replace('__SCRIPT_PATH__', json.dumps(script_path))
                    .replace('__PORT__', json.dumps(port))
                    .replace('__COURSE__', json.dumps(target))
                    .replace('__TOKEN__', json.dumps(tok)))
        # It must PARSE.  A served <script> the browser refuses to run is
        # silent: the page answers 200, the button is there, and nothing happens
        # when it is pressed.  This caught a real one -- Chemical's escaping
        # collapsed the quotes inside a nested HTML string, so every course page
        # shipped a syntax error and the button did nothing.
        pj = subprocess.run(['node', '--check', script_path],
                            capture_output=True, text=True, timeout=60)
        ok('the served enrol script PARSES', pj.returncode == 0,
           ((pj.stderr.strip().splitlines() or [''])[0])[:160])
        out = subprocess.run(['node', runner], capture_output=True, text=True,
                             timeout=90)
        result = {}
        for line in out.stdout.splitlines():
            if line.startswith('RESULT '):
                result = json.loads(line[7:])
        if result.get('bootErr'):
            ok('the enrol script ran at all', False,
               'the harness could not even evaluate it: %s' % result['bootErr'])
        ok('the script disabled the button',
           result.get('disabled') is True,
           'disabled=%r (button should be off: the prerequisite is unmet); '
           'script said: %r' % (result.get('disabled'), result))
        why = result.get('why') or ''
        ok('and it told the reader which course to finish first',
           target in why or (deps and dict(deps).get(target, [''])[0] in why),
           'reason shown: %r' % why)
        ok('and named the bar', '70' in why or '%' in why,
           'reason shown: %r' % why)
        ok('and unhid the reason element', result.get('whyHidden') is False,
           'hidden=%r' % result.get('whyHidden'))
        if out.returncode != 0 and not result:
            print('       node said: ' + (out.stderr.strip()[:300] or '?'))

    print('\n' + '=' * 74)
    if not failures:
        print('enroll_check: ALL %d CHECKS PASSED' % checks)
    else:
        print('enroll_check: %d of %d CHECKS FAILED' % (len(failures), checks))
        for f in failures:
            print('  FAILED: %s' % f)
    return 0 if not failures else 1


# The node harness.  Runs the page's own inline script against the real API,
# with a DOM small enough to be obviously correct.  It prints one RESULT line
# that this checker parses, so a crash is visible rather than a silent pass.
ENROL_RUNNER = r'''
const vm = require('vm');
const fs = require('fs');
// Read verbatim: the script under test is byte-for-byte what the browser gets,
// which is the only way this harness can claim to be testing it.
const SCRIPT = fs.readFileSync(__SCRIPT_PATH__, 'utf8');
const PORT = __PORT__, COURSE = __COURSE__, TOKEN = __TOKEN__;

// What a real browser would hold after a successful login. Only 'session_token'
// is in here, because that is the only key pages_auth.ch writes -- see the note
// on the localStorage stub below.
const STORE = { 'session_token': TOKEN };

function el(tag) {
  return { tagName: tag, className: '', textContent: '', hidden: true,
           children: [], attrs: {}, disabled: false,
           appendChild(c) { this.children.push(c); return c; },
           setAttribute(k, v) { this.attrs[k] = v; },
           addEventListener(ev, fn) { this._ev = ev; this._fn = fn; },
           click() { if (this._fn) { this._fn(); } } };
}
const REG = new Map();
function get(id) {
  if (!REG.has(id)) {
    const e = el('div');
    if (id === 'enroll-why') { e.hidden = true; }
    if (id === 'enroll-btn') { e.disabled = false; e.textContent = 'Enroll'; }
    REG.set(id, e);
  }
  return REG.get(id);
}
const sandbox = {
  console,
  document: { getElementById: get, createElement: el,
              addEventListener: () => {} },
  window: {},
  // A REAL localStorage, not `getItem: () => TOKEN`.  The stub answered the
  // same value for EVERY key, so it could not tell a script reading the right
  // key from one reading a key nothing writes -- which is exactly the bug this
  // check missed: the served script asked for 'ul_session_token' while login
  // writes 'session_token', and with a stub that returns the token for any
  // string, both the can-enroll call and the enroll POST carried a valid
  // Authorization header and every state came out right.
  //
  // KEYING THE STUB IS THE ASSERTION.  A key that is not in STORE behaves the
  // way a browser behaves when it is absent: undefined.  Now the script can
  // only pass by asking for the name the rest of the product writes.
  localStorage: { getItem: (k) => (Object.prototype.hasOwnProperty.call(STORE, k) ? STORE[k] : undefined),
                  setItem: () => {} },
  encodeURIComponent, Promise, JSON, String, Number, Math, Array, Object,
  fetch: (u, o) => fetch('http://localhost:' + PORT + u, o),
  setTimeout, clearTimeout,
};
// The script reads window.localStorage in some builds and bare localStorage in
// others; give it both.
sandbox.window.localStorage = sandbox.localStorage;
vm.createContext(sandbox);
let bootErr = null;
try { vm.runInContext(SCRIPT, sandbox); } catch (e) { bootErr = String(e); }

setTimeout(() => {
  const btn = get('enroll-btn'), why = get('enroll-why');
  console.log('RESULT ' + JSON.stringify({
    disabled: !!btn.disabled,
    buttonText: btn.textContent,
    why: why.textContent || '',
    whyHidden: !!why.hidden,
    bootErr: bootErr,
  }));
}, 3000);
'''


if __name__ == '__main__':
    sys.exit(main())
