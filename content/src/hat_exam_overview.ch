// HAT course — Concept 1: What the HAT actually is (verified exam intelligence).
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
            <h1>Know the Arena: What HAT-1 Actually Is</h1>
            <div class="lesson-meta">14 min · Module 1: Know the Arena · Orientation</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You are training for a known course, not a mystery. The paper has a fixed shape: a fixed number of questions, a fixed clock, three fixed sections and a fixed scoring rule. Every one of those facts changes how you should answer questions, and candidates who ignore them lose marks that have nothing to do with intelligence.</p>
                <p>Here is the expensive part. Marks are lost to <em>format</em>, not to knowledge: nine minutes burned on one analytical puzzle; fifty questions left blank because of a negative-marking rumour that has never applied to this test; a technical graduate registering in the wrong category and studying the wrong weights. This lesson removes all of that risk first, before you learn a single technique.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Model the HAT as <strong>one paper, three sections, one clock, zero penalties</strong>.</p>
                <ul>
                    <li><strong>Three sections:</strong> Verbal Reasoning, Analytical Reasoning, Quantitative Reasoning.</li>
                    <li><strong>100 multiple-choice questions</strong>, one mark each, 100 marks.</li>
                    <li><strong>120 minutes</strong> for the whole paper, with no per-section time limit — you own the clock.</li>
                    <li><strong>No negative marking.</strong> A wrong answer costs exactly as much as a blank: nothing.</li>
                </ul>
                <p>Notice how much that already implies. Because there are no penalties, your score is simply <em>attempts &times; accuracy</em>, so a blank is a guaranteed zero and a guess is free. Because there is no per-section limit, a puzzle that costs four minutes is paid for out of the other sections, not out of its own. Because the clock is 120 minutes for 100 questions, the whole paper runs at an average of 72 seconds per question.</p>
                <p>What the model does not contain is your category, because that is the one thing that moves the weights — the subject of the next lesson.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The HAT is the <strong>Higher Education Aptitude Test</strong>, conducted by the <strong>Education Testing Council (ETC) of the Higher Education Commission (HEC), Pakistan</strong>. It is the standardised route into MS and MPhil programmes at HEC-recognised universities, it is used for PhD admission through its subject variant, and it is the screening test for HEC-nominated scholarships such as the Commonwealth and Chinese Government (CSC) awards.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Property</th><th scope="col">Value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Questions</td><td>100 MCQs, 1 mark each, 100 marks total</td></tr>
                        <tr><td>Time allowed</td><td>120 minutes for the whole paper</td></tr>
                        <tr><td>Sections</td><td>Verbal Reasoning, Analytical Reasoning, Quantitative Reasoning</td></tr>
                        <tr><td>Medium</td><td>English, paper-based MCQ answer sheet</td></tr>
                        <tr><td>Negative marking</td><td>None</td></tr>
                        <tr><td>Calculator</td><td>Not allowed</td></tr>
                        <tr><td>Qualifying score</td><td>50 out of 100 for MS/MPhil admission; competitive scholarships want far more</td></tr>
                        <tr><td>Score validity</td><td>2 years from the date of the test</td></tr>
                        <tr><td>Test cycles</td><td>Quarterly, at centres across the country</td></tr>
                    </tbody>
                </table>
                <p>Your category is chosen at registration from your 16 years of education, and it decides how the 100 marks are split:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Stream</th><th scope="col">Verbal</th><th scope="col">Analytical</th><th scope="col">Quantitative</th><th scope="col">For degrees in</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><strong>HAT-1</strong></td><td>30</td><td>30</td><td><strong>40</strong></td><td>Engineering and Technology, Computer Science, Mathematics, Statistics, Physics</td></tr>
                        <tr><td>HAT-2</td><td>30</td><td>40</td><td>30</td><td>Management Sciences, Business Education</td></tr>
                        <tr><td>HAT-3</td><td>40</td><td>35</td><td>25</td><td>Arts and Humanities, Social Sciences, Psychology, Law</td></tr>
                        <tr><td>HAT-4</td><td>40</td><td>30</td><td>30</td><td>Agriculture and Veterinary, Biological and Medical Sciences, Physical Sciences, Education, Media</td></tr>
                        <tr><td>HAT-General</td><td>40</td><td>30</td><td>30</td><td>Religious Studies (madrasa graduates)</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-warn">
                    <strong>HAT-1 has no technical section.</strong> Many engineering candidates arrive expecting physics, programming or circuit questions. They are not on the paper: for HAT-1 the three aptitude sections <em>are</em> the 100%. If you have been revising mechanics and logic gates, you have been training for a race that is not on the calendar. Everything in this course is on the paper.
                </div>
                <div class="callout callout-tip">
                    <strong>The PhD variant is a different paper.</strong> HAT-Subject (for PhD admission) is 30% aptitude — 15% verbal plus 15% analytical — and 70% subject-specific content from your discipline, with a higher qualifying bar of 60%. If your goal is a PhD rather than an MS/MPhil, this course trains the 30% aptitude half; you will also need disciplined subject revision.
                </div>
                <h3>What you take into the hall</h3>
                <ul>
                    <li>Original CNIC and the printed roll number slip — without them you do not sit the test.</li>
                    <li>Blue or black ballpoint pen for the answer sheet.</li>
                    <li>Nothing else. Phones, smart watches, calculators, notes and bags stay outside.</li>
                </ul>
                <p>Registration is online through the ETC portal, in a window that closes before the test date. Register early: the portal is busiest in the last two days, and a paid challan does not count as a submitted application until you have logged back in and submitted it.</p>
                <div class="callout callout-warn">
                    <strong>Verify before you plan around it.</strong> Tests evolve: HEC has introduced subject-weighted variants, some special scholarship cycles publish a single uniform weightage for every candidate, and universities can require a score above the minimum. Treat the numbers above as the published HAT-1 pattern, and confirm the current circular on the ETC portal plus your target department's admission notice before your final weeks.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p>A HAT-1 candidate's paper comes back section by section:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">Marks available</th><th scope="col">Marks earned</th><th scope="col">Accuracy</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Quantitative</td><td>40</td><td>30</td><td>75%</td></tr>
                        <tr><td>Verbal</td><td>30</td><td>15</td><td>50%</td></tr>
                        <tr><td>Analytical</td><td>30</td><td>12</td><td>40%</td></tr>
                    </tbody>
                </table>
                <p>Total: 30 + 15 + 12 = <strong>57 out of 100</strong>. That clears the 50-mark admission floor, and it would not survive a competitive scholarship shortlist.</p>
                <p>Read the same score a second way, as a training plan. Quantitative is already at 75%, so its remaining 10 marks are the most expensive on the paper. Verbal and Analytical are at 50% and 40%: eighteen marks are sitting there in <em>rule-based</em> questions — agreement, prepositions, vocabulary, syllogisms, series — that a few weeks of drilling converts into marks. The plan writes itself, and weightage alone would not have written it.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Answer without scrolling back. Every option explains itself, right or wrong.</p>
                <div class="quiz" id="quiz-1">
                    <p>On a 100-question paper with 120 minutes allowed, roughly how long do you have per question?</p>
                    <button class="quiz-option" data-correct="true" data-explain="120 minutes divided by 100 questions is 1.2 minutes, which is 72 seconds." onclick="checkQuiz('quiz-1', this)">About 72 seconds per question</button>
                    <button class="quiz-option" data-correct="false" data-explain="Two minutes per question would take 200 minutes, well past the 120-minute limit." onclick="checkQuiz('quiz-1', this)">About 2 minutes per question</button>
                    <button class="quiz-option" data-correct="false" data-explain="30 seconds per question finishes the paper in 50 minutes and leaves more than half the clock unused." onclick="checkQuiz('quiz-1', this)">About 30 seconds per question</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>An Electrical Engineering graduate registers for HAT-1. Which section carries the most marks, and how many?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Verbal carries 30 marks on HAT-1. The heaviest section is Quantitative." onclick="checkQuiz('quiz-2', this)">Verbal Reasoning, 40 marks</button>
                    <button class="quiz-option" data-correct="true" data-explain="HAT-1 is the engineering, computer science, mathematics, statistics and physics stream, where Quantitative Reasoning carries 40 of the 100 marks." onclick="checkQuiz('quiz-2', this)">Quantitative Reasoning, 40 marks</button>
                    <button class="quiz-option" data-correct="false" data-explain="There is no separate subject or technical section on HAT-1: the paper is 30 verbal, 30 analytical and 40 quantitative, and nothing else." onclick="checkQuiz('quiz-2', this)">Physics and computing, 40 marks</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Thirty seconds remain and you cannot decide between two options. What is the correct action?</p>
                    <button class="quiz-option" data-correct="false" data-explain="With no negative marking a blank can only ever be worth zero, while a two-way guess is worth half a mark in expectation." onclick="checkQuiz('quiz-3', this)">Leave it blank to protect the score</button>
                    <button class="quiz-option" data-correct="true" data-explain="Wrong answers are not penalised, so a guess between two options has positive expectation while a blank is a guaranteed zero." onclick="checkQuiz('quiz-3', this)">Shade your best guess and move on</button>
                    <button class="quiz-option" data-correct="false" data-explain="Only one option can be correct, so shading several gains nothing and risks an ambiguous answer sheet." onclick="checkQuiz('quiz-3', this)">Shade both options</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>A friend taking HAT-Subject for a PhD asks how much of their paper is aptitude. What do you tell them?</p>
                    <button class="quiz-option" data-correct="false" data-explain="The 70% figure is the subject-specific component, not the aptitude part. Aptitude is 30%, split 15% verbal and 15% analytical." onclick="checkQuiz('quiz-4', this)">70%, the same as the general paper</button>
                    <button class="quiz-option" data-correct="true" data-explain="HAT-Subject is 30% aptitude (15% verbal, 15% analytical) plus 70% subject-specific achievement, and it qualifies at 60% rather than 50%." onclick="checkQuiz('quiz-4', this)">30% aptitude plus 70% subject content</button>
                    <button class="quiz-option" data-correct="false" data-explain="Quantitative is the heaviest section on HAT-1, but the PhD variant is built differently: aptitude is a minority of the paper." onclick="checkQuiz('quiz-4', this)">100% aptitude, identical to HAT-1</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: name the three sections, and state the two numbers that define the paper's shape.</p>
                <p>The answer: Verbal Reasoning, Analytical Reasoning and Quantitative Reasoning; 100 questions in 120 minutes, with no negative marking.</p>
                <div id="fill-1">
                    <p>My paper has <input type="text" class="fill-blank" data-answer="100" placeholder="?" aria-label="number of questions" /> multiple-choice questions worth one mark each, to be answered in <input type="text" class="fill-blank" data-answer="120" placeholder="?" aria-label="minutes allowed" /> minutes. The commonly cited qualifying score for MS/MPhil admission is <input type="text" class="fill-blank" data-answer="50" placeholder="?" aria-label="qualifying marks" /> out of 100, and there is <input type="text" class="fill-blank" data-answer="no" placeholder="?" aria-label="negative marking yes or no" /> negative marking.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are a Computer Science graduate with six weeks and one attempt you care about. Your arithmetic is fast, your grammar is weak, and you have never solved a seating-arrangement puzzle. What does the paper you are sitting tell you to do, and what does it tell you not to do?</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Register for HAT-1. Quantitative is 40 marks and already fast for you, so the first job is to <em>protect</em> those marks: secure the arithmetic, percentages, ratio and algebra topics that the section is built on, and stop when your accuracy is high and stable. That is not where the remaining marks are.</p>
                    <p>The remaining marks are in 60 that sit outside Quantitative. Verbal at 30 marks contains a large block of rule-based questions — agreement, prepositions, vocabulary, sentence completion — which convert faster than any other material on the paper, because a rule learned once is right every time. Analytical at 30 marks contains puzzle families with a small number of procedures: draw the grid, encode the constraints, eliminate. Those procedures turn a 40% section into a 65% section in a few weeks, and they are exactly the things this course drils.</p>
                    <p>What the paper tells you <em>not</em> to do: revise physics, programming or digital logic because you are an engineer. They are not on HAT-1. And do not spend six weeks polishing the section you already like: past 75% accuracy, an hour in Quantitative buys less than an hour anywhere else.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now know the arena: 100 questions, 120 minutes, three sections, no penalties, and a 40-mark quantitative block that is yours to protect. The next lesson converts those weights into a study budget — how many hours each section should get, and why the answer is not "40% of my time on the 40-mark section".</p>
            </div>

            <div class="lesson-footer">
                <span>Module 1 · Lesson 1 of 44</span>
                <span><a href="/courses/hat/lessons/hat-weightage-strategy">Next: Weightage and Study Strategy</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
