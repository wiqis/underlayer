// HAT course — Translating word problems into equations.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_word_problems() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Translating Word Problems — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Translating Word Problems</h1>
            <div class="lesson-meta">16 min &middot; Module 2: Quantitative Reasoning &middot; Core technique</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Most marks lost in quantitative reasoning are not lost to arithmetic. They are lost before the arithmetic begins, while the question is still a sentence. A number increased by thirty percent of itself equals 91 is one line of algebra once it is written down, and a trap while it is still English.</p>
                <p>Translation is a skill with rules, and the rules are learnable. Apply them mechanically and a word problem stops being a test of reading and becomes a test of substitution.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Treat every word problem as three fixed steps.</p>
                <ul>
                    <li><strong>Name the unknown.</strong> Write let x be the number, or let c be the cost. A named unknown turns prose into symbols.</li>
                    <li><strong>Translate phrase by phrase.</strong> Each English keyword maps to one symbol: is to equals, of to multiply, per to divide, more than to plus, less than to minus.</li>
                    <li><strong>Solve, then back-substitute.</strong> Put the answer back into the original sentence and check that it now says something true.</li>
                </ul>
                <div class="formula">translate first, solve second &middot; never solve while still reading</div>
                <p>The model omits two things you must supply. It assumes every quantity is in the same unit, and it assumes a single unknown; when a question has two, one unknown is expressed in terms of the other.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>The keyword table.</strong> Learn it until reading a sentence produces symbols automatically.</p>
                <table>
                    <thead>
                        <tr><th scope="col">English</th><th scope="col">Symbol</th><th scope="col">Example</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>is, equals, was</td><td>=</td><td>x is 12 gives x = 12</td></tr>
                        <tr><td>of</td><td>&times;</td><td>30 percent of x gives 0.30 &times; x</td></tr>
                        <tr><td>per, for each</td><td>&divide;</td><td>km per hour gives km &divide; hours</td></tr>
                        <tr><td>more than, increased by</td><td>+</td><td>5 more than x gives x + 5</td></tr>
                        <tr><td>less than, decreased by</td><td>&minus;</td><td>5 less than x gives x &minus; 5</td></tr>
                        <tr><td>sum, total, together</td><td>+</td><td>the sum of x and y gives x + y</td></tr>
                        <tr><td>product, times</td><td>&times;</td><td>3 times x gives 3x</td></tr>
                        <tr><td>quotient, ratio, split</td><td>&divide;</td><td>the quotient of x and 3 gives x &divide; 3</td></tr>
                    </tbody>
                </table>
                <p><strong>Percentages are multipliers.</strong> The word of is the reason. Thirty percent of itself means 0.30 times the number, so a number increased by thirty percent of itself becomes x + 0.30x, which is 1.30x. Translating the phrase directly is faster and safer than reasoning about it.</p>
                <p><strong>Unit consistency.</strong> If a rate is per hour and a time is in minutes, convert one before writing the equation. A mismatch here produces a wrong answer that still looks internally consistent.</p>
                <p><strong>Back-substitution.</strong> Every word problem is self-checking. Put the value you found back into the words and verify. In the example below, 70 increased by 30 percent of 70 is 70 + 21 = 91, exactly as stated.</p>
                <div class="callout callout-tip">
                    <strong>The one-line test:</strong> after translating, read your equation back into English. If it does not match the sentence, the equation is wrong, no matter how clean the later algebra looks.
                </div>
                <div class="callout callout-warn">
                    <strong>Less than reverses.</strong> Five less than x is x minus 5, not 5 minus x. The phrase names the number that is reduced, not the number being removed, and this reversal is the single most common translation error.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>A number increased by 30 percent of itself equals 91. Find the number.</em></p>
                <p>Name the unknown: let the number be x. Translate: increased by 30 percent of itself is x + 0.30x. Equals 91 sets the whole thing to 91.</p>
                <div class="formula">x + 0.30x = 91 &nbsp; &rarr; &nbsp; 1.30x = 91 &nbsp; &rarr; &nbsp; x = 91 &divide; 1.30 = 70</div>
                <p>Back-substitute: 30 percent of 70 is 21, and 70 + 21 = 91. The sentence is satisfied, so the number is <strong>70</strong>.</p>
                <p>Notice where the difficulty actually sat. The equation 1.30x = 91 is trivial; the work was recognising that 30 percent of itself is a multiplier applied to x, not an amount added afterwards.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>A number increased by 30 percent of itself equals 91. Find the number.</p>
                    <button class="quiz-option" data-correct="true" data-explain="x + 0.30x = 1.30x = 91, so x = 91 divided by 1.30 = 70. Check: 70 + 21 = 91." onclick="checkQuiz('quiz-1', this)">70</button>
                    <button class="quiz-option" data-correct="false" data-explain="64 comes from subtracting 30 percent of 91 (about 27), which treats 91 as the starting value instead of the increased one." onclick="checkQuiz('quiz-1', this)">64</button>
                    <button class="quiz-option" data-correct="false" data-explain="121 adds 30 as a fixed amount rather than 30 percent of the unknown number." onclick="checkQuiz('quiz-1', this)">121</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Which expression means seven less than three times a number?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This reverses the subtraction: the phrase reduces three times the number, so the unknown part comes first." onclick="checkQuiz('quiz-2', this)">7 &minus; 3x</button>
                    <button class="quiz-option" data-correct="true" data-explain="Three times the number is 3x, and removing 7 from it gives 3x minus 7." onclick="checkQuiz('quiz-2', this)">3x &minus; 7</button>
                    <button class="quiz-option" data-correct="false" data-explain="This subtracts 7 from the number before tripling it, which changes the value entirely." onclick="checkQuiz('quiz-2', this)">3(x &minus; 7)</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>The sum of two consecutive integers is 37. What is the smaller integer?</p>
                    <button class="quiz-option" data-correct="false" data-explain="17 would make the pair 17 and 18, whose sum is only 35." onclick="checkQuiz('quiz-3', this)">17</button>
                    <button class="quiz-option" data-correct="true" data-explain="Let the smaller be x, so the larger is x + 1. Then 2x + 1 = 37, giving x = 18." onclick="checkQuiz('quiz-3', this)">18</button>
                    <button class="quiz-option" data-correct="false" data-explain="19 is the larger of the pair, not the smaller one the question asks for." onclick="checkQuiz('quiz-3', this)">19</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>A car covers 180 km in 3 hours. What is its average speed in km per hour?</p>
                    <button class="quiz-option" data-correct="false" data-explain="540 multiplies the distance by the time, but the word per calls for division." onclick="checkQuiz('quiz-4', this)">540</button>
                    <button class="quiz-option" data-correct="true" data-explain="Per means divide, so the speed is 180 divided by 3 = 60 km per hour." onclick="checkQuiz('quiz-4', this)">60</button>
                    <button class="quiz-option" data-correct="false" data-explain="183 adds the numbers instead of dividing distance by time." onclick="checkQuiz('quiz-4', this)">183</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what does is translate to, what does of translate to, and what does per translate to?</p>
                <p>The answers: is becomes equals, of becomes multiply, and per becomes divide.</p>
                <div id="fill-1">
                    <p>In translation, is becomes <input type="text" class="fill-blank" data-answer="equals" placeholder="?" aria-label="meaning of is" />, of becomes <input type="text" class="fill-blank" data-answer="multiply" placeholder="?" aria-label="meaning of of" />, and per becomes <input type="text" class="fill-blank" data-answer="divide" placeholder="?" aria-label="meaning of per" />. In the worked example, the unknown number is <input type="text" class="fill-blank" data-answer="70" placeholder="?" aria-label="worked example answer" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A number is doubled and then 6 is added. The result equals 4 less than three times the number. Find the number.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Name the unknown x. Doubled and then 6 is added is 2x + 6. Four less than three times the number is 3x &minus; 4, because the phrase reduces three times the number.</p>
                    <div class="formula">2x + 6 = 3x &minus; 4 &nbsp; &rarr; &nbsp; 6 + 4 = 3x &minus; 2x &nbsp; &rarr; &nbsp; x = 10</div>
                    <p>Back-substitute: 2(10) + 6 = 26, and 3(10) &minus; 4 = 26. The two sides agree, so the number is <strong>10</strong>.</p>
                    <p>The two traps are both translation errors. Four less than reverses, so it is 3x &minus; 4 rather than 4 &minus; 3x; and then 6 is added means the addition happens after the doubling, giving 2x + 6 rather than 2(x + 6).</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You can now turn a sentence into an equation. The next lesson applies that skill to the most common commercial setting in the test: buying, marking up, discounting and selling, where the same percentage machinery reappears under the vocabulary of profit, loss and discount.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-data-probability">Previous: Data, Averages and Probability</a></span>
                <span><a href="/courses/hat/lessons/hat-profit-loss-discount">Next: Profit, Loss and Discount</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
