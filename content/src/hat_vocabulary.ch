// HAT course — Concept 10: Vocabulary you can actually learn.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_vocabulary() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Vocabulary You Can Actually Learn — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Vocabulary You Can Actually Learn</h1>
            <div class="lesson-meta">15 min · Module 3: Verbal Reasoning · Core technique</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Vocabulary questions are where candidates decide they are "bad at English". That conclusion is usually wrong. A paper cannot test a vocabulary of 100,000 words; it tests a few hundred words that recur across past papers, plus a set of Latin and Greek building blocks that let you work out words you have never met.</p>
                <p>The consequence is that this section is unusually improvable. Learning fifty roots and prefixes is a weekend of work and it pays marks in vocabulary, analogies, sentence completion and reading comprehension at the same time.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Attack an unknown word with three tools, in this order.</p>
                <ol>
                    <li><strong>Break it into parts.</strong> Prefix, root, suffix. A word with <em>mal-</em> in it is about something bad; a word with <em>bene-</em> is about something good.</li>
                    <li><strong>Sense the charge.</strong> Even without the exact meaning, decide whether the word is positive, negative or neutral. This alone eliminates roughly half of the options in most questions.</li>
                    <li><strong>Use the context.</strong> The sentence around the word constrains it more than the word's dictionary meaning does.</li>
                </ol>
                <p>The model's limit: some words are simply arbitrary, and no decomposition helps. Those are the ones to add to a review list rather than reason about.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Prefixes that reverse or oppose.</strong> un-, in-, im-, il-, ir-, dis-, mis-, anti-, counter-, non-. <em>Incredible</em>, <em>implausible</em> and <em>irreversible</em> all carry the same negative prefix in different spellings chosen for pronunciation.</p>
                <p><strong>Prefixes of direction and degree.</strong> pre- (before), post- (after), sub- (under), super- and hyper- (above), hypo- (under), over-, under-, extra-, co- (together), re- (again).</p>
                <p><strong>Roots worth memorising.</strong></p>
                <table>
                    <thead>
                        <tr><th scope="col">Root</th><th scope="col">Meaning</th><th scope="col">Examples</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>dict</td><td>say, speak</td><td>predict, contradict, malediction</td></tr>
                        <tr><td>spec / spect</td><td>look, watch</td><td>inspect, retrospect, circumspect</td></tr>
                        <tr><td>ject</td><td>throw</td><td>reject, eject, project</td></tr>
                        <tr><td>port</td><td>carry</td><td>transport, portable, export</td></tr>
                        <tr><td>scrib / script</td><td>write</td><td>describe, prescribe, manuscript</td></tr>
                        <tr><td>vert</td><td>turn</td><td>convert, revert, avert</td></tr>
                        <tr><td>duc / duct</td><td>lead</td><td>conduct, induce, abduct</td></tr>
                        <tr><td>cred</td><td>believe</td><td>credible, credulous, credentials</td></tr>
                        <tr><td>bene</td><td>good</td><td>benefit, benevolent, benediction</td></tr>
                        <tr><td>mal</td><td>bad</td><td>malice, malignant, malnutrition</td></tr>
                    </tbody>
                </table>
                <p>Combine the roots and the meaning appears without a dictionary. <em>Malediction</em> is mal (bad) plus dict (speak): a curse. <em>Benediction</em> is its opposite: a blessing. <em>Credulous</em> is cred (believe) plus the sense of "given to": someone who believes too readily — which is why <em>credulous</em> is a criticism while <em>credible</em> is a compliment.</p>
                <p><strong>Words that recur, in pairs.</strong> Learning antonyms together is more efficient than learning single words, because antonym questions are common and the pair reinforces both meanings.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Word</th><th scope="col">Meaning</th><th scope="col">Opposite</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>candid</td><td>honest, direct</td><td>evasive</td></tr>
                        <tr><td>frugal</td><td>careful with money</td><td>extravagant</td></tr>
                        <tr><td>tenacious</td><td>persistent</td><td>yielding</td></tr>
                        <tr><td>lucid</td><td>clear</td><td>obscure</td></tr>
                        <tr><td>ephemeral</td><td>lasting a very short time</td><td>enduring</td></tr>
                        <tr><td>benign</td><td>harmless, kindly</td><td>malignant</td></tr>
                        <tr><td>obstinate</td><td>stubborn</td><td>compliant</td></tr>
                        <tr><td>superficial</td><td>shallow</td><td>profound</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-tip">
                    <strong>The charge test.</strong> If a sentence needs a word that criticises someone, every positive-sounding option is wrong regardless of its precise meaning. This test does not require you to know the words, only to sense them, and it converts a four-option guess into a two-option decision.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>Choose the word closest in meaning to "ephemeral".</em></p>
                <p>Options: permanent, short-lived, colourful, expensive.</p>
                <p>The root is not decisive here — <em>ephemeral</em> comes from the Greek for "lasting a day" — so use the recall pair from the table: ephemeral is the opposite of enduring, and its meaning is something that lasts a very short time. The answer is short-lived.</p>
                <p>Now the same word inside a sentence, which is the harder form:</p>
                <p><em>The applause was ephemeral; within a minute the hall was silent again.</em></p>
                <p>Here the context does the work: the second half of the sentence tells you the applause ended quickly, so whatever <em>ephemeral</em> means, it must be consistent with a one-minute life. Notice that a candidate who does not know the word can still answer a question framed this way, provided the sentence contains a definition or a contrast. Learn to look for that structure — a semicolon, a dash, or a word like <em>although</em> — because it is placed there deliberately.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Using the roots mal and dict, what does malediction mean?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Mal means bad and dict means speak, so a malediction is a curse. Benediction, with bene, is its opposite." onclick="checkQuiz('quiz-1', this)">A curse</button>
                    <button class="quiz-option" data-correct="false" data-explain="A blessing is a benediction: bene means good. The prefix here is mal." onclick="checkQuiz('quiz-1', this)">A blessing</button>
                    <button class="quiz-option" data-correct="false" data-explain="A prediction uses dict (speak) but with pre (before); mal carries the sense of something bad." onclick="checkQuiz('quiz-1', this)">A prediction</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>What does frugal mean?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This is the opposite of frugal; a frugal person does not waste money." onclick="checkQuiz('quiz-2', this)">Extravagant</button>
                    <button class="quiz-option" data-correct="true" data-explain="Being careful with money is the opposite of being extravagant, which makes frugal the antonym of extravagant." onclick="checkQuiz('quiz-2', this)">Careful with money</button>
                    <button class="quiz-option" data-correct="false" data-explain="Wealthy describes how much money someone has, not how carefully they handle it." onclick="checkQuiz('quiz-2', this)">Wealthy</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Using the root cred, which meaning fits credulous?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Cred here means believe, so credulous is about believing, not about being brave." onclick="checkQuiz('quiz-3', this)">Courageous</button>
                    <button class="quiz-option" data-correct="true" data-explain="The root cred means believe, and the ending carries the sense of being given to a habit: someone who believes too readily." onclick="checkQuiz('quiz-3', this)">Too willing to believe things</button>
                    <button class="quiz-option" data-correct="false" data-explain="That describes credible or credible-looking, which is a different word despite the shared root." onclick="checkQuiz('quiz-3', this)">Trustworthy</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what do the roots spect, vert and port mean, and how do you handle a word you have never seen before?</p>
                <p>The answer is: to look, to turn and to carry. An unknown word is handled by splitting it into prefix, root and suffix, then checking the sentence's charge and structure before choosing.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>The prefix meaning bad is <input type="text" class="fill-blank" data-answer="mal" placeholder="?" aria-label="bad prefix" />, and describing something that lasts a very short time uses the word <input type="text" class="fill-blank" data-answer="ephemeral" placeholder="?" aria-label="short-lived word" />. The word that means honest and direct, whose opposite is evasive, is <input type="text" class="fill-blank" data-answer="candid" placeholder="?" aria-label="honest and direct" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Without a dictionary, decide what each of these words most likely means, and say which clue decided it: <em>circumspect</em>, <em>induce</em>, <em>prescribe</em>.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p><em>Circumspect</em>: spect means look, and circum means around, so the sense is looking around before acting — cautious and careful. Nothing about the word suggests certainty or speed, which is why it is the opposite of rash.</p>
                    <p><em>Induce</em>: duc means lead, and in- suggests into, so the sense is to lead someone into something — to persuade, or to bring about a result. This is why a doctor inducing labour is bringing a process about, and a fact inducing a conclusion is leading you to it.</p>
                    <p><em>Prescribe</em>: scrib means write, and pre means before, so the original sense is writing in advance — which is why it applies both to a doctor writing instructions ahead of the treatment and to a rule laid down before the situation arises. Its near-twin <em>proscribe</em> has the same root but means to forbid, since pro- here carries the sense of putting something out in front as banned; the pair is a favourite of test writers precisely because it is so easy to confuse.</p>
                    <p>The skill being practised is not memorising these three words, it is committing to an inference and being able to name the clue that produced it. Naming the clue is what prevents you from talking yourself into the wrong option under time pressure.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Vocabulary gives you the meaning of individual words. The next lesson asks something harder: given two words whose meanings you know, describe the relationship between them and find another pair sharing exactly that relationship. Analogies are the most rule-driven question type in the verbal section.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-quant-drill">Previous: Quantitative Drill</a></span>
                <span><a href="/courses/hat/lessons/hat-synonyms-antonyms">Next: Synonyms and Antonyms</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
