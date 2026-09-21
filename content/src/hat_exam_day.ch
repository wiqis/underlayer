// HAT course — Exam day: execution under pressure.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_exam_day() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Exam Day - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Exam Day: Execution Under Pressure</h1>
            <div class="lesson-meta">14 min &middot; Module 5: The Athlete's Program &middot; Execution</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Eight weeks of preparation can be spent or wasted in the first twenty minutes of the test. Exam day is not a different skill from the ones you have trained; it is those skills performed under a fixed clock, in an unfamiliar room, with your attention split between the paper and your own nerves. That is a performance, and performances are rehearsed.</p>
                <p>The goal of this lesson is to remove every decision that does not need to be made on the day, so the only thing left to do is answer questions.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Control what is controllable; pre-decide the rest.</p>
                <ul>
                    <li><strong>Before: logistics.</strong> Where, when, what to carry, what to eat. All decided the night before.</li>
                    <li><strong>During: the clock.</strong> Checkpoints written down before question one, so pacing is measured rather than felt.</li>
                    <li><strong>Under stress: a fixed protocol.</strong> One breathing pattern, one rule for stuck questions, one rule for guessing.</li>
                </ul>
                <p>The model's missing piece: nerves do not disappear with experience; they are managed by habits that run without conscious effort. The habits are the point.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The facts to hold in mind</h3>
                <ul>
                    <li><strong>100 questions, 120 minutes.</strong> That is seventy-two seconds per question on average, and the hard ones will not respect the average.</li>
                    <li><strong>The three sections are weighted 30 / 30 / 40</strong> — Verbal, Analytical, Quantitative for HAT-1 — and the quantitative section carries the most questions.</li>
                    <li><strong>There is no negative marking.</strong> A blank is a guaranteed zero; a guess is a chance at a mark. Never leave a question unanswered.</li>
                    <li><strong>The qualifying score is commonly 50 out of 100</strong> (many competitive programmes require more), and a valid score is typically usable for two years.</li>
                    <li><strong>No calculator.</strong> The paper is answered on an MCQ answer sheet; confirm the permitted stationery and the exact reporting time on your admit card.</li>
                </ul>
                <h3>The morning checklist</h3>
                <ul>
                    <li>Admit slip and a valid identity document, in the bag the night before.</li>
                    <li>Two or more working pens or pencils, and a watch if one is permitted.</li>
                    <li>A light, familiar meal. Nothing new and nothing heavy.</li>
                    <li>Arrive early, with margin for transport. Rushed arrival is the single biggest avoidable stressor.</li>
                    <li>No last-minute cramming. Review only your one-page error-log summary; new material raises anxiety and rarely appears.</li>
                </ul>
                <h3>The first five minutes</h3>
                <ol>
                    <li>Read the instructions and confirm the section order and the number of questions.</li>
                    <li>Write your checkpoints where you can see them: roughly question 25 by minute 30, question 50 by minute 60, question 75 by minute 90, finished by minute 120.</li>
                    <li>Take four slow breaths, in for four and out for four, before starting. This is not decoration; it lowers the error rate in the first ten minutes.</li>
                </ol>
                <h3>The stuck-question rule</h3>
                <div class="callout callout-tip">
                    <strong>Ninety seconds, then move.</strong> If a question has not resolved after about ninety seconds, mark it, eliminate one or two options if you can, choose the best remaining, and leave it. The marks you lose by leaving three questions unread are larger than the mark you might gain by solving one slowly.
                </div>
                <div class="callout callout-warn">
                    <strong>Three repeated mistakes.</strong> (1) Changing a correct first answer on a hunch with no new reason. (2) Spending the last ten minutes on one hard question instead of checking that every question has an answer. (3) Letting one unfamiliar question convince you the whole paper is beyond you — it is a standard paper with a few deliberately hard items.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Scenario</h2>
                <p>At minute 30 you are starting question 20, and the next item is a data-interpretation question that needs four percentage calculations. Your checkpoint says question 25 by minute 30. You are about five questions behind.</p>
                <p>Do not speed up across the whole section, which raises errors everywhere. Instead, apply the rule locally: mark this question, make one elimination and guess, and use the regained ninety seconds to return to pace. Re-check the clock at the next question, not continuously; glancing at the clock every question costs both time and attention.</p>
                <p>The reasoning is arithmetic, not willpower: a few questions behind is recoverable by guessing the items you would have solved slowly anyway, but it is not recoverable by trying to read faster.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>You have ninety seconds left and eight unanswered questions. What should you do?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Leaving questions blank guarantees zero on each; with no negative marking, a fast elimination and guess can only help." onclick="checkQuiz('quiz-1', this)">Leave them blank rather than guess</button>
                    <button class="quiz-option" data-correct="true" data-explain="With no negative marking, answer every remaining question quickly, eliminating where you can, so each carries a chance of a mark." onclick="checkQuiz('quiz-1', this)">Answer all eight quickly, eliminating where possible</button>
                    <button class="quiz-option" data-correct="false" data-explain="Trying to fully solve one leaves seven blank; the expected marks are far lower than answering all eight." onclick="checkQuiz('quiz-1', this)">Solve the one you understand fully and leave the rest</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>What is the best use of the final night before the test?</p>
                    <button class="quiz-option" data-correct="false" data-explain="New material this late raises anxiety and rarely appears; it also competes with sleep, which matters more." onclick="checkQuiz('quiz-2', this)">Learn a new topic you avoided all along</button>
                    <button class="quiz-option" data-correct="true" data-explain="Light review of your error-log summary, preparation of materials, and a full night of sleep protect the performance you have trained." onclick="checkQuiz('quiz-2', this)">Review your error-log summary, prepare materials, sleep</button>
                    <button class="quiz-option" data-correct="false" data-explain="A full-length mock the night before sacrifices sleep for little gain and can dent confidence." onclick="checkQuiz('quiz-2', this)">Take an extra full-length mock at midnight</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Why is the "ninety seconds then move" rule effective?</p>
                    <button class="quiz-option" data-correct="false" data-explain="It is not about difficulty; it is about protecting the time budget for the rest of the paper." onclick="checkQuiz('quiz-3', this)">It guarantees you solve the hard question later</button>
                    <button class="quiz-option" data-correct="true" data-explain="It prevents one question from consuming time that belongs to several others, which is how total score is protected." onclick="checkQuiz('quiz-3', this)">It stops one question from starving the rest of the paper of time</button>
                    <button class="quiz-option" data-correct="false" data-explain="Skipping does not reduce difficulty; it manages the allocation of a fixed resource, time." onclick="checkQuiz('quiz-3', this)">It makes the remaining questions easier</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: state the checkpoint schedule and the rule for a stuck question.</p>
                <p>Roughly question 25 by minute 30, 50 by minute 60, 75 by minute 90, and finished by minute 120. A stuck question gets about ninety seconds, then a mark, an elimination and a guess, and you move on.</p>
                <div id="fill-1">
                    <p>There is no <input type="text" class="fill-blank" data-answer="negative marking" placeholder="?" aria-label="what the HAT does not apply" />, so every question should be <input type="text" class="fill-blank" data-answer="answered" placeholder="?" aria-label="what to do with every question" />. The paper has <input type="text" class="fill-blank" data-answer="100" placeholder="?" aria-label="number of questions" /> questions in <input type="text" class="fill-blank" data-answer="120" placeholder="?" aria-label="minutes allowed" /> minutes.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Write your personal exam-day plan in five lines: reporting time, materials, checkpoints, stuck-question rule, and the one habit you will not break.</p>
                <details>
                    <summary>Show a model plan</summary>
                    <p>Reporting time: arrive forty-five minutes early. Materials: admit slip, identity document, two pens, watch if allowed, water if permitted. Checkpoints: 25 by 30, 50 by 60, 75 by 90, done by 120. Stuck rule: ninety seconds, mark, eliminate, guess, move. Non-negotiable habit: every question carries an answer before time is called.</p>
                    <p>The point of writing it down is that these become decisions already made, so on the day you spend attention on questions rather than on managing yourself.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the end of the core exam-preparation course. You have the material, the technique, the pacing and the execution plan. The remaining work is reps: timed mocks, the error log, and the review schedule Underlayer keeps for you. Walk in having rehearsed, and the test becomes the performance you trained for.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-energy-management">Previous: Energy, Sleep and Stamina</a></span>
                <span><a href="/courses/hat/lessons/hat-physics-mechanics">Next: Physics and Mechanics</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
