// underlayer_content — WHO IS SIGNED IN, in the nav's own right-hand slot.
//
// THE SIGN-OUT BUTTON, and why it is here.  Measured 2026-10-02: /api/auth/me
// was called from zero of the 438 page builders in content/src.  The endpoint
// shipped, it works, and it is the one request whose answer changes what a
// reader should do next -- sign in or do not sign in.  Without it the nav's
// right-hand slot on a lesson page was an empty <div> (it has to be: a lesson
// page draws no theme toggle), and a reader had no way to tell an account from
// no account anywhere on the site.
//
// Showing the name is only half of it.  An identity slot with no way to end the
// session is worse on a shared machine than the empty div it replaced, because
// it now tells the next person at the keyboard whose account they are in and
// gives them nothing to do about it.  POST /api/auth/logout shipped with no UI
// consumer at all; this is that consumer, and it also closes the open P1 in
// docs/features-complete.md (7.1.18, "Auth-aware navbar: Login/Register links
// when logged out, profile + Logout when logged in").
//
// WHY IT IS IN THE NAV RATHER THAN IN THE LESSON TOOLS ROW.  The tools row is
// per-lesson and lives in content/src/lesson_tools.ch; this is per-SITE and
// belongs in the one component both layers render.  It is therefore emitted from
// render_site_nav, not render_lesson_nav, which means the collection pages in
// web/src get it too -- /courses, /dashboard, /search -- from the same six lines.
// A sign-in state that differs between a lesson and the course index is the same
// class of bug as a nav link that works on one and not the other.
//
// THE SHAPES, VERIFIED WITH CURL BEFORE ANY OF THIS WAS WRITTEN.  The logout
// shape is in here because it is not the obvious one:
//   POST /api/auth/me's sibling -- POST /api/auth/logout -> {"ok":true}
// and the METHOD matters.  DELETE /api/auth/logout is 404: app/main.ch registers
// POST only, and a client that guessed DELETE would have got a cheerful "Not
// Found" and kept the session.  After it, GET /api/auth/me answers 401.
//
//   GET /api/auth/me -> {"learner_id":"...","name":"...","email":"...",
//                        "username":"","display_name":"","avatar_url":""}
//   401 with {"error":"unauthorized"} when there is no valid session.
//
// WHICH NAME, AND WHY display_name FIRST.  Four candidate fields come back and
// three are empty strings on a fresh account.  display_name is what a learner
// set for themselves, username is what they chose at signup, name is what was
// typed at registration.  The first non-empty one wins, and if all three are
// empty the reader gets "Sign in" rather than an empty slot -- which is the
// honest thing to render for an account with no name on it.
//
// NO TOKEN MEANS NO REQUEST AT ALL.  Backend-optional: on a file:// URL with no
// server the page still has to render its full lesson, and asking a server that
// is not there produces a console error rather than a page.  The local token
// read is wrapped in try/catch because localStorage throws outright in a
// browser with site data blocked, and a nav script that throws is a nav script
// that took the theme toggle with it.
//
// IT RE-DECLARES __ulToken / __ulHeaders GUARDED, for the reason written at
// length in lesson_standing_js.ch: the nav renders on collection pages that do
// not call render_lesson_engagement, so those helpers may not exist.  The `||`
// form is idempotent, so on a lesson page the engagement script's versions win
// and there is exactly one implementation of each.
public namespace underlayer_content {

    public func render_identity_js(page : &mut HtmlPage) {
        #js {
            window.__ulToken = window.__ulToken || function() {
                var t = '';
                try { t = localStorage.getItem('session_token') || ''; } catch (e) { t = ''; }
                return t;
            };
            window.__ulHeaders = window.__ulHeaders || function() {
                var h = { 'Content-Type': 'application/json' };
                var t = window.__ulToken();
                if (t) { h['Authorization'] = 'Bearer ' + t; }
                return h;
            };

            window.__ulPaintIdentity = function(me) {
                var slot = document.getElementById('ul-identity');
                if (!slot) { return; }
                slot.textContent = '';
                var who = '';
                if (me) {
                    if (me.display_name) { who = me.display_name; } else { if (me.username) { who = me.username; } else { if (me.name) { who = me.name; } } }
                }
                var link = document.createElement('a');
                if (who.length === 0) {
                    link.className = 'ul-signin';
                    link.href = '/login';
                    link.textContent = 'Sign in';
                } else {
                    link.className = 'ul-signin ul-signed-in';
                    link.href = '/dashboard';
                    link.textContent = who;
                    // THE SIGN-OUT BUTTON, which is here because of what it would
                    // be like without it.  This slot did not exist before this
                    // change, so "advertise a signed-in state with no way to end
                    // it" would be a regression introduced by adding the name --
                    // and on a shared machine it is the whole reason a name is
                    // worth showing.  POST /api/auth/logout shipped and had no UI
                    // consumer; this is that consumer, and it closes the open P1
                    // in docs/features-complete.md (7.1.18).
                    var out = document.createElement('button');
                    out.type = 'button';
                    out.className = 'ul-signout';
                    out.id = 'ul-signout';
                    out.textContent = 'Sign out';
                    out.addEventListener('click', function() { window.__ulSignOut(); });
                    slot.appendChild(link);
                    slot.appendChild(out);
                    slot.hidden = false;
                    return;
                }
                slot.appendChild(link);
                slot.hidden = false;
            };

            // WHY __ulSignOut CALLS ONE LOCAL HELPER AND NOT FOUR FUNCTIONS FROM
            // THE OTHER COMPONENT.  This file is emitted by render_site_nav, so
            // it is on every page that has a nav; the tools row is emitted by
            // render_lesson_tools and is lesson-only.  Calling
            // window.__ulPaintBookmark() directly therefore assumes the tools are
            // present, and the non-vacuity proof in tools/integration_check.py
            // caught exactly that: with `render_lesson_tools(page)` removed, the
            // Sign out handler threw `__ulPaintBookmark is not a function` on
            // every page and the whole script block died -- so the nav could not
            // even repaint.  Each component has to be removable on its own, and
            // the guarded helper is the whole of that discipline here.
            window.__ulPaintBookmarkSafe = function() {
                if (typeof window.__ulPaintBookmark === 'function') {
                    window.__ulPaintBookmark(false);
                }
            };

            // WHY THERE IS NO RELOAD HERE, which is the obvious implementation and
            // the wrong one.  Reloading the page to redraw the nav would build a
            // new document, and the engagement script records a read on
            // DOMContentLoaded -- so signing out would count as having read the
            // lesson again.  A sign-out that inflates your own progress is worse
            // than a sign-out that leaves a chip briefly stale, so this repaints
            // in place: identity back to "Sign in", the lesson's action buttons
            // hidden again, and the signed-out line back.  The token is removed
            // from localStorage as well as the server, or the next page load
            // would send it again and get a 401.
            window.__ulSignOut = function() {
                fetch('/api/auth/logout', { method: 'POST', headers: window.__ulHeaders() })
                    .then(function(r) { return r.json(); })
                    .catch(function() { })
                    .then(function() {
                        try { localStorage.removeItem('session_token'); } catch (e) { }
                        window.__ulPaintIdentity(null);
                        var acts = document.getElementById('ul-tools-actions');
                        if (acts) { acts.hidden = true; }
                        var so = document.getElementById('ul-tools-signedout');
                        if (so) { so.hidden = false; }
                        window.__ulPaintBookmarkSafe();
                        var pill = document.getElementById('ul-progress-state');
                        if (pill) { pill.textContent = 'Signed out'; pill.className = 'ul-progress-state'; }
                    });
            };

            window.__ulLoadIdentity = function() {
                if (window.__ulToken().length === 0) {
                    window.__ulPaintIdentity(null);
                    return;
                }
                fetch('/api/auth/me', { headers: window.__ulHeaders() })
                    .then(function(r) { return r.json(); })
                    .then(function(d) {
                        if (d && d.error) { window.__ulPaintIdentity(null); return; }
                        window.__ulPaintIdentity(d);
                    })
                    .catch(function() { window.__ulPaintIdentity(null); });
            };

            document.addEventListener('DOMContentLoaded', function() { window.__ulLoadIdentity(); });
        }
    }

    public func render_identity_css(page : &mut HtmlPage) {
        #css {
            .ul-signin { font-size: 0.85rem; font-weight: 600; color: hsl(217 91% 60%); text-decoration: none; white-space: nowrap; }
            .ul-signin:hover { text-decoration: underline; }
            .ul-signed-in { color: hsl(220 9% 46%); }
            .ul-signed-in:hover { color: hsl(217 91% 60%); }
            .ul-signout { font: inherit; font-size: 0.78rem; font-weight: 600; padding: 0.2rem 0.5rem; border: 1px solid hsl(220 11% 89%); border-radius: 6px; background: hsl(0 0% 100%); color: hsl(220 9% 46%); cursor: pointer; white-space: nowrap; }
            .ul-signout:hover { background: hsl(220 14% 96%); color: hsl(221 39% 11%); }
            .nav-identity { display: inline-flex; align-items: center; gap: 0.4rem; }
        }
    }

}