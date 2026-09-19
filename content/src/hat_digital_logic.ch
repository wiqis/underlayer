// HAT course — Concept 21: Digital logic and circuit basics.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_digital_logic() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Digital Logic and Circuit Basics — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Digital Logic and Circuit Basics</h1>
            <div class="lesson-meta">18 min · Module 5: Subject — Engineering and Computing · Foundation</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Digital logic sits directly beneath the number systems and programming you have just covered: gates are what add binary numbers, and Boolean expressions are what conditions in code compile down to. For computing, electronics and electrical candidates it is the most likely place for a short, self-contained numerical question.</p>
                <p>It is also the fairest topic on the paper. Logic has no interpretation, no vocabulary and no estimation. Given the inputs and the gate, there is exactly one output, and given the truth table, exactly one answer — which means these marks depend only on knowing five gate definitions and two laws.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Work in truth tables for circuit questions and in algebraic identities for expression questions.</p>
                <ol>
                    <li><strong>Count the inputs</strong> and write every combination: two inputs give four rows, three inputs give eight.</li>
                    <li><strong>Evaluate inner gates first</strong> and add one column per gate, left to right.</li>
                    <li><strong>For expression questions,</strong> apply De Morgan's laws and absorption instead of drawing the circuit.</li>
                </ol>
                <p>Writing a column per gate is why these questions are reliable. Every column depends only on the columns to its left, so there is no point at which you are holding intermediate results in your head, and any error is visible on the page.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Truth tables for the five gates.</strong> The output is a 1 only in the row where the gate's condition is satisfied.</p>
                <table>
                    <thead>
                        <tr><th scope="col">A</th><th scope="col">B</th><th scope="col">AND</th><th scope="col">OR</th><th scope="col">NAND</th><th scope="col">NOR</th><th scope="col">XOR</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>0</td><td>0</td><td>0</td><td>1</td><td>1</td><td>0</td></tr>
                        <tr><td>0</td><td>1</td><td>0</td><td>1</td><td>1</td><td>0</td><td>1</td></tr>
                        <tr><td>1</td><td>0</td><td>0</td><td>1</td><td>1</td><td>0</td><td>1</td></tr>
                        <tr><td>1</td><td>1</td><td>1</td><td>1</td><td>0</td><td>0</td><td>0</td></tr>
                    </tbody>
                </table>
                <p>AND outputs a 1 only when both inputs are 1. OR outputs a 1 when at least one input is 1. NOT inverts a single input. NAND and NOR are the negations of AND and OR, so their columns are simply inverted. XOR, the exclusive OR, outputs a 1 when the inputs <em>differ</em> — and that is the column worth memorising separately, because it is the one used in addition.</p>
                <p><strong>De Morgan's laws</strong> convert between AND and OR under negation. They are the most commonly tested identities in the whole topic.</p>
                <div class="formula">NOT(A AND B) = (NOT A) OR (NOT B) &nbsp;&nbsp;·&nbsp;&nbsp; NOT(A OR B) = (NOT A) AND (NOT B)</div>
                <p>Read them as a rule rather than a formula: negate each input, and the gate flips. This is exactly what a compiler does when it rewrites a condition such as "if not (x &gt; 0 and y &gt; 0)" into "if x &le; 0 or y &le; 0", which is why the law shows up in programming as well as in circuit questions.</p>
                <p><strong>Useful simplifications.</strong> A AND 0 is 0, A AND 1 is A, A OR 0 is A, A OR 1 is 1, A OR (NOT A) is 1, A AND (NOT A) is 0, and A OR (A AND B) is A. This last one, absorption, looks like it should be more complicated than it is: if A is true the whole expression is true regardless of B, and if A is false both terms are false.</p>
                <p><strong>NAND and NOR are universal gates.</strong> Either one alone can build every other gate, so a single gate type suffices to construct any circuit. Questions often ask which gate is universal, and both NAND and NOR are correct answers to that wording.</p>
                <p><strong>Addition is the standard application.</strong> The half adder takes two single bits and produces a sum and a carry.</p>
                <div class="formula">sum = A XOR B &nbsp;&nbsp;·&nbsp;&nbsp; carry = A AND B</div>
                <p>The sum bit is 1 when the two bits differ, which is exactly XOR, and the carry is 1 only when both are 1, which is AND. A full adder handles a carry coming in as well, and is built from two half adders combined with an OR gate — which is how the whole chain from gates to arithmetic is closed.</p>
                <div class="callout callout-tip">
                    <strong>Check XOR against ordinary addition.</strong> In 1 + 1 the digit is 0 and 1 carries over, and XOR gives 0 for two equal inputs while the AND gives the carry. The two outputs together reproduce binary addition exactly, so if a question confuses the sum and carry rows, going back to 1 + 1 settles it in seconds.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>Simplify: Y = A AND (NOT A OR B).</em></p>
                <p>Distribute the AND over the OR: Y = (A AND NOT A) OR (A AND B). The first term is 0, because a value cannot be both true and false. So Y = 0 OR (A AND B), which is <strong>A AND B</strong>.</p>
                <p>The truth table confirms it in four rows. With A = 0 the whole expression is 0 immediately, whatever B is, because the outer gate is AND. With A = 1 the bracket becomes 0 OR B, which is just B, so the output equals B. So the output is 1 only when A is 1 and B is 1 — which is exactly A AND B.</p>
                <p>The second route is worth having because it is what a question is usually testing: the expression is written to look complicated, and the simplification is two lines. Note also that the truth table gave the same answer by a completely different method, which is the general safety net for this topic — if the algebra is not coming, four rows always work.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>When does an XOR gate output a 1?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Both inputs being 1 makes XOR output 0, because XOR is the exclusive OR." onclick="checkQuiz('quiz-1', this)">When both inputs are 1</button>
                    <button class="quiz-option" data-correct="true" data-explain="XOR is 1 when the inputs differ, that is for the rows 0,1 and 1,0." onclick="checkQuiz('quiz-1', this)">When the two inputs differ</button>
                    <button class="quiz-option" data-correct="false" data-explain="Both inputs 0 gives 0 for XOR. That is the row where no input is true." onclick="checkQuiz('quiz-1', this)">When both inputs are 0</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Apply De Morgan's law to NOT(A AND B).</p>
                    <button class="quiz-option" data-correct="false" data-explain="That is the original expression. De Morgan flips the gate and negates each input." onclick="checkQuiz('quiz-2', this)">NOT A AND NOT B</button>
                    <button class="quiz-option" data-correct="true" data-explain="Negating each input and flipping AND to OR gives (NOT A) OR (NOT B)." onclick="checkQuiz('quiz-2', this)">(NOT A) OR (NOT B)</button>
                    <button class="quiz-option" data-correct="false" data-explain="A AND B is the negation of this expression, not its equivalent." onclick="checkQuiz('quiz-2', this)">A AND B</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>In a half adder, which gate produces the carry output?</p>
                    <button class="quiz-option" data-correct="false" data-explain="XOR produces the sum bit, which is 1 when the inputs differ." onclick="checkQuiz('quiz-3', this)">XOR</button>
                    <button class="quiz-option" data-correct="true" data-explain="AND produces the carry, because a carry occurs only when both bits are 1, as in 1 + 1." onclick="checkQuiz('quiz-3', this)">AND</button>
                    <button class="quiz-option" data-correct="false" data-explain="A NOT gate has a single input and cannot produce the carry of two bits." onclick="checkQuiz('quiz-3', this)">NOT</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: state both of De Morgan's laws, and give the two outputs of a half adder in terms of the input bits.</p>
                <p>The answer is: NOT(A AND B) equals (NOT A) OR (NOT B), and NOT(A OR B) equals (NOT A) AND (NOT B); the sum is A XOR B and the carry is A AND B.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>A gate that can be used to build every other gate is called a <input type="text" class="fill-blank" data-answer="universal" placeholder="?" aria-label="gate that builds all others" /> gate, and both NAND and <input type="text" class="fill-blank" data-answer="NOR" placeholder="?" aria-label="the other universal gate" /> qualify. In a half adder the sum bit is produced by an <input type="text" class="fill-blank" data-answer="XOR" placeholder="?" aria-label="gate producing the sum bit" /> gate.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Build the truth table for a full adder: inputs A, B and a carry-in C, with a sum output and a carry-out output. Then verify one row by hand arithmetic.</p>
                <details>
                    <summary>The method and the check</summary>
                    <p>Three inputs give eight rows. For each row, work the first half adder on A and B to get s1 and c1, then the second half adder on s1 and C to get the final sum and c2, and finally OR the two carries, since a carry can arrive from either stage.</p>
                    <p>The check row: A = 1, B = 1, C = 1. In binary, 1 + 1 + 1 is 3, which is 11 in binary, so the sum bit is 1 and the carry-out is 1. Confirm your table gives the same. If it gives 0 and 1 instead, the second half adder was applied to the wrong intermediate value.</p>
                    <p>Then answer the question the whole module has been building towards: how many full adders are needed to add two eight-bit numbers? Eight, one per bit position, with the carry from each stage feeding the next, and the carry-out of the last stage becoming a ninth bit of the result. Gates become arithmetic, arithmetic becomes a processor, and every step of it is the same handful of definitions you just used.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>That completes the subject module and the course. You now have the test format, a weightage-based study plan, both arithmetic and reasoning techniques, the verbal question types, and the technical foundations for HAT-1. The last thing worth doing is a full timed mock under the timing rules from Lesson 3, because the paper tests recall under a clock, and the clock is the part that no amount of reading can prepare you for.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-programming-fundamentals">Previous: Computing Fundamentals</a></span>
                <span><a href="/courses/hat">Back to the course overview</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
