// HAT course — Cause and effect: separating correlation from causation.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_cause_effect() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Cause and Effect - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Cause and Effect: Correlation Is Not Causation</h1>
            <div class="lesson-meta">15 min &middot; Module 4: Analytical Reasoning &middot; Logic</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The analytical section contains a small, highly predictable family of questions about causes: a claim that one thing produces another, and a task to strengthen, weaken or evaluate it. The reasoning is the same as critical reasoning, but the answer almost always turns on the single distinction the section loves most: two things moving together is not proof that one moves the other.</p>
                <p>These questions are fair. They never require specialist knowledge; they require you to notice that a third factor, a reversed order, or a coincidence can explain the evidence just as well as the stated cause.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A causal claim needs three supports. Remove any one and the claim weakens.</p>
                <ul>
                    <li><strong>Association.</strong> The cause and the effect occur together — there is a correlation.</li>
                    <li><strong>Order.</strong> The proposed cause comes before the effect in time.</li>
                    <li><strong>No better explanation.</strong> No common third factor produces both, and the direction is not reversed.</li>
                </ul>
                <p>The model's missing piece: the test rarely asks you to prove causation. It asks which option makes the causal claim more or less credible. So you look for the option that supplies a mechanism or removes a rival explanation; that is the strengthener. The option that supplies a rival explanation is the weakener.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The four possible relationships</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Relationship</th><th scope="col">Example</th><th scope="col">How to weaken the stated cause</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>A causes B (as claimed)</td><td>Smoking causes lung damage</td><td>Hard to weaken; look for a confound the study missed</td></tr>
                        <tr><td>B causes A (reversed)</td><td>Lung damage causes smoking</td><td>Show the effect precedes the supposed cause</td></tr>
                        <tr><td>C causes both (common cause)</td><td>Stress causes both smoking and illness</td><td>Name the third factor that drives both</td></tr>
                        <tr><td>Coincidence</td><td>Two unrelated trends</td><td>Show the association is spurious or disappears with more data</td></tr>
                    </tbody>
                </table>
                <h3>The signals in the wording</h3>
                <ul>
                    <li><strong>Because, since, due to</strong> introduce a stated cause; the claim to attack is the link between it and the effect.</li>
                    <li><strong>Therefore, hence, as a result</strong> introduce the conclusion that depends on the causal link.</li>
                    <li><strong>Correlate, associated with, linked to</strong> are deliberately weaker than "causes" and often the honest description of the evidence.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>The one-question habit.</strong> Ask: "What else could make both of these happen, or could the second one cause the first?" The answer to that question is usually the correct option.
                </div>
                <div class="callout callout-warn">
                    <strong>Two repeated traps.</strong> (1) Accepting a plausible-sounding cause because it "makes sense" without checking order or confounds. (2) Choosing an option that merely repeats the association instead of addressing the causal link.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>Cities that employ more firefighters also record more fire damage. The author concludes that the firefighters cause the damage. Which statement most weakens the conclusion?</em></p>
                <p>The evidence is a correlation and the conclusion is causal. More fires in a city lead both to more firefighters being deployed and to more damage, so the common factor — the frequency and size of fires — explains the association without any firefighter causing anything. The strong weakener is: "larger cities have more fires, and both larger fire crews and greater damage follow from those fires."</p>
                <p>Note why the tempting option "some firefighters are poorly trained" is wrong: it attacks a peripheral detail rather than the logical link, and it does not explain the correlation. Weakeners must break the causal argument, not merely introduce doubt.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Ice-cream sales and drowning deaths rise together every summer. What is the flaw in concluding that ice cream causes drowning?</p>
                    <button class="quiz-option" data-correct="false" data-explain="There is no false dilemma here; two alternatives are not being forced." onclick="checkQuiz('quiz-1', this)">False dilemma</button>
                    <button class="quiz-option" data-correct="true" data-explain="Warm weather drives both ice-cream purchases and swimming, so the shared cause explains the correlation without any direct link." onclick="checkQuiz('quiz-1', this)">A common cause explains both</button>
                    <button class="quiz-option" data-correct="false" data-explain="Circular reasoning would assume the conclusion; the flaw here is a confound, not circularity." onclick="checkQuiz('quiz-1', this)">Circular reasoning</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Which observation would most strengthen the claim that a new study app improves exam scores?</p>
                    <button class="quiz-option" data-correct="false" data-explain="A correlation with app use repeats the evidence rather than ruling out alternatives; students who study more may both use the app and score higher." onclick="checkQuiz('quiz-2', this)">Students who use the app score higher</button>
                    <button class="quiz-option" data-correct="true" data-explain="A controlled comparison that holds other study behaviour constant isolates the app's effect and supports the causal claim." onclick="checkQuiz('quiz-2', this)">Students randomly assigned to the app score higher than an otherwise identical group</button>
                    <button class="quiz-option" data-correct="false" data-explain="Popularity says nothing about whether the app causes higher scores." onclick="checkQuiz('quiz-2', this)">The app is the most downloaded study app</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>"Since" and "therefore" appear in a causal claim. Which is the conclusion?</p>
                    <button class="quiz-option" data-correct="false" data-explain="The clause after since is a premise offered as the cause, not the conclusion." onclick="checkQuiz('quiz-3', this)">The clause after "since"</button>
                    <button class="quiz-option" data-correct="true" data-explain="Therefore marks the conclusion, which depends on the causal link stated in the premise." onclick="checkQuiz('quiz-3', this)">The clause after "therefore"</button>
                    <button class="quiz-option" data-correct="false" data-explain="Neither word marks an example or an illustration." onclick="checkQuiz('quiz-3', this)">The clause after an example marker</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: state the three supports a causal claim needs, and name the relationship that exists when a third factor drives both quantities.</p>
                <p>A causal claim needs association, correct time order, and no better explanation. A third factor driving both is called a common cause.</p>
                <div id="fill-1">
                    <p>Two quantities that move together are said to <input type="text" class="fill-blank" data-answer="correlate" placeholder="?" aria-label="what two moving-together quantities do" />. If a hidden factor drives both, that factor is a <input type="text" class="fill-blank" data-answer="common cause" placeholder="?" aria-label="hidden factor driving both" />. If the effect actually produces the supposed cause, the relationship is <input type="text" class="fill-blank" data-answer="reversed" placeholder="?" aria-label="effect produces cause" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A study reports that employees who take more sick days are promoted less often, and concludes that sick leave damages careers. Give the most plausible alternative explanation and state what evidence would settle the question.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>The alternative is a common cause: poor health, or a demanding role, can independently reduce attendance and reduce promotion chances. A second alternative is reversed causation at the level of commitment: employees already planning to leave take more leave and are passed over.</p>
                    <p>The evidence that would settle it: a controlled design that compares employees with similar health and similar roles, so that sick leave varies for reasons unrelated to those factors, and measures promotion separately. If promotion gaps persist, the causal claim survives; if they disappear, common cause or reversal better explains the data.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You can now separate a causal claim from a mere association. The next lesson moves from evaluating arguments to building them: taking a set of ordering and grouping rules and deducing exactly what must follow, the formal core of the analytical section.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-course-of-action">Previous: Course of Action</a></span>
                <span><a href="/courses/hat/lessons/hat-logic-deduction">Next: Ordering, Grouping and Deduction</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
