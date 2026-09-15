// Concept Template: STANDARD lesson layout (P3 2.2.5)
// The canonical 8-unit teaching order used across Underlayer courses:
//   why -> model -> reality -> example -> interact -> retrieve -> apply -> connect
// Authors: copy this file, rename the render function, and fill in each unit.
// CSS/JS is intentionally self-contained so the copy needs nothing else.
// (page/html_cbi/css_cbi/js_cbi are imported at module level in chemical.mod.)

public namespace underlayer_content {

using std::string

using std::string_view

public func template_standard() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Concept Title — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson template-standard">
            <h1>Concept Title</h1>
            <div class="lesson-meta">15 min · Core concept · Module X of Y</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>What problem does this concept solve, and what breaks if you do not understand it?</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The simplified mental model a learner should hold. Mark simplifications as models.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>How reality differs from the model. Reference the authoritative spec here.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Every example must be verifiable — show real output, never invented bytes.</p>
                <div class="code-block"><pre>$ command showing real output</pre></div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Active use follows every concept — no passive reading.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Retrieval is not optional. Answer without looking back:</p>
                <div class="quiz" id="quiz-1">
                    <button class="quiz-option" data-correct="false" data-explain="Why this option is wrong." onclick="checkQuiz('quiz-1', this)">Wrong option</button>
                    <button class="quiz-option" data-correct="true" data-explain="Why this option is right." onclick="checkQuiz('quiz-1', this)">Correct option</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Use the concept on a slightly different task than the example.</p>
                <div class="quiz" id="quiz-2">
                    <button class="quiz-option" data-correct="true" data-explain="Why this option is right." onclick="checkQuiz('quiz-2', this)">Correct option</button>
                    <button class="quiz-option" data-correct="false" data-explain="Why this option is wrong." onclick="checkQuiz('quiz-2', this)">Wrong option</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>How this connects to what came before and what comes next.</p>
            </div>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; font-family: system-ui, -apple-system, sans-serif; line-height: 1.7; color: #111827; }
        .lesson-meta { color: #6b7280; font-size: 0.875rem; margin-bottom: 2rem; }
        .unit { margin-bottom: 2rem; padding: 1.5rem; border-radius: 8px; border-left: 4px solid; }
        .unit-why { border-color: #3b82f6; background: #eff6ff; }
        .unit-model { border-color: #059669; background: #ecfdf5; }
        .unit-reality { border-color: #d97706; background: #fffbeb; }
        .unit-example { border-color: #8b5cf6; background: #f5f3ff; }
        .unit-interact { border-color: #ec4899; background: #fdf2f8; }
        .unit-retrieve { border-color: #06b6d4; background: #ecfeff; }
        .unit-apply { border-color: #f97316; background: #fff7ed; }
        .unit-connect { border-color: #10b981; background: #ecfdf5; }
        h1 { font-size: 1.75rem; margin-bottom: 0.5rem; }
        h2 { font-size: 1.15rem; margin-bottom: 0.75rem; margin-top: 0; }
        p { margin: 0.5rem 0; }
        .code-block { background: #f5f5f5; padding: 1rem; border-radius: 6px; font-family: ui-monospace, monospace; font-size: 0.9rem; overflow-x: auto; }
        .code-block pre { margin: 0; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; font-size: 0.95rem; }
        .quiz-option:hover { border-color: #3b82f6; background: #eff6ff; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
        .quiz-option:disabled { cursor: default; }
        .quiz-feedback { margin-top: 0.75rem; font-size: 0.9rem; min-height: 1.5rem; }
    }

    #js {
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
