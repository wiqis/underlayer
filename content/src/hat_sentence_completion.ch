// HAT course — Concept 12: Sentence completion and signal words.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_sentence_completion() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Sentence Completion and Signal Words — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Sentence Completion and Signal Words</h1>
            <div class="lesson-meta">14 min · Module 3: Verbal Reasoning · Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Sentence completion is the most learnable question type in the paper, and the one most often answered by feel. Candidates read the sentence, sense a general meaning, then choose the option that "sounds right" — which is precisely how distractors are designed to win.</p>
                <p>The sentence gives you more help than it appears to. The connective words in it — <em>although</em>, <em>because</em>, <em>moreover</em> — tell you the direction the blank must move, before you have any idea which word belongs there. Read those words first and half the options eliminate themselves.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A blank is a hole with a sign next to it. Your job is to read the sign before choosing the filling.</p>
                <ol>
                    <li><strong>Find the signals.</strong> Connective words and punctuation. A colon introduces an explanation; a semicolon joins two parallel clauses; <em>although</em> promises a contradiction.</li>
                    <li><strong>Predict the direction and charge.</strong> Does the blank move with the sentence or against it? Positive, negative or neutral?</li>
                    <li><strong>Only then look at the options.</strong> Eliminate by direction and charge first, by precise meaning second.</li>
                </ol>
                <p>With two blanks, work on the more constrained one first. Usually one blank sits next to a signal word and the other does not; solving the constrained blank often removes two or three options outright.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>The signal words, grouped by what they promise.</strong></p>
                <table>
                    <thead>
                        <tr><th scope="col">Group</th><th scope="col">Words</th><th scope="col">What the blank must do</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Contrast</td><td>although, though, even though, however, nevertheless, nonetheless, yet, but, despite, in spite of, whereas, ironically</td><td>Move against the other clause — the two halves disagree</td></tr>
                        <tr><td>Cause and effect</td><td>because, since, therefore, thus, hence, consequently, as a result, accordingly</td><td>Move with the other clause — one half explains the other</td></tr>
                        <tr><td>Addition</td><td>and, moreover, furthermore, besides, in addition, similarly, likewise</td><td>Continue in the same direction as what came before</td></tr>
                        <tr><td>Example</td><td>for instance, for example, such as, namely</td><td>Be a specific instance of the general claim</td></tr>
                        <tr><td>Condition</td><td>if, unless, provided that, as long as</td><td>Hold only under the stated condition</td></tr>
                    </tbody>
                </table>
                <p><strong>Watch the near-miss pairs.</strong> <em>Because of</em> and <em>in spite of</em> look similar and mean opposite things: one gives a reason, the other gives an obstacle that did not prevent the result. <em>Since</em> can mean either "because" or "from the time that", so check which reading the sentence supports.</p>
                <p><strong>Punctuation is a signal too.</strong> A colon means "here is the explanation of what I just said". A semicolon joins two grammatically complete, related clauses, usually restating or contrasting. A dash marks an aside that often redefines the word before it.</p>
                <p><strong>The charge test.</strong> If a sentence describes a failure, a delay or a loss, the blank is negative even if you do not know the options. Strike out every clearly positive option before you compare meanings. This costs nothing and frequently leaves two candidates.</p>
                <div class="callout callout-warn">
                    <strong>The "sounds right" trap.</strong> The most attractive wrong option is almost always a word that fits the general topic of the sentence without fitting its grammar, direction or charge. Test an option by substituting it and re-reading the whole sentence, not by judging the word alone.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>Although the committee's report was ___ , its recommendations were ___: almost none of them could be put into practice.</em></p>
                <p>Find the signals. <em>Although</em> promises contrast: the two halves must disagree. The colon then explains the second half — recommendations that could not be put into practice are <em>impractical</em>, so the second blank is fixed before you look at anything else.</p>
                <p>The second blank is negative and tells you the first blank must be positive and opposing. The report was the opposite of impractical in its own right, so the first blank is about being thorough, complete or well researched. Options offering "superficial" or "careless" in the first blank are eliminated by the contrast signal alone, because they would agree with the second half instead of opposing it.</p>
                <p>The answer's shape, then, is: thorough and impractical. Notice that you reached it without needing to know that "impractical" is the more precise of several negative options — the <em>although</em> plus the colon did most of the work.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>The medicine was effective, ___ its side effects made it unsuitable for long-term use.</p>
                    <button class="quiz-option" data-correct="false" data-explain="This signals a cause, so the two halves would agree. Here the second half contradicts the first." onclick="checkQuiz('quiz-1', this)">because</button>
                    <button class="quiz-option" data-correct="true" data-explain="The clause after the blank contradicts the clause before it, so a contrast signal is needed." onclick="checkQuiz('quiz-1', this)">nevertheless</button>
                    <button class="quiz-option" data-correct="false" data-explain="Moreover adds agreement. The sentence needs disagreement, since an effective medicine with disqualifying side effects is a contrast." onclick="checkQuiz('quiz-1', this)">moreover</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Although the theory is ___ , it has never been ___ by experiment.</p>
                    <button class="quiz-option" data-correct="true" data-explain="Although signals contrast: the theory is credible in principle, yet unverified in practice." onclick="checkQuiz('quiz-2', this)">plausible ... confirmed</button>
                    <button class="quiz-option" data-correct="false" data-explain="Both blanks point the same way, so the sentence would not contrast. A disproven theory cannot also be called unconvincing under an although." onclick="checkQuiz('quiz-2', this)">doubtful ... disproven</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the reversed contrast: it says the theory is weak yet accepted, which is the opposite of the sentence's logic." onclick="checkQuiz('quiz-2', this)">flawed ... accepted</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>The road was flooded; consequently, the convoy was ___ to a longer route.</p>
                    <button class="quiz-option" data-correct="false" data-explain="The signal consequently gives a result, and the convoy could not simply be delayed by a longer route; it had to take it." onclick="checkQuiz('quiz-3', this)">delayed</button>
                    <button class="quiz-option" data-correct="true" data-explain="Consequently gives the effect of the flooding, and the effect on the route was a diversion." onclick="checkQuiz('quiz-3', this)">diverted</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is positive and unrelated to the cause; the convoy did not welcome the flooding." onclick="checkQuiz('quiz-3', this)">invited</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what does <em>although</em> promise about a sentence, and how should you use a colon when you meet one?</p>
                <p>The answer is: <em>although</em> promises contrast, so the two halves must disagree in direction. A colon introduces the explanation or definition of what came immediately before it.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>The word <input type="text" class="fill-blank" data-answer="although" placeholder="?" aria-label="contrast signal" /> signals contrast, while <input type="text" class="fill-blank" data-answer="because" placeholder="?" aria-label="cause signal" /> signals a cause. A <input type="text" class="fill-blank" data-answer="colon" placeholder="?" aria-label="punctuation introducing explanation" /> introduces the explanation of the clause before it.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Two blanks, and one of them is far more constrained than the other. Decide the direction of each before thinking about any vocabulary: <em>The proposal was widely ___ at first, but as its costs became clear, support began to ___ .</em></p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Find the signals. <em>But</em> signals contrast between the two halves, and <em>as its costs became clear</em> tells you the second half describes something getting worse. So the second blank must be negative and must describe a decrease: support declined, faded, eroded.</p>
                    <p>Now the first blank. Because the second half tells you support fell, the first half must tell you it was high to begin with. The first blank must therefore be positive and about being received — welcomed, applauded, supported. The word <em>widely</em> before the blank also rules out options that are about intensity rather than breadth.</p>
                    <p>The order matters. If you started with the first blank you would have had four plausible positive words and no way to choose. Solving the second blank first turns the first into a one-option decision, which is the whole technique: find the blank the sentence has already decided for you.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Sentence completion uses signals about meaning. The next lesson is about signals of correctness: grammar. Error identification questions ask you to find the mistake in a sentence, and because the tested rules are a short, finite list, this is one of the highest-return topics in the whole verbal section.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-analogies">Previous: Analogies and Word Relationships</a></span>
                <span><a href="/courses/hat/lessons/hat-grammar-errors">Next: Finding the Error: Grammar Rules</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
