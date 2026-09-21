// HAT course — Module 5: managing energy, sleep and stamina for a two-hour paper.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_energy_management() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Energy, Sleep and Stamina - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Energy, Sleep and Stamina</h1>
            <div class="lesson-meta">15 min &middot; Module 5: The Athlete's Program &middot; Performance</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Knowledge does not sit in a sealed box waiting for the exam. It runs on a body, and that body has a daily budget of attention. The HAT asks for 100 questions in 120 minutes of unbroken focus, which is a stamina event as much as an aptitude test.</p>
                <p>A candidate who is tired does not merely work slower. They misread the final line of a question, trust a careless first answer, and abandon a hard item instead of moving on. Those are marks, and they are lost to fatigue long before they are lost to the syllabus.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Treat energy as a resource you spend and restore. Four levers govern how much of it reaches your study and your exam.</p>
                <ul>
                    <li><strong>Sleep</strong> restores the budget and consolidates the day's practice. It is preparation, not lost study time.</li>
                    <li><strong>Focus blocks</strong> spend the budget efficiently: short concentrated efforts with real breaks, not one long grind.</li>
                    <li><strong>Fuel and water</strong> keep the budget steady; skipping meals or running dry makes late-session thinking brittle.</li>
                    <li><strong>Movement</strong> resets attention cheaply; a few minutes of walking between blocks returns more than pushing through.</li>
                </ul>
                <p>The model omits individual variation. The right block length, the right bedtime and the effect of caffeine differ from person to person, so the numbers below are defaults to adjust, not rules handed down.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The four levers in practice</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Lever</th><th scope="col">What to do</th><th scope="col">What it protects</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><strong>Sleep</strong></td><td>Aim for seven to eight hours, and keep the wake time steady, including weekends</td><td>Consolidation of the day's practice and a clear head for morning work</td></tr>
                        <tr><td><strong>Focus blocks</strong></td><td>Work in blocks of about 45 minutes, then break for about 10</td><td>Attention quality across the whole session rather than only the first hour</td></tr>
                        <tr><td><strong>Fuel and water</strong></td><td>Eat before deep blocks, keep water at the desk, avoid heavy meals mid-session</td><td>Steady energy in the second and third hours of work</td></tr>
                        <tr><td><strong>Movement</strong></td><td>Walk or stretch during breaks; keep one light activity on rest days</td><td>Focus that survives the afternoon dip</td></tr>
                    </tbody>
                </table>
                <div class="formula">daily deep work = blocks &times; block length, and the cap matters more than the total</div>
                <p>Three or four true deep blocks a day is a realistic ceiling for most people. Beyond that, additional hours are spent re-reading and mis-answering, which looks like work and trains nothing.</p>
                <h3>Avoid the overactivity-collapse cycle</h3>
                <p>The common failure is a five-hour Saturday session followed by three blank days. Total hours look respectable, but the crash days waste more than the long session earned. A steady daily dose of two to three hours, held for weeks, beats spectacular weekends every time.</p>
                <div class="callout callout-tip">
                    <strong>Struggle is the signal, not the problem.</strong> When a topic feels hard and you are tempted to switch pages, that discomfort is the moment learning is happening. Name it, stay with the question for another minute, and only then take the break.
                </div>
                <div class="callout callout-warn">
                    <strong>Sleep debt fakes a lower score.</strong> Trading sleep for revision raises the hours on the clock and lowers the marks in the paper. In the final week, protect sleep as carefully as you protect the formula sheet.
                </div>
                <div class="callout callout-tip">
                    <strong>Taper the final week.</strong> Reduce volume rather than adding it: one early mock, light review and the error log, no new material, and a wake time shifted towards the test's start hour.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p>A candidate works full time and has two clear hours each weekday evening plus most of Saturday. The timetable below respects the energy budget instead of fighting it.</p>
                <pre>Mon  Deep block 45 + break 10 + practise 45   (review queue first)
Tue  Deep block 45 + break 10 + drill 45
Wed  Rest from new material: review queue only, 30 min
Thu  Deep block 45 + break 10 + drill 45
Fri  Light: vocabulary and error-log review, 30 min
Sat  Mock 120 min in the morning, then scoring and logging 40 min
Sun  Off: no study, one walk, sleep on schedule</pre>
                <p>The week holds roughly eight hours of genuine work and still leaves Wednesday and Sunday as recovery. Note what is absent: no late-night sessions, no single five-hour push, and Saturday's mock is placed at the start of the day when attention is highest.</p>
                <p>In the final week the same candidate cuts the weekday evening sessions and keeps only the review queue, then sits one mock early in the week and stops adding work. Sleep moves thirty minutes earlier each night so the wake time matches the test's start hour.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Which of these is preparation rather than lost study time?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Skipping breakfast removes fuel for the morning blocks and tends to cost attention exactly when the best work should happen." onclick="checkQuiz('quiz-1', this)">Skipping breakfast to start revising sooner</button>
                    <button class="quiz-option" data-correct="true" data-explain="Sleep consolidates the practice you have already done and restores the attention budget, so it earns its place in the plan rather than competing with it." onclick="checkQuiz('quiz-1', this)">Sleeping seven to eight hours on a steady schedule</button>
                    <button class="quiz-option" data-correct="false" data-explain="An all-nighter raises hours and lowers performance at once; the material covered is not consolidated and the next day is wrecked." onclick="checkQuiz('quiz-1', this)">Studying all night before a practice mock</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Which plan best builds the stamina the two-hour paper needs?</p>
                    <button class="quiz-option" data-correct="false" data-explain="One long weekend session followed by nothing is the overactivity-collapse cycle; it trains neither consistency nor the sustained focus the paper demands." onclick="checkQuiz('quiz-2', this)">One five-hour session every Saturday</button>
                    <button class="quiz-option" data-correct="true" data-explain="Steady focused blocks on most days build attention that lasts, and they mirror the daily demand of a two-hour paper far better than occasional marathons." onclick="checkQuiz('quiz-2', this)">Steady focused blocks on most days, with recovery days</button>
                    <button class="quiz-option" data-correct="false" data-explain="Studying to exhaustion and then taking a week off repeats the same crash cycle with a longer recovery; consistency, not intensity spikes, builds stamina." onclick="checkQuiz('quiz-2', this)">Studying until exhausted, then a week of rest</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>What does the overactivity-collapse cycle look like?</p>
                    <button class="quiz-option" data-correct="true" data-explain="A burst of intense work followed by days of inability to study is the cycle: total hours look fine, but the crash days waste more than the burst earned." onclick="checkQuiz('quiz-3', this)">A very long push, then several days with no study at all</button>
                    <button class="quiz-option" data-correct="false" data-explain="A steady routine of moderate daily blocks is the opposite of the cycle and is the recommended pattern, not the failure mode." onclick="checkQuiz('quiz-3', this)">Two or three focused blocks every weekday</button>
                    <button class="quiz-option" data-correct="false" data-explain="A planned recovery day inside a steady week is healthy pacing; the cycle is defined by the crash that follows overreach, not by rest itself." onclick="checkQuiz('quiz-3', this)">Taking one recovery day each week</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>What should the final week before the test look like?</p>
                    <button class="quiz-option" data-correct="false" data-explain="New heavy material in the last week cannot be learned well and displaces the review and rest that actually protect your score." onclick="checkQuiz('quiz-4', this)">Starting new heavy topics to widen coverage</button>
                    <button class="quiz-option" data-correct="true" data-explain="A taper reduces volume while protecting sleep and finishes with one early mock, the error log and the formula sheet, so you arrive rested and sharp." onclick="checkQuiz('quiz-4', this)">Reducing volume, protecting sleep and sitting one early mock</button>
                    <button class="quiz-option" data-correct="false" data-explain="Doubling the hours in the last week adds fatigue rather than marks, and it spikes exactly when sleep and calm matter most." onclick="checkQuiz('quiz-4', this)">Doubling study hours to squeeze in more revision</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: name the four levers of energy and the shape of the final week.</p>
                <p>The answer: sleep, focus blocks, fuel and water, and movement; the final week is a taper that reduces volume, protects sleep and keeps only one early mock.</p>
                <div id="fill-1">
                    <p>Sleep is part of <input type="text" class="fill-blank" data-answer="preparation" placeholder="?" aria-label="what sleep counts as" />, not lost study time. Work in focused <input type="text" class="fill-blank" data-answer="blocks" placeholder="?" aria-label="unit of focused work" /> with short breaks rather than marathon sessions. The final week before the test is a <input type="text" class="fill-blank" data-answer="taper" placeholder="?" aria-label="final week pattern" />: reduce volume and protect sleep. When a topic feels hard, remember that <input type="text" class="fill-blank" data-answer="struggle" placeholder="?" aria-label="expected difficulty" /> is expected.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Look at last week as it actually happened, not as you wish it had. Estimate the time you slept and the number of genuine deep blocks you completed each day. Then rewrite the week so that sleep and recovery come first and study fits around them.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Start with the fixed points: a wake time you can hold every day, then the obligations you cannot move. Study gets scheduled into the gaps that remain, not squeezed into whatever is left after everything else, because energy left over at midnight is worth very little.</p>
                    <p>Place the highest-value work, the review queue and the hardest new topic, into your best block of the day. Protect one recovery day and one light day; these are not indulgences but the mechanism that stops the overactivity-collapse cycle before it starts.</p>
                    <p>Finally, plan the taper separately. In the last week, remove the long sessions, keep the review queue and the error log, sit one mock early, and shift your wake time towards the test's start hour. A week of steadier sleep and lower volume will do more for your score than any extra chapter read in the same seven days.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Energy is now budgeted, not spent by accident. The final lesson puts every thread together on the day itself: the routine, the pacing decisions and the calm execution that carries a rested mind through 120 minutes. See <a href="/courses/hat/lessons/hat-exam-day">Exam Day: Execution Under Pressure</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-score-targets">Previous: What Score Do You Need?</a></span>
                <span><a href="/courses/hat/lessons/hat-exam-day">Next: Exam Day</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
