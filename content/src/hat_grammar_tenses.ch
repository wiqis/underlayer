// HAT course — Concept 17: Tenses, articles and conditionals.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_grammar_tenses() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Tenses, Articles and Conditionals - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Tenses, Articles and Conditionals</h1>
            <div class="lesson-meta">16 min &middot; Module 3: Verbal Reasoning &middot; Grammar rules</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Tense, articles and conditionals are the three systems that decide whether a sentence places events correctly in time and marks them as old or new information. They are also the areas where second-language writers most often rely on feel and get it wrong, because the mother tongue marks these things differently or not at all.</p>
                <p>The good news is that all three are closed systems. There are twelve tenses but only a handful of forms, four conditional patterns, and one decision for each article. Learn the patterns and the errors become visible.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Place the verb on two axes at once: time (present, past, future) and aspect (simple, continuous, perfect, perfect continuous).</p>
                <ul>
                    <li><strong>Simple</strong> states a fact or a habit.</li>
                    <li><strong>Continuous</strong> shows an action in progress around a time.</li>
                    <li><strong>Perfect</strong> links an earlier action to a later reference point.</li>
                    <li><strong>Perfect continuous</strong> shows a duration continuing up to a reference point.</li>
                </ul>
                <p>What the model omits: it does not tell you which tense a particular time word demands, and it leaves out the sequence rule in reported speech, where a past reporting verb pulls later verbs back one step. Treat it as a map of the system, not a substitute for the time words.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>The twelve tenses, each with one anchor word.</strong> Learn the anchor, then match it.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Tense</th><th scope="col">Form</th><th scope="col">Uses when</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Present simple</td><td>works</td><td>habits, general truths, timetables</td></tr>
                        <tr><td>Present continuous</td><td>is working</td><td>now, temporary situations</td></tr>
                        <tr><td>Present perfect</td><td>has worked</td><td>past linked to now; for, since, already, yet</td></tr>
                        <tr><td>Present perfect cont.</td><td>has been working</td><td>duration still continuing</td></tr>
                        <tr><td>Past simple</td><td>worked</td><td>finished past time; yesterday, in 2015</td></tr>
                        <tr><td>Past continuous</td><td>was working</td><td>in progress when something else happened</td></tr>
                        <tr><td>Past perfect</td><td>had worked</td><td>earlier of two past actions; by the time</td></tr>
                        <tr><td>Past perfect cont.</td><td>had been working</td><td>duration up to a past point</td></tr>
                        <tr><td>Future simple</td><td>will work</td><td>prediction, decision now</td></tr>
                        <tr><td>Future continuous</td><td>will be working</td><td>in progress at a future time</td></tr>
                        <tr><td>Future perfect</td><td>will have worked</td><td>completed before a future point</td></tr>
                        <tr><td>Future perfect cont.</td><td>will have been working</td><td>duration up to a future point</td></tr>
                    </tbody>
                </table>
                <p><strong>The four conditionals.</strong> The pattern is fixed, and the mistake is almost always a mismatched pair.</p>
                <div class="formula">Zero: if + present simple, present simple &mdash; general truth</div>
                <div class="formula">First: if + present simple, will + base &mdash; real future possibility</div>
                <div class="formula">Second: if + past simple, would + base &mdash; unreal present</div>
                <div class="formula">Third: if + had + past participle, would have + past participle &mdash; unreal past</div>
                <p>Never put <em>would</em> in the if-clause: &ldquo;if I would have known&rdquo; is wrong, and the third conditional gives <em>if I had known</em>. Likewise, the second conditional pairs a past form in the if-clause with <em>would</em> in the main clause, not another past form.</p>
                <p><strong>Articles follow sound and information.</strong> Use <em>a</em> before a consonant sound and <em>an</em> before a vowel sound, judged by sound, not spelling: a university, a European, an hour, an MBA. Use <em>the</em> for something already mentioned, unique, or specified by a phrase. Use the zero article for plurals and uncountables in a general sense: water, books, honesty.</p>
                <div class="callout callout-tip">
                    <strong>Since versus for.</strong> <em>Since</em> takes a point in time (since Monday, since 2019); <em>for</em> takes a duration (for three months). Both take the present perfect when the period continues to now: &ldquo;I have lived here for two years.&rdquo;
                </div>
                <div class="callout callout-warn">
                    <strong>Present perfect cannot sit with finished past time.</strong> &ldquo;He has gone yesterday&rdquo; fails because <em>yesterday</em> is a closed past point, which requires the past simple: &ldquo;He went yesterday.&rdquo; This single mismatch is the most tested tense error in the paper.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>By the time the inspector arrived, the staff has been working since six in the morning and had not yet completed the audit.</em></p>
                <p>There is one tense fault. After <em>by the time the inspector arrived</em>, the reference point is in the past, so the duration up to that point needs the past perfect continuous: <strong>had been working</strong>, not <em>has been working</em>. The <em>since six</em> keeps its point in time, which is correct.</p>
                <p>The second verb, <em>had not yet completed</em>, is already the past perfect and correctly places completion before the same past reference point. The corrected sentence reads: <em>By the time the inspector arrived, the staff had been working since six in the morning and had not yet completed the audit.</em></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Which is correct: <em>I have visited Karachi in 2015.</em></p>
                    <button class="quiz-option" data-correct="false" data-explain="The present perfect cannot combine with a finished past point such as in 2015." onclick="checkQuiz('quiz-1', this)">I have visited Karachi in 2015.</button>
                    <button class="quiz-option" data-correct="true" data-explain="A named finished past time requires the past simple: I visited Karachi in 2015." onclick="checkQuiz('quiz-1', this)">I visited Karachi in 2015.</button>
                    <button class="quiz-option" data-correct="false" data-explain="The past continuous suggests an action in progress at a time, which is not the meaning here." onclick="checkQuiz('quiz-1', this)">I was visiting Karachi in 2015.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Complete the third conditional: <em>If I ____ known, I would have called.</em></p>
                    <button class="quiz-option" data-correct="false" data-explain="Would never appears in the if-clause of any conditional." onclick="checkQuiz('quiz-2', this)">would have</button>
                    <button class="quiz-option" data-correct="true" data-explain="The third conditional pairs if plus had plus past participle with would have plus past participle." onclick="checkQuiz('quiz-2', this)">had</button>
                    <button class="quiz-option" data-correct="false" data-explain="A present simple here would make a first conditional, which does not match the would have in the main clause." onclick="checkQuiz('quiz-2', this)">have</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Which article fits: <em>She waited for ____ hour before the interview.</em></p>
                    <button class="quiz-option" data-correct="false" data-explain="A is used before consonant sounds, but hour begins with a vowel sound because the h is silent." onclick="checkQuiz('quiz-3', this)">a</button>
                    <button class="quiz-option" data-correct="true" data-explain="An is used before a vowel sound, and hour begins with the vowel sound in the silent h." onclick="checkQuiz('quiz-3', this)">an</button>
                    <button class="quiz-option" data-correct="false" data-explain="The points to something specific already known, but no particular hour has been mentioned yet." onclick="checkQuiz('quiz-3', this)">the</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>Which is correct: <em>She has been teaching here ____ 2018.</em></p>
                    <button class="quiz-option" data-correct="true" data-explain="Since takes a point in time, and 2018 is a point, so the present perfect continuous is correct." onclick="checkQuiz('quiz-4', this)">since</button>
                    <button class="quiz-option" data-correct="false" data-explain="For takes a duration such as four years, not a starting point such as 2018." onclick="checkQuiz('quiz-4', this)">for</button>
                    <button class="quiz-option" data-correct="false" data-explain="During takes a period in which something happens, not a starting point." onclick="checkQuiz('quiz-4', this)">during</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: give the form of the third conditional, and state the rule that separates since from for.</p>
                <p>The answer is: if plus had plus past participle, then would have plus past participle. <em>Since</em> takes a point in time and <em>for</em> takes a duration, and both use the present perfect when the period continues to the present.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>The past perfect of the verb work is <input type="text" class="fill-blank" data-answer="had worked" placeholder="?" aria-label="past perfect of work" />. In the second conditional, the if-clause uses the past simple and the main clause uses <input type="text" class="fill-blank" data-answer="would" placeholder="?" aria-label="main clause modal" />. Before a vowel sound we write the article <input type="text" class="fill-blank" data-answer="an" placeholder="?" aria-label="article before a vowel sound" />. A finished past time such as yesterday requires the <input type="text" class="fill-blank" data-answer="past" placeholder="?" aria-label="tense for finished past time" /> simple, not the present perfect.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Find every error and correct it: <em>Since five years, the team has been working on the project, and when the funding ended they have already published two papers.</em></p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>The first fault is the preposition. <em>Since</em> needs a point in time, but <em>five years</em> is a duration, so it becomes <strong>For five years</strong>. The present perfect continuous that follows is correct, because the activity continues to now.</p>
                    <p>The second fault is in the past clause. <em>When the funding ended</em> sets a finished past reference point, so an action completed before that point needs the past perfect, not the present perfect: <strong>they had already published two papers</strong>.</p>
                    <p>The corrected sentence reads: <em>For five years, the team has been working on the project, and when the funding ended they had already published two papers.</em> The pattern is worth naming: a present reference point takes the present perfect, and a past reference point takes the past perfect.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Tenses and conditionals organise what a sentence says; punctuation organises how it is delivered. The next lesson covers the marks that separate clauses and lists, and the two boundary errors &mdash; the comma splice and the run-on &mdash; that turn two sentences into one illegal one.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-grammar-agreement">Previous: Agreement, Pronouns and Modifiers</a></span>
                <span><a href="/courses/hat/lessons/hat-grammar-punctuation">Next: Punctuation</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
