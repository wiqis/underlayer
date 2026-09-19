// HAT course — Grammar agreement: subjects, verbs, pronouns, modifiers, parallelism.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_grammar_agreement() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Agreement, Pronouns and Modifiers — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Agreement, Pronouns and Modifiers</h1>
            <div class="lesson-meta">16 min · Module 3: Verbal Reasoning · Grammar rules</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Grammar questions are the most deterministic items in the verbal section: there is one correct rule, no ambiguity and no need for a broad vocabulary. A candidate who knows fifteen rules can answer every agreement and pronoun question on the paper.</p>
                <p>The examiner's whole craft in these items is to separate the verb from its subject. "The list of items ___ long" offers the eye a plural noun ("items") right next to the blank. If you follow your ear, you write "are". If you follow the rule, you find the real subject — "list" — and write "is".</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>For every grammar sentence, ask three questions in this order:</p>
                <ol>
                    <li><strong>What is the subject?</strong> Strip out every phrase that begins with <em>of</em>, <em>with</em>, <em>along with</em>, <em>in addition to</em> or <em>together with</em> — they are not part of the subject.</li>
                    <li><strong>Is it singular or plural?</strong> Decide from the stripped-down subject, not from the nearest noun.</li>
                    <li><strong>Does everything else agree with it?</strong> Pronouns, verbs and lists must all follow the same number and form.</li>
                </ol>
                <p>The model is deliberately mechanical, because the questions are mechanical. You are not judging style; you are running a checklist.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Subject and verb agreement</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Rule</th><th scope="col">Correct</th><th scope="col">Wrong</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>The verb follows the true subject, not the nearest noun</td><td>The list of items is long</td><td>The list of items are long</td></tr>
                        <tr><td>Each, every, either, neither are singular</td><td>Each of the students has a card</td><td>Each of the students have a card</td></tr>
                        <tr><td>One of the + plural noun takes a singular verb</td><td>One of the books is missing</td><td>One of the books are missing</td></tr>
                        <tr><td>Either ... or and neither ... nor agree with the nearer subject</td><td>Neither the manager nor the clerks were ready</td><td>Neither the manager nor the clerks was ready</td></tr>
                        <tr><td>A number of takes a plural verb; the number of takes a singular verb</td><td>A number of students were absent</td><td>A number of students was absent</td></tr>
                        <tr><td>Collective nouns take a singular verb when acting as one body</td><td>The committee has decided</td><td>The committee have decided</td></tr>
                        <tr><td>Distances, amounts and periods are singular</td><td>Ten kilometres is a long walk</td><td>Ten kilometres are a long walk</td></tr>
                        <tr><td>Phrases in between do not change the number</td><td>The teacher, along with the students, was late</td><td>The teacher, along with the students, were late</td></tr>
                    </tbody>
                </table>
                <h3>Pronouns</h3>
                <ul>
                    <li><strong>After a preposition, use the object form:</strong> between you and me, for him and her.</li>
                    <li><strong>Who is a subject, whom is an object:</strong> the officer who arrested him; the officer whom we met.</li>
                    <li><strong>Its is possessive, it's means it is;</strong> their is possessive, they're means they are.</li>
                    <li><strong>Each, every and everyone</strong> take a singular pronoun in formal writing.</li>
                </ul>
                <h3>Modifiers and parallelism</h3>
                <ul>
                    <li><strong>Modifiers attach to the nearest sensible noun.</strong> "Walking down the road, a dog bit me" says the dog was walking down the road; the sentence must start with the person it describes.</li>
                    <li><strong>Lists must be parallel:</strong> reading, writing and arithmetic — not reading, writing and to do arithmetic.</li>
                    <li><strong>Comparisons must be complete and correct:</strong> she is senior to me, different from the others, taller than any other student in the class.</li>
                    <li><strong>Fewer counts, less measures:</strong> fewer students, less water; fewer rupees, less money.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>Cross out the decoy phrase.</strong> Physically strike the phrase between the subject and the verb, then read the sentence: "The list ... is long" becomes instantly obvious. This one move answers most agreement questions on the paper.
                </div>
                <div class="callout callout-warn">
                    <strong>Three traps the examiner reuses.</strong> (1) A plural noun sitting immediately before the verb. (2) "One of the", where the singular "one" governs the verb. (3) "Along with" or "as well as", which do not make a singular subject plural, whereas "and" does.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. The quality of the samples ___ excellent.</h3>
                <p>Strike "of the samples": the subject is "quality", singular, so the verb is <strong>is</strong>. The plural "samples" is the decoy.</p>
                <h3>2. Neither the principal nor the teachers ___ informed.</h3>
                <p>With neither ... nor, the verb agrees with the nearer subject: "teachers" is plural, so <strong>were</strong>.</p>
                <h3>3. Being a careful driver, ___ .</h3>
                <p>The opening modifier must describe the subject of the main clause, so the completion has to make the driver the subject: "Being a careful driver, <strong>he checked the mirrors before moving</strong>". A completion beginning with "the car" is a dangling modifier.</p>
                <h3>4. The team ___ unable to agree on a single strategy, yet its members remained cordial.</h3>
                <p>Treating the team as one body takes a singular verb: <strong>was</strong>. Note the pronoun "its", which agrees with the same singular view — the sentence is internally consistent.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Choose the correct sentence.</p>
                    <button class="quiz-option" data-correct="false" data-explain="The subject is the singular 'list', so 'are' is wrong; 'items' is a decoy inside a prepositional phrase." onclick="checkQuiz('quiz-1', this)">The list of items are long</button>
                    <button class="quiz-option" data-correct="true" data-explain="Strike 'of items': the subject is the singular 'list', so the verb is 'is'." onclick="checkQuiz('quiz-1', this)">The list of items is long</button>
                    <button class="quiz-option" data-correct="false" data-explain="'Long' describes the list, not a quantity that would license a plural verb; the number of the subject is what matters." onclick="checkQuiz('quiz-1', this)">The list of items have long</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Each of the candidates ___ submitted the form.</p>
                    <button class="quiz-option" data-correct="false" data-explain="'Each' is singular, so it takes 'has'; the plural 'candidates' does not govern the verb." onclick="checkQuiz('quiz-2', this)">have</button>
                    <button class="quiz-option" data-correct="true" data-explain="Each of the candidates has submitted: each is singular, and the verb follows that." onclick="checkQuiz('quiz-2', this)">has</button>
                    <button class="quiz-option" data-correct="false" data-explain="'Is submitted' is passive and changes the meaning; the sentence needs the perfect tense 'has submitted'." onclick="checkQuiz('quiz-2', this)">is submitted</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Which sentence avoids a dangling modifier?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This makes the report the thing that was walking down the corridor, which is the dangling modifier." onclick="checkQuiz('quiz-3', this)">Walking down the corridor, the report was found</button>
                    <button class="quiz-option" data-correct="true" data-explain="The subject of the main clause, 'the officer', is the person doing the walking, so the modifier attaches correctly." onclick="checkQuiz('quiz-3', this)">Walking down the corridor, the officer found the report</button>
                    <button class="quiz-option" data-correct="false" data-explain="Passive voice hides the actor, leaving the modifier without a subject to describe." onclick="checkQuiz('quiz-3', this)">The report was found while walking down the corridor</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>She is senior ___ me in the department.</p>
                    <button class="quiz-option" data-correct="false" data-explain="'Than' is used with comparative adjectives such as taller or older, not with senior." onclick="checkQuiz('quiz-4', this)">than</button>
                    <button class="quiz-option" data-correct="true" data-explain="Senior, junior, superior and inferior take 'to'; the pair 'senior to' is fixed." onclick="checkQuiz('quiz-4', this)">to</button>
                    <button class="quiz-option" data-correct="false" data-explain="'Of' cannot follow senior in this construction; the fixed collocation is 'senior to'." onclick="checkQuiz('quiz-4', this)">of</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what governs the verb in "one of the books ___ missing", and which pairs take "to" rather than "than"?</p>
                <p>The answer: the singular word "one"; and senior, junior, superior and inferior all take "to".</p>
                <div id="fill-1">
                    <p>In "one of the books is missing", the subject is the word <input type="text" class="fill-blank" data-answer="one" placeholder="?" aria-label="the true subject" />, which is singular. With either ... or and neither ... nor, the verb agrees with the <input type="text" class="fill-blank" data-answer="nearer" placeholder="?" aria-label="which subject governs" /> subject. After a preposition we use the object form of a pronoun, as in between you and <input type="text" class="fill-blank" data-answer="me" placeholder="?" aria-label="object pronoun" />, and senior takes the preposition <input type="text" class="fill-blank" data-answer="to" placeholder="?" aria-label="preposition with senior" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Find and correct the single error in each of these sentences: (1) "The number of applicants have risen sharply." (2) "Ten kilometres are a long distance to walk." (3) "Neither of the two plans were acceptable." (4) "He is more taller than his brother."</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>(1) "The number of" is singular, so it takes <strong>has risen</strong> — while "a number of applicants have risen" would be correct, which is exactly why this pair is a favourite.</p>
                    <p>(2) Distances are treated as a single quantity, so <strong>is</strong> a long distance.</p>
                    <p>(3) "Neither" is singular on its own, so <strong>was</strong> acceptable. Note the contrast with "neither the manager nor the clerks were", where the nearer subject is plural.</p>
                    <p>(4) "Taller" is already comparative, so the comparative "more" is redundant: <strong>He is taller than his brother</strong>.</p>
                    <p>Each correction came from one rule, not from a sense of what sounds right — and each wrong version is precisely what "sounds right" if you read quickly.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Agreement and pronouns are the mechanical half of grammar. The next lesson turns to the other half of what the examiner tests: word pairs that are simply fixed — prepositions after verbs, idioms and confused words.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-sentence-completion">Previous: Sentence Completion and Signal Words</a></span>
                <span><a href="/courses/hat/lessons/hat-grammar-errors">Next: Finding the Error</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
