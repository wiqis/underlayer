#!/usr/bin/env node
// session_js_check.js -- prove the shared session helper actually works.
//
// A grep for `__ulCourseId = function` in the served HTML proves nothing: the
// js_cbi macro rewrites `function(){}` into `(function(){})`, so the text a
// grep looks for is not the text that ships.  This extracts the REAL emitted
// script out of the served page and executes it, then asserts behaviour.
//
// Run: node tools/session_js_check.js <base-url>
// Exits non-zero on the first failed assertion.

const BASE = process.argv[2] || 'http://localhost:9001';

let failures = 0;
function check(name, cond, detail) {
    if (cond) { console.log('  PASS  ' + name); }
    else { failures++; console.log('  FAIL  ' + name + (detail ? '  -- ' + detail : '')); }
}

// Pull every <script> body out of a served page.
function scriptsOf(html) {
    const out = [];
    const re = /<script[^>]*>([\s\S]*?)<\/script>/g;
    let m;
    while ((m = re.exec(html)) !== null) { out.push(m[1]); }
    return out;
}

// Run a page's real script with fetch ALREADY answering `status`.
// __ulFetch closes over the `fetch` binding it was given, so swapping
// window.fetch afterwards does not reach it -- the stub has to be right at the
// moment the script is evaluated.
function run401(html, storage, pathname) {
    const calls = [];
    // Use the SAME permissive stub as run(), so the page's other top-level
    // statements (setTheme(getTheme()) in the nav, which touches
    // document.documentElement.classList) execute against something real.  A
    // thinner stub here makes this helper crash on an unrelated element and
    // reports it as a session-helper failure, which is how a check stops being
    // believed.
    const env = makeEnv(storage, '', pathname);
    const doc = env.document;
    const fetch401 = function (url, init) {
        calls.push({ url: url, init: init || {} });
        return Promise.resolve({
            status: 401,
            json: function () { return Promise.resolve({ error: 'unauthorized' }); },
        });
    };
    const body = scriptsOf(html).join('\n;\n');
    // eslint-disable-next-line no-new-func
    const fn = new Function('window', 'localStorage', 'document', 'fetch', 'console',
        'JSON', 'encodeURIComponent', 'decodeURIComponent', 'Promise', 'Error',
        'setTimeout', 'clearTimeout',
        body + '\n; return window;');
    const win = fn(env.window, env.localStorage, doc, fetch401, console,
        JSON, encodeURIComponent, decodeURIComponent, Promise, Error,
        setTimeout, clearTimeout);
    return { win: win, env: env, calls: calls };
}

// Run a page's real script with fetch answering a fixed onboarding-check
// payload.  Used for the "where does a learner land after auth" cases, where
// the answer depends on what the server says.
function runGate(html, storage, pathname, payload) {
    const env = makeEnv(storage, '', pathname);
    const body = scriptsOf(html).join('\n;\n');
    // eslint-disable-next-line no-new-func
    const fn = new Function('window', 'localStorage', 'document', 'fetch', 'console',
        'JSON', 'encodeURIComponent', 'decodeURIComponent', 'Promise', 'Error',
        'setTimeout', 'clearTimeout', body + '\n; return window;');
    const fetchGate = function () {
        return Promise.resolve({
            status: 200,
            json: function () { return Promise.resolve(payload); },
        });
    };
    const win = fn(env.window, env.localStorage, env.document, fetchGate, console,
        JSON, encodeURIComponent, decodeURIComponent, Promise, Error,
        setTimeout, clearTimeout);
    return { win: win, env: env };
}

// A DOM stub just large enough for the helper to run against.
//
// PERMISSIVE ON PURPOSE.  This stub lets an unguarded localStorage access THROW
// rather than pretending it cannot, because that throw is the defect the check
// is looking for -- but it does not let the page's own unrelated DOM calls stop
// the run.  A stub that supplies every property silently would make a page
// that is broken in a real browser look healthy here, and this file exists to
// catch exactly that.
function makeEnv(storage, search, pathname) {
    const calls = [];
    const el = new Proxy({
        innerHTML: '', textContent: '', hidden: false, href: '',
        className: '', type: '',
        addEventListener: function () {},
        appendChild: function () {},
        querySelector: function () { return null; },
        querySelectorAll: function () { return []; },
        getElementsByClassName: function () { return []; },
        getElementsByTagName: function () { return []; },
        scrollIntoView: function () {},
        style: {},
        classList: {
            add: function () {}, remove: function () {},
            contains: function () { return false; }, toggle: function () {},
        },
        children: [],
    }, {
        get: function (t, k) {
            if (k in t) { return t[k]; }
            return function () { return null; };
        },
        set: function (t, k, v) { t[k] = v; return true; },
    });
    return {
        calls: calls,
        window: {
            location: { pathname: pathname, search: search, href: pathname + search },
            addEventListener: function () {},
            matchMedia: function () { return { matches: false, addEventListener: function () {} }; },
            scrollTo: function () {},
            getComputedStyle: function () { return {}; },
        },
        localStorage: storage,
        document: {
            getElementById: function () { return el; },
            createElement: function () { return el; },
            addEventListener: function () {},
            querySelector: function () { return el; },
            querySelectorAll: function () { return []; },
            getElementsByClassName: function () { return []; },
            getElementsByTagName: function () { return []; },
            body: el,
            head: el,
            documentElement: el,
        },
        fetch: function (url, init) {
            calls.push({ url: url, init: init || {} });
            return Promise.resolve({ status: 200, json: function () { return Promise.resolve({}); } });
        },
        console: console,
        JSON: JSON,
        encodeURIComponent: encodeURIComponent,
        decodeURIComponent: decodeURIComponent,
        Promise: Promise,
        Error: Error,
        setTimeout: setTimeout,
        clearTimeout: clearTimeout,
    };
}

function run(html, storage, search, pathname) {
    const env = makeEnv(storage, search, pathname);
    const body = scriptsOf(html).join('\n;\n');
    // eslint-disable-next-line no-new-func
    const fn = new Function('window', 'localStorage', 'document', 'fetch', 'console',
        'JSON', 'encodeURIComponent', 'decodeURIComponent', 'Promise', 'Error',
        'setTimeout', 'clearTimeout',
        body + '\n; return window;');
    return {
        win: fn(env.window, env.localStorage, env.document, env.fetch, console,
            JSON, encodeURIComponent, decodeURIComponent, Promise, Error,
            setTimeout, clearTimeout),
        env: env,
    };
}

// Small helper for the gate lifecycle assertions in section 13.
async function chk2(base, auth) {
    const r = await fetch(base + '/api/onboarding/check', { headers: auth });
    return await r.json();
}

async function main() {
    console.log('session_js_check against ' + BASE);

    // ---------------------------------------------------------------------
    console.log('\n[1] the helper is emitted and defined on every page that uses it');
    for (const path of ['/progress', '/review', '/analytics']) {
        const html = await (await fetch(BASE + path)).text();
        const env = makeEnv({}, '', path);
        const win = run(html, env.localStorage, '', path).win;
        check('/' + path.slice(1) + ': __ulFetch defined',
            typeof win.__ulFetch === 'function');
        check('/' + path.slice(1) + ': __ulHeaders defined',
            typeof win.__ulHeaders === 'function');
        check('/' + path.slice(1) + ': __ulToken defined',
            typeof win.__ulToken === 'function');
        check('/' + path.slice(1) + ': __ulCourseId defined',
            typeof win.__ulCourseId === 'function');
        check('/' + path.slice(1) + ': __ulGate defined',
            typeof win.__ulGate === 'function');
    }

    // ---------------------------------------------------------------------
    console.log('\n[2] __ulCourseId reads the real course, never a hardcoded elf');
    {
        const html = await (await fetch(BASE + '/progress')).text();

        const r1 = run(html, {}, '?course_id=rvasm', '/progress').win.__ulCourseId();
        check('?course_id=rvasm -> rvasm', r1 === 'rvasm', 'got ' + r1);

        const r2 = run(html, {}, '', '/courses/pe/lessons/coff-header').win.__ulCourseId();
        check('/courses/pe/... -> pe', r2 === 'pe', 'got ' + r2);

        const r3 = run(html, {}, '?course_id=rvasm&x=1', '/progress').win.__ulCourseId();
        check('query with a second param -> rvasm', r3 === 'rvasm', 'got ' + r3);

        const r4 = run(html, {}, '?x=1&course_id=rvabi', '/progress').win.__ulCourseId();
        check('course_id as the SECOND param -> rvabi', r4 === 'rvabi', 'got ' + r4);

        // The stamped server value: this is how /review and /progress work at
        // all, since their URLs carry no course.
        const stamped = html.indexOf('__UL_COURSE_ID') !== -1;
        check('page stamps __UL_COURSE_ID (server-resolved course)', stamped);
    }

    // ---------------------------------------------------------------------
    console.log('\n[3] a course id is never silently replaced by elf');
    {
        const html = await (await fetch(BASE + '/review')).text();
        // Every URL the page builds must carry the course it was told to.
        const r = run(html, {}, '?course_id=coff', '/review');
        r.win.__ulFetch('/api/review/due?course_id=' + r.win.__ulCourseId() + '&limit=50');
        await new Promise(res => setImmediate(res));
        const urls = r.env.calls.map(c => c.url).join(' ');
        check('review asks for coff, not elf', urls.indexOf('coff') !== -1, urls);
        check('review never asks for elf', urls.indexOf('elf') === -1, urls);
    }

    // ---------------------------------------------------------------------
    console.log('\n[4] __ulHeaders attaches the token, and no "Bearer null"');
    {
        const html = await (await fetch(BASE + '/progress')).text();

        const signedOut = run(html, {}, '', '/progress').win;
        const h1 = signedOut.__ulHeaders({});
        check('signed out -> no Authorization header',
            h1['Authorization'] === undefined, JSON.stringify(h1));

        // A real localStorage-shaped store.  `run` threads this into the
        // script scope, and __ulToken reads it from there -- passing an object
        // to run() is not enough unless the store itself answers getItem.
        const store = {
            getItem: function (k) { return k === 'session_token' ? 'abc123' : null; },
            removeItem: function () {},
            setItem: function () {},
        };
        const signedIn = run(html, store, '', '/progress').win;
        check('token is read from storage',
            signedIn.__ulToken() === 'abc123', signedIn.__ulToken());
        const h2 = signedIn.__ulHeaders({});
        check('signed in -> Bearer abc123',
            h2['Authorization'] === 'Bearer abc123', JSON.stringify(h2));

        const h3 = signedIn.__ulHeaders({ 'X-Extra': 'kept' });
        check('extra headers survive the merge', h3['X-Extra'] === 'kept');

        // THE REGRESSION THIS EXISTED FOR: the nav's zero-argument version used
        // to win the `||` race, and `extra` keys were silently dropped.  If the
        // two definitions drift apart again, this is what fails.
        const h4 = signedIn.__ulHeaders({ 'X-Second': 'also-kept' });
        check('a SECOND extra key survives too (the nav/web signature match)',
            h4['X-Second'] === 'also-kept', JSON.stringify(h4));

        // And the reverse direction: the nav's own no-extra call still works.
        const h5 = signedIn.__ulHeaders();
        check('a no-argument call still returns valid headers',
            h5['Authorization'] === 'Bearer abc123', JSON.stringify(h5));
    }

    // ---------------------------------------------------------------------
    console.log('\n[5] blocked site data must not throw (this killed 11 pages before)');
    {
        const html = await (await fetch(BASE + '/progress')).text();
        const hostile = {
            getItem: function () { throw new Error('SecurityError: site data blocked'); },
            removeItem: function () { throw new Error('SecurityError'); },
            setItem: function () {},
        };
        let threw = null;
        try {
            const w = run(html, hostile, '', '/progress').win;
            const t = w.__ulToken();
            const h = w.__ulHeaders({});
            check('token read returns empty string, not a throw', t === '');
            check('headers build with no token and no throw',
                h['Authorization'] === undefined, JSON.stringify(h));
        } catch (e) { threw = e; }
        check('no exception escaped the helpers', threw === null,
            threw ? String(threw) : '');
    }

    // ---------------------------------------------------------------------
    console.log('\n[6] a 401 clears the dead token and redirects (7.1.19)');
    {
        const html = await (await fetch(BASE + '/progress')).text();
        let removed = false;
        const store = {
            getItem: function (k) { return k === 'session_token' ? 'expired-token' : null; },
            removeItem: function (k) { if (k === 'session_token') { removed = true; } },
            setItem: function () {},
        };
        const env = makeEnv(store, '', '/progress');
        const r = run(html, store, '', '/progress');
        const win = r.win;
        // The helper closed over the `fetch` passed INTO the script scope, so
        // replacing window.fetch after the fact does nothing.  Re-run with the
        // stub already answering 401 -- that is what actually exercises the
        // branch.
        const r401 = run401(html, store, '/progress');
        let rejected = null;
        try {
            await r401.win.__ulFetch('/api/progress?course_id=elf');
        } catch (e) { rejected = e; }
        check('the token was removed from localStorage', removed === true);
        check('the caller is told it was a 401',
            rejected && rejected.status === 401, String(rejected));
        try {
            await r401.win.__ulFetch('/api/progress?course_id=elf');
        } catch (e) { rejected = e; }
        check('the token was removed from localStorage', removed === true);
        check('the caller is told it was a 401',
            rejected && rejected.status === 401, String(rejected));
    }

    // ---------------------------------------------------------------------
    console.log('\n[7] silent401 suppresses the REDIRECT but still rejects');
    {
        const html = await (await fetch(BASE + '/progress')).text();
        let removed = false;
        let target = '';
        const store = {
            getItem: function (k) { return k === 'session_token' ? 'expired-token' : null; },
            removeItem: function () { removed = true; },
            setItem: function () {},
        };
        const r401 = run401(html, store, '/progress');
        Object.defineProperty(r401.env.window.location, 'href', {
            set: function (v) { target = v; },
            get: function () { return ''; },
            configurable: true,
        });
        let rejected = null;
        try { await r401.win.__ulFetch('/api/review/due', { silent401: true }); }
        catch (e) { rejected = e; }
        // The reject is what stops the caller parsing {error:...} as data.
        check('still rejects on 401 even when silent',
            rejected && rejected.status === 401, String(rejected));
        check('token still cleared even when silent', removed === true);
        // And the thing that makes it "silent": no navigation happened.
        check('NO navigation to /login', target === '', target);
    }

    // ---------------------------------------------------------------------
    console.log('\n[7b] NO page ships the literal "Bearer null"');
    {
        // The old review page built its header as
        //     "Authorization": bearerValue()
        // where bearerValue() returned "" when signed out -- producing the
        // header value "Bearer " with nothing after it, and settings.ch built
        // "Bearer " + localStorage.getItem(...) which produced the literal
        // string "Bearer null".  Both are strings a server cannot distinguish
        // from a real header, so the request authenticated as nobody but looked
        // authenticated.  Assert the text is absent from every page.
        const paths = ['/progress', '/review', '/analytics', '/dashboard',
            '/notes', '/bookmarks', '/streaks', '/settings', '/achievements',
            '/notifications', '/certificates', '/study-plans'];
        let bad = [];
        for (const p of paths) {
            let text;
            try {
                const resp = await fetch(BASE + p);
                if (resp.status !== 200) { continue; }
                text = await resp.text();
            } catch (e) { continue; }
            if (text.indexOf('Bearer null') !== -1) { bad.push(p + ' (Bearer null)'); }
            if (text.indexOf('Bearer" + ') !== -1) { bad.push(p + ' (unconditional Bearer)'); }
        }
        check('no served page contains "Bearer null" or an unguarded Bearer concat',
            bad.length === 0, bad.join(', '));
    }

    console.log('\n[8] the login redirect cannot loop on an auth page');
    {
        const html = await (await fetch(BASE + '/progress')).text();
        for (const p of ['/login', '/register', '/onboarding']) {
            let navigated = false;
            const env = makeEnv({}, '', p);
            const r = run(html, {}, '', p);
            Object.defineProperty(r.env.window.location, 'href', {
                set: function (v) { navigated = (v !== ''); },
                get: function () { return ''; },
                configurable: true,
            });
            r.win.__ulRedirectToLogin();
            check(p + ' does NOT redirect to /login', navigated === false);
        }
        // And a real page DOES redirect, carrying `next` back.
        {
            let target = '';
            const r = run(html, {}, '', '/progress');
            Object.defineProperty(r.env.window.location, 'href', {
                set: function (v) { target = v; },
                get: function () { return ''; },
                configurable: true,
            });
            r.win.__ulRedirectToLogin();
            check('/progress DOES redirect to /login', target.indexOf('/login') === 0, target);
            check('the redirect carries next= back to the page',
                target.indexOf('next=') !== -1 && target.indexOf('%2Fprogress') !== -1, target);
        }
    }

    // ---------------------------------------------------------------------
    console.log('\n[9] __ulGate answers rather than navigating by itself');
    {
        const html = await (await fetch(BASE + '/progress')).text();
        const emptyStore = {
            getItem: function () { return null; },
            removeItem: function () {},
            setItem: function () {},
        };

        // Signed out: no request at all (backend-optional -- a file:// page
        // with no server must still render).
        const rOut = run(html, emptyStore, '', '/progress');
        const callsBefore = rOut.env.calls.length;
        const blocked = await rOut.win.__ulGate();
        check('signed out -> not blocked', blocked === false);
        check('signed out -> makes NO request',
            rOut.env.calls.length === callsBefore,
            'made ' + (rOut.env.calls.length - callsBefore));

        // Signed in, onboarding incomplete -> blocked, and the CALLER decides.
        const store = {
            getItem: function (k) { return k === 'session_token' ? 'tok' : null; },
            removeItem: function () {}, setItem: function () {},
        };
        const env2 = makeEnv(store, '', '/progress');
        let target = '';
        Object.defineProperty(env2.window.location, 'href', {
            set: function (v) { target = v; },
            get: function () { return ''; },
            configurable: true,
        });
        const body = scriptsOf(html).join('\n;\n');
        // eslint-disable-next-line no-new-func
        const fn = new Function('window', 'localStorage', 'document', 'fetch', 'console',
            'JSON', 'encodeURIComponent', 'decodeURIComponent', 'Promise', 'Error',
            'setTimeout', 'clearTimeout', body + '\n; return window;');
        const fetchGate = function () {
            return Promise.resolve({
                status: 200,
                json: function () { return Promise.resolve({ completed: false, authenticated: true }); },
            });
        };
        const w3 = fn(env2.window, store, env2.document, fetchGate, console,
            JSON, encodeURIComponent, decodeURIComponent, Promise, Error,
            setTimeout, clearTimeout);
        const blocked2 = await w3.__ulGate();
        check('signed in + incomplete -> blocked', blocked2 === true);
        // __ulGate must NOT navigate on its own -- that is the caller's call,
        // and a gate that redirects by itself can loop.
        check('__ulGate did NOT navigate by itself', target === '', target);

        // Completed onboarding -> not blocked.
        const w4fn = new Function('window', 'localStorage', 'document', 'fetch', 'console',
            'JSON', 'encodeURIComponent', 'decodeURIComponent', 'Promise', 'Error',
            'setTimeout', 'clearTimeout', body + '\n; return window;');
        const env3 = makeEnv(store, '', '/progress');
        const fetchDone = function () {
            return Promise.resolve({
                status: 200,
                json: function () { return Promise.resolve({ completed: true, authenticated: true }); },
            });
        };
        const w4 = w4fn(env3.window, store, env3.document, fetchDone, console,
            JSON, encodeURIComponent, decodeURIComponent, Promise, Error,
            setTimeout, clearTimeout);
        const blocked3 = await w4.__ulGate();
        check('signed in + complete -> not blocked', blocked3 === false);
    }

    // ---------------------------------------------------------------------
    console.log('\n[10] the onboarding gate is on the gate pages, and hidden');
    {
        for (const p of ['/', '/dashboard']) {
            const html = await (await fetch(BASE + p)).text();
            check(p + ' carries the gate', html.indexOf('ul-onboarding-gate') !== -1);
            check(p + ' ships the gate HIDDEN (correct before any JS runs)',
                /id="ul-onboarding-gate"[^>]*\shidden/.test(html)
                || /\shidden[^>]*id="ul-onboarding-gate"/.test(html));
            check(p + ' has the gate script', html.indexOf('__ulPaintGate') !== -1);
        }
        // The auth pages must NOT carry the gate: a learner on /login being
        // told to finish onboarding is the loop this design avoids.
        for (const p of ['/login', '/register']) {
            const html = await (await fetch(BASE + p)).text();
            check(p + ' does NOT carry the gate',
                html.indexOf('ul-onboarding-gate') === -1);
        }
    }

    // ---------------------------------------------------------------------
    console.log('\n[11] __ulAfterAuth honours `next`, then the gate, then home');
    {
        const html = await (await fetch(BASE + '/login')).text();

        // next= wins, and the learner lands where they were going.
        {
            let target = '';
            const store = { getItem: function () { return null; }, removeItem: function () {}, setItem: function () {} };
            const env = makeEnv(store, '', '/login');
            const r = run(html, store, '?next=%2Freview', '/login');
            Object.defineProperty(r.env.window.location, 'href', {
                set: function (v) { target = v; }, get: function () { return ''; }, configurable: true,
            });
            r.win.__ulAfterAuth();
            check('?next=%2Freview -> /review', target === '/review', target);
        }

        // No next, onboarding incomplete -> /onboarding.
        {
            let target = '';
            const store = { getItem: function (k) { return k === 'session_token' ? 'tok' : null; }, removeItem: function () {}, setItem: function () {} };
            const env = makeEnv(store, '', '/login');
            const r = runGate(html, store, '/login', { completed: false, authenticated: true });
            Object.defineProperty(r.env.window.location, 'href', {
                set: function (v) { target = v; }, get: function () { return ''; }, configurable: true,
            });
            await r.win.__ulAfterAuth();
            await new Promise(res => setTimeout(res, 10));
            check('new account, no next -> /onboarding', target === '/onboarding', target);
        }

        // No next, onboarding complete -> home.
        {
            let target = '';
            const store = { getItem: function (k) { return k === 'session_token' ? 'tok' : null; }, removeItem: function () {}, setItem: function () {} };
            const r = runGate(html, store, '/login', { completed: true, authenticated: true });
            Object.defineProperty(r.env.window.location, 'href', {
                set: function (v) { target = v; }, get: function () { return ''; }, configurable: true,
            });
            await r.win.__ulAfterAuth();
            await new Promise(res => setTimeout(res, 10));
            check('established account, no next -> /', target === '/', target);
        }
    }

    // ---------------------------------------------------------------------
    console.log('\n[12] `next` cannot be used as an open redirect');
    {
        const html = await (await fetch(BASE + '/login')).text();
        const store = { getItem: function () { return null; }, removeItem: function () {}, setItem: function () {} };

        // Each of these must be REFUSED, and refusal means falling through to
        // the normal decision -- never to the attacker's URL.
        const attacks = [
            ['http://evil.example/steal', 'absolute http URL'],
            ['https://evil.example/steal', 'absolute https URL'],
            ['%2F%2Fevil.example%2Fsteal', 'protocol-relative //host'],
            ['javascript:alert(1)', 'javascript: scheme'],
            ['%2Flogin%3Fnext%3D%2Flogin', 'bounce back to /login'],
            ['', 'empty'],
        ];
        for (const [value, label] of attacks) {
            const r = run(html, store, '?next=' + value, '/login');
            const got = r.win.__ulNextPath();
            check('refused: ' + label, got === '', 'returned ' + JSON.stringify(got));
        }

        // And a legitimate one still works, so the check is not just "refuse all".
        const ok = run(html, store, '?next=%2Fprogress', '/login');
        check('a real path is still honoured', ok.win.__ulNextPath() === '/progress',
            ok.win.__ulNextPath());
    }

    // ---------------------------------------------------------------------
    console.log('\n[13] the gate endpoint answers correctly against a real server');
    {
        // THE REGRESSION THIS EXISTS FOR.  GET /api/onboarding/check used to
        // infer "has onboarded" from the existence of a learning_preferences
        // row -- which registration creates for EVERY account.  It therefore
        // answered {"completed":true} for a learner who had done nothing at
        // all, the gate could never fire, and onboarding was reachable only by
        // typing its URL.  This walks the real lifecycle over HTTP.
        const email = 'gate-check-' + Date.now() + '@underlayer.dev';
        const reg = await fetch(BASE + '/api/auth/register', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: email, password: 'password123', name: 'Gate Check' }),
        });
        const regBody = await reg.json();
        const tok = regBody.session_token;
        if (!tok) {
            check('could register a learner for the gate check', false, JSON.stringify(regBody));
        } else {
            const auth = { 'Authorization': 'Bearer ' + tok, 'Content-Type': 'application/json' };
            const chk = async () => (await (await fetch(BASE + '/api/onboarding/check', { headers: auth })).json());

            const before = await chk();
            check('a BRAND NEW account is NOT gated',
                before.completed === false && before.authenticated === true,
                JSON.stringify(before));

            // Complete WITHOUT a course -- the onboarding page allows this, so
            // if the marker were conditional the learner would be gated on
            // every page load forever with no way out.
            await fetch(BASE + '/api/onboarding/complete', {
                method: 'POST', headers: auth,
                body: JSON.stringify({ daily_minutes: 30, session_length: 'short' }),
            });
            const afterNoCourse = await chk();
            check('completing WITHOUT a course clears the gate (no loop)',
                afterNoCourse.completed === true, JSON.stringify(afterNoCourse));

            // A SECOND learner, completing WITH a course.
            const email2 = 'gate-check2-' + Date.now() + '@underlayer.dev';
            const reg2 = await fetch(BASE + '/api/auth/register', {
                method: 'POST', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email: email2, password: 'password123', name: 'Gate Check 2' }),
            });
            const tok2 = (await reg2.json()).session_token;
            const auth2 = { 'Authorization': 'Bearer ' + tok2, 'Content-Type': 'application/json' };
            check('a second brand new account is NOT gated',
                (await chk2(BASE, auth2)).completed === false);
            await fetch(BASE + '/api/onboarding/complete', {
                method: 'POST', headers: auth2,
                body: JSON.stringify({ daily_minutes: 20, session_length: 'medium', selected_course: 'rvasm' }),
            });
            check('completing WITH a course clears the gate',
                (await chk2(BASE, auth2)).completed === true);
            await fetch(BASE + '/api/user/account', { method: 'DELETE', headers: auth2 });

            // Anonymous.
            const anon = await (await fetch(BASE + '/api/onboarding/check')).json();
            check('anonymous is reported as unauthenticated, not completed',
                anon.authenticated === false && anon.completed === false,
                JSON.stringify(anon));

            // A garbage token must NOT be reported as "onboarded".
            const bad = await (await fetch(BASE + '/api/onboarding/check', {
                headers: { 'Authorization': 'Bearer ' + 'f'.repeat(64) },
            })).json();
            check('a garbage token is unauthenticated',
                bad.authenticated === false, JSON.stringify(bad));

            // Leave no rows behind -- this gate must not accumulate accounts.
            await fetch(BASE + '/api/user/account', { method: 'DELETE', headers: auth });
        }
    }

    console.log('\n' + (failures === 0
        ? 'session_js_check: ALL CHECKS PASSED'
        : 'session_js_check: ' + failures + ' CHECK(S) FAILED'));
    process.exit(failures === 0 ? 0 : 1);
}

main().catch(e => { console.error('session_js_check crashed: ' + (e && e.stack)); process.exit(2); });