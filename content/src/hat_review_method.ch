// HAT course — Module 5: retrieval, spacing and interleaving so review sticks.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_review_method() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("How to Review So It Sticks - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>How to Review So It Sticks</h1>
            <div class="lesson-meta">16 min &middot; Module 5: The Athlete's Program &middot; Review system</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Reading a page again feels like learning. It is fluent, comfortable, and almost useless. The fluency comes from recognition, not from recall: your eye passes over a sentence you have seen before and the feeling of familiarity is mistaken for the ability to produce the answer under a clock.</p>
                <p>Unreviewed, a freshly learned fact decays quickly, with the sharpest drop in the first days after you meet it. The fix is not more reading. It is arranging to meet the fact again, from memory, at the moments when it is sliding away.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three habits turn review into memory. Each is cheap; together they are most of the difference between a topic you have seen and a topic you own.</p>
                <ul>
                    <li><strong>Retrieval.</strong> Produce the answer from memory before checking. The effort of recall is what strengthens the trace; seeing the answer does not.</li>
                    <li><strong>Spacing.</strong> Review just before you would forget, then widen the gaps. Every successful recall at a wider interval raises the threshold for the next one.</li>
                    <li><strong>Interleaving.</strong> Mix topics inside a session instead of finishing one before starting the next. It feels harder, and it is, because you must choose the right rule each time.</li>
                </ul>
                <p>The model omits two things. It does not say how long to wait for any individual fact, because the right interval depends on how easily that fact came back last time. And it assumes the material was understood first; retrieval cannot rescue a rule you never grasped.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The three techniques, side by side</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Technique</th><th scope="col">What you actually do</th><th scope="col">Why it works</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><strong>Retrieval</strong></td><td>Close the page and write the rule, the formula or the answer from memory, then check</td><td>Recall effort strengthens the memory far more than re-reading, which only feels productive</td></tr>
                        <tr><td><strong>Spacing</strong></td><td>Return to the item after a gap, and stretch the gap each time it comes back correctly</td><td>Reviewing at the edge of forgetting is the moment that buys the most lasting retention</td></tr>
                        <tr><td><strong>Interleaving</strong></td><td>Shuffle topics in one set, so percentages sit beside ratios and grammar beside vocabulary</td><td>Choosing the method for each question builds the skill the HAT actually tests</td></tr>
                        <tr><td><strong>Explaining aloud</strong></td><td>Say the rule in plain words as if teaching a friend, and note where the words run out</td><td>The gaps in a spoken explanation are exactly the gaps in your understanding</td></tr>
                    </tbody>
                </table>
                <h3>The spacing schedule</h3>
                <p>A simple expanding ladder covers most items. Re-attempt the item cold at each rung, and if it returns correctly, move up; if not, repeat at the same interval rather than advancing.</p>
                <div class="formula">first review &rarr; day 1 &rarr; day 3 &rarr; day 7 &rarr; day 21 &rarr; retire</div>
                <div class="callout callout-tip">
                    <strong>Do the queue before new material.</strong> In Underlayer, every concept seeds review items on the server, and the dashboard's review queue is spaced repetition with a forgetting-curve scheduler. Clear the daily queue first, and the same items come back exactly when you are about to lose them.
                </div>
                <div class="callout callout-warn">
                    <strong>Do not confuse recognition with recall.</strong> Looking at a worked answer and thinking "yes, I knew that" is not evidence. Only producing it from a blank page counts, so keep the page closed until you have tried.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p>On a Monday, a candidate logs one error: percentage change computed on the new value instead of the original. The rule is now written on one line. Here is the review schedule that follows from the ladder.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Rung</th><th scope="col">When</th><th scope="col">What is done</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Day 1</td><td>Tuesday</td><td>Redo one percentage-change question cold and write the rule from memory first</td></tr>
                        <tr><td>Day 3</td><td>Thursday</td><td>Two fresh percentage-change questions, plus the rule stated aloud</td></tr>
                        <tr><td>Day 7</td><td>Next Monday</td><td>One question inside a mixed set that also includes ratio and averages</td></tr>
                        <tr><td>Day 21</td><td>Three weeks on</td><td>One percentage question in a timed mini-drill; correct without hesitation retires the item</td></tr>
                    </tbody>
                </table>
                <p>Four short contacts over three weeks, roughly ten minutes in total, and the trap stops recurring. The same ladder applies to a grammar rule, a vocabulary word or a geometry formula; only the item changes, not the spacing.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Which activity best strengthens a topic you have already understood?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Re-reading raises familiarity, which is mistaken for knowledge, but it does not practise the recall the exam demands." onclick="checkQuiz('quiz-1', this)">Re-reading the lesson notes twice</button>
                    <button class="quiz-option" data-correct="true" data-explain="Producing the answer from memory is retrieval practice, and the effort of recall is what actually makes the memory durable." onclick="checkQuiz('quiz-1', this)">Closing the page and answering from memory</button>
                    <button class="quiz-option" data-correct="false" data-explain="Highlighting is passive marking of text, and it creates the same illusion of learning as re-reading without any recall." onclick="checkQuiz('quiz-1', this)">Highlighting the key sentences in colour</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>When should each spaced review be scheduled?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Reviewing immediately after learning, while the item is still fresh, adds little; the useful moment is later, when recall becomes effortful." onclick="checkQuiz('quiz-2', this)">Immediately after the first learning session</button>
                    <button class="quiz-option" data-correct="true" data-explain="The productive moment is just before you would forget, and the gap widens each time the item returns correctly, which is the whole logic of spaced repetition." onclick="checkQuiz('quiz-2', this)">Just before you would forget, with widening gaps</button>
                    <button class="quiz-option" data-correct="false" data-explain="A fixed monthly review ignores how the item behaved last time; the interval must expand with each successful recall." onclick="checkQuiz('quiz-2', this)">On one fixed day every month, regardless of recall</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>You work percentages, then ratios, then percentages again inside one session. What is this called?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Cramming is massed practice on one topic; switching between topics is the opposite, and it forces you to select the right rule each time." onclick="checkQuiz('quiz-3', this)">Cramming</button>
                    <button class="quiz-option" data-correct="true" data-explain="Mixing topics in one set is interleaving, and it builds the discrimination the paper tests because each question demands a fresh choice of method." onclick="checkQuiz('quiz-3', this)">Interleaving</button>
                    <button class="quiz-option" data-correct="false" data-explain="Highlighting is a reading behaviour with no recall; the mixing of topics has a different name and a different purpose." onclick="checkQuiz('quiz-3', this)">Highlighting</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>When should you clear the Underlayer review queue?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Leaving it until after new material means the queue competes with fatigue, and the items due are exactly the ones sliding away now." onclick="checkQuiz('quiz-4', this)">After finishing the new material for the day</button>
                    <button class="quiz-option" data-correct="true" data-explain="The queue is scheduled for when forgetting begins, so it is the highest-yield block of the session and belongs before new study." onclick="checkQuiz('quiz-4', this)">Before starting new material</button>
                    <button class="quiz-option" data-correct="false" data-explain="Waiting for a mock leaves due items to decay for no reason; the queue is a daily habit, not an exam-week task." onclick="checkQuiz('quiz-4', this)">Only in the week before a mock test</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: name the three review habits and the first three rungs of the spacing ladder.</p>
                <p>The answer: retrieval, spacing and interleaving; the ladder is day 1, day 3 and day 7, then day 21.</p>
                <div id="fill-1">
                    <p>Spaced repetition schedules each review just before you would <input type="text" class="fill-blank" data-answer="forget" placeholder="?" aria-label="what spacing anticipates" />. Retrieval practice means testing yourself rather than <input type="text" class="fill-blank" data-answer="reading" placeholder="?" aria-label="passive activity to avoid" /> the material again. Mixing topics within one session is called <input type="text" class="fill-blank" data-answer="interleaving" placeholder="?" aria-label="mixing technique" />. In Underlayer, clear the daily <input type="text" class="fill-blank" data-answer="queue" placeholder="?" aria-label="daily queued task" /> before starting new material.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Take one rule you keep forgetting from your error log. Write it on a single line, then schedule four cold re-attempts on the ladder: day 1, day 3, day 7 and day 21. Decide now what question you will attempt at each rung.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>The rule must be small enough to fit on one line, because a line can be recalled and a paragraph cannot. "Percentage change divides by the original" is a rule; "percentages" is a topic and cannot be reviewed.</p>
                    <p>At each rung the task is the same in form: close the page, produce the rule from memory, then answer a fresh question of that type. The first rung is deliberately close, while the trace is still fragile. By day 7 the item should be embedded in a mixed set, because that is where interleaving tests whether you can still find the rule when it is not signposted.</p>
                    <p>If any rung fails, the item does not advance; it repeats at the same interval. If all four succeed, retire it and replace it with the next line on your forgetting page. Four or five such items running in parallel, refreshed weekly, is a complete personal review system, and it costs less than fifteen minutes a day.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Review is now scheduled rather than hoped for. The next lesson turns the technique into a target: how to work out the score you actually need, measure your gap to it, and project whether your current rate of improvement will close it in time.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-error-log">Previous: The Error Log</a></span>
                <span><a href="/courses/hat/lessons/hat-score-targets">Next: What Score Do You Need?</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
