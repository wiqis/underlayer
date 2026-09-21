// HAT course — Concept 11: Analogies and word relationships.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_analogies() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Analogies and Word Relationships — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Analogies and Word Relationships</h1>
            <div class="lesson-meta">14 min · Module 3: Verbal Reasoning · Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Analogy questions look like vocabulary questions, and that is what makes them dangerous. The distractors are chosen to share the <em>subject matter</em> of the stem, so a candidate who works by association — "doctor, hospital, that feels related" — will find two or three options that feel right and pick the wrong one.</p>
                <p>Analogies are actually the most rule-driven question type in the verbal section. There is a finite list of relationships, and every correct answer uses the same relationship as the stem, in the same direction. Learn the list and the question becomes mechanical.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Never read an analogy as "A is to B". Say the relationship out loud as a full sentence, then test each option against that sentence.</p>
                <div class="formula">Stem: scalpel is to surgeon as ... a tool is used by a worker</div>
                <p>Two checks make the method reliable:</p>
                <ul>
                    <li><strong>Direction.</strong> "Surgeon is to scalpel" is the reverse relationship: a worker uses a tool. If an option reverses the direction, it is wrong even if the words belong together.</li>
                    <li><strong>Category.</strong> The relation must match in kind, not only in wording. "Part to whole" is not the same as "member to category", even though both involve small-to-large.</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <table>
                    <thead>
                        <tr><th scope="col">Relationship</th><th scope="col">Example stem</th><th scope="col">The bridge sentence</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Synonym</td><td>candid : frank</td><td>These words mean the same thing</td></tr>
                        <tr><td>Antonym</td><td>lucid : obscure</td><td>These words mean opposite things</td></tr>
                        <tr><td>Part to whole</td><td>toe : foot</td><td>A toe is a part of a foot</td></tr>
                        <tr><td>Whole to part</td><td>foot : toe</td><td>A foot contains toes as parts</td></tr>
                        <tr><td>Tool to user</td><td>scalpel : surgeon</td><td>A scalpel is a tool used by a surgeon</td></tr>
                        <tr><td>Worker to workplace</td><td>surgeon : hospital</td><td>A surgeon works in a hospital</td></tr>
                        <tr><td>Cause to effect</td><td>drought : famine</td><td>A drought causes famine</td></tr>
                        <tr><td>Degree</td><td>warm : hot</td><td>Hot is a more extreme form of warm</td></tr>
                        <tr><td>Object to function</td><td>pen : write</td><td>A pen is used for writing</td></tr>
                        <tr><td>Category to member</td><td>fruit : mango</td><td>A mango is a kind of fruit</td></tr>
                        <tr><td>Worker to product</td><td>carpenter : furniture</td><td>A carpenter makes furniture</td></tr>
                        <tr><td>Object to characteristic</td><td>glass : fragile</td><td>Glass is characteristically fragile</td></tr>
                    </tbody>
                </table>
                <p>Order matters inside each of these. Toe : foot is part to whole; foot : toe is the reverse. Test writers regularly offer the reverse of the correct relationship as a distractor, and it is the single most common wrong answer.</p>
                <p><strong>The elimination routine.</strong> Write the bridge sentence first, then strike out every option that fails one of these three tests: the relationship is a different kind, the direction is reversed, or the words belong to a different level of generality. Usually two options survive, and the difference between them is precision — one is "a tool used by a worker", the other is "a tool used by a specific kind of worker".</p>
                <div class="callout callout-tip">
                    <strong>Same-form trick.</strong> Check the grammatical shape of the stem. If the stem is noun : noun, the answer is almost always noun : noun. An option that is noun : verb is usually a trap, regardless of how sensible it sounds.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>Scalpel is to surgeon as which of the following?</em></p>
                <p>Options: hammer to carpenter, hospital to patient, needle to injection, medicine to illness.</p>
                <p>Bridge sentence: a scalpel is a tool used by a surgeon. Now test each option against that sentence.</p>
                <ul>
                    <li><em>Hammer to carpenter</em>: a hammer is a tool used by a carpenter. Same relationship, same direction, same grammatical form. This is the answer.</li>
                    <li><em>Hospital to patient</em>: a hospital is a place where a patient is treated. A place, not a tool, and the second word is not the user. Different relationship.</li>
                    <li><em>Needle to injection</em>: a needle is used in an injection — an object-to-process relation, and the second word is not a person at all.</li>
                    <li><em>Medicine to illness</em>: medicine treats an illness, a cause-to-effect-ish relation in the opposite direction from the stem.</li>
                </ul>
                <p>Notice that three of the four options are medical, which is exactly the trap. The words feel related to the stem's world; only one of them repeats the stem's relationship. Working from the bridge sentence rather than from association is what makes the question trivial.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Scalpel is to surgeon as which of the following?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Tool to user, same direction: a hammer is a tool used by a carpenter, exactly as a scalpel is used by a surgeon." onclick="checkQuiz('quiz-1', this)">Hammer is to carpenter</button>
                    <button class="quiz-option" data-correct="false" data-explain="Place to person, not tool to user. The relationship has changed even though the topic feels related." onclick="checkQuiz('quiz-1', this)">Hospital is to patient</button>
                    <button class="quiz-option" data-correct="false" data-explain="Object to process, and the second word is not a person. The bridge sentence for the stem needs a user." onclick="checkQuiz('quiz-1', this)">Needle is to injection</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Drought is to famine as which of the following?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This is effect to cause, the reverse direction of the stem." onclick="checkQuiz('quiz-2', this)">Illness is to virus</button>
                    <button class="quiz-option" data-correct="true" data-explain="Cause to effect, same direction: a drought causes famine and an earthquake causes destruction." onclick="checkQuiz('quiz-2', this)">Earthquake is to destruction</button>
                    <button class="quiz-option" data-correct="false" data-explain="These are near-synonyms: the relationship in the stem is causation, not sameness." onclick="checkQuiz('quiz-2', this)">Storm is to tempest</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Toe is to foot as which of the following?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This is whole to part; the stem is part to whole." onclick="checkQuiz('quiz-3', this)">Tree is to branch</button>
                    <button class="quiz-option" data-correct="true" data-explain="Part to whole: a finger is part of a hand, just as a toe is part of a foot." onclick="checkQuiz('quiz-3', this)">Finger is to hand</button>
                    <button class="quiz-option" data-correct="false" data-explain="Part to whole, but at the wrong level: the stem pairs a digit with its limb (toe with foot), so the match must be finger with hand. A hand is only a part of the body, not the corresponding limb-level part." onclick="checkQuiz('quiz-3', this)">Hand is to body</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what is the first thing you should write down for an analogy question, and what are the three tests an option must pass?</p>
                <p>The answer is: a bridge sentence stating the stem's relationship. An option must use the same kind of relationship, in the same direction, at the same level of generality.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>A tool-to-user stem is answered by another <input type="text" class="fill-blank" data-answer="tool" placeholder="?" aria-label="tool to user" /> to user pair. If the stem is part to whole, an option that is whole to part has its <input type="text" class="fill-blank" data-answer="direction" placeholder="?" aria-label="what is reversed" /> reversed. Warm is to hot is a relationship of <input type="text" class="fill-blank" data-answer="degree" placeholder="?" aria-label="relationship type" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Build the bridge sentence for each stem and name the relationship, then say which single test eliminates the tempting wrong option: <em>obstinate : stubborn</em>, <em>carpenter : furniture</em>, <em>glass : fragile</em>.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p><em>Obstinate : stubborn</em> is a synonym pair — the words mean the same thing, which matters because a near-miss option will offer a related but unequal pair, such as stubborn : angry, where one word is not equivalent to the other.</p>
                    <p><em>Carpenter : furniture</em> is worker to product, and the direction test decides it: "a carpenter makes furniture" cannot be reversed into "furniture makes a carpenter". An option like furniture : wood is object to material, a different relationship that the subject matter makes tempting.</p>
                    <p><em>Glass : fragile</em> is object to characteristic, and the precision test decides it: an option like glass : transparent also names a real characteristic, so the question would distinguish the two by the stem's specificity. Where two options both name a true characteristic, return to the stem and match how general it is — fragile is a defining property of glass, while transparent is one of several.</p>
                    <p>The habit to take away is that the bridge sentence is not a warm-up, it is the answer. Write it down even when the analogy looks obvious, because the obvious cases are exactly where association takes over and the reversed-direction distractor wins.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Analogies test relationships between words you are given. Sentence completion tests the reverse skill: choosing a word to fit a structure that is already there, using the sentence's own signals as clues. Those signals — contrast, cause, addition — are a short list, and learning them is next.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-synonyms-antonyms">Previous: Synonyms and Antonyms</a></span>
                <span><a href="/courses/hat/lessons/hat-sentence-completion">Next: Sentence Completion and Signal Words</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
