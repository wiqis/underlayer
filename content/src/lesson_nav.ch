// underlayer_content — THE site nav, as one component.
//
// WHY IT LIVES IN content/ AND NOT IN web/.  The nav has to be reachable from
// two layers.  The collection pages in web/src used to carry their own copy
// each -- that is what let `/courses` stay broken for so long: every page
// rendered a nav that looked finished, and the href in it went nowhere.  The
// 398 lesson pages are built in content/src, which is the layer BELOW web and
// cannot import it.  A component only one layer can call is a component half
// the collection cannot use, so it lives in the layer both can call, and
// web/src/nav_bar.ch is now a two-line delegation to this file.  There is one
// nav here, not one here and one there.
//
// WHY FOURTEEN LINKS BECAME FOUR PLUS ONE MENU.  Measured on the served HTML,
// 2026-10-03: the nav carried fourteen peer links -- Home, Courses, Path,
// Search, Dashboard, Review, Progress, Bookmarks, Notes, Planner,
// Achievements, Streaks, Alerts, Certificates -- in one flat `flex-wrap: wrap`
// row inside a 1400px bar.  On a 1440px screen that is one unreadable line of
// fourteen equally-weighted words with no grouping and nothing to say which
// one matters; below 1300px six of those pages hid `.nav-links` outright with
// no hamburger to restore it, so the whole nav simply vanished on a laptop
// (see the removal note in web/src/home_assets.ch).  A learner opening
// Underlayer could not tell what the product was asking of them.
//
// docs/ui-ux-design.md:438 already answered this and the code had drifted away
// from it: it specifies `Header: [Logo] [Courses] [Progress] [Settings]`.  So
// the nav now leads with the four things a learner actually came for -- Learn,
// Path, Review, Progress -- plus Search, and puts the ten account-scoped
// screens behind one "Your space" menu.  Six top-level items instead of
// fourteen; every route still reachable; and the grouped ones are now visibly
// grouped, which is the thing a flat list could not say.
//
// WHY A MENU AND NOT A TRUNCATED LIST.  Dropping the ten screens would have
// been cheaper and would have broken tools/nav_check.py, which requires
// /dashboard and /progress to be present in the nav region precisely so that
// "a nav is present but empty" cannot pass.  A `<details>` menu keeps every
// href in the document for that checker AND degrades correctly with scripting
// off, because `<details>` needs no JavaScript to open.  A button-plus-`hidden`
// menu would have hidden ten routes from every reader with JS blocked, and it
// would need an ARIA-expanded/cat-keyboard-close dance to match what
// `<details>` gives for free.
//
// WHY THE ACTIVE LINK IS CHOSEN BY SCRIPT AND WHY NOTHING IS ACTIVE BEFORE IT
// RUNS.  This function is called from 442 places and none of them knows the
// request path -- a lesson page knows its course and concept, but not the URL
// it was served at, and threading a parameter through 442 files to light up
// one class is the wrong trade.  So the choice is made client-side from
// `location.pathname`, in the script that every nav already loads.
//
// The important half is what it REPLACED.  The markup used to hardcode
// `class="nav-link active"` on Courses, so every page in the product -- the
// home page, a lesson, a certificate -- highlighted "Courses" forever.  That is
// worse than no highlight: it is a confident wrong answer, and on the home page
// it pointed at a page the reader was not on.  So there is now NO default
// active class in the markup.  If the script never runs, the reader sees no
// highlighted link, which is merely uninformative; where before they saw a
// lie.  See lesson_nav_js.ch for the matcher.
//
// WHY A LESSON PAGE GETS A SLIGHTLY SMALLER NAV, and why that is not a second
// navbar.  Both differences are inside this one component, switched by one
// flag, and both are because the thing the piece would control is not there:
//
//   * no skip-link.  On a lesson page this nav is the FIRST element in <body>,
//     so there is nothing above it for a skip-link to skip.  386 of the 398
//     lesson pages also carry no id="main-content", so a skip-link aimed at
//     one would be a link to an anchor that is not on the page -- the exact
//     dead-link shape this collection already had once.
//   * no theme toggle.  A lesson page does not inject the components theme, so
//     it has no dark mode and nothing for the toggle to change.  A button that
//     changes nothing is a decoration, and this collection's design rules
//     forbid decorative interactivity.
//
// WHY THESE ARE WRITTEN AS AN EARLY RETURN AND NOT AS `@if`/`@else` INSIDE A
// `#html` BLOCK.  `@if(cond) { ... } @else { ... }` in a block is the documented
// form and pages_courses' cards use it, but tools/bracecheck.py ends a `#html`
// block at the first line that is nothing but `}` -- which is the line closing
// the `@else`.  Written that way the block stops being checked at the
// conditional, so a nav whose whole job is to be on 398 pages should not be
// the page that is quietly not verified.  Two early returns give both checkers
// the whole block.
//
// THE COLOURS ARE THE NAV'S OWN TOKENS, NOT THE THEME'S, and the reason is a
// compiler bug worth writing down.  The obvious way to make one stylesheet
// serve both a themed page and a lesson page is a fallback:
// `hsl(var(--card, 0 0% 100%))`.  That does not work here.  The css_cbi
// pipeline SILENTLY DROPS the fallback -- verified with a standalone probe
// module, where `color: var(--x, red)` comes out of the macro as
// `color: var(--x)` -- so the nav would render with invalid colours on exactly
// the 398 pages this file exists to fix.  So the nav defines its own
// `--nav-*` tokens on :root and .dark, carrying the components theme's own
// light and dark values: identical rendering on a themed page, correct
// rendering on a lesson page, and no dependence on a feature this compiler does
// not have.  If the theme's values change, these change with them -- that is
// the cost of the fallback bug and it is paid in one file.
public namespace underlayer_content {

    // The one entry point.  `lesson` is true on a content/src page.
    public func render_site_nav(page : &mut HtmlPage, lesson : bool = false) {
        // THE THEME IS APPLIED BEFORE THE FIRST PAINT, from <head>.
        //
        // This is the fix for the flash: the page painted light, then the body
        // script added `.dark` and it repainted. This call emits a small
        // blocking script into <head> instead, so the first paint is already the
        // right colour. It goes HERE, before anything else, because this is the
        // one function every themed page in both layers calls -- so the fix
        // cannot be applied to some pages and forgotten on others, which is how
        // the eleven duplicate navs happened in the first place.
        render_theme_boot_js(page, lesson)
        render_color_scheme_meta(page)
        nav_skip_link(page, lesson)
        #html {
            <div class="navbar">
                <div class="nav-inner">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <button type="button" class="nav-toggle" id="ul-nav-toggle" aria-expanded="false" aria-controls="ul-nav-links">
                        <span class="nav-toggle-bars" aria-hidden="true"></span>
                        <span class="nav-toggle-text">Menu</span>
                    </button>
                    <div class="nav-links" id="ul-nav-links">
                        <a href="/courses" class="nav-link" data-nav="/courses">Learn</a>
                        <a href="/learning-path" class="nav-link" data-nav="/learning-path">Path</a>
                        <a href="/review" class="nav-link" data-nav="/review">Review</a>
                        <a href="/progress" class="nav-link" data-nav="/progress">Progress</a>
                        <a href="/search" class="nav-link" data-nav="/search">Search</a>
                        <details class="nav-menu">
                            <summary class="nav-link nav-menu-summary">Your space</summary>
                            <div class="nav-menu-panel">
                                <a href="/dashboard" class="nav-link" data-nav="/dashboard">Dashboard</a>
                                <a href="/bookmarks" class="nav-link" data-nav="/bookmarks">Bookmarks</a>
                                <a href="/notes" class="nav-link" data-nav="/notes">Notes</a>
                                <a href="/study-plans" class="nav-link" data-nav="/study-plans">Study planner</a>
                                <a href="/achievements" class="nav-link" data-nav="/achievements">Achievements</a>
                                <a href="/streaks" class="nav-link" data-nav="/streaks">Streaks</a>
                                <a href="/notifications" class="nav-link" data-nav="/notifications">Alerts</a>
                                <a href="/certificates" class="nav-link" data-nav="/certificates">Certificates</a>
                                <div class="nav-menu-rule" role="separator"></div>
                                <a href="/help" class="nav-link" data-nav="/help">Help</a>
                                <a href="/faq" class="nav-link" data-nav="/faq">FAQ</a>
                                <a href="/settings" class="nav-link" data-nav="/settings">Settings</a>
                            </div>
                        </details>
                    </div>
                    {nav_right(page, lesson)}
                </div>
            </div>
        }
        render_site_nav_css(page)
        render_identity_css(page)
        render_identity_js(page)
        render_nav_active_js(page)
        // The narrow-screen menu script goes on EVERY page, lesson included.
        //
        // It used to sit after the `lesson` early-return, which is where it was
        // when only the THEME was meant to be skipped.  But the toggle BUTTON is
        // in the shared markup, so a lesson page rendered a nav toggle that did
        // nothing at all -- the second dead control this component used to
        // carry, and the more serious of the two, because it is the only way out
        // of the nav on a narrow screen.  The early-return below is now about
        // the theme and nothing else, which is what its comment always said.
        render_nav_toggle_js(page)
        if(lesson) {
            return
        }
        render_site_nav_js(page)
    }

    // What every course in the collection called from its page builder.  Named
    // for the page it is called from, so the insertions read as what they are;
    // it is the same one nav, through the same one markup block.
    //
    // IT ALSO REPORTS THE ENGAGEMENT EVENT, and that is not incidental.  431 of
    // the 438 page builders in this directory make this call and nothing else
    // that is universal, which makes it the one place a fact about every lesson
    // page can live.  Before it, "a learner opened a concept" was reported by
    // 31 hand-written copies inside 31 pages' own #js blocks and by nobody
    // else, so FSRS, streaks, achievements and every progress view depended on
    // an event that seven of every eight pages never produced.  Adding it here
    // reaches all 431 in one reviewable line, and tools/progress_check.py
    // fails if it is ever taken out.
    //
    // It goes AFTER the nav markup because that is the order the browser wants
    // -- the strip sits between the nav and the lesson, where a positional fact
    // about the course belongs -- and because HtmlPage collects blocks
    // regardless of call order, so neither this nor the caller's
    // `page.defaultPrepare()` placement changes the output.
    // IT ALSO EMITS THE LESSON TOOLS -- the bookmark, note, report, streak and
    // achievement row -- and that call is INSIDE render_lesson_tools() rather
    // than beside it, for a reason that was found by removing it.  The scripts
    // and the markup were four sibling calls; taking away `render_lesson_tools`
    // took away the markup and left the boot function on the page, which then
    // threw `window.__ulLoadBookmark is not a function` on every lesson.  The
    // non-vacuity proof in tools/integration_check.py surfaced it as a Node
    // stack trace.  A feature has to be removable in ONE line or the gate that
    // removes it is measuring half a feature.
    public func render_lesson_nav(page : &mut HtmlPage) {
        render_site_nav(page, true)
        // THE SHORT SIGN-IN ADVISORY.  One line, one button, hidden in the
        // markup and revealed only for a reader who has no session -- so a
        // signed-in reader never sees a flash of it, and a page opened from
        // disk with no server at all never sees it.  The lesson is NOT gated:
        // a stranger has to be able to read one before deciding whether to
        // register.  See web/src/pages_auth_gate.ch for why that line is drawn
        // there rather than here.
        render_signin_advisory(page)
        render_signin_advisory_js(page)
        render_lesson_engagement(page)
        render_lesson_tools(page)
        // THE READING CONTROLS' BEHAVIOUR, for every lesson page.
        //
        // 100 lesson pages ship the markup -- three accessibility buttons, four
        // reading dropdowns, a shortcuts dialog -- and 21 of them ship the
        // JavaScript that makes it work. The other 79 raised
        // `ReferenceError: toggleHighContrast is not defined` on click, and their
        // four <select>s silently reverted, because `onchange` on a missing
        // function throws the same way.
        //
        // It is called HERE, inside render_lesson_nav, rather than inside
        // render_lesson_js, because 435 page builders call this function and only
        // 333 call that one. Putting it next to the 79 pages that were broken is
        // the whole point; putting it in the less-reached helper would leave them
        // broken.
        render_lesson_controls_js(page)
    }

    // Reveal the advisory for a signed-out reader.
    //
    // It rides on the /api/auth/me call the nav's identity loader ALREADY
    // makes, so this adds no request to any page.  Re-reading the token is not
    // enough on its own -- a stale token means signed out, and a reader with a
    // stale token should be shown the advisory, not an empty lesson tools row
    // that quietly does nothing.
    func render_signin_advisory_js(page : &mut HtmlPage) {
        #js {
            window.__ulPaintSigninAdvisory = function(isSignedIn) {
                var bar = document.getElementById('ul-signin-advisory');
                if (!bar) { return; }
                // Only ever unhide. A late-arriving answer must not remove a
                // prompt the reader is already looking at.
                if (!isSignedIn) { bar.hidden = false; }
            };

            window.addEventListener('DOMContentLoaded', function() {
                var signedIn = false;
                if (typeof window.__ulToken === 'function' &&
                    window.__ulToken().length > 0) {
                    // A token exists; only /api/auth/me can say whether it is
                    // still good.  Failure means signed out, which is the
                    // answer the advisory is for.
                    fetch('/api/auth/me', { headers: window.__ulHeaders() })
                        .then(function(r) { return r.ok ? r.json() : null; })
                        .then(function(d) {
                            signedIn = !!(d && d.learner_id);
                            window.__ulPaintSigninAdvisory(signedIn);
                        })
                        .catch(function() { window.__ulPaintSigninAdvisory(false); });
                } else {
                    window.__ulPaintSigninAdvisory(false);
                }
            });
        }
    }

    // The skip-link, on pages that have something above the nav to skip past.
    // A lesson page does not, and 386 of the 398 have no #main-content to aim
    // at, so on a lesson page this emits nothing at all.
    func nav_skip_link(page : &mut HtmlPage, lesson : bool) {
        if(!lesson) {
            #html {
                <a href="#main-content" class="skip-link">Skip to content</a>
            }
            return
        }
    }

    // The right-hand slot.  A theme toggle on a themed page, and on BOTH
    // pages the identity slot that says whether anybody is signed in -- that was
    // /api/auth/me called from zero page builders on 2026-10-02, and an empty
    // right-hand slot is exactly where the answer belongs.  See
    // content/src/lesson_identity.ch.
    //
    // The slot is kept rather than omitted on a lesson page because `.nav-inner`
    // is `justify-content: space-between` and dropping the third child moves the
    // whole link row off-centre.
    func nav_right(page : &mut HtmlPage, lesson : bool) {
        if(!lesson) {
            #html {
                <div class="nav-right">
                    <span class="nav-identity" id="ul-identity" hidden></span>
                    <button type="button" class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
                        <span class="theme-icon-light">&#9728;</span>
                        <span class="theme-icon-dark">&#9790;</span>
                    </button>
                </div>
            }
            return
        }
        #html {
            <div class="nav-right">
                <span class="nav-identity" id="ul-identity" hidden></span>
            </div>
        }
    }

}