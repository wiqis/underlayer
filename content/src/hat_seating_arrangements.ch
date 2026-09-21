// HAT course — Seating arrangements: linear and circular puzzles, drawn not imagined.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_seating_arrangements() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Seating Arrangements — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Seating Arrangements: Linear and Circular</h1>
            <div class="lesson-meta">18 min · Module 4: Analytical Reasoning · Puzzles</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Arrangement puzzles are the analytical section's centre of gravity, and the single biggest source of lost time on the paper. A five-person row with four conditions can be solved in four minutes with a written diagram, or in twelve minutes — usually unsuccessfully — by holding the conditions in your head.</p>
                <p>They are also the most reliable marks available once you have the procedure, because each puzzle comes as a set of three to five questions sharing one setup. Get the diagram right once and the whole set is nearly free.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Never solve an arrangement in your head. Draw a <strong>strip of boxes</strong> and write conditions into it.</p>
                <div class="formula">slots &rarr; fixed facts &rarr; blocks &rarr; exclusions &rarr; case split (only if needed)</div>
                <ol>
                    <li><strong>Draw the slots.</strong> A row of numbered boxes for a line, or a hexagon of six for a circle.</li>
                    <li><strong>Write in the fixed facts.</strong> "A is at the extreme right" pins box 5 immediately.</li>
                    <li><strong>Draw blocks.</strong> "B immediately before C" is one block [B C] that slides as a unit — never two separate facts.</li>
                    <li><strong>Mark exclusions.</strong> "C is not adjacent to B" becomes a cross on the neighbouring boxes of B.</li>
                    <li><strong>Split into cases only when forced.</strong> Pick the most constrained element, assume one of its two possible positions, and check whether the rest still fits. Nearly always one case dies immediately.</li>
                </ol>
                <p>The model's payoff is that the diagram becomes a machine: the questions at the end are answered by reading the strip, not by re-deriving.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Direction conventions — the part people get wrong</h3>
                <ul>
                    <li><strong>Facing the centre:</strong> a person's <em>left</em> is clockwise, and their <em>right</em> is anticlockwise. (Stand at the south of a circle facing north: your left hand points west, which is the clockwise neighbour.)</li>
                    <li><strong>Facing outward:</strong> left is anticlockwise, right is clockwise — the mirror image.</li>
                    <li><strong>"Immediately to the left"</strong> means the next seat, with nobody between. <strong>"Second to the left"</strong> means one person between you and them.</li>
                    <li><strong>"Opposite"</strong> is only defined in a circle, and only when the count is even: with n seats, the seat n/2 steps away.</li>
                    <li><strong>"X sits between Y and Z"</strong> does not say in which order — it is the most common reason a puzzle appears to have two solutions when the question asks "must be true".</li>
                </ul>
                <h3>Notation to write on your rough sheet</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Condition</th><th scope="col">What you write</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>A is immediately before B</td><td>[A B] as one sliding block</td></tr>
                        <tr><td>A is not adjacent to C</td><td>crosses on the two seats beside A</td></tr>
                        <tr><td>Exactly two people sit between A and B</td><td>A _ _ B or B _ _ A, three seats apart</td></tr>
                        <tr><td>A is somewhere to the left of B</td><td>A &lt; B (an inequality, not a distance)</td></tr>
                        <tr><td>A is opposite B</td><td>write A and B in opposite seats at once</td></tr>
                    </tbody>
                </table>
                <h3>The three question forms</h3>
                <ul>
                    <li><strong>"Must be true"</strong> — look for what the constraints force in every valid arrangement. Draw the cases if you are unsure; if a fact changes between cases, it is not forced.</li>
                    <li><strong>"Could be true"</strong> — you cannot reason to it; test each option against the constraints and reject those that break one. Answer by elimination.</li>
                    <li><strong>"Cannot be true"</strong> — usually the fastest, because most constraints kill an option outright.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>Start every puzzle set with the constraints, not the questions.</strong> Three or four questions share the setup; if you read the questions first you will re-read the constraints once per question.
                </div>
                <div class="callout callout-warn">
                    <strong>The two-solutions ambush.</strong> If two arrangements satisfy every condition, the question cannot be a "must be true" question — so re-check whether you have misread a condition ("between" and "immediately" are different) before assuming the puzzle is broken. If the question really does not force the answer, the correct option is the one that agrees with both cases.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Linear Puzzle</h2>
                <p><em>Five students — A, B, C, D and E — sit in a row of five seats, numbered 1 to 5 from left to right.</em></p>
                <ul>
                    <li>A sits at the extreme right.</li>
                    <li>B sits immediately to the left of A.</li>
                    <li>C is not adjacent to B.</li>
                    <li>D sits between C and E.</li>
                </ul>
                <p>Draw the strip and apply the steps:</p>
                <ol>
                    <li>From "A at the extreme right" and "B immediately left of A": seat 5 = A, seat 4 = B.</li>
                    <li>C is not adjacent to B, so C cannot be in seat 3. Remaining seats for C, D, E are 1, 2 and 3, so C is in seat 1 or seat 2.</li>
                    <li>Take C in seat 1. Then D must be between C and E, which forces seat 2 = D and seat 3 = E.</li>
                    <li>Take C in seat 2. Then D would have to sit between seat 2 and E, but the only seat between them belongs to one of them — impossible. That case dies.</li>
                </ol>
                <p>The unique arrangement is <strong>C, D, E, B, A</strong>. Read off the answers: E is in the middle seat, D is immediately right of C, and the seat beside A - A is at the right end - is occupied by B.</p>
                <h2>Worked Circular Puzzle</h2>
                <p><em>Six people — A, B, C, D, E and F — sit around a circular table facing the centre.</em></p>
                <ul>
                    <li>A is opposite D.</li>
                    <li>B is immediately to the left of A.</li>
                    <li>C is immediately to the right of A.</li>
                    <li>E is not adjacent to C.</li>
                </ul>
                <p>Draw six seats clockwise. Put A at the top. Facing the centre, left is clockwise, so B takes the next seat clockwise; right is anticlockwise, so C takes the next seat anticlockwise. D goes opposite A, three seats away. The two remaining seats, opposite each other, belong to E and F — and E is not adjacent to C, which places E next to B and F next to C.</p>
                <p>Clockwise from A: <strong>A, B, E, D, F, C</strong>. The deductions worth noticing: A is opposite D, B is opposite F, and C is opposite E. Any question about who sits opposite whom is answered by reading the ring.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>In the row puzzle (C, D, E, B, A), who sits in the middle seat?</p>
                    <button class="quiz-option" data-correct="false" data-explain="D is in seat 2, immediately right of C; the middle seat of five is seat 3." onclick="checkQuiz('quiz-1', this)">D</button>
                    <button class="quiz-option" data-correct="true" data-explain="Seat 3 is the middle of five, and the arrangement is C, D, E, B, A, so E is in the middle." onclick="checkQuiz('quiz-1', this)">E</button>
                    <button class="quiz-option" data-correct="false" data-explain="B is in seat 4, immediately left of A at the extreme right." onclick="checkQuiz('quiz-1', this)">B</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>In the circular arrangement (A, B, E, D, F, C clockwise), who sits opposite B?</p>
                    <button class="quiz-option" data-correct="false" data-explain="D is opposite A, three seats away from A in either direction." onclick="checkQuiz('quiz-2', this)">D</button>
                    <button class="quiz-option" data-correct="true" data-explain="Counting three seats clockwise from B gives F, so B and F are opposite each other." onclick="checkQuiz('quiz-2', this)">F</button>
                    <button class="quiz-option" data-correct="false" data-explain="E sits immediately clockwise of B, adjacent rather than opposite." onclick="checkQuiz('quiz-2', this)">E</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>For people seated around a table facing the centre, a person's left is:</p>
                    <button class="quiz-option" data-correct="true" data-explain="Facing the centre, the left hand points clockwise, so the person immediately to your left is the clockwise neighbour." onclick="checkQuiz('quiz-3', this)">clockwise</button>
                    <button class="quiz-option" data-correct="false" data-explain="Anticlockwise is the left of a person facing outward, not of a person facing the centre." onclick="checkQuiz('quiz-3', this)">anticlockwise</button>
                    <button class="quiz-option" data-correct="false" data-explain="Left and right are well defined by which way the person faces; only the mapping to clockwise or anticlockwise changes." onclick="checkQuiz('quiz-3', this)">undefined in a circle</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>A question asks which option "could be true". What is the correct method?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Reasoning to a possibility is unreliable; you must test each option against every condition and reject the ones that break one." onclick="checkQuiz('quiz-4', this)">Derive the single arrangement and read it off</button>
                    <button class="quiz-option" data-correct="true" data-explain="For 'could be true' questions, test each option against the constraints and eliminate; the survivor is the answer even if the arrangement is not unique." onclick="checkQuiz('quiz-4', this)">Test each option against the constraints and eliminate</button>
                    <button class="quiz-option" data-correct="false" data-explain="Skipping is unnecessary: 'could be true' questions are usually the most mechanical, because elimination decides them." onclick="checkQuiz('quiz-4', this)">Skip it and return if time permits</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what is the difference between "between" and "immediately", and where is a person's left when they face the centre?</p>
                <p>The answer: "immediately" means no seat in between while "between" only requires separation; and facing the centre, left is clockwise.</p>
                <div id="fill-1">
                    <p>When people face the centre, a person's left is <input type="text" class="fill-blank" data-answer="clockwise" placeholder="?" aria-label="direction of left when facing centre" />. The phrase "immediately before" means the two occupy adjacent seats as a <input type="text" class="fill-blank" data-answer="block" placeholder="?" aria-label="how to treat adjacent items" />. In a circle of six, a person's opposite is <input type="text" class="fill-blank" data-answer="three" placeholder="?" aria-label="seats to the opposite" /> seats away, and a "could be true" question is answered by <input type="text" class="fill-blank" data-answer="elimination" placeholder="?" aria-label="method for could be true" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Five colleagues P, Q, R, S and T sit in a row. P sits at the left end; T sits immediately to the right of P; R does not sit next to T; Q is to the right of S. Solve it and then say what an extra condition would have to be in order to fix S and Q completely.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>P is at the left end, so seat 1 is P, and T immediately right of P puts T in seat 2. R does not sit next to T, so R is not in seat 3. The remaining seats 3, 4 and 5 hold R, S and Q, with Q to the right of S. Cases: R = 4 leaves S and Q in 3 and 5, and Q right of S gives S = 3, Q = 5, so P T S R Q. R = 5 leaves S and Q in 3 and 4, and Q right of S gives S = 3, Q = 4, so P T S Q R.</p>
                    <p>So the puzzle as given is not unique: two arrangements survive, P T S R Q and P T S Q R. A "must be true" question would ask about what is common to both - P is at the left end, T is immediately right of P, and S is in seat 3. To pin Q as well you need one more relational fact: "Q is at the right end" forces P T S R Q. Note that a fact already true of both arrangements, such as "S sits exactly in the middle", removes nothing.</p>
                    <p>The practical lesson is the one that saves marks: when your diagram still has multiple cases, do not force a single answer. Answer only what is forced, and use elimination for the questions that ask about possibilities.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Seating is the visual half of the puzzle family. The next lesson takes the same grid method into the puzzles about order and schedule — who meets when, who is assigned to which day — where the diagram is a calendar rather than a row.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-logic-deduction">Previous: Ordering, Grouping and Deduction</a></span>
                <span><a href="/courses/hat/lessons/hat-ordering-scheduling">Next: Ordering, Grouping and Scheduling</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
