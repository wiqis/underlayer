// HAT course  -  Sequences and series: arithmetic and geometric patterns and their sums.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_sequences() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Sequences and Series - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Sequences and Series</h1>
            <div class="lesson-meta">15 min &middot; Module 2: Quantitative Reasoning &middot; Algebra</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Sequence questions look like puzzles, but they are formula work. Two patterns cover almost every exam item: arithmetic (a fixed amount added each step) and geometric (a fixed factor multiplied each step). Both are described completely by two numbers  -  a starting value and the step  -  and once you have those, a later term, a running total and even an infinite sum are a single substitution.</p>
                <p>The trap is speed, not difficulty. Under time pressure, candidates add the terms one by one for a question the formula answers in ten seconds.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <ul>
                    <li><strong>A sequence is an ordered list; a series is its sum.</strong> The same numbers, two different questions.</li>
                    <li><strong>Arithmetic means constant difference.</strong> Each term is the previous term plus a fixed d, so the terms grow in a straight line.</li>
                    <li><strong>Geometric means constant ratio.</strong> Each term is the previous term multiplied by a fixed r, so growth is explosive or decaying.</li>
                    <li><strong>Differences reveal the type.</strong> Subtract consecutive terms: if the answers are constant, it is arithmetic. Divide consecutive terms: if that is constant, it is geometric.</li>
                </ul>
                <p>The model omits patterns that are neither type, such as squares (1, 4, 9, 16) or second differences. These need their own recognition, but they are rare compared with the two standard families.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Arithmetic sequences</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Quantity</th><th scope="col">Formula</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>First term</td><td>a</td></tr>
                        <tr><td>Common difference</td><td>d = any term &minus; previous term</td></tr>
                        <tr><td>nth term</td><td>a + (n &minus; 1)d</td></tr>
                        <tr><td>Sum of n terms</td><td>(n &divide; 2) &times; (2a + (n &minus; 1)d)</td></tr>
                        <tr><td>Sum of n terms with last term l</td><td>(n &divide; 2) &times; (a + l)</td></tr>
                    </tbody>
                </table>
                <h3>Geometric sequences</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Quantity</th><th scope="col">Formula</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>First term</td><td>a</td></tr>
                        <tr><td>Common ratio</td><td>r = any term &divide; previous term</td></tr>
                        <tr><td>nth term</td><td>a &times; r^(n &minus; 1)</td></tr>
                        <tr><td>Sum of n terms (r &ne; 1)</td><td>a &times; (r^n &minus; 1) &divide; (r &minus; 1)</td></tr>
                        <tr><td>Sum to infinity (|r| &lt; 1)</td><td>a &divide; (1 &minus; r)</td></tr>
                    </tbody>
                </table>
                <p>Notice the shared skeleton: both nth-term formulas use (n &minus; 1) steps from the first term, because the first term is already at n = 1.</p>
                <div class="callout callout-tip">
                    <strong>Identify before you compute.</strong> Write a, then d (or r), then n. Most mistakes happen because one of those three was read wrongly, not because the substitution was hard.
                </div>
                <div class="callout callout-warn">
                    <strong>Traps.</strong> (1) Using a + nd instead of a + (n &minus; 1)d  -  the off-by-one. (2) Confusing the nth term with the sum of n terms. (3) Applying the infinite sum a &divide; (1 &minus; r) when |r| &ge; 1, where the series does not converge. (4) Assuming a ratio must be greater than 1; r may be a fraction like 1/2 or a negative number.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <h3>Arithmetic: 7, 11, 15, ...</h3>
                <p>a = 7 and d = 4. The 20th term is a + (n &minus; 1)d = 7 + 19 &times; 4 = 7 + 76 = <strong>83</strong>.</p>
                <p>The sum of the first 20 terms is (n &divide; 2)(2a + (n &minus; 1)d) = 10 &times; (14 + 76) = 10 &times; 90 = <strong>900</strong>. Check with the last term: 10 &times; (7 + 83) = 10 &times; 90 = 900.</p>
                <h3>Geometric: 3, 6, 12, ...</h3>
                <p>a = 3 and r = 2. The 6th term is 3 &times; 2^5 = 3 &times; 32 = <strong>96</strong>.</p>
                <p>The sum of the first 6 terms is 3 &times; (2^6 &minus; 1) &divide; (2 &minus; 1) = 3 &times; 63 = <strong>189</strong>. Adding directly confirms it: 3 + 6 + 12 + 24 + 48 + 96 = 189.</p>
                <h3>Infinite geometric: 8 + 4 + 2 + ...</h3>
                <p>a = 8 and r = 1/2, and |r| &lt; 1, so the sum is 8 &divide; (1 &minus; 1/2) = 8 &divide; 0.5 = <strong>16</strong>.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What is the 15th term of the arithmetic sequence 5, 9, 13, ...?</p>
                    <button class="quiz-option" data-correct="true" data-explain="a = 5, d = 4, so the 15th term is 5 + 14 &times; 4 = 61." onclick="checkQuiz('quiz-1', this)">61</button>
                    <button class="quiz-option" data-correct="false" data-explain="65 comes from using 15 steps, 5 + 15 &times; 4; the first term is already step zero, so the multiplier is 14." onclick="checkQuiz('quiz-1', this)">65</button>
                    <button class="quiz-option" data-correct="false" data-explain="57 comes from 13 &times; 4 + 5; the sequence starts at 5, not at 1." onclick="checkQuiz('quiz-1', this)">57</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>What is the sum of the first 10 even numbers, 2 + 4 + 6 + ... + 20?</p>
                    <button class="quiz-option" data-correct="true" data-explain="a = 2, d = 2, n = 10, so S = 5 &times; (4 + 18) = 110. The last term is 20, so 5 &times; (2 + 20) = 110." onclick="checkQuiz('quiz-2', this)">110</button>
                    <button class="quiz-option" data-correct="false" data-explain="100 would be the sum of the first 10 odd numbers or a pairing slip; here averaging 2 and 20 gives 11, times 10 is 110." onclick="checkQuiz('quiz-2', this)">100</button>
                    <button class="quiz-option" data-correct="false" data-explain="90 undercounts; the 10 terms run from 2 to 20, not from 2 to 18." onclick="checkQuiz('quiz-2', this)">90</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>What is the 5th term of the geometric sequence 2, 6, 18, ...?</p>
                    <button class="quiz-option" data-correct="true" data-explain="a = 2 and r = 3, so the 5th term is 2 &times; 3^4 = 2 &times; 81 = 162." onclick="checkQuiz('quiz-3', this)">162</button>
                    <button class="quiz-option" data-correct="false" data-explain="54 is the 4th term, 2 &times; 3^3; the 5th term needs four multiplications, not three." onclick="checkQuiz('quiz-3', this)">54</button>
                    <button class="quiz-option" data-correct="false" data-explain="486 is the 6th term; it applies one extra multiplication by 3." onclick="checkQuiz('quiz-3', this)">486</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>What is the sum to infinity of 12 + 6 + 3 + ...?</p>
                    <button class="quiz-option" data-correct="true" data-explain="a = 12 and r = 1/2, so the sum is 12 &divide; (1 &minus; 1/2) = 12 &divide; 0.5 = 24." onclick="checkQuiz('quiz-4', this)">24</button>
                    <button class="quiz-option" data-correct="false" data-explain="18 is only the sum of the first three terms; the remaining terms add another 6." onclick="checkQuiz('quiz-4', this)">18</button>
                    <button class="quiz-option" data-correct="false" data-explain="36 would correspond to r = 2/3; here the ratio is one half, so the total is smaller." onclick="checkQuiz('quiz-4', this)">36</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: write the nth term of an arithmetic sequence and the condition under which a geometric series has a finite sum.</p>
                <p>The nth term is a + (n &minus; 1)d; a geometric series converges to a finite sum only when |r| &lt; 1.</p>
                <div id="fill-1">
                    <p>In an arithmetic sequence the fixed step is called the common <input type="text" class="fill-blank" data-answer="difference" placeholder="?" aria-label="fixed step in an arithmetic sequence" />, and in a geometric sequence it is called the common <input type="text" class="fill-blank" data-answer="ratio" placeholder="?" aria-label="fixed step in a geometric sequence" />. A geometric series has a finite sum only when the absolute value of the ratio is less than <input type="text" class="fill-blank" data-answer="1" placeholder="?" aria-label="convergence bound on the ratio" />. For the arithmetic sequence 3, 7, 11, ... the 10th term is <input type="text" class="fill-blank" data-answer="39" placeholder="?" aria-label="tenth term of three seven eleven" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>In an arithmetic sequence the 3rd term is 10 and the 8th term is 25. Find the first term, the common difference, and the sum of the first 20 terms.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Use the nth-term formula twice. The 3rd term gives a + 2d = 10 and the 8th gives a + 7d = 25.</p>
                    <p>Subtract the first equation from the second: (a + 7d) &minus; (a + 2d) = 25 &minus; 10, so 5d = 15 and d = 3.</p>
                    <p>Substitute back: a + 2 &times; 3 = 10, so a = 4. Check the 8th term: 4 + 7 &times; 3 = 25, as required.</p>
                    <p>The sum of the first 20 terms is (20 &divide; 2)(2 &times; 4 + 19 &times; 3) = 10 &times; (8 + 57) = 10 &times; 65 = <strong>650</strong>.</p>
                    <p>What this exposes: two pieces of information fix both unknowns, because each term is one equation in a and d. That is the general method whenever the formula has two constants.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Sequences describe one quantity changing step by step. The next lesson changes the setting entirely: measurements of flat shapes and solids, where the arithmetic is short but the choice of formula and the units decide the answer.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-quadratic-equations">Previous: Quadratic Equations</a></span>
                <span><a href="/courses/hat/lessons/hat-geometry">Next: Geometry and Measurement</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
