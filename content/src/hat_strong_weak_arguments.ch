// HAT course — Strong and Weak Arguments: judging which arguments genuinely bear on a proposal.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_strong_weak_arguments() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Strong and Weak Arguments - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Strong and Weak Arguments</h1>
            <div class="lesson-meta">15 min &middot; Module 4: Analytical Reasoning &middot; Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A question of this type presents a statement or proposal, followed by two arguments, usually one for it and one against. You must decide which argument, if either, is <strong>strong</strong>.</p>
                <p>The trap is personal opinion. The proposal may be one you support or oppose, and the arguments are written to pull you towards your own view. The exam does not care what you think; it asks only whether an argument genuinely bears on the proposal and stands on its own.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>An argument is strong when it does three things at once: it is <strong>relevant</strong> to the proposal, <strong>plausible</strong> on its own, and it speaks <strong>directly</strong> to whether the proposal should be adopted.</p>
                <div class="formula">strong = relevant + plausible + directly on the proposal</div>
                <ul>
                    <li><strong>Relevant:</strong> it is about this proposal, not about something nearby.</li>
                    <li><strong>Plausible:</strong> a reasonable person could accept the reason without further proof of a controversial claim.</li>
                    <li><strong>Direct:</strong> it gives a reason to adopt or reject the proposal itself.</li>
                </ul>
                <p>What this model omits: it does not weigh arguments against each other. Both arguments can be strong, or neither, and that is a legitimate outcome. You are grading each argument alone, not staging a debate.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Reject the emotional and the vague.</strong> Arguments that appeal to fear, tradition, or the character of the people involved are weak, however persuasive they sound. So are arguments built on words like <em>everyone knows</em> or <em>it is obvious</em>, which assert rather than reason.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Argument</th><th scope="col">Verdict</th><th scope="col">Why</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>The change will upset many people</td><td>Weak</td><td>Vagueness and emotion, with no bearing on the merits</td></tr>
                        <tr><td>It will reduce waiting time by half</td><td>Strong</td><td>Concrete and directly on the proposal</td></tr>
                        <tr><td>We have always done it the old way</td><td>Weak</td><td>Tradition is not a reason about outcomes</td></tr>
                        <tr><td>It costs more than the budget allows</td><td>Strong</td><td>Feasibility bears directly on adoption</td></tr>
                        <tr><td>The proposer is not trustworthy</td><td>Weak</td><td>Attacks the person, not the proposal</td></tr>
                        <tr><td>It has worked in similar cities</td><td>Strong</td><td>Relevant evidence from comparable cases</td></tr>
                    </tbody>
                </table>
                <p><strong>Beware the restatement.</strong> An argument that simply repeats the proposal, or the opposite of it, in different words is not an argument at all. It gives no independent reason, so it is weak.</p>
                <p><strong>Judge on the merits, not the outcome.</strong> An argument is strong because of its content, not because it is on your side. If the argument against a proposal you like is concrete and directly relevant, it is still strong.</p>
                <div class="callout callout-tip">
                    <strong>The feasibility question.</strong> Many strong arguments are about consequence or practicality: will it work, can we afford it, does it fix the problem. These bear directly on whether to adopt, which is exactly what the question asks.
                </div>
                <div class="callout callout-warn">
                    <strong>Do not grade by side.</strong> Both given arguments can be strong, or neither. Do not assume that one must be for and one must be against, or that exactly one is credited.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>Proposal: &ldquo;The college should replace paper notices with a digital noticeboard.&rdquo;</em></p>
                <p>Argument A, for: &ldquo;It will let announcements reach students instantly on their phones.&rdquo; This is concrete, plausibly true, and directly supports the change. Strong.</p>
                <p>Argument B, against: &ldquo;Digital screens are a modern invention and change is always unsettling.&rdquo; This rests on a vague discomfort with change rather than any specific drawback. It is emotional and general. Weak.</p>
                <p>Now consider a different argument B, against: &ldquo;A significant number of students do not own a smartphone, so some would miss notices.&rdquo; This is specific and directly identifies a group who would be harmed, bearing on whether the change is a good idea. Strong.</p>
                <p>The contrast shows the test working. The first B fails on vagueness and relevance; the second B passes because it names a real, concrete consequence of adopting the proposal.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What makes an argument strong?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Relevance, plausibility and a direct bearing on the proposal are the three marks of a strong argument." onclick="checkQuiz('quiz-1', this)">It is relevant, plausible and directly on the proposal.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Agreement with your view is irrelevant; strength is about the argument, not your side." onclick="checkQuiz('quiz-1', this)">It agrees with your own opinion.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Emotional force can persuade but does not make an argument strong." onclick="checkQuiz('quiz-1', this)">It sounds forceful and emotional.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Proposal: &ldquo;The city should ban private cars from the old town.&rdquo; Which argument against it is strong?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Fear of change in general is vague and not specific to this proposal." onclick="checkQuiz('quiz-2', this)">Change is always risky for a city.</button>
                    <button class="quiz-option" data-correct="true" data-explain="A concrete group that depends on cars and would be harmed directly bears on the proposal." onclick="checkQuiz('quiz-2', this)">Residents with disabilities who cannot use buses would lose access.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Attacking those who proposed the ban does not address its merits." onclick="checkQuiz('quiz-2', this)">The councillors who proposed it are not to be trusted.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Proposal: &ldquo;The firm should allow staff to work from home.&rdquo; Which argument for it is weak?</p>
                    <button class="quiz-option" data-correct="false" data-explain="A measured reduction in overhead costs is a concrete, relevant reason." onclick="checkQuiz('quiz-3', this)">It would cut office rent and utility costs.</button>
                    <button class="quiz-option" data-correct="true" data-explain="This merely restates the proposal in favour-oriented words and gives no independent reason." onclick="checkQuiz('quiz-3', this)">Working from home is a good thing to allow.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Evidence that productivity held steady is directly relevant and plausible." onclick="checkQuiz('quiz-3', this)">Similar firms found productivity held steady.</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what are the three marks of a strong argument, and why is a restatement weak?</p>
                <p>The answer: relevant, plausible and directly on the proposal; a restatement gives no independent reason, so it cannot support or attack the proposal.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>A strong argument is <input type="text" class="fill-blank" data-answer="relevant" placeholder="?" aria-label="first mark" />, plausible, and directly about the proposal. An argument that appeals only to emotion or tradition is <input type="text" class="fill-blank" data-answer="weak" placeholder="?" aria-label="verdict on emotional appeal" />. An argument that repeats the proposal is a <input type="text" class="fill-blank" data-answer="restatement" placeholder="?" aria-label="a repeated proposal" /> and adds no reason. Both arguments may be strong, so strength is judged per <input type="text" class="fill-blank" data-answer="argument" placeholder="?" aria-label="unit of judgement" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Proposal: &ldquo;The university should make attendance at lectures compulsory.&rdquo; Arguments: (A) &ldquo;Students who attend regularly score higher, so attendance improves results.&rdquo; (B) &ldquo;Making it compulsory would punish students who work part-time to fund their studies.&rdquo; (C) &ldquo;Compulsory attendance is simply old-fashioned.&rdquo; Grade each.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>(A) is strong for the proposal. It offers a concrete, plausible benefit tied to outcomes, and it speaks directly to whether the policy should be adopted. The correlation-to-cause worry from the critical reasoning lesson is present, but as an argument it is still specific and directly relevant.</p>
                    <p>(B) is strong against the proposal. It names a definite group that the policy would harm and gives a specific reason. It bears directly on whether to adopt, so it is strong even if you favour compulsory attendance.</p>
                    <p>(C) is weak. Calling the idea old-fashioned is a vague judgement, not a reason about consequences or merits. It gives no concrete basis on which to accept or reject the policy.</p>
                    <p>The lesson from grading all three: strength is a property of the reasoning, not of the side it supports, and two opposing arguments can both be strong in the same item.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Arguments weigh a proposal. The next lesson takes a problem and asks what should be done about it, where the test is whether a proposed action is feasible, relevant and proportionate to the situation.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-statement-conclusion">Previous: Statement and Conclusion</a></span>
                <span><a href="/courses/hat/lessons/hat-course-of-action">Next: Course of Action</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
