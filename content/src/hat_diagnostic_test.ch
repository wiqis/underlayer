// HAT course — Module 1: sitting a cold baseline diagnostic before studying.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_diagnostic_test() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Your Baseline Diagnostic: Start with Evidence - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Your Baseline Diagnostic: Start with Evidence</h1>
            <div class="lesson-meta">14 min &middot; Module 1: Know the Arena &middot; Planning</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Most candidates begin by revising whatever feels weakest. Feeling is a poor map: the topic that feels hard is often one you already score on, while marks leak silently from a section you consider easy. Guessing where to start wastes the first fortnight of an eight-week plan.</p>
                <p>A cold diagnostic replaces the guess with evidence. You sit one full paper before studying anything, score it by section, and let the numbers choose the plan. The first attempt is not a verdict on you; it is a measurement of where the marks currently are.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Treat preparation as three measurements joined by two work periods.</p>
                <div class="formula">diagnostic (cold) &rarr; targeted work &rarr; re-diagnostic (two weeks) &rarr; targeted work &rarr; full mock</div>
                <ul>
                    <li><strong>Cold</strong> means no revision beforehand and no help during. A warm diagnostic measures your notes, not your unaided memory.</li>
                    <li><strong>Sectional</strong> means three scores, not one total. The HAT-1 paper is weighted quantitative 40, verbal 30 and analytical 30, so a single total hides more than it reveals.</li>
                    <li><strong>Timed</strong> means the clock runs exactly as it will on the day: 100 multiple-choice questions in 120 minutes.</li>
                    <li><strong>Repeated</strong> means a second cold sitting after two weeks, so you can see whether the plan actually worked.</li>
                </ul>
                <p>The model omits two things. A single sitting is a noisy snapshot: one bad passage or one tired hour can move a section score by several marks. And it measures current performance, not potential, so a low first score is a starting point, never a ceiling.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>How to sit it</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Condition</th><th scope="col">Why it matters</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>One sitting, 120 minutes, no breaks</td><td>The paper is 100 questions in 120 minutes; sustained attention is part of what is measured</td></tr>
                        <tr><td>No calculator, no pausing, no notes</td><td>You are measuring the state you will actually bring on the day</td></tr>
                        <tr><td>Leave a question blank only if you never reached it</td><td>There is no negative marking, so a blank is a guaranteed zero, not a safe choice</td></tr>
                        <tr><td>Keep the marked answer sheet</td><td>You need right, wrong and blank per section, which a raw total cannot recover</td></tr>
                    </tbody>
                </table>
                <h3>How to score it</h3>
                <ol>
                    <li><strong>By section.</strong> Quantitative out of 40, verbal out of 30, analytical out of 30. Write three numbers, never one.</li>
                    <li><strong>By clock.</strong> Record the elapsed time when you finish question 25, 50, 75 and 100. These stamps locate where time is lost.</li>
                    <li><strong>By cause.</strong> For every miss, mark K if you did not know the rule, and T if you knew it but ran out of time or rushed.</li>
                    <li><strong>By blank.</strong> A blank forced by the clock is a time loss; a blank born of fear is a confidence loss, and the two need different repairs.</li>
                </ol>
                <div class="formula">section target = current correct + near-term recoverable losses</div>
                <p>Near-term recoverable means the time losses and the slips, not the genuine knowledge gaps, which take longer to close. Set the target from the result, not from a wish.</p>
                <div class="callout callout-tip">
                    <strong>The retest dates the work.</strong> Re-sit the same style of paper cold after two weeks. If the plan is working, the sectional scores move; if a section has not moved, the plan for that section is wrong, not the candidate.
                </div>
                <div class="callout callout-warn">
                    <strong>Do not study first.</strong> The most common error is to revise for a few days before the baseline, which destroys the baseline. The whole value of the diagnostic is that it is cold.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p>A candidate sits the diagnostic cold and scores quantitative 22/40, verbal 18/30 and analytical 14/30, with six analytical questions left blank. The clock stamps show question 75 reached only at 110 minutes, so most of the blanks sit in the analytical tail.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">Score</th><th scope="col">Diagnosis</th><th scope="col">Two-week target</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Quantitative</td><td>22/40</td><td>18 misses, spread evenly: knowledge and slips together</td><td>26/40</td></tr>
                        <tr><td>Verbal</td><td>18/30</td><td>12 misses, mostly vocabulary and grammar rules</td><td>23/30</td></tr>
                        <tr><td>Analytical</td><td>14/30</td><td>10 wrong plus 6 blanks, and the blanks are pure time loss</td><td>22/30</td></tr>
                    </tbody>
                </table>
                <p>The plan that follows from those numbers:</p>
                <ul>
                    <li><strong>Analytical first.</strong> Six blanks are the cheapest marks in the paper: no new knowledge is needed, only pacing. Drill one analytical set under a strict clock every second day.</li>
                    <li><strong>Verbal in short daily doses.</strong> Twelve misses are mostly rule-based, so thirty minutes of vocabulary and grammar daily beats one long weekly session.</li>
                    <li><strong>Quantitative held, then pushed.</strong> Fix the slips first with a units and magnitude check, then add the two or three missing rules.</li>
                </ul>
                <p>Two weeks later the re-diagnostic reads 26/40, 23/30 and 21/30. Every section moved, and the analytical gain came almost entirely from the recovered blanks.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Why sit the diagnostic cold, before studying anything?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Being fresh helps any test, but it is not the point: the point is that a diagnostic taken after revision measures your notes rather than your unaided ability." onclick="checkQuiz('quiz-1', this)">Because you always score better when rested</button>
                    <button class="quiz-option" data-correct="true" data-explain="A warm score reflects the pages you just read; only a cold score shows what you can retrieve with no help, which is what the plan must be built on." onclick="checkQuiz('quiz-1', this)">Because a warm score measures your notes, not your unaided memory</button>
                    <button class="quiz-option" data-correct="false" data-explain="Time saved is not the reason; the diagnostic exists to produce evidence, and studying first would contaminate the evidence." onclick="checkQuiz('quiz-1', this)">Because it saves revision time later</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>What is the value of recording the clock at questions 25, 50, 75 and 100?</p>
                    <button class="quiz-option" data-correct="false" data-explain="It is not a judgement about reading speed; it is a location tool, telling you where the clock stops being your ally." onclick="checkQuiz('quiz-2', this)">To prove you are a slow reader</button>
                    <button class="quiz-option" data-correct="true" data-explain="The four stamps show where time is lost, which is what separates a run-out-of-time blank from a genuine knowledge gap and points the repair in the right direction." onclick="checkQuiz('quiz-2', this)">To locate where time is lost and separate blanks from knowledge gaps</button>
                    <button class="quiz-option" data-correct="false" data-explain="The HAT awards no partial marks for pacing; the stamps are diagnostic data for you, not a score component." onclick="checkQuiz('quiz-2', this)">Because the HAT awards partial marks for steady pacing</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Six analytical questions were left blank. Which cause are they?</p>
                    <button class="quiz-option" data-correct="false" data-explain="A knowledge gap is a miss you attempted and could not do; a blank caused by the clock is a different failure with a much faster repair." onclick="checkQuiz('quiz-3', this)">Knowledge</button>
                    <button class="quiz-option" data-correct="true" data-explain="Blanks reached too late are a time loss, and because there is no negative marking they become the cheapest marks to recover through pacing practice." onclick="checkQuiz('quiz-3', this)">Time</button>
                    <button class="quiz-option" data-correct="false" data-explain="Guessing luck does not apply here, since the questions were never answered at all; the failure is the clock, not the choice." onclick="checkQuiz('quiz-3', this)">Luck</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>After two weeks of work you re-diagnose, and one section has not moved. What does this mean?</p>
                    <button class="quiz-option" data-correct="false" data-explain="A single noisy snapshot is not a ceiling; the score is evidence about the plan, and a stalled section usually means the plan was mismatched to the cause." onclick="checkQuiz('quiz-4', this)">You have reached your natural ceiling</button>
                    <button class="quiz-option" data-correct="true" data-explain="A section that does not move after targeted work means the training is aimed at the wrong cause or is too shallow; change the method for that section rather than the candidate." onclick="checkQuiz('quiz-4', this)">The training for that section is wrong and must change</button>
                    <button class="quiz-option" data-correct="false" data-explain="The first diagnostic is still valid evidence; re-diagnosing is exactly how you detect that a plan is not yet working." onclick="checkQuiz('quiz-4', this)">The first diagnostic was invalid</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: state the conditions that make a diagnostic valid and the four things you record when scoring it.</p>
                <p>The answer: cold, one sitting, 120 minutes, no calculator, no pausing; and you record sectional scores, clock stamps at 25/50/75/100, misses split into knowledge and time, and the blanks by cause.</p>
                <div id="fill-1">
                    <p>The HAT has <input type="text" class="fill-blank" data-answer="100" placeholder="?" aria-label="number of questions" /> multiple-choice questions in <input type="text" class="fill-blank" data-answer="120" placeholder="?" aria-label="minutes allowed" /> minutes, so the average budget is <input type="text" class="fill-blank" data-answer="72" placeholder="?" aria-label="seconds per question" /> seconds per question. Because there is no negative marking, every question should be <input type="text" class="fill-blank" data-answer="answered" placeholder="?" aria-label="what to do with every question" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You have just finished your own cold diagnostic. Write down the three sectional scores, the clock stamps at questions 25, 50, 75 and 100, and the split of your misses into knowledge and time. Then choose one section and set a two-week target.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Start with the sectional scores, because a single total hides the shape of the problem. Suppose they come back quantitative 24/40, verbal 20/30 and analytical 12/30, with the clock stamps showing question 75 reached only at 115 minutes.</p>
                    <p>The stamps say the analytical tail is where the loss is concentrated. Count the blanks there: if four analytical questions were never reached, those four are time losses, not knowledge gaps, and they are the first target because the HAT has no negative marking and pacing is trainable within days.</p>
                    <p>Set the target from the recoverable part: analytical near-term recoverable is the blanks plus the slips, so a target of 12 to 19 or 20 is honest, while a target of 30 in two weeks is a wish. Do the same arithmetic for the other two sections, then write the plan as one line per section with the method attached: pacing drills for the time loss, short daily rule sessions for the knowledge gaps, and a slip check for the careless misses.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now hold evidence instead of a guess. The next lesson turns that evidence into a calendar: how to weight your hours to the sections that pay, and how to sequence the eight weeks so each block earns the next. See <a href="/courses/hat/lessons/hat-study-plan">The Eight-Week Program</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-weightage-strategy">Previous: Weightage and Study Strategy</a></span>
                <span><a href="/courses/hat/lessons/hat-study-plan">Next: The Eight-Week Program</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
