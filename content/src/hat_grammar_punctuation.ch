// HAT course — Concept 18: Punctuation and sentence boundaries.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_grammar_punctuation() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Punctuation and Sentence Boundaries - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Punctuation and Sentence Boundaries</h1>
            <div class="lesson-meta">15 min &middot; Module 3: Verbal Reasoning &middot; Grammar rules</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Punctuation looks like decoration and is actually structure. The comma, semicolon and colon are the marks that tell a reader where one grammatical unit ends and the next begins, and two of the most common sentence errors &mdash; the comma splice and the run-on &mdash; are punctuation failures rather than meaning failures.</p>
                <p>Because these questions are decided by a small number of rules, they are among the most reliable marks in the grammar section. You do not need to like the marks to be able to place them correctly.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>First find the clause boundaries, then choose the mark that fits the boundary.</p>
                <ul>
                    <li><strong>Two independent clauses</strong> need a full stop, a semicolon, or a comma plus a conjunction.</li>
                    <li><strong>A list or an explanation</strong> is introduced by a colon, not a semicolon.</li>
                    <li><strong>A non-restrictive clause</strong> &mdash; extra information that can be removed &mdash; is enclosed in commas.</li>
                    <li><strong>An introductory phrase</strong> is followed by a comma before the main clause begins.</li>
                </ul>
                <p>What the model omits: it does not cover every optional comma of rhythm, because style commas vary between publishers, and it does not settle apostrophes, which are a separate decision about possession and contraction.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>The marks and their jobs.</strong> Each mark has one main function; misuse is almost always a boundary error.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Mark</th><th scope="col">Its job</th><th scope="col">Example</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Comma</td><td>Separates list items, follows an opener, encloses extra information</td><td>We bought tea, rice, and salt.</td></tr>
                        <tr><td>Semicolon</td><td>Joins two independent clauses without a conjunction</td><td>The test was hard; the class was ready.</td></tr>
                        <tr><td>Colon</td><td>Introduces a list or an explanation after a complete clause</td><td>He needed three things: time, help, and money.</td></tr>
                        <tr><td>Apostrophe</td><td>Marks possession or a contraction</td><td>the teacher's book; it's raining</td></tr>
                        <tr><td>Dash</td><td>Marks a strong break or an aside</td><td>The answer &mdash; and this is crucial &mdash; was wrong.</td></tr>
                    </tbody>
                </table>
                <p><strong>Commas in a list.</strong> Items in a simple series are separated by commas, and a final comma before <em>and</em> removes ambiguity. In a list of longer phrases, the commas keep the items distinct.</p>
                <p><strong>Commas after introductory material.</strong> When a sentence opens with a phrase or subordinate clause, a comma marks the point where the main clause begins: <em>After the storm passed, the streets dried quickly.</em></p>
                <p><strong>Non-restrictive versus restrictive clauses.</strong> Extra information that can be removed takes commas: <em>My brother, who lives in Quetta, is a doctor.</em> Information that identifies which one does not: <em>The brother who lives in Quetta is a doctor.</em> The commas change the meaning, not just the pacing.</p>
                <p><strong>A colon must follow a complete clause.</strong> &ldquo;He needed: time and money&rdquo; is wrong because what precedes the colon is not a sentence. Write <em>He needed time and money</em>, or <em>He needed two things: time and money.</em></p>
                <p><strong>Apostrophes.</strong> Singular possession adds an apostrophe and s (<em>the student's notes</em>); plural possession that already ends in s adds only the apostrophe (<em>the students' notes</em>). Contractions mark missing letters: <em>it is</em> becomes <em>it's</em>, while <em>its</em> is the possessive and never takes an apostrophe.</p>
                <div class="callout callout-tip">
                    <strong>The semicolon test.</strong> If the two halves could each stand alone as a sentence, a semicolon is legal. If either half cannot stand alone, the semicolon is wrong and a comma is usually needed.
                </div>
                <div class="callout callout-warn">
                    <strong>Two boundary errors to name.</strong> A comma splice joins two independent clauses with only a comma: <em>The experiment failed, the team repeated it.</em> A run-on joins them with no mark at all: <em>The experiment failed the team repeated it.</em> Both are fixed by a semicolon, a full stop, or a comma plus a conjunction.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>The experiment failed the team repeated it with a new sample and the second attempt succeeded.</em></p>
                <p>Read the clauses. <em>The experiment failed</em> is a sentence on its own, and <em>the team repeated it with a new sample</em> is another. They are jammed together with no mark, which makes this a run-on. The first fix is a semicolon or a full stop: <strong>The experiment failed; the team repeated it with a new sample.</strong></p>
                <p>The next clause, <em>and the second attempt succeeded</em>, is joined by the conjunction <em>and</em>, which is legal, but a comma before the conjunction makes the whole sentence easier to follow. The corrected sentence reads: <em>The experiment failed; the team repeated it with a new sample, and the second attempt succeeded.</em></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Which mark correctly joins the clauses: <em>The results were clear ____ the team published them immediately.</em></p>
                    <button class="quiz-option" data-correct="false" data-explain="A comma alone between two independent clauses is a comma splice." onclick="checkQuiz('quiz-1', this)">a comma</button>
                    <button class="quiz-option" data-correct="true" data-explain="A semicolon legally joins two independent clauses without a conjunction." onclick="checkQuiz('quiz-1', this)">a semicolon</button>
                    <button class="quiz-option" data-correct="false" data-explain="A colon introduces a list or explanation, not a second clause that simply continues the narrative." onclick="checkQuiz('quiz-1', this)">a colon</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Which sentence correctly uses the apostrophe?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Its is the possessive form and takes no apostrophe; it is is the contraction it's." onclick="checkQuiz('quiz-2', this)">The cat licked it's paw.</button>
                    <button class="quiz-option" data-correct="true" data-explain="The apostrophe marks the missing letter in the contraction it is." onclick="checkQuiz('quiz-2', this)">It's going to rain tonight.</button>
                    <button class="quiz-option" data-correct="false" data-explain="A plural noun ending in s takes the apostrophe after the s for possession: the students' notes." onclick="checkQuiz('quiz-2', this)">All the student's notes were lost.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Which sentence is correct?</p>
                    <button class="quiz-option" data-correct="false" data-explain="What precedes the colon is not a complete clause, so the colon has no clause to introduce." onclick="checkQuiz('quiz-3', this)">He needed: time, help, and money.</button>
                    <button class="quiz-option" data-correct="true" data-explain="The colon follows a complete clause and introduces the list that explains it." onclick="checkQuiz('quiz-3', this)">He needed three things: time, help, and money.</button>
                    <button class="quiz-option" data-correct="false" data-explain="A semicolon must join two independent clauses, but a list is not a clause." onclick="checkQuiz('quiz-3', this)">He needed three things; time, help, and money.</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>Identify the sentence error: <em>The traffic was heavy, we arrived late.</em></p>
                    <button class="quiz-option" data-correct="true" data-explain="Two independent clauses joined by only a comma form a comma splice; a semicolon or a conjunction is needed." onclick="checkQuiz('quiz-4', this)">comma splice</button>
                    <button class="quiz-option" data-correct="false" data-explain="A run-on has no punctuation between the clauses; here a comma is present." onclick="checkQuiz('quiz-4', this)">run-on</button>
                    <button class="quiz-option" data-correct="false" data-explain="A misplaced modifier attaches to the wrong noun; there is no such modifier here." onclick="checkQuiz('quiz-4', this)">misplaced modifier</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: state the difference between a comma splice and a run-on, and give the two possessive forms of a singular and a plural noun.</p>
                <p>The answer is: a comma splice joins two independent clauses with only a comma, while a run-on joins them with no mark at all. Singular possession is <em>student's</em> and plural possession is <em>students'</em>.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>Two independent clauses can be joined without a conjunction by a <input type="text" class="fill-blank" data-answer="semicolon" placeholder="?" aria-label="mark joining clauses" />. A mark that introduces a list after a complete clause is the <input type="text" class="fill-blank" data-answer="colon" placeholder="?" aria-label="mark before a list" />. Two clauses joined by only a comma make a comma <input type="text" class="fill-blank" data-answer="splice" placeholder="?" aria-label="comma boundary error" />. The possessive of it is written <input type="text" class="fill-blank" data-answer="its" placeholder="?" aria-label="possessive of it" />, with no apostrophe.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Punctuate and correct this passage: <em>The manager reviewed the report it contained three errors she sent it back for revision the author was not pleased.</em></p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Start by marking every clause that could stand alone. <em>The manager reviewed the report</em> is one. <em>It contained three errors</em> is another. <em>She sent it back for revision</em> is a third, and <em>the author was not pleased</em> is a fourth.</p>
                    <p>All four are independent, so pairing them with commas alone would produce comma splices. The first pair is best joined with a semicolon or a full stop; the second pair likewise, or with a conjunction. One valid result is: <em>The manager reviewed the report; it contained three errors. She sent it back for revision, and the author was not pleased.</em></p>
                    <p>The point of the exercise is the order of operations. Find the boundaries first, then choose the marks; if you punctuate by ear you will join some clauses and split others, and the result will be inconsistent.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Punctuation closes the grammar sequence. The next lesson turns to collocation: the prepositions, idioms and easily confused word pairs that are fixed by usage rather than derived from a rule.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-grammar-tenses">Previous: Tenses, Articles and Conditionals</a></span>
                <span><a href="/courses/hat/lessons/hat-prepositions-idioms">Next: Prepositions and Idioms</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
