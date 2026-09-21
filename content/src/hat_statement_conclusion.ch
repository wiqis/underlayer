// HAT course — Statement and Conclusion: deciding which conclusions follow necessarily.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_statement_conclusion() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Statement and Conclusion - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Statement and Conclusion</h1>
            <div class="lesson-meta">15 min &middot; Module 4: Analytical Reasoning &middot; Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>In this question type you are given one or more statements, followed by two or three claimed conclusions. You must decide which conclusions <strong>definitely follow</strong> from the statements as written, with no outside knowledge and no assumptions added by you.</p>
                <p>The difficulty is not reading; it is restraint. Most wrong options are true in the real world or plausible in the story, but not forced by the sentences. The question asks what the statements compel, not what you suspect is probably the case.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Treat the statements as the only facts that exist. A conclusion follows only if no picture consistent with the statements can make it false.</p>
                <div class="formula">follows = true in every case the statements allow</div>
                <ul>
                    <li><strong>Must follow:</strong> the statements guarantee it; you cannot imagine them true and the conclusion false.</li>
                    <li><strong>Might follow:</strong> the statements permit it but do not require it. This is <em>not</em> an answer.</li>
                    <li><strong>Does not follow:</strong> the conclusion overreaches, restates, or contradicts the statements.</li>
                </ul>
                <p>What this model omits: it says nothing about how likely a conclusion is. Probability is irrelevant here. A conclusion that is almost certainly true is still wrong if the statements do not force it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Test each conclusion alone.</strong> Read the statements, cover the options, then read one conclusion and ask only one question: can I build a consistent case where the statements hold and this conclusion is false? If yes, it does not follow.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Trap</th><th scope="col">Example shape</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Overreach</td><td>&ldquo;Some prices rose&rdquo; does not give &ldquo;all prices rose&rdquo;</td></tr>
                        <tr><td>Restatement</td><td>The conclusion repeats a statement and claims nothing new</td></tr>
                        <tr><td>Outside fact</td><td>The conclusion is true in the world but absent from the statements</td></tr>
                        <tr><td>Reversal</td><td>&ldquo;All A are B&rdquo; is turned into &ldquo;all B are A&rdquo;</td></tr>
                        <tr><td>Cause from order</td><td>Two events listed together are said to cause one another</td></tr>
                        <tr><td>Probability as proof</td><td>Something likely is treated as something certain</td></tr>
                    </tbody>
                </table>
                <p><strong>Quantifiers decide most items.</strong> If a statement says <em>some</em> or <em>many</em>, a conclusion that says <em>all</em> or <em>none</em> cannot be guaranteed. If a statement says <em>all</em>, a conclusion saying <em>some</em> can follow, provided the group exists.</p>
                <div class="callout callout-tip">
                    <strong>The phrase that saves you.</strong> Ask: &ldquo;Could the opposite of this conclusion be true while the statements still hold?&rdquo; If yes, it does not follow. This single question settles nearly every option.
                </div>
                <div class="callout callout-warn">
                    <strong>Reject restatements.</strong> If a conclusion merely repeats a statement in different words, it is not a conclusion drawn from the statements. It adds nothing, and it is not the answer.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>Statements: &ldquo;All members of the club pay the annual fee. Some members also volunteer for the clean-up drive.&rdquo;</em></p>
                <p>Conclusions: (1) Some who volunteer pay the fee; (2) All volunteers pay the fee; (3) Only members pay the fee.</p>
                <p>Conclusion (1) follows. The statement says some members volunteer, and every member pays, so at least those volunteers both volunteer and pay. The overlap is guaranteed.</p>
                <p>Conclusion (2) does not follow. The statement says some members volunteer; it never says that only members volunteer. A non-member may volunteer without paying the fee, so the word <em>all</em> overreaches and the conclusion fails.</p>
                <p>Conclusion (3) does not follow. The statements say what members do; they say nothing about non-members. Many non-members may also pay the fee, and the statements would still hold. The word <em>only</em> overreaches, so the conclusion fails.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Statements: &ldquo;All engineers on the team are graduates. Some graduates are also managers.&rdquo; Does the conclusion &ldquo;some engineers are managers&rdquo; follow?</p>
                    <button class="quiz-option" data-correct="false" data-explain="The managers may be graduates who are not engineers; the two groups can be separate, so it does not follow." onclick="checkQuiz('quiz-1', this)">Yes, it must follow.</button>
                    <button class="quiz-option" data-correct="true" data-explain="The managers could all lie outside the engineer group while both statements stay true, so the conclusion is only possible, not forced." onclick="checkQuiz('quiz-1', this)">No, it does not follow.</button>
                    <button class="quiz-option" data-correct="false" data-explain="The statements do not forbid it, but a conclusion must be forced, not merely allowed." onclick="checkQuiz('quiz-1', this)">Yes, because it is possible.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Statement: &ldquo;Some students passed the entrance test.&rdquo; Which conclusion follows?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Some does not mean all; many may have failed, so this overreaches." onclick="checkQuiz('quiz-2', this)">All students passed.</button>
                    <button class="quiz-option" data-correct="true" data-explain="At least one passed is exactly what some asserts; the conclusion only restates the quantity guarantee." onclick="checkQuiz('quiz-2', this)">At least one student passed.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Some allows that others failed but does not require it; either way this is not guaranteed." onclick="checkQuiz('quiz-2', this)">At least one student failed.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Statements: &ldquo;The city has opened a new bus route. Complaints about crowding have risen since then.&rdquo; Conclusion: &ldquo;The new route caused the rise in complaints.&rdquo; Does it follow?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Order in time does not prove cause; this is the classic post hoc trap." onclick="checkQuiz('quiz-3', this)">Yes, since the rise came after.</button>
                    <button class="quiz-option" data-correct="true" data-explain="A preceding event does not establish causation, and other causes are not ruled out, so the conclusion is not forced." onclick="checkQuiz('quiz-3', this)">No, sequence is not causation.</button>
                    <button class="quiz-option" data-correct="false" data-explain="The statements say nothing about the route running late, so this is outside the given facts." onclick="checkQuiz('quiz-3', this)">Yes, the route must be running late.</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what single question settles whether a conclusion follows, and why are restatements rejected?</p>
                <p>The answer: ask whether the opposite of the conclusion could be true while the statements still hold; a restatement claims nothing new, so it is not a conclusion drawn from the statements.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>A conclusion must <input type="text" class="fill-blank" data-answer="follow" placeholder="?" aria-label="what a conclusion must do" /> necessarily from the statements. If the statements only permit it, we say it <input type="text" class="fill-blank" data-answer="might" placeholder="?" aria-label="weaker relation" /> follow, which is not enough. A conclusion that merely repeats a statement is a <input type="text" class="fill-blank" data-answer="restatement" placeholder="?" aria-label="a repeated statement" /> and is rejected. Nothing may be added from outside <input type="text" class="fill-blank" data-answer="knowledge" placeholder="?" aria-label="what must not be added" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Statements: &ldquo;All scholarship holders must maintain a grade average of seventy. Some scholarship holders play for the college team.&rdquo; Conclusions: (1) Every team player who holds a scholarship averages seventy; (2) All who average seventy hold a scholarship; (3) Some team players average seventy.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>(1) Follows. A scholarship holder who plays for the team is a scholarship holder, and all scholarship holders must average seventy. The team player sits inside the scholarship group, which sits inside the average-seventy group.</p>
                    <p>(2) Does not follow. This is the reversal. Averaging seventy is necessary for a scholarship, not sufficient. Many students averaging seventy may hold no scholarship, and the statements remain true.</p>
                    <p>(3) Follows on the usual reading. Some scholarship holders play for the team, and all scholarship holders average seventy, so those playing holders average seventy. At least one such player exists.</p>
                    <p>The item turns entirely on direction: inside the circle follows, outside the circle does not. Keep the groups nested correctly and the answer is immediate.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Conclusions are forced by statements. The next lesson drops the force and keeps the claim: a proposal is put forward, and you must judge which supporting arguments are genuinely strong rather than merely loud.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-statement-assumption">Previous: Statement and Assumption</a></span>
                <span><a href="/courses/hat/lessons/hat-strong-weak-arguments">Next: Strong and Weak Arguments</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
