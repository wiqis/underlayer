// underlayer_web — THE SESSION HELPER, as one shared script.
//
// WHAT THIS REPLACES.  Measured 2026-10-02, by counting the ways a page reads
// the session token before it calls an endpoint:
//
//     web/src/handlers_review_page.ch     3   (bearerValue / authHeaders /
//                                                 jsonAuthHeaders, each reading
//                                                 localStorage on its own)
//     web/src/pages_settings.ch           4   (four inline
//                                                 'Bearer ' + getItem(...), two
//                                                 of which pass `null` straight
//                                                 into a header value)
//     web/src/pages_study_plans.ch        1
//     web/src/pages_notes.ch              1
//     web/src/pages_bookmarks.ch          1
//     ... 11 more files, 1 each
//
// Seventeen implementations of one question ("who is this request from?"), and
// they did not agree.  Three of them read the token inside a try/catch and
// eleven did not, so a browser with site data blocked threw on eleven pages and
// rendered on three.  Two of them sent the literal string "Bearer null" as a
// header.  None of them validated the token against the server, so a token that
// had expired or been revoked produced the same empty state as never having
// signed in -- which is the P1 at 7.1.19: an expired session is silently
// indistinguishable from a signed-out visitor, on every authenticated page.
//
// THE THREE THINGS THIS DOES, ONCE.
//
//   1. __ulToken() / __ulHeaders() -- read localStorage safely, always.  The
//      try/catch is not defensive noise: localStorage ACCESS THROWS in a
//      browser configured to block site data, and an unguarded read takes the
//      whole page script down with it.
//
//   2. __ulFetch() -- one fetch wrapper that attaches the header AND handles
//      401.  This is the part that was missing everywhere.  On a 401 it clears
//      the dead token and sends the reader to /login with a `next` parameter, so
//      they land back where they were rather than on a bare login page that
//      forgets what they asked for.  The clear is the important half: a revoked
//      or expired token left in localStorage is re-sent on every subsequent
//      page load, so every page kept getting 401s for a session that could
//      never work again, and the reader had to clear site data by hand to
//      recover.
//
//   3. __ulCourseId() -- which course this page is about, read from the URL
//      with a real fallback.  Three pages had `course_id=elf` written into a
//      fetch URL, so /review, /progress and /analytics reported ELF progress to
//      a learner studying RISC-V and never mentioned the other 33 courses.  The
//      fallback is the LAST enrolled course, not a hardcoded id, and it is
//      resolved from the server rather than guessed in the browser.
//
// WHY IT IS EMITTED PER PAGE AND NOT SERVED AS A .JS FILE.  The 398 lesson
// pages are pre-rendered to static HTML for GitHub Pages, and a page that
// reaches a server for its scripts is a page that does not work offline --
// which the backend-optional rule forbids.  Emitting it costs a few hundred
// bytes per page and keeps every page working from file://.  The content-layer
// copy in content/src/lesson_identity.ch is separate and also guarded: the two
// layers cannot import each other, and both use the `window.__ulX = window.__ulX
// || ...` form so whichever loads first wins and there is exactly one
// implementation on any given page.
//
// THE ONBOARDING GATE.  __ulGate() is what makes /api/onboarding/check -- an
// endpoint that shipped and was called from nowhere -- mean something.  It
// answers one question for every page that calls it: "this learner is signed in
// and has not finished onboarding, so show them the gate?"  It does NOT
// redirect by itself; it returns a boolean and lets the page decide what that
// means, because a redirect that fires on every page including /login and
// /onboarding is a redirect loop.  See pages_gate.ch for the callers.
public namespace underlayer_web {

    // WHERE A NEWLY SIGNED-IN LEARNER GOES NEXT.  (11.2.17 + 7.1.20)
    //
    // BOTH REGISTRATION AND LOGIN USED TO END AT `window.location.href = '/'`.
    // That is wrong in two different ways and both were invisible until the
    // gate below existed:
    //
    //   1. A brand-new account has completed no onboarding, has chosen no
    //      course, and has no progress.  /api/onboarding/check exists, answers
    //      `{"completed": false, "authenticated": true}`, and was called from
    //      nowhere on the platform -- so the onboarding flow, which exists and
    //      works, was reachable only by typing /onboarding.
    //   2. Signing in from /login?next=%2Freview threw that `next` away.  A
    //      reader bounced off an expired session landed on /login, signed in,
    //      and was sent to the home page instead of back to the review queue
    //      they left.  __ulRedirectToLogin writes the `next` deliberately; a
    //      login handler that ignores it makes that half of the feature dead.
    //
    // THE ORDER IS THE WHOLE DESIGN and it is the only order that works:
    //   `next` (they asked for something specific)  >
    //   onboarding gate (they have an account but no course)  >
    //   home.
    // The gate must NOT come first: a learner who followed a `next` link has
    // already demonstrated they can find things themselves, and being forced
    // through onboarding they did not ask for is the kind of interruption this
    // collection's design rules forbid.  Conversely a new account that is sent
    // straight to a lesson has no course context, no dashboard, and no idea
    // what exists.
    //
    // BACKEND-OPTIONAL.  With no token in storage this is never called, and if
    // the check fails for any reason the learner lands on '/'.  The failure
    // mode is one extra page load, not a dead page.
    public func render_auth_destination_js(page : &mut HtmlPage) {
        #js {
            // READ `next` OFF THE QUERY STRING OF THE AUTH PAGE ITSELF, i.e.
            // /login?next=%2Freview.  Only a PATH is honoured: if the value is
            // an absolute URL this would be an open redirect, handing an
            // attacker a working phishing link on the platform's own domain.
            // Rejecting anything that does not start with a single slash is the
            // whole check.
            window.__ulNextPath = function() {
                var q = window.location.search || '';
                var key = 'next=';
                var at = q.indexOf(key);
                if (at === -1) { return ''; }
                var raw = q.substring(at + key.length);
                var amp = raw.indexOf('&');
                if (amp !== -1) { raw = raw.substring(0, amp); }
                var p = decodeURIComponent(raw);
                // Must be a site-relative path.  "//evil.com" is protocol-
                // relative and would leave the site; "http://..." and
                // "https://..." are absolute.  Neither may be honoured.
                if (p.charAt(0) !== '/') { return ''; }
                if (p.substring(0, 2) === '//') { return ''; }
                // Never bounce straight back to the auth pages: /login?next=
                // /login is a loop, and a crafted link could keep a reader
                // bouncing.
                //
                // THE COMPARISON IS ON THE PATH ONLY, NOT THE WHOLE STRING.
                // An earlier version tested `p === '/login'`, which a
                // `/login?next=/login` slips straight past -- the value is not
                // equal to '/login', it merely STARTS with it, and the reader
                // is bounced from login to login forever.  A loop is not a
                // cosmetic bug: the reader cannot escape it by clicking
                // anything, because every page they reach sends them back.
                // So strip the query and fragment first, then compare.
                var bare = p;
                var qm = bare.indexOf('?');
                if (qm !== -1) { bare = bare.substring(0, qm); }
                var hm = bare.indexOf('#');
                if (hm !== -1) { bare = bare.substring(0, hm); }
                var blocked = ['/login', '/register', '/forgot-password',
                               '/reset-password', '/onboarding'];
                for (var i = 0; i < blocked.length; i++) {
                    if (bare === blocked[i]) { return ''; }
                }
                return p;
            };

            // THE WHOLE DECISION, IN ONE PLACE, CALLED BY BOTH AUTH FORMS.
            window.__ulAfterAuth = function() {
                var next = window.__ulNextPath();
                if (next) { window.location.href = next; return; }
                // No `next`, so ask whether this account still needs onboarding.
                fetch('/api/onboarding/check', { headers: window.__ulHeaders({}) })
                    .then(function(r) { return r.json(); })
                    .then(function(d) {
                        if (d && d.authenticated && d.completed === false) {
                            window.location.href = '/onboarding';
                            return;
                        }
                        window.location.href = '/';
                    })
                    .catch(function() { window.location.href = '/'; });
            };
        }
    }

    public func render_session_js(page : &mut HtmlPage) {
        #js {
            // Guarded, for the reason in the file header: the content-layer
            // copy of these three helpers is emitted by the nav component, and
            // a platform page carries both.  Whichever block evaluates first
            // defines them; the `||` makes the second a no-op.
            window.__ulToken = window.__ulToken || function() {
                var t = '';
                try { t = localStorage.getItem('session_token') || ''; } catch (e) { t = ''; }
                return t;
            };

            window.__ulHeaders = window.__ulHeaders || function(extra) {
                var h = { 'Content-Type': 'application/json' };
                var t = window.__ulToken();
                if (t) { h['Authorization'] = 'Bearer ' + t; }
                if (extra) {
                    for (var k in extra) { h[k] = extra[k]; }
                }
                return h;
            };

            // WHY A TOKEN IS FORWARDED AS `next` AND NOT AS A QUERY PARAMETER ON
            // EVERY LINK.  The session token is a bearer credential: anything
            // that can read the URL -- a shared link, a referrer header, a
            // browser history file, a proxy log -- can use it.  It lives in
            // localStorage and nowhere else, and only a PATH crosses this line.
            window.__ulRedirectToLogin = function() {
                var path = window.location.pathname + window.location.search;
                var slash = path.indexOf('?');
                var bare = slash === -1 ? path : path.slice(0, slash);
                // Never bounce the auth pages themselves: a 401 handler that
                // redirects to /login from /login is an infinite loop, and that
                // is a real risk here rather than a theoretical one.
                var authPages = ['/login', '/register', '/forgot-password',
                                 '/reset-password', '/onboarding'];
                for (var i = 0; i < authPages.length; i++) {
                    if (bare === authPages[i]) { return false; }
                }
                window.location.href = '/login?next=' + encodeURIComponent(bare);
                return true;
            };

            // THE ONE FETCH EVERY AUTHENTICATED PAGE SHOULD USE.
            //
            // THE 401 CONTRACT IS "ALWAYS REJECTS", and that is deliberate.
            // An earlier version RETURNED the 401 response when `silent401`
            // was set, on the reasoning that the caller might want to read it.
            // But every caller in this codebase is
            // `.then(function(r) { return r.json(); })`, so a returned 401
            // hands them `{error: "unauthorized"}` and they parse it AS DATA --
            // the review-due counter read `data.length` on an error object,
            // and the concept list iterated a field that was not on it.
            // Neither threw; both painted a confident wrong number.  So: a 401
            // always rejects with `status === 401`, and each caller's existing
            // `.catch` paints the empty state.  One contract, and the flags
            // only decide whether we ALSO navigate.
            window.__ulFetch = function(url, opts) {
                opts = opts || {};
                var init = { method: opts.method || 'GET', headers: opts.headers || {} };
                if (opts.json !== undefined) {
                    init.headers = window.__ulHeaders(opts.headers);
                    init.body = JSON.stringify(opts.json);
                } else if (opts.body !== undefined) {
                    init.body = opts.body;
                }
                return fetch(url, init).then(function(r) {
                    if (r.status === 401) {
                        // Drop the dead token FIRST.  Leaving it means every
                        // later page load re-sends it and gets another 401, and
                        // the reader's only way out is clearing site data.
                        try { localStorage.removeItem('session_token'); } catch (e) { }
                        window.__ulPaintIdentitySafe();
                        // silent401 means "a 401 is an answer here, not a
                        // reason to navigate" -- see the header note.
                        if (!opts.silent401 && !opts.noRedirect) {
                            window.__ulRedirectToLogin();
                        }
                        var e = new Error('unauthorized');
                        e.status = 401;
                        e.handled = true;
                        throw e;
                    }
                    return r;
                });
            };

            // The nav owns identity painting and lives in content/, which the
            // web layer cannot import.  Guarded exactly like __ulToken above,
            // so calling this from a page whose nav did not boot is a no-op and
            // not a TypeError.
            window.__ulPaintIdentitySafe = window.__ulPaintIdentitySafe || function() {
                if (typeof window.__ulPaintIdentity === 'function') {
                    window.__ulPaintIdentity(null);
                }
            };

            // WHICH COURSE IS THIS PAGE ABOUT.
            //
            // Three shapes are read, in this order: ?course_id= on the query
            // string, then a /courses/<id>/ segment in the path, then whatever
            // the server stamped onto the page as __UL_COURSE_ID.  The third is
            // why this works on /review and /progress, whose URLs carry no
            // course at all: the handler resolved the learner's real course
            // server-side, where it can read the database, and this picks it up.
            // The browser cannot invent that value and this does not guess one --
            // which is the difference between this and the three hardcoded
            // `course_id=elf` fetches it replaces.
            window.__ulCourseId = function() {
                var q = window.location.search || '';
                // NO REGEX LITERALS IN THIS BLOCK, and that is a hard constraint
                // rather than a style choice: the js_cbi macro does not parse
                // them.  `/[?&]course_id=([^&]+)/` fails at the `//`-looking
                // interior and the compiler reports a dozen parse errors
                // pointing into a JavaScript file, which is not a useful place
                // for a reader to start.  The string walk below does the same
                // job and the macro understands it.
                var key = 'course_id=';
                var at = q.indexOf(key);
                if (at !== -1) {
                    var start = at + key.length;
                    var end = q.indexOf('&', start);
                    if (end === -1) { end = q.length; }
                    return decodeURIComponent(q.substring(start, end));
                }
                var p = window.location.pathname || '';
                // /courses/<id>/... -> <id>
                if (p.indexOf('/courses/') === 0) {
                    var rest = p.substring(9);
                    var slash = rest.indexOf('/');
                    if (slash !== -1) { rest = rest.substring(0, slash); }
                    if (rest.length > 0) { return rest; }
                }
                if (window.__UL_COURSE_ID) { return window.__UL_COURSE_ID; }
                return 'elf';
            };

            // THE ONBOARDING GATE, and why it returns rather than redirects.
            // A gate that navigated from inside a fetch handler could fire on
            // /login (whose own check also 401s), on /onboarding (the page the
            // gate is supposed to send you TO), and on any page whose answer
            // arrives late.  Three redirects chasing each other is a loop, and
            // the failure mode is a page that cannot load at all.  So this
            // answers, and the caller acts.
            window.__ulGate = function(nextPath) {
                if (window.__ulToken().length === 0) { return Promise.resolve(false); }
                return fetch('/api/onboarding/check', { headers: window.__ulHeaders({}) })
                    .then(function(r) {
                        if (r.status === 401) { return false; }
                        return r.json();
                    })
                    .then(function(d) {
                        var blocked = !!(d && d.authenticated && d.completed === false);
                        if (blocked && nextPath && window.location.pathname !== '/onboarding') {
                            window.location.href = '/onboarding';
                        }
                        return blocked;
                    })
                    .catch(function() { return false; });
            };
        }
    }

}