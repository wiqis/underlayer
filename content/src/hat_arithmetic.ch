// HAT course — Concept 4: Arithmetic you can do in your head.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_arithmetic() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Arithmetic You Can Do in Your Head — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Arithmetic You Can Do in Your Head</h1>
            <div class="lesson-meta">15 min · Module 2: Quantitative Reasoning · Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Quantitative Reasoning is not a mathematics test. Almost every question can be reduced to two or three arithmetic steps with small numbers, and the marks go to the candidate who executes those steps correctly inside 72 seconds. Two distinct failures cost marks here: getting the order of operations wrong, and being slow enough that the last fifteen questions of the paper go unanswered.</p>
                <p>Speed is not a talent. It comes from a small set of exact facts you never re-derive — the fraction-to-percent table, squares to 25, divisibility rules — plus estimation to eliminate options before you compute.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Give yourself two gears.</p>
                <ul>
                    <li><strong>Exact gear.</strong> Small numbers, exact arithmetic, shown on paper. Use it when the options are close together or the question asks for a precise value.</li>
                    <li><strong>Estimate gear.</strong> Round to convenient numbers, compute roughly, and eliminate options that fall outside the rough band. Use it when the options are far apart — which, on a 100-question paper, is most of the time.</li>
                </ul>
                <p>The model's missing piece: none of this works if the underlying operations are shaky. Order of operations is the foundation the rest of the section stands on, so fix that first, exactly.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Order of operations.</strong> Evaluate in this order: brackets, then powers and roots, then multiplication and division left to right, then addition and subtraction left to right.</p>
                <pre>12 + 3 x (8 - 5)  = 12 + 3 x 3 = 12 + 9 = 21
(12 + 3) x (8 - 5) = 15 x 3 = 45</pre>
                <p>The same digits give different answers; the brackets decide. Read every question as if the author placed the brackets deliberately, because they did.</p>
                <p><strong>Fractions and percentages you should never re-derive.</strong> Learn this table cold — it converts division into multiplication, which is faster and less error-prone.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Fraction</th><th scope="col">Decimal</th><th scope="col">Percent</th><th scope="col">Fraction</th><th scope="col">Decimal</th><th scope="col">Percent</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1/8</td><td>0.125</td><td>12.5%</td><td>5/8</td><td>0.625</td><td>62.5%</td></tr>
                        <tr><td>1/6</td><td>0.1667</td><td>16.67%</td><td>1/3</td><td>0.3333</td><td>33.33%</td></tr>
                        <tr><td>1/5</td><td>0.2</td><td>20%</td><td>2/3</td><td>0.6667</td><td>66.67%</td></tr>
                        <tr><td>1/4</td><td>0.25</td><td>25%</td><td>3/4</td><td>0.75</td><td>75%</td></tr>
                        <tr><td>3/8</td><td>0.375</td><td>37.5%</td><td>7/8</td><td>0.875</td><td>87.5%</td></tr>
                    </tbody>
                </table>
                <p><strong>Squares.</strong> Know these by heart; they appear directly and inside products.</p>
                <pre>11 12 13 14 15 16 17 18 19 20  21  22  23  24  25
121 144 169 196 225 256 289 324 361 400 441 484 529 576 625</pre>
                <p>For any number ending in 5, square it by multiplying the leading part by itself plus one and appending 25: 35 squared is 3 x 4 = 12, then 25, giving 1225.</p>
                <p><strong>Divisibility rules</strong> turn "is this divisible by" into a ten-second check:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Divisor</th><th scope="col">Rule</th><th scope="col">Example</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>3</td><td>Digit sum is divisible by 3</td><td>4317: 4 + 3 + 1 + 7 = 15, so yes (4317 / 3 = 1439)</td></tr>
                        <tr><td>9</td><td>Digit sum is divisible by 9</td><td>4311: 4 + 3 + 1 + 1 = 9, so yes (4311 / 9 = 479)</td></tr>
                        <tr><td>4</td><td>Last two digits form a multiple of 4</td><td>1316: 16 is a multiple of 4, so yes</td></tr>
                        <tr><td>11</td><td>Alternating digit-sum difference is 0 or a multiple of 11</td><td>2728: (2 + 2) - (7 + 8) = -11, so yes (2728 / 11 = 248)</td></tr>
                    </tbody>
                </table>
                <p><strong>LCM and HCF.</strong> Factorise, then take each prime to the highest power for the LCM and to the lowest for the HCF. For 12 (2 squared x 3) and 18 (2 x 3 squared): LCM is 4 x 9 = 36, HCF is 2 x 3 = 6. Sanity check: LCM x HCF should equal 12 x 18.</p>
                <div class="callout callout-tip">
                    <strong>Fast multiplication.</strong> Split and recombine: 15 x 24 is 15 x 20 + 15 x 4 = 300 + 60 = 360. Multiply by 11 by adding the digits: 63 x 11 gives 6, 6 + 3, 3, that is 693. Multiply by 5 by halving and appending a zero: 48 x 5 is 24 with a zero, which is 240.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>A train covers 348 kilometres in 4 hours. At the same average speed, how far does it travel in 90 minutes?</em></p>
                <p>Step 1, exact gear: 348 divided by 4 is 87 kilometres per hour. Step 2, convert the time to a fraction of an hour: 90 minutes is 1.5 hours. Step 3: 87 x 1.5 = 87 + 43.5 = 130.5, so 130.5 kilometres.</p>
                <p>Now the estimate gear on the same question, in case the options were far apart: 350 kilometres in 4 hours is a bit under 90 per hour, and 1.5 hours is one and a half of those, so a little under 135 — say 130. Any option outside 125 to 140 is wrong on sight. Note the sequence: estimate to eliminate, then compute exactly only if two plausible options survive.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What is the value of 12 + 3 x (8 - 5)?</p>
                    <button class="quiz-option" data-correct="false" data-explain="That is what you get by adding first: 15 x 3 = 45. Brackets govern multiplication before addition, so this is not the value." onclick="checkQuiz('quiz-1', this)">45</button>
                    <button class="quiz-option" data-correct="true" data-explain="Brackets first: 8 - 5 = 3, then 3 x 3 = 9, then 12 + 9 = 21." onclick="checkQuiz('quiz-1', this)">21</button>
                    <button class="quiz-option" data-correct="false" data-explain="This would require the multiplication to be ignored entirely." onclick="checkQuiz('quiz-1', this)">15</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Is 4317 divisible by 3?</p>
                    <button class="quiz-option" data-correct="false" data-explain="The digit sum of 4317 is 4 + 3 + 1 + 7 = 15, which is divisible by 3, so 4317 is divisible by 3." onclick="checkQuiz('quiz-2', this)">No, because 4317 is odd</button>
                    <button class="quiz-option" data-correct="true" data-explain="Digit sum 15 is divisible by 3, and 4317 / 3 = 1439 exactly." onclick="checkQuiz('quiz-2', this)">Yes, because the digit sum is 15</button>
                    <button class="quiz-option" data-correct="false" data-explain="Divisibility by 3 depends on the digit sum, not on the last digit." onclick="checkQuiz('quiz-2', this)">Yes, because the last digit is 7</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>What is 3 divided by 4, expressed as a percentage?</p>
                    <button class="quiz-option" data-correct="false" data-explain="0.8 x 100 is 80, not 8. Watch the decimal shift when converting to a percentage." onclick="checkQuiz('quiz-3', this)">8%</button>
                    <button class="quiz-option" data-correct="false" data-explain="62.5% is 5/8. The fraction here is 3 divided by 4." onclick="checkQuiz('quiz-3', this)">62.5%</button>
                    <button class="quiz-option" data-correct="true" data-explain="3 divided by 4 is 0.75, and 0.75 x 100 is 75 percent." onclick="checkQuiz('quiz-3', this)">75%</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: state the order of operations, and give the divisibility rule for 11.</p>
                <p>The answer is: brackets, powers and roots, multiplication and division left to right, addition and subtraction left to right. For 11, add the digits in alternating positions, subtract the two sums, and check whether the difference is 0 or a multiple of 11.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>One eighth as a percentage is <input type="text" class="fill-blank" data-answer="12.5" placeholder="?" aria-label="one eighth as a percentage" /> percent. Seventeen squared is <input type="text" class="fill-blank" data-answer="289" placeholder="?" aria-label="17 squared" />. The LCM of 12 and 18 is <input type="text" class="fill-blank" data-answer="36" placeholder="?" aria-label="LCM" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Without a calculator, decide which of these three is largest: 24 percent of 350, 35 percent of 240, or 30 percent of 280. Show your method, not just the winner.</p>
                <details>
                    <summary>Show the worked solution</summary>
                    <p>Use the fraction table instead of long multiplication. Twenty-four percent is close to one quarter, so 24% of 350 is a little less than 87.5: exactly, 350 x 0.24 = 84. Thirty-five percent of 240: 10% is 24, so 35% is 24 + 24 + 24 + 12 = 84. Thirty percent of 280: 10% is 28, so 30% is 28 + 28 + 28 = 84.</p>
                    <p>All three are 84. The point of the example is the third method — splitting a percentage into tens and a half-ten — which is how you answer percentage questions in about eight seconds instead of forty. The second point is that noticing the tie saves you from guessing between options that are deliberately set close together.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Exact operations and fast estimation are now in place. The next lesson turns that speed onto the properties of whole numbers — divisibility, primes, HCF and LCM — the shortcuts that answer a question without a full division.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-triage-and-guessing">Previous: Triage and Guessing</a></span>
                <span><a href="/courses/hat/lessons/hat-number-properties">Next: Number Properties</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
