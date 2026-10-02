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
        nav_skip_link(page, lesson)
        #html {
            <div class="navbar">
                <div class="nav-inner">
                    <a href="/" class="nav-brand">Underlayer</a>
                    <div class="nav-links">
                        <a href="/" class="nav-link">Home</a>
                        <a href="/courses" class="nav-link active">Courses</a>
                        <a href="/learning-path" class="nav-link">Path</a>
                        <a href="/search" class="nav-link">Search</a>
                        <a href="/dashboard" class="nav-link">Dashboard</a>
                        <a href="/review" class="nav-link">Review</a>
                        <a href="/progress" class="nav-link">Progress</a>
                        <a href="/bookmarks" class="nav-link">Bookmarks</a>
                        <a href="/notes" class="nav-link">Notes</a>
                        <a href="/study-plans" class="nav-link">Planner</a>
                        <a href="/achievements" class="nav-link">Achievements</a>
                        <a href="/streaks" class="nav-link">Streaks</a>
                        <a href="/notifications" class="nav-link">Alerts</a>
                        <a href="/certificates" class="nav-link">Certificates</a>
                    </div>
                    {nav_right(page, lesson)}
                </div>
            </div>
        }
        render_site_nav_css(page)
        render_identity_css(page)
        render_identity_js(page)
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
        render_lesson_engagement(page)
        render_lesson_tools(page)
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
                    <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">
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

    // The nav's own styles, so a page that renders the nav cannot render it
    // unstyled.  `position: sticky` and not `fixed`: a sticky bar stays in the
    // flow and therefore needs no body offset to clear it, while a fixed bar
    // needs a hard-coded `padding-top` equal to its own height -- a number
    // that is wrong the moment the link row wraps onto a second line on a
    // narrow screen.  All 43 other `.navbar` rules in this collection are
    // sticky and none is fixed, so this is also the convention.
    public func render_site_nav_css(page : &mut HtmlPage) {
        #css {
            :root { --nav-card: 0 0% 100%; --nav-border: 220 11% 89%; --nav-fg: 221 39% 11%; --nav-muted: 220 9% 46%; --nav-accent: 220 14% 96%; }
            .dark { --nav-card: 240 10% 3.9%; --nav-border: 240 3.7% 15.9%; --nav-fg: 0 0% 98%; --nav-muted: 240 5% 64.9%; --nav-accent: 240 3.7% 15.9%; }
            .skip-link { position: absolute; top: -100%; left: 0; background: hsl(217 91% 60%); color: white; padding: 0.75rem 1.5rem; z-index: 200; font-weight: 600; text-decoration: none; border-radius: 0 0 8px 0; }
            .skip-link:focus { top: 0; }
            .navbar { background: hsl(var(--nav-card)); border-bottom: 1px solid hsl(var(--nav-border)); padding: 0.75rem 0; position: sticky; top: 0; z-index: 100; }
            .nav-inner { max-width: 1400px; margin: 0 auto; padding: 0 1.5rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; row-gap: 0.25rem; column-gap: 1rem; }
            .nav-brand { font-size: 1.25rem; font-weight: 700; color: hsl(var(--nav-fg)); text-decoration: none; }
            .nav-brand:hover { color: hsl(217 91% 60%); text-decoration: none; }
            .nav-links { display: flex; flex-wrap: wrap; justify-content: center; align-items: center; gap: 0.25rem 0.5rem; flex: 0 1 auto; min-width: 0; }
            .nav-link { color: hsl(var(--nav-muted)); text-decoration: none; font-size: 0.9rem; font-weight: 500; padding: 0.5rem 0.6rem; border-radius: 6px; transition: all 0.15s; white-space: nowrap; }
            .nav-link:hover { color: hsl(var(--nav-fg)); background: hsl(var(--nav-accent)); text-decoration: none; }
            .nav-link.active { color: hsl(217 91% 60%); background: hsl(217 91% 60% / 10%); }
            .nav-right { display: flex; align-items: center; gap: 0.75rem; }
            .theme-toggle { background: none; border: 1px solid hsl(var(--nav-border)); border-radius: 8px; padding: 0.5rem; cursor: pointer; font-size: 1.1rem; line-height: 1; }
            .theme-toggle:hover { background: hsl(var(--nav-accent)); }
            .theme-icon-dark { display: none; }
            .dark .theme-icon-light { display: none; }
            .dark .theme-icon-dark { display: inline; }
        }
    }

    // Theme init, shared so every page that offers the toggle behaves the same
    // way: saved choice first, then the OS preference.  Never emitted on a
    // lesson page, because no lesson page draws the toggle.
    public func render_site_nav_js(page : &mut HtmlPage) {
        #js {
            function getTheme() {
                var saved = localStorage.getItem('theme');
                if (saved) return saved;
                return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
            }
            function setTheme(theme) {
                document.documentElement.classList.toggle('dark', theme === 'dark');
                localStorage.setItem('theme', theme);
            }
            function toggleTheme() {
                var current = document.documentElement.classList.contains('dark') ? 'dark' : 'light';
                setTheme(current === 'dark' ? 'light' : 'dark');
            }
            setTheme(getTheme());
        }
    }

}
