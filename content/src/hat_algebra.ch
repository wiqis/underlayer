// HAT course — Concept 7: Algebra without fear.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_algebra() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Algebra Without Fear — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Algebra Without Fear</h1>
            <div class="lesson-meta">16 min · Module 2: Quantitative Reasoning · Core technique</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Word problems in the quantitative section are sentences hiding equations. "Three more than twice a number is 17" is not an algebra question; it is a translation question, and the algebra that follows is two lines. Candidates who freeze here usually cannot say which of two things they are being asked to find, or they translate the sentence into the wrong equation and then solve it perfectly.</p>
                <p>The other reason algebra deserves a lesson of its own is speed. A well-formed equation often beats arithmetic reasoning, because it does not require you to hold three quantities in your head while manipulating them.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Treat every word problem as three steps, and never skip the first.</p>
                <ol>
                    <li><strong>Name the unknown.</strong> Write "let x be ..." in your own words. If the question asks for something else, name that too.</li>
                    <li><strong>Translate.</strong> Write one equation per stated relationship. Two relationships means two equations.</li>
                    <li><strong>Solve and check.</strong> Substitute the answer back into the sentence, not just into the equation.</li>
                </ol>
                <p>The translation dictionary is small and worth memorising: "is" becomes equals, "more than" becomes plus, "less than" becomes minus, "of" becomes multiply, "per" becomes divide, "twice" becomes two times. The one trap: "less than" reverses order. "Five less than a number" is x - 5, not 5 - x.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Linear equations in one unknown.</strong> Collect the unknown on one side and the numbers on the other.</p>
                <pre>5(x - 3) = 2x + 6
5x - 15 = 2x + 6
3x = 21
x = 7</pre>
                <p>Check by substitution: the left side is 5 x (7 - 3) = 20, and the right side is 2 x 7 + 6 = 20. Both sides agree, so x = 7 is correct.</p>
                <p><strong>Two equations, two unknowns.</strong> Add them to remove one variable when the coefficients line up. If x + y = 10 and x - y = 4, adding gives 2x = 14, so x = 7, and then y = 10 - 7 = 3. Check the second equation: 7 - 3 = 4.</p>
                <p>When the coefficients do not line up, multiply one equation first. For y = 2x and x + y = 9, substitute: x + 2x = 9, so 3x = 9, x = 3 and y = 6.</p>
                <p><strong>Quadratics.</strong> The form that appears is almost always factorable with small integers. To solve x squared - 5x + 6 = 0, look for two numbers that multiply to +6 and add to -5: those are -2 and -3, so the equation factors as (x - 2)(x - 3) = 0 and x is 2 or 3. Check both: 4 - 10 + 6 = 0 and 9 - 15 + 6 = 0.</p>
                <p><strong>Inequalities.</strong> Solve exactly as an equation, flipping the direction of the inequality when you multiply or divide by a negative number. From 2x + 3 less than 11, subtract 3 to get 2x less than 8, then divide by 2 for x less than 4.</p>
                <p><strong>Expanding and simplifying.</strong> 2(3x - 4) is 6x - 8. Do this before solving whenever brackets are present, because it removes a common source of sign errors.</p>
                <div class="callout callout-tip">
                    <strong>Answer the question that was asked.</strong> If the question asks for the larger of two numbers and you solved for the smaller, the answer is wrong even though the algebra was right. Underline the final request before you start solving.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>A father is currently three times as old as his son. In 12 years the father will be twice as old as his son. How old is the son now?</em></p>
                <p>Name the unknowns: let s be the son's age now, and let f be the father's age now. Translate the two sentences:</p>
                <pre>f = 3s
f + 12 = 2(s + 12)</pre>
                <p>The second sentence is where errors appear: it is <em>son's age in 12 years</em> on the right, so both ages must be advanced. Substitute the first into the second: 3s + 12 = 2s + 24, so s = 12, and f = 3 x 12 = 36.</p>
                <p>Check against the original sentence, not the equation: the father is 36 and the son is 12, so the father is three times as old — correct. In 12 years the son is 24 and the father is 48, and 48 is twice 24 — correct. The answer is 12.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Solve for x: 5(x - 3) = 2x + 6.</p>
                    <button class="quiz-option" data-correct="true" data-explain="5x - 15 = 2x + 6 leads to 3x = 21, so x = 7. Substituting gives 20 on both sides." onclick="checkQuiz('quiz-1', this)">7</button>
                    <button class="quiz-option" data-correct="false" data-explain="x = 3 gives 5(0) = 0 on the left and 12 on the right. The sides must be equal." onclick="checkQuiz('quiz-1', this)">3</button>
                    <button class="quiz-option" data-correct="false" data-explain="x = 21 comes from stopping after 3x = 21 without dividing by 3." onclick="checkQuiz('quiz-1', this)">21</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>If x + y = 10 and x - y = 4, what are x and y?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Adding the equations gives 2x = 14, so x = 7, not 4." onclick="checkQuiz('quiz-2', this)">7 and 7</button>
                    <button class="quiz-option" data-correct="true" data-explain="Adding removes y: 2x = 14, so x = 7 and y = 10 - 7 = 3. Check: 7 - 3 = 4." onclick="checkQuiz('quiz-2', this)">7 and 3</button>
                    <button class="quiz-option" data-correct="false" data-explain="These values satisfy x + y = 10 but give a difference of 8, not 4." onclick="checkQuiz('quiz-2', this)">9 and 1</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>What are the roots of x squared - 5x + 6 = 0?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Two numbers multiplying to 6 and adding to -5 are -2 and -3, so x is 2 or 3." onclick="checkQuiz('quiz-3', this)">2 and 3</button>
                    <button class="quiz-option" data-correct="false" data-explain="1 and 6 multiply to 6 but add to 7. The sum must be -5, so both roots are positive and their negatives are the factors." onclick="checkQuiz('quiz-3', this)">1 and 6</button>
                    <button class="quiz-option" data-correct="false" data-explain="Substituting x = -2 gives 4 + 10 + 6, which is 20, not zero. The factors are (x - 2) and (x - 3), so both roots are positive." onclick="checkQuiz('quiz-3', this)">-2 and -3</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what is the first step for any word problem, and how do you handle two stated relationships?</p>
                <p>The answer is: name the unknown explicitly first; two stated relationships become two equations, which you solve together by adding, or by substituting one into the other.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>Solving 3x + 7 = 22 gives x = <input type="text" class="fill-blank" data-answer="5" placeholder="?" aria-label="value of x" />. Factorising x squared - 5x + 6 gives the roots <input type="text" class="fill-blank" data-answer="2" placeholder="?" aria-label="smaller root" /> and 3. If two numbers sum to 45 and differ by 13, the larger is <input type="text" class="fill-blank" data-answer="29" placeholder="?" aria-label="larger number" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A shop sells pens at 55 rupees each. Pens bought in a pack of 8 cost 400 rupees. You need 30 pens. What is the cheapest total, and how much do you save compared with buying single pens?</p>
                <details>
                    <summary>Show the worked solution</summary>
                    <p>Thirty pens bought singly cost 30 x 55 = 1650 rupees. Buying packs of 8 is cheaper per pen (400 / 8 = 50 rupees), so use as many packs as possible: three packs give 24 pens for 3 x 400 = 1200 rupees, leaving 6 pens to buy singly at 6 x 55 = 330. Total 1200 + 330 = 1530 rupees, which is a saving of 1650 - 1530 = 120 rupees.</p>
                    <p>Now the step most candidates skip: could four packs be cheaper? Four packs give 32 pens for 1600 rupees — more pens, but 1600 is more than 1530, so it is worse. The algebra here is the constraint: whole packs only, and the cheapest solution is the largest number of packs that does not require buying more than needed. Writing that constraint down is what turns a word problem into a two-line computation.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Algebra handles relationships between numbers. Geometry handles relationships between shapes and spaces, and it is the section of the quantitative paper where a single forgotten formula costs a mark that no amount of calculation can recover — because a wrong formula produces a wrong answer with no internal signal that anything went wrong.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-ratio-proportion">Previous: Ratio, Proportion and Rate</a></span>
                <span><a href="/courses/hat/lessons/hat-geometry">Next: Geometry and Measurement</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
