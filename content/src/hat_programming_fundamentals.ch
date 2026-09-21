// HAT course — Concept 20: Computing fundamentals.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_programming_fundamentals() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Computing Fundamentals — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Computing Fundamentals</h1>
            <div class="lesson-meta">20 min · Module 6: Engineering Foundations (Optional) · Foundation</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>This lesson is optional background, not a section of the HAT-1 paper. HAT-1 tests reasoning only, so nothing here is examined directly. It is included because candidates applying to computer science and software engineering programmes often want their first-course computing material refreshed before graduate study, and because number systems and Boolean logic sharpen the quantitative and analytical reasoning the test does examine.</p>
                <p>These questions are the most predictable on the whole paper. There are only a few topics, each has one standard method, and the answers can be verified by hand. The marks are there to be taken, and the way to lose them is to have never converted a binary number under a clock.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three operations cover most of this area. Learn them as procedures, not as facts.</p>
                <ol>
                    <li><strong>Base conversion:</strong> write place values, multiply and add.</li>
                    <li><strong>Code tracing:</strong> keep a table with one column per variable and one row per iteration.</li>
                    <li><strong>Boolean evaluation:</strong> reduce one operator at a time, writing the intermediate result.</li>
                </ol>
                <p>Every one of these has a visible working, which is why these questions reward method more than insight. Do the working on paper even when the answer feels obvious.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Number systems.</strong> Binary is base 2, octal base 8, decimal base 10, hexadecimal base 16. The place values are powers of the base, starting at the right with the base to the power zero.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Binary</th><th scope="col">Place values</th><th scope="col">Decimal</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1011</td><td>8 + 0 + 2 + 1</td><td>11</td></tr>
                        <tr><td>1111</td><td>8 + 4 + 2 + 1</td><td>15</td></tr>
                        <tr><td>10000000</td><td>2<sup>7</sup></td><td>128</td></tr>
                    </tbody>
                </table>
                <p>Hexadecimal covers exactly four binary bits per digit, which is why it is everywhere in computing: 0 to 9 then A to F, where A is 10 and F is 15. So <em>FF</em> is 15 &times; 16 + 15, which is 255, the largest value in one byte.</p>
                <p>Converting decimal to binary means repeated division by two, reading the remainders upwards. Converting back means adding the place values where a 1 appears.</p>
                <p><strong>Data and storage units.</strong> A bit is one binary digit, a byte is 8 bits, a kilobyte is 1024 bytes, a megabyte is 1024 kilobytes, and so on in powers of 1024. A byte can hold 256 distinct values, so it represents unsigned numbers from 0 to 255, or signed numbers from &minus;128 to 127 in the usual twos-complement convention.</p>
                <p><strong>Control flow and tracing.</strong> A <em>for</em> loop repeats a known number of times; a <em>while</em> loop repeats while a condition holds and can run forever if the condition never changes. To trace either, tabulate the variables after each iteration rather than trying to follow the whole run in your head — off-by-one errors and accumulated sums are exactly what the table exposes.</p>
                <pre>sum = 0
for i = 1 to 4:
    sum = sum + i</pre>
                <p>After i = 1 the sum is 1, after 2 it is 3, after 3 it is 6, and after 4 it is 10. The final value is 10, not 4 &times; something and not 1 + 2 + 3 + 4 + 4.</p>
                <p><strong>Arrays and indexing.</strong> Most languages number array elements from zero, so the first element is at index 0 and the last of an array of size n is at index n &minus; 1. Many exam questions are built entirely on this convention.</p>
                <p><strong>Boolean logic.</strong> AND is true only when both inputs are true, OR is true when at least one is, and NOT inverts. Since AND binds more tightly than OR, the expression A OR B AND C groups as A OR (B AND C). Where the question uses brackets, evaluate inside first.</p>
                <p><strong>Algorithm basics.</strong> Linear search checks elements one by one and needs up to n comparisons; binary search on sorted data halves the range each time and needs about log&#8322;(n) steps, so a thousand items take roughly ten comparisons instead of a thousand. Bubble sort and insertion sort are simple but slow on large inputs, while merge sort is faster because it divides the work. Questions at this level ask for the number of steps or for which algorithm is appropriate, not for proofs.</p>
                <div class="callout callout-warn">
                    <strong>Watch for the off-by-one trap.</strong> "Repeats 1 to n" includes both ends and runs n times; "i &lt; n" starting from 0 runs n times; "i &lt;= n" starting from 0 runs n + 1 times. Write the first two iterations before you commit to an answer.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>Trace the loop: total = 0; for i = 1 to 4; total = total + (i &times; i); print total.</em></p>
                <p>Rather than following the code in your head, build the table.</p>
                <table>
                    <thead>
                        <tr><th scope="col">i</th><th scope="col">i &times; i</th><th scope="col">total after</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1</td><td>1</td><td>1</td></tr>
                        <tr><td>2</td><td>4</td><td>5</td></tr>
                        <tr><td>3</td><td>9</td><td>14</td></tr>
                        <tr><td>4</td><td>16</td><td>30</td></tr>
                    </tbody>
                </table>
                <p>The answer is 30, the sum of the first four squares. The table is the method: each row depends only on the row above, so a mistake is located immediately rather than discovered at the end when no option matches.</p>
                <p>Notice also what the table protects against. The two common wrong answers are 16, from reading only the final value of i &times; i, and 10, from summing the values of i instead of their squares. Both come from losing track mid-trace, which a table makes impossible.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What is the binary number 1101 in decimal?</p>
                    <button class="quiz-option" data-correct="false" data-explain="12 is 1100 in binary; the last place value of 1 has been dropped." onclick="checkQuiz('quiz-1', this)">12</button>
                    <button class="quiz-option" data-correct="true" data-explain="The place values are 8, 4, 2 and 1, and 8 + 4 + 1 is 13, since the twos place is zero." onclick="checkQuiz('quiz-1', this)">13</button>
                    <button class="quiz-option" data-correct="false" data-explain="11 is 1011 in binary. Reading binary means adding place values, not reading the digits as a decimal number." onclick="checkQuiz('quiz-1', this)">11</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>What is the hexadecimal number 2A in decimal?</p>
                    <button class="quiz-option" data-correct="true" data-explain="The first digit is worth 2 times 16, and A is 10, so 32 + 10 is 42." onclick="checkQuiz('quiz-2', this)">42</button>
                    <button class="quiz-option" data-correct="false" data-explain="2 + 10 is 12, but the first hexadecimal digit is worth sixteen times its value, not one times." onclick="checkQuiz('quiz-2', this)">12</button>
                    <button class="quiz-option" data-correct="false" data-explain="26 treats A as 10 without multiplying the first digit by the base of 16." onclick="checkQuiz('quiz-2', this)">26</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>An array has 10 elements and is indexed from 0. Which index holds the last element?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Index 10 is one past the final element; that is the classic off-by-one error." onclick="checkQuiz('quiz-3', this)">Index 10</button>
                    <button class="quiz-option" data-correct="true" data-explain="With zero-based indexing the last of n elements sits at index n minus 1, so the last of ten elements is index 9." onclick="checkQuiz('quiz-3', this)">Index 9</button>
                    <button class="quiz-option" data-correct="false" data-explain="Index 0 is the first element, not the last." onclick="checkQuiz('quiz-3', this)">Index 0</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: how many distinct values can one byte hold, and why do programmers use hexadecimal at all?</p>
                <p>The answer is: 256 values, from 0 to 255 unsigned; and because each hexadecimal digit maps exactly onto four binary bits, so it writes binary compactly without ambiguity.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>Binary is base <input type="text" class="fill-blank" data-answer="2" placeholder="?" aria-label="base of binary" />, and hexadecimal is base <input type="text" class="fill-blank" data-answer="16" placeholder="?" aria-label="base of hexadecimal" />. One byte contains <input type="text" class="fill-blank" data-answer="8" placeholder="?" aria-label="bits in a byte" /> bits. In a zero-based array of size n, the last valid index is n minus <input type="text" class="fill-blank" data-answer="1" placeholder="?" aria-label="offset for the last index" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Write out ten conversions by hand, five binary to decimal and five decimal to binary, then the same for hexadecimal. Time yourself on the second set.</p>
                <details>
                    <summary>Drills that cover the likely questions</summary>
                    <p>Convert 1011, 11001, 11111111, 100101 and 10101010 to decimal. Convert 9, 21, 64, 100 and 200 to binary, by repeated division by two.</p>
                    <p>Then convert FF, 1A, 80 and C7 to decimal, and check each against its binary form: C7 is 1100 0111, which is 199. Working in both directions cements the relationship between four bits and one hexadecimal digit, and that relationship is what most questions in this area actually test.</p>
                    <p>Finally, trace the sum loop from this lesson but with a twist: start the total at 10 and loop i from 2 to 5 adding i &times; i. Build the table first, then compare your result with a direct addition. If the two agree, your tracing procedure is reliable; if they disagree, the table shows you where it went wrong, which is the entire reason for the table.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Computing fundamentals and digital logic overlap more than candidates expect. Gates are the physical layer beneath everything in this lesson, and the final concept covers them along with the small set of standard results that most questions in that area reuse.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-physics-mechanics">Previous: Physics and Mechanics</a></span>
                <span><a href="/courses/hat/lessons/hat-digital-logic">Next: Digital Logic and Circuit Basics</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
