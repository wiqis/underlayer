// HAT course — Concept 15: Sentence correction by rewriting the underlined part.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_sentence_correction() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Sentence Correction - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Sentence Correction</h1>
            <div class="lesson-meta">16 min &middot; Module 3: Verbal Reasoning &middot; Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Sentence correction is the twin of error identification, and confusing the two is the fastest way to lose marks on it. In error identification the fault is hidden and you find one word. Here the faulty portion is already underlined, and your job is to rewrite the whole underlined part so that the sentence becomes correct.</p>
                <p>That changes the skill. You are no longer hunting for a fault; you are choosing among five versions of the same clause, and the four wrong ones are engineered to look plausible. The rules remain finite &mdash; agreement, pronouns, tense, parallelism, modifiers, comparison forms and idiom &mdash; and each has a mechanical test.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Read the sentence for meaning first, and only then look hard at the underlined part.</p>
                <ol>
                    <li><strong>Read the whole sentence.</strong> The underlined part may be wrong only in relation to words outside it.</li>
                    <li><strong>Predict the fix before reading the options.</strong> A self-generated answer is harder to mislead.</li>
                    <li><strong>Walk the checklist.</strong> Agreement, pronoun, tense, parallelism, modifier, comparison, idiom.</li>
                    <li><strong>Eliminate on the first provable error.</strong> Once an option breaks a rule, it is gone.</li>
                    <li><strong>Keep &ldquo;no change&rdquo; as a candidate.</strong> It is a real option and is sometimes the answer.</li>
                </ol>
                <p>What the model omits: some options differ only by idiom, which cannot be reasoned out and must be remembered, and a few sentences contain two errors at once, both inside the underline. It also omits that two options may be grammatical while one is clearer &mdash; then choose the shorter and more parallel version.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>The checklist, in the order the errors usually appear.</strong> Run it every time, even when the answer feels obvious.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Check</th><th scope="col">The test</th><th scope="col">Typical fault</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Subject and verb</td><td>Strip the phrase between them and match number</td><td>The group of students <em>are</em> late</td></tr>
                        <tr><td>Pronoun</td><td>Name the noun the pronoun stands for</td><td>The firm and <em>it</em> workers</td></tr>
                        <tr><td>Tense</td><td>Compare the underlined verb with the other verbs</td><td>He <em>has left</em> yesterday</td></tr>
                        <tr><td>Parallelism</td><td>Items joined by <em>and</em> or <em>or</em> share a form</td><td>to cut, to raise, <em>increasing</em></td></tr>
                        <tr><td>Modifier</td><td>An opening phrase describes the next noun</td><td><em>Walking home</em>, the rain soaked me</td></tr>
                        <tr><td>Comparison</td><td>Match the two things being compared</td><td>The climate of Lahore is hotter than Multan</td></tr>
                        <tr><td>Idiom</td><td>Recall the fixed pair</td><td><em>discuss about</em> the plan</td></tr>
                    </tbody>
                </table>
                <p><strong>Comparisons must compare like with like.</strong> &ldquo;The climate of Lahore is hotter than Multan&rdquo; compares a climate with a city. It becomes &ldquo;hotter than that of Multan&rdquo;, or &ldquo;hotter than the climate of Multan&rdquo;. The pronoun <em>that</em> stands in for <em>the climate</em>, so the two sides finally match.</p>
                <div class="callout callout-tip">
                    <strong>No change is one of five.</strong> Test makers set the correct answer to the unchanged text a predictable fraction of the time, so treating &ldquo;no change&rdquo; as automatically wrong hands back marks. Judge it by the rules like any other option.
                </div>
                <div class="callout callout-warn">
                    <strong>Eliminate on the first error, not after full evaluation.</strong> A common mistake is to find a flaw in every option and then lose the comparison. One broken rule is enough to discard an option, and stopping there saves the most time.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>The committee's goals were to cut waste, to raise morale, and increasing output.</em> Suppose the underlined part is <em>to cut waste, to raise morale, and increasing output</em>.</p>
                <p>The list has three items joined by <em>and</em>. Two are infinitives (<em>to cut</em>, <em>to raise</em>) and the third is a gerund (<em>increasing</em>). The rule is parallelism, so the third item must match the first two.</p>
                <p>The corrected underline is <strong>to cut waste, to raise morale, and to increase output</strong>. A distractor will offer &ldquo;to cut waste, raising morale, and increasing output&rdquo;, which fixes the last item but breaks the first two. Another will offer &ldquo;cutting waste, raising morale, and to increase output&rdquo;, which reverses the fault. Only the fully parallel version survives.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Which correction makes the list parallel: <em>Her plan was to rest, to eat, and sleeping.</em></p>
                    <button class="quiz-option" data-correct="true" data-explain="Two items are infinitives, so the third must be an infinitive too: to rest, to eat, and to sleep." onclick="checkQuiz('quiz-1', this)">to rest, to eat, and to sleep</button>
                    <button class="quiz-option" data-correct="false" data-explain="Resting and eating are gerunds, so they no longer match the infinitive items that remain." onclick="checkQuiz('quiz-1', this)">resting, eating, and sleeping</button>
                    <button class="quiz-option" data-correct="false" data-explain="This mixes an infinitive with gerunds, which is the original parallelism fault moved around." onclick="checkQuiz('quiz-1', this)">to rest, eating, and sleeping</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Which correction is needed: <em>The list of items, which the manager checked twice, are on the desk.</em></p>
                    <button class="quiz-option" data-correct="false" data-explain="Items is the object of the preposition of, so its number cannot control the verb." onclick="checkQuiz('quiz-2', this)">Change items to item.</button>
                    <button class="quiz-option" data-correct="true" data-explain="The subject is the singular list, so the verb must be is. The plural items is a decoy between subject and verb." onclick="checkQuiz('quiz-2', this)">Change are to is.</button>
                    <button class="quiz-option" data-correct="false" data-explain="The relative clause is grammatically fine and is not the error." onclick="checkQuiz('quiz-2', this)">Remove the clause which the manager checked twice.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Which correction fixes the tense: <em>He said that he will finish the report the next day.</em></p>
                    <button class="quiz-option" data-correct="false" data-explain="Finish is a base form and cannot follow will after a past reporting verb in this sequence." onclick="checkQuiz('quiz-3', this)">Change finish to finished only.</button>
                    <button class="quiz-option" data-correct="true" data-explain="After the past reporting verb said, will shifts to would and the infinitive stays: he would finish." onclick="checkQuiz('quiz-3', this)">Change will to would.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Said is correctly in the past and matches the reporting clause; it is not the error." onclick="checkQuiz('quiz-3', this)">Change said to says.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>Which version is correct: <em>He is senior than me in the department.</em></p>
                    <button class="quiz-option" data-correct="false" data-explain="Than is the error; senior does not take than." onclick="checkQuiz('quiz-4', this)">He is senior than me.</button>
                    <button class="quiz-option" data-correct="true" data-explain="Senior takes to, not than: he is senior to me. The same holds for junior, superior and inferior." onclick="checkQuiz('quiz-4', this)">He is senior to me.</button>
                    <button class="quiz-option" data-correct="false" data-explain="Senior of me is wrong: senior, junior, superior and inferior all take to." onclick="checkQuiz('quiz-4', this)">He is senior of me.</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: name the first two items on the checklist, and state what &ldquo;no change&rdquo; means as an option.</p>
                <p>The answer is: subject and verb agreement, then pronoun reference. &ldquo;No change&rdquo; means the underlined part is already correct, and it is a genuine answer choice, not a throwaway.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>In this question type you rewrite the whole <input type="text" class="fill-blank" data-answer="underlined" placeholder="?" aria-label="the rewritten portion" /> part. The first check on the list is subject and <input type="text" class="fill-blank" data-answer="verb" placeholder="?" aria-label="agreement partner" /> agreement. Items joined by and must share a grammatical form, which is the rule of <input type="text" class="fill-blank" data-answer="parallelism" placeholder="?" aria-label="shared form rule" />. The noun a pronoun stands for is its <input type="text" class="fill-blank" data-answer="antecedent" placeholder="?" aria-label="noun a pronoun replaces" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Find every error and give the corrected sentence: <em>Neither of the two proposals, which the board reviewed for months, were accepted, and the director, after consulting his team, have promised to submit new ones.</em></p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>There are two errors, and both are agreement faults hiding behind interrupting phrases.</p>
                    <p><em>Neither of the two proposals ... were accepted.</em> The subject is <em>neither</em>, which is singular. The plural <em>proposals</em> sits immediately before the verb as a decoy, and the relative clause makes the gap even wider. The verb becomes <strong>was accepted</strong>.</p>
                    <p><em>The director ... have promised.</em> The subject is the singular <em>director</em>; the phrase <em>after consulting his team</em> is an interruption, and <em>team</em> is not the subject. The verb becomes <strong>has promised</strong>.</p>
                    <p>The corrected sentence reads: <em>Neither of the two proposals, which the board reviewed for months, was accepted, and the director, after consulting his team, has promised to submit new ones.</em> The lesson is to strip interruptions before every agreement check, in both halves of the sentence.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Sentence correction asks you to repair a sentence. The next lesson is the mirror image: finding the single error in a sentence without being told where it is. The same rules apply, but the search is the skill, and the tested list is short and finite.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-paragraph-completion">Previous: Paragraph Completion</a></span>
                <span><a href="/courses/hat/lessons/hat-grammar-errors">Next: Finding the Error: Grammar Rules</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
