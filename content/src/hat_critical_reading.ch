// HAT course — Concept 16: Critical reading — tone, purpose and inference.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_critical_reading() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Critical Reading: Tone, Purpose and Inference - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Critical Reading: Tone, Purpose and Inference</h1>
            <div class="lesson-meta">18 min &middot; Module 3: Verbal Reasoning &middot; Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Ordinary comprehension asks what the passage says. Critical reading asks what the author is doing and how they feel about it. Those are different questions with different evidence, and a candidate who treats them as the same will keep choosing the option that is true but irrelevant.</p>
                <p>Three operations decide almost every such question: separating what is stated from what is only implied, reading tone from the words the author chose, and following the structure of the argument. Each has a testable procedure, and together they cover the hardest verbal items on the paper.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>For every passage, ask three questions and keep the answers separate.</p>
                <ul>
                    <li><strong>What is stated?</strong> A fact you can point to a line for. If you cannot point, it is not stated.</li>
                    <li><strong>What is implied?</strong> A claim that must follow from what is stated, one step away and no more.</li>
                    <li><strong>How does the author feel?</strong> Tone, read from adjectives, verbs and qualifiers.</li>
                </ul>
                <p>What the model omits: it cannot supply outside knowledge, and it will not tell you the author's purpose unless you notice how the paragraphs are arranged. It also omits that a single word can carry the tone, so tone must be read from individual word choices, not from the overall subject.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Purpose is a verb.</strong> Ask what the author is trying to do, and match that verb to the passage's shape.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Purpose</th><th scope="col">What the passage does</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Inform</td><td>Presents facts and findings without judging them</td></tr>
                        <tr><td>Persuade</td><td>Argues for a position and answers objections</td></tr>
                        <tr><td>Describe</td><td>Builds a picture through sensory or concrete detail</td></tr>
                        <tr><td>Criticise</td><td>Identifies faults in a theory, policy or work</td></tr>
                        <tr><td>Analyse</td><td>Breaks a topic into parts and shows how they relate</td></tr>
                        <tr><td>Compare</td><td>Sets two things side by side to reveal a difference</td></tr>
                    </tbody>
                </table>
                <p><strong>Tone lives in word choice.</strong> The same event can be reported as neutral, cautious, sceptical, critical, approving or ironic, and the clue is a small set of evaluative words.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Tone</th><th scope="col">Words that signal it</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Cautious</td><td>suggests, may, appears, preliminary</td></tr>
                        <tr><td>Sceptical</td><td>claims, allegedly, so-called, supposedly</td></tr>
                        <tr><td>Critical</td><td>flawed, neglects, misleading, overlooks</td></tr>
                        <tr><td>Approving</td><td>elegant, rigorous, promising, valuable</td></tr>
                        <tr><td>Neutral</td><td>reports, notes, documents, measures</td></tr>
                    </tbody>
                </table>
                <p><strong>Inference has a hard boundary.</strong> The correct inference is the option that must be true given the text. An option that is merely plausible, or true in the world but not argued here, is wrong. Extreme words &mdash; <em>always</em>, <em>never</em>, <em>all</em>, <em>only</em>, <em>eliminate</em> &mdash; are the most reliable signal that an option has overreached.</p>
                <p><strong>Structure and function.</strong> When a question asks why a sentence or paragraph is present, name its job: it introduces, it qualifies, it gives an example, it concedes a point, it turns the argument. The first sentence of the paragraph and its link to the previous one usually give the answer.</p>
                <div class="callout callout-tip">
                    <strong>Scope discipline.</strong> An option that answers the question but goes beyond the passage is wrong. A favourite wrong answer attaches a correct idea to the wrong subject, or pushes a correct subject one step too far.
                </div>
                <div class="callout callout-warn">
                    <strong>Stated is not implied, and implied is not imagined.</strong> If a question asks what is implied, an option that merely repeats a stated fact does not answer it, and an option that needs information from outside the passage does not either. Stay on the single step the text supports.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>A decade-long study of irrigation in the Indus basin found that fields watered at night lost roughly a third less water to evaporation than fields watered by day. The authors caution, however, that the saving depends on soil type and that night watering is impractical where electricity is rationed to daytime hours.</em></p>
                <p>An inference question asks: which conclusion is supported? The tempting wrong answer is &ldquo;night watering would reduce total water use on every farm&rdquo;. The passage found a saving on the fields studied, but adds two qualifications; <em>every</em> reaches past the evidence and the word <em>however</em> warns that the claim is limited.</p>
                <p>The supported inference is that the saving is not guaranteed for all fields, because the authors themselves tie it to soil type and to the availability of night electricity. That is one step from the text, uses the author's own qualifiers, and stops where the evidence stops.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>In the passage above, what is the authors' tone towards the finding?</p>
                    <button class="quiz-option" data-correct="false" data-explain="No evaluative words of praise appear; the authors do not celebrate the result." onclick="checkQuiz('quiz-1', this)">Enthusiastic and approving.</button>
                    <button class="quiz-option" data-correct="true" data-explain="The word caution and the two stated limits mark a cautious, qualified attitude to the finding." onclick="checkQuiz('quiz-1', this)">Cautious and qualified.</button>
                    <button class="quiz-option" data-correct="false" data-explain="The authors report the study without dismissing it, so they are not sceptical of the result itself." onclick="checkQuiz('quiz-1', this)">Dismissive and sceptical.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Which option is the strongest inference from the passage?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Every overreaches: the passage gives qualifications, so a universal claim cannot be inferred." onclick="checkQuiz('quiz-2', this)">Night watering eliminates evaporation losses on every farm.</button>
                    <button class="quiz-option" data-correct="true" data-explain="The saving is tied to soil type and to electricity, so it cannot be assumed for fields without those conditions." onclick="checkQuiz('quiz-2', this)">The saving may not apply to fields of a different soil type.</button>
                    <button class="quiz-option" data-correct="false" data-explain="This uses outside knowledge about power supply and is not argued in the passage." onclick="checkQuiz('quiz-2', this)">The region's electricity supply is unreliable.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>What is the function of the second sentence, beginning <em>The authors caution</em>?</p>
                    <button class="quiz-option" data-correct="false" data-explain="It does not state the main finding; it limits it. The finding is in the first sentence." onclick="checkQuiz('quiz-3', this)">It states the main finding of the study.</button>
                    <button class="quiz-option" data-correct="true" data-explain="It qualifies the finding by naming the conditions under which the saving holds, which is exactly the job of a qualification." onclick="checkQuiz('quiz-3', this)">It qualifies the finding by naming its limits.</button>
                    <button class="quiz-option" data-correct="false" data-explain="It does not contradict or reject the finding, only restricts its scope." onclick="checkQuiz('quiz-3', this)">It rejects the finding of the study.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>An option to an inference question contains the word <em>only</em>. What does that most likely mean?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Extreme words like only, always and never usually push an option beyond what the passage supports, so it is a strong signal of a scope error." onclick="checkQuiz('quiz-4', this)">It is probably too extreme and fails the must-be-true test.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Precision matters, but the word only usually restricts the claim in a way the passage never authorised." onclick="checkQuiz('quiz-4', this)">It is probably correct because it is precise.</button>
                    <button class="quiz-option" data-correct="false" data-explain="The word itself neither confirms nor denies correctness; it is a warning sign that must be checked against the text." onclick="checkQuiz('quiz-4', this)">It tells you nothing about the answer.</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: name three purpose verbs, and state the boundary rule for a valid inference.</p>
                <p>The answer is: inform, persuade, describe, criticise, analyse and compare. A valid inference must be one step from the text and must be something the text requires to be true.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>A claim you can point to a line for is <input type="text" class="fill-blank" data-answer="stated" placeholder="?" aria-label="explicitly given" />, while a claim that follows in one step is <input type="text" class="fill-blank" data-answer="implied" placeholder="?" aria-label="not spelled out" />. An option containing an extreme word such as only or always should be suspected of failing on <input type="text" class="fill-blank" data-answer="scope" placeholder="?" aria-label="failure reason" />. A writer who merely presents facts without judging them aims to <input type="text" class="fill-blank" data-answer="inform" placeholder="?" aria-label="purpose verb" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Take one passage and write three short lists before answering anything: the sentences that state facts, the claims that are only suggested, and the evaluative words that reveal tone.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Writing the three lists forces the separation the questions are testing. When a question asks for an inference, you answer from the second list, not the first, which prevents the common error of choosing a stated fact for an inference question.</p>
                    <p>The tone list is deliberately mechanical. You are collecting evaluative adjectives and verbs, not deciding how the passage feels in general. A passage about a serious subject can still be written in a cautious or even ironic tone, and only the word choices reveal which.</p>
                    <p>Finally, when an option survives, check it against the scope of the passage. Ask whether the passage argues this exact claim, or something narrower. The correct answer sits inside the passage's scope; the wrong ones either repeat a stated fact or step outside the text.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Critical reading closes the teaching of verbal technique. The next lesson puts everything in the module to work under a clock: a thirty-question mixed drill at the real paper's pace, with a full answer key and a repair plan.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-reading-comprehension">Previous: Reading Comprehension Under Time</a></span>
                <span><a href="/courses/hat/lessons/hat-verbal-drill">Next: Verbal Drill</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
