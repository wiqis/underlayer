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
// B5 (2026-11-27) — FIRST STEP OF A STEPWISE CSP EXTERNALISATION.
//
// The script used to be inline on EVERY themed page, and it was one of the
// reasons `script-src` had to keep `'unsafe-inline'`. HTTP-served brand-shell
// pages now load the SAME source from a same-origin blocking external asset,
// `/assets/theme-boot.js`, with a pinned SRI `integrity` hash. A blocking
// external script still runs before the body is parsed, so there is no flash.
//
// The hash was deliberately NOT added to CSP `script-src`: under CSP3 that
// makes the browser ignore `'unsafe-inline'`, breaking the macro-emitted inline
// blocks (33 violations measured in a CDP drive). The asset is therefore
// covered by the existing `'self'` source and verified by SRI, not by a new
// policy entry. No tightened CSP is claimed.
//
// Lesson pages KEEP the inline copy. They are also pre-rendered for `file://`,
// where an absolute `/assets/...` URL points at the filesystem root and never
// resolves. Backend-optional is a core constraint: breaking the theme on a
// downloaded course is not an acceptable trade for a partial CSP win. This is
// an explicitly PARTIAL externalisation — see `docs/deployment.md` §6 item 1
// for the inventory and the remaining work.
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

    // The exact bytes of the external asset. `web/src/theme_boot_asset.ch`
    // serves this string and the `<script>` tag below pins its hash; the inline
    // fallback carries the same bytes. `tools/theme_boot_hash_check.py` proves
    // all three agree; a mismatch would make the browser refuse an SRI script
    // and reintroduce the flash.
    //
    // Deliberately a single quoted literal: no string appends build markup or
    // JS here, and every quote inside is a single quote so the Chemical string
    // literal stays unambiguous.
    public func theme_boot_js_source() : string {
        return string("(function(){var g=window.$wiqisThemeGet;if(typeof g==='function'){window.$wiqisThemeSet(g());return;}var p='system';try{p=localStorage.getItem('wiqis-theme')||'system';}catch(e){p='system';}var d=p==='dark';if(p==='system'){d=false;try{d=!!(window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches);}catch(e){d=false;}}var el=document.documentElement;el.classList.toggle('dark',d);el.setAttribute('data-theme',p);el.style.colorScheme=d?'dark':'light';})();")
    }

    // SHA-384 of theme_boot_js_source(), base64, pinned once in the SRI
    // `integrity` attribute below. Chemical cannot interpolate a value into a
    // `<script>` string literal, so the hash appears as a literal there rather
    // than through a constant; tools/theme_boot_hash_check.py is what keeps the
    // two from drifting. Deliberately NOT present in the CSP `script-src`.

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
        //
        // `lesson = true` means a lesson page (HTTP-served OR pre-rendered for
        // file://): keep the inline form (same bytes), because an absolute
        // asset URL cannot resolve from disk. Every HTTP-served brand-shell
        // page takes the external branch.
        var boot = string()
        if(lesson) {
            boot = string("<script>(function(){var g=window.$wiqisThemeGet;if(typeof g==='function'){window.$wiqisThemeSet(g());return;}var p='system';try{p=localStorage.getItem('wiqis-theme')||'system';}catch(e){p='system';}var d=p==='dark';if(p==='system'){d=false;try{d=!!(window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches);}catch(e){d=false;}}var el=document.documentElement;el.classList.toggle('dark',d);el.setAttribute('data-theme',p);el.style.colorScheme=d?'dark':'light';})();</script>")
        } else {
            boot = string("<script src=\"/assets/theme-boot.js\" integrity=\"sha384-+gwYSbETg+BseeAs0LJMGgeg+pDg1DdV59E7dJ0v+GH9CookguKFp6Nw5IFZ8dcH\"></script>")
        }
        // One append for both branches: the checker_nonvacuity plant replaces
        // this line and must kill the boot on served pages as well as on static
        // pages, otherwise it certifies nothing.
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
