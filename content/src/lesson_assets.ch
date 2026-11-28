// Shared lesson CSS + JS for 8-unit concept pages.
//
// Every concept page (ELF, PE, ...) emits its own 8-unit markup and then calls
// render_lesson_css / render_lesson_js so courses look and behave consistently.
// Same pattern as course_landing_assets.ch (markup lives in #html/#css/#js
// macros only — no string-built HTML).
//
// The JS does two jobs:
//   1. Quiz / fill-in-the-blank checking with per-option explanations.
//   2. Reporting attempts and page views to the backend when a session token
//      exists. In static mode (no backend) every fetch fails silently, so the
//      same page works from a file:// URL.
public namespace underlayer_content {

    // ONE TYPEFACE, ONE TEXT SIZE, ONE MEASURE on every surface. The tokens are
    // declared by the shared nav stylesheet, which is emitted on lesson pages
    // too, so there is no lesson-only palette left to drift.
    public func render_lesson_css(page : &mut HtmlPage) {
        #css {
            body { font-family: var(--font-sans); font-size: 1rem; line-height: 1.6; margin: 0; color: hsl(var(--foreground)); background: hsl(var(--background)); }
            .lesson { max-width: 68ch; margin: 0 auto; padding: 2rem 1.5rem; }
            .lesson-meta { color: hsl(var(--muted-foreground)); font-size: 0.875rem; margin-bottom: 2rem; }
            .lesson h1 { font-size: 1.75rem; margin-bottom: 0.5rem; line-height: 1.3; }
            .unit { margin-bottom: 1.5rem; padding: 1.5rem; border-radius: 10px; border: 1px solid hsl(var(--border)); border-left: 4px solid hsl(var(--primary)); background: hsl(var(--card)); color: hsl(var(--foreground)); }
            .unit-why, .unit-model, .unit-reality, .unit-example, .unit-interact, .unit-retrieve, .unit-apply, .unit-connect { border-left-color: hsl(var(--primary)); background: hsl(var(--card)); }
            .unit h2 { font-size: 1.15rem; margin: 0 0 0.75rem 0; }
            .unit p { margin: 0.5rem 0; }
            .unit ul, .unit ol { margin: 0.5rem 0; padding-left: 1.4rem; }
            .unit li { margin: 0.25rem 0; }
            .lesson code { background: hsl(var(--muted)); color: hsl(var(--foreground)); padding: 0.15rem 0.4rem; border-radius: 4px; font-family: ui-monospace, monospace; font-size: 0.9em; }
            .lesson pre { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: ui-monospace, monospace; overflow-x: auto; white-space: pre; margin: 1rem 0; }
            .lesson table { width: 100%; border-collapse: collapse; margin: 1rem 0; font-size: 0.95rem; }
            .lesson th, .lesson td { padding: 0.5rem; border: 1px solid hsl(var(--border)); text-align: left; }
            .lesson th { background: hsl(var(--muted)); font-weight: 600; }
            .callout { padding: 0.75rem 1rem; margin: 0.75rem 0; border-radius: 6px; font-size: 0.95rem; }
            .callout-tip { background: hsl(var(--accent)); border-left: 3px solid hsl(var(--primary)); color: hsl(var(--foreground)); }
            .callout-warn { background: hsl(var(--accent)); border-left: 3px solid hsl(var(--primary)); color: hsl(var(--foreground)); }
            .formula { background: hsl(var(--card)); border: 1px dashed hsl(var(--border)); border-radius: 6px; padding: 0.6rem 0.9rem; margin: 0.75rem 0; font-family: ui-monospace, monospace; font-size: 0.95rem; color: hsl(var(--foreground)); }
            .quiz { margin-top: 1rem; }
            .quiz-option { display: block; width: 100%; min-height: 2.75rem; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid hsl(var(--border)); border-radius: 6px; background: hsl(var(--card)); cursor: pointer; text-align: left; font-size: 1rem; color: hsl(var(--foreground)); }
            .quiz-option:hover:not(:disabled) { border-color: hsl(var(--primary)); background: hsl(var(--accent)); }
            .quiz-option.correct { border-color: hsl(var(--primary)); background: hsl(var(--accent)); }
            .quiz-option.wrong { border-color: hsl(var(--primary)); background: hsl(var(--accent)); }
            .quiz-option:disabled { cursor: default; }
            .quiz-feedback { margin-top: 0.75rem; font-size: 0.9rem; min-height: 1.25rem; }
            .fill-blank { padding: 0.4rem 0.6rem; border: 1px solid hsl(var(--border)); border-radius: 4px; width: 7rem; font-family: ui-monospace, monospace; font-size: 0.95rem; margin: 0 0.25rem; background: hsl(var(--card)); color: hsl(var(--foreground)); }
            .fill-blank:focus { outline: 2px solid hsl(var(--primary)); outline-offset: 1px; }
            .fill-blank.correct { border-color: hsl(var(--primary)); background: hsl(var(--accent)); }
            .fill-blank.wrong { border-color: hsl(var(--primary)); background: hsl(var(--accent)); }
            .fill-check-btn { margin-top: 0.75rem; min-height: 2.75rem; padding: 0.5rem 1rem; border: 1px solid hsl(var(--border)); border-radius: 6px; background: hsl(var(--card)); cursor: pointer; font-size: 1rem; color: hsl(var(--foreground)); }
            .fill-check-btn:hover { background: hsl(var(--accent)); border-color: hsl(var(--primary)); }
            .fill-feedback { margin-top: 0.5rem; font-size: 0.9rem; }
            .lesson details { margin: 0.75rem 0; background: hsl(var(--card)); border: 1px solid hsl(var(--border)); border-radius: 6px; padding: 0.6rem 0.9rem; color: hsl(var(--foreground)); }
            .lesson summary { cursor: pointer; font-weight: 600; font-size: 0.95rem; }
            .lesson-footer { display: flex; justify-content: space-between; gap: 1rem; margin-top: 2.5rem; padding-top: 1.25rem; border-top: 1px solid hsl(var(--border)); font-size: 0.9rem; }
            .lesson-footer a { color: hsl(var(--primary)); text-decoration: none; }
            .lesson-footer a:hover { text-decoration: underline; }
            .back-link { display: inline-block; margin-bottom: 1rem; color: hsl(var(--primary)); text-decoration: none; font-size: 0.9rem; }
            .back-link:hover { text-decoration: underline; }
            .course-description { font-size: 1.05rem; color: #4b5563; margin: 0.5rem 0; }
            .module-list { display: flex; flex-direction: column; gap: 1.5rem; margin-top: 1.5rem; }
            .module-list .unit { margin-bottom: 0; }
            .concept-list { list-style: none; padding: 0; margin: 0.5rem 0 0 0; }
            .concept-list li { padding: 0.4rem 0; border-bottom: 1px solid hsl(var(--border)); }
            .concept-list li:last-child { border-bottom: none; }
            .concept-list a { color: hsl(var(--primary)); text-decoration: none; }
            .concept-list a:hover { text-decoration: underline; }
            /* H15 — reserve space for visual blocks that used to arrive after
               first paint (hex dumps, tables, figures, quiz controls). Layout
               reservation only: no byte, offset or spec claim is made here and
               no content is hidden. */
            .lesson pre, .lesson .hex-dump, .lesson .hex-interactive { min-height: 3.5rem; }
            .lesson table { min-height: 2.25rem; }
            .lesson figure, .lesson img, .lesson svg { min-height: 4rem; }
            .lesson .quiz, .lesson .quiz-options, .lesson .exercise-ui { min-height: 3rem; }
            @media (max-width: 640px) {
                .lesson { padding: 1rem; }
                .unit { padding: 1rem; }
                .lesson table { font-size: 0.85rem; }
                .lesson-footer { flex-direction: column; }
            }
        }
        render_exercise_css(page)
        // THE GUIDED JOURNEY.  Emitted here, in the shared lesson assets, so
        // every lesson that uses this helper gets the shell in BOTH modes:
        // pre-rendered static pages built from content/src and the pages served
        // by handle_lesson.  Lessons with their own inline assets are patched by
        // web/src/journey_apply.ch instead.  Both paths call the same functions.
        render_journey_markup(page)
        render_journey_css(page)
    }

    public func render_lesson_js(page : &mut HtmlPage) {
        #js {
            // ---- backend integration (no-ops in static mode) ----
            function __ul_ctx() {
                var parts = window.location.pathname.split('/').filter(function(p) { return p.length > 0; });
                if (parts.length >= 4) {
                    if (parts[0] === 'courses') {
                        if (parts[2] === 'lessons') {
                            return { course: parts[1], concept: parts[3] };
                        }
                    }
                }
                return null;
            }
            function __ul_token() {
                var t = '';
                try { t = localStorage.getItem('session_token') || ''; } catch (e) { t = ''; }
                return t;
            }
            function __ul_report_attempt(correct) {
                var ctx = __ul_ctx();
                if (!ctx) { return; }
                var t = __ul_token();
                if (!t) { return; }
                var rating = 'again';
                if (correct) { rating = 'good'; }
                var url = '/api/review/submit?concept_id=' + encodeURIComponent(ctx.concept) +
                    '&course_id=' + encodeURIComponent(ctx.course) + '&rating=' + rating;
                try { fetch(url, { method: 'POST', headers: { 'Authorization': 'Bearer ' + t } }).catch(function() {}); } catch (e) {}
            }
            // NOTE: the #js macro drops parentheses in plain-JS mode, so
            // `!(a && b)` would emit as `!a && b`. Parenthesised negation is
            // avoided here on purpose.
            document.addEventListener('click', function(ev) {
                var el = ev.target;
                while (el && el !== document) {
                    var isOption = el.classList && el.classList.contains('quiz-option');
                    if (isOption) { break; }
                    el = el.parentNode;
                }
                if (!el || el === document) { return; }
                setTimeout(function() { __ul_report_attempt(el.classList.contains('correct')); }, 80);
            }, true);
            document.addEventListener('change', function(ev) {
                var el = ev.target;
                if (!el || !el.classList) { return; }
                var isBlank = el.classList.contains('fill-blank');
                var isSelect = el.classList.contains('app-select');
                if (!isBlank && !isSelect) { return; }
                    var ans = el.getAttribute('data-answer');
                    if (!ans) { return; }
                    var val = '';
                    if (el.value) { val = el.value; }
                    var valLower = val.trim().toLowerCase();
                    var ansLower = ans.toLowerCase();
                    __ul_report_attempt(valLower === ansLower);
            }, true);

            // ---- quiz checking ----
            // Each option carries data-correct="true|false" and data-explain,
            // so every option (right or wrong) teaches something.
            function checkQuiz(quizId, btn) {
                var quiz = document.getElementById(quizId);
                if (!quiz) { return; }
                var options = quiz.querySelectorAll('.quiz-option');
                var feedback = quiz.querySelector('.quiz-feedback');
                for (var i = 0; i < options.length; i++) { options[i].disabled = true; }
                var correct = btn.getAttribute('data-correct') === 'true';
                var explain = btn.getAttribute('data-explain') || '';
                if (correct) {
                    btn.classList.add('correct');
                    if (feedback) {
                        feedback.textContent = 'Correct. ' + explain;
                        feedback.style.color = '#059669';
                    }
                } else {
                    btn.classList.add('wrong');
                    if (feedback) {
                        feedback.textContent = 'Not quite. ' + explain;
                        feedback.style.color = '#dc2626';
                    }
                }
            }

            // ---- fill in the blank ----
            // Answers are exact strings after trim, so blanks are designed to have
            // a single unambiguous form.
            function checkFillBlanks(scopeId) {
                var scope = document.getElementById(scopeId);
                if (!scope) { scope = document; }
                var blanks = scope.querySelectorAll('.fill-blank');
                var feedback = scope.querySelector('.fill-feedback');
                var allCorrect = true;
                for (var i = 0; i < blanks.length; i++) {
                    var el = blanks[i];
                    var answer = el.getAttribute('data-answer');
                    var val = el.value.trim();
                    // Case-insensitive so a correct answer typed in lower case
                    // (for example "nor" for NOR) is still accepted.
                    if (val.toLowerCase() === answer.toLowerCase()) {
                        el.classList.add('correct');
                        el.classList.remove('wrong');
                    } else {
                        el.classList.add('wrong');
                        el.classList.remove('correct');
                        allCorrect = false;
                    }
                }
                if (feedback) {
                    if (allCorrect) {
                        feedback.textContent = 'All correct.';
                        feedback.style.color = '#059669';
                    } else {
                        feedback.textContent = 'Some blanks are still off. Check them against the lesson above.';
                        feedback.style.color = '#dc2626';
                    }
                }
            }
        }
        render_exercise_js(page)
        render_exercise_build_js(page)
        render_journey_js(page)
    }

}
