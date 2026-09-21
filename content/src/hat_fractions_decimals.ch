// HAT course — Fractions, decimals and the conversion table.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_fractions_decimals() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Fractions, Decimals and Percentages — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Fractions, Decimals and the Conversion Table</h1>
            <div class="lesson-meta">14 min · Module 2: Quantitative Reasoning · Number sense</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A single conversion table removes twenty or thirty seconds from percentage questions, ratio questions, probability questions and data interpretation questions — every one of them asks you to move between a fraction, a decimal and a percentage. Candidates who compute 5 &divide; 8 by long division on the exam lose the marks they came to collect.</p>
                <p>There is a second, quieter win: comparing fractions correctly. The most common careless error in quantitative sections is deciding that 3 &divide; 5 is bigger than 7 &divide; 11 because 5 is smaller than 11. It is not — and a cross-multiplication takes four seconds.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A fraction is a division waiting to happen, and a percentage is just a fraction with 100 underneath. Three representations, one number:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Fraction</th><th scope="col">Decimal</th><th scope="col">Percentage</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1/2</td><td>0.5</td><td>50%</td></tr>
                        <tr><td>1/4</td><td>0.25</td><td>25%</td></tr>
                        <tr><td>3/4</td><td>0.75</td><td>75%</td></tr>
                        <tr><td>1/5</td><td>0.2</td><td>20%</td></tr>
                        <tr><td>1/8</td><td>0.125</td><td>12.5%</td></tr>
                        <tr><td>3/8</td><td>0.375</td><td>37.5%</td></tr>
                        <tr><td>1/10</td><td>0.1</td><td>10%</td></tr>
                    </tbody>
                </table>
                <p>Notice the structure: every entry on the right is the decimal times 100, so you only ever memorise the fraction-to-decimal half. Notice also that the list is built from halves, quarters, fifths, eighths and tenths — the denominators that appear in real questions.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The table worth memorising</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Fraction</th><th scope="col">Decimal</th><th scope="col">Percentage</th><th scope="col">Fraction</th><th scope="col">Decimal</th><th scope="col">Percentage</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1/2</td><td>0.5</td><td>50%</td><td>1/8</td><td>0.125</td><td>12.5%</td></tr>
                        <tr><td>1/3</td><td>0.333&hellip;</td><td>33.3%</td><td>3/8</td><td>0.375</td><td>37.5%</td></tr>
                        <tr><td>2/3</td><td>0.666&hellip;</td><td>66.7%</td><td>5/8</td><td>0.625</td><td>62.5%</td></tr>
                        <tr><td>1/4</td><td>0.25</td><td>25%</td><td>7/8</td><td>0.875</td><td>87.5%</td></tr>
                        <tr><td>3/4</td><td>0.75</td><td>75%</td><td>1/9</td><td>0.111&hellip;</td><td>11.1%</td></tr>
                        <tr><td>1/5</td><td>0.2</td><td>20%</td><td>1/11</td><td>0.0909&hellip;</td><td>9.09%</td></tr>
                        <tr><td>2/5</td><td>0.4</td><td>40%</td><td>1/12</td><td>0.0833&hellip;</td><td>8.33%</td></tr>
                        <tr><td>3/5</td><td>0.6</td><td>60%</td><td>1/16</td><td>0.0625</td><td>6.25%</td></tr>
                        <tr><td>4/5</td><td>0.8</td><td>80%</td><td>1/7</td><td>0.142857&hellip;</td><td>14.3%</td></tr>
                        <tr><td>1/6</td><td>0.166&hellip;</td><td>16.7%</td><td>1/20</td><td>0.05</td><td>5%</td></tr>
                    </tbody>
                </table>
                <h3>Comparing without computing</h3>
                <p>To compare a/b with c/d, cross-multiply: if a &times; d exceeds c &times; b, the first fraction is larger. Example: 7/12 against 11/19 gives 7 &times; 19 = 133 and 11 &times; 12 = 132, so 7/12 is larger — by a margin of one part in 228, which is why this question is always designed to catch estimation.</p>
                <h3>Operations, kept cheap</h3>
                <ul>
                    <li><strong>Multiply:</strong> multiply across the top and across the bottom, then simplify with the HCF.</li>
                    <li><strong>Divide:</strong> flip the second fraction and multiply.</li>
                    <li><strong>Add or subtract:</strong> find the LCD, convert, then combine. For halves and thirds, the LCD is 6.</li>
                    <li><strong>"Of" means multiply:</strong> three-fifths of 240 is 3 &times; 240 &divide; 5 = 144.</li>
                    <li><strong>Recurring decimal to fraction:</strong> a single repeating digit goes over 9 (0.333&hellip; = 1/3), two repeating digits over 99 (0.272727&hellip; = 27/99 = 3/11), and 0.142857&hellip; is 1/7.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>Percentages from fractions in one step:</strong> to convert a fraction to a percentage, multiply by 100 and divide by the denominator. 3/8 becomes 300 &divide; 8 = 37.5% without ever writing a decimal.
                </div>
                <div class="callout callout-warn">
                    <strong>The trap that catches most candidates.</strong> When two fractions are compared, the options are usually the two fractions plus "they are equal". Cross-multiply rather than reasoning from the denominators: a larger denominator does not always mean a smaller fraction (5/8 is larger than 4/7, even though 8 is larger than 7).
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. What is 5/8 of 240?</h3>
                <p>240 &divide; 8 = 30, then 30 &times; 5 = <strong>150</strong>. Dividing first keeps the numbers small; multiplying first gives 1,200 &divide; 8, which is the same answer with more to hold in your head.</p>
                <h3>2. A tank is 7/12 full. Is that more or less than 11/19 full?</h3>
                <p>Cross-multiply: 7 &times; 19 = 133 against 11 &times; 12 = 132, so 7/12 is larger, by a sliver. Options that include "cannot be determined" are wrong: the comparison is fully determined.</p>
                <h3>3. Write 0.375 as a fraction in lowest terms.</h3>
                <p>0.375 = 375/1000. The HCF of 375 and 1000 is 125, so divide both: 3/8. Recognising 0.375 directly from the table saves the work.</p>
                <h3>4. Express 1/7 as a percentage, to one decimal place.</h3>
                <p>1/7 = 0.142857&hellip;, so 14.2857&hellip;%, which rounds to <strong>14.3%</strong>. The nearby distractor is 12.5%, which is 1/8.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Which is larger, 2/3 or 5/8?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Cross-multiplying: 2 &times; 8 = 16 against 5 &times; 3 = 15, so 2/3 is larger. In decimals that is 0.667 against 0.625." onclick="checkQuiz('quiz-1', this)">2/3</button>
                    <button class="quiz-option" data-correct="false" data-explain="5/8 is 0.625 and 2/3 is 0.667, so the larger denominator does not make the larger fraction." onclick="checkQuiz('quiz-1', this)">5/8</button>
                    <button class="quiz-option" data-correct="false" data-explain="They are not equal: 2/3 is 0.667 and 5/8 is 0.625, a difference of about 0.04." onclick="checkQuiz('quiz-1', this)">They are equal</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>What is 3/8 expressed as a percentage?</p>
                    <button class="quiz-option" data-correct="false" data-explain="33.3% is 1/3, not 3/8. Multiply 3/8 by 100 to get 37.5%." onclick="checkQuiz('quiz-2', this)">33.3%</button>
                    <button class="quiz-option" data-correct="true" data-explain="3/8 = 0.375, and 0.375 &times; 100 = 37.5%." onclick="checkQuiz('quiz-2', this)">37.5%</button>
                    <button class="quiz-option" data-correct="false" data-explain="62.5% is 5/8; the numerator here is 3, so the figure is smaller." onclick="checkQuiz('quiz-2', this)">62.5%</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>A recipe needs 2/3 of a kilogram of flour and you are making 3/4 of the quantity. How much flour?</p>
                    <button class="quiz-option" data-correct="false" data-explain="That is 2/3 + 3/4 in effect, but scaling a recipe uses multiplication, not addition." onclick="checkQuiz('quiz-3', this)">17/12 kg</button>
                    <button class="quiz-option" data-correct="true" data-explain="2/3 &times; 3/4 = 6/12 = 1/2 kilogram, the correct scaling of a 2/3 kilogram quantity by three quarters." onclick="checkQuiz('quiz-3', this)">1/2 kg</button>
                    <button class="quiz-option" data-correct="false" data-explain="5/7 is obtained by adding numerators and denominators, which is not a valid operation on fractions." onclick="checkQuiz('quiz-3', this)">5/7 kg</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>Express 0.272727&hellip; as a fraction in lowest terms.</p>
                    <button class="quiz-option" data-correct="false" data-explain="27/100 is the terminating decimal 0.27, but the decimal here repeats forever, so it goes over 99 before simplifying." onclick="checkQuiz('quiz-4', this)">27/100</button>
                    <button class="quiz-option" data-correct="true" data-explain="A two-digit repeating block goes over 99: 27/99 simplifies by 9 to 3/11." onclick="checkQuiz('quiz-4', this)">3/11</button>
                    <button class="quiz-option" data-correct="false" data-explain="2/7 is 0.285714&hellip;, a different repeating decimal from 0.272727&hellip;" onclick="checkQuiz('quiz-4', this)">2/7</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: how do you compare two fractions without a calculator, and what is 7/8 as a percentage?</p>
                <p>The answer: cross-multiply the numerator of one by the denominator of the other; and 7/8 = 0.875, so 87.5%.</p>
                <div id="fill-1">
                    <p>To convert a fraction to a percentage, multiply by <input type="text" class="fill-blank" data-answer="100" placeholder="?" aria-label="multiplier for percentage" /> and divide by the denominator. To compare a/b with c/d quickly, <input type="text" class="fill-blank" data-answer="cross-multiply" placeholder="?" aria-label="comparison method" />. As a percentage, 1/8 is <input type="text" class="fill-blank" data-answer="12.5" placeholder="?" aria-label="one eighth as percent" /> and 7/8 is <input type="text" class="fill-blank" data-answer="87.5" placeholder="?" aria-label="seven eighths as percent" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A question gives two ratios of students who passed a test — 5/8 of class A and 7/12 of class B — and asks which class had the higher pass rate. Solve it, then state what extra information you would need to answer "which class had more students pass".</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Cross-multiply: 5 &times; 12 = 60 against 7 &times; 8 = 56, so class A's rate, 5/8, is higher. As decimals, 0.625 against 0.583 — the gap is real and visible once converted.</p>
                    <p>For the second question — which class had more students pass — you need each class's size. A rate has no size: 5/8 of a class of 40 is 25 students, while 7/12 of a class of 240 is 140, so the higher rate can belong to the class with fewer passers. This is the same trap that appears in data interpretation tables and in every "which grew faster in percentage terms" question.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Fractions are now tools rather than obstacles. The next lesson takes the most common application of them on the paper: percentages, percentage change, and the profit, loss and interest questions built on top of it.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-number-properties">Previous: Number Properties</a></span>
                <span><a href="/courses/hat/lessons/hat-percentages">Next: Percentages and Percentage Change</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
