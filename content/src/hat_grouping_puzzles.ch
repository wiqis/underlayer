// HAT course — Grouping and selection puzzles: assigning items to teams under constraints.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_grouping_puzzles() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Grouping and Selection Puzzles - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Grouping and Selection Puzzles</h1>
            <div class="lesson-meta">18 min &middot; Module 4: Analytical Reasoning &middot; Puzzles</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Grouping puzzles ask you to sort people or things into teams, committees or categories while obeying conditions. Unlike a seating row there is no order to exploit, so the only visible structure is <em>which group</em> each item joins. That makes them feel shapeless, and candidates who try to hold the conditions in their heads lose the most time here.</p>
                <p>Selection puzzles are the same family with a twist: not every item is used, and the question may only ask which items <em>can</em> be chosen. A committee of four from seven people is a grouping puzzle whose second group is simply "not selected". Master the grid and both varieties collapse into one method.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Draw a <strong>grid</strong>: items down the side, groups across the top. Every condition becomes a mark or a cross, and the puzzle turns into a fill-in exercise.</p>
                <ul>
                    <li><strong>List the items.</strong> Write every person or object once, down the left edge.</li>
                    <li><strong>List the groups.</strong> Teams, committees, boxes - one column each, with the allowed size in the header.</li>
                    <li><strong>Place the fixed items.</strong> "A is on Red" is a tick in that cell and crosses across the rest of A's row.</li>
                    <li><strong>Translate conditionals.</strong> "If X is in, Y is out" forbids a combination - mark it and stop re-reading the sentence.</li>
                    <li><strong>Count the slots.</strong> If a group needs two members and only two items can still go there, they are forced together.</li>
                    <li><strong>Split only when stuck.</strong> Assume one placement, run it out, and discard the case if it breaks a rule.</li>
                </ul>
                <p>The model omits the one thing experience supplies: which item to branch on first. The reliable rule of thumb is to branch on the item named in the most conditions.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Condition to grid</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Condition in words</th><th scope="col">Mark on the grid</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>A must be on Red</td><td>Tick A-Red, cross A across the other teams</td></tr>
                        <tr><td>A and B are always together</td><td>One block that moves as a unit</td></tr>
                        <tr><td>A and B are never together</td><td>They cannot share any group</td></tr>
                        <tr><td>At least one of A, B is selected</td><td>Forbid the selection with neither</td></tr>
                        <tr><td>At most one of A, B is selected</td><td>Forbid the selection with both</td></tr>
                        <tr><td>If A is in, then B is in</td><td>Forbid A without B</td></tr>
                    </tbody>
                </table>
                <h3>Conditionals and their contrapositives</h3>
                <p>An implication and its contrapositive are the same statement. "If A is in, then B is in" is identical to "If B is out, then A is out". "If A is in, then B is out" is identical to "If B is in, then A is out". Spotted this way, such a condition says only one thing: <em>these two can never both be in</em>. Both may still be out, which is the trap.</p>
                <div class="formula">in/out = a two-group grid &nbsp;&middot;&nbsp; group size = number of slots &nbsp;&middot;&nbsp; leftovers = the "not selected" column</div>
                <pre>
        Red   Blue   Green
A       in     -      -
B        -     ?      ?
C        -     ?      ?
D        -     ?      ?
E       in     -      -
F        -     ?      ?
size     2     2      2
</pre>
                <h3>Three question forms</h3>
                <ul>
                    <li><strong>Must be true</strong> - a fact forced in every valid assignment; if it changes between your cases it is not forced.</li>
                    <li><strong>Could be true</strong> - test each option against the conditions and reject the breakers; the survivor wins.</li>
                    <li><strong>Cannot be true</strong> - the fastest, because a single broken condition kills the option.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>Read the group sizes first.</strong> The sizes tell you how much freedom is left. When three teams each take two of six items, knowing one team fixes the arithmetic for the others.
                </div>
                <div class="callout callout-warn">
                    <strong>"Either A or B" is ambiguous in everyday speech.</strong> In these papers it usually means at least one, and sometimes it means exactly one. If the answer hinges on it, check which reading keeps the other conditions consistent - only one usually will.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>Six students A, B, C, D, E and F are assigned to three teams - Red, Blue and Green - with exactly two students per team.</em></p>
                <ul>
                    <li>A is on Red.</li>
                    <li>E is on the same team as A.</li>
                    <li>D is not on the same team as A.</li>
                    <li>B and C are on the same team.</li>
                    <li>F is not on Red.</li>
                </ul>
                <p>Fill the grid:</p>
                <ol>
                    <li>A is on Red and E joins A, so Red is full: Red = A, E.</li>
                    <li>D cannot share with A, and F is not on Red, so D and F must be in Blue and Green - the only teams with room left.</li>
                    <li>B and C occupy both slots of one team, so they take either Blue or Green entirely.</li>
                    <li>Therefore the other of Blue and Green is filled by D and F.</li>
                </ol>
                <p>The placement is not unique: either Blue = B, C and Green = D, F, or the reverse. What <em>is</em> forced is the pairing structure - A with E, B with C, and D with F. That is the must-be-true answer the puzzle is really after.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>In the worked puzzle, which statement must be true?</p>
                    <button class="quiz-option" data-correct="false" data-explain="E is required to be on the same team as A, so they are never separated." onclick="checkQuiz('quiz-1', this)">A and E are on different teams</button>
                    <button class="quiz-option" data-correct="true" data-explain="Red is full with A and E, and F cannot be on Red, so D and F fill the remaining team together." onclick="checkQuiz('quiz-1', this)">D and F are on the same team</button>
                    <button class="quiz-option" data-correct="false" data-explain="F is explicitly not on Red, so this contradicts a condition." onclick="checkQuiz('quiz-1', this)">F is on Red</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A condition reads "If D is selected, then F is not selected." Which statement is equivalent to it?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Denying the antecedent is invalid: D can be out while F is out too." onclick="checkQuiz('quiz-2', this)">If D is not selected, then F is selected</button>
                    <button class="quiz-option" data-correct="true" data-explain="The contrapositive swaps and negates: if F is selected then D is not, which forbids them being chosen together." onclick="checkQuiz('quiz-2', this)">If F is selected, then D is not selected</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the exact combination the condition forbids, so it cannot be equivalent." onclick="checkQuiz('quiz-2', this)">D and F are both selected</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>A committee is chosen from A, B, C, D, E with the rule "at most two of A, B, C". Which selection of four breaks the rule?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This contains only A and B from the trio, which is within the limit of two." onclick="checkQuiz('quiz-3', this)">A, B, D, E</button>
                    <button class="quiz-option" data-correct="true" data-explain="A, B and C together make three from the trio, exceeding the limit of two." onclick="checkQuiz('quiz-3', this)">A, B, C, D</button>
                    <button class="quiz-option" data-correct="false" data-explain="This contains only A and C from the trio, which is within the limit of two." onclick="checkQuiz('quiz-3', this)">A, C, D, E</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>For a question asking which option "must be true", the correct method is to:</p>
                    <button class="quiz-option" data-correct="false" data-explain="One valid case shows only what is possible, not what is forced in every case." onclick="checkQuiz('quiz-4', this)">Build one valid arrangement and read off its facts</button>
                    <button class="quiz-option" data-correct="true" data-explain="A fact forced in every valid arrangement is the answer; if it varies between cases it is not forced." onclick="checkQuiz('quiz-4', this)">Find a fact common to every valid arrangement</button>
                    <button class="quiz-option" data-correct="false" data-explain="Guessing without checking the conditions is exactly how marks are lost on these items." onclick="checkQuiz('quiz-4', this)">Choose the option that looks most likely</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: how do you draw a grouping puzzle, and what does "if A is in then B is out" really forbid?</p>
                <p>The answer: a grid with items down the side and groups across the top; and the condition forbids only the case where A and B are both in.</p>
                <div id="fill-1">
                    <p>In the grid, items run down the side and groups run across the <input type="text" class="fill-blank" data-answer="top" placeholder="?" aria-label="where groups are listed" />. "If X is in then Y is out" is equivalent to "if Y is in then X is <input type="text" class="fill-blank" data-answer="out" placeholder="?" aria-label="contrapositive conclusion" />". "At most two of A, B, C" forbids any selection containing <input type="text" class="fill-blank" data-answer="three" placeholder="?" aria-label="forbidden count" /> of them. A "could be true" question is answered by testing each option and using <input type="text" class="fill-blank" data-answer="elimination" placeholder="?" aria-label="method for could be true" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Seven students A, B, C, D, E, F and G form a committee of exactly four. E must be on the committee. A and B cannot both be chosen. If C is chosen, D must be chosen. D and E cannot both be chosen. Who must be on the committee?</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>E is fixed on the committee. Since D and E cannot both be chosen, D is out. The rule "if C is chosen then D must be chosen" has contrapositive "if D is not chosen then C is not chosen", so C is out too.</p>
                    <p>That leaves seats to fill from A, B, F and G, with exactly three needed. A and B cannot both be chosen, so at most one of them can be used. To reach three from four items while taking at most one of A and B, the committee must take both F and G, plus exactly one of A or B.</p>
                    <p>So every valid committee contains E, F and G, contains exactly one of A or B, and never contains C or D. The must-be-true facts are E, F and G on the committee, and C and D off it - even though the exact identity of the fourth member is left open.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Grouping is the family of puzzles where items must be sorted. The next lesson keeps the shared-setup habit but changes the picture: a network of one-way circuits and two-way radios, where every question asks for a path and an intermediary count.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-ordering-scheduling">Previous: Ordering, Grouping and Scheduling</a></span>
                <span><a href="/courses/hat/lessons/hat-network-routing">Next: Network Routing Sets</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
