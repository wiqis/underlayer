// Shared lesson CSS + JS for 8-unit concept pages.
//
// Every concept page (HAT, PE, ...) emits its own 8-unit markup and then calls
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

    public func render_lesson_css(page : &mut HtmlPage) {
        #css {
            body { font-family: system-ui, -apple-system, sans-serif; line-height: 1.7; margin: 0; color: #111827; background: #ffffff; }
            .lesson { max-width: 820px; margin: 0 auto; padding: 2rem; }
            .lesson-meta { color: #6b7280; font-size: 0.875rem; margin-bottom: 2rem; }
            .lesson h1 { font-size: 1.75rem; margin-bottom: 0.5rem; }
            .unit { margin-bottom: 2rem; padding: 1.5rem; border-radius: 8px; border-left: 4px solid; }
            .unit-why { border-color: #3b82f6; background: #eff6ff; }
            .unit-model { border-color: #059669; background: #ecfdf5; }
            .unit-reality { border-color: #d97706; background: #fffbeb; }
            .unit-example { border-color: #8b5cf6; background: #f5f3ff; }
            .unit-interact { border-color: #ec4899; background: #fdf2f8; }
            .unit-retrieve { border-color: #06b6d4; background: #ecfeff; }
            .unit-apply { border-color: #f97316; background: #fff7ed; }
            .unit-connect { border-color: #10b981; background: #ecfdf5; }
            .unit h2 { font-size: 1.15rem; margin: 0 0 0.75rem 0; }
            .unit p { margin: 0.5rem 0; }
            .unit ul, .unit ol { margin: 0.5rem 0; padding-left: 1.4rem; }
            .unit li { margin: 0.25rem 0; }
            .lesson code { background: #f3f4f6; padding: 0.15rem 0.4rem; border-radius: 4px; font-family: ui-monospace, monospace; font-size: 0.9em; }
            .lesson pre { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: ui-monospace, monospace; overflow-x: auto; white-space: pre; margin: 1rem 0; }
            .lesson table { width: 100%; border-collapse: collapse; margin: 1rem 0; font-size: 0.95rem; }
            .lesson th, .lesson td { padding: 0.5rem; border: 1px solid #d1d5db; text-align: left; }
            .lesson th { background: #f9fafb; font-weight: 600; }
            .callout { padding: 0.75rem 1rem; margin: 0.75rem 0; border-radius: 6px; font-size: 0.95rem; }
            .callout-tip { background: #eff6ff; border-left: 3px solid #3b82f6; }
            .callout-warn { background: #fffbeb; border-left: 3px solid #d97706; }
            .formula { background: #ffffff; border: 1px dashed #9ca3af; border-radius: 6px; padding: 0.6rem 0.9rem; margin: 0.75rem 0; font-family: ui-monospace, monospace; font-size: 0.95rem; }
            .quiz { margin-top: 1rem; }
            .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: #ffffff; cursor: pointer; text-align: left; font-size: 0.95rem; color: #111827; }
            .quiz-option:hover:not(:disabled) { border-color: #3b82f6; background: #eff6ff; }
            .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
            .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
            .quiz-option:disabled { cursor: default; }
            .quiz-feedback { margin-top: 0.75rem; font-size: 0.9rem; min-height: 1.25rem; }
            .fill-blank { padding: 0.4rem 0.6rem; border: 1px solid #d1d5db; border-radius: 4px; width: 7rem; font-family: ui-monospace, monospace; font-size: 0.95rem; margin: 0 0.25rem; }
            .fill-blank:focus { outline: 2px solid #3b82f6; outline-offset: 1px; }
            .fill-blank.correct { border-color: #059669; background: #ecfdf5; }
            .fill-blank.wrong { border-color: #dc2626; background: #fef2f2; }
            .fill-check-btn { margin-top: 0.75rem; padding: 0.5rem 1rem; border: 1px solid #d1d5db; border-radius: 6px; background: #ffffff; cursor: pointer; font-size: 0.9rem; color: #111827; }
            .fill-check-btn:hover { background: #f9fafb; border-color: #3b82f6; }
            .fill-feedback { margin-top: 0.5rem; font-size: 0.9rem; }
            .lesson details { margin: 0.75rem 0; background: #ffffff; border: 1px solid #e5e7eb; border-radius: 6px; padding: 0.6rem 0.9rem; }
            .lesson summary { cursor: pointer; font-weight: 600; font-size: 0.95rem; }
            .lesson-footer { display: flex; justify-content: space-between; gap: 1rem; margin-top: 2.5rem; padding-top: 1.25rem; border-top: 1px solid #e5e7eb; font-size: 0.9rem; }
            .lesson-footer a { color: #2563eb; text-decoration: none; }
            .lesson-footer a:hover { text-decoration: underline; }
            .back-link { display: inline-block; margin-bottom: 1rem; color: #2563eb; text-decoration: none; font-size: 0.9rem; }
            .back-link:hover { text-decoration: underline; }
            .course-description { font-size: 1.05rem; color: #4b5563; margin: 0.5rem 0; }
            .module-list { display: flex; flex-direction: column; gap: 1.5rem; margin-top: 1.5rem; }
            .module-list .unit { margin-bottom: 0; }
            .concept-list { list-style: none; padding: 0; margin: 0.5rem 0 0 0; }
            .concept-list li { padding: 0.4rem 0; border-bottom: 1px solid #e5e7eb; }
            .concept-list li:last-child { border-bottom: none; }
            .concept-list a { color: #2563eb; text-decoration: none; }
            .concept-list a:hover { text-decoration: underline; }
            @media (max-width: 640px) {
                .lesson { padding: 1rem; }
                .unit { padding: 1rem; }
                .lesson table { font-size: 0.85rem; }
                .lesson-footer { flex-direction: column; }
            }
        }
        render_exercise_css(page)
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
            function __ul_report_view() {
                var ctx = __ul_ctx();
                if (!ctx) { return; }
                var t = __ul_token();
                if (!t) { return; }
                try {
                    fetch('/api/learning/view', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + t },
                        body: JSON.stringify({ course_id: ctx.course, concept_id: ctx.concept })
                    }).catch(function() {});
                } catch (e) {}
            }
            document.addEventListener('DOMContentLoaded', function() { __ul_report_view(); });
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
    }

}
