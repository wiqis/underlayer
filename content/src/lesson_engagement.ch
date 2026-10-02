// underlayer_content — THE engagement call, in one place, for every lesson.
//
// THE DEFECT THIS FILE FIXES, measured on 2026-10-02 against the running
// server.  A learner registered, signed in, opened three lesson pages, and
// GET /api/progress came back byte-identical.  The read side, the FSRS
// schedule, streaks, achievements and analytics are all downstream of one
// event: "a learner opened a concept".  Nothing produced it.
//
// WHY 31 FILES ALREADY LOOKED LIKE THEY DID.  31 of the 438 page builders in
// content/src carried their own hand-written copy of the POST below, inside
// their own #js block -- a copy per page, in the page, invisible to review as
// a single decision.  The other 407 produced no event at all: every HAT page,
// every a64/jvm/mem/smp page, every page whose nav it draws itself.  So the
// collection had the behaviour on the pages a person happened to open first
// and not on the rest, which is why the collection looked instrumented.
//
// WHY ONE FUNCTION AND NOT 407 EDITS, which is the actual fix.  431 of the 438
// page builders already make exactly one call, `render_lesson_nav(&mut page)`
// -- inserted by tools/add_lesson_nav.py and asserted by that script's
// --check, because the nav on a lesson is not something you can forget.  The
// engagement call is the same kind of fact about a lesson page: it is true of
// every lesson page, so it belongs in the component every lesson page already
// renders.  Adding it here is one edit that reaches 431 pages, and it is
// checkable in the same way the nav is.  407 hand edits would have been 407
// chances to forget one, and nothing in the build would have said so.
//
// WHY THE CALL HAS NO COURSE OR CONCEPT ARGUMENT.  The page genuinely does not
// know them at build time: render_concept(concept_id) in web/src/helpers.ch
// builds an ELF page from a concept id alone, with no course, no module and
// no position, and the URL is the only place the pair exists.  So the script
// reads them from window.location -- the same thing the 31 existing copies do,
// which is a hint that this was always the intended shape -- and degrades to
// nothing when the pathname is not a lesson URL.  That last part is what makes
// it safe to emit on every page the nav reaches, including collection pages in
// web/src that call the same component.
//
// ONE EVENT PER PAGE LOAD, AND NOT ON A RESTORE.  Three separate guards,
// because each one closes a different hole:
//
//   1. It is fired from the DOMContentLoaded handler, once, from a closure.
//      There is no scroll listener, no IntersectionObserver and no timer, so
//      reading a long lesson for twenty minutes cannot produce twenty events.
//   2. It is skipped when the pageshow event carries `persisted` -- that is
//      the back/forward cache.  A back-navigation to a lesson you already read
//      restores the page from memory WITHOUT re-running DOMContentLoaded's
//      work in a meaningful sense; browsers have been inconsistent here for
//      years, and counting a restore as a new read is how a learner ends up
//      with a streak built from pressing Back.
//   3. It is skipped when `document.visibilityState` is already 'prerender'.
//      Cheap, and it costs one property read.
//
// WHICH COMES AFTERWARDS, AND WHY IT IS NEEDED.  The three above are all about
// NOT firing.  This is about not firing TWICE, and it was found by a machine
// check rather than by reading: a normal page load fires DOMContentLoaded and
// then pageshow, and registering the start on both -- which this file did --
// records TWO reads for one page view.  tools/progress_check.py runs the
// emitted script in Node against a DOM shim, the shim fires both handlers the
// way a browser does, and the second POST came back.  The consequence was the
// same as the duplicate reporter removed by
// tools/remove_legacy_view_report.py: the first POST answers first_time:true
// and the second false, so a learner's first visit to a concept was labelled
// "read before", and record_activity() ran twice.
//
// The fix is the __ulEngagementStarted flag on __ulStartEngagement, in
// lesson_engagement_js.ch.  It is per document, which is the right scope, and
// that also subsumes guard 2 above: a bfcache restore replays pageshow
// without re-running DOMContentLoaded, so the flag is still set and the restore
// is correctly not a new read.
//
// WHY "QUIETLY" FOR A SIGNED-OUT LEARNER.  Backend-optional is an explicit
// design rule of this platform: a course must work from a file:// URL with no
// server at all.  So there is no token -> no request, not a request -> 401 ->
// error.  The strip then says "Sign in to record your progress", which is the
// honest state and is still useful, rather than an empty box.
//
// NO RAW BRACES IN #html (AGENTS.md rule 7 / tools/bracecheck.py).  The strip
// is markup; the behaviour is in the #js block below it.
public namespace underlayer_content {

    // The strip: where the learner is in the course, whether this concept is
    // already logged, and the previous/next affordances.
    //
    // It is emitted by the nav rather than by each page, which is also how it
    // ends up ABOVE the lesson: it is a positional fact about the course, and
    // a positional fact belongs at the top of the page.
    public func render_lesson_engagement(page : &mut HtmlPage) {
        #html {
            <div class="ul-progress" id="ul-progress" hidden aria-live="polite">
                <div class="ul-progress-bar">
                    <div class="ul-progress-fill" id="ul-progress-fill"></div>
                </div>
                <div class="ul-progress-row">
                    <span class="ul-progress-where" id="ul-progress-where"></span>
                    <span class="ul-progress-state" id="ul-progress-state"></span>
                    <span class="ul-progress-nav">
                        <a class="ul-step" id="ul-prev" rel="prev" hidden>Previous</a>
                        <a class="ul-step" id="ul-next" rel="next" hidden>Next</a>
                    </span>
                </div>
            </div>
        }
        render_lesson_engagement_css(page)
        render_lesson_engagement_js(page)
        render_lesson_engagement_boot(page)
    }

}