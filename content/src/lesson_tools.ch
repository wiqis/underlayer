// underlayer_content — THE tools row: what a learner can DO to a lesson.
//
// WHY IT LIVES IN THE NAV AND NOT IN THE LESSON BODY.  Measured 2026-10-02:
// api/auth/me, api/bookmarks, api/notes, api/feedback, streaks,
// api/achievements and api/certificates were called from ZERO of the 438 page
// builders in this directory, while all seven endpoints shipped and worked.  A
// learner could read a lesson and not bookmark it, not annotate it, not tell
// whether they were signed in, not send a correction, and not see how they were
// doing.  The engagement strip fixed the same class of defect for one event
// (see lesson_engagement.ch): the fix is the shared component every lesson page
// already renders, not 431 hand edits.  This is the rest of that fix.
//
// WHY A SEPARATE ROW AND NOT THREE MORE SPANS IN THE PROGRESS STRIP.  The strip
// above it answers one question -- where am I in this course -- and it answers
// it with a position, a bar and a status pill.  Bookmarking is not a position.
// Mixing them would have made the strip a toolbar, and a strip that is also a
// toolbar is the thing a reader stops reading.  Two rows, two questions: this
// one is what you can do HERE, the strip is where you are.
//
// TWO GROUPS, ONE ROW, AND WHY THE SEPARATOR IS REAL.  `ul-tools-standing` is
// facts about the learner (streak, achievements, certificate) and
// `ul-tools-actions` is facts about this page (bookmark, note, report).  They
// are not the same kind of fact and they do not change together: signing out
// empties the first group and takes the second group away entirely.
//
// EVERYTHING HERE IS BEHIND THE SIGNED-IN GATE, WITH ONE EXCEPTION DELIBERATE.
// Backend-optional is a design rule of this platform: a course must work from a
// file:// URL with no server.  So the row reveals itself with no token and says
// what a signed-in learner could do, and every button that would need the server
// stays unrendered-but-inert.  No feature in this row can hide, delay, or
// interfere with the lesson, because the lesson is above it in the document and
// this row is a set of controls the reader chooses to press.
//
// ONE CALL, FIVE EMISSIONS, AND WHY THE OTHERS ARE INSIDE THIS FUNCTION
// RATHER THAN BESIDE IT.  The markup, the styles and the three script blocks
// are emitted from here so that `render_lesson_tools(page)` in
// content/src/lesson_nav.ch is the whole feature: remove that one line and the
// row, its styles and all three scripts go together.  They were four sibling
// calls in the nav first, and tools/integration_check.py's non-vacuity proof
// caught the consequence -- the boot script survived without the functions it
// called, and every lesson threw `__ulLoadBookmark is not a function`.  A
// feature that cannot be removed in one line cannot be measured in one line.
//
// NO RAW BRACES IN #html (AGENTS.md rule 7 / tools/bracecheck.py).  Every
// handler is attached from the #js block in lesson_tools_js.ch, never from an
// inline onclick, because an onclick is a brace inside an attribute and that is
// exactly what bracecheck.py exists to catch.
public namespace underlayer_content {

    public func render_lesson_tools(page : &mut HtmlPage) {
        #html {
            <div class="ul-tools" id="ul-tools" hidden>
                <div class="ul-tools-standing">
                    <span class="ul-chip" id="ul-streak" hidden></span>
                    <span class="ul-chip" id="ul-achievements" hidden></span>
                    <a class="ul-chip ul-chip-link" id="ul-certificate" href="/courses" hidden>Claim your certificate</a>
                </div>
                <div class="ul-tools-actions" id="ul-tools-actions" hidden>
                    <button type="button" class="ul-tool" id="ul-bookmark" aria-pressed="false">Bookmark</button>
                    <button type="button" class="ul-tool" id="ul-notes-toggle" aria-expanded="false" aria-controls="ul-notes-panel">Note</button>
                    <button type="button" class="ul-tool" id="ul-feedback-toggle" aria-expanded="false" aria-controls="ul-feedback-panel">Report a problem</button>
                </div>
                <p class="ul-tools-offline" id="ul-tools-signedout" hidden>Sign in to bookmark this lesson, keep notes on it, and send corrections.</p>
                <div class="ul-panel" id="ul-notes-panel" hidden>
                    <label class="ul-panel-label" for="ul-note-text">Your note on this lesson</label>
                    <textarea class="ul-field" id="ul-note-text" rows="3" maxlength="2000" placeholder="What confused you, what you concluded, what to check."></textarea>
                    <div class="ul-panel-row">
                        <button type="button" class="ul-tool ul-tool-primary" id="ul-note-save">Save note</button>
                        <span class="ul-panel-state" id="ul-note-state"></span>
                    </div>
                    <ul class="ul-note-list" id="ul-note-list"></ul>
                </div>
                <div class="ul-panel" id="ul-feedback-panel" hidden>
                    <label class="ul-panel-label" for="ul-feedback-type">What is wrong with this lesson</label>
                    <select class="ul-field" id="ul-feedback-type">
                        <option value="correction">A fact here is wrong</option>
                        <option value="unclear">Something is unclear</option>
                        <option value="broken">Something does not work</option>
                        <option value="gap">Something important is missing</option>
                    </select>
                    <label class="ul-panel-label" for="ul-feedback-message">Where</label>
                    <textarea class="ul-field" id="ul-feedback-message" rows="3" maxlength="2000" placeholder="Point at the sentence, the number or the step."></textarea>
                    <div class="ul-panel-row">
                        <button type="button" class="ul-tool ul-tool-primary" id="ul-feedback-save">Send</button>
                        <span class="ul-panel-state" id="ul-feedback-state"></span>
                    </div>
                </div>
            </div>
        }
        render_lesson_tools_css(page)
        render_lesson_tools_js(page)
        render_lesson_tools_boot(page)
        render_lesson_feedback_js(page)
        render_lesson_standing_js(page)
    }

}