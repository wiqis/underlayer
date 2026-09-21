// HAT course — Concept 25: The error log — diagnosing every wrong answer by cause.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_error_log() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Error Log — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>The Error Log: Your Only Real Study Material</h1>
            <div class="lesson-meta">16 min · Module 5: The Athlete's Program · Review system</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Most candidates repeat the same six or seven mistakes for the whole preparation period, in different clothes. They get a percentage question wrong on Monday, a different percentage question wrong on Friday, and never notice that both failures came from dividing by the new value instead of the original.</p>
                <p>An error log fixes this by forcing the question that a score alone cannot answer: <strong>why</strong> did this one go wrong? Once you have the cause, the repair is obvious, and the same cause stops costing you marks because you can now recognise it before you commit.</p>
            </div>

            <div class="unit unit-model">
                <h2>The Model: Three Causes</h2>
                <p>Every wrong answer in the HAT comes from one of three places. Naming the cause is the whole technique.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Cause</th><th scope="col">What it looks like</th><th scope="col">How to fix it</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><strong>Knowledge</strong></td><td>You did not know the rule or formula. "I had no idea how to start."</td><td>Re-study the concept, then do five fresh questions of that type the same week</td></tr>
                        <tr><td><strong>Procedure</strong></td><td>You knew the rule but applied it in the wrong order, mis-drew a diagram, or missed a condition in the question</td><td>Write the correct procedure in one line and drill it on new examples until it is automatic</td></tr>
                        <tr><td><strong>Attention</strong></td><td>You knew it, could do it, and lost it anyway — misread "not", copied a number wrong, answered the wrong question</td><td>Adopt a fixed check (re-read the final line, check units and signs) and slow down on the last step</td></tr>
                    </tbody>
                </table>
                <p>The distribution is what matters. If most misses are <em>knowledge</em>, study more content. If they are <em>procedure</em>, drill. If they are <em>attention</em>, your problem is not the syllabus at all, and more studying will not touch it — you need habits, not facts.</p>
                <div class="callout callout-tip">
                    <strong>Attention errors are the cheapest marks in the paper.</strong> A candidate losing 8 marks a paper to misreads can recover most of them in two weeks with one rule: before marking an option, re-read the question's final line and confirm it asks what you answered. No new knowledge required.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Detail: Building the Log</h2>
                <p>Use a simple table, on paper or in a spreadsheet. Five columns are enough — resistance to adding more is what kills logs.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Date</th><th scope="col">Question</th><th scope="col">What I did</th><th scope="col">Cause</th><th scope="col">Fix</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Mar 04</td><td>Percentage change from 300 to 350</td><td>Divided 50 by 350</td><td>Procedure</td><td>Percentage change always divides by the <em>original</em>. Write "change / original" at the top of rough paper</td></tr>
                        <tr><td>Mar 04</td><td>Seating puzzle, question 3</td><td>Answered from memory, no diagram</td><td>Procedure</td><td>Draw the row before reading the sub-questions; never more than 5 seconds of thinking without paper</td></tr>
                        <tr><td>Mar 06</td><td>Sum of first n terms</td><td>Could not recall the formula</td><td>Knowledge</td><td>Learn n(n+1)/2 and test it on n=4 before trusting it</td></tr>
                        <tr><td>Mar 06</td><td>Which option does <em>not</em> weaken the argument</td><td>Answered a "weakens" question</td><td>Attention</td><td>Underline the negative word in every question before answering</td></tr>
                    </tbody>
                </table>
                <h3>Rules for a log that actually works</h3>
                <ul>
                    <li><strong>Write the cause within 24 hours.</strong> A week later you will not remember what you were thinking, and the log reduces to a list of questions with no diagnosis.</li>
                    <li><strong>One line per error, not a paragraph.</strong> If a repair needs more than one line, it is a knowledge gap and belongs in a separate "rules I keep forgetting" page.</li>
                    <li><strong>Re-attempt every logged question cold</strong> three to seven days later. If you get it right without help, it retires from the log; if not, the cause was misdiagnosed.</li>
                    <li><strong>Review the log the day before the test.</strong> Not the syllabus, not new material — the log. It is a personalised list of exactly how you lose marks.</li>
                    <li><strong>Count by cause weekly.</strong> Knowing that "six attention, two procedure, one knowledge" this week tells you what next week's training is.</li>
                </ul>
                <div class="callout callout-warn">
                    <strong>Do not log everything.</strong> Log the questions you got wrong <em>and</em> the ones you got right by guessing, because a lucky guess is an error that has not been charged yet. Everything else stays out; a log that takes an hour to write will be abandoned by week two.
                </div>
                <h3>The "rules I keep forgetting" page</h3>
                <p>Keep a separate single page for facts that keep costing you marks: percentage change divides by the original, "senior to" not "senior than", the 6-8-10 triangle, the contrapositive, the formula for work done. Target ten to fifteen entries. Copy it out in your own hand — the writing is part of the learning — and read it in the last week. This page is worth more in the final three days than any textbook.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p>Over three practice sets a candidate logs 21 errors. The causes split: 5 knowledge, 7 procedure, 9 attention. Their instinct is to buy another maths book.</p>
                <p>The split says otherwise. Only 5 of 21 misses came from missing knowledge; 16 came from rule application and from slips. Adding content would target the smallest bucket. The correct plan is:</p>
                <ul>
                    <li><strong>Attention (9):</strong> install one check — underline the question's key instruction, re-read the final line before marking. Practise it in the next three practice sets and count how many misreads survive.</li>
                    <li><strong>Procedure (7):</strong> write each misapplied rule on the "rules I keep forgetting" page in one line, then do five fresh questions of that type per rule.</li>
                    <li><strong>Knowledge (5):</strong> re-study those five concepts only, using this course's lessons and their quizzes.</li>
                </ul>
                <p>Two weeks later the same candidate logs 12 errors: 3 knowledge, 4 procedure, 5 attention. The reduced attention count proves the habit took hold — and no extra content was studied at all.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>You knew the formula, set the problem up correctly, then divided by the new value instead of the original. Which cause is this?</p>
                    <button class="quiz-option" data-correct="false" data-explain="You did know the formula, so the missing ingredient was not knowledge; treating it as one would send you to re-read a lesson you already understand." onclick="checkQuiz('quiz-1', this)">Knowledge</button>
                    <button class="quiz-option" data-correct="true" data-explain="Knowing the rule but applying it wrongly is a procedure failure; the fix is a one-line written procedure plus drilling it on fresh questions, not more content." onclick="checkQuiz('quiz-1', this)">Procedure</button>
                    <button class="quiz-option" data-correct="false" data-explain="An attention error is a slip such as misreading the question or copying a digit; here the arithmetic was on the right numbers with the wrong denominator, which is a rule-application error." onclick="checkQuiz('quiz-1', this)">Attention</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Your log shows 9 attention errors and 5 knowledge errors this week. What is the best use of the next week?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Adding content addresses the smallest bucket and leaves the largest one untouched; the attention errors will simply move to the new topics." onclick="checkQuiz('quiz-2', this)">Buy a new content book and study more topics</button>
                    <button class="quiz-option" data-correct="true" data-explain="The largest count is attention, and attention is repaired by habits — underlining, re-reading the final line, checking units — plus practice in which you count how many slips survive." onclick="checkQuiz('quiz-2', this)">Install a check habit and measure the slip rate in practice</button>
                    <button class="quiz-option" data-correct="false" data-explain="Sitting more mocks without changing anything produces more data about the same habit; the log has already told you what to change." onclick="checkQuiz('quiz-2', this)">Sit four more mocks and compare totals</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Which practice most improves the log's accuracy?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Waiting a week erases the memory of your reasoning, so the cause column degrades into guesswork and the repair targets the wrong thing." onclick="checkQuiz('quiz-3', this)">Writing causes a week later, after all mocks are done</button>
                    <button class="quiz-option" data-correct="true" data-explain="Causes can only be identified while the reasoning is fresh; within 24 hours the difference between a rule slip and a misread is usually still recoverable." onclick="checkQuiz('quiz-3', this)">Recording the cause within 24 hours of the mock</button>
                    <button class="quiz-option" data-correct="false" data-explain="Logging only knowledge errors hides the procedure and attention failures, which are usually the majority and the cheapest to fix." onclick="checkQuiz('quiz-3', this)">Logging only the errors where the topic was unfamiliar</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: name the three causes and one fix for each.</p>
                <p>The answer: knowledge, fixed by re-studying the concept and doing five fresh questions; procedure, fixed by writing the rule in one line and drilling it; attention, fixed with a fixed check such as re-reading the question's final line.</p>
                <div id="fill-1">
                    <p>The three causes of a wrong answer are knowledge, procedure and <input type="text" class="fill-blank" data-answer="attention" placeholder="?" aria-label="third cause" />. A question I got right by <input type="text" class="fill-blank" data-answer="guessing" placeholder="?" aria-label="how lucky answers are found" /> still belongs in the log. Causes are written within <input type="text" class="fill-blank" data-answer="24" placeholder="?" aria-label="hours to record cause" /> hours, and every logged question is re-attempted cold after 3 to <input type="text" class="fill-blank" data-answer="7" placeholder="?" aria-label="days before re-attempt" /> days.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Take your most recent set of wrong answers — from a mock, a drill, or this course's quizzes — and build the first four rows of your log. Five columns. Then count the causes and write the training they imply for the coming week.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Rows should be one line each: date, question, what I actually did, cause, fix. The "what I did" column is the important one — it is the difference between "got percentages wrong" and "divided by the new value", and only the second is repairable.</p>
                    <p>When you count, expect attention and procedure to dominate at first. This surprises candidates who assume they need more content, and it is why the log beats a score report: out of, say, ten misses, two might be knowledge, four procedure and four attention. Buying another book targets the two.</p>
                    <p>The weekly training then writes itself: for every knowledge miss, re-do the lesson and its quizzes; for every procedure miss, put a one-line rule on the forgetting page and do five fresh questions of that type; for every attention miss, name the specific habit (underline the instruction, re-read the final line, check units) and count surviving slips in the next set. Four or five consecutive weeks of this and the log starts shrinking on its own.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The log now tells you where marks are lost, and the mocks tell you whether the repairs worked. The last two lessons set the number you are aiming at and the routine for the day itself.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-mock-protocol">Previous: How to Run a Mock Test</a></span>
                <span><a href="/courses/hat/lessons/hat-review-method">Next: How to Review So It Sticks</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
