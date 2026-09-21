// HAT course — Prepositions, idioms and confused words.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_prepositions_idioms() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Prepositions, Idioms and Confused Words — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Prepositions, Idioms and Confused Words</h1>
            <div class="lesson-meta">16 min · Module 3: Verbal Reasoning · Fixed collocations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A preposition question looks trivial and is worth a mark: "comply ___ the rules" has exactly one correct answer, and it is correct because it is the fixed pairing, not because it follows a rule of logic. The same is true of "effect" against "affect", "principal" against "principle", and the handful of confusable word pairs the paper reuses every cycle.</p>
                <p>This is the most efficiently learned material in the whole verbal section: a closed list of roughly sixty items, each learned with one sentence. Two hours of study here typically converts to three or four marks, and those marks cannot be lost again by a bad day.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Prepositions are not chosen by meaning — they are chosen by <strong>memory of the pairing</strong>. So the study method is not reasoning, it is a list rehearsed with a sentence each:</p>
                <div class="formula">verb + fixed preposition &nbsp;·&nbsp; adjective + fixed preposition &nbsp;·&nbsp; idiom as an unbreakable unit</div>
                <p>Two habits make the list stick. First, always store the pair, never the preposition alone: "depend on", not "on". Second, store a real sentence with it: "the result depends on the sample size". A remembered sentence survives stress; a remembered list does not.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Verbs with fixed prepositions</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Verb</th><th scope="col">Preposition</th><th scope="col">Verb</th><th scope="col">Preposition</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>depend, insist, rely, congratulate</td><td>on</td><td>differ, escape, prevent, refrain</td><td>from</td></tr>
                        <tr><td>comply, interfere, agree (a person), cope</td><td>with</td><td>object, refer, listen, attend</td><td>to</td></tr>
                        <tr><td>consist, accuse (a person), approve, dispose</td><td>of</td><td>abide, stand (by a decision)</td><td>by</td></tr>
                        <tr><td>conform, prefer (one thing to another)</td><td>to</td><td>arrive (a city), believe, engage, participate</td><td>in</td></tr>
                    </tbody>
                </table>
                <h3>Adjectives with fixed prepositions</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Adjective</th><th scope="col">Preposition</th><th scope="col">Adjective</th><th scope="col">Preposition</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>afraid, aware, capable, fond, guilty, jealous</td><td>of</td><td>interested, proficient, engaged, absorbed</td><td>in</td></tr>
                        <tr><td>angry (a person), pleased, satisfied, familiar (a thing)</td><td>with</td><td>good, bad, adept, skilled, excel</td><td>at</td></tr>
                        <tr><td>responsible, eligible, famous, fit, sorry</td><td>for</td><td>superior, inferior, senior, junior, similar, married, accustomed</td><td>to</td></tr>
                        <tr><td>anxious, curious, concerned, particular</td><td>about</td><td>different, safe, protected, derived</td><td>from</td></tr>
                    </tbody>
                </table>
                <h3>Idioms to hold as whole units</h3>
                <p>on account of, in spite of, by means of, for the sake of, at the expense of, in the light of, with respect to, take into account, make up for, put up with, look forward to, look down upon, call off, carry out, give in, break down.</p>
                <h3>Confused word pairs</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Pair</th><th scope="col">Distinction</th><th scope="col">Example</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>affect / effect</td><td>affect is the verb, effect the noun</td><td>The drug affects the pulse; it had no effect</td></tr>
                        <tr><td>advice / advise</td><td>advice is the noun, advise the verb</td><td>He gave advice; he advised me to wait</td></tr>
                        <tr><td>principal / principle</td><td>principal means chief or a school head; principle is a rule</td><td>The principal reason; a matter of principle</td></tr>
                        <tr><td>its / it's</td><td>its is possessive; it's means it is</td><td>The company raised its prices; it's late</td></tr>
                        <tr><td>than / then</td><td>than compares; then marks time</td><td>Better than before; then we left</td></tr>
                        <tr><td>lie / lay</td><td>lie is intransitive; lay needs an object</td><td>I lie down; I lay the book on the table</td></tr>
                        <tr><td>complement / compliment</td><td>complement completes; compliment praises</td><td>A complement to the course; a nice compliment</td></tr>
                        <tr><td>eminent / imminent</td><td>eminent means distinguished; imminent means about to happen</td><td>An eminent scholar; imminent danger</td></tr>
                        <tr><td>adverse / averse</td><td>adverse describes conditions; averse describes reluctance</td><td>Adverse weather; averse to risk</td></tr>
                    </tbody>
                </table>
                <h3>Spellings that are marked</h3>
                <p>accommodate, definitely, separate, occurrence, necessary, government, receive, believe, maintenance, embarrass, privilege, commitment.</p>
                <div class="callout callout-tip">
                    <strong>Read the pair aloud in a sentence.</strong> Confusion between effect and affect usually disappears the moment the word has to carry a verb's work: "the policy will ___ prices" can only take affect.
                </div>
                <div class="callout callout-warn">
                    <strong>Do not reason from meaning.</strong> Many candidates argue that "comply to the rules" should be right because rules are something you move towards. The exam does not grade arguments; it grades the fixed pairing. When in doubt, recall the sentence you memorised.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. All staff must comply ___ the new safety rules.</h3>
                <p>Comply pairs with <strong>with</strong>: comply with the rules. Confidently offering "to" comes from reasoning that you comply <em>to</em> an authority — a different verb entirely.</p>
                <h3>2. The delay had no ___ on the final schedule.</h3>
                <p>Here the blank needs a noun after "had no", so it is <strong>effect</strong>. "Affect" is the verb form, and "effected" would mean brought about, which changes the meaning.</p>
                <h3>3. She is senior ___ the other officers.</h3>
                <p>Senior takes <strong>to</strong>, never "than": she is senior to the other officers. The "than" version is the classic trap because the sentence means a comparison.</p>
                <h3>4. The plan was abandoned ___ account of the strike.</h3>
                <p>The idiom is <strong>on</strong> account of. The alternatives "in account of" and "by account of" are inventions that look plausible under pressure.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>All staff must comply ___ the new safety rules.</p>
                    <button class="quiz-option" data-correct="true" data-explain="Comply with is the fixed pairing; the preposition is a matter of collocation, not of direction." onclick="checkQuiz('quiz-1', this)">with</button>
                    <button class="quiz-option" data-correct="false" data-explain="Comply to is not standard English, even though you may comply with a rule issued by an authority you comply to in a different sense." onclick="checkQuiz('quiz-1', this)">to</button>
                    <button class="quiz-option" data-correct="false" data-explain="Comply by appears only in the different phrase 'comply by doing something'; with a noun object it is comply with." onclick="checkQuiz('quiz-1', this)">by</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>She is not afraid ___ criticism.</p>
                    <button class="quiz-option" data-correct="false" data-explain="Afraid from is not used in English; the adjective pairs with of." onclick="checkQuiz('quiz-2', this)">from</button>
                    <button class="quiz-option" data-correct="true" data-explain="Afraid of is the fixed pairing, like aware of, capable of and guilty of." onclick="checkQuiz('quiz-2', this)">of</button>
                    <button class="quiz-option" data-correct="false" data-explain="Afraid to takes a verb (afraid to speak), not a noun such as criticism." onclick="checkQuiz('quiz-2', this)">to</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>The new policy had no ___ on prices.</p>
                    <button class="quiz-option" data-correct="false" data-explain="Affect is the verb: the policy affects prices. After 'had no' a noun is required." onclick="checkQuiz('quiz-3', this)">affect</button>
                    <button class="quiz-option" data-correct="true" data-explain="Effect is the noun, so 'had no effect on prices' is correct." onclick="checkQuiz('quiz-3', this)">effect</button>
                    <button class="quiz-option" data-correct="false" data-explain="Effort is a different word entirely, chosen here by its resemblance to affect." onclick="checkQuiz('quiz-3', this)">effort</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>The meeting was postponed ___ account of the strike.</p>
                    <button class="quiz-option" data-correct="false" data-explain="In account of is not an English idiom; the fixed phrase is on account of." onclick="checkQuiz('quiz-4', this)">in</button>
                    <button class="quiz-option" data-correct="true" data-explain="On account of is the fixed idiom meaning because of." onclick="checkQuiz('quiz-4', this)">on</button>
                    <button class="quiz-option" data-correct="false" data-explain="By account of is a plausible-sounding invention; keep the memorised unit on account of." onclick="checkQuiz('quiz-4', this)">by</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: which preposition follows "consist", "depend" and "responsible"?</p>
                <p>The answer: consist of, depend on, responsible for.</p>
                <div id="fill-1">
                    <p>We say depend <input type="text" class="fill-blank" data-answer="on" placeholder="?" aria-label="preposition after depend" />, consist <input type="text" class="fill-blank" data-answer="of" placeholder="?" aria-label="preposition after consist" /> and responsible <input type="text" class="fill-blank" data-answer="for" placeholder="?" aria-label="preposition after responsible" />. The noun form of affect is <input type="text" class="fill-blank" data-answer="effect" placeholder="?" aria-label="noun of affect" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Correct the preposition or word error in each sentence: (1) "The committee insisted for a written report." (2) "His answer was different than mine." (3) "Neither of the options had any affect on the result." (4) "She is capable to handling the project alone."</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>(1) Insist takes <strong>on</strong>: insisted on a written report.</p>
                    <p>(2) In formal writing, different pairs with <strong>from</strong>: different from mine. "Different than" appears in informal use, especially before clauses, and the exam prefers from.</p>
                    <p>(3) The noun is needed, so <strong>effect</strong>: no effect on the result.</p>
                    <p>(4) Capable pairs with <strong>of</strong>, and of takes the -ing form: capable of handling the project alone.</p>
                    <p>Notice the pattern in all four: each error is a fixed pairing replaced by a plausible-sounding alternative. That is why this material is learned as a list of pairs and sentences rather than as a set of rules.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Words, relationships, grammar and fixed pairs are now in place. The next lesson is the largest single verbal block on the paper and the one where technique beats vocabulary: reading comprehension under a clock.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-grammar-punctuation">Previous: Punctuation</a></span>
                <span><a href="/courses/hat/lessons/hat-reading-comprehension">Next: Reading Comprehension Under Time</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
