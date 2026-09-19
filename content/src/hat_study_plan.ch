// HAT course — Concept 3: A six-week study plan.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_study_plan() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Six-Week Study Plan — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>A Six-Week Study Plan</h1>
            <div class="lesson-meta">13 min · Module 1: Understanding the Test · Planning</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Preparation fails in one of two ways. Either you study without measuring, so you cannot tell whether three weeks of effort moved your score; or you measure without studying, so you collect mock scores and change nothing. A plan that survives contact with a real schedule has to do both: produce evidence, then act on it.</p>
                <p>Six weeks is a realistic window for a working candidate with roughly 8 to 12 hours a week. The plan below is deliberately built around the two facts that make the HAT forgiving: there is no negative marking, and around half the paper is rule-based rather than knowledge-based.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of the six weeks as three phases with different jobs.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Phase</th><th scope="col">Weeks</th><th scope="col">Job</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Measure and build rules</td><td>1</td><td>Diagnostic mock, then learn the rule-based material: grammar, vocabulary, direction, coding</td></tr>
                        <tr><td>Drill the techniques</td><td>2 to 4</td><td>One section forward each week, daily short review, written error log</td></tr>
                        <tr><td>Simulate and repair</td><td>5 to 6</td><td>Timed mixed practice and full mocks, then repair the top three error patterns only</td></tr>
                    </tbody>
                </table>
                <p>Every session, regardless of phase, has the same three-block shape: a short review of previously missed questions, a longer block of new practice, and a written error log. The review block is not optional and not negotiable — it is the only part of the plan that converts past mistakes into future marks.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Week 1: measure before you study.</strong> Sit one full paper under real conditions — 100 questions, 120 minutes, no pauses, no notes. Score it by section, not just in total. A score of 44 tells you almost nothing; Quantitative 24/40, Verbal 12/30, Analytical 8/30 tells you exactly where the next 20 hours belong.</p>
                <p><strong>Weeks 2 to 4: one section forward, everything reviewed daily.</strong> The daily shape that works for most candidates:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Block</th><th scope="col">Length</th><th scope="col">What happens</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Review</td><td>10 to 15 min</td><td>Re-attempt the questions you missed yesterday, from memory, before looking at the solution</td></tr>
                        <tr><td>New practice</td><td>45 to 60 min</td><td>One section, mixed difficulty, written work shown</td></tr>
                        <tr><td>Error log</td><td>5 to 10 min</td><td>Write each miss with one line of cause and one line of rule</td></tr>
                    </tbody>
                </table>
                <p><strong>The error log is the instrument.</strong> Every miss gets exactly one cause from a closed list, because the cause decides the fix:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Cause</th><th scope="col">Fix</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Concept gap</td><td>Re-learn the rule, then re-attempt the question tomorrow</td></tr>
                        <tr><td>Careless slip</td><td>Change the habit: underline the question's last two words before answering</td></tr>
                        <tr><td>Ran out of time</td><td>Practise the section with a per-question cap</td></tr>
                        <tr><td>Guessed</td><td>Log it, but do not study it — guesses carry no information</td></tr>
                    </tbody>
                </table>
                <p><strong>Weeks 5 and 6: simulate, then repair only the top three.</strong> Take a full timed mock every three days. Between mocks, work only on the three most frequent entries in your error log. Repairing ten problems at once repairs none of them; repairing three until they stop appearing is visible progress.</p>
                <div class="callout callout-warn">
                    <strong>Two traps.</strong> First, do not spend the last week learning new material — the returns arrive too late and the anxiety is real. Second, do not practise untimed. Untimed practice measures knowledge; timed practice measures the thing you are actually being tested on, which is knowledge under a clock.
                </div>
                <div class="callout callout-tip">
                    <strong>Use spaced review for the rules.</strong> The rule-based material in this course — grammar corrections, vocabulary roots, direction and coding conventions — is exactly the material that decays without retrieval. Underlayer's review queue schedules those items for you; if you are using the static (no-backend) build, keep your own list of 20 rules and re-test yourself on them twice a week.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>A candidate's six weeks, condensed to the numbers that mattered:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Checkpoint</th><th scope="col">Quantitative</th><th scope="col">Verbal</th><th scope="col">Analytical</th><th scope="col">Total</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Week 1 diagnostic</td><td>24/40</td><td>12/30</td><td>8/30</td><td>44</td></tr>
                        <tr><td>Week 3 mid-mock</td><td>27/40</td><td>17/30</td><td>12/30</td><td>56</td></tr>
                        <tr><td>Week 6 final mock</td><td>30/40</td><td>21/30</td><td>16/30</td><td>67</td></tr>
                    </tbody>
                </table>
                <p>Verify: 24 + 12 + 8 = 44, 27 + 17 + 12 = 56, and 30 + 21 + 16 = 67. The gains are +6 in Quantitative, +9 in Verbal and +8 in Analytical. Note which section moved most: the weakest one, Verbal, moved 9 marks while the already-strong section added 6. That is the marginal-return model of the previous lesson showing up in real numbers — and note that no section was abandoned.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What is the first thing to do with a diagnostic mock?</p>
                    <button class="quiz-option" data-correct="true" data-explain="A total score hides the section detail that decides where your next hour goes. Section-wise scoring is what makes a plan possible." onclick="checkQuiz('quiz-1', this)">Score it section by section, so the gaps are visible</button>
                    <button class="quiz-option" data-correct="false" data-explain="A single total is the least actionable number on the page; 44 could mean four different plans." onclick="checkQuiz('quiz-1', this)">Score it as a single total and move straight to study</button>
                    <button class="quiz-option" data-correct="false" data-explain="Taking it without a clock changes what is measured: you would be testing knowledge, not knowledge under time pressure." onclick="checkQuiz('quiz-1', this)">Retake it untimed until the score is comfortable</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>In the final week, what should the error log be used for?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Guesses carry no information about a rule you are missing, so studying them wastes the repair window." onclick="checkQuiz('quiz-2', this)">Study every entry in the error log equally before the next mock</button>
                    <button class="quiz-option" data-correct="true" data-explain="Repairing the most frequent causes until they disappear is measurable progress; spreading effort over ten causes fixes none." onclick="checkQuiz('quiz-2', this)">Work only on the three most frequent causes</button>
                    <button class="quiz-option" data-correct="false" data-explain="Stopping practice to re-read theory replaces time-under-clock with time-under-book, which is the opposite of what weeks five and six are for." onclick="checkQuiz('quiz-2', this)">Stop practising and re-read all the theory</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what are the three blocks of a daily session, and what is the first thing you do in week one?</p>
                <p>The answer is: review yesterday's misses, new practice in one section, and a written error log. Week one begins with a full timed diagnostic, scored by section.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>A diagnostic must be taken with a <input type="text" class="fill-blank" data-answer="clock" placeholder="?" aria-label="what the diagnostic needs" />, and it must be scored by <input type="text" class="fill-blank" data-answer="section" placeholder="?" aria-label="how to score it" />. Misses caused purely by <input type="text" class="fill-blank" data-answer="guessing" placeholder="?" aria-label="a cause that needs no study" /> should be logged but not studied.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You have only four weeks, not six, and you work full time. Week 1 is your diagnostic week; the mock shows Quantitative 20/40, Verbal 16/30, Analytical 11/30 — a total of 47. Which phases do you compress, and which do you refuse to cut?</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Compress the drill phase and the simulation phase; never cut the diagnostic week or the error log. The diagnostic is about 2 hours out of a four-week budget and it determines where every other hour goes, so it is the cheapest two hours in the plan. The error log costs about 7 minutes a session and is the only mechanism that stops the same mistake twice.</p>
                    <p>Here the numbers point somewhere specific: 47 with a 20/40 Quantitative is below the threshold, but the gap is concentrated in the heaviest section of HAT-1. A four-week plan that gives Quantitative two thirds of the practice hours, keeps a daily 10-minute rule review for Verbal and Analytical, and takes two full timed mocks in the final week is realistic. What is not realistic is spreading 40 hours evenly and finishing with three sections that are all still at half marks.</p>
                    <p>Also note the floor: Analytical at 11/30 is close to the level where a single bad passage decides the section. Thirty minutes twice a week on arrangement and deduction procedures raises that floor far more cheaply than the same hour spent pushing Quantitative from 20 to 21.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You have the shape of the test and a plan that measures before it works. From here the course stops being about the exam and becomes about the three sections themselves.</p>
                <p>Next is Quantitative Reasoning, which carries the most marks on HAT-1. It starts where all quantitative questions start: with arithmetic you can do quickly and accurately, without a calculator.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-weightage-strategy">Previous: Weightage and Study Strategy</a></span>
                <span><a href="/courses/hat/lessons/hat-arithmetic">Next: Arithmetic You Can Do in Your Head</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
