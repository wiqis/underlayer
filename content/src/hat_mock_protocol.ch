// HAT course — Concept 24: How to run a mock test properly.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_mock_protocol() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("How to Run a Mock — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>How to Run a Mock Test</h1>
            <div class="lesson-meta">18 min · Module 5: The Athlete's Program · Simulation</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A mock taken badly is worse than no mock at all, because it teaches you the wrong habits and then gives you a false reading of your readiness. Taken well, it is the single most valuable hour in your preparation: it is the only activity that rehearses the whole paper — knowledge, timing, triage, stamina and nerve — at once.</p>
                <p>The difference between a useful mock and a wasted one is entirely in the conditions. Most candidates take mocks casually: phone nearby, ten-minute break at question 40, answers checked as they go. That is practice at <em>something</em>, but it is not practice at the HAT.</p>
            </div>

            <div class="unit unit-model">
                <h2>The Model: A Mock Is a Rehearsal, Not a Test</h2>
                <p>Treat the mock as a dress rehearsal for a performance, and it becomes obvious what the conditions must be:</p>
                <ul>
                    <li><strong>Same duration.</strong> 120 minutes, one sitting, no pause button.</li>
                    <li><strong>Same materials.</strong> The paper, a pencil, rough paper, a timer. No calculator, no phone, no dictionary.</li>
                    <li><strong>Same sequence.</strong> Sections in the order the real paper uses.</li>
                    <li><strong>Same scoring.</strong> One mark per correct answer, no negative marking, so leave nothing blank.</li>
                    <li><strong>Same time of day.</strong> If your test is at 10 a.m., practise at 10 a.m.; alertness has a schedule.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>Draw, even in the mock.</strong> The point of the mock is to rehearse your <em>procedure</em>, not just your knowledge. If your real plan is to draw diagrams and write difference tables, the mock is where that becomes automatic. Skipping the drawing in practice means it will not happen when it matters.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Detail: The Four-Phase Mock Cycle</h2>
                <p>A mock on its own changes nothing. A mock inside a four-phase cycle changes everything.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Phase</th><th scope="col">When</th><th scope="col">What you do</th><th scope="col">Time</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1. Sit</td><td>Fixed day and time</td><td>Full conditions, full paper, one sitting. Do not mark answers as you go</td><td>120 min</td></tr>
                        <tr><td>2. Mark</td><td>Same day, after a 15-minute break</td><td>Score honestly, section by section, and record the time you reached question 25, 50, 75 and 100</td><td>30 min</td></tr>
                        <tr><td>3. Diagnose</td><td>Same day or next morning</td><td>Every wrong answer goes into the error log with a cause; classify as knowledge, procedure, or attention</td><td>60 min</td></tr>
                        <tr><td>4. Repair</td><td>Next 2-3 days</td><td>Re-study only the diagnosed concepts, then re-attempt the missed questions cold</td><td>2-3 sessions</td></tr>
                    </tbody>
                </table>
                <p>The ratio matters: marking and diagnosing should take about as long as the mock itself. A candidate who sits four mocks and diagnoses none is doing 480 minutes of measuring and zero minutes of improving.</p>
                <h3>When to sit the first mock</h3>
                <ul>
                    <li><strong>Baseline mock, before studying.</strong> Sit one now, cold, even if you expect to score badly. It costs 120 minutes and it tells you exactly which sections to spend the next eight weeks on. Without it you are allocating study time by feeling.</li>
                    <li><strong>Progress mocks, every two weeks.</strong> Same paper format, changing content. Compare section scores, not just totals.</li>
                    <li><strong>Final mock, five to seven days out.</strong> This is the dress rehearsal. After it, taper: light review only, no new mock in the last 48 hours.</li>
                </ul>
                <div class="callout callout-warn">
                    <strong>Do not sit a mock in the last 24 hours.</strong> A bad final mock produces panic, and a good one produces false confidence; neither is useful on the eve of the paper. The last day is for reviewing your error log and a one-page summary of rules you keep forgetting.
                </div>
                <h3>Mock hygiene</h3>
                <ul>
                    <li><strong>One paper, one attempt.</strong> Never re-sit the same paper to "improve" your score; the number becomes meaningless because you remember the answers.</li>
                    <li><strong>Keep every mock paper.</strong> Corrections written in a different colour, next to the original attempt, are the best revision material you will ever own.</li>
                    <li><strong>Score by section.</strong> A total of 62 built from 30 quantitative, 20 verbal and 12 analytical is a very different situation from 62 built from 18, 22 and 22 — the first needs arithmetic work, the second needs analysis of puzzles.</li>
                    <li><strong>Log the time stamps.</strong> Section score tells you what you know; the clock tells you whether you can afford to show it.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p>A candidate's first cold baseline mock yields 51/100 overall: quantitative 25/40, verbal 19/30, analytical 7/30. Six analytical questions were left untouched.</p>
                <p>Total 51 is above the qualifying line but below a competitive one, and the section split is the real information. Quantitative is already at 62.5% and verbal at 63%, but analytical is at 23% — and six of its blanks show the failure was time, not knowledge. So the eight weeks cannot be an even three-way split. The plan should put roughly 60% of remaining analytical time into <em>procedure and pacing</em> (diagramming, set budgeting, the 40-second look) rather than into more studying, and simply maintain quantitative and verbal with a weekly timed set each.</p>
                <p>The actionable lesson from one mock: the biggest available gain was not a topic at all, it was the clock in one section.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>You take a mock and score well, then realise you checked a few answers as you went and took a short break at halfway. What is the value of that score?</p>
                    <button class="quiz-option" data-correct="false" data-explain="The score was produced under easier conditions, so it overstates your current level; trusting it would hide exactly the pacing problems the mock exists to expose." onclick="checkQuiz('quiz-1', this)">It is a valid estimate of your current level</button>
                    <button class="quiz-option" data-correct="true" data-explain="Conditions are the variable that makes a mock predictive; without them the number measures knowledge under no pressure, which the real paper never offers." onclick="checkQuiz('quiz-1', this)">It is not predictive — the conditions, not the score, are the point</button>
                    <button class="quiz-option" data-correct="false" data-explain="A partial mock is not useless — it is still a timed content workout — but you cannot read a readiness score from it, and treating it as one is the danger." onclick="checkQuiz('quiz-1', this)">It is worth exactly half a mock</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A candidate sits four mocks in a month and never marks them. Which statement best describes the outcome?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Sitting alone can build stamina and timing sense, but with no marking there is no diagnosis, and the same errors will recur in every paper." onclick="checkQuiz('quiz-2', this)">Stamina alone will fix most of the errors</button>
                    <button class="quiz-option" data-correct="true" data-explain="Eight hours of measurement produced zero minutes of correction; the same mistakes recur, so the score curve stays flat and morale drops." onclick="checkQuiz('quiz-2', this)">Eight hours spent measuring, nothing repaired</button>
                    <button class="quiz-option" data-correct="false" data-explain="Repeated mocks are only 'over-practice' if each one is diagnosed and repaired; undiagnosed repetition is wasted, not excessive." onclick="checkQuiz('quiz-2', this)">Four mocks is simply too many</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Your last mock before the real test is five days away and you score badly. What is the correct response?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Cramming new topics in the last days adds anxiety and rarely adds marks; the damage was diagnosed in this mock, and repair is targeted review." onclick="checkQuiz('quiz-3', this)">Start studying new topics immediately</button>
                    <button class="quiz-option" data-correct="true" data-explain="A low final mock is a gift: it names your remaining weak points while there is still time to fix them, so you spend the last days on diagnosed repairs rather than on general reading." onclick="checkQuiz('quiz-3', this)">Treat it as diagnosis and repair exactly what it exposed</button>
                    <button class="quiz-option" data-correct="false" data-explain="Sitting another full mock two days later consumes your best energy and gives no new information; you already know what went wrong." onclick="checkQuiz('quiz-3', this)">Sit another full mock two days later</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: how long does a mock take, and what must you record besides the score?</p>
                <p>The answer: 120 minutes under exam conditions; besides the score, record your section split, your time stamps at questions 25, 50, 75 and 100, and a cause for every wrong answer.</p>
                <div id="fill-1">
                    <p>A mock runs for <input type="text" class="fill-blank" data-answer="120" placeholder="?" aria-label="mock duration" /> minutes in one sitting, with no calculator. Its clock checkpoints are questions 25, 50, <input type="text" class="fill-blank" data-answer="75" placeholder="?" aria-label="third checkpoint" /> and 100. Marking and diagnosis together take about as long as the mock itself, and the final mock sits <input type="text" class="fill-blank" data-answer="5" placeholder="?" aria-label="days before the test" /> to 7 days before the test, never in the last 24 hours.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Schedule your mock cycle now: a cold baseline this week, then one every two weeks, then the final dress rehearsal five to seven days before the test. Write the dates into your calendar with the marking and diagnosing blocks attached, not just the 120 minutes.</p>
                <details>
                    <summary>Show the schedule that works</summary>
                    <p>Use fixed slots at the same time of day as your real test. Each cycle needs three blocks: the 120-minute sit, a 30-minute marking block the same day (after a real 15-minute break, so the paper has time to settle), and a 60-minute diagnosis block where every miss is written into the error log with its cause and its fix.</p>
                    <p>Then attach one 2-3 session repair window over the following two or three days using the diagnosis block, not by re-reading whole lessons. Re-attempt the missed questions cold, on paper, before looking at your earlier working — that is the evidence the repair worked.</p>
                    <p>Protect the baseline especially. It is tempting to delay it until you feel ready; that instinct usually means delaying it until a week before the test, when it is too late for the information to change your study plan. Sit it cold, accept the low number, and let it tell you where the marks actually are.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>A mock generates raw material: a list of wrong answers. The next lesson turns that list into the only document that should drive the rest of your preparation.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-analytical-drill">Previous: Analytical Drill</a></span>
                <span><a href="/courses/hat/lessons/hat-error-log">Next: The Error Log</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
