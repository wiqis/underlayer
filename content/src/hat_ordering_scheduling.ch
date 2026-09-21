// HAT course — Ordering, grouping and scheduling puzzles: the grid method.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_ordering_scheduling() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Ordering, Grouping and Scheduling — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Ordering, Grouping and Scheduling</h1>
            <div class="lesson-meta">18 min · Module 4: Analytical Reasoning · Puzzles</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Once seating is understood, the rest of the analytical puzzles are the same idea wearing different clothes: assign each item to exactly one slot, subject to constraints. Orders of merit, meeting schedules, subject-and-city grids and team memberships are all one procedure.</p>
                <p>The procedure is worth an afternoon because it is reusable: the same grid answers "who came first", "which day is free" and "who teaches what". Candidates who lack it treat each new puzzle as a fresh problem and run out of time by question 60.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Build a <strong>grid</strong> whose rows are the items and whose columns are the attributes, then let every condition cross out cells.</p>
                <div class="formula">items &times; attributes grid &rarr; one cross per ruled-out combination &rarr; the leftover cell is forced</div>
                <p>Three mechanics turn conditions into crosses:</p>
                <ul>
                    <li><strong>Definite conditions</strong> delete a whole row and column ("A teaches Maths" crosses out Maths for everyone else and every other subject for A).</li>
                    <li><strong>Relational conditions</strong> link two grids ("the person from Lahore teaches Chemistry" ties the city grid to the subject grid).</li>
                    <li><strong>Negative conditions</strong> delete a single cell ("D is not from Multan").</li>
                </ul>
                <p>When the grid stalls with two items and two attributes, add the one condition you have not used. Puzzles are designed with exactly enough conditions; the unused one always breaks the tie.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Worked grid puzzle</h3>
                <p><em>Four friends — A, B, C and D — each chose a different subject (Maths, Physics, Chemistry, Biology) and each comes from a different city (Lahore, Karachi, Quetta, Multan).</em></p>
                <ul>
                    <li>A chose Maths.</li>
                    <li>B is from Karachi.</li>
                    <li>C is from Lahore and chose Chemistry.</li>
                    <li>D is not from Multan.</li>
                    <li>The person from Quetta chose Physics.</li>
                </ul>
                <p>Filling the grid:</p>
                <ol>
                    <li>A = Maths; C = Chemistry; so Physics and Biology remain for B and D.</li>
                    <li>B = Karachi, C = Lahore; so A and D hold Multan and Quetta. D is not from Multan, so D = Quetta and A = Multan.</li>
                    <li>The Quetta person chose Physics, so D = Physics, leaving B = Biology.</li>
                </ol>
                <table>
                    <thead>
                        <tr><th scope="col">Person</th><th scope="col">Subject</th><th scope="col">City</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>A</td><td>Maths</td><td>Multan</td></tr>
                        <tr><td>B</td><td>Biology</td><td>Karachi</td></tr>
                        <tr><td>C</td><td>Chemistry</td><td>Lahore</td></tr>
                        <tr><td>D</td><td>Physics</td><td>Quetta</td></tr>
                    </tbody>
                </table>
                <p>Note how the answer came from the fifth condition. Without "the Quetta person chose Physics", B and D would still be interchangeable — which is exactly the situation where a question can only ask "must be true".</p>
                <h3>Worked scheduling puzzle</h3>
                <p><em>Five meetings — M1, M2, M3, M4, M5 — are held on five consecutive weekdays.</em></p>
                <ul>
                    <li>M1 is on Monday.</li>
                    <li>M2 is on Wednesday.</li>
                    <li>M3 is not on Friday.</li>
                    <li>M5 is on the day immediately after M4.</li>
                </ul>
                <p>Monday and Wednesday are taken, leaving Tuesday, Thursday and Friday. The pair [M4, M5] must be consecutive: the only free consecutive pair is Thursday and Friday. So M4 is on Thursday and M5 on Friday, which leaves <strong>M3 on Tuesday</strong> — consistent with the rule that it is not on Friday, which was the condition that stopped you from placing M3 last.</p>
                <h3>The four question shapes</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Question shape</th><th scope="col">Method</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Fully determined</td><td>There is one arrangement; read the answer off the grid</td></tr>
                        <tr><td>"Must be true"</td><td>Find what holds in every surviving case; test by trying to break it</td></tr>
                        <tr><td>"Could be true"</td><td>Test each option; reject any that breaks a condition</td></tr>
                        <tr><td>"Cannot be true"</td><td>Often fastest: look for the option that violates a given condition</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-tip">
                    <strong>Group puzzles have an extra trick.</strong> When items are only assigned to groups (not ordered), count the sizes first: if group X has three members and only two people are allowed into it, you have already learned something about everyone else.
                </div>
                <div class="callout callout-warn">
                    <strong>Do not re-read the conditions for each question.</strong> The grid is the source of truth after step one. Re-reading the prose is the main reason a five-question puzzle set takes fifteen minutes instead of six.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Second Example, Solved by Counting</h2>
                <p><em>Six students are divided into two project teams of three. A and B must be on the same team. C must not be on a team with A. D must be with B.</em></p>
                <p>Start from the strongest link: A, B and D must all be together, and that is already three people — the maximum team size — so team one is exactly &#123;A, B, D&#125;. C is not with A, so C is on team two with the remaining students E and F. The split is fully determined without any case work, purely because the team size acted as a constraint.</p>
                <p>Counting before drawing is the habit worth taking from this example: limits on group size are among the most powerful conditions in the section, and they are the easiest to overlook because they are expressed as a fact about the setup rather than as a rule about a person.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>In the scheduling puzzle, which meeting is on Tuesday?</p>
                    <button class="quiz-option" data-correct="false" data-explain="M4 is on Thursday, forming the consecutive pair with M5 on Friday." onclick="checkQuiz('quiz-1', this)">M4</button>
                    <button class="quiz-option" data-correct="true" data-explain="Monday and Wednesday are taken by M1 and M2, the consecutive pair M4-M5 takes Thursday and Friday, leaving Tuesday for M3." onclick="checkQuiz('quiz-1', this)">M3</button>
                    <button class="quiz-option" data-correct="false" data-explain="M5 is on Friday, immediately after M4, which is the condition that fixes the pair." onclick="checkQuiz('quiz-1', this)">M5</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>In the person-subject-city grid, who is from Quetta?</p>
                    <button class="quiz-option" data-correct="false" data-explain="A is from Multan, which is forced because D cannot be from Multan and B and C already hold Karachi and Lahore." onclick="checkQuiz('quiz-2', this)">A</button>
                    <button class="quiz-option" data-correct="true" data-explain="D is from Quetta: Karachi and Lahore are taken by B and C, and D is not from Multan, so D takes Quetta." onclick="checkQuiz('quiz-2', this)">D</button>
                    <button class="quiz-option" data-correct="false" data-explain="B is from Karachi, given directly by the conditions." onclick="checkQuiz('quiz-2', this)">B</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Which subject did B choose?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Physics is chosen by D, the person from Quetta." onclick="checkQuiz('quiz-3', this)">Physics</button>
                    <button class="quiz-option" data-correct="true" data-explain="With A in Maths and C in Chemistry, and Physics following from the Quetta condition, Biology is left for B." onclick="checkQuiz('quiz-3', this)">Biology</button>
                    <button class="quiz-option" data-correct="false" data-explain="Chemistry belongs to C, who is from Lahore." onclick="checkQuiz('quiz-3', this)">Chemistry</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>Your grid still leaves two possible arrangements and the next question says "must be true". What do you do?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Choosing the arrangement you drew first is a guess; an unchecked fact may hold in one case and fail in the other." onclick="checkQuiz('quiz-4', this)">Pick the arrangement that looks most likely</button>
                    <button class="quiz-option" data-correct="true" data-explain="Find what holds in both surviving cases, or test each option against the conditions to see which is forced." onclick="checkQuiz('quiz-4', this)">Find the fact common to both cases, or test each option</button>
                    <button class="quiz-option" data-correct="false" data-explain="Skipping costs marks unnecessarily; 'must be true' questions remain answerable whenever you know what is forced." onclick="checkQuiz('quiz-4', this)">Skip the question, since the puzzle is underdetermined</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what are the three kinds of condition, and why do group-size limits matter so much?</p>
                <p>The answer: definite conditions, relational conditions and negative conditions; group-size limits restrict everyone at once, because filling a group to its capacity removes the remaining people from it.</p>
                <div id="fill-1">
                    <p>A condition such as "A teaches Maths" is a <input type="text" class="fill-blank" data-answer="definite" placeholder="?" aria-label="type of condition" /> condition, while "the person from Lahore teaches Chemistry" is <input type="text" class="fill-blank" data-answer="relational" placeholder="?" aria-label="type of condition" />. The grid's rows are items and its columns are <input type="text" class="fill-blank" data-answer="attributes" placeholder="?" aria-label="what the columns hold" />. Questions that ask what <input type="text" class="fill-blank" data-answer="could" placeholder="?" aria-label="question form needing elimination" /> be true are answered by elimination.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Four teachers W, X, Y and Z teach four subjects (English, Urdu, Maths, Science) in four periods (1, 2, 3, 4). The Maths teacher takes period 2. Y teaches Urdu in period 4. W is not the Science teacher. Z takes period 1 and does not teach English. Work out the full timetable, then say which single extra condition would make the puzzle solvable in fewer steps.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Fill the definite facts: Y = Urdu, period 4; Z = period 1; Maths = period 2 (so Z, in period 1, is not Maths, and Y, in period 4, is not Maths).</p>
                    <p>Remaining periods for W and X are 2 and 3, and Maths must be in period 2, so whichever of W or X holds period 2 teaches Maths. Z does not teach English and does not teach Maths (period 1 is not period 2), so Z teaches either Science or Urdu — but Urdu belongs to Y, so Z teaches Science. Then W is not Science, and English, Maths and Urdu remain for W, X and Y; since Y has Urdu and period 4 is not Maths, the Maths teacher must be W or X in period 2.</p>
                    <p>Two cases survive: W = Maths in period 2 with X = English in period 3, or X = Maths in period 2 with W = English in period 3. One extra definite condition — "X teaches English" or "W takes period 2" — collapses it to a single timetable. It is a good habit to note, at the end of a puzzle, exactly which extra fact would finish it: that is what "must be true" questions are testing you for.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Grids and strips are done. The next lesson changes machinery entirely: syllogisms, where the diagram is a pair of circles and the only question is whether a conclusion follows necessarily from two premises.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-seating-arrangements">Previous: Seating Arrangements</a></span>
                <span><a href="/courses/hat/lessons/hat-grouping-puzzles">Next: Grouping and Selection Puzzles</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
