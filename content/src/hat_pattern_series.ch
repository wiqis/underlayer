// HAT course — Concept 18: Number and letter series.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_pattern_series() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Number and Letter Series — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Number and Letter Series</h1>
            <div class="lesson-meta">15 min · Module 4: Analytical Reasoning · Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Series questions give a short list of numbers or letters and ask for the next term. They look like a test of insight and are actually a test of method: there are perhaps ten common rules, and every question uses one of them or a combination.</p>
                <p>The time cost matters as much as the accuracy. A candidate who stares at a sequence hoping to recognise it can burn two minutes on a question worth one mark. A candidate with a checklist either finds the rule in twenty seconds or moves on.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Apply this checklist in order, and stop as soon as the rule becomes obvious.</p>
                <ol>
                    <li><strong>Write the differences</strong> between consecutive terms. If they are constant, the series is arithmetic.</li>
                    <li><strong>If the differences are not constant, write their differences too.</strong> A constant second difference means the terms follow a square-type pattern.</li>
                    <li><strong>If the terms grow very fast, look for a ratio.</strong> A constant ratio means geometric; increasing ratios suggest factorials or powers.</li>
                    <li><strong>If neither works, test the standard sets:</strong> perfect squares, cubes, primes, and the Fibonacci-style rule where each term is the sum of the previous two.</li>
                    <li><strong>Check for alternating patterns,</strong> where odd and even positions follow separate rules.</li>
                </ol>
                <p>The checklist is ordered by the likelihood of each rule, not by elegance, so following it in order is the fastest path in expectation.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>The rule families, with an example of each.</strong></p>
                <table>
                    <thead>
                        <tr><th scope="col">Rule</th><th scope="col">Series</th><th scope="col">Next term</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Constant difference</td><td>7, 11, 15, 19</td><td>23 (add 4)</td></tr>
                        <tr><td>Growing difference</td><td>2, 5, 10, 17, 26</td><td>37 (differences 3, 5, 7, 9, then 11)</td></tr>
                        <tr><td>Constant ratio</td><td>3, 6, 12, 24, 48</td><td>96 (multiply by 2)</td></tr>
                        <tr><td>Increasing ratio</td><td>1, 2, 6, 24, 120</td><td>720 (multiply by 2, 3, 4, 5, then 6)</td></tr>
                        <tr><td>Perfect squares</td><td>1, 4, 9, 16, 25</td><td>36 (1², 2², 3² ...)</td></tr>
                        <tr><td>Primes</td><td>2, 3, 5, 7, 11, 13</td><td>17</td></tr>
                        <tr><td>Sum of previous two</td><td>1, 1, 2, 3, 5, 8</td><td>13</td></tr>
                        <tr><td>Alternating rules</td><td>2, 10, 4, 20, 6</td><td>30 (odd positions add 2, even positions add 10)</td></tr>
                    </tbody>
                </table>
                <p><strong>A series can be a known sequence with a twist.</strong> The squares 1, 4, 9, 16, 25 become 2, 5, 10, 17, 26 when each is increased by one — and that second series is exactly the "growing difference" row above, which is why writing differences finds it quickly. Similarly, the primes appear shifted by one or embedded in a longer pattern.</p>
                <p><strong>Descents behave the same way.</strong> 100, 96, 88, 76 has differences of &minus;4, &minus;8, &minus;12, so the next difference is &minus;16 and the next term is 60. A series with growing negative differences is not harder than one with growing positive differences; it is the same rule seen from below.</p>
                <p><strong>Letter series are number series in disguise.</strong> Write the position of each letter in the alphabet and the sequence becomes numeric. B, D, G, K, P is 2, 4, 7, 11, 16, with differences of 2, 3, 4, 5, so the next difference is 6 and the next letter is the 22nd, which is V.</p>
                <p><strong>Letters can also move through the alphabet in blocks.</strong> AZ, BY, CX pairs each forward-step with a backward-step: the first letter moves forward by one while the second moves backward by one. When you see pairs, check the two positions separately rather than as a rigid pair.</p>
                <p><strong>Odd-one-out questions use the same knowledge backwards.</strong> Find the property that all but one of the options share. 4, 9, 16, 25, 36 and 50: all are perfect squares except 50. State the property before you state the odd one, or you will pick an option that is merely unusual.</p>
                <div class="callout callout-tip">
                    <strong>Do not test rules at random.</strong> If differences and ratios fail, the remaining candidates are squares, cubes, primes and Fibonacci — test those four in that order, mentally, and stop at the first that fits all the terms. A rule that fits four terms but not the fifth is not the rule.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>2, 5, 10, 17, 26, ?</em></p>
                <p>Write the differences: 3, 5, 7, 9. They are not constant, but they increase by two each time, so the difference sequence is itself arithmetic with a constant second difference. The next difference is 11, and 26 + 11 is <strong>37</strong>.</p>
                <p>Now notice the alternative view: the terms are 1² + 1, 2² + 1, 3² + 1, 4² + 1, 5² + 1. That is 2, 5, 10, 17, 26 exactly. The two descriptions are the same series, and the second explains why the first difference grows by two each time — a square pattern always produces odd differences.</p>
                <p>This is worth remembering as a shortcut rather than a coincidence. Whenever the differences are 3, 5, 7, 9 — consecutive odd numbers — the terms are squares with a constant added, and you can write the next term straight from the square formula without continuing the difference table.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What comes next: 100, 96, 88, 76, ?</p>
                    <button class="quiz-option" data-correct="true" data-explain="The differences are minus 4, minus 8 and minus 12, so the next difference is minus 16 and 76 minus 16 is 60." onclick="checkQuiz('quiz-1', this)">60</button>
                    <button class="quiz-option" data-correct="false" data-explain="64 would continue a constant difference of 4, but the differences are growing: 4, 8, 12." onclick="checkQuiz('quiz-1', this)">64</button>
                    <button class="quiz-option" data-correct="false" data-explain="72 ignores the pattern entirely; each step falls by more than the one before it." onclick="checkQuiz('quiz-1', this)">72</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>What comes next: B, D, G, K, P, ?</p>
                    <button class="quiz-option" data-correct="false" data-explain="R is the 18th letter. The steps are 2, 3, 4, 5, so the next step is 6 and P is the 16th letter." onclick="checkQuiz('quiz-2', this)">R</button>
                    <button class="quiz-option" data-correct="true" data-explain="The letters are positions 2, 4, 7, 11, 16 with steps 2, 3, 4, 5, so the next position is 22, which is V." onclick="checkQuiz('quiz-2', this)">V</button>
                    <button class="quiz-option" data-correct="false" data-explain="U is position 21. The step from P needs to be 6, not 5, because the steps are increasing." onclick="checkQuiz('quiz-2', this)">U</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Which is the odd one out: 4, 9, 16, 25, 36, 50?</p>
                    <button class="quiz-option" data-correct="false" data-explain="4 is 2 squared and belongs with the others." onclick="checkQuiz('quiz-3', this)">4</button>
                    <button class="quiz-option" data-correct="false" data-explain="36 is 6 squared and belongs with the others." onclick="checkQuiz('quiz-3', this)">36</button>
                    <button class="quiz-option" data-correct="true" data-explain="All the others are perfect squares; 50 is not. State the property first, then find the option that breaks it." onclick="checkQuiz('quiz-3', this)">50</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what do you do when the differences between terms are not constant, and what is the first thing to write for a letter series?</p>
                <p>The answer is: write the differences of the differences, testing for a constant second difference; and for a letter series, write each letter's alphabet position so it becomes a number series.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>A series whose terms increase by a constant amount is called <input type="text" class="fill-blank" data-answer="arithmetic" placeholder="?" aria-label="constant difference series" />, while one that multiplies by a constant is called <input type="text" class="fill-blank" data-answer="geometric" placeholder="?" aria-label="constant ratio series" />. In the alphabet, the letter B has position <input type="text" class="fill-blank" data-answer="2" placeholder="?" aria-label="position of B" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Write one series for each rule family on this page: constant difference, growing difference, constant ratio, squares, primes, and sum of the previous two. Then swap them with a friend, or return to them the next day, and solve them using only the checklist.</p>
                <details>
                    <summary>Three series to try, and the rule behind each</summary>
                    <p><em>3, 8, 15, 24, 35, ?</em> The differences are 5, 7, 9, 11 — consecutive odd numbers starting from 5, so the next is 13 and the answer is 48. These are the squares minus one.</p>
                    <p><em>2, 6, 12, 20, 30, ?</em> The differences are 4, 6, 8, 10, so the next is 12 and the answer is 42. These are consecutive products, or n² + n.</p>
                    <p><em>1, 3, 9, 27, ?</em> The ratio is a constant 3, so the answer is 81. This is the geometric case, and it should be caught at step three of the checklist before any difference table is written.</p>
                    <p>Writing these yourself is what converts the checklist from a list you remember into a habit you apply. Notice too that the first two both look unfamiliar until the differences are written down, and the third does not need differences at all — recognising which of the five steps to run, and in what order, is most of the skill.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>That completes the analytical question types. The drill that follows puts them together under a clock, because the analytical section rewards a fast, practised routine more than any other. After that, the course turns to the training programme that turns technique into a score: mock tests, the error log, targets and exam-day execution.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-data-interpretation">Previous: Tables, Charts and Graphs</a></span>
                <span><a href="/courses/hat/lessons/hat-analytical-drill">Next: Analytical Drill</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
