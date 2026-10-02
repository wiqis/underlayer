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

    // A collection page: skip-link plus navbar, theme toggle included.
    public func render_nav_bar(page : &mut HtmlPage) {
        underlayer_content::render_site_nav(page)
    }

}
