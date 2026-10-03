#!/usr/bin/env python3
"""progress_check.py -- prove that opening a lesson page RECORDS something.

THE DEFECT THIS CHECK EXISTS FOR
-------------------------------
Measured 2026-10-02 against the running server: a learner registered, signed
in, opened three lesson pages, and GET /api/progress came back byte-identical
before and after.  The whole read side -- FSRS scheduling, streaks,
achievements, /dashboard, /progress -- is downstream of one event, "a learner
opened a concept", and 407 of the 438 page builders never produced it.  31 did,
each with a private hand-written copy.

This check is the machine gate for that.  It is the thing three source comments
in content/src/ and repository/src/ refer to, so it has to exist and it has to
be able to fail.

WHAT IT DOES, IN ORDER
---------------------
  1. Registers a brand-new learner.  A fresh account every run, so the script
     is order-independent and never passes on state a previous run left behind.
  2. Signs in and keeps the session token.
  3. Asserts GET /api/progress/<course> reports 0% before any read.
  4. Fetches a real lesson page over HTTP and asserts the served HTML carries
     the engagement call -- the function name, the strip element, and exactly
     ONE POST of /api/learning/view.  "Exactly one" is the interesting half:
     325 pages used to carry two reporters and posted every read twice.
  5. DRIVES the page's own script, in Node, in a DOM shim: it executes the
     emitted script with window.location set to the lesson URL and a stub
     fetch, then asserts the script issued exactly one POST /api/learning/view
     with this course and this concept.  This is what makes step 6 honest --
     the request the script would really make is the one that is replayed.
  6. Asserts the POST actually changed the recorded state: the concept appears
     in GET /api/progress/<course>, progress_percentage moves off zero, and
     the second read of the same concept comes back first_time:false.
  7. Asserts the learner's course list, from /api/me/overview, now names the
     course they read -- the enrollments table was empty for every learner on
     the platform before this was wired.
  8. Asserts "which quiz did I fail" is answerable: submits a known-wrong
     answer and reads it back out of /api/exercises/failures by exercise id.
  9. Asserts the course landing page's own bar asks for ITS course and sends
     the session token, because it used to request ELF for all 34 courses and
     report the "demo" learner to every signed-in learner.

HOW IT PROVES IT IS NOT VACUOUS
-------------------------------
A check that passes on the unfixed platform is worse than no check, because it
looks like coverage.  `--prove-non-vacuous` does the following: it copies the
repository to a scratch directory, deletes the one line
`render_lesson_engagement(page)` from content/src/lesson_nav.ch, rebuilds,
serves that copy on its own port, and runs the whole check against it.  The
build MUST fail.  If it does not, this script exits non-zero saying so -- an
assertion it cannot break is an assertion that tests nothing.

The copy is of the WHOLE tree because the engagement call is reached through the
shared nav: you cannot remove it from one page, which is the whole point of
where it lives, so the only way to take it out is to take it out of the one
component all 398 pages render.

Usage:
    python3 tools/progress_check.py
    python3 tools/progress_check.py --base http://localhost:9000
    python3 tools/progress_check.py --prove-non-vacuous

Exit: 0 every assertion held, 1 an assertion failed, 2 bad usage.
"""
import argparse
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CC = os.environ.get('CC') or '/home/wakaztahir/work/Chemical/chemical/cmake-build-debug/TCCCompiler'

# The one line whose removal must break the check.
THE_CALL = 'render_lesson_engagement(page)'
# The functions the served page must expose, and the POST it must make.
FN_START = '__ulStartEngagement'
FN_REPORT = '__ulReportRead'
STRIP_ID = 'ul-progress'
VIEW_PATH = '/api/learning/view'

failures = []
checks = 0


def ok(what):
    global checks
    checks += 1
    print('  PASS  %s' % what)


def bad(what, detail=''):
    global checks
    checks += 1
    print('  FAIL  %s' % what)
    if detail:
        for line in str(detail).splitlines():
            print('          %s' % line)
    failures.append(what)


def section(title):
    print('\n== %s' % title)


# ---------------------------------------------------------------- HTTP helpers

# THE LOGIN LIMITER (web/src/rate_limit.ch) caps /api/auth/register and
# /api/auth/login at 8 attempts per 5 minutes per IP. This script registers and
# signs in, so it trips the cap -- and the failure it produced was "sign in and
# get a session token -> 429", which is the limiter working, not a broken check.
#
# It made this file ORDER-DEPENDENT in the worst way: it passed on a quiet server
# and failed on a busy one, with nothing about the platform having changed. A
# check that passes or fails depending on what ran before it is not a check. So
# the counters are cleared first. The limiter is asserted directly, from a
# known-empty counter, in tools/security_check.py CHECK 14.
DB_PATH = os.environ.get('UL_DB', './underlayer.db')


def clear_rate_limits():
    """Empty the rate_limits table, if it exists. Never raises."""
    try:
        c = sqlite3.connect(DB_PATH, timeout=20)
        c.execute('DELETE FROM rate_limits')
        c.commit()
        c.close()
    except Exception:
        pass


def request(base, path, token=None, method='GET', body=None, timeout=30):
    url = base.rstrip('/') + path
    data = None
    headers = {}
    if body is not None:
        data = json.dumps(body).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read().decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8', 'replace')


def request_json(base, path, token=None, method='GET', body=None):
    st, txt = request(base, path, token=token, method=method, body=body)
    try:
        return st, json.loads(txt)
    except Exception:
        return st, {'_raw': txt[:400]}


def health(base):
    try:
        st, _ = request(base, '/api/health', timeout=5)
        return st == 200
    except Exception:
        return False


def wait_health(base, seconds=40):
    deadline = time.time() + seconds
    while time.time() < deadline:
        if health(base):
            return True
        time.sleep(0.5)
    return False


# ------------------------------------------------------- driving the page's JS

# The engagement script is a browser script: it reads window.location, reads
# localStorage, registers DOMContentLoaded, and calls fetch.  Rather than assert
# on the text of the script, this runs it, in Node, against the smallest shim
# that gives it an honest answer, and reports what it actually did.  If the
# script stops being called, or is called with the wrong concept, or posts
# twice, this is where it shows up -- not as a string comparison that a rename
# would defeat.
DRIVER_JS = r"""
// ---- shim -------------------------------------------------------------
// Small, but faithful enough that the lesson page's own 23KB script runs
// without being rewritten for the test.  Anything this shim fakes badly is
// reported, not hidden: a TypeError out of the script is a FAIL here, because
// a lesson whose script throws is a lesson whose quizzes do not work.
var POSTS = [];
var URLS = [];
var tokens = { 'session_token': process.env.UL_TOKEN || '' };
var listeners = {};
function FakeClassList(el) {
    this._s = {};
    this.add = function(c) { this._s[c] = true; };
    this.remove = function(c) { delete this._s[c]; };
    this.contains = function(c) { return !!this._s[c]; };
    this.toggle = function(c, on) {
        if (on === undefined) { on = !this._s[c]; }
        if (on) { this._s[c] = true; } else { delete this._s[c]; }
        return on;
    };
}
function FakeEl(id) {
    var el = {
        id: id,
        tagName: 'DIV',
        textContent: '',
        innerHTML: '',
        value: '',
        href: '',
        type: '',
        placeholder: '',
        disabled: false,
        hidden: false,
        style: {},
        dataset: {},
        children: [],
        attrs: {},
        parentNode: null,
        parentElement: null,
        nextSibling: null,
        firstChild: null,
        classList: new FakeClassList(el),
        appendChild: function(c) { el.children.push(c); c.parentNode = el; return c; },
        removeChild: function(c) { el.children = el.children.filter(function(x) { return x !== c; }); },
        insertBefore: function(n) { el.children.push(n); n.parentNode = el; return n; },
        setAttribute: function(k, v) { el.attrs[k] = String(v); },
        getAttribute: function(k) { return Object.prototype.hasOwnProperty.call(el.attrs, k) ? el.attrs[k] : null; },
        removeAttribute: function(k) { delete el.attrs[k]; },
        hasAttribute: function(k) { return Object.prototype.hasOwnProperty.call(el.attrs, k); },
        addEventListener: function() {},
        removeEventListener: function() {},
        querySelector: function() { return null; },
        querySelectorAll: function() { return []; },
        closest: function() { return null; },
        matches: function() { return false; },
        focus: function() {},
        blur: function() {},
        click: function() {},
        getBoundingClientRect: function() { return { top: 0, left: 0, width: 0, height: 0 }; }
    };
    return el;
}
var els = {};
global.document = {
    visibilityState: 'visible',
    documentElement: FakeEl('html'),
    head: FakeEl('head'),
    getElementById: function(id) {
        if (!els[id]) { els[id] = FakeEl(id); }
        return els[id];
    },
    querySelector: function(sel) { return FakeEl(sel); },
    querySelectorAll: function() { return []; },
    addEventListener: function(name, fn) { (listeners[name] = listeners[name] || []).push(fn); },
    removeEventListener: function() {},
    createElement: function(tag) { var e = FakeEl('new'); e.tagName = String(tag).toUpperCase(); return e; },
    createTextNode: function(t) { return { nodeValue: t }; },
    createDocumentFragment: function() { return FakeEl('frag'); },
    body: FakeEl('body')
};
global.window = {
    location: { pathname: process.env.UL_PATH || '/' },
    addEventListener: function(name, fn) { (listeners['w_' + name] = listeners['w_' + name] || []).push(fn); },
    matchMedia: function() { return { matches: false }; },
    scrollTo: function() {},
    getComputedStyle: function() { return {}; }
};
global.localStorage = {
    getItem: function(k) { return Object.prototype.hasOwnProperty.call(tokens, k) ? tokens[k] : null; },
    setItem: function(k, v) { tokens[k] = String(v); },
    removeItem: function(k) { delete tokens[k]; }
};
global.fetch = function(url, opts) {
    var o = opts || {};
    URLS.push(url);
    if (o.method && String(o.method).toUpperCase() === 'POST') {
        POSTS.push({ url: url, body: o.body ? JSON.parse(o.body) : null });
    }
    // Resolve with the shape the script expects and let its .then run.
    return Promise.resolve({
        ok: true, status: 200,
        json: function() { return Promise.resolve({ recorded: true, first_time: true }); }
    });
};
global.navigator = { userAgent: 'shim' };

// ---- the page's real script ------------------------------------------
var SRC = require('fs').readFileSync(process.env.UL_JS, 'utf8');
eval(SRC);

// Fire it the way a browser would: DOMContentLoaded, then a non-persisted
// pageshow.  The pageshow handler is guarded on ev.persisted, so a bfcache
// restore must produce NO further post -- asserted below.
(listeners['DOMContentLoaded'] || []).forEach(function(f) { f(); });
(listeners['w_pageshow'] || []).forEach(function(f) { f({ persisted: false }); });
(listeners['w_pageshow'] || []).forEach(function(f) { f({ persisted: true }); });

// Let the promise chains the script started settle.
setTimeout(function() {
    var views = POSTS.filter(function(p) { return String(p.url).indexOf(process.env.UL_VIEW) === 0; });
    console.log(JSON.stringify({
        posts_total: POSTS.length,
        views: views,
        all_urls: URLS
    }));
}, 400);
"""


def drive_in_node(js_text, path, token, view_path=VIEW_PATH):
    """Run the served script and report what it posted.  (count, posts, err)."""
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as fh:
        fh.write(js_text)
        js_file = fh.name
    drv_file = js_file + '.driver'
    with open(drv_file, 'w') as fh:
        fh.write(DRIVER_JS)
    env = dict(os.environ,
               UL_JS=js_file, UL_PATH=path, UL_TOKEN=token or '',
               UL_VIEW=view_path)
    try:
        p = subprocess.run(['node', drv_file], capture_output=True, text=True,
                           timeout=60, env=env)
    except FileNotFoundError:
        return None, [], 'node is not installed; cannot drive the page script'
    finally:
        for f in (js_file, drv_file):
            try:
                os.unlink(f)
            except OSError:
                pass
    if p.returncode != 0:
        return None, [], 'node exited %d:\n%s' % (p.returncode, p.stderr[-2000:])
    line = [l for l in p.stdout.splitlines() if l.startswith('{')]
    if not line:
        return None, [], 'driver printed no result:\n%s' % p.stdout[-1000:]
    data = json.loads(line[-1])
    return data['posts_total'], data['views'], None


def extract_scripts(html):
    """Every inline <script> body, in order."""
    import re
    return re.findall(r'<script[^>]*>(.*?)</script>', html, re.S)


# The dashboard's own script, driven the same way.  It fetches from the REAL
# server (node 18+ has global fetch), so what comes back is the real answer to
# "which quiz did I fail" for the learner the check just created -- not a
# fixture.  The question is the user requirement, so asserting it on the API
# while never asserting that a page shows it would be asserting half of it.
DASH_DRIVER_JS = r"""
var tokens = { 'session_token': process.env.UL_TOKEN || '' };
var listeners = {};
function FakeEl(id) {
    var el = {
        id: id, tagName: 'DIV', textContent: '', innerHTML: '', value: '',
        href: '', style: {}, dataset: {}, children: [], attrs: {},
        classList: {
            _s: {},
            add: function(c) { this._s[c] = true; },
            remove: function(c) { delete this._s[c]; },
            contains: function(c) { return !!this._s[c]; },
            toggle: function(c, on) {
                if (on === undefined) { on = !this._s[c]; }
                if (on) { this._s[c] = true; } else { delete this._s[c]; }
                return on;
            }
        },
        appendChild: function(c) { el.children.push(c); return c; },
        setAttribute: function(k, v) { el.attrs[k] = String(v); },
        getAttribute: function(k) { return el.attrs[k] || null; },
        addEventListener: function() {},
        querySelector: function() { return null; },
        querySelectorAll: function() { return []; },
        closest: function() { return null; }
    };
    return el;
}
var els = {};
global.document = {
    visibilityState: 'visible',
    documentElement: FakeEl('html'),
    getElementById: function(id) { if (!els[id]) { els[id] = FakeEl(id); } return els[id]; },
    querySelector: function(sel) { return FakeEl(sel); },
    querySelectorAll: function() { return []; },
    addEventListener: function(n, f) { (listeners[n] = listeners[n] || []).push(f); },
    createElement: function(t) { var e = FakeEl('new'); e.tagName = String(t).toUpperCase(); return e; },
    createTextNode: function(t) { return { nodeValue: t, children: [] }; },
    body: FakeEl('body')
};
global.window = {
    location: { pathname: '/dashboard' },
    addEventListener: function(n, f) { (listeners['w_' + n] = listeners['w_' + n] || []).push(f); },
    matchMedia: function() { return { matches: false }; },
    scrollTo: function() {}
};
global.localStorage = {
    getItem: function(k) { return Object.prototype.hasOwnProperty.call(tokens, k) ? tokens[k] : null; },
    setItem: function(k, v) { tokens[k] = String(v); }
};
// /dashboard is built from universal components, so its script also carries
// the SSR/hydration runtime: $__uni_dispatch, $__uni_html, $__ur and friends.
// Those are stubbed out, deliberately.  What is under test here is the
// dashboard's own data wiring -- which endpoints it calls and what it renders
// into wd-courses / wd-failures -- not the component runtime, which is the
// same runtime on every page in the collection and is not what regressed.  A
// stub returns a no-op function for any $__uni*/$__ur* name, so an unknown
// member is a no-op rather than a crash that would hide the real assertion.
(function stubHydrationRuntime() {
    var noop = function() { return ''; };
    // The hydration runtime's element factory, as the emitted SSR code spells
    // it: $_ur.createElement(tag, attrs, text).
    global.$_ur = {
        createElement: function(tag, attrs, text) {
            var e = FakeEl(String(tag));
            if (attrs) { for (var k in attrs) { e.attrs[k] = String(attrs[k]); } }
            if (text !== undefined && text !== null) { e.textContent = String(text); }
            return e;
        }
    };
    var handler = {
        get: function(target, prop) {
            if (prop in target) { return target[prop]; }
            if (typeof prop === 'string' &&
                (prop.indexOf('$__uni') === 0 || prop.indexOf('$__ur') === 0)) {
                target[prop] = noop;
                return noop;
            }
            return undefined;
        }
    };
    ['window', 'document', 'globalThis'].forEach(function(name) {
        try { global[name] = new Proxy(global[name], handler); } catch (e) { }
    });
})();
function hrefsOf(node, out) {
    if (node === null || node === undefined) { return out; }
    if (Array.isArray(node)) { node.forEach(function(n) { hrefsOf(n, out); }); return out; }
    if (node.href) { out.push(String(node.href)); }
    if (node.children) { node.children.forEach(function(n) { hrefsOf(n, out); }); }
    return out;
}
function textOf(node) {
    if (node === null || node === undefined) { return ''; }
    if (Array.isArray(node)) { return node.map(textOf).join(' '); }
    var s = '';
    // A text node carries nodeValue; an element carries textContent directly
    // (that is how wdEl() fills a label) or has children (that is how it
    // nests a row).  Reading only the first two is how a rendered list comes
    // back looking empty when it is in fact full of text.
    if (node.nodeValue !== undefined && node.nodeValue !== null) {
        s = String(node.nodeValue);
    } else if (node.textContent) {
        s = String(node.textContent);
    }
    if (node.children && node.children.length) {
        var inner = node.children.map(textOf).join(' ');
        s = (s ? s + ' ' : '') + inner;
    }
    return s;
}
eval(require('fs').readFileSync(process.env.UL_JS, 'utf8'));
(listeners['DOMContentLoaded'] || []).forEach(function(f) { f(); });
setTimeout(function() {
    console.log(JSON.stringify({
        courses: textOf(els['wd-courses']),
        failures: textOf(els['wd-failures']),
        course_hrefs: hrefsOf(els['wd-courses'], []),
        failure_hrefs: hrefsOf(els['wd-failures'], []),
        courses_count: els['wd-courses-count'] ? els['wd-courses-count'].textContent : null,
        failures_count: els['wd-failures-count'] ? els['wd-failures-count'].textContent : null
    }));
}, 1500);
"""


def drive_dashboard(html, token, base):
    """Run the dashboard's own script against the real server."""
    scripts = [s for s in extract_scripts(html) if 'wdLoad' in s]
    if not scripts:
        return None, 'no inline <script> contains wdLoad'
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as fh:
        fh.write(scripts[0])
        js_file = fh.name
    drv = js_file + '.driver'
    with open(drv, 'w') as fh:
        fh.write(DASH_DRIVER_JS)
    # The page's own script fetches a RELATIVE '/api/me/overview', which node's
    # fetch cannot resolve (there is no base URL outside a browser), so the
    # path is rewritten in the SCRIPT being evaluated -- not in the driver,
    # which never contained it.
    with open(js_file, encoding='utf-8') as fh:
        page_js = fh.read()
    page_js = page_js.replace("'/api/me/overview'",
                              "'" + base.rstrip('/') + "/api/me/overview'")
    with open(js_file, 'w', encoding='utf-8') as fh:
        fh.write(page_js)
    env = dict(os.environ, UL_JS=js_file, UL_TOKEN=token or '')
    try:
        p = subprocess.run(['node', drv], capture_output=True, text=True,
                           timeout=90, env=env)
    except FileNotFoundError:
        return None, 'node is not installed; cannot drive the dashboard script'
    finally:
        for f in (js_file, drv):
            try:
                os.unlink(f)
            except OSError:
                pass
    if p.returncode != 0:
        return None, 'node exited %d:\n%s' % (p.returncode, p.stderr[-2000:])
    line = [l for l in p.stdout.splitlines() if l.startswith('{')]
    if not line:
        return None, 'dashboard driver printed no result:\n%s' % p.stdout[-1000:]
    return json.loads(line[-1]), None


# ------------------------------------------------------------------ the checks

def pick_course_and_concept(base):
    """A real course and a real concept, read from the course API rather than
    hardcoded, so a renamed course cannot silently turn this into a no-op."""
    st, data = request_json(base, '/api/courses/all')
    if st != 200 or not isinstance(data, dict):
        return None, None, 'GET /api/courses/all returned %s' % st
    courses = data.get('courses', data)
    if not courses:
        return None, None, 'no courses in the API'
    courses = sorted(courses, key=lambda c: c.get('id', ''))
    # Prefer elf if present: it is the course with the most concepts, so a
    # single read is a meaningful fraction of it and the manifest total is
    # certainly non-zero.  Otherwise take the first course alphabetically.
    chosen = None
    for c in courses:
        if c.get('id') == 'elf':
            chosen = c
            break
    if chosen is None:
        chosen = courses[0]
    cid = chosen.get('id')
    st, course = request_json(base, '/api/courses/%s' % cid)
    if st != 200:
        return None, None, 'GET /api/courses/%s returned %s' % (cid, st)
    concepts = course.get('concepts') or []
    if not concepts:
        return None, None, 'course %s has no concepts' % cid
    concept = concepts[0].get('id')
    return cid, concept, None


def pick_wrong_answer(base, concept):
    """Exercises for a concept, in the shape the checks need.

    Returns (list_of_(exercise_id, question, [options]), error).  It does NOT
    decide which answer is wrong: GET /api/exercises/:concept does not return
    the stored answer, so the check submits options one at a time and keeps the
    first the server grades wrong.  Guessing instead -- assuming options[0] is
    wrong -- makes the whole check fail on any exercise whose first option
    happens to be the answer, which is a defect in the check dressed up as a
    finding.
    """
    st, data = request_json(base, '/api/exercises/%s' % concept)
    if st != 200 or not isinstance(data, dict):
        return None, 'GET /api/exercises/%s returned %s' % (concept, st)
    out = []
    for ex in data.get('exercises') or []:
        eid = ex.get('id')
        if not eid:
            continue
        opts = ex.get('options') or []
        out.append((eid, ex.get('question') or '', opts))
    if not out:
        return None, 'no exercises for concept %s' % concept
    return out, None


def submit(base, token, cid, eid, answer):
    path = ('/api/exercises/submit?exercise_id=%s&answer=%s&course_id=%s'
            % (urllib.parse.quote(eid), urllib.parse.quote(answer), cid))
    return request_json(base, path, token=token, method='POST')


def run_checks(base, expect_engagement=True):
    global checks, failures
    failures = []
    checks = 0

    section('server')
    if not wait_health(base):
        bad('server answers /api/health 200 on %s' % base,
            'is the server running?  bash scripts/restart_underlayer.sh')
        return 1
    ok('server answers /api/health 200 on %s' % base)

    # ---- 1. a brand new learner -------------------------------------
    section('1. fresh learner')
    stamp = int(time.time())
    email = 'progress-check-%d-%d@example.invalid' % (stamp, os.getpid())
    password = 'Pr0gressCheck!%d' % (stamp % 100000)
    # Refill the limiter's allowance, so this run measures progress and not the
    # residue of whatever ran before it. See clear_rate_limits().
    clear_rate_limits()
    st, reg = request_json(base, '/api/auth/register', method='POST',
                           body={'email': email, 'password': password,
                                 'name': 'Progress Check'})
    if st != 200 or not isinstance(reg, dict) or not reg.get('learner_id'):
        bad('register a fresh learner', 'HTTP %s %s' % (st, reg))
        return 1
    learner_id = reg['learner_id']
    ok('registered %s (learner %s)' % (email, learner_id[:8]))

    st, login = request_json(base, '/api/auth/login', method='POST',
                             body={'email': email, 'password': password})
    token = login.get('session_token') or login.get('token') if isinstance(login, dict) else None
    if st != 200 or not token:
        bad('sign in and get a session token',
            'HTTP %s; keys: %s' % (st, list(login) if isinstance(login, dict) else login))
        return 1
    ok('signed in, session token of %d chars' % len(token))

    st, me = request_json(base, '/api/auth/me', token=token)
    if st != 200 or me.get('learner_id') != learner_id:
        bad('GET /api/auth/me returns this learner', 'HTTP %s %s' % (st, me))
    else:
        ok('GET /api/auth/me confirms the identity')

    # ---- 2. which page are we testing? ------------------------------
    section('2. the lesson under test')
    cid, concept, why = pick_course_and_concept(base)
    if cid is None:
        bad('find a course and concept to test', why)
        return 1
    lesson_path = '/courses/%s/lessons/%s' % (cid, concept)
    ok('testing %s' % lesson_path)

    # ---- 3. before: no progress -------------------------------------
    section('3. progress before any read')
    st, before = request_json(base, '/api/progress/%s' % cid, token=token)
    if st != 200:
        bad('GET /api/progress/%s returns 200' % cid, 'HTTP %s %s' % (st, before))
        return 1
    started_before = before.get('concepts_started', -1)
    pct_before = before.get('progress_percentage', -1)
    total = before.get('concepts_total', 0)
    if started_before == 0:
        ok('a brand-new learner has concepts_started=0')
    else:
        bad('a brand-new learner has concepts_started=0',
            'got %r -- is this learner really new?' % (started_before,))
    if pct_before == 0:
        ok('progress_percentage is 0 before any read')
    else:
        bad('progress_percentage is 0 before any read', 'got %r' % (pct_before,))
    if total and total > 0:
        ok('concepts_total=%d comes from the course manifest' % total)
    else:
        bad('concepts_total is the manifest concept count',
            'got %r; a denominator of 0 makes the percentage meaningless' % (total,))

    # ---- 4. the served page carries the call ------------------------
    section('4. the served page carries the engagement call')
    st, html = request(base, lesson_path)
    if st != 200:
        bad('GET %s returns 200' % lesson_path, 'HTTP %s' % st)
        return 1
    if FN_START in html:
        ok('%s present in the served HTML' % FN_START)
    else:
        bad('%s present in the served HTML' % FN_START,
            'the strip is not on the page, so nothing can be recorded')

    if FN_REPORT in html:
        ok('%s present (the function that POSTs the read)' % FN_REPORT)
    else:
        bad('%s present (the function that POSTs the read)' % FN_REPORT)

    if ('id="%s"' % STRIP_ID) in html:
        ok('the strip element id="%s" is in the markup' % STRIP_ID)
    else:
        bad('the strip element id="%s" is in the markup' % STRIP_ID,
            'the script has nothing to write into')

    n_views = html.count("'%s'" % VIEW_PATH)
    if n_views == 1:
        ok('the page posts /api/learning/view exactly once')
    elif n_views == 0:
        bad('the page posts /api/learning/view exactly once',
            'found 0 -- this is the unfixed platform: the read is never '
            'recorded, so no progress view can ever move')
    else:
        bad('the page posts /api/learning/view exactly once',
            'found %d -- a read is recorded more than once per page load, so '
            'activity counts and first_time are both wrong' % n_views)

    if '__ul_report_view' in html:
        bad('no legacy private copy of the view POST remains',
            '__ul_report_view is still in the served page; the shared nav and '
            'a page-level copy both report, so every read is doubled')
    else:
        ok('no legacy private copy of the view POST remains')

    # ---- 5. drive the script ----------------------------------------
    section('5. driving the page\'s own script')
    scripts = [s for s in extract_scripts(html) if FN_START in s]
    if not scripts:
        bad('find the engagement script in the served page',
            'no inline <script> contains %s' % FN_START)
        return 1
    ok('found %d inline script(s) carrying the engagement call' % len(scripts))

    total_posts, views, err = drive_in_node(scripts[0], lesson_path, token)
    if err:
        # A missing node is a real limitation and must not read as a pass.
        bad('execute the engagement script in Node', err)
    else:
        ok('the script ran (%d POST(s) issued in total)' % total_posts)
        if len(views) == 1:
            ok('the script issued exactly one POST %s' % VIEW_PATH)
        elif not views:
            bad('the script issued exactly one POST %s' % VIEW_PATH,
                'it issued none -- running the page changes nothing on the '
                'server, whatever the HTML contains')
        else:
            bad('the script issued exactly one POST %s' % VIEW_PATH,
                'it issued %d' % len(views))
        if views:
            body = views[0].get('body') or {}
            if body.get('course_id') == cid and body.get('concept_id') == concept:
                ok('the POST body names this course and concept (%s / %s)'
                   % (cid, concept))
            else:
                bad('the POST body names this course and concept (%s / %s)' % (cid, concept),
                    'got %s' % (body,))

    # ---- 6. does the read actually change state? --------------------
    section('6. the read changes recorded state')
    # Replay exactly the request the script would have made.
    st, view = request_json(base, VIEW_PATH, token=token, method='POST',
                            body={'course_id': cid, 'concept_id': concept})
    if st == 200 and view.get('recorded') is True:
        ok('POST %s recorded the read' % VIEW_PATH)
    else:
        bad('POST %s recorded the read' % VIEW_PATH, 'HTTP %s %s' % (st, view))

    if view.get('first_time') is True:
        ok('first_time=true on the first read of %s' % concept)
    else:
        bad('first_time=true on the first read of %s' % concept,
            'got %r -- the platform cannot tell a new read from a re-read'
            % (view.get('first_time'),))

    st, after = request_json(base, '/api/progress/%s' % cid, token=token)
    started_after = after.get('concepts_started', -1)
    pct_after = after.get('progress_percentage', -1)
    if started_after == started_before + 1:
        ok('concepts_started moved %d -> %d' % (started_before, started_after))
    else:
        bad('concepts_started moved %d -> %d' % (started_before, started_after + 1),
            'got %r; opening a page did not add the concept' % (started_after,))

    if pct_after > pct_before:
        ok('progress_percentage moved %d -> %d (this is the defect the whole '
           'exercise is about)' % (pct_before, pct_after))
    elif pct_after == 0 and total == 0:
        bad('progress_percentage moved off zero',
            'concepts_total is 0, so there is no denominator to move against')
    else:
        bad('progress_percentage moved %d -> %d' % (pct_before, pct_after),
            'a learner who reads a lesson sees no progress.  On the unfixed '
            'platform this is forced arithmetic: the number was '
            '(health.health_score*100) and health_score is mastered/touched, '
            'and nothing on the reading path ever writes "mastered"')

    ids = [c.get('concept_id') for c in after.get('concepts') or []]
    if concept in ids:
        ok('%s appears in the learner\'s recorded concepts' % concept)
    else:
        bad('%s appears in the learner\'s recorded concepts' % concept,
            'got %s' % (ids,))

    # a second read must not be a first read
    st, view2 = request_json(base, VIEW_PATH, token=token, method='POST',
                             body={'course_id': cid, 'concept_id': concept})
    if st == 200 and view2.get('first_time') is False:
        ok('first_time=false on the second read of the same concept')
    else:
        bad('first_time=false on the second read of the same concept',
            'got %r -- every read looks new, so "logged" means nothing'
            % (view2.get('first_time'),))

    st, after2 = request_json(base, '/api/progress/%s' % cid, token=token)
    started_after2 = after2.get('concepts_started', -1)
    if started_after2 == started_after:
        ok('a re-read does not inflate concepts_started (still %d)'
           % started_after2)
    else:
        bad('a re-read does not inflate concepts_started',
            '%d -> %d on a second read of the same concept'
            % (started_after, started_after2))

    # ---- 7. which courses am I taking --------------------------------
    section('7. the learner\'s own course list')
    st, ov = request_json(base, '/api/me/overview', token=token)
    if st != 200 or not isinstance(ov, dict):
        bad('GET /api/me/overview returns 200', 'HTTP %s %s' % (st, ov))
    else:
        courses = ov.get('courses') or []
        got = [c.get('course_id') for c in courses]
        if cid in got:
            ok('the course they read is in their own list: %s' % (got,))
        else:
            bad('the course they read is in their own list',
                'read %s, list is %s -- the enrollments table is written by '
                'nothing and "which courses am I taking" has no answer' % (cid, got))
        if ov.get('courses_total') == len(courses) and courses:
            ok('courses_total agrees with the list length')

    # ---- 8. which quiz did I fail ------------------------------------
    section('8. which quiz did I fail')
    ex_list, why = pick_wrong_answer(base, concept)
    ex_id = None
    ex_question = ''
    if ex_list is None:
        bad('find an exercise to answer', why)
    else:
        ok('%d exercise(s) available in %s' % (len(ex_list), concept))
        # Submit until one is graded wrong.  The first option is tried first
        # because it usually is not the answer, but "usually" is not a
        # criterion.
        for eid, question, opts in ex_list:
            for answer in (opts or ['__progress_check_definitely_wrong__']):
                st, sub = submit(base, token, cid, eid, answer)
                if st == 200 and sub.get('correct') is False:
                    ex_id, ex_question = eid, question
                    break
            if ex_id is not None:
                break
        if ex_id is None:
            bad('submit a known-wrong answer to an exercise',
                'tried %d exercise(s) and could not get one graded wrong; the '
                'check cannot tell a wrong answer from a right one'
                % len(ex_list))
        else:
            ok('submitted a wrong answer to %s' % ex_id)

    if ex_id is not None:
        st, fails = request_json(base, '/api/exercises/failures', token=token)
        items = fails.get('failed_exercises') if isinstance(fails, dict) else None
        if items is None:
            bad('GET /api/exercises/failures lists the missed exercises',
                'HTTP %s %s' % (st, fails))
        else:
            ids = [f.get('exercise_id') for f in items]
            if ex_id in ids:
                ok('%s is readable back out of /api/exercises/failures' % ex_id)
            else:
                bad('%s is readable back out of /api/exercises/failures' % ex_id,
                    'asked about %s, got %s -- the wrong answer is graded, '
                    'shown to the learner, and then thrown away' % (ex_id, ids))
            for f in items:
                if f.get('exercise_id') == ex_id:
                    if f.get('lesson_url'):
                        ok('the failure links to its lesson (%s)'
                           % f.get('lesson_url'))
                    if f.get('misses', 0) >= 1:
                        ok('the failure carries a miss count (%d)'
                           % f.get('misses'))
                    if f.get('question'):
                        ok('the failure carries the question text, which is '
                           'what identifies it to a learner')
                    break

    # ---- 9. the course landing page's own bar -----------------------
    section('9. the course landing page asks about ITS course')
    st, land = request(base, '/courses/%s' % cid)
    if st != 200:
        bad('GET /courses/%s returns 200' % cid, 'HTTP %s' % st)
    else:
        if 'nav-status?course_id=' in land:
            ok('the landing bar passes ?course_id to /api/nav-status')
        else:
            bad('the landing bar passes ?course_id to /api/nav-status',
                'it fetches /api/nav-status bare, so the handler falls back to '
                'the literal "elf" and /courses/rvasm draws ELF\'s numbers')
        if "Authorization" in land and "__ul_token" in land:
            ok('the landing bar sends the session token')
        else:
            bad('the landing bar sends the session token',
                'with no Authorization header the handler falls back to the '
                '"demo" learner, so the bar can never show a real learner\'s '
                'own progress')

    st, navst = request_json(base, '/api/nav-status?course_id=%s' % cid, token=token)
    if st == 200 and navst.get('course_id') == cid:
        ok('/api/nav-status echoes back the course it was asked about (%s)'
           % cid)
    else:
        bad('/api/nav-status echoes back the course it was asked about',
            'asked %s, got %s' % (cid, navst))
    if navst.get('progress_pct') == pct_after:
        ok('the landing bar agrees with /api/progress (%d%%)'
           % navst.get('progress_pct', -1))
    else:
        bad('the landing bar agrees with /api/progress',
            'nav-status says %r%%, /api/progress says %r%% -- two numbers for '
            'one thing, on the same page'
            % (navst.get('progress_pct'), pct_after))

    # ---- 10. the learner can SEE it --------------------------------
    section('10. the learner can see it, not just fetch it')
    # A parallel dashboard was not built for this: /dashboard already existed,
    # so the two questions with no answer were added to it.  This runs the
    # dashboard's OWN script against the REAL server and reads what it renders,
    # because an API that answers is not the same as a page that shows.
    # THE TOKEN IS SENT HERE NOW, and it is the reason this section needs a
    # note.  /dashboard is behind the sign-in gate (web/src/pages_auth_gate.ch):
    # every number on it is the signed-in learner's own, so an anonymous request
    # gets the gate page instead.  Fetching it without a token used to work and
    # now returns a page with no #wd-courses on it -- which looked like the
    # feature had broken, when in fact the gate was working exactly as intended.
    #
    # So this asserts BOTH halves: the gate refuses an anonymous request, and the
    # dashboard renders the real thing for a signed-in one.  Only the first half
    # could have been written before the gate existed.
    # The gate is a 303 to /login now (web/src/pages_auth_gate.ch, 2026-10-03),
    # not an in-place card, so `ul-gate-card` is gone and `request` follows the
    # redirect to the sign-in page. Asserting on the old markup would fail on a
    # correctly-gated page.
    #
    # What matters is unchanged and is asserted directly: an anonymous request
    # must not receive ANY learner data. The markers below are the dashboard's own
    # containers, so finding one means the gate let the page through. This holds
    # whichever way the gate is implemented, which is why it is written this way
    # rather than against a class name.
    st_anon, dash_anon = request(base, '/dashboard')
    leaked = [p for p in ('wd-courses', 'wd-failures', 'wd-next-step')
              if p in dash_anon]
    if not leaked:
        ok('/dashboard gates an anonymous visitor (no learner data without a session)')
    else:
        bad('/dashboard gates an anonymous visitor',
            'a signed-out request received the real dashboard: %s' % ', '.join(leaked))

    st, dash = request(base, '/dashboard', token=token)
    if st != 200:
        bad('GET /dashboard returns 200 for a signed-in learner', 'HTTP %s' % st)
        return 1 if failures else 0
    for probe in ('wd-courses', 'wd-failures'):
        if probe in dash:
            ok('the dashboard has a place to draw the answer (#%s)' % probe)
        else:
            bad('the dashboard has a place to draw the answer (#%s)' % probe)

    rendered, err = drive_dashboard(dash, token, base)
    if err:
        bad("the dashboard's script renders the learner's own data", err)
    else:
        # The list shows the course TITLE and links to /courses/<id>; the id
        # alone is not what the learner reads, so both are checked.
        courses_text = rendered.get('courses') or ''
        course_hrefs = ' '.join(rendered.get('course_hrefs') or [])
        title = ''
    _stc, _cd = request_json(base, '/api/courses/%s' % cid)
    if isinstance(_cd, dict):
        title = _cd.get('title') or ''
        if cid in course_hrefs and (not title or title in courses_text):
            ok('the dashboard lists the course the learner read, by title and '
               'linked (%s)' % cid)
        else:
            bad('the dashboard lists the course the learner read, by title and linked',
                'course=%s title=%r; rendered text=%r hrefs=%r'
                % (cid, title, courses_text[:200], course_hrefs[:200]))

        # The failed-quiz list shows the QUESTION and links to the lesson.
        # The exercise id is deliberately not shown -- it identifies nothing to
        # a learner -- so the question is what has to be on screen.
        fails_text = rendered.get('failures') or ''
        if ex_id and ex_question and ex_question in fails_text:
            ok('the dashboard shows the question the learner got wrong')
        else:
            bad('the dashboard shows the question the learner got wrong',
                'asked for %r; the "Which quizzes I failed" list rendered: %r'
                % (ex_question[:80], fails_text[:250]))
        if ex_id and '/courses/%s/lessons/' % cid in ' '.join(rendered.get('failure_hrefs') or []):
            ok('each failed question links back to its lesson')
        else:
            bad('each failed question links back to its lesson',
                'hrefs=%r' % (rendered.get('failure_hrefs'),))
        if str(rendered.get('failures_count')).strip() not in ('', '0', 'None'):
            ok('the failed-quiz count reads %r'
               % rendered.get('failures_count'))
        else:
            bad('the failed-quiz count is above zero',
                'the learner just missed an exercise; the count reads %r'
                % (rendered.get('failures_count'),))

    # ---- 11. leave no trace ------------------------------------------
    # A gate that adds a row to the development database on every run is a gate
    # that will eventually bury somebody's real data, or hide a regression
    # behind its own accumulated state.  The learner this run created is
    # deleted through the product's own account-deletion endpoint, which also
    # exercises that path on every run.
    section('11. cleanup')
    st, _ = request(base, '/api/user/account', token=token, method='DELETE')
    if st == 200:
        ok('the throwaway learner was deleted through '
           'DELETE /api/user/account')
    else:
        bad('the throwaway learner was deleted',
            'DELETE /api/user/account returned %s.  Left behind: %s.  Remove it '
            'by hand: this check must not accumulate accounts.' % (st, email))

    return 1 if failures else 0


# ------------------------------------------------------------- non-vacuity

def prove_non_vacuous(base_port=9109):
    """Remove THE_CALL from a scratch copy, rebuild, and require the check to
    fail against it.  If it passes, this script is not testing anything."""
    print('\n' + '=' * 72)
    print('PROVING THIS CHECK IS NOT VACUOUS')
    print('=' * 72)
    print('Copying the tree, deleting the one line `%s` from' % THE_CALL)
    print('content/src/lesson_nav.ch, rebuilding, and running the check')
    print('against that build.  The build MUST fail the check.')

    if not os.path.exists(CC):
        print('\nFAIL: compiler not found at %s' % CC)
        print('      Set CC to the TCCCompiler path and re-run.')
        return 1

    scratch = tempfile.mkdtemp(prefix='progress-check-nonvacuous-')
    dst = os.path.join(scratch, 'underlayer')
    print('\n  scratch copy: %s' % dst)
    try:
        # Copy the source tree, not the build products, and leave the .git
        # directory behind: this is a measurement, not a second checkout.
        shutil.copytree(ROOT, dst,
                        ignore=shutil.ignore_patterns('.git', 'build', '__pycache__',
                                                      '.venv', 'node_modules'))
        nav = os.path.join(dst, 'content', 'src', 'lesson_nav.ch')
        with open(nav, encoding='utf-8') as fh:
            src = fh.read()
        n = src.count(THE_CALL)
        if n != 1:
            print('\nFAIL: expected exactly one `%s` in lesson_nav.ch, found %d.'
                  % (THE_CALL, n))
            print('      The anchor for this proof moved, so the proof would be')
            print('      measuring the wrong thing.  Fix the anchor, not the gate.')
            return 1
        with open(nav, 'w', encoding='utf-8') as fh:
            fh.write(src.replace(THE_CALL, '// REMOVED BY progress_check.py'))

        print('\n  building the mutilated copy (this takes a few minutes)...')
        exe = os.path.join(dst, 'build', 'underlayer.exe')
        os.makedirs(os.path.dirname(exe), exist_ok=True)
        p = subprocess.run(
            [CC, 'chemical.mod', '-o', 'build/underlayer.exe',
             '--mode', 'debug_quick', '--no-cache', '-bm-modules'],
            cwd=dst, capture_output=True, text=True, timeout=3600)
        if p.returncode != 0:
            tail = (p.stdout or '')[-1500:] + (p.stderr or '')[-1500:]
            print('\n  build FAILED, which is not the result we wanted:')
            print('  ' + tail.replace('\n', '\n  '))
            print('\n  A build that cannot finish cannot demonstrate that the')
            print('  check is non-vacuous.  The check itself has not been')
            print('  exonerated -- it is UNPROVEN.')
            return 1
        if not os.path.exists(exe):
            # The compiler exited 0 and the artefact is not there.  Report what
            # it actually did rather than dying with FileNotFoundError three
            # steps later, which reads like a bug in the check.
            print('\n  build exited 0 but %s does not exist.' % exe)
            print('  cwd=%s' % dst)
            try:
                print('  %s contains: %s'
                      % (os.path.dirname(exe), sorted(os.listdir(os.path.dirname(exe)))))
            except OSError as e:
                print('  cannot list %s: %s' % (os.path.dirname(exe), e))
            print('  ---- last 1500 chars of compiler stdout ----')
            print('  ' + (p.stdout or '')[-1500:].replace('\n', '\n  '))
            print('  ---- last 1500 chars of compiler stderr ----')
            print('  ' + (p.stderr or '')[-1500:].replace('\n', '\n  '))
            print('\n  The mutilated platform could not be run, so the')
            print('  non-vacuity of this check is UNPROVEN.')
            return 1
        print('  build succeeded (removal is safe to compile; the point is that')
        print('  it makes the platform wrong, which the next step tests).')

        print('\n  starting the mutilated server on port %d...' % base_port)
        env = dict(os.environ, PORT=str(base_port))
        log = open(os.path.join(scratch, 'server.log'), 'w')
        proc = subprocess.Popen([exe], cwd=dst, stdout=log, stderr=log,
                                env=env, start_new_session=True)
        base = 'http://localhost:%d' % base_port
        try:
            if not wait_health(base, seconds=60):
                print('\n  the mutilated server never came up on %d.' % base_port)
                print('  The proof could not run.')
                return 1
            print('  mutilated server is up.  Running the check against it...')
            rc = run_checks(base, expect_engagement=False)
        finally:
            try:
                os.killpg(os.getpgid(proc.pid), 15)
            except Exception:
                proc.terminate()
            proc.wait(timeout=30)
            log.close()

        print('\n' + '-' * 72)
        if rc == 0:
            print('THE CHECK PASSED AGAINST THE MUTILATED BUILD.')
            print('')
            print('That means tools/progress_check.py does not actually test')
            print('the engagement call: it passes on a platform that records')
            print('nothing.  It is worse than no check, because it looks like')
            print('coverage.  Treat this as a bug in the check, not a pass.')
            print('-' * 72)
            return 1
        print('THE CHECK FAILED AGAINST THE MUTILATED BUILD, as it must.')
        print('Reproduced failures on the platform with %s removed:' % THE_CALL)
        for f in failures:
            print('  - %s' % f)
        print('-' * 72)
        print('\nPROVEN NON-VACUOUS: the check detects the removal of the call.')
        return 0
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--base', default='http://localhost:9000',
                    help='base URL of the running server (default http://localhost:9000)')
    ap.add_argument('--prove-non-vacuous', action='store_true',
                    help='also rebuild without the engagement call and require '
                         'this check to fail (slow: several minutes)')
    ap.add_argument('--port', type=int, default=9109,
                    help='port for the mutilated server in the non-vacuity proof')
    args = ap.parse_args()

    if not args.base.startswith('http'):
        print('usage error: --base must be an http(s) URL')
        return 2

    rc = run_checks(args.base)

    print('\n' + '=' * 72)
    if rc == 0:
        print('progress_check: ALL %d CHECKS PASSED against %s' % (checks, args.base))
    else:
        print('progress_check: %d of %d CHECKS FAILED against %s'
              % (len(failures), checks, args.base))
    print('=' * 72)
    if failures:
        for f in failures:
            print('  FAILED: %s' % f)

    if args.prove_non_vacuous:
        if rc != 0:
            print('\nNot running the non-vacuity proof: the check does not pass')
            print('on the real platform, so it has nothing to prove yet.')
            return rc
        prc = prove_non_vacuous(args.port)
        return rc or prc

    return rc


if __name__ == '__main__':
    sys.exit(main())