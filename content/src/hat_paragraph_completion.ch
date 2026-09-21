// HAT course — Paragraph completion: choosing the sentence that continues the argument.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_paragraph_completion() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Paragraph Completion and Coherence - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Paragraph Completion and Coherence</h1>
            <div class="lesson-meta">14 min &middot; Module 3: Verbal Reasoning &middot; Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Paragraph completion gives you four or five sentences and a blank, usually the final sentence, and asks which option finishes the passage. It looks like a reading question and is really a logic question wearing a paragraph: the missing sentence is decided entirely by the direction the earlier sentences have already set.</p>
                <p>The section rewards the same habit as sentence completion — predicting from signals before you read the options — but at the scale of a whole argument instead of a single clause. Candidates who read the passage, then read the options, then re-read the passage, lose three minutes on a question that a signal reader answers in forty seconds.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Read the passage as a short argument with three movable parts.</p>
                <ul>
                    <li><strong>Topic.</strong> What is the passage about? One phrase, stated before you look at options.</li>
                    <li><strong>Direction.</strong> Is the passage asserting, contrasting, giving an example, or drawing a conclusion? The connective before the blank tells you.</li>
                    <li><strong>Scope.</strong> Which words are already in play? A correct completion stays inside the passage's vocabulary and does not import a new subject.</li>
                </ul>
                <p>The model's missing piece: a blank that begins with <em>Thus</em> or <em>Therefore</em> wants a conclusion, while a blank beginning with <em>However</em> wants a reversal. Predict the blank's job from its connectives before you predict its content.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The signal words and what the blank must do</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Signal before the blank</th><th scope="col">Relationship</th><th scope="col">What the blank must do</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>however, although, yet, nevertheless</td><td>Contrast</td><td>Oppose or qualify what came before</td></tr>
                        <tr><td>moreover, in addition, similarly</td><td>Addition</td><td>Continue the same direction with a stronger or parallel point</td></tr>
                        <tr><td>therefore, thus, consequently, hence</td><td>Cause and effect / conclusion</td><td>State the consequence that follows from the premises</td></tr>
                        <tr><td>for example, for instance, such as</td><td>Illustration</td><td>Give a specific case of the general claim</td></tr>
                        <tr><td>in short, in sum, overall</td><td>Summary</td><td>Restate the passage's main claim without adding new scope</td></tr>
                    </tbody>
                </table>
                <h3>Why the wrong options are wrong</h3>
                <ul>
                    <li><strong>Too extreme.</strong> Words like all, never, only, always push past what the passage supports. A passage saying a policy has costs does not license "the policy must be abolished".</li>
                    <li><strong>Off-topic.</strong> The option is true and reasonable but about something the passage never raised. True is not the same as relevant.</li>
                    <li><strong>Reversed.</strong> The option continues the wrong direction, usually after a contrast signal such as however.</li>
                    <li><strong>Circular or repetitive.</strong> The option simply restates an earlier sentence instead of performing the blank's job (for example, concluding when a conclusion was required).</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>The predictive read.</strong> Cover the options. Say the missing sentence yourself from the passage and its connectives. Then match. An option that changes the subject or the strength of the claim is wrong even if it reads well.
                </div>
                <div class="callout callout-warn">
                    <strong>Two repeated traps.</strong> (1) Choosing the option that echoes the passage's most familiar words without checking the logical direction. (2) Letting a plausible real-world belief override the passage: the test asks what completes <em>this</em> argument, not what you know to be true.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>Remote work has cut the daily commute for millions of employees, and companies have saved on office space. Yet surveys repeatedly find that junior staff learn faster when they sit near experienced colleagues. ___.</em></p>
                <p>The blank follows a contrast. The passage first gives benefits, then a cost. A conclusion beginning <em>Thus</em> must therefore state a qualified overall judgement, not a one-sided one: the correct answer is "the shift's gains must be weighed against its cost to early-career learning", not "remote work should be abandoned" (too extreme) nor "commuting is always unpleasant" (off-topic).</p>
                <p>Watch the sequence: read the first clause (benefit), the contrast word <em>Yet</em>, the counter-example (cost), then predict a balanced conclusion. Every correct option does exactly the job its connective promised.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Which signal phrase would most likely precede a blank that must state an opposing idea?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Moreover adds a further point in the same direction, so the blank would continue rather than oppose." onclick="checkQuiz('quiz-1', this)">Moreover</button>
                    <button class="quiz-option" data-correct="true" data-explain="Nevertheless marks a contrast, so the blank must oppose or qualify what came before." onclick="checkQuiz('quiz-1', this)">Nevertheless</button>
                    <button class="quiz-option" data-correct="false" data-explain="For instance introduces an example of the same claim, not a reversal of it." onclick="checkQuiz('quiz-1', this)">For instance</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A passage argues that a new tax reduced consumption. The final blank begins "Therefore,". Which completion is correct?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This restates the premise rather than drawing the conclusion the signal promises, and it imports a new idea about enforcement." onclick="checkQuiz('quiz-2', this)">the tax was collected by the revenue authority</button>
                    <button class="quiz-option" data-correct="true" data-explain="A conclusion from the premise that consumption fell is that the policy achieved part of its aim, stated within the passage's scope." onclick="checkQuiz('quiz-2', this)">the policy achieved its immediate goal</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is an extreme claim and a new scope: the passage never discusses abolishing the tax." onclick="checkQuiz('quiz-2', this)">the tax should be abolished at once</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Which option should you eliminate first when completing a paragraph?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Length does not determine correctness; the logic does." onclick="checkQuiz('quiz-3', this)">the shortest option</button>
                    <button class="quiz-option" data-correct="true" data-explain="An option that contradicts the passage's established direction is wrong regardless of how well written it is." onclick="checkQuiz('quiz-3', this)">the option that reverses the passage's direction</button>
                    <button class="quiz-option" data-correct="false" data-explain="Familiar vocabulary can be a decoy; an option may echo the passage and still perform the wrong logical job." onclick="checkQuiz('quiz-3', this)">the option that repeats a word from the passage</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: name the three parts of the model, and state what a blank introduced by <em>Thus</em> must do.</p>
                <p>The three parts are topic, direction and scope. A blank introduced by <em>Thus</em> must state the conclusion that follows from the premises already given.</p>
                <div id="fill-1">
                    <p>A blank introduced by <em>however</em> must <input type="text" class="fill-blank" data-answer="contrast" placeholder="?" aria-label="job of however blank" /> with what came before. A blank introduced by <em>therefore</em> must state a <input type="text" class="fill-blank" data-answer="conclusion" placeholder="?" aria-label="job of therefore blank" />. The correct option never introduces a new <input type="text" class="fill-blank" data-answer="topic" placeholder="?" aria-label="what correct options never introduce" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Write, in one clause, a completion for this passage and justify it by its signal: <em>Many cities have widened roads to ease congestion. Traffic has instead increased on the widened routes. This suggests that ___.</em></p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>The signal "This suggests that" asks for a cautious inference from the evidence. A strong completion: "adding capacity can invite more traffic rather than relieving it". The word "suggests" keeps the claim measured; the option must not assert a certainty the evidence cannot give.</p>
                    <p>Predictable distractors: "road-widening is always a mistake" (too extreme), "drivers prefer wide roads because they are safer" (off-topic cause the passage never raised), and "congestion is unrelated to road capacity" (contradicts the passage's contrast).</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You can now complete an argument from its signals. The next lesson turns to the mechanical side of verbal accuracy: locating the single grammatical error in a sentence, where the rules are finite and the answer is deterministic.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-sentence-completion">Previous: Sentence Completion and Signal Words</a></span>
                <span><a href="/courses/hat/lessons/hat-grammar-errors">Next: Finding the Error: Grammar Rules</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
