// underlayer_content — the nav's behaviour: theme, active link, mobile menu.
//
// THREE SEPARATE JOBS, THREE SEPARATE ENTRY POINTS, because they are emitted
// on different sets of pages.  `render_site_nav_js` (the theme) is deliberately
// NOT emitted on a lesson page, which has no toggle to drive; the other two are
// emitted on every page, because "which link am I on" and "how do I open the
// menu" are questions a lesson page raises too.
//
// WHY THE ACTIVE LINK IS FOUND BY SCRIPT, restated once here because this is
// the load-bearing part.  The markup carries NO `active` class anywhere -- see
// the note in lesson_nav.ch about the hardcoded `class="nav-link active"` that
// sat on "Courses" in all 432 pages.  This script is what puts one there, and
// the failure mode is the reason it is acceptable: if it never runs, no link is
// highlighted (uninformative), where before a wrong link was highlighted
// (misleading).  No flash is possible in the bad direction, because there is
// nothing to correct.
//
// WHY `data-nav` AND NOT A GUESS.  A nav key is the ROUTE PREFIX it owns, not
// its own path, so `/courses` must also claim `/courses/elf/lessons/bytes` --
// a lesson is inside Learn, which is the truth a reader needs.  A naive
// `href === location.pathname` test therefore highlights nothing at all on
// every lesson page, which is 398 of the 432 pages in the product.
//
// WHY THE LONGEST MATCH WINS.  `/courses/elf/path` (the per-course learning
// path page) is claimed by `/courses` as a prefix.  If two entries ever both
// match, the longer one is the more specific answer and the more correct one,
// so the loop keeps the longest rather than the first.  With the current six
// keys this is defensive rather than load-bearing, but the next key added to
// the nav should not have to know that a shorter sibling exists.
//
// WHY `<details>` GETS A CLICK-OUTSIDE HANDLER AT ALL.  A native `<details>`
// stays open when you click elsewhere, which is fine for a disclosure widget
// inside a form and wrong for site navigation: a reader who opens "Your
// space", scrolls to the panel, and clicks a link expects the panel to be gone
// on the next page -- which it is, because the next page is a different
// document.  So the outside-click close only matters for the reader who opens
// it and then dismisses it in place, and it is four lines.  It is not a focus
// trap and does not need to be: Escape is handled so a keyboard reader can
// dismiss it without reaching for the mouse.
public namespace underlayer_content {

    // Mark the nav entry the reader is actually on.  Runs on EVERY page, lesson
    // or not, because a lesson page needs "Learn" lit up exactly as much as
    // /courses does.
    public func render_nav_active_js(page : &mut HtmlPage) {
        #js {
            window.__ulPaintNavActive = function() {
                var p = window.location.pathname || '/';
                // Strip a trailing slash so /courses/ and /courses agree, but
                // leave a bare "/" alone.
                if (p.length > 1 && p.charAt(p.length - 1) === '/') {
                    p = p.slice(0, p.length - 1);
                }
                var items = document.querySelectorAll('[data-nav]');
                var best = null;
                var bestLen = -1;
                var i = 0;
                while (i < items.length) {
                    var key = items[i].getAttribute('data-nav') || '';
                    var hit = (key === p) ||
                              (key !== '/' && p.indexOf(key + '/') === 0);
                    if (hit && key.length > bestLen) {
                        best = items[i];
                        bestLen = key.length;
                    }
                    i = i + 1;
                }
                if (!best) { return; }
                best.classList.add('active');
                best.setAttribute('aria-current', 'page');
                // Light up the group the active item lives in, so a reader on
                // /bookmarks sees "Your space" as the current section and not
                // five unrelated top-level links that are all equally inactive.
                var panel = best.closest ? best.closest('.nav-menu') : null;
                if (panel) {
                    panel.setAttribute('data-active', 'true');
                    var summary = panel.querySelector('.nav-menu-summary');
                    if (summary) { summary.classList.add('active'); }
                }
            };

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', window.__ulPaintNavActive);
            } else {
                window.__ulPaintNavActive();
            }
        }
    }

    // The narrow-screen menu.  Emitted on EVERY page, lesson pages included: the
    // toggle button is in the shared markup, so a lesson page without this
    // script carries a button that does nothing -- and on a phone that button
    // is the only route to every other page.  See the ordering note in
    // render_site_nav, which is why this call sits ABOVE the lesson
    // early-return and the theme's does not.
    public func render_nav_toggle_js(page : &mut HtmlPage) {
        #js {
            window.__ulNavToggle = function(open) {
                var btn = document.getElementById('ul-nav-toggle');
                var panel = document.getElementById('ul-nav-links');
                if (!btn || !panel) { return; }
                var next = (typeof open === 'boolean') ? open : !panel.classList.contains('nav-open');
                panel.classList.toggle('nav-open', next);
                // aria-expanded is the only thing a screen reader announces for
                // this control, so it has to agree with what is on screen.
                btn.setAttribute('aria-expanded', next ? 'true' : 'false');
            };

            document.addEventListener('DOMContentLoaded', function() {
                var btn = document.getElementById('ul-nav-toggle');
                var panel = document.getElementById('ul-nav-links');
                if (!btn || !panel) { return; }
                btn.addEventListener('click', function() { window.__ulNavToggle(); });
                // Dismiss in place. A click on a link navigates anyway, so this
                // only covers "opened it, changed my mind".
                document.addEventListener('click', function(e) {
                    if (!panel.classList.contains('nav-open')) { return; }
                    if (panel.contains(e.target) || btn.contains(e.target)) { return; }
                    window.__ulNavToggle(false);
                });
                // Close any open <details> menus on Escape, then the panel
                // itself, so Escape always leaves the reader where they started
                // rather than one level deeper than they asked to be.
                document.addEventListener('keydown', function(e) {
                    if (e.key !== 'Escape' && e.key !== 'Esc') { return; }
                    var openMenus = document.querySelectorAll('.nav-menu[open]');
                    var i = 0;
                    while (i < openMenus.length) { openMenus[i].removeAttribute('open'); i = i + 1; }
                    if (panel.classList.contains('nav-open')) {
                        window.__ulNavToggle(false);
                        btn.focus();
                    }
                });
            });
        }
    }

    // Theme init, shared so every page that offers the toggle behaves the same
    // way: saved choice first, then the OS preference.  Never emitted on a
    // lesson page, because no lesson page draws the toggle.
    public func render_site_nav_js(page : &mut HtmlPage) {
        #js {
            function getTheme() {
                // THE try/catch HERE IS NOT DEFENSIVE NOISE.  localStorage
                // ACCESS THROWS -- it does not return null -- in a browser with
                // site data blocked (Firefox "Block cookies and other site
                // data" on file:// and in private windows; Safari ITP in
                // third-party contexts).  An unguarded read therefore takes
                // down the WHOLE script block, not just the theme: every
                // function defined after this line in the same <script> is
                // still DEFINED (the block parsed) but never RUNS, because
                // setTheme(getTheme()) is a top-level statement and its
                // throw aborts the block.  So the identity loader and the
                // sign-out handler in the other component -- separate blocks,
                // separate <script> tags -- survived, while anything in THIS
                // block did not.
                //
                // The same reason the identity helper in lesson_identity.ch
                // wraps its own read.  It had the guard, this one did not, and
                // "the theme helper is the one that breaks" is exactly the kind
                // of asymmetry that a shared helper (web/src/session_js.ch)
                // exists to remove.
                var saved = '';
                try { saved = localStorage.getItem('theme'); } catch (e) { saved = ''; }
                if (saved) return saved;
                var prefersDark = false;
                try { prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches; }
                catch (e) { prefersDark = false; }
                return prefersDark ? 'dark' : 'light';
            }
            function setTheme(theme) {
                document.documentElement.classList.toggle('dark', theme === 'dark');
                // A failed WRITE must not take the toggle down either: the
                // class has already been applied above, so the visible change
                // has happened.  Letting the write throw here would undo that
                // for the reader -- the button would appear not to work.
                try { localStorage.setItem('theme', theme); } catch (e) { }
            }
            function toggleTheme() {
                var current = document.documentElement.classList.contains('dark') ? 'dark' : 'light';
                setTheme(current === 'dark' ? 'light' : 'dark');
            }
            setTheme(getTheme());
        }
    }

}