// HAT course — Powers, roots and surds: the laws of indices.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_exponents_roots() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Powers, Roots and Surds — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Powers, Roots and Surds</h1>
            <div class="lesson-meta">15 min &middot; Module 2: Quantitative Reasoning &middot; Number sense</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Powers and roots appear in the quantitative section in forms that look unrelated: a large product that collapses to a single power, a comparison of two enormous numbers, and a fraction with a square root in the denominator. They are all the same handful of index laws applied in a different order.</p>
                <p>Learn the laws once and a question such as which is larger, 3 to the power 30 or 2 to the power 45, becomes a two-line rewrite rather than a calculation.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Treat an exponent as a count of repeated multiplication, and three rules follow immediately.</p>
                <ul>
                    <li><strong>Multiplying powers of the same base adds the exponents</strong>, because the total count of factors simply adds up.</li>
                    <li><strong>Dividing powers of the same base subtracts the exponents</strong>, because factors cancel.</li>
                    <li><strong>A power of a power multiplies the exponents</strong>, because each of the inner factors is repeated again.</li>
                </ul>
                <div class="formula">a<sup>m</sup> &times; a<sup>n</sup> = a<sup>m + n</sup> &nbsp;&middot;&nbsp; a<sup>m</sup> &divide; a<sup>n</sup> = a<sup>m &minus; n</sup> &nbsp;&middot;&nbsp; (a<sup>m</sup>)<sup>n</sup> = a<sup>mn</sup></div>
                <p>The model assumes the base is a positive number. An even root of a negative number has no real value, and roots of negative numbers are outside the scope of the test.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>The full set of index laws.</strong> The first three are the working rules; the rest extend them to zero, negative and fractional exponents.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Law</th><th scope="col">Statement</th><th scope="col">Example</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Product</td><td>a<sup>m</sup> &times; a<sup>n</sup> = a<sup>m + n</sup></td><td>2<sup>3</sup> &times; 2<sup>4</sup> = 2<sup>7</sup> = 128</td></tr>
                        <tr><td>Quotient</td><td>a<sup>m</sup> &divide; a<sup>n</sup> = a<sup>m &minus; n</sup></td><td>3<sup>5</sup> &divide; 3<sup>2</sup> = 3<sup>3</sup> = 27</td></tr>
                        <tr><td>Power of a power</td><td>(a<sup>m</sup>)<sup>n</sup> = a<sup>mn</sup></td><td>(5<sup>2</sup>)<sup>3</sup> = 5<sup>6</sup> = 15625</td></tr>
                        <tr><td>Zero power</td><td>a<sup>0</sup> = 1</td><td>7<sup>0</sup> = 1</td></tr>
                        <tr><td>Negative power</td><td>a<sup>&minus;n</sup> = 1 &divide; a<sup>n</sup></td><td>2<sup>&minus;3</sup> = 1 &divide; 8</td></tr>
                        <tr><td>Fractional power</td><td>a<sup>1/n</sup> = the n-th root of a</td><td>9<sup>1/2</sup> = 3</td></tr>
                    </tbody>
                </table>
                <p><strong>Surds.</strong> A surd is a root that cannot be evaluated exactly, such as the square root of 2. The product rule for roots lets you pull out perfect squares.</p>
                <div class="formula">root(ab) = root(a) &times; root(b) &nbsp;&rarr;&nbsp; root(50) = root(25) &times; root(2) = 5 root(2)</div>
                <p><strong>Like surds add.</strong> root(50) plus root(18) simplifies to 5 root(2) plus 3 root(2), which is 8 root(2). Surds add only when the number under the root is the same.</p>
                <p><strong>Rationalising a denominator.</strong> Multiply top and bottom by the root in the denominator. For 6 divided by root(3), multiply both by root(3) to get 6 root(3) divided by 3, which is 2 root(3).</p>
                <p><strong>Comparing powers.</strong> Rewrite both sides with a common exponent or a common base. To compare 2 to the power 10 with 4 to the power 5, note that 4 is 2 squared and 4 to the power 5 becomes 2 to the power 10, so the two are equal.</p>
                <p><strong>Logarithms are the inverse of powers.</strong> log<sub>b</sub> x answers "b raised to what power gives x?". So log<sub>3</sub> 27 = 3 because 3&sup3; = 27, and log<sub>2</sub> 32 = 5 because 2<sup>5</sup> = 32. Writing the definition once removes the mystery: b<sup>log<sub>b</sub> x</sup> = x and log<sub>b</sub>(b<sup>k</sup>) = k.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Rule</th><th scope="col">Statement</th><th scope="col">Example</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Product</td><td>log<sub>b</sub>(MN) = log<sub>b</sub> M + log<sub>b</sub> N</td><td>log<sub>2</sub> 8 + log<sub>2</sub> 4 = 3 + 2 = 5 = log<sub>2</sub> 32</td></tr>
                        <tr><td>Quotient</td><td>log<sub>b</sub>(M/N) = log<sub>b</sub> M &minus; log<sub>b</sub> N</td><td>log<sub>10</sub> 1000 &minus; log<sub>10</sub> 10 = 3 &minus; 1 = 2</td></tr>
                        <tr><td>Power</td><td>log<sub>b</sub>(M<sup>k</sup>) = k &times; log<sub>b</sub> M</td><td>log<sub>3</sub> 81 = log<sub>3</sub> 3<sup>4</sup> = 4</td></tr>
                        <tr><td>Chain (telescoping)</td><td>log<sub>a</sub> b &times; log<sub>b</sub> c &times; ... = log<sub>a</sub> (last)</td><td>log<sub>a</sub> b &times; log<sub>b</sub> c &times; log<sub>c</sub> d = log<sub>a</sub> d</td></tr>
                    </tbody>
                </table>
                <p>The chain rule is change of base written as a product: each fraction log x / log (base) cancels against its neighbour, leaving only the first base and the last argument. A product that loops back on itself — log<sub>a</sub> n &times; log<sub>n</sub> a — is just 1.</p>
                <div class="callout callout-tip">
                    <strong>The rewrite habit:</strong> when two powers look hard to compare, find a common base or a common exponent and rewrite. Almost every comparison question is built so that one of the two is available.
                </div>
                <div class="callout callout-warn">
                    <strong>Roots do not distribute over addition.</strong> The square root of 9 plus 16 is 5, not 3 + 4. The product rule for roots works for multiplication only, and applying it to a sum is the most common surd error.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>Simplify root(50) plus root(18), and rationalise 6 divided by root(3).</em></p>
                <p>Simplify each root by pulling out the largest perfect square. 50 is 25 times 2, so root(50) is 5 root(2). 18 is 9 times 2, so root(18) is 3 root(2).</p>
                <div class="formula">root(50) + root(18) = 5 root(2) + 3 root(2) = 8 root(2)</div>
                <p>For the second part, multiply numerator and denominator by root(3) to clear the root from the denominator.</p>
                <div class="formula">6 &divide; root(3) = (6 root(3)) &divide; 3 = 2 root(3)</div>
                <p>Both answers are exact. A calculator gives root(50) plus root(18) as about 11.31, and 8 root(2) is also about 11.31, which confirms the simplification.</p>
                <p><strong>Logs, worked.</strong> log<sub>3</sub> 27 is the power that turns 3 into 27, which is 3. The product log<sub>a</sub> b &times; log<sub>b</sub> c &times; log<sub>c</sub> d &times; log<sub>d</sub> e &times; log<sub>e</sub> f telescopes: every intermediate base cancels, leaving log<sub>a</sub> f. A product that returns to its start — log<sub>a</sub> n &times; log<sub>n</sub> a — multiplies to 1 for the same reason.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Simplify 2<sup>3</sup> &times; 2<sup>4</sup>.</p>
                    <button class="quiz-option" data-correct="false" data-explain="64 is 2 to the power 6; the product rule adds the exponents, giving 2 to the power 7." onclick="checkQuiz('quiz-1', this)">64</button>
                    <button class="quiz-option" data-correct="true" data-explain="Same base, so add the exponents: 2 to the power of 3 + 4, which is 2 to the power 7, equal to 128." onclick="checkQuiz('quiz-1', this)">128</button>
                    <button class="quiz-option" data-correct="false" data-explain="4096 is 2 to the power 12, which comes from multiplying the exponents instead of adding them." onclick="checkQuiz('quiz-1', this)">4096</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Simplify the square root of 72.</p>
                    <button class="quiz-option" data-correct="false" data-explain="3 root 8 equals root 72, but 8 still contains the perfect square 4, so it is not fully simplified." onclick="checkQuiz('quiz-2', this)">3 root(8)</button>
                    <button class="quiz-option" data-correct="true" data-explain="72 is 36 times 2, and root 36 is 6, so the simplified form is 6 root 2." onclick="checkQuiz('quiz-2', this)">6 root(2)</button>
                    <button class="quiz-option" data-correct="false" data-explain="2 root 18 also equals root 72, but 18 still hides the perfect square 9, so it is not in simplest form." onclick="checkQuiz('quiz-2', this)">2 root(18)</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Rationalise 4 divided by root(2).</p>
                    <button class="quiz-option" data-correct="false" data-explain="root 2 is what remains after dividing by 2, not the rationalised value; the numerator must be adjusted too." onclick="checkQuiz('quiz-3', this)">root(2)</button>
                    <button class="quiz-option" data-correct="true" data-explain="Multiply top and bottom by root 2: 4 root 2 divided by 2 = 2 root 2." onclick="checkQuiz('quiz-3', this)">2 root(2)</button>
                    <button class="quiz-option" data-correct="false" data-explain="4 root 2 multiplies by root 2 but forgets to divide by the 2 left in the denominator." onclick="checkQuiz('quiz-3', this)">4 root(2)</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>Which is larger, 2<sup>10</sup> or 4<sup>5</sup>?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Rewrite 4 as 2 squared: 4 to the power 5 is 2 to the power 10, so neither is larger." onclick="checkQuiz('quiz-4', this)">2<sup>10</sup> is larger</button>
                    <button class="quiz-option" data-correct="true" data-explain="Since 4 is 2 squared, 4 to the power 5 is 2 to the power 10. The two are equal." onclick="checkQuiz('quiz-4', this)">They are equal</button>
                    <button class="quiz-option" data-correct="false" data-explain="4 to the power 5 is 2 to the power 10, so it is not larger; rewriting the base shows they match exactly." onclick="checkQuiz('quiz-4', this)">4<sup>5</sup> is larger</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-5">
                    <p>What is log<sub>3</sub> 27?</p>
                    <button class="quiz-option" data-correct="false" data-explain="9 is 3 squared times something else; log asks for the exponent, not a factor of the argument." onclick="checkQuiz('quiz-5', this)">9</button>
                    <button class="quiz-option" data-correct="true" data-explain="3 to the power 3 is 27, so log base 3 of 27 is 3." onclick="checkQuiz('quiz-5', this)">3</button>
                    <button class="quiz-option" data-correct="false" data-explain="27 would be the argument itself; the logarithm is the power you raise the base to." onclick="checkQuiz('quiz-5', this)">27</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-6">
                    <p>Simplify log<sub>a</sub> b &times; log<sub>b</sub> c &times; log<sub>c</sub> d.</p>
                    <button class="quiz-option" data-correct="false" data-explain="The product of three logs is not their sum; the bases telescope instead." onclick="checkQuiz('quiz-6', this)">log<sub>a</sub> b + log<sub>b</sub> c + log<sub>c</sub> d</button>
                    <button class="quiz-option" data-correct="true" data-explain="Change of base turns each factor into (log of arg)/(log of base); every intermediate denominator cancels the previous numerator, leaving log<sub>a</sub> d." onclick="checkQuiz('quiz-6', this)">log<sub>a</sub> d</button>
                    <button class="quiz-option" data-correct="false" data-explain="log<sub>d</sub> a is the reverse direction; the chain starts at base a and ends at argument d." onclick="checkQuiz('quiz-6', this)">log<sub>d</sub> a</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: state the product, quotient and power-of-a-power laws, and the value of any nonzero number raised to the power zero.</p>
                <p>The answers: same base multiply means add the exponents, same base divide means subtract the exponents, a power of a power means multiply the exponents, and any nonzero base to the power zero is 1.</p>
                <div id="fill-1">
                    <p>For the same base, multiplying the powers means adding the exponents, so the new exponent is the <input type="text" class="fill-blank" data-answer="sum" placeholder="?" aria-label="product law exponent" /> of m and n. A power of a power <input type="text" class="fill-blank" data-answer="multiplies" placeholder="?" aria-label="power of a power rule" /> the exponents. Any nonzero base raised to the power zero equals <input type="text" class="fill-blank" data-answer="1" placeholder="?" aria-label="zero exponent value" />. The surds root(50) and root(18) simplify to 5 root(2) and 3 root(2), so their sum is 8 root(2), with 8 outside the root and <input type="text" class="fill-blank" data-answer="2" placeholder="?" aria-label="number under the root in the sum" /> inside it. log<sub>3</sub> 27 = <input type="text" class="fill-blank" data-answer="3" placeholder="?" aria-label="log base 3 of 27" /> because 3 cubed is 27. The chain log<sub>a</sub> b &times; log<sub>b</sub> c &times; log<sub>c</sub> d equals log<sub>a</sub> <input type="text" class="fill-blank" data-answer="d" placeholder="?" aria-label="telescoped log chain result" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Which is larger, 3<sup>30</sup> or 2<sup>45</sup>? Rewrite both to compare without a calculator.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Find a common exponent. Both 30 and 45 are multiples of 15, so write each power as a fifteenth power of a new base.</p>
                    <div class="formula">3<sup>30</sup> = (3<sup>2</sup>)<sup>15</sup> = 9<sup>15</sup> &nbsp;&nbsp; and &nbsp;&nbsp; 2<sup>45</sup> = (2<sup>3</sup>)<sup>15</sup> = 8<sup>15</sup></div>
                    <p>Both are raised to the same power, 15, so the larger base decides it. Since 9 is greater than 8, <strong>3 to the power 30 is larger</strong>.</p>
                    <p>The alternative route, rewriting both with a common base, is dead here because 2 and 3 share no common base. The lesson is to look for a common exponent when the bases are unrelated, and a common base when one base is a power of the other.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Index laws are the grammar underneath algebra. The next lessons put them to work in equations and expressions, where powers move from being numbers to being variables, and where the same three rules reappear at every step.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-counting-probability">Previous: Counting and Probability</a></span>
                <span><a href="/courses/hat/lessons/hat-algebra">Next: Algebra Without Fear</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
