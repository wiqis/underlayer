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
// WHY IT DELEGATES TO WiqisTheme WHEN THAT IS PRESENT.  The head script must
// run before the nav's own helpers are DEFINED, so it cannot call them; but
// brandlib's pre-paint script runs earlier still and installs the globals. On
// those pages this script only re-applies the same stored choice; on a lesson
// page (no brandlib) it resolves `wiqis-theme` itself with the same three
// values. One key, one class, one answer.
//
// LOCALSTORAGE IS GUARDED.  Reading it throws when site data is blocked, and a
// throw in a head script aborts before the class is set -- leaving the page in
// the wrong theme with no UI path to correct it.
//
// WHAT IT ALSO DOES: set `data-theme` and `color-scheme`, so the browser's own
// form controls and scrollbars follow the same choice as the document.
using std::string

public namespace underlayer_content {

    // Emit the pre-paint theme script into <head> -- ON EVERY PAGE, lessons
    // included.
    //
    // This used to return early on a lesson page: lessons had a hardcoded light
    // palette and no token set, so adding `.dark` half-darkened them (a dark
    // <body> with white unit cards on top).  That was the symptom of a missing
    // token set, not a reason to skip the theme: after the palette was moved to
    // brand tokens (lesson_nav_css.ch / journey_shell.ch) a lesson has a real
    // `.dark` appearance, and skipping the boot left it in Times New Roman on a
    // white card while the rest of the fleet followed the reader's choice.
    // There is now ONE theme contract and it applies to every surface.
    //
    // The key is `wiqis-theme`, the company-wide key used by brandlib's
    // WiqisTheme (`system` | `light` | `dark`).  When WiqisTheme has already
    // installed its globals, this script delegates to them; on a lesson page,
    // where there is no WiqisTheme, it resolves the same key itself.  Using a
    // second `theme` key here was how a page could hold two contradictory
    // preferences at once.
    public func render_theme_boot_js(page : &mut HtmlPage, lesson : bool) {
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
        var boot = string("<script>(function(){var g=window.$wiqisThemeGet;if(typeof g==='function'){window.$wiqisThemeSet(g());return;}var p='system';try{p=localStorage.getItem('wiqis-theme')||'system';}catch(e){p='system';}var d=p==='dark';if(p==='system'){d=false;try{d=!!(window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches);}catch(e){d=false;}}var el=document.documentElement;el.classList.toggle('dark',d);el.setAttribute('data-theme',p);el.style.colorScheme=d?'dark':'light';})();</script>")
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