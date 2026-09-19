// HAT course — Synonyms and antonyms: the highest-frequency verbal question type.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_synonyms_antonyms() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Synonyms and Antonyms — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Synonyms and Antonyms</h1>
            <div class="lesson-meta">16 min · Module 3: Verbal Reasoning · Vocabulary in action</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The verbal section's largest single block is vocabulary: a word, four options, one meaning. It is also the block that improves fastest, because it has no ceiling on how much you can prepare and no ambiguity about what is being asked. Two hundred well-chosen words, learned with roots and in sentences, is worth more marks than any technique in this course.</p>
                <p>There is a technique half as well: even when the word is unfamiliar, the options can usually be cut from four to two using roots, tone and part of speech. That is the difference between a section at 50% and a section at 70%.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A synonym question asks for the option <strong>closest in meaning</strong>; an antonym question asks for the option <strong>most nearly opposite</strong>. Neither asks for an identical word, which is why degree and tone matter.</p>
                <div class="formula">predict &rarr; cover the options &rarr; match &rarr; eliminate by degree</div>
                <p>The order matters. Reading four options first anchors you on them and makes you choose whichever you recognise; predicting first forces you to use the word itself. Then eliminate by degree: if the word means "humid" and an option says "soaking", the option is too strong.</p>
                <p>Antonym questions have their own trap: two options often fit the same direction — one a synonym, one a near-synonym — and the genuine opposite looks less familiar. Ask what the word's <em>opposite pole</em> is: not "unrelated to it", but the far end of its own axis.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Roots that decode unfamiliar words</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Root</th><th scope="col">Meaning</th><th scope="col">Words</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>bene / mal</td><td>good / bad</td><td>benevolent, benefit, malice, malfunction</td></tr>
                        <tr><td>ver</td><td>truth</td><td>verify, veracity, verdict</td></tr>
                        <tr><td>cred</td><td>believe</td><td>credible, incredulous, credentials</td></tr>
                        <tr><td>lum</td><td>light</td><td>lucid, luminous, illuminate</td></tr>
                        <tr><td>ten</td><td>hold</td><td>tenacious, tenant, retain</td></tr>
                        <tr><td>greg</td><td>flock, group</td><td>gregarious, congregate, segregate</td></tr>
                        <tr><td>loqu / locu</td><td>speak</td><td>loquacious, eloquent, elocution</td></tr>
                        <tr><td>path</td><td>feeling</td><td>apathy, sympathy, pathetic</td></tr>
                        <tr><td>phil</td><td>love</td><td>philanthropy, bibliophile</td></tr>
                        <tr><td>dict</td><td>say</td><td>predict, contradict, dictate</td></tr>
                        <tr><td>spec / vid</td><td>look / see</td><td>inspect, spectacle, evident, provide</td></tr>
                        <tr><td>mit / miss</td><td>send</td><td>transmit, dismiss, emissary</td></tr>
                        <tr><td>chron</td><td>time</td><td>chronology, chronic, synchronise</td></tr>
                        <tr><td>pseudo</td><td>false</td><td>pseudonym, pseudoscience</td></tr>
                    </tbody>
                </table>
                <h3>A word bank worth owning</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Word</th><th scope="col">Meaning</th><th scope="col">Word</th><th scope="col">Meaning</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>lucid</td><td>clear, easy to understand</td><td>obscure</td><td>unclear, little known</td></tr>
                        <tr><td>candid</td><td>frank, honest</td><td>evasive</td><td>avoiding a direct answer</td></tr>
                        <tr><td>gregarious</td><td>sociable</td><td>taciturn</td><td>reserved, saying little</td></tr>
                        <tr><td>laconic</td><td>using very few words</td><td>verbose</td><td>using too many words</td></tr>
                        <tr><td>ephemeral</td><td>short-lived</td><td>perpetual</td><td>never-ending</td></tr>
                        <tr><td>meticulous</td><td>extremely careful</td><td>negligent</td><td>careless</td></tr>
                        <tr><td>tenacious</td><td>persistent, holding on</td><td>irresolute</td><td>wavering</td></tr>
                        <tr><td>magnanimous</td><td>generous, forgiving</td><td>petty</td><td>small-minded</td></tr>
                        <tr><td>frugal</td><td>thrifty, sparing</td><td>extravagant</td><td>wasteful</td></tr>
                        <tr><td>mitigate</td><td>to make less severe</td><td>exacerbate</td><td>to make worse</td></tr>
                        <tr><td>impartial</td><td>fair, unbiased</td><td>biased</td><td>prejudiced</td></tr>
                        <tr><td>austere</td><td>plain, severe</td><td>lavish</td><td>richly abundant</td></tr>
                        <tr><td>pragmatic</td><td>practical</td><td>dogmatic</td><td>asserting unproven beliefs</td></tr>
                        <tr><td>diligent</td><td>hard-working</td><td>indolent</td><td>lazy</td></tr>
                        <tr><td>prevalent</td><td>widespread</td><td>scarce</td><td>hard to find</td></tr>
                        <tr><td>redundant</td><td>needlessly repeated</td><td>concise</td><td>brief and clear</td></tr>
                        <tr><td>capricious</td><td>unpredictably changing</td><td>steadfast</td><td>firmly constant</td></tr>
                        <tr><td>ubiquitous</td><td>found everywhere</td><td>rare</td><td>uncommon</td></tr>
                        <tr><td>dubious</td><td>doubtful</td><td>certain</td><td>beyond doubt</td></tr>
                        <tr><td>parsimonious</td><td>extremely stingy</td><td>generous</td><td>freely giving</td></tr>
                    </tbody>
                </table>
                <h3>How to learn words so they survive to exam day</h3>
                <ul>
                    <li><strong>Ten a day, not a hundred a week.</strong> Volume without repetition produces a word you will meet on the paper and not recognise.</li>
                    <li><strong>Every word gets a sentence.</strong> Meaning attaches to a context: "candid press conference", "laconic reply".</li>
                    <li><strong>Pair it with its opposite.</strong> Learning lucid/obscure together doubles a single memorisation and answers both forms of the question.</li>
                    <li><strong>Revisit on days 1, 3 and 7.</strong> The same spacing the platform's review queue uses, applied by hand if you prefer paper.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>Tone and part of speech.</strong> "Notorious" means famous for something bad, so it is not a synonym of "famous". And "novel" is an adjective meaning new before it is a noun meaning a book — check how the word is used in the stem sentence before choosing.
                </div>
                <div class="callout callout-warn">
                    <strong>The antonym trap.</strong> When two options point the same way ("relieve" and "soften" for the opposite of "aggravate"), neither can be the answer — the question wants the other pole, not a synonym of one pole. Read all four options before deciding.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. CANDID is most nearly:</h3>
                <p>Predict first: candid means open and honest, like an unposed photograph. Options: deceitful, frank, hesitant, polished. "Deceitful" is the opposite pole, "hesitant" is unrelated, "polished" describes style. <strong>Frank</strong> is the match.</p>
                <h3>2. Choose the word most nearly opposite to FRUGAL:</h3>
                <p>Frugal means sparing with money, so the opposite pole is wasteful. Options: thrifty, extravagant, careful, poor. "Thrifty" is a synonym (same direction, so eliminated), "careful" is adjacent, and "poor" describes a state, not a habit. <strong>Extravagant</strong>.</p>
                <h3>3. MALEVOLENT is most nearly:</h3>
                <p>Decode with the root: mal = bad, vol = wish, so "wishing harm". Options: kind, spiteful, timid, powerful. <strong>Spiteful</strong>. Knowing three roots (bene, mal, vol) answers this in five seconds.</p>
                <h3>4. The word OBSCURE in "an obscure regulation" most nearly means:</h3>
                <p>Used of a regulation, obscure means little known or hard to understand — not physically dark. Options: unclear, dim, hidden, complicated. <strong>Unclear</strong> fits the context best; "dim" is the physical sense, which does not apply to a regulation.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>LACONIC most nearly means:</p>
                    <button class="quiz-option" data-correct="false" data-explain="Talkative is the opposite pole; a laconic person is the one who says little while a loquacious person talks a great deal." onclick="checkQuiz('quiz-1', this)">talkative</button>
                    <button class="quiz-option" data-correct="true" data-explain="Laconic means using very few words: a laconic reply is brief to the point of bluntness." onclick="checkQuiz('quiz-1', this)">using very few words</button>
                    <button class="quiz-option" data-correct="false" data-explain="Musical is unrelated; it may be confused with the sound of the word rather than its meaning." onclick="checkQuiz('quiz-1', this)">musical</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Choose the word most nearly opposite to MITIGATE:</p>
                    <button class="quiz-option" data-correct="false" data-explain="Relieve is a synonym of mitigate, so it points the same way and cannot be the opposite." onclick="checkQuiz('quiz-2', this)">relieve</button>
                    <button class="quiz-option" data-correct="true" data-explain="Mitigate means to make less severe; its opposite pole is to make worse. Both admit and relieve are the same direction as mitigate." onclick="checkQuiz('quiz-2', this)">aggravate</button>
                    <button class="quiz-option" data-correct="false" data-explain="Measure is unrelated to severity; mitigate is about reducing harm, not about assessing it." onclick="checkQuiz('quiz-2', this)">measure</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>You meet a word you have never seen. What is the best first move?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Choosing the option you recognise is exactly how the familiar-but-wrong distractor is built." onclick="checkQuiz('quiz-3', this)">Pick the option whose word you recognise</button>
                    <button class="quiz-option" data-correct="true" data-explain="Decode the roots, look for a prefix such as bene or mal, and use the tone of the sentence; elimination is worth more than recognition." onclick="checkQuiz('quiz-3', this)">Break the word into roots and use the sentence's tone</button>
                    <button class="quiz-option" data-correct="false" data-explain="Because there is no negative marking, skipping a verbal item gives away a question that elimination could have won." onclick="checkQuiz('quiz-3', this)">Skip it and save the time</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>Choose the word most nearly opposite to TENACIOUS:</p>
                    <button class="quiz-option" data-correct="false" data-explain="Stubborn is a near-synonym of tenacious, in the same direction rather than opposite." onclick="checkQuiz('quiz-4', this)">stubborn</button>
                    <button class="quiz-option" data-correct="true" data-explain="Tenacious means holding on firmly; its opposite is giving way easily, that is, irresolute or wavering." onclick="checkQuiz('quiz-4', this)">irresolute</button>
                    <button class="quiz-option" data-correct="false" data-explain="Strong is adjacent in meaning rather than opposed; tenacity is persistence, and its opposite is giving up." onclick="checkQuiz('quiz-4', this)">strong</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: give one word meaning short-lived, one meaning careless, and the root that means "truth".</p>
                <p>The answer: ephemeral, negligent, and ver (as in verify and veracity).</p>
                <div id="fill-1">
                    <p>A word meaning short-lived is <input type="text" class="fill-blank" data-answer="ephemeral" placeholder="?" aria-label="word meaning short-lived" />. A word meaning careless is <input type="text" class="fill-blank" data-answer="negligent" placeholder="?" aria-label="word meaning careless" />. The root meaning truth is <input type="text" class="fill-blank" data-answer="ver" placeholder="?" aria-label="root for truth" />, and the root meaning bad is <input type="text" class="fill-blank" data-answer="mal" placeholder="?" aria-label="root for bad" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Decode these four words you have not memorised, using roots and prefixes only: <strong>incredulous</strong>, <strong>circumspect</strong>, <strong>maladroit</strong>, <strong>benevolent</strong>. Then say which two are close to opposite in meaning and why.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p><strong>Incredulous</strong> = in (not) + cred (believe) + ous (full of) = unable to believe, sceptical. <strong>Circumspect</strong> = circum (around) + spec (look) = looking around, therefore cautious. <strong>Maladroit</strong> = mal (bad) + adroit (skilful) = clumsy. <strong>Benevolent</strong> = bene (good) + vol (wish) = wishing good, therefore kind.</p>
                    <p>The opposition pair is <strong>benevolent</strong> and <strong>maladroit</strong> in respect of the mal/bene contrast only — but careful: maladroit is about skill, not about goodwill, so it is not a true antonym of benevolent. The genuine opposite of benevolent is malevolent (wishing harm), and the genuine opposite of maladroit is adroit (skilful). That distinction is exactly the degree-and-axis check that separates a right answer from a tempting one.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Single words are done. The next lesson puts words into relationships — analogies — where a fixed bridge sentence between two words is worth more than knowing both definitions.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-vocabulary">Previous: Vocabulary You Can Actually Learn</a></span>
                <span><a href="/courses/hat/lessons/hat-analogies">Next: Analogies and Word Relationships</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
