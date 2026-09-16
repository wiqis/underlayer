// Concept Template: EXERCISE-FOCUSED layout (P3 2.2.6)
// Retrieval-first ordering for concepts learners mostly practice, not read:
//   warm-up retrieve -> guided apply -> challenge -> explain -> mistakes recap
// Authors: copy this file, rename the render function, and fill in the exercises.
// (page/html_cbi/css_cbi/js_cbi are imported at module level in chemical.mod.)

public namespace underlayer_content {

using std::string

using std::string_view

public func template_exercise_focus() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Concept Title — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson template-exercise">
            <h1>Concept Title</h1>
            <div class="lesson-meta">10 min · Practice · Module X of Y</div>

            <div class="unit unit-retrieve">
                <h2>Warm-Up</h2>
                <p>A retrieval question on the prerequisite knowledge this concept builds on:</p>
                <div class="quiz" id="quiz-1">
                    <button class="quiz-option" data-correct="true" data-explain="Why this option is right." onclick="checkQuiz('quiz-1', this)">Correct option</button>
                    <button class="quiz-option" data-correct="false" data-explain="Why this option is wrong." onclick="checkQuiz('quiz-1', this)">Wrong option</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Guided Practice</h2>
                <p>The core exercise, with a hint if you need it:</p>
                <div class="quiz" id="quiz-2">
                    <button class="quiz-option" data-correct="false" data-explain="Why this option is wrong." onclick="checkQuiz('quiz-2', this)">Wrong option</button>
                    <button class="quiz-option" data-correct="true" data-explain="Why this option is right." onclick="checkQuiz('quiz-2', this)">Correct option</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-challenge">
                <h2>Challenge</h2>
                <p>A harder variation. This is supposed to be hard — struggle is normal:</p>
                <div class="quiz" id="quiz-3">
                    <button class="quiz-option" data-correct="true" data-explain="Why this option is right." onclick="checkQuiz('quiz-3', this)">Correct option</button>
                    <button class="quiz-option" data-correct="false" data-explain="Why this option is wrong." onclick="checkQuiz('quiz-3', this)">Wrong option</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Explain It Back</h2>
                <p>In your own words: what does this concept do, and what would break without it? If you can explain it, you own it.</p>
            </div>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; font-family: system-ui, -apple-system, sans-serif; line-height: 1.7; color: #111827; }
        .lesson-meta { color: #6b7280; font-size: 0.875rem; margin-bottom: 2rem; }
        .unit { margin-bottom: 2rem; padding: 1.5rem; border-radius: 8px; border-left: 4px solid; }
        .unit-retrieve { border-color: #06b6d4; background: #ecfeff; }
        .unit-apply { border-color: #f97316; background: #fff7ed; }
        .unit-challenge { border-color: #dc2626; background: #fef2f2; }
        .unit-connect { border-color: #10b981; background: #ecfdf5; }
        h1 { font-size: 1.75rem; margin-bottom: 0.5rem; }
        h2 { font-size: 1.15rem; margin-bottom: 0.75rem; margin-top: 0; }
        p { margin: 0.5rem 0; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; font-size: 0.95rem; }
        .quiz-option:hover { border-color: #3b82f6; background: #eff6ff; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
        .quiz-option:disabled { cursor: default; }
        .quiz-feedback { margin-top: 0.75rem; font-size: 0.9rem; min-height: 1.5rem; }
    }

    #js {
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
            var url = '/api/review/submit?concept_id=' + encodeURIComponent(ctx.concept) + '&course_id=' + encodeURIComponent(ctx.course) + '&rating=' + rating;
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
        document.addEventListener('click', function(ev) {
            var el = ev.target;
            while (el && el !== document && !(el.classList && el.classList.contains('quiz-option'))) { el = el.parentNode; }
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
            if (!ans) { ans = el.getAttribute('data-correct'); }
            if (!ans) { return; }
            var val = '';
            if (el.value) { val = el.value; }
            val = val.trim();
            __ul_report_attempt(val === ans);
        }, true);
        function checkQuiz(quizId, btn) {
            var quiz = document.getElementById(quizId);
            var options = quiz.querySelectorAll('.quiz-option');
            var feedback = quiz.querySelector('.quiz-feedback');
            for(var i = 0; i < options.length; i++) { options[i].disabled = true; }
            var correct = btn.getAttribute('data-correct') === 'true';
            var explain = btn.getAttribute('data-explain') || '';
            if(correct) {
                btn.classList.add('correct');
                feedback.textContent = 'Correct! ' + explain;
                feedback.style.color = '#059669';
            } else {
                btn.classList.add('wrong');
                feedback.textContent = 'Not quite. ' + explain;
                feedback.style.color = '#dc2626';
            }
        }
    }

    return page.toString()
}

}
