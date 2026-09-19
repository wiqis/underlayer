// HAT course — Concept 13: Finding the error — grammar rules.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_grammar_errors() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Finding the Error: Grammar Rules — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Finding the Error: Grammar Rules</h1>
            <div class="lesson-meta">16 min · Module 3: Verbal Reasoning · Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Error identification looks like it requires an ear for English. It does not. The rules tested are a short, finite list — subject and verb agreement, preposition pairs, comparison forms, parallelism, tense consistency — and each one has a mechanical test you can apply without any feeling for style.</p>
                <p>That makes this the highest-return topic in the verbal section for a candidate whose English has gaps. A candidate with excellent intuitions and no rules will be beaten here by a candidate with ten rules and no intuitions, because the questions are built from the rules.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Do not read the sentence as a whole. Scan it in a fixed order, looking for one thing at a time.</p>
                <ol>
                    <li><strong>Find the subject and the verb.</strong> Ignore everything between them and check agreement.</li>
                    <li><strong>Check the small words.</strong> Prepositions, articles and comparison words.</li>
                    <li><strong>Check lists.</strong> Every item in a list must have the same grammatical shape.</li>
                    <li><strong>Check the time words</strong> against the tense of the verb.</li>
                </ol>
                <p>Scanning in a fixed order matters because the eye is drawn to the longest or strangest phrase, which is usually not where the error is. The error is placed in one of the four zones above, and the words around it are there to distract you.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Subject and verb agreement.</strong> The verb agrees with the subject, not with the nearest noun. Phrases beginning with <em>of</em> are traps.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Wrong</th><th scope="col">Right</th><th scope="col">Why</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>The list of items are long.</td><td>The list of items is long.</td><td>The subject is <em>list</em>, not <em>items</em></td></tr>
                        <tr><td>Each of the students have a laptop.</td><td>Each of the students has a laptop.</td><td><em>Each</em> is singular</td></tr>
                        <tr><td>One of my friend is here.</td><td>One of my friends is here.</td><td><em>One of</em> takes a plural noun</td></tr>
                        <tr><td>Neither of them are ready.</td><td>Neither of them is ready.</td><td><em>Neither</em> is singular</td></tr>
                    </tbody>
                </table>
                <p><strong>Comparison forms.</strong> Do not double a comparison, and learn the pairs that take <em>to</em> rather than <em>than</em>.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Wrong</th><th scope="col">Right</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>This is more better.</td><td>This is better.</td></tr>
                        <tr><td>He is senior than me.</td><td>He is senior to me.</td></tr>
                        <tr><td>She is junior than him.</td><td>She is junior to him.</td></tr>
                        <tr><td>It is superior than the other.</td><td>It is superior to the other.</td></tr>
                    </tbody>
                </table>
                <p>The words that take <em>to</em> are senior, junior, superior, inferior, prior, preferable and similar. Nearly every one of them appears in a past paper at some point.</p>
                <p><strong>Preposition pairs worth memorising.</strong> <em>Discuss</em> takes no preposition (not "discuss about"); <em>explain</em> takes <em>to</em> when the listener is named ("explain to me"); <em>comprise</em> takes no <em>of</em>; <em>cope</em> takes <em>with</em>, without <em>up</em>; <em>married</em> takes <em>to</em>; <em>return</em> takes no <em>back</em>. Preposition errors are among the easiest marks on the paper once you have the list.</p>
                <p><strong>Countable and uncountable.</strong> Fewer with countable things, less with quantities: <em>fewer people</em>, <em>less water</em>, <em>fewer books</em>, <em>less traffic</em>. Similarly <em>many</em> with countable nouns and <em>much</em> with uncountable ones.</p>
                <p><strong>Parallelism.</strong> Items joined by <em>and</em> or <em>or</em> must share a grammatical form. "She likes reading, writing, and to paint" breaks because two items are gerunds and one is an infinitive; it becomes "reading, writing and painting".</p>
                <p><strong>Tense with time words.</strong> <em>Since</em> and <em>for</em> divide cleanly: <em>since</em> needs a point in time (since Monday), <em>for</em> needs a duration (for three months). "He has gone yesterday" fails because a finished past time cannot take the present perfect: it becomes "He went yesterday".</p>
                <p><strong>Misplaced modifiers.</strong> A participial phrase at the start of a sentence attaches to the subject that follows. "Walking home, the rain soaked me" claims the rain was walking; it becomes "Walking home, I was soaked by the rain".</p>
                <div class="callout callout-tip">
                    <strong>Articles by sound, not by letter.</strong> Use <em>an</em> before a vowel sound: an hour, an honest man, an MBA. Use <em>a</em> before a consonant sound even when the letter is a vowel: a university, a European, a one-way street.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>The committee, after reviewing all the documents submitted by the applicants, have decided to postpone the announcement.</em></p>
                <p>The eye goes to the long phrase in the middle and suspects it. That phrase is grammatically fine. The error is in the zone the method checks first: subject and verb. Strip out the interrupting phrase and the sentence reads "The committee ... have decided", where the subject is singular. The correction is <strong>has decided</strong>.</p>
                <p>Note both halves of the lesson. First, interrupting phrases are decoration — remove them and check agreement. Second, collective nouns such as committee, team, jury and government are treated as singular in formal written English, which is the register this test uses.</p>
              </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Find the error: The list of items are long.</p>
                    <button class="quiz-option" data-correct="false" data-explain="items is the object of the preposition of, and the number of the object does not control the verb." onclick="checkQuiz('quiz-1', this)">items</button>
                    <button class="quiz-option" data-correct="true" data-explain="The subject is the singular list, so the verb should be is. The plural items is a decoy placed between the subject and the verb." onclick="checkQuiz('quiz-1', this)">are</button>
                    <button class="quiz-option" data-correct="false" data-explain="long is an adjective complement and agrees with the singular subject without any change." onclick="checkQuiz('quiz-1', this)">long</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Find the error: She is senior than her colleague in the department.</p>
                    <button class="quiz-option" data-correct="false" data-explain="senior is the correct word; the problem is the word that follows it." onclick="checkQuiz('quiz-2', this)">senior</button>
                    <button class="quiz-option" data-correct="true" data-explain="Senior takes to, not than: she is senior to her colleague. The same applies to junior, superior, inferior and prior." onclick="checkQuiz('quiz-2', this)">than</button>
                    <button class="quiz-option" data-correct="false" data-explain="colleague is the correct noun here; the error is in the comparison word." onclick="checkQuiz('quiz-2', this)">colleague</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Find the error: She likes reading, writing, and to paint.</p>
                    <button class="quiz-option" data-correct="false" data-explain="reading and writing are both gerunds, and they are consistent with each other." onclick="checkQuiz('quiz-3', this)">reading</button>
                    <button class="quiz-option" data-correct="true" data-explain="The list must be parallel. Two items are gerunds, so the third must also be a gerund: painting." onclick="checkQuiz('quiz-3', this)">to paint</button>
                    <button class="quiz-option" data-correct="false" data-explain="likes correctly takes a gerund list here, and its form is not the problem." onclick="checkQuiz('quiz-3', this)">likes</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: list four words that take <em>to</em> instead of <em>than</em> in comparisons, and give the rule for <em>since</em> versus <em>for</em>.</p>
                <p>The answer is: senior, junior, superior and inferior; also prior, preferable and similar. <em>Since</em> takes a point in time, while <em>for</em> takes a duration.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>With countable nouns we use <input type="text" class="fill-blank" data-answer="fewer" placeholder="?" aria-label="countable quantifier" />, and with uncountable nouns we use <input type="text" class="fill-blank" data-answer="less" placeholder="?" aria-label="uncountable quantifier" />. The correct form is one of my <input type="text" class="fill-blank" data-answer="friends" placeholder="?" aria-label="noun after one of my" />. Before vowel sounds we use the article <input type="text" class="fill-blank" data-answer="an" placeholder="?" aria-label="article before a vowel sound" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Find every error in this sentence and fix it: <em>Each of the participants have been informed about the changes, and neither of the supervisors are available to discuss about the schedule.</em></p>
                <details>
                    <summary>Show the corrections</summary>
                    <p>There are three errors, and each one belongs to a different zone in the checklist.</p>
                    <p><em>Each of the participants have</em> breaks subject and verb agreement: <em>each</em> is singular, so it becomes <strong>has</strong>. This is the first zone, and the plural noun immediately before the verb is the decoy.</p>
                    <p><em>Neither of the supervisors are</em> is the same error again, and the test writers do repeat rules within one sentence: <em>neither</em> is singular, so <strong>neither ... is available</strong>. A candidate who catches the first one and stops has left a mark on the table.</p>
                    <p><em>Discuss about</em> is a preposition pair: <em>discuss</em> takes no preposition, so it becomes <strong>discuss the schedule</strong>. This one is invisible to anyone reading for meaning, because the sentence's meaning was never in doubt — which is exactly why the preposition list has to be memorised rather than felt.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Grammar rules work at the level of the sentence. The final verbal lesson moves up to the level of the paragraph. Reading comprehension is where the verbal section spends the most words and the most time, and where a small number of habits decide whether you finish or run out of clock.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-sentence-completion">Previous: Sentence Completion and Signal Words</a></span>
                <span><a href="/courses/hat/lessons/hat-reading-comprehension">Next: Reading Comprehension Under Time</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
