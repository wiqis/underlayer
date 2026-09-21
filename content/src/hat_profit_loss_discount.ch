// HAT course — Profit, loss and discount, and the base each percentage is measured against.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_profit_loss_discount() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Profit, Loss and Discount — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Profit, Loss and Discount</h1>
            <div class="lesson-meta">15 min &middot; Module 2: Quantitative Reasoning &middot; Applied arithmetic</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Profit, loss and discount questions are percentage questions wearing shopkeeper clothes. The arithmetic is the same as every other percentage problem; what changes is that three different prices are in play at once, and each percentage is measured against a different one. Choose the wrong base and every later step is wrong, while the answer still looks tidy.</p>
                <p>Get the bases right and the entire family collapses into one or two multiplications.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three prices move through every transaction.</p>
                <ul>
                    <li><strong>Cost price (CP)</strong> is what the seller paid. Profit and loss percentages are always measured against it.</li>
                    <li><strong>Marked price (MP)</strong> is the advertised price. A discount is always measured against it.</li>
                    <li><strong>Selling price (SP)</strong> is what the buyer actually pays; it is the bridge between the other two.</li>
                </ul>
                <div class="formula">CP &nbsp;&rarr;&nbsp; profit or loss &nbsp;&rarr;&nbsp; SP &nbsp;&larr;&nbsp; discount &nbsp;&larr;&nbsp; MP</div>
                <p>The model omits overheads such as transport, tax and packaging unless the question names them. When it does, add them to the cost price first, because profit is still measured against total cost.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>The core definitions.</strong> Profit is what is left when the selling price exceeds the cost price; loss is the shortfall when it does not.</p>
                <div class="formula">profit = SP &minus; CP &nbsp;&nbsp; loss = CP &minus; SP &nbsp;&nbsp; profit% = (SP &minus; CP) &divide; CP &times; 100</div>
                <p><strong>Working backwards.</strong> The formulas invert cleanly, and most questions test the inverse.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Given</th><th scope="col">Find SP</th><th scope="col">Find CP</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Profit of p percent</td><td>SP = CP &times; (1 + p &divide; 100)</td><td>CP = SP &divide; (1 + p &divide; 100)</td></tr>
                        <tr><td>Loss of l percent</td><td>SP = CP &times; (1 &minus; l &divide; 100)</td><td>CP = SP &divide; (1 &minus; l &divide; 100)</td></tr>
                        <tr><td>Discount of d percent</td><td>SP = MP &times; (1 &minus; d &divide; 100)</td><td>MP = SP &divide; (1 &minus; d &divide; 100)</td></tr>
                    </tbody>
                </table>
                <p><strong>Successive discounts.</strong> Two discounts are never added. Convert each to a multiplier and multiply: discounts of 10 percent and 20 percent give 0.90 &times; 0.80 = 0.72, which is a single discount of 28 percent, not 30.</p>
                <p><strong>Mark-up then discount.</strong> A shop marks up by 40 percent and then discounts by 25 percent: the combined multiplier is 1.40 &times; 0.75 = 1.05, a profit of 5 percent. The order does not change the product; it only fixes which base each percentage uses.</p>
                <div class="callout callout-tip">
                    <strong>One habit fixes the family:</strong> before computing, write down which price the percentage is measured against. Profit percent goes on CP, discount goes on MP, and almost every error in this topic is a base error.
                </div>
                <div class="callout callout-warn">
                    <strong>The two standard traps.</strong> First, computing profit percent on the selling price instead of the cost price: buying at 400 and selling at 500 is a 25 percent profit, not 20 percent. Second, adding successive discounts: 10 percent then 20 percent is 28 percent, never 30.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>A shop marks a jacket at 2000. It offers a 20 percent discount, and still makes a profit of 25 percent on the cost. Find the cost price.</em></p>
                <p>Start at the marked price, because that is where the discount is measured. The discount multiplier is 0.80, so the selling price is 2000 &times; 0.80 = 1600.</p>
                <p>Now move from the selling price to the cost. A profit of 25 percent means the selling price is 1.25 times the cost, so the cost is the selling price divided by 1.25.</p>
                <div class="formula">CP = 1600 &divide; 1.25 = 1280</div>
                <p>Check forward: 25 percent of 1280 is 320, and 1280 + 320 = 1600, which matches the discounted selling price. The cost price is <strong>1280</strong>.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>An article bought for 800 is sold for 720. What is the loss percentage?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Loss is 800 minus 720 = 80, and 80 divided by 800 = 0.10, so the loss is 10 percent." onclick="checkQuiz('quiz-1', this)">10%</button>
                    <button class="quiz-option" data-correct="false" data-explain="80 divided by 720 = 11.1 percent measures the loss against the selling price, but loss percent is defined on the cost price." onclick="checkQuiz('quiz-1', this)">11.1%</button>
                    <button class="quiz-option" data-correct="false" data-explain="8 percent would be a loss of 64, not the 80 that separates 800 and 720." onclick="checkQuiz('quiz-1', this)">8%</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A marked price of 1500 is reduced by a 20 percent discount. What is the selling price?</p>
                    <button class="quiz-option" data-correct="true" data-explain="SP = MP times 0.80 = 1500 times 0.80 = 1200." onclick="checkQuiz('quiz-2', this)">1200</button>
                    <button class="quiz-option" data-correct="false" data-explain="300 is the amount of the discount itself, not the price the customer pays." onclick="checkQuiz('quiz-2', this)">300</button>
                    <button class="quiz-option" data-correct="false" data-explain="1800 adds 20 percent instead of subtracting it, which would be a mark-up, not a discount." onclick="checkQuiz('quiz-2', this)">1800</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Two successive discounts of 10 percent and 20 percent are equivalent to a single discount of what percentage?</p>
                    <button class="quiz-option" data-correct="false" data-explain="30 percent comes from adding the two discounts, which ignores that the second is applied to an already reduced price." onclick="checkQuiz('quiz-3', this)">30%</button>
                    <button class="quiz-option" data-correct="true" data-explain="0.90 times 0.80 = 0.72, so the customer pays 72 percent and the discount is 100 minus 72 = 28 percent." onclick="checkQuiz('quiz-3', this)">28%</button>
                    <button class="quiz-option" data-correct="false" data-explain="25 percent is the simple average of the two discounts, which has no basis in how discounts compound." onclick="checkQuiz('quiz-3', this)">25%</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>An item is sold for 600 at a profit of 20 percent. What is the cost price?</p>
                    <button class="quiz-option" data-correct="false" data-explain="480 takes 20 percent off the selling price, but the profit was calculated on the cost, so the selling price is the larger of the two." onclick="checkQuiz('quiz-4', this)">480</button>
                    <button class="quiz-option" data-correct="true" data-explain="SP = CP times 1.20, so CP = 600 divided by 1.20 = 500. Check: 20 percent of 500 is 100, and 500 + 100 = 600." onclick="checkQuiz('quiz-4', this)">500</button>
                    <button class="quiz-option" data-correct="false" data-explain="720 adds 20 percent to the selling price, but the selling price already includes the profit." onclick="checkQuiz('quiz-4', this)">720</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: which price is the base for profit percent, and which is the base for a discount?</p>
                <p>The answers: profit and loss percent are measured on the cost price, and discount is measured on the marked price.</p>
                <div id="fill-1">
                    <p>Profit percent is measured against the <input type="text" class="fill-blank" data-answer="cost" placeholder="?" aria-label="base for profit percent" /> price, while a discount is measured against the <input type="text" class="fill-blank" data-answer="marked" placeholder="?" aria-label="base for discount" /> price. A 20 percent discount on a marked price of 1500 gives a selling price of <input type="text" class="fill-blank" data-answer="1200" placeholder="?" aria-label="discounted selling price" />. Successive discounts of 10 percent and 20 percent give a net multiplier of <input type="text" class="fill-blank" data-answer="0.72" placeholder="?" aria-label="net multiplier of successive discounts" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A trader marks an article 40 percent above its cost and then allows a discount of 25 percent on the marked price. What is his profit percentage?</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Let the cost price be 100, which turns every percentage into an amount. A mark-up of 40 percent makes the marked price 140. A discount of 25 percent on the marked price gives a selling price of 140 &times; 0.75 = 105.</p>
                    <div class="formula">profit% = (105 &minus; 100) &divide; 100 &times; 100 = 5 percent</div>
                    <p>The trader makes <strong>5 percent</strong>. The combined multiplier is 1.40 &times; 0.75 = 1.05, which confirms the same result in one step.</p>
                    <p>The trap is 15 percent, obtained by subtracting the discount from the mark-up. That subtraction is invalid because the two percentages have different bases: the 40 percent is taken on cost, and the 25 percent is taken on the marked price.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Profit and loss are single-step percentage changes. The next lesson handles a change that repeats itself over time, where the percentage is applied again and again to a growing base. That is simple and compound interest, and the same multiplier logic drives both.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-word-problems">Previous: Translating Word Problems</a></span>
                <span><a href="/courses/hat/lessons/hat-interest">Next: Simple and Compound Interest</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
