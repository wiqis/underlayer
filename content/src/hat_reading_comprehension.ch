// HAT course — Concept 14: Reading comprehension under time.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_reading_comprehension() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Reading Comprehension Under Time — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Reading Comprehension Under Time</h1>
            <div class="lesson-meta">18 min · Module 3: Verbal Reasoning · Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Reading comprehension is the most expensive part of the verbal section in two currencies at once: it carries the largest share of verbal marks, and it eats the largest share of your clock. A candidate who reads every passage carefully from the first word to the last will usually run out of time, and running out of time is scored exactly the same as not knowing the answer.</p>
                <p>The good news is that the passages are not testing whether you enjoy reading. They are testing a small set of operations: locating information, distinguishing the main point from a supporting detail, and following what the author does and does not claim. All three are trainable and all three are faster than careful full reading.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Change the order of operations: <strong>read the question first, then hunt through the passage.</strong></p>
                <ol>
                    <li>Read the question stems only, not the answer choices yet. The stems tell you what to look for.</li>
                    <li>Read the first and last sentence of each paragraph. Passages are built so those sentences carry the paragraph's claim.</li>
                    <li>Return to the lines the question names, and read one sentence before and after them. Answers live in their neighbourhood, not only in the named line.</li>
                    <li>Eliminate before choosing. On most questions two options are clearly wrong and two are close.</li>
                </ol>
                <p>Reading the questions first is not a shortcut for its own sake. It turns an undirected task into a search, and search is fast because you stop when you have found the thing you were told to find.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Six question types, two behaviours.</strong> Nearly every question on the paper falls into one of these, and each type tells you where in the passage to look.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Type</th><th scope="col">What it asks</th><th scope="col">Where the answer is</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Main idea</td><td>What is the passage mostly about?</td><td>First and last sentences, read together</td></tr>
                        <tr><td>Specific detail</td><td>A fact named in the question</td><td>The named lines, plus the sentence before and after</td></tr>
                        <tr><td>Inference</td><td>What follows, without being stated?</td><td>One step from the text — never a leap</td></tr>
                        <tr><td>Author's attitude</td><td>How does the author feel about it?</td><td>Adjectives and verbs of evaluation</td></tr>
                        <tr><td>Vocabulary in context</td><td>What does this word mean here?</td><td>Substitute each option into the sentence and re-read</td></tr>
                        <tr><td>Structure / function</td><td>Why is this paragraph here?</td><td>The paragraph's first sentence and its link to the previous one</td></tr>
                    </tbody>
                </table>
                <p><strong>Answer the specific questions first, and the main-idea question last.</strong> Once you have answered three specific questions, you already know what the passage said, which makes the main-idea question cheap. Doing it first means guessing with less information and having to re-read later.</p>
                <p><strong>Inference has a hard boundary.</strong> The correct inference is the option that must be true given the text. Options that are merely plausible, or that are true in the real world but not argued in the passage, are wrong. The words that give it away are <em>always</em>, <em>never</em>, <em>all</em>, <em>only</em> — extreme options are very rarely the answer.</p>
                <p><strong>Vocabulary in context is a substitution test.</strong> Do not ask what the word usually means. Put each option into the sentence, read the whole sentence again, and keep the one that leaves the meaning of the sentence unchanged.</p>
                <p><strong>Scope discipline.</strong> An option that answers the question but goes beyond the passage is wrong. A favourite wrong answer is the correct idea attached to the wrong subject, or the correct subject pushed one step too far.</p>
                <div class="callout callout-warn">
                    <strong>The clock is a share of the section, not a separate task.</strong> If a passage has four questions, it deserves roughly four times the time of a single vocabulary question. Set that budget before you start reading, and leave a passage behind when the budget is spent — unanswered questions cost the same as wrong ones, but a passage you sink into costs the rest of the section too.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Consider this passage opening: <em>Urban heat islands are usually blamed on traffic and air conditioning, and both do contribute. Yet measurements in three Pakistani cities suggest that the loss of tree cover accounts for a larger share of the rise than either source, a finding that has surprised the engineers who modelled the cities' energy demand.</em></p>
                <p>A main-idea question here is answered by reading the first and last sentences together: the author qualifies a common explanation and points to a different dominant cause. The word <em>Yet</em> is the hinge, and the last clause tells you the finding was unexpected, which is why a question about the engineers' reaction also has an answer in the passage.</p>
                <p>Now consider an inference option: "Tree planting would eliminate urban heat islands." The passage supports that tree loss contributes a large share; it says nothing about eliminating the effect, and the extreme verb <em>eliminate</em> goes beyond the text. That option is wrong for the most common reason in the whole section: scope.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>In the passage above, which sentence carries the author's main claim?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This is the common explanation the author then qualifies. It is the setup, not the claim." onclick="checkQuiz('quiz-1', this)">The first sentence, that traffic and air conditioning are blamed.</button>
                    <button class="quiz-option" data-correct="true" data-explain="The hinge word Yet turns the sentence from the common view to the author's own claim about tree cover being the larger cause." onclick="checkQuiz('quiz-1', this)">The sentence beginning Yet, that tree loss accounts for a larger share.</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a supporting detail about the engineers' reaction, not the main claim." onclick="checkQuiz('quiz-1', this)">The clause about the engineers being surprised.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Which option is the classic wrong answer to an inference question?</p>
                    <button class="quiz-option" data-correct="false" data-explain="A claim that must follow from the text is exactly what an inference question wants." onclick="checkQuiz('quiz-2', this)">A restatement of what the text already implies.</button>
                    <button class="quiz-option" data-correct="true" data-explain="Extreme wording such as eliminate, always or only pushes the option beyond what the passage argues, so it fails the must-be-true test." onclick="checkQuiz('quiz-2', this)">A conclusion with an extreme word like eliminate.</button>
                    <button class="quiz-option" data-correct="false" data-explain="An option limited to the passage's own scope is usually the correct one." onclick="checkQuiz('quiz-2', this)">An option that stays inside the passage's scope.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Roughly how should time be divided across a passage with four questions?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Equal time per question ignores that passages vary in length and difficulty, and it wastes time on easy items." onclick="checkQuiz('quiz-3', this)">Give every question the same fixed time.</button>
                    <button class="quiz-option" data-correct="true" data-explain="Budget the passage in proportion to its number of questions, set it before reading, and abandon it when the budget is spent." onclick="checkQuiz('quiz-3', this)">Set a budget in proportion to its questions.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Reading every word carefully first is the behaviour that runs candidates out of time." onclick="checkQuiz('quiz-3', this)">Read every word before touching the questions.</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: which question type should be answered last, and why? And what test decides a vocabulary-in-context question?</p>
                <p>The answer is: main idea, because the specific questions tell you what the passage contains; and substitution, putting each option into the sentence and keeping the one that leaves the meaning unchanged.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>The word that often marks the author's turn from the common view to their own is <input type="text" class="fill-blank" data-answer="yet" placeholder="?" aria-label="hinge word" />. Inference options are usually wrong when they contain extreme words such as <input type="text" class="fill-blank" data-answer="always" placeholder="?" aria-label="extreme word" />. An option that goes beyond what the passage argues fails on <input type="text" class="fill-blank" data-answer="scope" placeholder="?" aria-label="failure reason" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Take one practice passage and do it twice. The first time, read it fully and then answer the questions, and write down the seconds it took. The second time, on a fresh passage, read the question stems first, read only the first and last sentence of each paragraph, then hunt. Compare the two times and the two scores.</p>
                <details>
                    <summary>What you should expect to see</summary>
                    <p>Most candidates find the second run is meaningfully faster and no less accurate, and the reason is worth naming: the first run spent time constructing a mental summary of a passage nobody asked about, while the second run read with a question already in hand.</p>
                    <p>If the second run is faster but less accurate, the cause is nearly always one of two things. Either you read the two anchor sentences and then answered from memory instead of returning to the lines, or you accepted an option because it sounded true rather than because it was in the text. Both are fixed by returning to the passage for every answer, including the ones you feel sure about.</p>
                    <p>If the second run is not faster, check whether you actually read the stems first. The habit is easy to intend and easy to abandon under time pressure, and it only pays when it is done consistently.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The verbal module is complete. The next module changes the kind of thinking required: analytical reasoning asks not what the text says but what follows from it, and how you can tell. The reading habits you just built — separating claim from support, noticing scope — are the raw material for that module.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-grammar-errors">Previous: Finding the Error — Grammar Rules</a></span>
                <span><a href="/courses/hat/lessons/hat-critical-reasoning">Next: Assumptions, Conclusions and Arguments</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
