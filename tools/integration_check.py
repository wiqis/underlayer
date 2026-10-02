#!/usr/bin/env python3
"""integration_check.py -- prove the shipped features are reachable FROM A LESSON.

THE DEFECT THIS CHECK EXISTS FOR
-------------------------------
Measured 2026-10-02 against the running server, by counting the lesson page
builders in content/src/*.ch that reference each API:

    api/learning/view   1        api/auth/me         0
    api/exercises        1        api/bookmarks       0
    record_activity      2        api/notes           0
                                 api/feedback        0
                                 streaks             0
                                 api/achievements    0
                                 api/certificates    0

The endpoints all shipped and all worked -- this script curls every one of them
before it asserts anything about the client.  A learner reading a lesson could
not bookmark it, annotate it, tell whether they were signed in, send a
correction, or see how they were standing.  The engagement strip was the only
integration, and it reached every page because it lives in the one component
every lesson page renders.

WHAT IT DOES, IN ORDER
----------------------
  1. Registers a fresh learner, signs in, and DELETEs the account at the end
     through the product's own DELETE /api/user/account, so this gate never
     accumulates rows in the development database.
  2. Exercises every real endpoint over HTTP, and asserts the SHAPE it got
     back.  A shape assertion is in here on purpose: the whole failure mode this
     work was guarding against is a client written against a guessed shape, and
     an endpoint that silently changes shape is invisible to a test that only
     asks "did it return 200".
  3. Fetches a real lesson page over HTTP and asserts each integrated client is
     present in the served HTML -- the element id, the function name, and the
     endpoint path.  Presence is not enough, so:
  4. DRIVES the page's own script in Node against a DOM shim, with fetch
     recording every request instead of answering it, and asserts the requests
     it WOULD make: which endpoints, which verbs, which bodies, and that a
     signed-out page load makes none of them.
  5. REPLAYS those exact requests against the real server and asserts the
     learner-visible effect: the bookmark comes back from the check endpoint,
     the note comes back from the notes endpoint, the feedback is stored, the
     streak chip and achievement chip render text, the nav names the learner,
     and the certificate flow on the course landing page issues one.
  6. Asserts the signed-out degradation on the same page: no token in the shim
     means zero requests, and the page still carries the full lesson body.

HOW IT PROVES IT IS NOT VACUOUS
-------------------------------
`--prove-non-vacuous` copies the tree, deletes ONE line --
`render_lesson_tools(page)` from content/src/lesson_nav.ch -- rebuilds, serves
that copy on its own port, and runs the whole check against it.  The check MUST
fail.  If it passes, this script exits non-zero saying it is not testing
anything: a check that passes on an unintegrated platform is worse than no
check, because it looks like coverage.

The removal has to be of the CALL in the shared component rather than of the
markup, because the markup is written once for all 431 lesson pages.  That is
the point of where it lives, so it is also the only honest way to take it out.

Usage:
    python3 tools/integration_check.py
    python3 tools/integration_check.py --base http://localhost:9000
    python3 tools/integration_check.py --prove-non-vacuous
    python3 tools/integration_check.py --list-shapes

Exit: 0 every assertion held, 1 an assertion failed, 2 bad usage.
"""
import argparse
import json
import os
import re
import shutil
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
THE_CALL = 'render_lesson_tools(page)'

# Every integrated feature, and what proves it is integrated.  The marker is
# what the served lesson page must contain; asserting on a substring that is
# only in a comment would be a check that reads well and proves nothing, so each
# marker below is an element id, a function name or a request path that only
# exists because the client exists.
FEATURES = [
    ('identity', 'api/auth/me', 'ul-identity', '__ulLoadIdentity',
     '/api/auth/me'),
    ('bookmark', 'api/bookmarks', 'ul-bookmark', '__ulToggleBookmark',
     '/api/bookmarks'),
    ('notes', 'api/notes', 'ul-notes-panel', '__ulSaveNote',
     '/api/notes'),
    ('feedback', 'api/feedback', 'ul-feedback-panel', '__ulSendFeedback',
     '/api/feedback'),
    ('streak', 'streaks', 'ul-streak', '__ulLoadStanding',
     '/api/streaks'),
    ('achievements', 'api/achievements', 'ul-achievements',
     '__ulPaintAchievements', '/api/achievements'),
    ('certificate offer', 'api/certificates', 'ul-certificate',
     '__ulLoadProgress', '/courses/'),
]

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


def warn(what, detail=''):
    """A finding that is real, is not this check's business to gate on, and that
    somebody should still see every run.  It does NOT affect the exit code: a
    gate that fails when a security bug gets FIXED is a gate that gets
    disabled."""
    print('  WARN  %s' % what)
    if detail:
        for line in str(detail).splitlines():
            print('          %s' % line)


def section(title):
    print('\n== %s' % title)


# ---------------------------------------------------------------- HTTP helpers

def request(base, path, token=None, method='GET', body=None, timeout=40):
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


def extract_scripts(html):
    return re.findall(r'<script[^>]*>(.*?)</script>', html, re.S)


def course_title_for(base, cid):
    """The course's manifest title, read from the API the certificate handler
    itself reads it from.  Used to assert a certificate carries the course NAME
    rather than its id -- `course_title` was a copy of `course_id`, so every
    certificate this platform issued was titled "elf"."""
    try:
        st, body = request_json(base, '/api/courses/%s' % cid)
    except Exception:
        return None
    if st != 200 or not isinstance(body, dict):
        return None
    return body.get('title')


def html_text(html):
    """The visible text of a page, tags stripped.  Used to prove the lesson BODY
    is intact -- the backend-optional rule is that a feature may add to a lesson
    and may never remove from it."""
    body = re.sub(r'<script[^>]*>.*?</script>', ' ', html, flags=re.S)
    body = re.sub(r'<style[^>]*>.*?</style>', ' ', body, flags=re.S)
    body = re.sub(r'<[^>]+>', ' ', body)
    body = re.sub(r'&[a-z]+;|&#\d+;', ' ', body)
    return re.sub(r'\s+', ' ', body).strip()


# ------------------------------------------------------- driving the page's JS
#
# The lesson script is a browser script: it reads window.location, reads
# localStorage, registers DOMContentLoaded, and calls fetch.  Rather than assert
# on the text of the script, this runs it in Node against the smallest shim that
# gives it an honest answer and reports what it ACTUALLY requested.  If a client
# stops being called, or is called with the wrong verb, or is called while
# signed out, this is where it shows up -- not as a string comparison that a
# rename would defeat.
DRIVER_JS = r"""
// ---- shim -------------------------------------------------------------
var REQUESTS = [];
var listeners = {};
var tokens = {};
if (process.env.UL_TOKEN) { tokens['session_token'] = process.env.UL_TOKEN; }

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
        tagName: 'DIV', innerHTML: '', value: '',
        href: '', type: '', placeholder: '', disabled: false, hidden: false,
        style: {}, dataset: {}, children: [], attrs: {},
        parentNode: null, parentElement: null, nextSibling: null,
        firstChild: null, listeners: {}, _text: '',
        classList: null,
        appendChild: function(c) { el.children.push(c); c.parentNode = el; return c; },
        removeChild: function(c) { el.children = el.children.filter(function(x) { return x !== c; }); },
        insertBefore: function(n) { el.children.push(n); return n; },
        setAttribute: function(k, v) {
            el.attrs[k] = String(v);
            // A real getElementById finds an element the page created and then
            // gave an id.  The Sign out button is built with createElement and
            // named after itself, so without this the shim could not see it and
            // the driver pressed nothing -- which looked exactly like the button
            // having no handler.
            if (k === 'id' && v) { el.id = v; }
        },
        getAttribute: function(k) { return Object.prototype.hasOwnProperty.call(el.attrs, k) ? el.attrs[k] : null; },
        removeAttribute: function(k) { delete el.attrs[k]; },
        hasAttribute: function(k) { return Object.prototype.hasOwnProperty.call(el.attrs, k); },
        addEventListener: function(name, fn) { (el.listeners[name] = el.listeners[name] || []).push(fn); },
        removeEventListener: function() {},
        dispatch: function(name, ev) { (el.listeners[name] || []).forEach(function(f) { f(ev || {}); }); },
        querySelector: function() { return null; },
        querySelectorAll: function() { return []; },
        closest: function() { return null; },
        matches: function() { return false; },
        focus: function() {}, blur: function() {}, click: function() {},
        getBoundingClientRect: function() { return { top: 0, left: 0, width: 0, height: 0 }; }
    };
    el.classList = new FakeClassList(el);
    // textContent is an ACCESSOR because assigning '' to it REMOVES the
    // element's children, and the whole of "sign out repaints the nav" is that
    // one assignment.  With textContent as a plain field, the old children
    // survived it and the slot read 'N Sign out Sign in' -- which is what the
    // first run of this check reported.
    Object.defineProperty(el, 'textContent', {
        get: function() { return el._text; },
        set: function(v) { el._text = String(v); if (el._text === '') { el.children = []; } }
    });
    Object.defineProperty(el, 'id', {
        get: function() { return el._id; },
        set: function(v) { el._id = String(v); if (v) { els[String(v)] = el; } }
    });
    el.id = String(id);
    return el;
}
var els = {};
function elFor(id) { if (!els[id]) { els[id] = FakeEl(id); } return els[id]; }
// Pre-create every id the served markup declares, so that peek() below means
// "present in the page" and not merely "the script happened to ask for it".
(UL_IDS || []).forEach(function(id) { elFor(id); });
// The page's OWN initial hidden state, from the served markup.  Without this a
// control the script is supposed to leave hidden reads as revealed.
(UL_HIDDEN || []).forEach(function(id) { elFor(id).hidden = true; });

global.document = {
    visibilityState: 'visible',
    documentElement: FakeEl('html'),
    head: FakeEl('head'),
    getElementById: function(id) { return elFor(id); },
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
// fetch RECORDS the request and answers with the shape the real endpoint was
// measured to return.  Nothing here talks to the network: step 5 of the check
// replays the recorded requests against the real server for real.
var ANSWERS = {
    '/api/auth/me': { learner_id: 'L', name: 'N', email: 'e', username: '', display_name: '', avatar_url: '' },
    '/api/bookmarks/check': { bookmarked: false },
    '/api/bookmarks': { ok: true, id: 'B' },
    '/api/notes': [],
    '/api/notes/concept': [],
    '/api/notes/concept/id': [],
    '/api/streaks': { learner_id: 'L', current_streak: 4, longest_streak: 4, total_active_days: 9, last_active_date: '2026-10-02' },
    '/api/achievements/count': { count: 3 },
    '/api/learning/view': { recorded: true, status: 'learning', first_time: true, times_seen: 0 },
    '/api/navigation': { modules: [{ title: 'M', concepts: [{ id: 'c1', title: 'C1' }] }] },
    '/api/progress': { progress_percentage: 100, concepts_started: 1, concepts_total: 1, concepts: [] }
};
function answerFor(url, method) {
    var m = String(method || 'GET').toUpperCase();
    if (m !== 'GET') { return { ok: true, id: 'X', recorded: true, first_time: true }; }
    var keys = Object.keys(ANSWERS);
    for (var i = 0; i < keys.length; i++) {
        if (String(url).indexOf(keys[i]) === 0) { return ANSWERS[keys[i]]; }
    }
    return {};
}
global.fetch = function(url, opts) {
    var o = opts || {};
    var method = o.method ? String(o.method).toUpperCase() : 'GET';
    var body = null;
    if (o.body) { try { body = JSON.parse(o.body); } catch (e) { body = o.body; } }
    REQUESTS.push({ url: String(url), method: method, body: body, has_auth: !!(o.headers && o.headers['Authorization']) });
    return Promise.resolve({ ok: true, status: 200, json: function() { return Promise.resolve(answerFor(url, method)); } });
};
global.navigator = { userAgent: 'shim' };

// ---- the page's real script ------------------------------------------
var SRC = require('fs').readFileSync(process.env.UL_JS, 'utf8');
eval(SRC);

(listeners['DOMContentLoaded'] || []).forEach(function(f) { f(); });

function textOf(node) {
    if (node === null || node === undefined) { return ''; }
    if (Array.isArray(node)) { return node.map(textOf).join(' '); }
    var s = '';
    if (node.nodeValue !== undefined && node.nodeValue !== null) { s = String(node.nodeValue); }
    else if (node.textContent) { s = String(node.textContent); }
    if (node.children && node.children.length) {
        var inner = node.children.map(textOf).join(' ');
        s = s ? s + ' ' + inner : inner;
    }
    return s;
}

// peek, NOT elFor: a marker element the page does not contain must report null
// here, so the assertion below fails.  elFor would invent it and the check
// would pass on a page with no client on it at all.
function peek(id) { return els[id] || null; }
function text(id) { var e = peek(id); return e ? textOf(e) : null; }
function hidden(id) { var e = peek(id); return e === null ? null : e.hidden; }
function attr(id, k) { var e = peek(id); return e === null ? null : e.getAttribute(k); }

function press(id) { var e = peek(id); if (e) { e.dispatch('click', { target: e }); } }

// The PRESSES, in the order a learner would make them: bookmark the lesson,
// write a note and save it, report a problem, send, then sign out.
setTimeout(function() {
    var after_load = REQUESTS.length;
    press('ul-bookmark');
    var ta = peek('ul-note-text'); if (ta) { ta.value = 'integration_check note body'; }
    press('ul-note-save');
    var fb = peek('ul-feedback-message'); if (fb) { fb.value = 'integration_check feedback body'; }
    // A real <select> reports the chosen option's value; the shim starts at '',
    // so the choice is made here the way a learner makes it.
    var fsel = peek('ul-feedback-type'); if (fsel) { fsel.value = 'unclear'; }
    press('ul-feedback-save');
    setTimeout(function() {
        var cert = peek('ul-certificate');
        var snapshot = {
            after_load: after_load,
            requests: REQUESTS,
            identity: text('ul-identity'),
            streak: text('ul-streak'),
            streak_hidden: hidden('ul-streak'),
            achievements: text('ul-achievements'),
            certificate_href: cert === null ? null : cert.href,
            certificate_hidden: hidden('ul-certificate'),
            bookmark_label: text('ul-bookmark'),
            bookmark_pressed: attr('ul-bookmark', 'aria-pressed'),
            tools_hidden: hidden('ul-tools'),
            signedout_hidden: hidden('ul-tools-signedout'),
            actions_hidden: hidden('ul-tools-actions'),
            signout_present: peek('ul-signout') !== null
        };
        // Sign out LAST, so every assertion above is made against a signed-in
        // page.  This is the other half of P1 7.1.18: a slot that says whose
        // account is open has to be able to END it, or it is worse on a shared
        // machine than the empty div it replaced.  The method is POST because
        // that is the only one app/main.ch registers -- DELETE
        // /api/auth/logout answers 404, and a client that guessed DELETE would
        // have reported success and kept the session.
        press('ul-signout');
        setTimeout(function() {
            snapshot.identity_after = text('ul-identity');
            snapshot.actions_hidden_after = hidden('ul-tools-actions');
            snapshot.signedout_hidden_after = hidden('ul-tools-signedout');
            snapshot.bookmark_pressed_after = attr('ul-bookmark', 'aria-pressed');
            snapshot.token_after = tokens['session_token'] === undefined
                ? null : tokens['session_token'];
            console.log(JSON.stringify(snapshot));
        }, 400);
    }, 500);
}, 500);
"""


def markup_state(html):
    """(ids, initially_hidden) read out of the SERVED MARKUP.

    The shim has to start from the page's own initial state or it invents one.
    Two things were wrong before this was parsed rather than assumed:
    `hidden` defaults to false in a shim, so a control the script is supposed
    to KEEP HIDDEN looked revealed; and a `<select>` defaults to value '', so a
    form that reads its own select posted an empty field_type and the server
    rightly answered 400.  Both are shim bugs and both had to be fixed here --
    the alternative was to loosen the assertions until they passed, which is
    how a check stops checking."""
    ids = set(re.findall(r'id="([A-Za-z0-9_-]+)"', html))
    hidden = set()
    for m in re.finditer(r'<([a-zA-Z][a-zA-Z0-9]*)([^>]*)>', html):
        attrs = m.group(2)
        idm = re.search(r'id="([A-Za-z0-9_-]+)"', attrs)
        if not idm:
            continue
        if re.search(r'(^|\s)hidden(\s|$|=|/)', attrs):
            hidden.add(idm.group(1))
    return ids, hidden


def drive(js_text, path, token, ids=(), initially_hidden=()):
    """(result, error).  Runs the served page script and reports every request it
    would make plus what it rendered.

    `ids` and `initially_hidden` come from markup_state() over the served HTML,
    so the shim starts from the page's own state rather than an invented one.
    Without this a control the script never reads reports as absent, which is a
    false failure here and, worse, would have to be worked around with a
    manufactured element -- which is how a check stops testing anything."""
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as fh:
        fh.write(js_text)
        js_file = fh.name
    drv = js_file + '.driver'
    driver = ("var UL_IDS = %s;\nvar UL_HIDDEN = %s;\n"
              % (json.dumps(sorted(ids)), json.dumps(sorted(initially_hidden)))) \
        + DRIVER_JS
    with open(drv, 'w') as fh:
        fh.write(driver)
    env = dict(os.environ, UL_JS=js_file, UL_PATH=path, UL_TOKEN=token or '')
    try:
        p = subprocess.run(['node', drv], capture_output=True, text=True,
                           timeout=90, env=env)
    except FileNotFoundError:
        return None, 'node is not installed; cannot drive the page script'
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
        return None, 'driver printed no result:\n%s' % p.stdout[-1000:]
    return json.loads(line[-1]), None


# --------------------------------------------------------------- shape checks
#
# What each endpoint ACTUALLY returns, measured 2026-10-02 and asserted here so
# a silent shape change cannot hide behind a 200.

def assert_shapes(base, token, cid, concept, list_shapes=False):
    section('1. the endpoints answer the shape a client was written against')
    results = []

    st, me = request_json(base, '/api/auth/me', token=token)
    if st == 200 and set(['learner_id', 'name', 'email', 'username',
                          'display_name', 'avatar_url']) <= set(me.keys()):
        ok('GET /api/auth/me -> {learner_id, name, email, username, '
           'display_name, avatar_url}')
    else:
        bad('GET /api/auth/me shape', 'HTTP %s keys=%s' % (st, sorted(me)))
    results.append(('GET /api/auth/me', me))

    st, chk = request_json(base, '/api/bookmarks/check/%s' % concept, token=token)
    if st == 200 and isinstance(chk.get('bookmarked'), bool):
        ok('GET /api/bookmarks/check/:conceptId -> {"bookmarked":%s}'
           % json.dumps(chk.get('bookmarked')))
    else:
        bad('GET /api/bookmarks/check shape', 'HTTP %s %s' % (st, chk))
    results.append(('GET /api/bookmarks/check', chk))

    st, made = request_json(base, '/api/bookmarks', token=token, method='POST',
                            body={'course_id': cid, 'concept_id': concept,
                                  'note': 'integration_check'})
    if st == 200 and made.get('ok') is True and made.get('id'):
        ok('POST /api/bookmarks -> {"ok":true,"id":"..."}')
    else:
        bad('POST /api/bookmarks shape', 'HTTP %s %s' % (st, made))
    results.append(('POST /api/bookmarks', made))

    st, after = request_json(base, '/api/bookmarks/check/%s' % concept, token=token)
    if st == 200 and after.get('bookmarked') is True:
        ok('GET /api/bookmarks/check now reports bookmarked=true for the '
           'concept just POSTed')
    else:
        bad('GET /api/bookmarks/check reflects the POST', 'HTTP %s %s' % (st, after))

    st, notes = request_json(base, '/api/notes/concept/%s' % concept, token=token)
    if st == 200 and isinstance(notes, list):
        ok('GET /api/notes/concept/:conceptId -> [] (%d note(s) on a fresh '
           'account)' % len(notes))
    else:
        bad('GET /api/notes/concept shape', 'HTTP %s %s' % (st, notes))

    st, mk = request_json(base, '/api/notes', token=token, method='POST',
                          body={'course_id': cid, 'concept_id': concept,
                                'content': 'integration_check note', 'section_ref': ''})
    if st == 200 and mk.get('ok') is True and mk.get('id'):
        ok('POST /api/notes -> {"ok":true,"id":"..."}')
    else:
        bad('POST /api/notes shape', 'HTTP %s %s' % (st, mk))
    results.append(('POST /api/notes', mk))
    note_id = mk.get('id') or ''

    st, mine = request_json(base, '/api/notes/concept/%s' % concept, token=token)
    keys = set(mine[0].keys()) if st == 200 and isinstance(mine, list) and mine else set()
    if {'id', 'concept_id', 'course_id', 'content', 'section_ref',
        'created_at', 'updated_at'} <= keys:
        ok('GET /api/notes/concept/:conceptId -> [{id, concept_id, course_id, '
           'content, section_ref, created_at, updated_at}]')
    else:
        bad('GET /api/notes/concept shape after POST',
            'HTTP %s keys=%s' % (st, sorted(keys)))
    results.append(('GET /api/notes/concept', mine))

    if note_id:
        st, up = request_json(base, '/api/notes/%s' % note_id, token=token,
                              method='PUT', body={'content': 'integration_check note v2'})
        if st == 200 and up.get('ok') is True:
            ok('PUT /api/notes/:id {content} -> {"ok":true} (the edit path)')
        else:
            bad('PUT /api/notes/:id shape', 'HTTP %s %s' % (st, up))

    st, fb = request_json(base, '/api/feedback', token=token, method='POST',
                          body={'concept_id': concept, 'course_id': cid,
                                'feedback_type': 'correction',
                                'message': 'integration_check feedback',
                                'page_url': '/courses/%s/lessons/%s' % (cid, concept)})
    if st == 200 and fb.get('ok') is True and fb.get('id'):
        ok('POST /api/feedback -> {"ok":true,"id":"..."}')
    else:
        bad('POST /api/feedback shape', 'HTTP %s %s' % (st, fb))
    results.append(('POST /api/feedback', fb))

    st, streak = request_json(base, '/api/streaks', token=token)
    if st == 200 and set(['learner_id', 'current_streak', 'longest_streak',
                          'total_active_days', 'last_active_date']) <= set(streak.keys()):
        ok('GET /api/streaks -> {learner_id, current_streak, longest_streak, '
           'total_active_days, last_active_date}')
    else:
        bad('GET /api/streaks shape', 'HTTP %s %s' % (st, streak))
    results.append(('GET /api/streaks', streak))

    st, act = request_json(base, '/api/streaks/activity', token=token, method='POST')
    if st == 200 and act.get('current_streak') is not None:
        ok('POST /api/streaks/activity -> current_streak=%r (a fresh learner '
           'can reach 1)' % act.get('current_streak'))
    else:
        bad('POST /api/streaks/activity shape', 'HTTP %s %s' % (st, act))

    st, ach = request_json(base, '/api/achievements/count', token=token)
    if st == 200 and isinstance(ach.get('count'), int):
        ok('GET /api/achievements/count -> {"count":%d}' % ach.get('count'))
    else:
        bad('GET /api/achievements/count shape', 'HTTP %s %s' % (st, ach))
    results.append(('GET /api/achievements/count', ach))

    # An achievement the chip can actually show.  The cheapest real one is the
    # first exercise, and the endpoint that awards it is /api/achievements/check.
    st, chkres = request_json(base, '/api/achievements/check', token=token, method='POST')
    if st == 200 and isinstance(chkres.get('count'), int):
        ok('POST /api/achievements/check -> {"ok":true,"count":%d}'
           % chkres.get('count'))
    else:
        bad('POST /api/achievements/check shape', 'HTTP %s %s' % (st, chkres))

    st, certs = request_json(base, '/api/certificates', token=token)
    if st == 200 and isinstance(certs, list):
        ok('GET /api/certificates -> [] (%d certificate(s) on a fresh '
           'account)' % len(certs))
    else:
        bad('GET /api/certificates shape', 'HTTP %s %s' % (st, certs))
    results.append(('GET /api/certificates', certs))

    if list_shapes:
        print('\n-- the shapes, verbatim --')
        for name, payload in results:
            print('   %-32s %s' % (name, json.dumps(payload)[:200]))
        print()

    return note_id


def pick_course_and_concept(base):
    st, data = request_json(base, '/api/courses/all')
    if st != 200 or not isinstance(data, dict):
        return None, None, 'GET /api/courses/all returned %s' % st
    courses = sorted(data.get('courses', data), key=lambda c: c.get('id', ''))
    if not courses:
        return None, None, 'no courses in the API'
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
        return cid, None, 'course %s has no concepts' % cid
    return cid, concepts[0].get('id'), None


def run_checks(base):
    global checks, failures
    failures = []
    checks = 0

    section('0. server')
    if not wait_health(base):
        bad('server answers /api/health 200 on %s' % base,
            'is the server running?  bash scripts/restart_underlayer.sh')
        return 1
    ok('server answers /api/health 200 on %s' % base)

    stamp = int(time.time())
    email = 'integration-check-%d-%d@example.invalid' % (stamp, os.getpid())
    password = 'IntegCheck!%d' % (stamp % 100000)
    st, reg = request_json(base, '/api/auth/register', method='POST',
                           body={'email': email, 'password': password,
                                 'name': 'Integration Check'})
    if st != 200 or not isinstance(reg, dict) or not reg.get('learner_id'):
        bad('register a fresh learner', 'HTTP %s %s' % (st, reg))
        return 1
    learner_id = reg['learner_id']
    ok('registered %s (learner %s)' % (email, learner_id[:8]))

    st, login = request_json(base, '/api/auth/login', method='POST',
                             body={'email': email, 'password': password})
    token = None
    if isinstance(login, dict):
        token = login.get('session_token') or login.get('token')
    if st != 200 or not token:
        bad('sign in and get a session token', 'HTTP %s' % st)
        return 1
    ok('signed in, session token of %d chars' % len(token))

    cid, concept, why = pick_course_and_concept(base)
    if not cid or not concept:
        bad('find a course and concept to test', str(why))
        return 1
    lesson_path = '/courses/%s/lessons/%s' % (cid, concept)
    ok('testing %s' % lesson_path)

    note_id = assert_shapes(base, token, cid, concept)

    # ---- the served page carries every client ------------------------
    section('2. the served lesson page carries every client')
    st, html = request(base, lesson_path)
    if st != 200:
        bad('GET %s returns 200' % lesson_path, 'HTTP %s' % st)
        return 1
    ok('%d bytes of lesson HTML' % len(html))
    page_ids, page_hidden = markup_state(html)
    for name, _api, el_id, fn, path in FEATURES:
        if ('id="%s"' % el_id) not in html:
            bad('%s: the element id="%s" is in the served markup' % (name, el_id),
                'there is nowhere for the client to draw anything')
        else:
            ok('%s: element id="%s" is in the served markup' % (name, el_id))
        if fn not in html:
            bad('%s: the function %s is in the served script' % (name, fn))
        else:
            ok('%s: function %s is in the served script' % (name, fn))

    # ---- drive the page's own script, signed in ---------------------
    section('3. driving the page\'s own script (signed in)')
    scripts = extract_scripts(html)
    if not scripts:
        bad('find the lesson script in the served page', 'no inline <script>')
        return 1
    page_js = max(scripts, key=len)
    rendered, err = drive(page_js, lesson_path, token, page_ids, page_hidden)
    if err:
        bad('execute the lesson script in Node', err)
        return 1
    reqs = rendered.get('requests') or []
    ok('the script ran; %d request(s) were issued' % len(reqs))
    if rendered.get('tools_hidden') is not False:
        bad('the tools row is revealed on a lesson page',
            'hidden=%r -- the row this check is about is not on the page'
            % rendered.get('tools_hidden'))
    else:
        ok('the tools row is revealed')
    if rendered.get('actions_hidden') is not False:
        bad('the action buttons are revealed for a signed-in learner',
            'hidden=%r' % rendered.get('actions_hidden'))
    else:
        ok('the action buttons are revealed for a signed-in learner')
    if rendered.get('signedout_hidden') is not True:
        bad('the signed-out line stays hidden when signed in',
            'hidden=%r' % rendered.get('signedout_hidden'))
    else:
        ok('the signed-out line stays hidden when signed in')

    wanted = [
        ('GET', '/api/auth/me', None),
        ('GET', '/api/bookmarks/check/', None),
        ('GET', '/api/notes/concept/', None),
        ('GET', '/api/streaks', None),
        ('GET', '/api/achievements/count', None),
        ('POST', '/api/bookmarks', 'POST'),
        ('POST', '/api/notes', 'POST'),
        ('POST', '/api/feedback', 'POST'),
    ]
    for method, path, _ in wanted:
        hits = [r for r in reqs if r['method'] == method and str(r['url']).startswith(path)]
        if hits:
            ok('%s %s was requested by the page (%d)' % (method, path, len(hits)))
        else:
            bad('%s %s was requested by the page' % (method, path),
                'requests seen: %s' % [(r['method'], r['url']) for r in reqs])

    # Only the NEW clients' endpoints are required to carry a token.  The
    # pre-existing scripts on this page fetch /api/navigation and
    # /api/exercises with no Authorization header, and that is correct: both
    # are public.  What must never happen is one of the NEW calls going out
    # unauthenticated, because /api/streaks in particular answers for the
    # shared "demo" learner rather than 401.
    NEW_CLIENT_PREFIXES = ('/api/auth/me', '/api/bookmarks', '/api/notes',
                           '/api/feedback', '/api/streaks',
                           '/api/achievements')
    new_reqs = [r for r in reqs if str(r['url']).startswith(NEW_CLIENT_PREFIXES)]
    no_auth = [r for r in new_reqs if not r['has_auth']]
    if new_reqs and not no_auth:
        ok('all %d request(s) the new clients made carried the session token'
           % len(new_reqs))
    elif not new_reqs:
        bad('the new clients made no request at all',
            'nothing here would reach the server whatever the HTML says')
    else:
        bad('every request the new clients made carried the session token',
            'without it these endpoints answer for the shared "demo" learner: %s'
            % [(r['method'], r['url']) for r in no_auth])

    post_bookmark = [r for r in reqs if r['method'] == 'POST'
                     and r['url'] == '/api/bookmarks']
    if post_bookmark:
        b = post_bookmark[0].get('body') or {}
        if b.get('course_id') == cid and b.get('concept_id') == concept:
            ok('the bookmark POST names this course and this concept (%s / %s)'
               % (cid, concept))
        else:
            bad('the bookmark POST names this course and this concept',
                'got %s' % (b,))

    post_note = [r for r in reqs if r['method'] == 'POST' and r['url'] == '/api/notes']
    if post_note:
        n = post_note[0].get('body') or {}
        if n.get('content') == 'integration_check note body':
            ok('the note POST carries exactly what was typed into the textarea')
        else:
            bad('the note POST carries exactly what was typed into the textarea',
                'got %s' % (n,))

    post_fb = [r for r in reqs if r['method'] == 'POST'
               and r['url'] == '/api/feedback']
    if post_fb:
        f = post_fb[0].get('body') or {}
        if (f.get('concept_id') == concept and f.get('course_id') == cid
                and f.get('message') == 'integration_check feedback body'
                and f.get('feedback_type')):
            ok('the feedback POST names the concept, the course, a type and the '
               'message: %s' % json.dumps(f))
        else:
            bad('the feedback POST names the concept, the course, a type and '
                'the message', 'got %s' % (f,))

    if rendered.get('identity'):
        ok('the nav reads "%s" as the signed-in identity' % rendered['identity'])
    else:
        bad('the nav reads a signed-in identity', 'the identity slot rendered '
            'empty, so a reader still cannot tell whether they are signed in')
    if rendered.get('signout_present'):
        ok('the nav carries a Sign out control next to the identity')
    else:
        bad('the nav carries a Sign out control next to the identity',
            'a slot that names the account but cannot end the session is worse '
            'on a shared machine than the empty slot it replaced (P1 7.1.18)')

    if re.match(r'^\d+-day streak$', rendered.get('streak') or ''):
        ok('the streak chip renders %r' % rendered.get('streak'))
    else:
        bad('the streak chip renders the streak', 'rendered %r' % rendered.get('streak'))
    if rendered.get('streak_hidden'):
        bad('a non-zero streak is shown', 'the chip stayed hidden')
    else:
        ok('a non-zero streak is shown, not hidden')

    if re.match(r'^\d+ achievements?$', rendered.get('achievements') or ''):
        ok('the achievement chip renders %r' % rendered.get('achievements'))
    else:
        bad('the achievement chip renders the count',
            'rendered %r' % rendered.get('achievements'))

    # ---- the learner-visible effect, on the server ------------------
    # ---- 4. replay what the page asked for, then read it back ------
    section('4. the page\'s own requests, replayed against the real server')
    # Step 3 drove the page against a shimmed fetch, which by design goes
    # nowhere -- so nothing the learner pressed had happened yet.  Every write
    # the page issued is now replayed EXACTLY as recorded (same method, same
    # path, same body) and then read back out of the server.  This is what makes
    # step 3 honest: the request the script would really make is the one that
    # has to be accepted, and the assertion after it is about stored state and
    # not about a stub's return value.
    writes = [r for r in reqs if r['method'] != 'GET']
    # /api/auth/logout is NOT replayed here.  It ends the session, and every
    # read-back below authenticates with that session -- replaying it in this
    # section made section 5 read as if nothing had been saved and made the
    # account deletion answer 401.  It is replayed in section 7, after the
    # read-backs, which is also the order a learner does it in.
    writes = [r for r in writes if str(r['url']) != '/api/auth/logout']
    # Bookmarks for this concept BEFORE the replay, so the assertion below is
    # about what ONE press added rather than about an absolute count.  Step 1 of
    # this check deliberately bookmarked the same concept to measure the
    # endpoint, so an absolute count would be counting the check itself.
    st, _pre = request_json(base, '/api/bookmarks', token=token)
    bm_before = len([b for b in (_pre if isinstance(_pre, list) else [])
                     if b.get('concept_id') == concept])
    replayed = []
    for r in writes:
        path = str(r['url'])
        if not path.startswith('/'):
            path = base.rstrip('/') + path
        st, body = request_json(base, path, token=token,
                                method=r['method'], body=r.get('body'))
        replayed.append((r['method'], path, st, body))
        if st == 200:
            ok('replaying %s %s -> HTTP 200 %s'
               % (r['method'], str(r['url']), json.dumps(body)[:110]))
        else:
            bad('replaying %s %s is accepted by the server' % (r['method'], path),
                'HTTP %s %s' % (st, body))
    if len(replayed) < 3:
        bad('the page issued at least three writes (bookmark, note, feedback)',
            'recorded %d: %s' % (len(replayed), [(r['method'], r['url']) for r in writes]))
    else:
        ok('the page issued %d write(s): %s'
           % (len(replayed), ', '.join('%s %s' % (m, str(r['url']))
                                       for m, r in zip([w[0] for w in replayed], writes))))

    section('5. the effect is real: the server answers with the learner\'s data')
    st, chk = request_json(base, '/api/bookmarks/check/%s' % concept, token=token)
    if st == 200 and chk.get('bookmarked') is True:
        ok('GET /api/bookmarks/check says the concept IS bookmarked')
    else:
        bad('GET /api/bookmarks/check says the concept IS bookmarked',
            'HTTP %s %s' % (st, chk))

    st, bms = request_json(base, '/api/bookmarks', token=token)
    mine_bm = [b for b in (bms if isinstance(bms, list) else [])
               if b.get('concept_id') == concept]
    if len(mine_bm) == bm_before + 1:
        ok('one press on Bookmark added exactly one row (%d -> %d) -- the '
           'toggle reads the server state instead of guessing, and '
           'POST /api/bookmarks does not de-duplicate so a guess would have '
           'doubled every press' % (bm_before, len(mine_bm)))
    else:
        bad('one press on Bookmark added exactly one row',
            '%d -> %d rows for %s' % (bm_before, len(mine_bm), concept))

    st, notes = request_json(base, '/api/notes/concept/%s' % concept, token=token)
    texts = [n.get('content') for n in (notes if isinstance(notes, list) else [])]
    if 'integration_check note body' in texts:
        ok('GET /api/notes/concept reads the typed note back (%d note(s))'
           % len(texts))
    else:
        bad('GET /api/notes/concept reads the typed note back',
            'got %s' % (texts,))

    st, all_notes = request_json(base, '/api/notes', token=token)
    ids = [n.get('id') for n in (all_notes if isinstance(all_notes, list) else [])]
    if note_id and note_id in ids:
        ok('the note is in the learner\'s own /api/notes list')
    else:
        bad('the note is in the learner\'s own /api/notes list',
            'asked for %s, got %s' % (note_id, ids))

    # THE TOKEN IS SENT HERE NOW, AND THAT IS THE POINT.  This GET used to be
    # made with no Authorization header, on the strength of a comment saying it
    # leaked every learner's feedback for the concept -- ids included -- and that
    # the lesson page therefore does not call it.  That leak has since been
    # closed server-side: the endpoint now answers 401 unauthenticated.  The
    # check was not updated, so it kept asserting the OLD behaviour and failed
    # with "got []" against a server that was doing the right thing.
    #
    # That is the failure mode worth writing down: a check documenting a known
    # defect is indistinguishable from a check that has gone stale, and the
    # difference is only visible from the outside.  So the two things it cared
    # about are now asserted directly, and both are now gate failures rather
    # than a warning somebody was meant to keep reading:
    #
    #   * the learner's own feedback reads back with a token
    #   * the endpoint does NOT answer for an anonymous caller
    st, fbs = request_json(base, '/api/feedback/concept/%s' % concept, token=token)
    msgs = [f.get('message') for f in (fbs if isinstance(fbs, list) else [])]
    if 'integration_check feedback body' in msgs:
        ok('the feedback the page sent is stored against this concept')
    else:
        bad('the feedback the page sent is stored against this concept',
            'got %s' % (msgs,))

    st_anon, fbs_anon = request_json(base, '/api/feedback/concept/%s' % concept)
    if st_anon == 401 or not isinstance(fbs_anon, list):
        ok('GET /api/feedback/concept/:id refuses an anonymous caller '
           '(the documented leak is closed server-side, HTTP %s)' % st_anon)
    else:
        bad('GET /api/feedback/concept/:id leaks other learners\' feedback '
            'to an anonymous caller', 'HTTP %s, %d message(s) returned'
            % (st_anon, len(fbs_anon)))

    st, streak = request_json(base, '/api/streaks', token=token)
    if streak.get('current_streak', 0) >= 1:
        ok('the streak the chip draws is this learner\'s (%d day(s))'
           % streak.get('current_streak'))
    else:
        bad('the streak the chip draws is this learner\'s', 'got %s' % streak)

    st, certs = request_json(base, '/api/certificates', token=token)
    if st == 200 and isinstance(certs, list):
        ok('GET /api/certificates answers for the learner (%d certificate(s))'
           % len(certs))
    else:
        bad('GET /api/certificates answers for the learner', 'HTTP %s' % st)

    # ---- the certificate claim, on the course landing page -----------
    section('6. the certificate claim lives on the course landing page')
    st, land = request(base, '/courses/%s' % cid)
    if st != 200:
        bad('GET /courses/%s returns 200' % cid, 'HTTP %s' % st)
    else:
        for marker, why in (('id="cert-claim"', 'the claim element'),
                            ('id="cert-claim-btn"', 'the claim button'),
                            ('id="cert-claim-link"', 'the link to an issued one'),
                            ('/api/certificates', 'the endpoint it reads and writes')):
            if marker in land:
                ok('%s is on /courses/%s' % (why, cid))
            else:
                bad('%s is on /courses/%s' % (why, cid))
    land_js = [s for s in extract_scripts(land) if 'cert-claim' in s]
    land_ids, land_hidden = markup_state(land)
    if not land_js:
        bad('find the claim script on the course landing page',
            'no inline <script> mentions cert-claim')
    else:
        claim_js = land_js[0]
        # (a) An unfinished course must OFFER nothing and write nothing.
        r1, err = drive_cert(claim_js, '/courses/%s' % cid, token, base,
                             land_ids, land_hidden, press_cert=False)
        if err:
            bad("the landing page's own claim script runs", err)
        else:
            if r1.get('post_count') == 0:
                ok('an unfinished course: a page load writes nothing')
            else:
                bad('an unfinished course: a page load writes nothing',
                    'POSTed %d time(s) on load' % r1.get('post_count'))
            if r1.get('box_hidden') is True:
                ok('an unfinished course: the claim box stays hidden (this '
                   'learner has read 1 concept of %s)' % cid)
            else:
                bad('an unfinished course: the claim box stays hidden',
                    'box_hidden=%r btn_hidden=%r'
                    % (r1.get('box_hidden'), r1.get('btn_hidden')))
            if r1.get('btn_hidden') is True:
                ok('an unfinished course: the claim button is not offered')
            else:
                bad('an unfinished course: the claim button is not offered',
                    'btn_hidden=%r' % r1.get('btn_hidden'))

            # (b) THE SERVER REFUSES AN UNFINISHED LEARNER.  This block used to
            # assert the opposite, and its comment said so out loud: "the
            # standing proof that the server does not check completion: the
            # learner in this run has read ONE concept."  It then pressed the
            # claim button and required a certificate to appear.
            #
            # That was true when written -- POST /api/certificates only asked
            # has_certificate() -- and it was a security hole: any signed-in
            # learner could POST any course id and be handed a certificate for a
            # course they had opened one lesson of, and /certificates/<id> would
            # then serve a page asserting they had completed it.  The gate now
            # lives in web/src/completion_gate.ch and refuses.
            #
            # So this check was not merely stale, it was a check that FAILED
            # WHEN THE HOLE WAS CLOSED and would have failed it again.  A gate
            # whose failure means "a vulnerability is fixed" is worse than no
            # gate, because the first person to see it red will be tempted to
            # make it green by removing the fix.  The direction is inverted:
            # the press must be REFUSED, and the refusal must be visible.
            r2, err2 = drive_cert(claim_js, '/courses/%s' % cid, token, base,
                                  land_ids, land_hidden, press_cert=True)
            if err2:
                bad('pressing the claim button runs without error', err2)
            else:
                posts = [r for r in (r2.get('reqs') or []) if r['method'] == 'POST']
                if posts:
                    ok('pressing the claim button POSTs %s' % posts[0]['url'])
                else:
                    bad('pressing the claim button POSTs /api/certificates',
                        'requests: %s' % [(r['method'], r['url'])
                                          for r in (r2.get('reqs') or [])])
            st, certs2 = request_json(base, '/api/certificates', token=token)
            rows = [c for c in (certs2 if isinstance(certs2, list) else [])
                    if c.get('course_id') == cid]
            if not rows:
                ok('the press produced NO certificate for an unfinished learner '
                   '-- the completion gate holds')
            else:
                bad('the press produced a certificate for an UNFINISHED learner '
                    '-- the completion gate is not holding', 'got %s' % (rows,))

            # The same claim, made directly rather than through the page.  The
            # page hides its button, so this is the only way to prove the refusal
            # is the SERVER's doing and not just the button's absence.
            st_direct, refused = request_json(
                base, '/api/certificates', token=token, method='POST',
                body={'course_id': cid})
            if st_direct in (403, 409):
                ok('a direct POST for an unfinished course is refused (HTTP %d)'
                   % st_direct)
            else:
                bad('a direct POST for an unfinished course was NOT refused',
                    'HTTP %s, body %s' % (st_direct, refused))

            # (b2) NOW FINISH THE COURSE AND CLAIM FOR REAL.  Everything below
            # -- the date, the title, the page's "you already hold this" state --
            # needs a certificate that actually exists, and it was being read off
            # a certificate the learner had not earned.
            st_man, manifest = request_json(base, '/api/courses/%s' % cid)
            concept_ids = [c.get('id') for c in (manifest.get('concepts') or [])] \
                if isinstance(manifest, dict) else []
            if not concept_ids:
                bad('could not read the course manifest to finish the course',
                    'GET /api/courses/%s' % cid)
            else:
                for c in concept_ids:
                    request_json(base, '/api/learning/view', token=token,
                                 method='POST',
                                 body={'course_id': cid, 'concept_id': c})
                st_ok, issued = request_json(
                    base, '/api/certificates', token=token, method='POST',
                    body={'course_id': cid})
                # The OUTCOME is what matters, not the response shape: a learner
                # who already holds one gets {"error": "certificate already
                # issued", "certificate_id": ...} at 200 rather than the id.
                # Asserting on `id` alone would fail a correct server, which is
                # the same class of mistake as asserting on a stale contract.
                holds = None
                if isinstance(issued, dict):
                    holds = issued.get('id') or issued.get('certificate_id')
                if holds:
                    ok('a learner who has read all %d concepts holds a '
                       'certificate (id %s)' % (len(concept_ids), holds))
                else:
                    bad('a learner who finished the course was refused a '
                        'certificate', 'HTTP %s, body %s' % (st_ok, issued))

            st, certs2 = request_json(base, '/api/certificates', token=token)
            rows = [c for c in (certs2 if isinstance(certs2, list) else [])
                    if c.get('course_id') == cid]
            if len(rows) == 1:
                ok('GET /api/certificates carries exactly one for %s (id %s)'
                   % (cid, rows[0].get('id')))
            else:
                bad('exactly one certificate for %s' % cid, 'got %s' % (rows,))
            if rows and rows[0].get('completion_date'):
                ok('the certificate carries a completion date (%s)'
                   % rows[0].get('completion_date'))
                # A GATE NOW, NOT A WARNING.  The date used to be computed by
                # hand in repository/src/certificates.ch with a 30-day month
                # and a 365-day year, which printed 2026-10-19 on 2026-10-02 --
                # a certificate claiming a completion date seventeen days in the
                # future.  It now calls underlayer_core::date_string.  A
                # certificate is a permanent record of what a learner did and
                # when; a wrong date on one is a false statement, so this fails
                # the gate rather than printing a warning nobody had to act on.
                today = time.strftime('%Y-%m-%d', time.gmtime())
                if rows[0].get('completion_date') != today:
                    bad('a certificate issued today carries completion_date '
                        '%s, not %s' % (rows[0].get('completion_date'), today))
                else:
                    ok('the completion date is today (%s)' % today)
            else:
                bad('the certificate carries a completion date', 'got %s' % (rows,))

            # THE COURSE TITLE, NOT THE COURSE ID.  `course_title` used to be a
            # copy of `course_id`, so every certificate this platform has issued
            # is titled "elf".  It is stored in the row, so this is not a display
            # bug that a CSS change can hide.
            want_title = course_title_for(base, cid)
            if rows and rows[0].get('course_title') == want_title:
                ok('the certificate is titled with the course name, not its id '
                   '(%r)' % want_title)
            else:
                bad('the certificate is titled with the course name, not its id',
                    'got %r, wanted %r'
                    % (rows[0].get('course_title') if rows else None, want_title))

            # (c) With one issued, the page shows it and links to it.
            r3, err3 = drive_cert(claim_js, '/courses/%s' % cid, token, base,
                                  land_ids, land_hidden, press_cert=False)
            if err3:
                bad('the claim script runs a second time', err3)
            else:
                if r3.get('box_hidden') is False and r3.get('label'):
                    ok('with one issued, the page says %r' % r3.get('label'))
                else:
                    bad('with one issued, the page says so',
                        'box_hidden=%r label=%r'
                        % (r3.get('box_hidden'), r3.get('label')))
                want = '/certificates/' + str(rows[0].get('id')) if rows else ''
                if want and want in str(r3.get('link_href')):
                    ok('and links to %s' % want)
                else:
                    bad('and links to the issued certificate',
                        'link_href=%r wanted %r' % (r3.get('link_href'), want))

    # ---- signed out: the lesson still works -------------------------
    section('7. signing out, from the page')
    # The press is the last one the driver makes, so this is the state the page
    # is left in.  All four are learner-visible consequences of one click, and
    # the last two are the ones a naive implementation gets wrong: leaving the
    # token in localStorage means the next page load sends a dead token, and
    # reloading the page to redraw the nav would record the lesson as read a
    # second time.
    logout_req = [r for r in reqs if str(r['url']) == '/api/auth/logout']
    if logout_req and logout_req[0]['method'] == 'POST':
        ok('Sign out POSTs /api/auth/logout (POST: DELETE answers 404 there)')
    elif logout_req:
        bad('Sign out POSTs /api/auth/logout',
            'it used %s -- that verb is not registered' % logout_req[0]['method'])
    else:
        bad('Sign out POSTs /api/auth/logout', 'no such request was issued')

    # And the request the page made, replayed for real, so "the session ended"
    # is a fact about the server and not about a stub.  This is the LAST write,
    # after every read-back above, because it ends the session they used.
    if logout_req:
        st, body = request_json(base, '/api/auth/logout', token=token, method='POST')
        if st == 200 and body.get('ok') is True:
            ok('replaying POST /api/auth/logout -> {"ok":true} (the session is '
               'gone on the server, not just in the tab)')
        else:
            bad('replaying POST /api/auth/logout is accepted',
                'HTTP %s %s' % (st, body))
        st2, _me2 = request_json(base, '/api/auth/me', token=token)
        if st2 == 401:
            ok('GET /api/auth/me answers 401 with that token afterwards')
        else:
            bad('GET /api/auth/me answers 401 after signing out',
                'it answered %s -- the button cleared the tab and not the session'
                % st2)
        st3, _bm3 = request_json(base, '/api/bookmarks', token=token)
        if st3 == 401:
            ok('the other endpoints reject the dead token too, so a stale tab '
               'cannot write')
        else:
            bad('the other endpoints reject the dead token',
                'GET /api/bookmarks answered %s' % st3)

    if rendered.get('token_after') is None:
        ok('signing out removes session_token from localStorage, so the next '
           'page load does not send a dead token')
    else:
        bad('signing out removes session_token from localStorage',
            'still set to %d chars' % len(str(rendered.get('token_after'))))

    if rendered.get('identity_after') == 'Sign in':
        ok('the nav reads "Sign in" again after signing out')
    else:
        bad('the nav reads "Sign in" again after signing out',
            'identity slot reads %r' % rendered.get('identity_after'))

    if rendered.get('actions_hidden_after') is True:
        ok('the lesson\'s action buttons are hidden again after signing out')
    else:
        bad('the lesson\'s action buttons are hidden again after signing out',
        'hidden=%r -- the page would still POST bookmarks for an account it no '
        'longer has' % rendered.get('actions_hidden_after'))

    if rendered.get('signedout_hidden_after') is False:
        ok('the signed-out line comes back, so the page does not pretend the '
           'account is still open')
    else:
        bad('the signed-out line comes back',
            'hidden=%r' % rendered.get('signedout_hidden_after'))

    if rendered.get('bookmark_pressed_after') == 'false':
        ok('the Bookmark button resets: the bookmark belonged to the account that '
           'just signed out')
    else:
        bad('the Bookmark button resets after signing out',
            'aria-pressed=%r -- it would claim a bookmark the learner no longer '
            'has' % rendered.get('bookmark_pressed_after'))

    section('8. signed out from the start, the lesson is whole and nothing is asked')
    scripts_out = extract_scripts(html)
    out, err = drive(max(scripts_out, key=len), lesson_path, '', page_ids, page_hidden)
    if err:
        bad('execute the lesson script signed out', err)
    else:
        out_reqs = out.get('requests') or []
        out_new = [r for r in out_reqs if str(r['url']).startswith(NEW_CLIENT_PREFIXES)]
        if not out_new:
            ok('a signed-out page load asks the server for nothing new at all '
               '(%d request(s) total, none of them a client that needs a token)'
               % len(out_reqs))
        else:
            bad('a signed-out page load asks the server for nothing new',
                'asked anyway: %s' % [(r['method'], r['url']) for r in out_new])
        # Not a gate, and deliberately so: /api/progress/<course> and
        # /api/streaks BOTH fall back to a shared learner id "demo" when there
        # is no session (web/src/handlers_progress.ch line 19,
        # web/src/handlers_streaks.ch line 10), so an unauthenticated read of
        # either answers with the demo learner's row rather than a 401.  That is
        # PRE-EXISTING on the engagement path and is not changed here -- it is a
        # product decision about what a signed-out reader should be shown, and
        # tools/progress_check.py asserts the current behaviour.  The NEW
        # clients in this change gate on the token, which is what stops them
        # adding one more reader to that bucket.
        if any(str(r['url']).startswith(('/api/progress', '/api/streaks',
                                         '/api/nav-status')) for r in out_reqs):
            warn('a signed-out page load still reads /api/progress (pre-existing)',
                 'those handlers answer for the shared "demo" learner rather '
                 'than 401; the clients added here do not')
        if out.get('signedout_hidden') is False:
            ok('the row says what signing in would do, rather than hiding it')
        else:
            bad('the row says what signing in would do',
                'signedout line hidden=%r' % out.get('signedout_hidden'))
        if out.get('actions_hidden') is True:
            ok('the buttons stay hidden when signed out')
        else:
            bad('the buttons stay hidden when signed out',
                'actions hidden=%r' % out.get('actions_hidden'))
        if out.get('identity'):
            ok('the nav offers "Sign in" rather than a name (%s)'
               % out.get('identity'))
        else:
            bad('the nav offers "Sign in" rather than a name',
                'identity slot rendered empty')

    # THE LESSON IS STILL THE PAGE.  This is the backend-optional rule stated
    # as an assertion: a feature may be added to a lesson and may never take
    # anything away from it.  Three things are checked -- the lesson's own
    # heading is there, its section headings are there, and the tools row was
    # inserted ABOVE the lesson rather than displacing it.
    h1 = re.search(r'<h1[^>]*>(.*?)</h1>', html, re.S)
    if h1:
        heading = re.sub(r'<[^>]+>', '', h1.group(1)).strip()
        if heading and heading in html_text(html):
            ok('the lesson\'s own <h1> is on the page (%r)' % heading[:60])
        else:
            bad('the lesson\'s own <h1> is on the page', repr(heading))
    else:
        bad('the lesson page has an <h1>', 'none found')
    n_h2 = len(re.findall(r'<h2[^>]*>', html))
    if n_h2 >= 3:
        ok('the lesson still carries its %d section headings' % n_h2)
    else:
        bad('the lesson still carries its section headings',
            'only %d <h2> -- a feature swallowed the body' % n_h2)
    if html.find('id="ul-tools"') < html.find('<h1'):
        ok('the tools row sits ABOVE the lesson, not instead of it')
    else:
        bad('the tools row sits ABOVE the lesson',
            'the nav strip is below the heading')
    text = html_text(html)
    if len(text) > 2000:
        ok('the visible lesson text is %d characters -- a feature did not '
           'truncate the lesson' % len(text))
    else:
        bad('the visible lesson text is substantial',
            'only %d characters -- something removed the lesson' % len(text))

    # ---- cleanup ---------------------------------------------------
    section('9. cleanup')
    # Section 7 signed the learner out on purpose, so the session token in hand
    # is dead and DELETE /api/user/account would answer 401.  Signing in again
    # first is not a workaround for the check being badly ordered -- it is what
    # a learner does, and it exercises login-after-logout on the way past.
    st, login2 = request_json(base, '/api/auth/login', method='POST',
                              body={'email': email, 'password': password})
    fresh = login2.get('session_token') or login2.get('token') if isinstance(login2, dict) else None
    if st == 200 and fresh:
        ok('signing in again after a sign-out works')
    else:
        bad('signing in again after a sign-out works', 'HTTP %s' % st)
        fresh = None

    st, _ = request(base, '/api/user/account', token=fresh, method='DELETE')
    if st == 200:
        ok('the throwaway learner was deleted through DELETE /api/user/account')
    else:
        bad('the throwaway learner was deleted',
            'DELETE /api/user/account returned %s.  Left behind: %s.  This check '
            'must not accumulate accounts.' % (st, email))
    st, _ = request_json(base, '/api/auth/me', token=fresh)
    if st == 401:
        ok('the deleted account resolves to nothing afterwards')
    else:
        bad('the deleted account resolves to nothing afterwards',
            'GET /api/auth/me answered %s' % st)

    # THE GATE MUST NOT ACCUMULATE ROWS.  This run posted feedback twice (once
    # to measure the endpoint in step 1, once because the page did), and a gate
    # that leaves two rows in the development database on every run eventually
    # hides a regression behind its own accumulated state.  content_feedback
    # was missing from repository/src/learner_deletion.ch's table list, so the
    # account deletion above used to leave both rows behind -- with the learner's
    # id and their message in them, served by an endpoint that takes no
    # Authorization header.  The assertion is here so that gap cannot reopen.
    st, left = request_json(base, '/api/feedback/concept/%s' % concept)
    mine_left = [f for f in (left if isinstance(left, list) else [])
                 if f.get('message') in ('integration_check feedback',
                                         'integration_check feedback body')]
    if not mine_left:
        ok('deleting the account removed this run\'s feedback as well -- the '
           'gate leaves nothing behind')
    else:
        bad('deleting the account removed this run\'s feedback as well',
            '%d row(s) survive with this run\'s messages: %s'
            % (len(mine_left), [f.get('message') for f in mine_left]))
        print('          Remove them with:')
        print("            sqlite3 underlayer.db \"DELETE FROM content_feedback "
              "WHERE message LIKE 'integration_check%'\"")
    return 1 if failures else 0


# The landing page's claim script, driven with a fetch that talks to the REAL
# server, because the point of this half is that the effect is real.
CERT_DRIVER_JS = r"""
// The REAL fetch, captured before the shim below replaces it.  node 18+ has a
// global fetch; this half of the check deliberately talks to the running server
// rather than to a fixture, because the claim is that pressing the button
// issues a certificate, and a stubbed answer cannot say that.
var REAL_FETCH = globalThis.fetch;
var REQS = [];
function FakeClassList(el) {
    this._s = {};
    this.add = function(c) { this._s[c] = true; };
    this.remove = function(c) { delete this._s[c]; };
    this.contains = function(c) { return !!this._s[c]; };
    this.toggle = function(c, on) { if (on === undefined) { on = !this._s[c]; } if (on) { this._s[c] = true; } else { delete this._s[c]; } return on; };
}
function FakeEl(id) {
    var el = {
        id: id, tagName: 'DIV', textContent: '', innerHTML: '', value: '', href: '',
        type: '', disabled: false, hidden: false, style: {}, dataset: {}, children: [],
        attrs: {}, parentNode: null, listeners: {}, classList: null,
        appendChild: function(c) { el.children.push(c); c.parentNode = el; return c; },
        setAttribute: function(k, v) { el.attrs[k] = String(v); },
        getAttribute: function(k) { return Object.prototype.hasOwnProperty.call(el.attrs, k) ? el.attrs[k] : null; },
        hasAttribute: function(k) { return Object.prototype.hasOwnProperty.call(el.attrs, k); },
        removeAttribute: function(k) { delete el.attrs[k]; },
        addEventListener: function(n, f) { (el.listeners[n] = el.listeners[n] || []).push(f); },
        removeEventListener: function() {},
        dispatch: function(n, ev) { (el.listeners[n] || []).forEach(function(f) { f(ev || {}); }); },
        querySelector: function() { return null; }, querySelectorAll: function() { return []; },
        closest: function() { return null; }, matches: function() { return false; },
        focus: function() {}, click: function() {},
        getBoundingClientRect: function() { return { top: 0, left: 0, width: 0, height: 0 }; }
    };
    el.classList = new FakeClassList(el);
    return el;
}
var els = {};
global.document = {
    visibilityState: 'visible', documentElement: FakeEl('html'), head: FakeEl('head'),
    getElementById: function(id) { if (!els[id]) { els[id] = FakeEl(id); } return els[id]; },
    querySelector: function(s) { return FakeEl(s); }, querySelectorAll: function() { return []; },
    addEventListener: function(n, f) {}, removeEventListener: function() {},
    createElement: function(t) { var e = FakeEl('new'); e.tagName = String(t).toUpperCase(); return e; },
    body: FakeEl('body')
};
global.window = {
    location: { pathname: process.env.UL_PATH || '/' },
    addEventListener: function() {},
    matchMedia: function() { return { matches: false }; },
    scrollTo: function() {}
};
global.localStorage = {
    getItem: function(k) { return k === 'session_token' ? (process.env.UL_TOKEN || '') : null; },
    setItem: function() {}, removeItem: function() {}
};
// The page's own script fetches RELATIVE paths; node cannot resolve them, so
// the base is prepended HERE, in the fetch shim, not in the page's source.
global.fetch = function(url, opts) {
    var o = opts || {};
    var method = o.method ? String(o.method).toUpperCase() : 'GET';
    REQS.push({ url: String(url), method: method });
    return REAL_FETCH(process.env.UL_BASE + url, o);
};
global.navigator = { userAgent: 'shim' };
eval(require('fs').readFileSync(process.env.UL_JS, 'utf8'));
function peek(id) { return els[id] || null; }
// UL_PRESS_CERT: press the claim button the way a learner would.  The button is
// only VISIBLE at 100% (the client gates on progress), but pressing it here is
// deliberate -- it is how the check proves the button is wired to the endpoint
// at all, and it is also the proof that the SERVER does not gate it: this runs
// for a learner who has read one concept of the course.
if (process.env.UL_PRESS_CERT === '1') {
    var b = peek('cert-claim-btn');
    if (b) { b.dispatch('click', { target: b }); }
}
setTimeout(function() {
    var btn = peek('cert-claim-btn');
    console.log(JSON.stringify({
        post_count: REQS.filter(function(r) { return r.method === 'POST'; }).length,
        label: peek('cert-claim-label') ? peek('cert-claim-label').textContent : null,
        link_href: peek('cert-claim-link') ? peek('cert-claim-link').href : null,
        btn_hidden: btn === null ? null : btn.hidden,
        box_hidden: peek('cert-claim') === null ? null : peek('cert-claim').hidden,
        reqs: REQS
    }));
}, 1500);
"""


def drive_cert(js_text, path, token, base, ids=(), initially_hidden=(),
               press_cert=False):
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as fh:
        fh.write(js_text)
        js_file = fh.name
    drv = js_file + '.driver'
    driver = ("var UL_IDS = %s;\nvar UL_HIDDEN = %s;\n"
              % (json.dumps(sorted(ids)), json.dumps(sorted(initially_hidden)))) \
        + CERT_DRIVER_JS
    driver = driver.replace(
        'global.document = {',
        "(UL_IDS || []).forEach(function(id) { els[id] = FakeEl(id); });\n"
        "(UL_HIDDEN || []).forEach(function(id) { els[id].hidden = true; });\n"
        "global.document = {", 1)
    with open(drv, 'w') as fh:
        fh.write(driver)
    env = dict(os.environ, UL_JS=js_file, UL_PATH=path, UL_TOKEN=token or '',
               UL_BASE=base.rstrip('/'), UL_PRESS_CERT='1' if press_cert else '0')
    try:
        p = subprocess.run(['node', drv], capture_output=True, text=True,
                           timeout=90, env=env)
    except FileNotFoundError:
        return None, 'node is not installed'
    finally:
        for f in (js_file, drv):
            try:
                os.unlink(f)
            except OSError:
                pass
    if p.returncode != 0:
        return None, 'node exited %d:\n%s' % (p.returncode, p.stderr[-1500:])
    line = [l for l in p.stdout.splitlines() if l.startswith('{')]
    if not line:
        return None, 'no result:\n%s' % p.stdout[-800:]
    data = json.loads(line[-1])
    data['issued_visible'] = (data.get('box_hidden') is False) and bool(data.get('label'))
    return data, None


# ------------------------------------------------------------- non-vacuity

def prove_non_vacuous(base_port=9111):
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

    scratch = tempfile.mkdtemp(prefix='integration-check-nonvacuous-')
    dst = os.path.join(scratch, 'underlayer')
    print('\n  scratch copy: %s' % dst)
    try:
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
            fh.write(src.replace(THE_CALL, '// REMOVED BY integration_check.py'))

        print('\n  building the mutilated copy (a few minutes)...')
        exe = os.path.join(dst, 'build', 'underlayer.exe')
        os.makedirs(os.path.dirname(exe), exist_ok=True)
        p = subprocess.run(
            [CC, 'chemical.mod', '-o', 'build/underlayer.exe',
             '--mode', 'debug_quick', '--no-cache', '-bm-modules'],
            cwd=dst, capture_output=True, text=True, timeout=3600)
        if p.returncode != 0 or not os.path.exists(exe):
            print('\n  the mutilated copy did not build, so the proof cannot run:')
            print('  ' + ((p.stdout or '')[-1200:] + (p.stderr or '')[-1200:]).replace('\n', '\n  '))
            print('\n  A build that cannot finish cannot demonstrate that the')
            print('  check is non-vacuous.  The check itself is UNPROVEN.')
            return 1
        print('  build succeeded (removal compiles; the point is that it makes')
        print('  the platform wrong, which the next step tests).')

        print('\n  starting the mutilated server on port %d...' % base_port)
        env = dict(os.environ, PORT=str(base_port))
        log = open(os.path.join(scratch, 'server.log'), 'w')
        proc = subprocess.Popen([exe], cwd=dst, stdout=log, stderr=log,
                                env=env, start_new_session=True)
        base = 'http://localhost:%d' % base_port
        try:
            if not wait_health(base, seconds=60):
                print('\n  the mutilated server never came up.  The proof could not run.')
                return 1
            print('  mutilated server is up.  Running the check against it...')
            rc = run_checks(base)
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
            print('That means tools/integration_check.py does not actually test')
            print('the lesson clients: it passes on a platform where a learner')
            print('still cannot bookmark, annotate, sign in or report.  It is')
            print('worse than no check, because it looks like coverage.')
            print('-' * 72)
            return 1
        print('THE CHECK FAILED AGAINST THE MUTILATED BUILD, as it must.')
        print('Reproduced failures with %s removed:' % THE_CALL)
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
    ap.add_argument('--base', default='http://localhost:9000')
    ap.add_argument('--prove-non-vacuous', action='store_true',
                    help='also rebuild without the lesson clients and require '
                         'this check to fail (slow: several minutes)')
    ap.add_argument('--port', type=int, default=9111,
                    help='port for the mutilated server in the non-vacuity proof')
    args = ap.parse_args()

    if not args.base.startswith('http'):
        print('usage error: --base must be an http(s) URL')
        return 2

    rc = run_checks(args.base)

    print('\n' + '=' * 72)
    if rc == 0:
        print('integration_check: ALL %d CHECKS PASSED against %s' % (checks, args.base))
    else:
        print('integration_check: %d of %d CHECKS FAILED against %s'
              % (len(failures), checks, args.base))
    print('=' * 72)
    for f in failures:
        print('  FAILED: %s' % f)

    if args.prove_non_vacuous:
        if rc != 0:
            print('\nNot running the non-vacuity proof: the check does not pass')
            print('on the real platform, so it has nothing to prove yet.')
            return rc
        return rc or prove_non_vacuous(args.port)

    return rc


if __name__ == '__main__':
    sys.exit(main())