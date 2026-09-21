// HAT course — Course of Action: judging which proposed action fits a given problem.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_course_of_action() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Course of Action - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Course of Action</h1>
            <div class="lesson-meta">15 min &middot; Module 4: Analytical Reasoning &middot; Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A course of action question describes a problem and offers two or three proposed actions. You must decide which action, if any, is a proper <strong>course of action</strong>: a step that follows from the problem and would actually help.</p>
                <p>The wording is often &ldquo;which of the following is a possible course of action&rdquo; or &ldquo;which step, if taken, would follow&rdquo;. The exam rewards actions that address the stated problem directly. It punishes dramatic, irrelevant, or already-assumed responses, and it punishes the temptation to discuss the problem rather than act on it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A good course of action is a single test with four checks. The action must be feasible, relevant, direct, and proportionate.</p>
                <div class="formula">good action = feasible + relevant + direct + proportionate</div>
                <ul>
                    <li><strong>Feasible:</strong> it can actually be carried out by the person or body in question.</li>
                    <li><strong>Relevant:</strong> it concerns the stated problem, not a neighbouring one.</li>
                    <li><strong>Direct:</strong> it does something about the problem rather than merely noting or lamenting it.</li>
                    <li><strong>Proportionate:</strong> it fits the size of the problem, neither trivial nor extreme.</li>
                </ul>
                <p>What this model omits: it does not consider whether other solutions exist. The exam asks whether this action follows from the problem, not whether it is the only possible response.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Discard the grand and the vague.</strong> The classic weak options are sweeping statements rather than steps: &ldquo;the government should be more careful&rdquo;, &ldquo;everyone should be educated about this&rdquo;, &ldquo;strict action should be taken&rdquo;. These name a sentiment, not an action, and they cannot be executed as stated.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Proposed action</th><th scope="col">Verdict</th><th scope="col">Why</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Set up a drainage inspection team for the flooded area</td><td>Good</td><td>Specific, feasible and directly aimed at the problem</td></tr>
                        <tr><td>Ban all construction in the district</td><td>Bad</td><td>Extreme and out of proportion to the stated problem</td></tr>
                        <tr><td>People should be more responsible</td><td>Bad</td><td>A sentiment, not an action; nobody can carry it out</td></tr>
                        <tr><td>Warn residents near the river to move to higher ground</td><td>Good</td><td>A concrete step that addresses the immediate risk</td></tr>
                        <tr><td>Punish the officials named in the report</td><td>Bad</td><td>Depends on facts not given; may be irrelevant to the problem</td></tr>
                        <tr><td>Increase the frequency of water testing</td><td>Good</td><td>Feasible and directly relevant to the stated concern</td></tr>
                    </tbody>
                </table>
                <p><strong>Do not import facts.</strong> An action that only makes sense if you assume extra facts not in the passage is not supported. If the passage never mentions a cause, an action aimed at that cause is speculative.</p>
                <p><strong>Reject the already-assumed.</strong> Sometimes an option states a fact or a goal already given in the problem rather than a step. Restating the problem is not a course of action.</p>
                <div class="callout callout-tip">
                    <strong>Ask: who does what?</strong> A real action has an actor and a concrete step. If you cannot name both, the option is probably the vague weak one the examiner planted.
                </div>
                <div class="callout callout-warn">
                    <strong>Proportion matters.</strong> An action that is wildly larger than the problem, such as banning an entire activity over a minor incident, is not a proper course of action even if it would technically help.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>Problem: &ldquo;Several students in the hostel have fallen ill after eating in the canteen, and inspections found the kitchen unsanitary.&rdquo;</em></p>
                <p>Proposed actions: (A) temporarily close the canteen for cleaning and medical inspection; (B) tell the affected students to be more careful about what they eat; (C) shut down all hostels in the city indefinitely.</p>
                <p>(A) is a good course of action. It is feasible, aimed directly at the unsanitary kitchen the passage mentions, and proportionate to the incident.</p>
                <p>(B) is bad. It shifts responsibility onto the victims and does nothing about the unsanitary kitchen the inspection actually found. It is vague and misdirected.</p>
                <p>(C) is bad. It is extreme out of all proportion, affects people with no connection to the problem, and the passage gives no basis for it.</p>
                <p>The credited action is the one that a sensible authority could carry out tomorrow, aimed at the specific problem named in the passage.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What makes a proposed action a proper course of action?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Feasibility, relevance, directness and proportion are the four checks a proper action must pass." onclick="checkQuiz('quiz-1', this)">It is feasible, relevant, direct and proportionate.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Whether it sounds impressive has no bearing on whether it fits the problem." onclick="checkQuiz('quiz-1', this)">It sounds strong and decisive.</button>
                    <button class="quiz-option" data-correct="false" data-explain="An action being the only option is not required; it must fit the problem, not be unique." onclick="checkQuiz('quiz-1', this)">It is the only possible solution.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Problem: &ldquo;A factory is discharging untreated waste into the river.&rdquo; Which is a good course of action?</p>
                    <button class="quiz-option" data-correct="false" data-explain="A blanket ban reaches far beyond the factory actually causing the problem and is disproportionate." onclick="checkQuiz('quiz-2', this)">Ban all industry in the region.</button>
                    <button class="quiz-option" data-correct="true" data-explain="An inspection with a clear requirement and enforcement is feasible, direct and proportionate to the stated violation." onclick="checkQuiz('quiz-2', this)">Inspect the plant and require it to treat its waste before discharge.</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a sentiment rather than an action; it names no actor and no concrete step." onclick="checkQuiz('quiz-2', this)">People should care more about the environment.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Why is &ldquo;strict action should be taken against the guilty&rdquo; usually a weak course of action?</p>
                    <button class="quiz-option" data-correct="false" data-explain="It is not too specific; its problem is the opposite, being too vague to execute." onclick="checkQuiz('quiz-3', this)">Because it is too specific.</button>
                    <button class="quiz-option" data-correct="true" data-explain="It states a general sentiment with no named actor or concrete step, so it cannot be carried out as written." onclick="checkQuiz('quiz-3', this)">Because it names no actor or concrete step.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Being unpopular does not make an action weak; practicality and fit are what matter." onclick="checkQuiz('quiz-3', this)">Because it is unpopular.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>Problem: &ldquo;Power cuts are disrupting evening study in a neighbourhood.&rdquo; Which action best fits?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Relocating everyone is extreme and disproportionate to a local power problem." onclick="checkQuiz('quiz-4', this)">Relocate all residents to another town.</button>
                    <button class="quiz-option" data-correct="true" data-explain="Scheduling outages outside study hours is feasible, directly relevant and proportionate." onclick="checkQuiz('quiz-4', this)">Schedule the cuts outside the main study hours.</button>
                    <button class="quiz-option" data-correct="false" data-explain="This restates the problem rather than proposing a step, so it is not a course of action." onclick="checkQuiz('quiz-4', this)">The power supply should be reliable.</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what are the four checks for a good course of action, and what are the two classic weak shapes?</p>
                <p>The answer: feasible, relevant, direct and proportionate; the classic weak shapes are the vague sentiment with no actor, and the extreme or disproportionate step.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>A proper course of action is <input type="text" class="fill-blank" data-answer="feasible" placeholder="?" aria-label="it can be carried out" /> and directly relevant to the problem. It must be <input type="text" class="fill-blank" data-answer="proportionate" placeholder="?" aria-label="fits the size of the problem" />, not extreme. A statement such as people should be more responsible is weak because it is a <input type="text" class="fill-blank" data-answer="sentiment" placeholder="?" aria-label="not an action" /> rather than a step. An option that merely restates the problem is not an <input type="text" class="fill-blank" data-answer="action" placeholder="?" aria-label="the missing thing" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Problem: &ldquo;Shopkeepers in the market report a rise in pickpocketing, and the police patrol ends at seven in the evening.&rdquo; Proposed actions: (A) extend the patrol beyond seven in the evening; (B) close the market after seven; (C) advise shoppers to be more alert.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>(A) is a good course of action. It is feasible, directly addresses the gap the passage names, and is proportionate to the problem. The passage itself points to the patrol ending at seven, which makes the extension the natural response.</p>
                    <p>(B) is bad. It punishes the market as a whole for the actions of thieves, is disproportionate to the problem, and the passage gives no basis for shutting the market down.</p>
                    <p>(C) is weak. It shifts responsibility onto shoppers, does not address the patrol gap or the pickpockets, and gives no concrete step to be carried out. It is advice as sentiment rather than an action on the stated problem.</p>
                    <p>The chosen action is the one tied to the detail the passage supplied. When a passage mentions a specific gap such as the patrol time, an action that closes that gap is almost always the credited course of action.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You have now met four reasoning question types: assumptions, conclusions, arguments and courses of action. The next lesson examines a fifth kind of claim — causal claims — and the trap of treating correlation as causation.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-strong-weak-arguments">Previous: Strong and Weak Arguments</a></span>
                <span><a href="/courses/hat/lessons/hat-cause-effect">Next: Cause and Effect</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
