// HAT course — Number properties: divisibility, primes, LCM/HCF, remainders, units digits.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_number_properties() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Number Properties — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Number Properties: Divisibility, Primes, HCF and LCM</h1>
            <div class="lesson-meta">15 min · Module 2: Quantitative Reasoning · Number sense</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Some quantitative questions are not calculations at all. They ask whether a number is divisible by 9, what digit a large power ends in, how many multiples of 7 sit between 100 and 500, or what the smallest number is that both 84 and 126 divide into evenly. All four are answerable in under thirty seconds by rules, and in three minutes by brute force — which is the same as not answerable at all under a 72-second clock.</p>
                <p>Number properties also power everything downstream: simplifying a ratio, comparing two fractions, and cancelling inside an algebra fraction all depend on seeing factors quickly.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three ideas cover almost every question in this family.</p>
                <ul>
                    <li><strong>Everything is built from primes.</strong> Any integer factors uniquely into primes, so divisibility, HCF and LCM are all questions about prime exponents.</li>
                    <li><strong>Divisibility is a test, not a division.</strong> Each small divisor has a cheap digit rule, so you never need to actually divide.</li>
                    <li><strong>Remainders wrap around.</strong> Remainders repeat in cycles, so the last digit of a large power is found by finding where the exponent lands in the cycle.</li>
                </ul>
                <div class="formula">N = 2<sup>a</sup> &times; 3<sup>b</sup> &times; 5<sup>c</sup> &times; &hellip; &nbsp;&nbsp; HCF takes the smallest exponents, LCM takes the largest</div>
                <p>The model is incomplete in one practical way: prime factorisation is the slow method. The fast method is the digit rules in the next unit, and the two must be used together.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Divisibility rules</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Divisor</th><th scope="col">Test</th><th scope="col">Example</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>2</td><td>Last digit is even</td><td>4,718 is even, 4,717 is not</td></tr>
                        <tr><td>3</td><td>Digit sum is a multiple of 3</td><td>4,812: 4+8+1+2 = 15, so yes</td></tr>
                        <tr><td>4</td><td>Last two digits form a multiple of 4</td><td>7,116: 16 is a multiple of 4, so yes</td></tr>
                        <tr><td>5</td><td>Ends in 0 or 5</td><td>2,445 ends in 5</td></tr>
                        <tr><td>6</td><td>Divisible by 2 and by 3</td><td>4,812 is even and digit-sum 15, so yes</td></tr>
                        <tr><td>8</td><td>Last three digits form a multiple of 8</td><td>9,024: 024 is 24, so yes</td></tr>
                        <tr><td>9</td><td>Digit sum is a multiple of 9</td><td>4,815: 4+8+1+5 = 18, so yes</td></tr>
                        <tr><td>10</td><td>Ends in 0</td><td>13,470</td></tr>
                        <tr><td>11</td><td>Alternating digit sum is a multiple of 11 (including 0)</td><td>4,732: (2+7) &minus; (3+4) = 2, so no</td></tr>
                    </tbody>
                </table>
                <h3>Primes and the numbers around them</h3>
                <p>Primes below 50: 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47. Two facts people lose marks on: <strong>1 is not prime</strong>, and <strong>2 is the only even prime</strong>.</p>
                <p>Squares worth knowing cold: 11&sup2; = 121, 12&sup2; = 144, 13&sup2; = 169, 14&sup2; = 196, 15&sup2; = 225, 16&sup2; = 256, 17&sup2; = 289, 18&sup2; = 324, 19&sup2; = 361, 20&sup2; = 400, 21&sup2; = 441, 22&sup2; = 484, 23&sup2; = 529, 24&sup2; = 576, 25&sup2; = 625. Cubes: 3&sup3; = 27, 4&sup3; = 64, 5&sup3; = 125, 6&sup3; = 216, 7&sup3; = 343, 8&sup3; = 512, 9&sup3; = 729, 10&sup3; = 1000, 11&sup3; = 1331, 12&sup3; = 1728.</p>
                <h3>HCF and LCM</h3>
                <div class="formula">HCF &times; LCM = product of the two numbers &nbsp;(for any two positive integers)</div>
                <p>Example: 84 = 2&sup2; &times; 3 &times; 7 and 126 = 2 &times; 3&sup2; &times; 7, so HCF = 2 &times; 3 &times; 7 = 42 and LCM = 2&sup2; &times; 3&sup2; &times; 7 = 252. Check with the identity: 42 &times; 252 = 10,584 and 84 &times; 126 = 10,584.</p>
                <p>Useful consequences: if two numbers are coprime, their LCM is simply their product; and a number divisible by both 6 and 4 must be divisible by 12 (the LCM, not the product 24).</p>
                <h3>Remainders and units digits</h3>
                <ul>
                    <li><strong>Counting multiples.</strong> Multiples of k from a to b: divide b by k, divide a &minus; 1 by k, subtract, and take the whole parts.</li>
                    <li><strong>Units digits cycle in fours.</strong> The last digit of powers of 7 runs 7, 9, 3, 1 and repeats; for 2 it runs 2, 4, 8, 6; for 3 it runs 3, 9, 7, 1; for 8 it runs 8, 4, 2, 6. Find the exponent's position in the cycle.</li>
                    <li><strong>Remainder arithmetic.</strong> You may add, subtract and multiply remainders and reduce at the end: the remainder of a product is the product of the remainders, reduced again.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>The 30-second habit:</strong> before any arithmetic on integers, glance at the options' last digits and the numbers' parity. If the options end in different digits, the units digit of the answer is your whole method.
                </div>
                <div class="callout callout-warn">
                    <strong>Three repeated traps.</strong> (1) Treating 1 as prime. (2) Using the product instead of the LCM when two divisors overlap — 6 and 4 overlap at 2. (3) Off-by-one in range counting: "between 100 and 500" excludes both endpoints' multiples unless stated, so subtract floor(99 &divide; k), not floor(100 &divide; k).
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. Is 4,835 divisible by 9?</h3>
                <p>Digit sum: 4+8+3+5 = 20. 20 is not a multiple of 9, so no. Note that the same sum tells you the remainder when divided by 9 is 2 — useful immediately.</p>
                <h3>2. What is the units digit of 7<sup>43</sup>?</h3>
                <p>The cycle for 7 is 7, 9, 3, 1, length 4. Divide the exponent by 4: 43 leaves remainder 3, so take the third element of the cycle: <strong>3</strong>. (Check with a small case: 7&sup3; = 343, which ends in 3.)</p>
                <h3>3. How many multiples of 7 lie between 100 and 500?</h3>
                <p>Whole part of 500 &divide; 7 is 71 (7 &times; 71 = 497). Whole part of 99 &divide; 7 is 14 (7 &times; 14 = 98). 71 &minus; 14 = <strong>57</strong>.</p>
                <h3>4. Two bells ring every 84 seconds and every 126 seconds. They ring together; how long until they ring together again?</h3>
                <p>This asks for the LCM: 252 seconds, which is 4 minutes 12 seconds. The distractor set will include 10,584 (the product) and 42 (the HCF).</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Which of these numbers is divisible by 9?</p>
                    <button class="quiz-option" data-correct="false" data-explain="4,821 has digit sum 15, which is a multiple of 3 but not of 9." onclick="checkQuiz('quiz-1', this)">4,821</button>
                    <button class="quiz-option" data-correct="true" data-explain="4,815 has digit sum 4+8+1+5 = 18, and 18 is a multiple of 9." onclick="checkQuiz('quiz-1', this)">4,815</button>
                    <button class="quiz-option" data-correct="false" data-explain="4,813 has digit sum 16, which is neither a multiple of 3 nor of 9." onclick="checkQuiz('quiz-1', this)">4,813</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>What is the units digit of 2<sup>35</sup>?</p>
                    <button class="quiz-option" data-correct="false" data-explain="The cycle for powers of 2 is 2, 4, 8, 6 with length 4; 35 leaves remainder 3, so the third element 8 is the answer, not 2." onclick="checkQuiz('quiz-2', this)">2</button>
                    <button class="quiz-option" data-correct="true" data-explain="2, 4, 8, 6 repeats every four powers and 35 leaves remainder 3, so the units digit is the third element, 8." onclick="checkQuiz('quiz-2', this)">8</button>
                    <button class="quiz-option" data-correct="false" data-explain="6 corresponds to remainder 0 in the cycle, which happens for exponents divisible by 4, not for 35." onclick="checkQuiz('quiz-2', this)">6</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>The HCF of two numbers is 6 and their LCM is 60. What is their product?</p>
                    <button class="quiz-option" data-correct="false" data-explain="10 is the LCM divided by the HCF, which is not a product of the numbers." onclick="checkQuiz('quiz-3', this)">10</button>
                    <button class="quiz-option" data-correct="true" data-explain="HCF &times; LCM equals the product for any two positive integers, so 6 &times; 60 = 360." onclick="checkQuiz('quiz-3', this)">360</button>
                    <button class="quiz-option" data-correct="false" data-explain="66 is HCF + LCM, which has no meaning in number theory and is offered here as a trap." onclick="checkQuiz('quiz-3', this)">66</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>A number leaves remainder 3 when divided by 7. What remainder does its square leave when divided by 7?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Squaring the remainder gives 9, and 9 exceeds the divisor, so it must be reduced: 9 &minus; 7 = 2." onclick="checkQuiz('quiz-4', this)">9</button>
                    <button class="quiz-option" data-correct="true" data-explain="Remainders may be multiplied and then reduced: 3 &times; 3 = 9, and 9 leaves remainder 2 on division by 7." onclick="checkQuiz('quiz-4', this)">2</button>
                    <button class="quiz-option" data-correct="false" data-explain="6 would come from 3 &times; 2, which is unrelated; the square uses the remainder twice." onclick="checkQuiz('quiz-4', this)">6</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: state the divisibility test for 9, and the identity that connects HCF, LCM and the two numbers.</p>
                <p>The answer: the digit sum must be a multiple of 9; and HCF &times; LCM equals the product of the two numbers.</p>
                <div id="fill-1">
                    <p>A number is divisible by 9 exactly when its <input type="text" class="fill-blank" data-answer="digit sum" placeholder="?" aria-label="divisibility test for nine" /> is a multiple of 9. For any two positive integers, HCF &times; LCM equals their <input type="text" class="fill-blank" data-answer="product" placeholder="?" aria-label="identity with HCF and LCM" />. The number 1 is <input type="text" class="fill-blank" data-answer="not" placeholder="?" aria-label="is one prime" /> prime, and the only even prime is <input type="text" class="fill-blank" data-answer="2" placeholder="?" aria-label="only even prime" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A question asks: "What is the smallest number that is divisible by each of 12, 15 and 18?" Work out the answer and name the distractor you expect beside it.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Factorise: 12 = 2&sup2; &times; 3, 15 = 3 &times; 5, 18 = 2 &times; 3&sup2;. The LCM takes the largest exponent of each prime: 2&sup2; &times; 3&sup2; &times; 5 = <strong>180</strong>.</p>
                    <p>The expected distractors: 3,240 (the product, from forgetting that the numbers share factors), 3 (the common factor, confusing LCM with HCF), and 540 (three times the LCM, from an arithmetic slip during factorisation).</p>
                    <p>Checking the answer in five seconds: 180 &divide; 12 = 15, 180 &divide; 15 = 12, 180 &divide; 18 = 10 — all whole numbers, and no smaller multiple passes all three tests, because 90 fails on 12.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You can now decide divisibility, factor and count without dividing. The next lesson puts factorisation to work on the most common quantitative material of all: fractions, decimals and the conversions between fractions, decimals and percentages.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-arithmetic">Previous: Arithmetic You Can Do in Your Head</a></span>
                <span><a href="/courses/hat/lessons/hat-fractions-decimals">Next: Fractions, Decimals and Percentages</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
