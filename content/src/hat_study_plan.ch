// HAT course — Concept 3: The eight-week program (athlete training plan).
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_study_plan() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Eight-Week Program — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>The Eight-Week Program: Training Like an Athlete</h1>
            <div class="lesson-meta">16 min · Module 1: Know the Arena · Planning</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Knowing every rule in this course is not the same as scoring well. The HAT is two hours of sustained attention under a clock, and like any performance event it responds to training structure: a measured baseline, progressive overload, simulation under real conditions, and a taper. Raw reading produces knowledge; structured practice produces a score.</p>
                <p>The difference shows up on the day. A candidate who has never sat a timed 100-question paper usually loses eight to twelve marks to pacing alone — questions reached too late, a passage read three times, a section abandoned in the last ten minutes.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Model preparation as a five-phase cycle, repeated weekly.</p>
                <div class="formula">diagnose &rarr; build (learn the rule) &rarr; drill (apply under time) &rarr; log (name the error) &rarr; retest (spaced repeat)</div>
                <ul>
                    <li><strong>Diagnose</strong> protects you from studying what you already know.</li>
                    <li><strong>Build</strong> is the short part: a rule, a template, a procedure. Twenty-five minutes.</li>
                    <li><strong>Drill</strong> is the long part: questions under a clock, because accuracy without speed scores nothing.</li>
                    <li><strong>Log</strong> is what most candidates skip, and it is where the marks are. Every wrong answer gets a named cause and a fix.</li>
                    <li><strong>Retest</strong> is the spaced repetition that moves an item into memory: redo the missed item after two days and again after a week.</li>
                </ul>
                <p>Two numbers make the model concrete: a realistic target is <strong>1,500 to 2,000 attempted questions</strong> and <strong>six to eight full-length timed mocks</strong> before the paper. Both are achievable in eight weeks at ten hours a week; neither is achievable by reading.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The eight-week calendar</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Week</th><th scope="col">Phase</th><th scope="col">Work</th><th scope="col">Deliverable</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>Diagnose</td><td>One full 100-question mock, cold, timed, with no pauses</td><td>Section scores and a written list of your top five error causes</td></tr>
                        <tr><td>1-2</td><td>Build</td><td>Quantitative foundations: arithmetic and estimation, number properties, fractions, percentages, ratio, averages</td><td>One timed 25-question quantitative drill per week at 80% or better</td></tr>
                        <tr><td>3-4</td><td>Build then overload</td><td>Algebra, geometry, counting and probability; verbal rules: vocabulary, analogies, sentence completion, agreement, prepositions</td><td>Sheet of every formula and rule you have used, written by hand</td></tr>
                        <tr><td>5</td><td>Overload</td><td>Analytical procedures: seating, ordering, syllogisms, series, data interpretation</td><td>First full mock after the diagnostic, with an error log per section</td></tr>
                        <tr><td>6</td><td>Simulate</td><td>Two mocks, interleaved mixed sets, error repair</td><td>Every logged error retested; second mock beat the first</td></tr>
                        <tr><td>7</td><td>Simulate and repair</td><td>Two mocks under exam conditions, plus targeted repair of the weakest topic</td><td>Stable score band; no topic below its floor</td></tr>
                        <tr><td>8</td><td>Taper</td><td>One mock early in the week, no new material after that, formulas and error log only</td><td>Sleep schedule aligned with the test start time</td></tr>
                    </tbody>
                </table>
                <h3>The daily template (90 minutes)</h3>
                <ul>
                    <li><strong>20 min — spaced review.</strong> Yesterday's logged errors, redone from scratch. This is non-negotiable and it is the highest-yield twenty minutes of the day.</li>
                    <li><strong>25 min — build.</strong> One rule, template or procedure, with three worked examples.</li>
                    <li><strong>35 min — drill.</strong> Timed: 20 to 25 questions, clock running, no pausing to look things up.</li>
                    <li><strong>10 min — log.</strong> Score it, name each error's cause, write the fix in one line.</li>
                </ul>
                <h3>Error causes you should be logging</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Cause</th><th scope="col">Looks like</th><th scope="col">Fix</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Concept gap</td><td>You did not know the rule at all</td><td>Study the rule today, retest in two days</td></tr>
                        <tr><td>Misread</td><td>You answered a different question than the one asked</td><td>Underline what is being asked before computing</td></tr>
                        <tr><td>Slip</td><td>You knew it and made an arithmetic or sign error</td><td>Units-digit and magnitude check before choosing</td></tr>
                        <tr><td>Time</td><td>You never reached it, or rushed the last line</td><td>Rehearse the budget and the 40-second look</td></tr>
                        <tr><td>Trap</td><td>You chose the wrong-base or off-by-one distractor</td><td>Name the trap in the log; they repeat</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-tip">
                    <strong>Compressed plans.</strong> With three weeks: skip the fundamentals you can already do, spend week 1 on rules and procedures, week 2 on timed drills, week 3 on three mocks and error repair. With two weeks: mock on day 1 and day 7, drill only the questions you got wrong in the diagnostic's weakest section, and never start a topic you have not already seen.
                </div>
                <div class="callout callout-warn">
                    <strong>Recovery is part of the training.</strong> The paper demands two hours of unbroken attention. Sleeping six hours a night for eight weeks produces a slower, more careless candidate, and no amount of drilling fixes that. Sleep seven to eight hours, and in the last week shift your waking time towards the test's start time.
                </div>
                <div class="callout callout-tip">
                    <strong>Use the platform, not just the pages.</strong> Every concept in this course seeds review items on the server. The dashboard's review queue is spaced repetition with a forgetting-curve scheduler: do the daily queue before new material, and the same items come back exactly when you are about to lose them.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Week, and a Real Log Entry</h2>
                <p>Week 4 of a HAT-1 plan, ten hours, split into six sessions:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Day</th><th scope="col">Session</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Monday</td><td>Spaced review (20) + percentages templates (25) + timed 25-question quantitative drill (35) + log (10)</td></tr>
                        <tr><td>Tuesday</td><td>Spaced review (20) + algebra: translating words to equations (25) + timed 20-question algebra set (35) + log (10)</td></tr>
                        <tr><td>Wednesday</td><td>Spaced review (20) + vocabulary roots and a 40-word bank (25) + timed 25-question verbal drill (35) + log (10)</td></tr>
                        <tr><td>Thursday</td><td>Spaced review (20) + geometry: circles and similarity (25) + timed 20-question mixed quantitative set (35) + log (10)</td></tr>
                        <tr><td>Friday</td><td>Spaced review (20) + grammar agreement rules (25) + timed 25-question verbal drill (35) + log (10)</td></tr>
                        <tr><td>Saturday</td><td>Full-length mock, 120 minutes, no pauses, then 40 minutes of scoring and logging</td></tr>
                    </tbody>
                </table>
                <p>An error-log entry from that Saturday, written the way it should be:</p>
                <pre>Q 27 (percentages, wrong base)
Wrote: change 20 on new value 100 = 20%  |  Correct: change 20 on original 80 = 25%
Cause: trap — divided by the new value
Fix: always write "change / original" before dividing
Retest: Tue  +  following Sat</pre>
                <p>One line of cause, one line of fix, one scheduled retest. Thirty such entries across eight weeks is a quantified map of your remaining weaknesses — and it is the only honest way to know what to study in the last week.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What is the best use of the final week before the test?</p>
                    <button class="quiz-option" data-correct="false" data-explain="New material in the last week cannot be drilled enough to pay off, and it displaces the repair work that does." onclick="checkQuiz('quiz-1', this)">Learning topics you have never seen</button>
                    <button class="quiz-option" data-correct="true" data-explain="The last week is for timing, stamina and fixing known errors: full-length mocks plus repair of the error log, then a taper." onclick="checkQuiz('quiz-1', this)">Full-length mocks, error repair and a taper</button>
                    <button class="quiz-option" data-correct="false" data-explain="Resting entirely risks arriving without the pacing and stamina that only simulation builds." onclick="checkQuiz('quiz-1', this)">Resting completely with no practice</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Why is the spaced review block the first twenty minutes of every session?</p>
                    <button class="quiz-option" data-correct="false" data-explain="It is not about warming up; it is retrieval practice, which is what actually moves items into durable memory." onclick="checkQuiz('quiz-2', this)">Because it warms up your arithmetic</button>
                    <button class="quiz-option" data-correct="true" data-explain="Redoing yesterday's errors from scratch is retrieval practice at the exact spacing where forgetting begins, so it is the highest-yield block in the day." onclick="checkQuiz('quiz-2', this)">Because redoing yesterday's errors from scratch is retrieval at the right spacing</button>
                    <button class="quiz-option" data-correct="false" data-explain="Order does not matter because the block is more efficient than new study; it is first because it is the most valuable, not because the rest depends on it." onclick="checkQuiz('quiz-2', this)">Because new material cannot be learned before it</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>You have exactly two weeks. Which plan is correct?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Two weeks is not enough to cover unseen topics to a scoring level; that choice guarantees weak coverage everywhere." onclick="checkQuiz('quiz-3', this)">Cover every topic in the syllabus lightly</button>
                    <button class="quiz-option" data-correct="true" data-explain="Diagnose on day one, drill only the weakest section's rule-based topics, then run mocks and repair. Depth in few topics beats shallow coverage." onclick="checkQuiz('quiz-3', this)">Diagnose, drill the weakest rule-based topics, then mock and repair</button>
                    <button class="quiz-option" data-correct="false" data-explain="Working only on your strongest section maximises comfort and minimises marks, since late hours there buy the fewest marks." onclick="checkQuiz('quiz-3', this)">Spend both weeks on the section you are best at</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: name the five phases of the weekly cycle and the two volume targets that make the plan concrete.</p>
                <p>The answer: diagnose, build, drill, log, retest; about 1,500 to 2,000 attempted questions and six to eight full-length timed mocks.</p>
                <div id="fill-1">
                    <p>The five phases of the weekly cycle are diagnose, <input type="text" class="fill-blank" data-answer="build" placeholder="?" aria-label="second phase" />, drill, <input type="text" class="fill-blank" data-answer="log" placeholder="?" aria-label="fourth phase" /> and retest. A realistic question target is <input type="text" class="fill-blank" data-answer="1500" placeholder="?" aria-label="minimum questions" /> to 2,000 attempted questions, and the last week is a <input type="text" class="fill-blank" data-answer="taper" placeholder="?" aria-label="final week phase" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your diagnostic was Quantitative 28/40, Verbal 11/30, Analytical 10/30. You work full time and have 8 hours a week for six weeks, plus four free days in the last week. Build the schedule.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Forty-eight usable hours plus four full days. The diagnostic says Quantitative needs protection, not development: allocate four of the 48 hours to a consolidation block covering percentage and algebra templates, and make the remaining 44 earn.</p>
                    <p>Verbal (19 marks missing) and Analytical (20 marks missing) are where the return is. Split those 44 hours evenly, 22 to Analytical and 22 to Verbal, in the order that lets you practise under time earliest: procedures first (seating, ordering, syllogisms, series, data interpretation), because a wrong procedure is worse than no procedure; then verbal rules (vocabulary roots, analogies, sentence completion, agreement, prepositions) in short daily doses of 30 minutes.</p>
                    <p>Use the four free days as simulation days: mock on day 1 (cold timing check), mock and repair on days 2 and 3 spaced apart, and on the final free day revision of the formula sheet and the error log only. Two mocks are the minimum simulation dose for a six-week plan; if only one is possible, make it a week before the test, never the day before.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now have a calendar and a feedback loop. The next lesson touches the thing the calendar cannot give you: the internal clock. It sets the per-section time budgets and the checkpoints that keep a plan from becoming a wish.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-diagnostic-test">Previous: Your Baseline Diagnostic</a></span>
                <span><a href="/courses/hat/lessons/hat-time-budget">Next: Your 120 Minutes</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
