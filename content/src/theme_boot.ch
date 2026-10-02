// underlayer_content — THE THEME, APPLIED BEFORE THE FIRST PAINT.
//
// THE BUG THIS EXISTS FOR, REPRODUCED NOT GUESSED.
//
// Measured on the served HTML of every themed page, 2026-10-02:
//
//     /dashboard   </head> at 19555   theme detection at 134902
//     /courses     </head> at 14658   theme detection at 228801
//     /search      </head> at 11919   theme detection at 112403
//
// So the code that reads `prefers-color-scheme` runs ~100 KB into the BODY,
// inside the one giant <script> that the universal-components runtime emits at
// the end. The browser therefore paints the document in the DEFAULT theme --
// light -- and only later, when that script executes, does `setTheme` add
// `.dark` to <html> and the page repaints. That is the flash: not a slow page,
// a CORRECT page that arrives in the wrong colours and then corrects itself.
//
// WHY IT CANNOT BE FIXED WHERE THE OLD SCRIPT IS.  A script at the end of
// <body> is too late by definition: the browser has already parsed and painted
// everything above it. Moving `setTheme(getTheme())` earlier inside that same
// script would help only if the script were earlier, and the script's position
// is the components runtime's, not ours.
//
// THE FIX IS THE STANDARD ONE: a tiny BLOCKING script in <head>. It runs before
// the first paint, sets the class, and costs a few hundred bytes. `pageHeadJs`
// is emitted inside <head> immediately before </head> (page.ch:864-867), which is
// exactly the slot for this.
//
// WHY IT IS INLINED AND NOT A SEPARATE .js FILE.  An external stylesheet or
// script is fetched, and a fetch is a round trip during which the browser is
// holding an UNPAINTED document. Inlining removes the round trip entirely, which
// is the whole point: this is not a performance nicety, it is the difference
// between the correct colour appearing first and appearing second. It also keeps
// the statically pre-rendered lesson pages working from file:// with no server.
//
// WHY THE LOGIC IS DUPLICATED FROM lesson_nav.ch'S getTheme().  It has to be:
// the head script must run before `getTheme` is DEFINED, so it cannot call it.
// The duplication is kept honest by tools/theme_check.py, which asserts that
// this script and the nav's agree on the two questions that can disagree --
// where the choice comes from, and what class name is applied. If either moves,
// that checker fails.
//
// ONE BEHAVIOURAL DIFFERENCE, DELIBERATE: this one tolerates a THROWING
// localStorage, and the nav's did not until the same day. Both now do, because
// localStorage access throws when site data is blocked, and a throw in the head
// script would abort before the class was set -- leaving the page in the light
// theme with no way to fix it from the UI.
//
// WHAT THIS DOES NOT DO.  It does not add a `color-scheme` CSS property, so the
// browser's own form controls and scrollbars are still light. That is a
// separate improvement and it belongs in the theme's own CSS, not here.
using std::string

public namespace underlayer_content {

    // Emit the pre-paint theme script into <head>.
    //
    // `lesson` is true on a content/src lesson page.  Lesson pages draw no theme
    // toggle (see lesson_nav.ch for why) and use their own hardcoded light
    // palette, so applying a `.dark` class to them would half-darken a page that
    // was never designed for it.  They are therefore skipped -- and that is a
    // correctness decision rather than an omission, so it is stated here rather
    // than left to be discovered.
    public func render_theme_boot_js(page : &mut HtmlPage, lesson : bool) {
        if(lesson) { return }
        // A RAW <script> into <head>, NOT a `#js` block.
        //
        // This is the detail that makes the fix work, and it cost one wrong
        // version to find: `#js` appends to `pageJs`, and `pageJs` is emitted in
        // ONE <script> at the very END of <body> (page.ch:871-876).  So the
        // first version of this function ran 100 KB into the body -- the flash,
        // unchanged, plus a <meta> that looked like it had fixed something.
        //
        // `append_head_view` writes into `pageHead`, which `toString` renders
        // between <head> and </head> (page.ch:857-860).  That is the slot.
        //
        // The script is also deliberately SELF-CONTAINED and IIFE-wrapped: it
        // must not depend on any other function being defined, because nothing
        // else has been parsed yet at this point in the document.
        var boot = string("<script>(function(){var c='';try{c=localStorage.getItem('theme')||'';}catch(e){c='';}var d=c;if(d!=='light'&&d!=='dark'){d='light';try{if(window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches){d='dark';}}catch(e){d='light';}}document.documentElement.classList.toggle('dark',d==='dark');})();</script>")
        var bv = boot.to_view()
        page.append_head_view(&bv)
    }

    // `<meta name="color-scheme">`, so the browser paints its OWN surfaces --
    // the page background behind the document, form controls, scrollbars, the
    // space around a <select> dropdown -- in the right colour too.
    //
    // Without it the document is dark and the frame around it is light, which
    // is visible on mobile Safari and in any browser with a non-default
    // background. Declaring both schemes (rather than only the chosen one) is
    // deliberate: it tells the browser "this page supports both", so a control
    // opened later follows the live theme instead of freezing at first paint.
    public func render_color_scheme_meta(page : &mut HtmlPage) {
        var meta = string("<meta name=\"color-scheme\" content=\"light dark\">")
        var mv = meta.to_view()
        page.append_head_view(&mv)
    }

}