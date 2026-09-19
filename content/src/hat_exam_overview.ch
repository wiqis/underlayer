// HAT course — Concept 1: What the HAT actually is.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_exam_overview() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("HAT Exam Overview — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>What the HAT Actually Is</h1>
            <div class="lesson-meta">12 min · Module 1: Understanding the Test · Orientation</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The Higher Education Aptitude Test (HAT) is a fixed-format test. It is not a syllabus you can read cover to cover — it is a pattern of reasoning questions with a known shape, known weights, and a known clock. Candidates who lose marks usually lose them to format, not to knowledge: they spend nine minutes on a six-line logic puzzle, or they leave blanks because they believe there is negative marking.</p>
                <p>Before you study a single algebra rule, you need a precise picture of what the paper asks, what it pays for, and what it does not.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Model the HAT as <strong>three sections, one clock, no penalties</strong>.</p>
                <ul>
                    <li>Three reasoning sections: Verbal Reasoning, Analytical Reasoning, Quantitative Reasoning.</li>
                    <li>100 multiple-choice questions worth 1 mark each. No negative marking.</li>
                    <li>120 minutes for the whole paper — an average of 72 seconds per question.</li>
                </ul>
                <p>The model is powerful because it immediately implies two strategies: never leave a blank, and never let one hard question eat ten of your 100 questions' worth of time. The model is incomplete in one way: your <em>subject category</em> moves the weights between sections, which is the entire subject of the next lesson.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>HAT is conducted by the <strong>Education Testing Council (ETC)</strong> of the Higher Education Commission (HEC), Pakistan. It is used for admission to MS, MPhil and PhD programs, for HEC scholarships, and it replaced the older NTS-style route for graduate admissions at HEC-recognised universities.</p>
                <p>The published facts of the paper:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Property</th><th scope="col">Value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Questions</td><td>100 MCQs, 1 mark each, 100 marks total</td></tr>
                        <tr><td>Time allowed</td><td>120 minutes</td></tr>
                        <tr><td>Mode</td><td>Paper-based, in English</td></tr>
                        <tr><td>Negative marking</td><td>None</td></tr>
                        <tr><td>Score validity</td><td>2 years from the date the result is declared</td></tr>
                        <tr><td>Qualifying score</td><td>50 out of 100 for MS/MPhil admission</td></tr>
                        <tr><td>Schedule</td><td>Conducted quarterly at centres in major cities</td></tr>
                    </tbody>
                </table>
                <p>The named sections and their weights depend on the category you register for:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Category</th><th scope="col">Verbal</th><th scope="col">Analytical</th><th scope="col">Quantitative</th><th scope="col">Intended for</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>HAT-1</td><td>30</td><td>30</td><td>40</td><td>Engineering and Technology, Computer Science, Mathematics, Statistics, Physics</td></tr>
                        <tr><td>HAT-2</td><td>30</td><td>40</td><td>30</td><td>Management Sciences, Business Education</td></tr>
                        <tr><td>HAT-3</td><td>40</td><td>35</td><td>25</td><td>Arts and Humanities, Social Sciences, Psychology, Law</td></tr>
                        <tr><td>HAT-4</td><td>40</td><td>30</td><td>30</td><td>Agriculture, Biological and Medical Sciences, Physical Sciences, Education, Media</td></tr>
                        <tr><td>HAT-General</td><td>40</td><td>30</td><td>30</td><td>Religious Studies (madrasa graduates)</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-warn">
                    <strong>Verify before you rely on it.</strong> Test patterns, fees and qualifying thresholds change, and some universities demand more than the minimum (60 or above is common for PhD admission). Treat the numbers above as the published pattern and confirm the current circular at <code>etc.hec.gov.pk</code> and your target university's admission notice before you plan around them.
                </div>
                <div class="callout callout-tip">
                    <strong>One detail candidates miss:</strong> the category is chosen at registration and, per the published procedure, cannot be changed afterwards. Choosing the wrong category changes which sections carry the most marks. If you are a Computer Science graduate, the described category is HAT-1: Quantitative carries 40 marks, the single largest block on the paper.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Take a HAT-1 candidate. Out of 100 marks the paper pays 40 for Quantitative, 30 for Verbal and 30 for Analytical. Suppose the raw performance is:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">Marks available</th><th scope="col">Marks earned</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Quantitative</td><td>40</td><td>30</td></tr>
                        <tr><td>Verbal</td><td>30</td><td>15</td></tr>
                        <tr><td>Analytical</td><td>30</td><td>10</td></tr>
                    </tbody>
                </table>
                <p>Total: 30 + 15 + 10 = <strong>55 out of 100</strong>. That clears the 50-mark threshold comfortably even though the Verbal and Analytical sections scored only half. Notice what this arithmetic says: on HAT-1, being strong in Quantitative earns marks faster than being strong anywhere else, but it is the two weaker sections that decide whether an otherwise strong candidate crosses the line.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Answer without scrolling back. Every option explains itself.</p>
                <div class="quiz" id="quiz-1">
                    <p>On a 100-question paper with 120 minutes allowed, roughly how long do you have per question?</p>
                    <button class="quiz-option" data-correct="true" data-explain="120 minutes divided by 100 questions is 1.2 minutes, which is 72 seconds." onclick="checkQuiz('quiz-1', this)">About 72 seconds per question</button>
                    <button class="quiz-option" data-correct="false" data-explain="Two minutes per question would take 200 minutes, well past the 120-minute limit." onclick="checkQuiz('quiz-1', this)">About 2 minutes per question</button>
                    <button class="quiz-option" data-correct="false" data-explain="30 seconds per question would finish the paper in 50 minutes and leave half the clock unused." onclick="checkQuiz('quiz-1', this)">About 30 seconds per question</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A Computer Science graduate registering for HAT-1 should expect which section to carry the most marks?</p>
                    <button class="quiz-option" data-correct="false" data-explain="On HAT-1 the Quantitative section carries 40 marks; Verbal and Analytical carry 30 each." onclick="checkQuiz('quiz-2', this)">Verbal Reasoning, with 40 marks</button>
                    <button class="quiz-option" data-correct="true" data-explain="HAT-1 is the engineering, computer science, mathematics, statistics and physics category, and Quantitative Reasoning carries 40 of the 100 marks." onclick="checkQuiz('quiz-2', this)">Quantitative Reasoning, with 40 marks</button>
                    <button class="quiz-option" data-correct="false" data-explain="Analytical Reasoning carries 30 marks on HAT-1; the largest single block is Quantitative." onclick="checkQuiz('quiz-2', this)">Analytical Reasoning, with 40 marks</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>You have 40 seconds left and cannot decide between two options. What is the best action?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Because wrong answers are not penalised, a guess costs nothing and can earn a mark; a blank can only ever be worth zero." onclick="checkQuiz('quiz-3', this)">Leave it blank to protect your score</button>
                    <button class="quiz-option" data-correct="true" data-explain="With no negative marking, eliminating even two options makes a guess positive in expectation, and a blank is guaranteed zero." onclick="checkQuiz('quiz-3', this)">Mark your best guess and move on</button>
                    <button class="quiz-option" data-correct="false" data-explain="Only one option can be correct, so marking several gains nothing and risks an ambiguous answer sheet." onclick="checkQuiz('quiz-3', this)">Shade every option for that question</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: name the three sections of the HAT and the two numbers that define the paper's shape (questions and minutes).</p>
                <p>The answer is: Verbal Reasoning, Analytical Reasoning and Quantitative Reasoning; 100 questions in 120 minutes with no negative marking.</p>
                <p>Now fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>The HAT has <input type="text" class="fill-blank" data-answer="100" placeholder="?" aria-label="number of questions" /> multiple-choice questions, to be answered in <input type="text" class="fill-blank" data-answer="120" placeholder="?" aria-label="minutes allowed" /> minutes, and the commonly cited qualifying score for MS/MPhil admission is <input type="text" class="fill-blank" data-answer="50" placeholder="?" aria-label="qualifying marks" /> out of 100.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are an Electrical Engineering graduate who has not opened an English grammar book since first year, and who solves calculus quickly. You have six weeks and one attempt you care about.</p>
                <p>Which section deserves the largest share of your study hours, and why?</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Register for HAT-1: Quantitative carries 40 marks, so effort there converts to marks fastest and your existing strength means those marks are the cheapest to secure. But because 60 marks sit outside Quantitative, the correct plan is not "study only maths" — it is to secure Quantitative first (fast, high-yield, low-risk), then buy the cheapest available Verbal and Analytical marks: vocabulary and grammar rules are learnable in six weeks in a way that reading speed is not, and analytical puzzles respond well to a small set of written procedures.</p>
                    <p>The mistake to avoid is treating the 40-mark section as the only section. A 40/40 Quantitative with 8/30 Verbal and 5/30 Analytical is 53 marks — barely over the line, and one bad question away from it.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now know the shape of the paper: three sections, 100 marks, 120 minutes, no penalties. The next lesson turns that shape into a plan — how the category weights should divide your study time, and how to sequence a six-week preparation so that the sections you cannot master quickly still pay for themselves.</p>
                <p>After that, the course moves into the sections themselves: Quantitative Reasoning, then Verbal Reasoning, then Analytical Reasoning, with a short module on mock tests and exam day.</p>
            </div>

            <div class="lesson-footer">
                <span>Module 1 · Lesson 1 of 21</span>
                <span><a href="/courses/hat/lessons/hat-weightage-strategy">Next: Weightage and Study Strategy</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
