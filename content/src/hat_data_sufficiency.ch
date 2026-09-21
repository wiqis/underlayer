// HAT course — Data sufficiency: is the information enough to answer?
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_data_sufficiency() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Is the Information Enough? — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Is the Information Enough? Data Sufficiency</h1>
            <div class="lesson-meta">14 min · Module 4: Analytical Reasoning · Reasoning about data</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Because the HAT is aligned with the GRE family of tests, one of the most valuable habits it rewards is deciding whether a question <em>can</em> be answered at all. "Cannot be determined" is a real option, and it is the correct one whenever two different situations both satisfy everything you were told but give different answers.</p>
                <p>The habit pays twice. It wins the data-sufficiency items directly, and it protects you from inventing information in ordinary questions — assuming a rate is constant, assuming a total is 100, assuming a figure is drawn to scale.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Ask: <strong>do the facts pin down exactly one answer?</strong> If two different answers are compatible with everything stated, the data is insufficient.</p>
                <div class="formula">sufficient &harr; every situation consistent with the data gives the same answer</div>
                <p>The test for sufficiency is the <em>two-number test</em>: try a simple value, then try a second, deliberately awkward value (zero, one, a negative, a fraction, or a very large number). If both fit the statements but give different answers, the data is insufficient — and you have proved it, rather than suspected it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>If your paper uses the statements format</h3>
                <p>Data-sufficiency items give a question followed by two statements, marked (1) and (2), and five fixed answer choices:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Choice</th><th scope="col">Meaning</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>A</td><td>Statement (1) alone is sufficient, but (2) alone is not</td></tr>
                        <tr><td>B</td><td>Statement (2) alone is sufficient, but (1) alone is not</td></tr>
                        <tr><td>C</td><td>Both statements together are sufficient, but neither alone is</td></tr>
                        <tr><td>D</td><td>Each statement alone is sufficient</td></tr>
                        <tr><td>E</td><td>Neither statement, even together, is sufficient</td></tr>
                    </tbody>
                </table>
                <p>Three rules of procedure make this format mechanical:</p>
                <ol>
                    <li><strong>Evaluate (1) in isolation.</strong> Cover statement (2) with your hand. Using (2) while judging (1) is the single most common error, and it turns a correct option into a wrong one.</li>
                    <li><strong>Then evaluate (2) in isolation.</strong> Cover (1) in the same way.</li>
                    <li><strong>Only then combine them.</strong> If neither alone worked but together they do, the answer is C.</li>
                </ol>
                <h3>Patterns that almost always mean "insufficient"</h3>
                <ul>
                    <li><strong>More unknowns than equations.</strong> One equation with two variables does not determine either variable.</li>
                    <li><strong>Percentages without a base.</strong> "Prices rose 20% and then fell 20%" does not determine the final price unless you know the starting price.</li>
                    <li><strong>Averages without counts.</strong> An average tells you a total only when you know how many values there are.</li>
                    <li><strong>Ratios without a total.</strong> "The ratio of boys to girls is 3 to 2" fixes no counts; the class could be 5, 50 or 500.</li>
                    <li><strong>One constraint, several integers.</strong> "n is a prime number greater than 10" leaves many possibilities; if the question asks which, the data is insufficient.</li>
                    <li><strong>Diagrams not drawn to scale.</strong> Never infer a length or angle from the picture.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>Sufficiency is about the answer, not the value.</strong> If a question asks "is n even?", a statement that n is a multiple of 6 is sufficient even though it does not tell you what n is. Answer the question that was asked.
                </div>
                <div class="callout callout-warn">
                    <strong>Never use outside assumptions.</strong> If a question says a shop sells pens at a constant price and gives no price, the price is unknown — even though every shop has one. Only stated facts and mathematical consequences of them count.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. What is the value of x? (1) x + y = 10 (2) y = 4</h3>
                <p>Statement (1) alone gives a relationship but not a value: x could be 6 or 100, depending on y. Statement (2) alone says nothing about x. Together they give x = 6, so the answer is <strong>C</strong>.</p>
                <h3>2. How many students are in the class? (1) The average mark is 60. (2) The sum of all marks is 1,200.</h3>
                <p>(1) alone gives an average with no count. (2) alone gives a total with no average. Together, count = total &divide; average = 1,200 &divide; 60 = 20. The answer is <strong>C</strong>. This pair is worth memorising as the classic example of two facts that are useless separately and sufficient together.</p>
                <h3>3. Is n even? (1) n is a multiple of 6. (2) n is greater than 10.</h3>
                <p>(1) alone is sufficient: every multiple of 6 is even, so the answer is yes whatever n is. (2) alone is not: 11 and 12 are both greater than 10 and have different parity. Since (1) alone suffices and (2) does not, the answer is <strong>A</strong>.</p>
                <h3>4. In an ordinary multiple-choice question: "A and B are consecutive positive integers. What is A?"</h3>
                <p>Two situations fit — A = 1 with B = 2, and A = 2 with B = 3 — and they give different answers. The correct choice is <strong>cannot be determined</strong>. Notice how the two-number test settled it in five seconds.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What is the value of x? (1) x + y = 10 (2) y = 4</p>
                    <button class="quiz-option" data-correct="false" data-explain="(1) alone leaves x dependent on y, which is unknown, so it is insufficient on its own." onclick="checkQuiz('quiz-1', this)">(1) alone is sufficient</button>
                    <button class="quiz-option" data-correct="false" data-explain="(2) alone says nothing about x at all, so it cannot be sufficient." onclick="checkQuiz('quiz-1', this)">(2) alone is sufficient</button>
                    <button class="quiz-option" data-correct="true" data-explain="Together they give x = 6, and neither statement alone determines x, so the answer is both together." onclick="checkQuiz('quiz-1', this)">Both together are sufficient, neither alone</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>How many students are in the class? (1) The average mark is 60. (2) The sum of all marks is 1,200.</p>
                    <button class="quiz-option" data-correct="false" data-explain="An average without a count determines nothing; you cannot recover a count from 60 alone." onclick="checkQuiz('quiz-2', this)">(1) alone is sufficient</button>
                    <button class="quiz-option" data-correct="false" data-explain="A total without an average determines nothing either; 1,200 marks could belong to 3 students or 300." onclick="checkQuiz('quiz-2', this)">(2) alone is sufficient</button>
                    <button class="quiz-option" data-correct="true" data-explain="Count = total &divide; average = 1,200 &divide; 60 = 20, so both statements together are sufficient." onclick="checkQuiz('quiz-2', this)">Both together are sufficient, neither alone</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Is n an even number? (1) n is a multiple of 6. (2) n is greater than 10.</p>
                    <button class="quiz-option" data-correct="true" data-explain="Every multiple of 6 is even, so (1) alone answers the question; (2) alone cannot, since 11 and 12 differ in parity." onclick="checkQuiz('quiz-3', this)">(1) alone is sufficient, (2) is not</button>
                    <button class="quiz-option" data-correct="false" data-explain="Being greater than 10 says nothing about parity: 11 is odd and 12 is even." onclick="checkQuiz('quiz-3', this)">(2) alone is sufficient, (1) is not</button>
                    <button class="quiz-option" data-correct="false" data-explain="Neither is needed together; statement (1) already settles the parity question." onclick="checkQuiz('quiz-3', this)">Both together are needed</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>When you assess whether statement (1) is sufficient, what may you use?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Using (2) while judging (1) is the classic error: it can make an insufficient statement look sufficient." onclick="checkQuiz('quiz-4', this)">Both statements together</button>
                    <button class="quiz-option" data-correct="true" data-explain="Each statement is judged alone, with the other covered; only after both are assessed do you test them together." onclick="checkQuiz('quiz-4', this)">Statement (1) only, with (2) covered</button>
                    <button class="quiz-option" data-correct="false" data-explain="Real-world background assumptions are never permitted; only the stated facts and their mathematical consequences count." onclick="checkQuiz('quiz-4', this)">Statement (1) plus general knowledge about the situation</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what is the two-number test, and which single pattern almost always signals insufficient information?</p>
                <p>The answer: try two different values that both fit the facts and see whether the answers differ; and an average without a count (or a ratio without a total) is almost always insufficient.</p>
                <div id="fill-1">
                    <p>Data is sufficient when every situation consistent with it gives the <input type="text" class="fill-blank" data-answer="same" placeholder="?" aria-label="whether answers agree" /> answer. The <input type="text" class="fill-blank" data-answer="two-number" placeholder="?" aria-label="the test name" /> test tries two values that both fit and checks whether the answers differ. An average without a <input type="text" class="fill-blank" data-answer="count" placeholder="?" aria-label="missing element for averages" /> determines no total, and when assessing a statement you judge it <input type="text" class="fill-blank" data-answer="alone" placeholder="?" aria-label="how each statement is judged" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Decide whether each question can be answered from what is given: (1) "A rectangle has a perimeter of 20. What is its area?" (2) "A rectangle has an area of 24. What is its perimeter?" (3) "A square has a perimeter of 20. What is its area?"</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>(1) Cannot be determined. Perimeter 20 means length + width = 10, and that admits 6 by 4 (area 24), 9 by 1 (area 9) and 5 by 5 when it is a square (area 25). The two-number test finds different areas for the same perimeter.</p>
                    <p>(2) Cannot be determined either: area 24 admits 6 by 4 (perimeter 20), 12 by 2 (perimeter 28) and 8 by 3 (perimeter 22). Again, different answers from the same fact.</p>
                    <p>(3) Determined. A square with perimeter 20 has side 5, so its area is 25 — one answer only, because the word "square" removes the freedom the earlier questions had.</p>
                    <p>The lesson generalises: your job in these questions is not to compute but to establish whether the constraints leave any freedom. When the wording removes the freedom, the data becomes sufficient, and often the computation is trivial.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>That completes the analytical families. The next lesson is a timed set that mixes them, exactly as the paper does, so that recognition — not just technique — gets trained under a clock.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-coding-decoding">Previous: Coding and Decoding</a></span>
                <span><a href="/courses/hat/lessons/hat-data-interpretation">Next: Tables, Charts and Graphs</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
