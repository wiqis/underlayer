// underlayer_web — the site nav, reached from web.
//
// THE NAV IS NOT DEFINED HERE.  It is defined in content/src/lesson_nav.ch,
// because the 398 lesson pages are built in content/, which is the layer
// BELOW web and cannot import this one, and a nav only half the collection can
// call is how `/courses` stayed a dead link behind a nav that looked finished.
// This file is the web-layer name for it: three pages call render_nav_bar and
// get the same markup, the same styles and the same theme script that every
// lesson page gets, so a link cannot be right on /courses and wrong on a
// lesson.  tools/nav_check.py asserts that on every run.
//
// render_theme_js is gone.  It used to be called from render_index_js in
// courses_index_assets.ch, which meant the theme script was emitted by a
// function named after the course index rather than by the nav that owns the
// toggle; the nav emits it now, and a second call would have shipped it twice.
// It had no other caller, so there was nothing to keep.  The script itself
// lives in the component, as render_site_nav_js.
//
// The comment that used to live here described the nav and its thirteen items.
// Those items are now one block of markup in content/src/lesson_nav.ch, which
// is where a reader looking for "which routes are in the nav" will find them.
using std::string

public namespace underlayer_web {

    // A collection page: the Wiqis brand layer (app shell, so the stored theme
    // preference is honoured) plus the one shared nav.  The nav itself also
    // installs the embedded sign-in dialog; its local `/sign-in` opener is the
    // same one a lesson page gets.  See content/src/lesson_nav.ch and
    // content/src/embedded_auth.ch — there is deliberately only one nav here.
    public func render_nav_bar(page : &mut HtmlPage) {
        WiqisTheme(page, true)
        underlayer_content::render_site_nav(page)
        // I11: the one shared support link in the footer. The nav markup itself
        // lives in content/src/lesson_nav.ch; this web-layer wrapper is the
        // single insertion point for the pages it renders, so no page can end
        // up with two copies or a different destination.
        render_support_footer(page)

        // C7 (7.1.14 / 7.1.24): an unread indicator and a due-review badge on
        // the one shared nav, which is what the signed-in home renders. Both
        // counts are checked against an authenticated endpoint first: a 401
        // is treated as "signed out" and NO number is painted, so the shared
        // shell can never present anonymous demo data as the reader's own.
        // Every value is written with textContent into a node created here.
        #css {
            .ul-nav-badge { display: inline-block; min-width: 1.2rem; padding: 0.05rem 0.35rem; margin-left: 0.3rem; border-radius: 9999px; background: hsl(217 91% 60%); color: hsl(0 0% 100%); font-size: 0.7rem; font-weight: 700; line-height: 1.4; text-align: center; }
            .ul-nav-badge[hidden] { display: none; }
        }
        #js {
            (function() {
                function badge(link, count) {
                    if (!link || link.querySelector('.ul-nav-badge')) { return; }
                    var node = document.createElement('span');
                    node.className = 'ul-nav-badge';
                    node.textContent = String(count);
                    if (count <= 0) { node.hidden = true; }
                    link.appendChild(node);
                }
                function place(selector) { return document.querySelector('.nav-links a[data-nav="' + selector + '"]'); }
                function getJson(path, onValue) {
                    fetch(path, { credentials: 'same-origin' }).then(function(r) {
                        if (r.status === 401) { return null; }
                        if (!r.ok) { throw new Error('http ' + r.status); }
                        return r.json();
                    }).then(function(d) { if (d) { onValue(d); } })
                    .catch(function() { /* absent badge is better than a wrong one */ });
                }
                // The unread-count endpoint requires a session, so a 200 is
                // also the sign-in signal for the anonymous demo endpoints.
                getJson('/api/notifications/unread-count', function(d) {
                    var n = parseInt(d.count, 10);
                    if (isNaN(n)) { n = 0; }
                    badge(place('/notifications'), n);
                    getJson('/api/review/due', function(due) {
                        var total = parseInt(due.total, 10);
                        if (isNaN(total)) { total = 0; }
                        badge(place('/review'), total);
                    });
                });
            })();
        }
    }

}
