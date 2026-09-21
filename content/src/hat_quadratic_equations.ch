// HAT course  -  Quadratic equations: factoring, the formula and the link to roots.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_quadratic_equations() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Quadratic Equations - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Quadratic Equations</h1>
            <div class="lesson-meta">16 min &middot; Module 2: Quantitative Reasoning &middot; Algebra</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Quadratics are the point where arithmetic turns into algebra. A question rarely announces "solve a quadratic"  -  it hides one inside a story about the area of a field, the product of two consecutive numbers, or a profit curve. The candidate who recognises the squared unknown early has a routine; the candidate who does not will try to guess numbers until time runs out.</p>
                <p>The section rewards two skills: turning a paragraph into the standard form a x&sup2; + b x + c = 0, and reading the coefficients for what they already say about the roots.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <ul>
                    <li><strong>Every quadratic has the same shape.</strong> Rearranged into a x&sup2; + b x + c = 0 with a &ne; 0, it is one equation in one unknown.</li>
                    <li><strong>Solving means finding where it is zero.</strong> A root is a value of x that makes the left side vanish.</li>
                    <li><strong>Factor when the numbers are kind; use the formula when they are not.</strong> The formula never fails, so it is the safety net.</li>
                    <li><strong>The coefficients already know the roots.</strong> Their sum is &minus;b &divide; a and their product is c &divide; a, which often answers the question faster than solving.</li>
                </ul>
                <p>The model omits one case deliberately: not every quadratic factorises over the rational numbers, so the formula is not a lazy fallback  -  it is the general method, and the discriminant tells you which situation you are in.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Standard form and factoring</h3>
                <div class="formula">a x&sup2; + b x + c = 0 &nbsp;&nbsp; (a &ne; 0)</div>
                <p>To factor, find two numbers whose product is a times c and whose sum is b. When a = 1 this reduces to two numbers multiplying to c and adding to b. For x&sup2; &minus; 5x + 6, the pair 2 and 3 multiply to 6 and add to 5 with a negative sign, so the factors are (x &minus; 2)(x &minus; 3) and the roots are 2 and 3.</p>
                <h3>The quadratic formula</h3>
                <div class="formula">x = ( &minus;b &plusmn; &radic;(b&sup2; &minus; 4ac) ) &divide; 2a</div>
                <p>Substitute once, compute the discriminant b&sup2; &minus; 4ac, then treat the plus and minus branches separately.</p>
                <h3>The discriminant counts the roots</h3>
                <div class="formula">D = b&sup2; &minus; 4ac</div>
                <table>
                    <thead>
                        <tr><th scope="col">Discriminant</th><th scope="col">Roots</th><th scope="col">Graph meets x-axis</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>D &gt; 0</td><td>Two distinct real roots</td><td>Twice</td></tr>
                        <tr><td>D = 0</td><td>One repeated real root</td><td>Once, at the vertex</td></tr>
                        <tr><td>D &lt; 0</td><td>No real roots</td><td>Never</td></tr>
                    </tbody>
                </table>
                <h3>Roots and coefficients</h3>
                <div class="formula">sum of roots = &minus;b &divide; a &nbsp;&nbsp;&nbsp; product of roots = c &divide; a</div>
                <p>Forming an equation from its roots is the reverse: if the roots are p and q, then x&sup2; &minus; (p + q)x + pq = 0.</p>
                <div class="callout callout-tip">
                    <strong>Five-second check:</strong> after finding two roots by any method, add them and compare with &minus;b &divide; a. If they disagree, a root is wrong  -  and the check costs almost nothing.
                </div>
                <div class="callout callout-warn">
                    <strong>Traps.</strong> (1) Forgetting the equation must equal zero before factoring. (2) Dropping the sign of a negative a or c. (3) Discarding a negative root when the story applies to a signed quantity. (4) Reading the sum as b &divide; a instead of &minus;b &divide; a.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>Solve 2x&sup2; + 3x &minus; 2 = 0.</em></p>
                <p>Here a = 2, b = 3 and c = &minus;2. Compute the discriminant first:</p>
                <div class="formula">D = b&sup2; &minus; 4ac = 3&sup2; &minus; 4(2)(&minus;2) = 9 + 16 = 25</div>
                <p>D &gt; 0, so there are two distinct real roots. Since &radic;25 = 5, the formula gives:</p>
                <div class="formula">x = ( &minus;3 &plusmn; 5 ) &divide; 4</div>
                <p>The plus branch gives x = 2 &divide; 4 = <strong>0.5</strong>. The minus branch gives x = &minus;8 &divide; 4 = <strong>&minus;2</strong>.</p>
                <p>Check against the coefficient identities. The roots sum to 0.5 + (&minus;2) = &minus;1.5, and &minus;b &divide; a = &minus;3 &divide; 2 = &minus;1.5. Their product is 0.5 &times; (&minus;2) = &minus;1, and c &divide; a = &minus;2 &divide; 2 = &minus;1. Both match, so the roots are correct.</p>
                <p>Factorising confirms it: 2x&sup2; + 3x &minus; 2 = (2x &minus; 1)(x + 2), which is zero at x = 0.5 and at x = &minus;2.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What is the discriminant of x&sup2; + 4x + 4 = 0?</p>
                    <button class="quiz-option" data-correct="true" data-explain="D = 4&sup2; &minus; 4(1)(4) = 16 &minus; 16 = 0, so there is one repeated real root." onclick="checkQuiz('quiz-1', this)">0</button>
                    <button class="quiz-option" data-correct="false" data-explain="32 is b&sup2; + 4ac = 16 + 16, but the discriminant subtracts the second term." onclick="checkQuiz('quiz-1', this)">32</button>
                    <button class="quiz-option" data-correct="false" data-explain="&minus;16 reverses the subtraction; here the two parts are equal, so D is 0." onclick="checkQuiz('quiz-1', this)">&minus;16</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>For 3x&sup2; &minus; 6x + 2 = 0, what are the sum and product of the roots?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Sum = &minus;b &divide; a = 6 &divide; 3 = 2, and product = c &divide; a = 2 &divide; 3." onclick="checkQuiz('quiz-2', this)">Sum 2, product 2/3</button>
                    <button class="quiz-option" data-correct="false" data-explain="2 is the sum, but the product is c &divide; a = 2 &divide; 3, not c itself." onclick="checkQuiz('quiz-2', this)">Sum 2, product 2</button>
                    <button class="quiz-option" data-correct="false" data-explain="The sum is &minus;b &divide; a; with b = &minus;6 this is positive 2, not &minus;2." onclick="checkQuiz('quiz-2', this)">Sum &minus;2, product 2/3</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>What are the roots of x&sup2; &minus; 7x + 12 = 0?</p>
                    <button class="quiz-option" data-correct="true" data-explain="3 and 4 multiply to 12 and add to 7, so x&sup2; &minus; 7x + 12 = (x &minus; 3)(x &minus; 4)." onclick="checkQuiz('quiz-3', this)">3 and 4</button>
                    <button class="quiz-option" data-correct="false" data-explain="&minus;3 and &minus;4 sum to &minus;7, which would need the middle term +7x." onclick="checkQuiz('quiz-3', this)">&minus;3 and &minus;4</button>
                    <button class="quiz-option" data-correct="false" data-explain="2 and 6 multiply to 12 but sum to 8, not 7, so the middle term is wrong." onclick="checkQuiz('quiz-3', this)">2 and 6</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>Which equation has roots 5 and &minus;2?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Sum = 3 and product = &minus;10, so the equation is x&sup2; &minus; 3x &minus; 10 = 0." onclick="checkQuiz('quiz-4', this)">x&sup2; &minus; 3x &minus; 10 = 0</button>
                    <button class="quiz-option" data-correct="false" data-explain="The middle term uses &minus;(sum); the sum is 3, so it must be &minus;3x, not +3x." onclick="checkQuiz('quiz-4', this)">x&sup2; + 3x &minus; 10 = 0</button>
                    <button class="quiz-option" data-correct="false" data-explain="The product is 5 &times; (&minus;2) = &minus;10, so the constant must be negative." onclick="checkQuiz('quiz-4', this)">x&sup2; &minus; 3x + 10 = 0</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what does the discriminant tell you, and how do the sum and product of the roots relate to a, b and c?</p>
                <p>The sign of D decides the number of real roots; the roots sum to &minus;b &divide; a and multiply to c &divide; a.</p>
                <div id="fill-1">
                    <p>For x&sup2; &minus; 5x + 6 = 0 the roots are 2 and 3, so their sum is <input type="text" class="fill-blank" data-answer="5" placeholder="?" aria-label="sum of roots of x squared minus five x plus six" /> and their product is <input type="text" class="fill-blank" data-answer="6" placeholder="?" aria-label="product of roots of x squared minus five x plus six" />. The discriminant of x&sup2; + 4x + 4 is <input type="text" class="fill-blank" data-answer="0" placeholder="?" aria-label="discriminant of x squared plus four x plus four" />, so the number of distinct real roots is <input type="text" class="fill-blank" data-answer="1" placeholder="?" aria-label="number of distinct real roots when D is zero" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A rectangular garden is 3 metres longer than it is wide, and its area is 40 square metres. Find its dimensions, and say what a negative root would mean here.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Let the width be w metres, so the length is w + 3. Area gives w(w + 3) = 40, which rearranges to w&sup2; + 3w &minus; 40 = 0.</p>
                    <p>Factorise: the pair 8 and &minus;5 multiplies to &minus;40 and adds to 3, so (w + 8)(w &minus; 5) = 0 and w = 5 or w = &minus;8.</p>
                    <p>A width cannot be negative, so w = 5 and the length is 8. Check the area: 5 &times; 8 = 40 square metres.</p>
                    <p>The negative root is not an error; it is the algebra reporting a second algebraic solution that the physical story rules out. Always re-read the last line of the question to see whether a negative (or fractional) root is admissible.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Quadratics describe one unknown squared against the same unknown. Sequences and series describe an ordered list of quantities whose pattern can be added up. The next lesson gives you the two patterns that carry almost all of those questions  -  arithmetic and geometric.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-algebra">Previous: Algebra Without Fear</a></span>
                <span><a href="/courses/hat/lessons/hat-sequences">Next: Sequences and Series</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
