// Concept Template: VISUALIZATION layout (P3 2.2.7)
// For concepts best taught through one central interactive visual:
//   intro -> full-width visualization -> guided read -> retrieve -> connect
// Authors: copy this file, rename the render function, and replace the viz block.
// (page/html_cbi/css_cbi/js_cbi are imported at module level in chemical.mod.)

public namespace underlayer_content {

using std::string

using std::string_view

public func template_visualization() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Concept Title — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson template-visual">
            <h1>Concept Title</h1>
            <div class="lesson-meta">15 min · Visual · Module X of Y</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>One paragraph: the problem this structure solves.</p>
            </div>

            <div class="viz-wrap" id="viz">
                <div class="viz-controls">
                    <button class="viz-btn" onclick="vizStep(-1)">◀ Back</button>
                    <button class="viz-btn" onclick="vizStep(1)">Next ▶</button>
                    <span class="viz-caption" id="viz-caption">Step 1 of 3</span>
                </div>
                <div class="viz-stage" id="viz-stage">Visualization goes here — one idea per step.</div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Answer without scrolling back:</p>
                <div class="quiz" id="quiz-1">
                    <button class="quiz-option" data-correct="true" data-explain="Why this option is right." onclick="checkQuiz('quiz-1', this)">Correct option</button>
                    <button class="quiz-option" data-correct="false" data-explain="Why this option is wrong." onclick="checkQuiz('quiz-1', this)">Wrong option</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Link the visual you just explored to the next concept.</p>
            </div>
        </div>
    }

    #css {
        .lesson { max-width: 960px; margin: 0 auto; padding: 2rem; font-family: system-ui, -apple-system, sans-serif; line-height: 1.7; color: #111827; }
        .lesson-meta { color: #6b7280; font-size: 0.875rem; margin-bottom: 2rem; }
        .unit { margin-bottom: 2rem; padding: 1.5rem; border-radius: 8px; border-left: 4px solid; }
        .unit-why { border-color: #3b82f6; background: #eff6ff; }
        .unit-retrieve { border-color: #06b6d4; background: #ecfeff; }
        .unit-connect { border-color: #10b981; background: #ecfdf5; }
        h1 { font-size: 1.75rem; margin-bottom: 0.5rem; }
        h2 { font-size: 1.15rem; margin-bottom: 0.75rem; margin-top: 0; }
        p { margin: 0.5rem 0; }
        .viz-wrap { margin: 0 auto 2rem auto; max-width: 900px; background: #1e1e1e; color: #d4d4d4; border-radius: 10px; padding: 1.25rem; }
        .viz-controls { display: flex; align-items: center; gap: 0.75rem; margin-bottom: 1rem; }
        .viz-btn { background: #374151; color: #d4d4d4; border: none; border-radius: 6px; padding: 0.4rem 0.9rem; cursor: pointer; font-size: 0.85rem; }
        .viz-btn:hover { background: #4b5563; }
        .viz-caption { font-size: 0.85rem; color: #9ca3af; }
        .viz-stage { min-height: 160px; font-family: ui-monospace, monospace; background: #111827; border-radius: 6px; padding: 1rem; overflow-x: auto; }
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
        var vizSteps = ['Step 1 content', 'Step 2 content', 'Step 3 content'];
        var vizIndex = 0;
        function vizRender() {
            var stage = document.getElementById('viz-stage');
            var caption = document.getElementById('viz-caption');
            if (stage) stage.textContent = vizSteps[vizIndex];
            if (caption) caption.textContent = 'Step ' + (vizIndex + 1) + ' of ' + vizSteps.length;
        }
        function vizStep(delta) {
            vizIndex = (vizIndex + delta + vizSteps.length) % vizSteps.length;
            vizRender();
        }
        vizRender();

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
