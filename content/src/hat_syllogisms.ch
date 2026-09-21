// HAT course — Syllogisms: statements, conclusions and the counterexample test.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_syllogisms() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Syllogisms — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Syllogisms: What Follows Necessarily</h1>
            <div class="lesson-meta">16 min · Module 4: Analytical Reasoning · Logic</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Syllogism items are the fairest questions on the paper: two or three statements, one or two claimed conclusions, and a purely formal question — does the conclusion follow from the statements <em>as written</em>, with no outside knowledge? You do not need to know anything about the subject matter, only the rules of the form.</p>
                <p>They are also where candidates lose marks to common sense. "All cats are animals; some animals are black; therefore some cats are black" feels true because you know cats can be black, yet it does not follow: the black animals might all be dogs. The exam tests the form, not the world.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Turn the statements into <strong>circles</strong> and ask one question: is the conclusion true in <em>every</em> arrangement the statements allow?</p>
                <div class="formula">valid conclusion = true in all allowed diagrams &nbsp;·&nbsp; if you can draw one counter-diagram, it fails</div>
                <table>
                    <thead>
                        <tr><th scope="col">Statement</th><th scope="col">Diagram</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>All A are B</td><td>The A circle sits entirely inside B</td></tr>
                        <tr><td>No A are B</td><td>The circles do not touch</td></tr>
                        <tr><td>Some A are B</td><td>The circles overlap, with at least one item inside the overlap</td></tr>
                        <tr><td>Some A are not B</td><td>Part of A lies outside B</td></tr>
                    </tbody>
                </table>
                <p>The counterexample method is faster than memorising rules: try to draw a picture consistent with the statements in which the conclusion is false. If the drawing is possible, the conclusion does not follow. Note the exam convention: <em>some</em> means at least one, and possibly all.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Forms that always hold</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Premises</th><th scope="col">Conclusion</th><th scope="col">Why</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>All A are B; All B are C</td><td>All A are C</td><td>Nested circles chain</td></tr>
                        <tr><td>All A are B; No B are C</td><td>No A are C</td><td>A lies inside B, which avoids C</td></tr>
                        <tr><td>Some A are B; All B are C</td><td>Some A are C</td><td>The overlap item is also in C</td></tr>
                        <tr><td>No A are B</td><td>No B are A</td><td>Non-contact is symmetric</td></tr>
                        <tr><td>Some A are B</td><td>Some B are A</td><td>Overlap is symmetric</td></tr>
                        <tr><td>All A are B</td><td>Some B are A</td><td>Only valid if A exists — the exam accepts it</td></tr>
                    </tbody>
                </table>
                <h3>Forms that never hold</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Premises</th><th scope="col">Claimed conclusion</th><th scope="col">Counterexample</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>All A are B</td><td>All B are A</td><td>Put B wider than A: every A is B, most B are not A</td></tr>
                        <tr><td>Some A are B; Some B are C</td><td>Some A are C</td><td>A and C can overlap B at different places, or not meet</td></tr>
                        <tr><td>All A are B; Some C are B</td><td>Some A are C</td><td>C can overlap B entirely outside A</td></tr>
                        <tr><td>No A are B; Some C are A</td><td>No C are B</td><td>C can extend beyond A into B</td></tr>
                    </tbody>
                </table>
                <h3>How to work an item in under a minute</h3>
                <ol>
                    <li>Underline the two extremes (the subject of the first statement and the object of the last). The conclusion can only be about those extremes joined through a shared middle term.</li>
                    <li>If the middle term is missing or appears in two different roles, the conclusion is almost always invalid.</li>
                    <li>Draw the diagram only for the doubtful cases, and draw it in the way most likely to break the conclusion.</li>
                    <li>Treat words like "only", "all except" and "none but" carefully: "none but graduates may apply" means all applicants are graduates.</li>
                </ol>
                <div class="callout callout-tip">
                    <strong>The nasty one.</strong> When one premise is "Some A are B" and the other is "All B are C", the answer "Some A are C" is valid — the same item that is both A and B is also C. But if the first premise is "Some A are B" and the second is "Some B are C", nothing follows: the two overlaps can involve different members of B.
                </div>
                <div class="callout callout-warn">
                    <strong>Do not apply real-world knowledge.</strong> If the statements say "all machines are silent", then within that question all machines are silent, whatever you know about machines. The exam rewards accepting the premises as given, however odd they sound.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. All engineers are graduates. All graduates are literate. Conclusion: all engineers are literate.</h3>
                <p>Valid. Engineer circle inside graduate circle, graduate circle inside literate circle, so engineer is inside literate. This is the chaining form.</p>
                <h3>2. Some doctors are musicians. All musicians are artists. Conclusion: some doctors are artists.</h3>
                <p>Valid. The doctors who are musicians are also artists, and there is at least one such doctor by "some".</p>
                <h3>3. All roses are flowers. Some flowers fade quickly. Conclusion: some roses fade quickly.</h3>
                <p>Invalid. Draw the eighty percent of the flower circle that lies outside the rose circle and let all the quickly-fading flowers be there. The premises remain true and the conclusion is false, so it does not follow.</p>
                <h3>4. No reptiles are mammals. All snakes are reptiles. Conclusion: no snakes are mammals.</h3>
                <p>Valid. The snake circle is inside the reptile circle, and the reptile circle avoids mammals entirely, so snakes cannot be mammals.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>All engineers are graduates. All graduates are literate. Which conclusion follows?</p>
                    <button class="quiz-option" data-correct="true" data-explain="The chain nests engineer inside graduate inside literate, so every engineer is literate." onclick="checkQuiz('quiz-1', this)">All engineers are literate</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the converse: the literate circle may be far wider than the engineer circle." onclick="checkQuiz('quiz-1', this)">All literate people are engineers</button>
                    <button class="quiz-option" data-correct="false" data-explain="Nothing in the premises says engineers and the literate are disjoint; in fact the premises require the opposite." onclick="checkQuiz('quiz-1', this)">No engineers are literate</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Some doctors are musicians. All musicians are artists. Which conclusion follows?</p>
                    <button class="quiz-option" data-correct="false" data-explain="The overlap between doctors and musicians need not be artists beyond the musicians who are artists; in fact those are exactly the ones who are artists, and the other doctors are unconstrained." onclick="checkQuiz('quiz-2', this)">All doctors are artists</button>
                    <button class="quiz-option" data-correct="true" data-explain="At least one doctor is a musician, and every musician is an artist, so at least one doctor is an artist." onclick="checkQuiz('quiz-2', this)">Some doctors are artists</button>
                    <button class="quiz-option" data-correct="false" data-explain="No musician can be a non-artist on these premises, so this conclusion contradicts them." onclick="checkQuiz('quiz-2', this)">No doctors are artists</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>All roses are flowers. Some flowers fade quickly. Which conclusion follows?</p>
                    <button class="quiz-option" data-correct="false" data-explain="The quickly-fading flowers may lie entirely outside the rose circle, so this does not follow." onclick="checkQuiz('quiz-3', this)">Some roses fade quickly</button>
                    <button class="quiz-option" data-correct="true" data-explain="Nothing follows about roses: the premises place roses inside flowers but say nothing about which flowers fade quickly." onclick="checkQuiz('quiz-3', this)">None of these follows</button>
                    <button class="quiz-option" data-correct="false" data-explain="The premises do not exclude the possibility, but a syllogism asks what must be true, not what might be." onclick="checkQuiz('quiz-3', this)">All roses fade quickly</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>Some A are B. Some B are C. Which conclusion follows?</p>
                    <button class="quiz-option" data-correct="false" data-explain="The two overlaps can involve different members of B, so no A need be C." onclick="checkQuiz('quiz-4', this)">Some A are C</button>
                    <button class="quiz-option" data-correct="true" data-explain="Two particular premises with a shared middle term yield nothing: draw A overlapping one part of B and C overlapping another, and no A is C." onclick="checkQuiz('quiz-4', this)">Nothing follows</button>
                    <button class="quiz-option" data-correct="false" data-explain="Nothing in the premises forbids an A being C, but that is possibility rather than necessity; the conclusion must follow." onclick="checkQuiz('quiz-4', this)">No A are C</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: which two particular premises never produce a conclusion, and what does "some" mean in these questions?</p>
                <p>The answer: "some A are B" with "some B are C" yields nothing; and "some" means at least one, possibly all.</p>
                <div id="fill-1">
                    <p>In these questions "some" means at least <input type="text" class="fill-blank" data-answer="one" placeholder="?" aria-label="minimum for some" />, and possibly all. "All A are B" and "All B are C" together give all A are <input type="text" class="fill-blank" data-answer="C" placeholder="?" aria-label="chained conclusion" />. To disprove a claimed conclusion you drawn a <input type="text" class="fill-blank" data-answer="counterexample" placeholder="?" aria-label="method of disproof" />, and outside knowledge must be <input type="text" class="fill-blank" data-answer="ignored" placeholder="?" aria-label="role of outside knowledge" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Statements: "No student who arrived late was admitted." "All those admitted sat the test." Which of these follow: (1) No student who arrived late sat the test; (2) All who sat the test were admitted; (3) Some who sat the test were admitted?</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Let A be latecomers, B the admitted and C those who sat the test. The premises are: No A are B; All B are C.</p>
                    <p>(1) "No A are C" does not follow: the admitted circle sits inside the test circle, but a latecomer could sit the test without being admitted — the test circle is wider than the admitted circle, and latecomers may fall in that outer ring. Invalid.</p>
                    <p>(2) "All C are B" is the converse of the second premise, so it does not follow: many who sat the test may not have been admitted. Invalid.</p>
                    <p>(3) "Some C are B" follows, provided at least one student was admitted: with all admitted sitting the test, those admitted students are inside both circles. Valid on the usual exam convention that the described group exists.</p>
                    <p>This item shows why naming the three circles and their relative sizes answers the question faster than reading the sentences again — the whole problem is the shape, not the story.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Formal logic is done. The next lesson returns to puzzles about people, but with a map instead of a grid: family relationships and directions, where every sentence adds an arrow or a branch.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-grouping-puzzles">Previous: Grouping and Selection Puzzles</a></span>
                <span><a href="/courses/hat/lessons/hat-sets-venn">Next: Set-Based Deduction</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
