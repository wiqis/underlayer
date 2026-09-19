// HAT course — Concept 2: Weightage and study strategy.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_weightage_strategy() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Weightage and Study Strategy — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Weightage and Study Strategy</h1>
            <div class="lesson-meta">14 min · Module 1: Understanding the Test · Planning</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Most candidates divide their study time evenly across the three sections. That feels fair, and it is the single most expensive planning mistake on this test, because the sections do not pay equally. On HAT-1, Quantitative Reasoning is worth 40 marks and the other two are worth 30 each; on HAT-3 the balance flips towards Verbal. Spending equal hours means deliberately over-investing in the cheapest marks and under-investing in the most expensive ones.</p>
                <p>Worse, the sections do not improve at the same rate. A rule you learn — <em>senior to</em>, not <em>senior than</em> — is worth marks immediately and permanently. A puzzle you practise is worth marks only if a similar puzzle appears. Study time should follow both the marks available and how quickly you convert hours into marks.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Model your preparation as a budget problem. You have a fixed number of hours. Each hour you spend on a section buys you some number of marks, and that number <strong>falls</strong> as you get better at the section.</p>
                <div class="formula">marginal marks per hour = (marks available in the section) x (room left to your ceiling) x (learnability)</div>
                <p>Useful consequences of this model:</p>
                <ul>
                    <li>A section that is worth 40 marks can never be ignored, but its 20th hour is worth far less than its 1st.</li>
                    <li>The first hours in a weak section are the cheapest marks on the paper, because your score there starts low and the questions are rule-based.</li>
                    <li>Sections with slow, noisy returns — typically analytical puzzles — should be practised for procedure, not for volume.</li>
                </ul>
                <p>The model is incomplete where the real test is messier: your personal learnability numbers must come from a real mock, not from a guess. That is what the next lesson builds.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The published weightages mean your strategy is <em>category-specific</em>. The table below is the one that should decide your study split, not a generic "cover everything" plan.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Category</th><th scope="col">Verbal</th><th scope="col">Analytical</th><th scope="col">Quantitative</th><th scope="col">Where the money is</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>HAT-1</td><td>30</td><td>30</td><td>40</td><td>Quantitative first, then buy cheap Verbal marks</td></tr>
                        <tr><td>HAT-2</td><td>30</td><td>40</td><td>30</td><td>Analytical first</td></tr>
                        <tr><td>HAT-3</td><td>40</td><td>35</td><td>25</td><td>Verbal first, Analytical second</td></tr>
                        <tr><td>HAT-4</td><td>40</td><td>30</td><td>30</td><td>Verbal first</td></tr>
                        <tr><td>HAT-General</td><td>40</td><td>30</td><td>30</td><td>Verbal first</td></tr>
                    </tbody>
                </table>
                <p>Two rules apply to every category:</p>
                <ul>
                    <li><strong>The floor rule.</strong> No section should be left so weak that it drags the total under the threshold by itself. A 40-mark section at 50% costs 20 marks; a 25-mark section at 0% costs 25. Floors matter more than peaks.</li>
                    <li><strong>The no-penalty rule.</strong> Because wrong answers cost nothing, every question you can narrow to two options is worth attempting. Nothing in your preparation should aim at "avoiding wrong answers"; it should aim at "answering more questions".</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>Sequence, not just split.</strong> Rules-based material (grammar, vocabulary, direction sense, coding) rewards short daily repetitions and holds its value. Problem-solving material (arithmetic, algebra, geometry) rewards blocked practice followed by mixed drills. Practise the rule-based material daily in small doses and the problem-based material in longer sessions.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>A HAT-1 candidate takes a diagnostic and scores: Quantitative 22/40, Verbal 12/30, Analytical 8/30. That is <strong>42 out of 100</strong> — below the 50-mark threshold. There are 30 study hours available. Two plans compete.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Plan</th><th scope="col">Allocation</th><th scope="col">Assumed return</th><th scope="col">Projected scores</th><th scope="col">Total</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>A, quant-only</td><td>30 h quantitative</td><td>0.5 marks/h early, 0.3 late (already at 55%)</td><td>Q 37/40, V 12/30, A 8/30</td><td>57</td></tr>
                        <tr><td>B, balanced to the gaps</td><td>10 h each section</td><td>Q 0.5, V 0.9, A 0.6 marks/h (weak sections gain fastest)</td><td>Q 27/40, V 21/30, A 14/30</td><td>62</td></tr>
                    </tbody>
                </table>
                <p>Verify the arithmetic: Plan A gives 22 + 15 = 37, and 37 + 12 + 8 = 57. Plan B gives 22 + 5 = 27, 12 + 9 = 21, 8 + 6 = 14, and 27 + 21 + 14 = 62.</p>
                <p>Plan B wins despite the section weights, because Plan A poured its last ten hours into a section that was already near its ceiling. The lesson is not "ignore weightage" — it is that weightage sets the <em>ceiling</em> of a section's value, while your current gap sets the <em>return</em> on the next hour. Spend the next hour where the return is highest, inside the sections that carry marks.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>How should study hours be allocated across the three sections?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Equal splits ignore both the section weights and your current gaps. The measured, not assumed, allocation is the whole point of the next lesson." onclick="checkQuiz('quiz-1', this)">Split study time equally across the three sections</button>
                    <button class="quiz-option" data-correct="true" data-explain="Weightage sets how much value a section can produce; your measured gap sets the next hour's return. Both belong in the plan." onclick="checkQuiz('quiz-1', this)">Weight each section by its marks, then bias hours toward your weakest measured returns</button>
                    <button class="quiz-option" data-correct="false" data-explain="Weightage alone is the ceiling, not the plan. A section you are already strong in can absorb 40 hours for two extra marks." onclick="checkQuiz('quiz-1', this)">Study only the heaviest section until it is perfect</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Your strongest section is already near its ceiling and your weakest is very low. What should the plan do?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Skipping a 30-mark section entirely can cost up to 30 marks, which no other section can repay inside the time budget." onclick="checkQuiz('quiz-2', this)">Skip the weakest section entirely to protect the strongest</button>
                    <button class="quiz-option" data-correct="true" data-explain="Sections are marks, and a section left at a very low score removes marks that nothing else can recover. Floors protect the total." onclick="checkQuiz('quiz-2', this)">Bring every section to a minimum viable floor, then push the high-return ones</button>
                    <button class="quiz-option" data-correct="false" data-explain="Raising a 90 percent section by 5 points is harder per hour than raising a 40 percent section by 5 points." onclick="checkQuiz('quiz-2', this)">Perfect the sections you already like before touching the others</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: for HAT-1, which section is worth the most marks, and what does the marginal-return model say you should do about a section you are already strong in?</p>
                <p>The answer is: Quantitative Reasoning at 40 marks; a strong section should be protected to its floor and then de-prioritised, because its next hour buys fewer marks than an hour spent on a weak, rule-based section.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>On HAT-1, Quantitative Reasoning carries <input type="text" class="fill-blank" data-answer="40" placeholder="?" aria-label="quantitative marks" /> marks, and each of the other two sections carries <input type="text" class="fill-blank" data-answer="30" placeholder="?" aria-label="other section marks" />. Because there is no negative marking, a question narrowed to two options should be <input type="text" class="fill-blank" data-answer="answered" placeholder="?" aria-label="action for a narrowed question" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are registering for HAT-3 (Arts and Humanities), where Verbal carries 40 marks, Analytical 35 and Quantitative 25. Your diagnostic shows strong reading but no practice with arrangement puzzles, and arithmetic that you have not touched since school. You have 24 hours a week for three weeks.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Three facts decide the split. First, Verbal carries the most marks, so it gets the largest block — but your reading is already strong, so the money inside this section is in the <em>rule-based</em> parts: grammar and vocabulary, which convert fast. Second, Analytical carries 35 marks and your weakness there is procedural, not conceptual: arrangement and deduction puzzles are a small number of repeatable techniques, so 3 to 4 hours buys a disproportionate share of the 35 marks. Third, Quantitative carries only 25 marks and is your weakest area, which makes it the highest-return-per-hour section up to a <em>floor</em> — enough arithmetic and percentages to stop losing easy marks — after which it should be left alone.</p>
                    <p>A workable allocation: Verbal 8 hours, Analytical 10 hours, Quantitative 6 hours. The Analytical block is the largest because it combines the second-heaviest weightage with the widest measured gap, and because puzzle technique has a short, steep learning curve that flattens quickly — exactly the shape the marginal-return model rewards.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now have a way to divide effort: by marks, adjusted by measured gaps. What you still lack is the measurement — the diagnostic that tells you which gaps you actually have, and the feedback loop that keeps the plan honest as the weeks pass.</p>
                <p>The next lesson builds that: a six-week structure with a diagnostic at the start, a written error log, and a short daily review block.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-exam-overview">Previous: What the HAT Actually Is</a></span>
                <span><a href="/courses/hat/lessons/hat-study-plan">Next: A Six-Week Study Plan</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
