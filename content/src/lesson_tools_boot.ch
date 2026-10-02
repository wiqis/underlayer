// underlayer_content — WHEN the tools row runs, and what it does when it cannot.
//
// SPLIT OUT OF lesson_tools_js.ch AND lesson_feedback_js.ch ONLY TO KEEP THOSE
// FILES UNDER 250 LINES (AGENTS.md).  Same namespace, one script block.
//
// REGISTERED ON DOMContentLoaded AND NOT ON pageshow, which is a decision and
// not an omission.  The engagement script needs both, because it POSTs an event
// and a bfcache restore must not count as a read.  Nothing here POSTs on load:
// the row does three GETs (bookmark state, this concept's notes, streak and
// achievement count), every one of them idempotent.  A restore that re-runs
// three reads costs a few milliseconds and cannot corrupt anything, and not
// registering a second listener is one less thing to get wrong than the
// engagement call already got wrong once (see lesson_engagement_boot.ch).
//
// THE THREE EXITS, IN ORDER, AND WHAT EACH ONE LEAVES THE READER WITH.
//
//   1. No lesson URL -- decline.  The nav is rendered by web/src on collection
//      pages too, and nothing in this row is about a lesson.  The row stays
//      hidden, exactly as the engagement script declines.  If this is wrong on
//      some page, the symptom is an absent control, not a broken page.
//
//   2. No token -- reveal the row and say what a signed-in learner could do.
//      NOT hidden.  The design rule is backend-optional: content is
//      self-contained and no feature may gate it, and the corollary the founder
//      asked for by name is that a signed-out learner must not be quietly
//      denied a feature they could have.  One line of text, no buttons, no
//      request.  The lesson above it is untouched either way.
//
//   3. Token -- wire the handlers and load the four reads.
//
// NOTHING IN THIS FILE CAN MAKE A LESSON FAIL.  Every branch is a
// getElementById that returns null off this page, and every fetch is followed by
// a .catch that does nothing.  There is no throw path and no way to hide the
// lesson body, which is above this row in the document.
public namespace underlayer_content {

    public func render_lesson_tools_boot(page : &mut HtmlPage) {
        #js {
            window.__ulBootTools = function() {
                var row = document.getElementById('ul-tools');
                if (!row) { return; }
                var ctx = window.__ulPosition();
                if (ctx === null) {
                    row.hidden = true;
                    return;
                }
                row.hidden = false;
                var t = window.__ulToken();
                if (t.length === 0) {
                    var so = document.getElementById('ul-tools-signedout');
                    if (so) { so.hidden = false; }
                    return;
                }
                var acts = document.getElementById('ul-tools-actions');
                if (acts) { acts.hidden = false; }
                window.__ulWireTools(ctx);
                window.__ulLoadBookmark(ctx);
                window.__ulLoadNotes(ctx);
                window.__ulLoadStanding();
            };
            document.addEventListener('DOMContentLoaded', function() { window.__ulBootTools(); });
        }
    }

}