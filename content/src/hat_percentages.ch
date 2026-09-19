// HAT course — Concept 5: Percentages and percentage change.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_percentages() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Percentages and Percentage Change — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Percentages and Percentage Change</h1>
            <div class="lesson-meta">16 min · Module 2: Quantitative Reasoning · Core technique</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Percentages are the most frequently tested idea in the quantitative section, and the one most often failed by candidates who can actually do the arithmetic. The failure is almost always the same: the percentage is applied to the wrong base. A pay rise of 10 percent followed by a cut of 10 percent does not leave the pay unchanged — and a candidate who computes it as "unchanged" has made a reasoning error, not a calculation error.</p>
                <p>Once you handle percentages as <em>multipliers</em>, most of these questions collapse into one or two multiplications, and the trap disappears.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Replace every percentage with a multiplier and the questions become multiplication problems.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Change</th><th scope="col">Multiplier</th><th scope="col">Change</th><th scope="col">Multiplier</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>+10%</td><td>x 1.10</td><td>-10%</td><td>x 0.90</td></tr>
                        <tr><td>+25%</td><td>x 1.25</td><td>-25%</td><td>x 0.75</td></tr>
                        <tr><td>+50%</td><td>x 1.50</td><td>-50%</td><td>x 0.50</td></tr>
                    </tbody>
                </table>
                <p>Two consequences follow immediately. First, a sequence of changes is just a product of multipliers, and multiplication order does not matter — so +20 percent then -20 percent is 1.2 x 0.8 = 0.96, a net fall of 4 percent, not zero. Second, "find the original" is a division: if the final value is 660 after a 25 percent discount, the original is 660 divided by 0.75, which is 880.</p>
                <p>The model is incomplete in one way worth naming: percentage change is always measured against the <em>starting</em> value. Identify that base before you touch the numbers, every single time.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Percentage of a quantity.</strong> Split into tens where possible. Eighteen percent of 250: 10 percent is 25, so 18 percent is 25 + 20 = 45, since 8 percent is a little over 8 percent of 250 rounded to 20.</p>
                <p><strong>Percentage change.</strong> Use the form:</p>
                <div class="formula">percentage change = (new value - old value) divided by old value, times 100</div>
                <p>A price moves from 800 to 920: the change is 120, and 120 divided by 800 is 0.15, so the increase is 15 percent. Note that dividing by the <em>old</em> value is what makes it a percentage increase rather than a percentage of the new price.</p>
                <p><strong>Successive changes.</strong> Multiply the multipliers. A 25 percent increase followed by a 20 percent discount is 1.25 x 0.80 = 1.00 — the price returns exactly to where it started. This is why shops can advertise a discount after a rise without losing anything, and it is a favourite question shape.</p>
                <p><strong>Reverse percentage.</strong> When the final value and the change are known and the original is wanted, divide by the multiplier rather than subtracting a percentage of the final value. After a 25 percent discount the price is 660, so the original is 660 / 0.75 = 880. Check it forward: 25 percent of 880 is 220, and 880 - 220 = 660.</p>
                <p><strong>Profit and loss percent</strong> is a percentage change with a vocabulary. A shop buys at 400 and sells at 500: profit is 100, and 100 / 400 = 25 percent. Profit is measured against cost, not against selling price.</p>
                <p><strong>Percentage points are not percentages.</strong> If a pass rate rises from 40 percent to 46 percent, that is an increase of 6 <em>percentage points</em>, but a relative increase of 6 / 40 = 15 percent. Read the question to see which one is being asked.</p>
                <div class="callout callout-warn">
                    <strong>The classic trap.</strong> "A number is increased by 20 percent and then decreased by 20 percent. What is the net change?" The distractors always include "no change". The correct answer is a fall of 4 percent, because the 20 percent decrease is taken from a larger base than the increase was.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>A shop's price for a tool is raised by 25 percent at the start of the season. At the end of the season the shop offers a 20 percent discount on the new price. A customer says the tool now costs exactly what it did before. Is the customer right?</em></p>
                <p>Work with multipliers and no original price is needed. The rise gives a multiplier of 1.25; the discount gives a multiplier of 0.80. Their product is 1.25 x 0.80 = 1.00, so the final price equals the original price: the customer is right.</p>
                <p>Now change one number and watch what happens. If the rise is 25 percent and the discount is 20 percent, the price returns to its original level. If the rise is 25 percent and the discount is 25 percent, the multiplier is 1.25 x 0.75 = 0.9375, a net fall of 6.25 percent. The relationship is asymmetric, which is exactly why the test keeps asking it.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>A quantity is increased by 20 percent and then decreased by 20 percent. What is the net change?</p>
                    <button class="quiz-option" data-correct="false" data-explain="That treats the two changes as cancelling. The second change is applied to a bigger base, so the fall is larger than the rise." onclick="checkQuiz('quiz-1', this)">No change</button>
                    <button class="quiz-option" data-correct="true" data-explain="1.2 x 0.8 = 0.96, so the value ends at 96 percent of where it started: a net fall of 4 percent." onclick="checkQuiz('quiz-1', this)">A fall of 4%</button>
                    <button class="quiz-option" data-correct="false" data-explain="A fall of 20 percent would require only one change. The net effect of the pair is much smaller than either individual change." onclick="checkQuiz('quiz-1', this)">A fall of 20%</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>After a 25 percent discount a jacket costs 660. What was its price before the discount?</p>
                    <button class="quiz-option" data-correct="false" data-explain="That would be 660 x 0.75, which shrinks the number instead of restoring the pre-discount price." onclick="checkQuiz('quiz-2', this)">495</button>
                    <button class="quiz-option" data-correct="true" data-explain="Divide by the multiplier: 660 / 0.75 = 880. Check forward: 880 - 220 = 660." onclick="checkQuiz('quiz-2', this)">880</button>
                    <button class="quiz-option" data-correct="false" data-explain="825 comes from adding 25 percent of 660, but the discount was taken from the original price, not from the final one." onclick="checkQuiz('quiz-2', this)">825</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>A shop buys an item for 400 and sells it for 500. What is the profit percentage?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Profit is measured against cost: (500 - 400) / 400 = 0.25, so 25 percent." onclick="checkQuiz('quiz-3', this)">25%</button>
                    <button class="quiz-option" data-correct="false" data-explain="100 / 500 = 20 percent is profit measured against selling price, which is not the standard definition." onclick="checkQuiz('quiz-3', this)">20%</button>
                    <button class="quiz-option" data-correct="false" data-explain="100 percent would mean selling for twice the cost, that is 800." onclick="checkQuiz('quiz-3', this)">100%</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what is the net effect of a 20 percent rise followed by a 20 percent fall, and how would you find the original price from a final price after a 30 percent discount?</p>
                <p>The answer is: a net fall of 4 percent, because 1.2 x 0.8 = 0.96. To reverse a 30 percent discount, divide the final price by 0.70.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>A 15 percent increase is the multiplier <input type="text" class="fill-blank" data-answer="1.15" placeholder="?" aria-label="multiplier for 15 percent increase" />. A rising pass rate that moves from 40 percent to 46 percent has risen by 6 percentage points, which is a relative increase of <input type="text" class="fill-blank" data-answer="15" placeholder="?" aria-label="relative increase percent" /> percent. Eighteen percent of 250 is <input type="text" class="fill-blank" data-answer="45" placeholder="?" aria-label="18 percent of 250" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A salary is 60,000. It is raised by 10 percent, and later cut by 10 percent. What is the final salary, and what single percentage change would have produced the same result in one step?</p>
                <details>
                    <summary>Show the worked solution</summary>
                    <p>Multiply the multipliers: 1.10 x 0.90 = 0.99. The final salary is 60,000 x 0.99 = 59,400. The equivalent single change is a fall of 1 percent.</p>
                    <p>Notice the two things this example is designed to expose. The absolute loss is 600, which is small enough that a candidate working in whole numbers might round it away and answer "unchanged" — the same mistake the multiplier method prevents. And the single-step equivalent is not 1 percent of the original change; the compounding is what produces exactly 0.99, and the size of the net effect depends on the size of the changes, not on their difference.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Percentages handle comparisons against a single base. The next technique handles comparisons between quantities — how one part relates to another, how a total splits, and how a rate scales when one input changes. That is ratio and proportion, and it is the machinery behind most word problems in this section.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-arithmetic">Previous: Arithmetic You Can Do in Your Head</a></span>
                <span><a href="/courses/hat/lessons/hat-ratio-proportion">Next: Ratio, Proportion and Rate</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
