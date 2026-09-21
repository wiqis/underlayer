// HAT course — Concept 15: Critical reasoning (assumptions and arguments).
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_critical_reasoning() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Assumptions, Conclusions and Arguments — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Assumptions, Conclusions and Arguments</h1>
            <div class="lesson-meta">18 min · Module 4: Analytical Reasoning · Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Critical reasoning questions look like reading questions and are not. The passage is short, four or five lines, and the question asks what must be true for the argument to work, or what would weaken it. Nothing here depends on outside knowledge — only on the structure of the reasoning.</p>
                <p>This is the friendliest part of the paper for a candidate with limited vocabulary, because the answer is decided by logic alone. It is unforgiving for a candidate who answers by opinion, because the passages are written to make the opinionated answer attractive.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Every argument has exactly three parts. Find all three before looking at the options.</p>
                <div class="formula">premises + [hidden assumption] &rarr; conclusion</div>
                <ul>
                    <li><strong>Premises</strong> are the facts you are given. They are not in dispute.</li>
                    <li><strong>The conclusion</strong> is what the author wants you to accept. It is usually the last sentence.</li>
                    <li><strong>The assumption</strong> is the unstated bridge between them. It is never written down, because writing it down would invite argument.</li>
                </ul>
                <p>Premise indicators: <em>because</em>, <em>since</em>, <em>given that</em>, <em>after all</em>. Conclusion indicators: <em>therefore</em>, <em>thus</em>, <em>hence</em>, <em>so</em>, <em>consequently</em>, <em>it follows that</em>. When the conclusion comes first, the rest of the passage exists to support it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>The negation test for assumptions.</strong> Take a candidate answer and negate it. If the argument collapses when the option is false, that option is a required assumption. If the argument survives, it is not.</p>
                <p>Suppose the argument claims that because sales of the new textbook fell after a price rise, the rise caused the fall. Negate the candidate "no other factor changed at the same time". The negation is: other factors changed. Under that negation the price rise is no longer clearly the cause, and the argument collapses. So "no other factor changed" is a required assumption, and it is also the flaw most likely to appear as a weakening option.</p>
                <p><strong>Strengthen and weaken questions attack the bridge, not the premises.</strong> The premises are given; you cannot argue with them. What you can do is show that the link from premises to conclusion is weaker or stronger than it looks. Practically, the correct weakening option introduces an alternative explanation, and the correct strengthening option closes off alternatives.</p>
                <p><strong>The flaws that come up again and again.</strong></p>
                <table>
                    <thead>
                        <tr><th scope="col">Flaw</th><th scope="col">Shape</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Correlation as cause</td><td>Two things moved together, so one caused the other</td></tr>
                        <tr><td>Hasty generalisation</td><td>A small or unrepresentative sample supports a broad claim</td></tr>
                        <tr><td>Sampling bias</td><td>The respondents were self-selected or asked leading questions</td></tr>
                        <tr><td>False dilemma</td><td>Only two options are offered when more exist</td></tr>
                        <tr><td>Circular reasoning</td><td>The conclusion is smuggled into a premise</td></tr>
                        <tr><td>Equivocation</td><td>A word changes meaning halfway through</td></tr>
                        <tr><td>Appeal to authority</td><td>A person, not evidence, settles the question</td></tr>
                        <tr><td>Attacking the person</td><td>The arguer is discredited instead of the argument</td></tr>
                    </tbody>
                </table>
                <p><strong>Distinguish the necessary from the sufficient.</strong> "Must be true" asks for a requirement. "Would most strengthen" asks for added support, which need not be required. These are different questions and they have different answers even on the same passage.</p>
                <div class="callout callout-warn">
                    <strong>Do not import facts.</strong> The most common error on this question type is choosing an option that is true in general but not supported by the passage. The paper accepts only what the given sentences licence.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>Students who attend extra coaching sessions score higher on the aptitude test than students who do not. Therefore, coaching improves test performance.</em></p>
                <p>The premise is the observed difference. The conclusion is the causal claim. The hidden bridge is that nothing else distinguishes the two groups — that the coaching is the cause and not a marker of something else, such as students who were already more motivated or from better-resourced schools.</p>
                <p>A weakening option would name exactly that: the coaching students were selected on the basis of an earlier test on which they already scored higher. A strengthening option would close it off: students were assigned to coaching at random, so the groups were equivalent before coaching began.</p>
                <p>Notice that neither option denies the premise. The difference in scores is taken as true in both cases; what changes is whether the premise supports the conclusion. Random assignment is the standard fix for this flaw in both the paper and real research, which is why it appears so often as the credited answer.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>In the coaching example, what is the conclusion?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This is the premise, the observed difference that the author accepts as given." onclick="checkQuiz('quiz-1', this)">That coaching students scored higher.</button>
                    <button class="quiz-option" data-correct="true" data-explain="The conclusion follows the indicator therefore and is the causal claim the author wants accepted." onclick="checkQuiz('quiz-1', this)">That coaching improves performance.</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the hidden assumption, not the stated conclusion." onclick="checkQuiz('quiz-1', this)">That the groups were equivalent beforehand.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>How do you test whether an option is a required assumption?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Plausibility is not a test; many plausible options are not required by the argument." onclick="checkQuiz('quiz-2', this)">Ask whether the option sounds plausible.</button>
                    <button class="quiz-option" data-correct="true" data-explain="Negate it. If the argument collapses when the option is false, the option was required." onclick="checkQuiz('quiz-2', this)">Negate it and see if the argument collapses.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Agreement with your own view is irrelevant; the test is structural, not personal." onclick="checkQuiz('quiz-2', this)">Ask whether you personally agree with it.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>A study finds ice cream sales and drowning deaths rise together, and concludes that ice cream causes drowning. Which flaw is this?</p>
                    <button class="quiz-option" data-correct="true" data-explain="The two variables move together because a third factor, summer heat, drives both; treating correlation as causation is the flaw." onclick="checkQuiz('quiz-3', this)">Correlation treated as causation.</button>
                    <button class="quiz-option" data-correct="false" data-explain="No word is being used in two senses here, so equivocation does not apply." onclick="checkQuiz('quiz-3', this)">Equivocation.</button>
                    <button class="quiz-option" data-correct="false" data-explain="The sample is not described as non-representative, so sampling bias is not the intended flaw." onclick="checkQuiz('quiz-3', this)">Sampling bias.</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: name the three parts of an argument, and give the test for a required assumption.</p>
                <p>The answer is: premises, a hidden assumption, and a conclusion; the test is negation — if the argument collapses when the option is false, the option was required.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>Words such as therefore and hence introduce the <input type="text" class="fill-blank" data-answer="conclusion" placeholder="?" aria-label="what therefore introduces" />, while because and since introduce a <input type="text" class="fill-blank" data-answer="premise" placeholder="?" aria-label="what because introduces" />. Two variables moving together is treated as <input type="text" class="fill-blank" data-answer="correlation" placeholder="?" aria-label="statistical relation" />, not proof of cause.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Write one argument of your own in three lines: a premise, a conclusion, and the hidden assumption that connects them. Then write one option that would weaken it and one that would strengthen it.</p>
                <details>
                    <summary>A worked shape you can copy</summary>
                    <p>Premise: every student in the pilot section passed the mock test. Conclusion: the new teaching method works. Hidden assumption: the pilot section was not already stronger than the others — no selection effect.</p>
                    <p>Weakening option: the pilot section was chosen from students who had passed a screening test. Strengthening option: students were allocated to sections at random by student number.</p>
                    <p>The point of writing your own is that the structure becomes visible when you build it. Once you have produced three arguments by hand, you stop reading these passages as prose and start seeing the skeleton, and the answer usually falls out before you reach the last option.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Critical reasoning works on a whole argument. The next lesson narrows the lens to a single statement and asks what it silently presupposes — the unstated premise, tested by negating each option and seeing whether the statement collapses.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-verbal-drill">Previous: Verbal Drill</a></span>
                <span><a href="/courses/hat/lessons/hat-statement-assumption">Next: Statement and Assumption</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
