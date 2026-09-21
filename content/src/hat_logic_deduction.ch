// HAT course — Concept 16: Deduction / logic puzzles.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_logic_deduction() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Ordering, Grouping and Deduction — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Ordering, Grouping and Deduction</h1>
            <div class="lesson-meta">20 min · Module 4: Analytical Reasoning · Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Deduction questions give you a handful of items, a few rules, and ask what must follow. There is no reading, no vocabulary and no ambiguity: each question has one answer that can be proved from the rules.</p>
                <p>They are also the most reliable marks on the paper once learned, because the method is mechanical. The items and rules change; the technique does not. Candidates who do badly here are almost never bad at logic — they are sketching arrangements in their head, losing track, and guessing.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Never reason about a puzzle without a diagram on paper.</p>
                <ol>
                    <li><strong>Draw the frame.</strong> If items are ordered, draw the slots. If they are grouped, draw the boxes.</li>
                    <li><strong>Write each rule as a symbol</strong> next to the frame: order relationships as arrows, blocks as brackets, exclusions as crossed pairs.</li>
                    <li><strong>Apply the strongest rules first.</strong> A rule that fixes a position beats a rule that only orders two items. A rule that forms a block beats both.</li>
                    <li><strong>Test the question against your diagram,</strong> not against the story. Answer choices are eliminated by contradiction.</li>
                </ol>
                <p>The diagram is not a study aid. It is the method. Almost every deduction question can be solved by placing items and crossing out contradictions.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Conditionals have three forms, and only one of them is valid.</strong> For a rule "if P then Q":</p>
                <table>
                    <thead>
                        <tr><th scope="col">Form</th><th scope="col">Reading</th><th scope="col">Valid?</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>P &rarr; Q</td><td>Given P, Q follows</td><td>Yes — the rule itself</td></tr>
                        <tr><td>not Q &rarr; not P</td><td>If Q fails, P cannot hold</td><td>Yes — the contrapositive</td></tr>
                        <tr><td>Q &rarr; P</td><td>Given Q, P follows</td><td>No — the converse</td></tr>
                        <tr><td>not P &rarr; not Q</td><td>If P fails, Q cannot hold</td><td>No — the inverse</td></tr>
                    </tbody>
                </table>
                <p>The contrapositive is the highest-value trick in the section. "If a student is late, the application is rejected" also tells you that an accepted application was not late. The converse — that a rejected application was late — does not follow, and it is exactly the kind of option the paper offers you.</p>
                <p><strong>Must-be-true and could-be-true are different questions.</strong> A must-be-true option holds in every arrangement that obeys the rules. A could-be-true option holds in at least one. Read the stem's wording before checking the options, because an option that is merely possible is wrong for the first and right for the second.</p>
                <p><strong>Elimination is a first-class technique.</strong> If a placement forces a contradiction with any rule, that option is dead. Working from the options is often faster than deriving the whole arrangement, and it is the intended solution path for could-be-true questions.</p>
                <p><strong>Grouping rules come in three shapes.</strong> "At least one" means the two items cannot both be absent; "at most one" means they cannot both be present; and an exclusion means exactly what it says. Distinguishing these three immediately is worth more than any amount of re-reading.</p>
                <div class="callout callout-tip">
                    <strong>When a question adds a condition, add it to the diagram first.</strong> Questions like "if S is third, which must be true?" are solved by placing S third, re-deriving the rest, and only then looking at the options. Candidates who read the options first start guessing.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Four files — P, Q, R and S — are reviewed one per day, Monday to Thursday. The rules are:</p>
                <ul>
                    <li>S is reviewed immediately after Q.</li>
                    <li>Q is not reviewed first.</li>
                    <li>P is reviewed before R.</li>
                </ul>
                <p>Apply the block rule first. Q and S must be adjacent and Q cannot be first, so the block occupies either days 2 and 3 or days 3 and 4.</p>
                <p>If the block is on days 2 and 3, days 1 and 4 are P and R in some order, and P before R forces P on day 1 and R on day 4: <strong>P, Q, S, R</strong>.</p>
                <p>If the block is on days 3 and 4, days 1 and 2 are P and R, and P before R forces P on day 1 and R on day 2: <strong>P, R, Q, S</strong>.</p>
                <p>There are exactly two valid arrangements, and this is the crucial observation: P is first in both. So "P is reviewed first" is true in every arrangement and is therefore a must-be-true answer. Note also how much work the block rule did — starting with it established the frame in one step, while the "P before R" rule alone would have told you much less.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>In the four-file puzzle, if Q is reviewed on day 3, which must be true?</p>
                    <button class="quiz-option" data-correct="true" data-explain="With Q on day 3 the block is on days 3 and 4, forcing P, R, Q, S, so P is first in the only valid arrangement." onclick="checkQuiz('quiz-1', this)">P is reviewed on day 1.</button>
                    <button class="quiz-option" data-correct="false" data-explain="R is on day 2 in this arrangement; S, not R, is last. The block rule puts S immediately after Q." onclick="checkQuiz('quiz-1', this)">R is reviewed on day 4.</button>
                    <button class="quiz-option" data-correct="false" data-explain="S must come immediately after Q, so S cannot be on day 2 when Q is on day 3." onclick="checkQuiz('quiz-1', this)">S is reviewed on day 2.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A rule states: if an application is late, it is rejected. Which statement must be true?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This is the converse. A rejected application might have been rejected for another reason." onclick="checkQuiz('quiz-2', this)">If an application is rejected, it was late.</button>
                    <button class="quiz-option" data-correct="true" data-explain="This is the contrapositive, which is logically equivalent to the original rule and always valid." onclick="checkQuiz('quiz-2', this)">If an application is not rejected, it was not late.</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the inverse. An on-time application could still fail for a different reason." onclick="checkQuiz('quiz-2', this)">If an application is not late, it is not rejected.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Which of these is a valid complete order for the four-file puzzle?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Q on day 1 breaks the rule that Q is not first." onclick="checkQuiz('quiz-3', this)">Q, S, P, R</button>
                    <button class="quiz-option" data-correct="false" data-explain="R on day 1 breaks the rule that P is reviewed before R." onclick="checkQuiz('quiz-3', this)">R, P, S, Q</button>
                    <button class="quiz-option" data-correct="true" data-explain="Q and S are adjacent and Q is not first, and P precedes R, so this arrangement satisfies all three rules." onclick="checkQuiz('quiz-3', this)">P, Q, S, R</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: from "if P then Q", which forms are valid and which are not? And which rule should a candidate apply first?</p>
                <p>The answer is: P implies Q and not-Q implies not-P are valid; Q implies P and not-P implies not-Q are not. Apply the strongest rule first — the one that fixes a position or forms a block.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>The valid rephrasing of a conditional that reverses and negates both parts is called the <input type="text" class="fill-blank" data-answer="contrapositive" placeholder="?" aria-label="valid rephrasing name" />. A question asking which arrangement is possible in at least one valid case is a could-be-<input type="text" class="fill-blank" data-answer="true" placeholder="?" aria-label="could be what" /> question. Arrangement rules are easiest to apply when drawn as a <input type="text" class="fill-blank" data-answer="diagram" placeholder="?" aria-label="what to draw" /> rather than held in the head.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Build your own puzzle so that the rules are visible. Take five students, a row of five seats, and write three rules: one block rule, one ordering rule and one exclusion.</p>
                <details>
                    <summary>A working example and what to check</summary>
                    <p>Five students A, B, C, D, E in seats 1 to 5. Rules: A sits immediately before B; C is not in seat 1; D sits somewhere before E.</p>
                    <p>Enumerate with the block first. AB occupies 1 and 2, or 2 and 3, or 3 and 4, or 4 and 5. In each case fill the remaining three seats with C, D, E under the rule that D precedes E, while remembering C cannot sit in seat 1.</p>
                    <p>The value of this exercise is not the answer. It is that you notice which rule did the most work. Here the block is still the starting point, but the exclusion does real work precisely when the block does not occupy seats 1 and 2 - the cases where seat 1 is still free and candidates who solve in their heads forget to check it.</p>
                    <p>Then write three questions against your puzzle: one must-be-true, one could-be-true, and one conditional that adds a new fact. If your could-be-true question has more than one valid option, you have written it wrongly — and discovering that is the whole point of the exercise.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Deduction works with rules you are given. The next concept works with numbers you are shown: tables, charts and graphs, where the reasoning is arithmetic on presented data rather than logic on stated rules.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-cause-effect">Previous: Cause and Effect</a></span>
                <span><a href="/courses/hat/lessons/hat-seating-arrangements">Next: Seating Arrangements</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
