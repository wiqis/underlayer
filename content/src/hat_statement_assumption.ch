// HAT course — Statement and Assumption: finding the unstated premise a statement relies on.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_statement_assumption() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Statement and Assumption - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Statement and Assumption</h1>
            <div class="lesson-meta">15 min &middot; Module 4: Analytical Reasoning &middot; Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every statement a person makes rests on things they did not say. When a notice reads &ldquo;the canteen will close at noon on Friday&rdquo;, it assumes the canteen normally opens. The sentence would be pointless otherwise. An <strong>assumption</strong> is exactly this hidden support: a claim the speaker must be taking for granted for the statement to make sense.</p>
                <p>This question type tests whether you can see the scaffolding behind a sentence, and whether you can tell a genuine support from a conclusion, a piece of advice, or a plain restatement. Candidates who answer by opinion fail; the answer is decided by structure, not by what you believe.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of the statement as a table top and the assumption as the leg holding it up. Remove the leg and the table falls.</p>
                <div class="formula">statement + [assumption] &rarr; the statement can stand</div>
                <ul>
                    <li>An assumption is <strong>not stated</strong>. If it appears in the passage, it is not the assumption.</li>
                    <li>An assumption is <strong>needed</strong>. The statement depends on it being true.</li>
                    <li>An assumption is <strong>not a conclusion</strong>. A conclusion is what the statement tries to prove; an assumption is what it silently accepts.</li>
                </ul>
                <p>What this model omits: it does not tell you how strong or how likely an assumption is. A statement can rest on a weak assumption; the exam still credits it if the statement cannot stand without it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>The negation test.</strong> Take each option, imagine it false, and re-read the statement. If the statement stops making sense or becomes impossible, the option is an assumption. If the statement survives untouched, it is not.</p>
                <p>Suppose the statement is &ldquo;all applicants must submit the form before the deadline&rdquo;. Negate the option &ldquo;the deadline is known to applicants&rdquo;. If nobody knows the deadline, the instruction is useless, so the statement collapses. The option is a valid assumption.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Option kind</th><th scope="col">How to recognise it</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Assumption</td><td>Hidden, required, and its negation breaks the statement</td></tr>
                        <tr><td>Conclusion</td><td>Drawn out from the statement; follows rather than supports</td></tr>
                        <tr><td>Restatement</td><td>Repeats the statement in different words, adds nothing</td></tr>
                        <tr><td>Inference</td><td>May follow from the statement, but the statement does not need it</td></tr>
                        <tr><td>Overreach</td><td>Too broad or too strong; the statement can stand without it</td></tr>
                    </tbody>
                </table>
                <p><strong>Watch the wording.</strong> Words like <em>all</em>, <em>only</em>, <em>every</em> and <em>never</em> make an option too strong. A statement that says some trainees improved does not assume that all trainees can improve. The safe assumption is almost always the modest one.</p>
                <div class="callout callout-tip">
                    <strong>Nothing is assumed.</strong> Sometimes the correct answer is simply that none of the given options is assumed, because each one is either stated, unnecessary, or too strong. Do not force a match just because options exist.
                </div>
                <div class="callout callout-warn">
                    <strong>Do not confuse assumption with inference.</strong> An inference is what you can conclude from the statement. An assumption is what the statement presumes before it can even be uttered. The direction is opposite.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>Statement: &ldquo;Residents should not burn leaves in the open because the smoke worsens air quality in the colony.&rdquo;</em></p>
                <p>Candidate assumptions: (a) smoke from burning leaves affects air quality; (b) residents burn leaves; (c) burning leaves is the only cause of poor air quality.</p>
                <p>Option (a) is already stated in the words &ldquo;the smoke worsens air quality&rdquo;, so it cannot be a hidden assumption. Option (c) is too strong: the advice works even if other causes also exist. Option (b) is the assumption: the instruction about residents makes sense only if residents actually engage in the practice. Negate it — no resident burns leaves — and the advisory becomes pointless.</p>
                <p>The credited assumption is (b), the modest linking claim. Notice that the conclusion, that residents should stop burning leaves, is the advice the statement delivers, not the assumption behind it.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>How do you test whether an option is an assumption?</p>
                    <button class="quiz-option" data-correct="false" data-explain="How good the statement sounds has nothing to do with whether it depends on the option." onclick="checkQuiz('quiz-1', this)">Ask whether the statement sounds correct.</button>
                    <button class="quiz-option" data-correct="true" data-explain="Negate the option and re-read the statement. If it collapses, the option was assumed." onclick="checkQuiz('quiz-1', this)">Negate it and see whether the statement collapses.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Personal agreement is irrelevant; the test is structural." onclick="checkQuiz('quiz-1', this)">Ask whether you agree with the option.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Statement: &ldquo;Use the north gate; it is closer to the examination hall.&rdquo; Which is assumed?</p>
                    <button class="quiz-option" data-correct="false" data-explain="The statement tells you the gate is closer; calling it close is a restatement, not a hidden assumption." onclick="checkQuiz('quiz-2', this)">The north gate is close.</button>
                    <button class="quiz-option" data-correct="true" data-explain="The advice is only useful if the north gate can actually be used by those being addressed." onclick="checkQuiz('quiz-2', this)">The north gate is open and usable.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Locating the hall is helpful but not necessary; the advice still works if the distance alone matters." onclick="checkQuiz('quiz-2', this)">Everyone knows where the hall is.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Statement: &ldquo;Some students failed the mock test, so the teaching needs review.&rdquo; Which option is too strong to be an assumption?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This is a modest and reasonable reading of the words some students." onclick="checkQuiz('quiz-3', this)">At least one student failed.</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the linking assumption that connects failure to the need for review." onclick="checkQuiz('quiz-3', this)">Failure reflects the quality of teaching.</button>
                    <button class="quiz-option" data-correct="true" data-explain="The words all students go beyond the statement, which mentioned only some; the advice survives without it." onclick="checkQuiz('quiz-3', this)">All students find the teaching unclear.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>When can &ldquo;none of these is assumed&rdquo; be the correct answer?</p>
                    <button class="quiz-option" data-correct="true" data-explain="If every option is stated, unnecessary, or too strong, then nothing hidden is actually required." onclick="checkQuiz('quiz-4', this)">When every option is stated or too strong.</button>
                    <button class="quiz-option" data-correct="false" data-explain="A question always has a defensible answer, and this option is a legitimate one in some items." onclick="checkQuiz('quiz-4', this)">Never; an assumption always exists.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Difficulty is not a reason; the option must be genuinely unsupported, not merely hard." onclick="checkQuiz('quiz-4', this)">Only when the statement is confusing.</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what are the three signs of an assumption, and which words make an option too strong?</p>
                <p>The answer: it is hidden, required, and its negation breaks the statement; overly strong options usually contain words such as all, only, or never.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>An assumption is an <input type="text" class="fill-blank" data-answer="unstated" placeholder="?" aria-label="whether it is said" /> premise that the statement depends on. The standard test is to <input type="text" class="fill-blank" data-answer="negate" placeholder="?" aria-label="the test" /> the option and see whether the statement collapses. An inference is drawn from the statement, while an assumption is something the statement takes for <input type="text" class="fill-blank" data-answer="granted" placeholder="?" aria-label="what the statement does" /> beforehand.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Statement: &ldquo;The library must extend its weekend hours, because students have no quiet place to study on Sundays.&rdquo; Which of these is assumed: (1) the library is the only quiet study place; (2) students need a quiet place on Sundays; (3) the library can open on Sundays?</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Option (1) overreaches. The advice to extend hours still stands even if other quiet places exist; the statement never claims exclusivity. It is too strong, so it is not assumed.</p>
                    <p>Option (2) is close to a restatement. The statement says students have no quiet place on Sundays; that already says the need exists. A restatement is not a hidden assumption. Treat it as stated content rather than the credited assumption.</p>
                    <p>Option (3) survives the negation test. Negate it — the library cannot open on Sundays — and the recommendation becomes impossible to follow. The statement depends on the library being able to open, so this is the required assumption.</p>
                    <p>The pattern to carry forward: keep the modest linking option, drop the restatement and the absolute claim, and let the negation test decide.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Assumptions look backwards, at what a statement silently needs. The next lesson looks forwards, at what a set of statements forces you to accept, and how to separate a conclusion that must follow from one that merely might.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-critical-reasoning">Previous: Assumptions, Conclusions and Arguments</a></span>
                <span><a href="/courses/hat/lessons/hat-statement-conclusion">Next: Statement and Conclusion</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
