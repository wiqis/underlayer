// HAT course — Simple and compound interest, growth and decay.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_interest() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Simple and Compound Interest — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Simple and Compound Interest</h1>
            <div class="lesson-meta">15 min &middot; Module 2: Quantitative Reasoning &middot; Applied arithmetic</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Interest is the percentage change that repeats. Simple interest applies the rate to the original sum every year, so it grows in a straight line. Compound interest applies the rate to the running balance, so each year earns interest on the previous interest, and the growth curves upward.</p>
                <p>The test cares about one thing above all: the difference between the two over two years. It has a short formula, it appears constantly, and it separates candidates who understand the compounding from those who only memorised a rate.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three quantities and one multiplier drive everything.</p>
                <ul>
                    <li><strong>P</strong> is the principal, the money at the start.</li>
                    <li><strong>r percent</strong> is the annual rate, and <strong>n</strong> is the number of years.</li>
                    <li><strong>Simple interest</strong> grows by P &times; r &divide; 100 each year, always on the original P.</li>
                    <li><strong>Compound interest</strong> grows by the multiplier (1 + r &divide; 100), applied afresh each year to the new balance.</li>
                </ul>
                <div class="formula">simple grows by addition &nbsp;&middot;&nbsp; compound grows by repeated multiplication</div>
                <p>The model assumes the rate is fixed and, for compound interest, that the interest is left in the account. If the question says the interest is withdrawn each year, the account behaves like simple interest even when the wording says compound.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Simple interest.</strong> The rate is charged once per year on the original principal only.</p>
                <div class="formula">SI = P &times; R &times; T &divide; 100 &nbsp;&nbsp; amount = P + SI</div>
                <p><strong>Compound interest.</strong> The amount is the principal multiplied by the growth factor once per year.</p>
                <div class="formula">A = P &times; (1 + r &divide; 100)<sup>n</sup> &nbsp;&nbsp; CI = A &minus; P</div>
                <p><strong>The two-year difference.</strong> Over exactly two years the gap between compound and simple interest has a tidy closed form worth memorising.</p>
                <div class="formula">CI &minus; SI over two years = P &times; (r &divide; 100)<sup>2</sup></div>
                <p><strong>Half-yearly compounding.</strong> When interest is compounded every six months, halve the annual rate and double the number of periods. A rate of 10 percent over one year becomes 5 percent over two periods.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Term</th><th scope="col">P = 10000, r = 10%, n = 2 years</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Simple interest</td><td>10000 &times; 10 &times; 2 &divide; 100 = 2000</td></tr>
                        <tr><td>Compound interest</td><td>10000 &times; 1.10<sup>2</sup> &minus; 10000 = 2100</td></tr>
                        <tr><td>Difference</td><td>2100 &minus; 2000 = 100, and P &times; (r &divide; 100)<sup>2</sup> = 100</td></tr>
                    </tbody>
                </table>
                <p><strong>Growth and decay.</strong> The same multiplier handles a rising population and a falling price. A quantity growing at r percent per year for n years is multiplied by (1 + r &divide; 100) n times; a quantity shrinking uses (1 &minus; r &divide; 100).</p>
                <div class="callout callout-tip">
                    <strong>The fastest check on any interest question:</strong> compound interest is always greater than simple interest over the same principal, rate and time. If your answer has them reversed, the arithmetic is wrong somewhere.
                </div>
                <div class="callout callout-warn">
                    <strong>Two common slips.</strong> Applying the rate to P for every year of a compound question, which quietly turns it into simple interest; and using the two-year difference formula for a term that is not two years.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>A sum of 10000 is invested at 10 percent per annum for 2 years. Find the simple interest, the compound interest and the difference between them.</em></p>
                <p>Simple interest applies the rate to the original principal each year.</p>
                <div class="formula">SI = 10000 &times; 10 &times; 2 &divide; 100 = 2000</div>
                <p>Compound interest multiplies by the growth factor 1.10 twice.</p>
                <div class="formula">A = 10000 &times; 1.10 &times; 1.10 = 12100 &nbsp; so &nbsp; CI = 12100 &minus; 10000 = 2100</div>
                <p>The difference is 2100 &minus; 2000 = 100. The two-year shortcut confirms it: P &times; (r &divide; 100)<sup>2</sup> = 10000 &times; 0.01 = 100. The extra 100 is the interest earned on the first year interest during the second year.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What is the simple interest on 5000 at 8 percent per annum for 3 years?</p>
                    <button class="quiz-option" data-correct="false" data-explain="400 is the interest for a single year; the term is three years, so it must be tripled." onclick="checkQuiz('quiz-1', this)">400</button>
                    <button class="quiz-option" data-correct="true" data-explain="SI = 5000 times 8 times 3 divided by 100 = 1200." onclick="checkQuiz('quiz-1', this)">1200</button>
                    <button class="quiz-option" data-correct="false" data-explain="600 is the interest for eighteen months, which is only half the stated term." onclick="checkQuiz('quiz-1', this)">600</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Find the compound interest on 1000 at 10 percent per annum for 2 years.</p>
                    <button class="quiz-option" data-correct="false" data-explain="100 is the first year interest alone, before the second year of compounding." onclick="checkQuiz('quiz-2', this)">100</button>
                    <button class="quiz-option" data-correct="false" data-explain="200 is the simple interest over two years; compound interest is always slightly more." onclick="checkQuiz('quiz-2', this)">200</button>
                    <button class="quiz-option" data-correct="true" data-explain="A = 1000 times 1.10 times 1.10 = 1210, so CI = 1210 minus 1000 = 210." onclick="checkQuiz('quiz-2', this)">210</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>For a principal of 20000 at 5 percent per annum, what is the difference between compound and simple interest over 2 years?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Difference = P times (r divided by 100) squared = 20000 times 0.05 times 0.05 = 50." onclick="checkQuiz('quiz-3', this)">50</button>
                    <button class="quiz-option" data-correct="false" data-explain="100 would need a rate of about 7.1 percent, or a principal of 40000 at 5 percent." onclick="checkQuiz('quiz-3', this)">100</button>
                    <button class="quiz-option" data-correct="false" data-explain="25 comes from using half the required rate; the formula squares the rate, not the principal." onclick="checkQuiz('quiz-3', this)">25</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>Find the amount when 10000 is invested at 10 percent per annum compounded half-yearly for 1 year.</p>
                    <button class="quiz-option" data-correct="false" data-explain="11000 is the simple interest amount; half-yearly compounding produces a little more." onclick="checkQuiz('quiz-4', this)">11000</button>
                    <button class="quiz-option" data-correct="true" data-explain="Halve the rate to 5 percent and double the periods to 2, so A = 10000 times 1.05 times 1.05 = 11025." onclick="checkQuiz('quiz-4', this)">11025</button>
                    <button class="quiz-option" data-correct="false" data-explain="12100 comes from compounding annually for two years, not half-yearly for one year." onclick="checkQuiz('quiz-4', this)">12100</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: write the simple interest formula, and state what happens to the rate and the number of periods under half-yearly compounding.</p>
                <p>The answers: SI equals P times R times T divided by 100; and for half-yearly compounding the rate is halved while the number of periods is doubled.</p>
                <div id="fill-1">
                    <p>Simple interest divides P &times; R &times; T by <input type="text" class="fill-blank" data-answer="100" placeholder="?" aria-label="divisor in the simple interest formula" />. For two years, CI &minus; SI equals P &times; (r &divide; 100) squared, which for P = 10000 and r = 10 gives <input type="text" class="fill-blank" data-answer="100" placeholder="?" aria-label="two year difference" />. Under half-yearly compounding the annual rate is halved and the number of periods is <input type="text" class="fill-blank" data-answer="doubled" placeholder="?" aria-label="effect on the number of periods" />. Compound interest exceeds simple interest over the same term because it earns interest on the <input type="text" class="fill-blank" data-answer="interest" placeholder="?" aria-label="compound versus simple" /> itself.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A sum of 8000 is invested at 10 percent per annum compound interest for 2 years. Find the amount and the compound interest, then confirm the two-year difference formula.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>The growth factor is 1.10, applied twice.</p>
                    <div class="formula">A = 8000 &times; 1.10 &times; 1.10 = 8000 &times; 1.21 = 9680</div>
                    <p>Compound interest is the amount minus the principal: CI = 9680 &minus; 8000 = 1680.</p>
                    <p>Simple interest would be 8000 &times; 10 &times; 2 &divide; 100 = 1600, so the difference is 1680 &minus; 1600 = 80. The shortcut agrees: P &times; (r &divide; 100)<sup>2</sup> = 8000 &times; 0.01 = 80.</p>
                    <p>The 80 is the interest on the first year interest of 800, which is 10 percent of 800. This connects the two-year difference formula to the intuition behind compounding, instead of leaving it as a memorised fact.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Compound interest is a repeated multiplication by the same factor, and multiplying a number by itself repeatedly is exactly what an exponent counts. The next lesson builds those laws directly, along with roots and surds, the last piece of number sense the quantitative section tests.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-profit-loss-discount">Previous: Profit, Loss and Discount</a></span>
                <span><a href="/courses/hat/lessons/hat-quant-drill">Next: Quantitative Drill</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
