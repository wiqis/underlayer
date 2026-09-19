// HAT course — Concept 5: Triage, elimination and the arithmetic of guessing.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_triage_and_guessing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Triage and Guessing — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Triage and Guessing: Converting Attempts into Marks</h1>
            <div class="lesson-meta">14 min · Module 1: Know the Arena · Technique</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Because the HAT does not penalise wrong answers, your raw score is exactly <strong>attempts multiplied by accuracy</strong>. That single fact turns guessing from a gamble into a technique, and it means a candidate who leaves fifteen questions blank has donated marks before the results are even marked.</p>
                <p>The athletes of this test are not the ones who answer everything correctly. They are the ones who (a) never leave a blank, (b) spend their minutes on questions they can actually win, and (c) know three or four elimination tricks that shrink four options to two in ten seconds.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Model every question as a bet whose expected value depends only on how many options remain alive.</p>
                <div class="formula">expected marks = 1 &times; (1 &divide; number of live options)</div>
                <table>
                    <thead>
                        <tr><th scope="col">Situation</th><th scope="col">Expected marks</th><th scope="col">Verdict</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Blank</td><td>0</td><td>Never correct</td></tr>
                        <tr><td>Blind guess, 4 options</td><td>0.25</td><td>Always better than blank</td></tr>
                        <tr><td>One option eliminated</td><td>0.33</td><td>Better again</td></tr>
                        <tr><td>Two options eliminated</td><td>0.50</td><td>A coin flip you should always take</td></tr>
                        <tr><td>Three options eliminated</td><td>1.00</td><td>That is just answering the question</td></tr>
                    </tbody>
                </table>
                <p>The table has one practical consequence: <em>guessing is a fallback, elimination is the technique</em>. Ten seconds spent deleting one clearly impossible option raises the value of the guess by a third. Fifteen blanks guessed blind earn about four marks; the same fifteen blanks with one option eliminated earn about five.</p>
                <p>The model is incomplete about accuracy, because accuracy is not fixed: it depends on how much time each attempted question gets. The rest of this lesson is about spending attention where it converts.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The three-bucket triage</h3>
                <p>On your first pass, sort questions by what they cost, not by how they look:</p>
                <ul>
                    <li><strong>Green — answer now.</strong> You can see the route and it takes under 40 seconds. These are your income.</li>
                    <li><strong>Yellow — one more look.</strong> You recognise the type but need a written step or two. Mark and return in pass two.</li>
                    <li><strong>Red — leave for last.</strong> Unfamiliar, very long, or dependent on a diagram you cannot construct. Mark, guess provisionally, and return only with leftover time.</li>
                </ul>
                <p>Two rules make the buckets work. First, your provisional guess for a red question is written immediately — never leave a page with blanks on it, because the final minutes are exactly when things go wrong. Second, a question never moves from green to red once started: the decision is made on sight, in the 40-second look.</p>
                <h3>Elimination tricks, in order of value</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Trick</th><th scope="col">Where it works</th><th scope="col">Example</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Last-digit check</td><td>Any multiplication or power</td><td>148 &times; 27 must end in 6, which kills options ending 4 or 8</td></tr>
                        <tr><td>Magnitude estimate</td><td>Arithmetic, percentages, rates</td><td>150 &times; 27 is about 4,050, so 39,960 is off by a factor of ten</td></tr>
                        <tr><td>Backsolve</td><td>Algebra, ages, percentages</td><td>Put each option into the original statement; the true one satisfies it exactly</td></tr>
                        <tr><td>Plug in a number</td><td>Variable expressions, ratios</td><td>Set x = 100 or x = 10 and test the options numerically</td></tr>
                        <tr><td>Direction check</td><td>Percentage change, averages</td><td>A price cut then rise cannot return to the original price, so "unchanged" is dead</td></tr>
                        <tr><td>Parity and divisibility</td><td>Counting, number properties</td><td>An odd count cannot be produced by an even-only sum</td></tr>
                    </tbody>
                </table>
                <h3>The distractor patterns the setters reuse</h3>
                <ul>
                    <li><strong>Wrong base.</strong> The percentage change computed on the new value instead of the original. If two options differ exactly that way, one is the trap.</li>
                    <li><strong>Off by one.</strong> In "how many numbers between" and "how many people in a row" questions, one option is always the fencepost error.</li>
                    <li><strong>Forgotten constant.</strong> Area of a triangle offered without the half, or a distance missing the two-way journey.</li>
                    <li><strong>Extreme language.</strong> In verbal and inference questions, options containing always, never, only or all are usually wrong; the passage rarely licenses them.</li>
                    <li><strong>Reversal.</strong> In analytical and analogy questions, the relationship is stated backwards — valid but in the wrong direction.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>Answer changing.</strong> Change an answer only when you can name the reason: a sign error, a misread unit, a forgotten condition. "Something feels off" is not a reason, and the classic finding that first instincts are better than second-guesses applies to reason-free changes only.
                </div>
                <div class="callout callout-warn">
                    <strong>The one thing you must never do.</strong> Handing in a sheet with blanks. With no negative marking, every blank is a self-inflicted zero, and the last two minutes of the paper are for shading, not for solving.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Elimination</h2>
                <p>Question: <em>A shirt marked at Rs 1,480 is sold at 27% off. What is the sale price?</em> Options: Rs 1,081 / Rs 1,096 / Rs 399 / Rs 1,844.</p>
                <ol>
                    <li><strong>Direction check.</strong> A discount must give a price below 1,480. That immediately kills Rs 1,844.</li>
                    <li><strong>Magnitude estimate.</strong> 27% of 1,480 is a bit more than a quarter, so about 400. Then 1,480 &minus; 400 = about 1,080. Rs 399 is a factor of four too small — it is the value of the discount itself, not the price. Two options remain.</li>
                    <li><strong>Last-digit check.</strong> 1,480 &times; 0.27 = 399.6, so the discount is 399.6 and the price is 1,480 &minus; 399.6 = 1,080.4, which shades up to Rs 1,081.</li>
                </ol>
                <p>Twenty seconds, no long multiplication, exactly one option standing. Note what the work looked like: three cheap checks instead of one expensive calculation. That is the pattern to rehearse until it is automatic.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>You have 40 seconds left and one unanswered question. You can clearly eliminate two of the four options. What is the best action?</p>
                    <button class="quiz-option" data-correct="false" data-explain="A blank is worth exactly zero, while a two-way guess is worth half a mark in expectation, and there is no penalty to offset it." onclick="checkQuiz('quiz-1', this)">Leave it blank so the sheet is unambiguous</button>
                    <button class="quiz-option" data-correct="true" data-explain="With two options eliminated the guess is worth 0.5 marks in expectation, and no penalty exists to reduce it. Guessing is strictly better than blank." onclick="checkQuiz('quiz-1', this)">Guess between the two remaining options</button>
                    <button class="quiz-option" data-correct="false" data-explain="Restarting the calculation with 40 seconds left cannot finish, and it forfeits the half mark the elimination already earned you." onclick="checkQuiz('quiz-1', this)">Restart the calculation from the beginning</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A distance question asks how far a car travels at 60 km/h for 150 minutes. One option is 150 km and another is 15 km. What does the magnitude check tell you?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Converting to hours is the correct move, but the question is about which options the estimate can kill; 150 km comes from forgetting the conversion." onclick="checkQuiz('quiz-2', this)">Both options are impossible</button>
                    <button class="quiz-option" data-correct="true" data-explain="150 minutes is 2.5 hours, so the distance is 60 &times; 2.5 = 150 km. The 15 km option fails the magnitude check, and here the 150 km option happens to be right — which is why you always estimate before choosing." onclick="checkQuiz('quiz-2', this)">60 km/h for 2.5 hours must be well over 100 km</button>
                    <button class="quiz-option" data-correct="false" data-explain="Multiplying by the minutes directly (60 &times; 150 = 9,000) is the classic unit trap, not a valid method." onclick="checkQuiz('quiz-2', this)">Multiply 60 by 150 because the time is in minutes</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>In a reading comprehension question, which inference option is most likely to be wrong?</p>
                    <button class="quiz-option" data-correct="false" data-explain="A restatement of the passage is usually safe, because it is directly supported by the text." onclick="checkQuiz('quiz-3', this)">The option that restates a sentence from the passage</button>
                    <button class="quiz-option" data-correct="true" data-explain="Extreme words such as always, never, only and all demand more than a passage normally proves, so they are the classic incorrect inference." onclick="checkQuiz('quiz-3', this)">The option containing always, never or only</button>
                    <button class="quiz-option" data-correct="false" data-explain="Length is not a signal in inference questions; the extreme-language check is far more reliable." onclick="checkQuiz('quiz-3', this)">The option that is the shortest</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>You have answered a quantitative question and moved on. On review you notice the question said "in metres" and you used centimetres. What should you do?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Feeling uneasy without a reason is exactly the case where changing answers hurts; but here you have a named, verifiable reason." onclick="checkQuiz('quiz-4', this)">Leave it, because first instincts are usually right</button>
                    <button class="quiz-option" data-correct="true" data-explain="You can name the reason — a unit error — and the corrected answer is checkable, which is precisely when changing an answer is correct." onclick="checkQuiz('quiz-4', this)">Change it, because you can name the specific reason</button>
                    <button class="quiz-option" data-correct="false" data-explain="Erasing without working out the corrected value risks replacing one wrong answer with another." onclick="checkQuiz('quiz-4', this)">Erase it and leave the question blank</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what is a blind guess worth out of one mark, and what is it worth after eliminating one option?</p>
                <p>The answer: 0.25 marks blind, 0.33 after eliminating one option — and both beat a blank, which is worth nothing.</p>
                <div id="fill-1">
                    <p>A blind guess among four options is worth <input type="text" class="fill-blank" data-answer="0.25" placeholder="?" aria-label="expected marks for a blind guess" /> marks in expectation. Because HAT has <input type="text" class="fill-blank" data-answer="no" placeholder="?" aria-label="negative marking" /> negative marking, a blank is worth <input type="text" class="fill-blank" data-answer="0" placeholder="?" aria-label="value of a blank" />, so the final minutes of the paper are spent <input type="text" class="fill-blank" data-answer="guessing" placeholder="?" aria-label="activity in the final minutes" /> on every remaining item.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Sort these six situations into green, yellow and red, and say what the first action is for each: (1) a vocabulary item whose word you know, (2) a five-question seating puzzle, (3) a percentage word problem about profit, (4) a reading passage with four questions, (5) a three-equation system that is not in the question bank you know, (6) a number series with no visible pattern after ten seconds.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p><strong>Green:</strong> the vocabulary item (10 seconds), the profit problem (familiar template, one line of setup). Answer both immediately and bank the marks.</p>
                    <p><strong>Yellow:</strong> the seating puzzle and the reading passage. Both are sets and both reward structure rather than speed: draw the grid for the puzzle, map the passage for the reading set. Mark them and take them in the second pass, with a hard cap of six to eight minutes each.</p>
                    <p><strong>Red:</strong> the three-equation system you have not seen, and the series with no visible pattern. Guess provisionally, mark them, and return only if time remains. Neither deserves more than 90 seconds total on the first pass, because both can eat a quarter of an hour without producing a mark.</p>
                    <p>The point of the exercise is that the sorting took ten seconds and the decisions were made before the pressure arrived. That is what a trained candidate does differently.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now know the arena, the budget and the betting arithmetic. From here the course stops being about the test and starts being about the subjects — beginning with Quantitative Reasoning, the 40-mark section, where you will find the fastest marks on the paper and the ones that must be protected.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-time-budget">Previous: Your 120 Minutes</a></span>
                <span><a href="/courses/hat/lessons/hat-arithmetic">Next: Arithmetic You Can Do in Your Head</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
