// HAT course — Concept 2: Weightage and study strategy (verified weights + topic priorities).
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
            <div class="lesson-meta">15 min · Module 1: Know the Arena · Planning</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Most candidates divide their preparation evenly across the three sections, because equal feels fair. On HAT-1 that is the most expensive planning mistake available: Quantitative carries 40 of the 100 marks while the other two carry 30 each, and the two weaker sections are usually where the cheapest marks are hiding.</p>
                <p>Worse, the sections do not improve at the same rate. A grammar rule learned once is right every single time it appears. A puzzle practised is worth marks only when a similar puzzle shows up. So study time has to follow two things at once: how many marks a section can produce, and how quickly your next hour converts into them.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Treat preparation as a budget problem with diminishing returns.</p>
                <div class="formula">marks from the next hour = (marks available) &times; (room left below your ceiling) &times; (learnability)</div>
                <ul>
                    <li><strong>Marks available</strong> sets the ceiling. Quantitative can produce 40 marks, so it can never be ignored; but nobody can score 150 in it.</li>
                    <li><strong>Room left</strong> sets the return. Going from 40% to 60% in a section is worth more marks per hour than going from 85% to 90%.</li>
                    <li><strong>Learnability</strong> sets the slope. Rule-based topics (agreement, prepositions, syllogisms, series, percentage templates) improve fast and hold; open-ended reading speed improves slowly.</li>
                </ul>
                <p>Read the formula as a spending rule: every hour goes to the section and topic that maximises the product, not to the section with the biggest headline weight.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The published section weights for every HAT stream:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Stream</th><th scope="col">Verbal</th><th scope="col">Analytical</th><th scope="col">Quantitative</th><th scope="col">Where your hours should point</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><strong>HAT-1</strong></td><td>30</td><td>30</td><td><strong>40</strong></td><td>Protect Quantitative, then buy rule-based Verbal and Analytical marks</td></tr>
                        <tr><td>HAT-2</td><td>30</td><td><strong>40</strong></td><td>30</td><td>Analytical puzzle procedure first</td></tr>
                        <tr><td>HAT-3</td><td><strong>40</strong></td><td>35</td><td>25</td><td>Verbal rules first, then puzzle procedure, a floor in Quantitative</td></tr>
                        <tr><td>HAT-4</td><td><strong>40</strong></td><td>30</td><td>30</td><td>Verbal first</td></tr>
                        <tr><td>HAT-General</td><td><strong>40</strong></td><td>30</td><td>30</td><td>Verbal first</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-tip">
                    <strong>HAT-1 in one line:</strong> 100% of the paper is the three aptitude sections. There is no technical or subject section to revise, so a Computer Science graduate should spend zero hours on mechanics or logic gates and put all of it into these three sections.
                </div>
                <p>The published table stops at section level, so the topic priorities below are inferred from those weights and from the composition of past papers. They are the course's working map, not an official document — but they are what makes the plan concrete.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">Marks</th><th scope="col">High-frequency topics</th><th scope="col">Practice rule</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Quantitative</td><td>40</td><td>Arithmetic and estimation, percentages, ratio and rate, algebra, geometry, averages, data in tables</td><td>Blocked practice per topic, then mixed timed drills</td></tr>
                        <tr><td>Verbal</td><td>30</td><td>Synonyms and antonyms, analogies, sentence completion, grammar and error identification, prepositions, reading comprehension</td><td>Short daily repetitions; rules hold their value</td></tr>
                        <tr><td>Analytical</td><td>30</td><td>Ordering and seating puzzles, deduction, syllogisms, series, data interpretation, assumption and conclusion</td><td>Draw every puzzle; learn a small number of procedures</td></tr>
                    </tbody>
                </table>
                <p>Two rules apply whatever your stream:</p>
                <ul>
                    <li><strong>The floor rule.</strong> No section may be left weak enough to sink the total on its own. Sixty marks sit outside Quantitative on HAT-1; a candidate at 40/40 in Quantitative with 6/30 and 7/30 elsewhere scores 53 and is one bad question from failing.</li>
                    <li><strong>The no-penalty rule.</strong> Nothing in your preparation should aim at "avoiding wrong answers". Aim at "attempting more questions with an elimination step". </li>
                </ul>
                <div class="callout callout-warn">
                    <strong>If your target is a scholarship or a PhD, revisit the weights.</strong> Competitive HEC scholarship shortlists want far more than the 50-mark minimum (70 and above is a realistic target), and the HAT-Subject paper for PhD admission is built differently: 30% aptitude at 15% verbal plus 15% analytical, and 70% subject-specific content, with a 60% qualifying bar.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p>A HAT-1 diagnostic returns Quantitative 22/40, Verbal 12/30, Analytical 8/30 — a total of <strong>42 out of 100</strong>, below the qualifying line. Thirty study hours are available. Two plans compete.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Plan</th><th scope="col">Allocation</th><th scope="col">Assumed return</th><th scope="col">Projected total</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>A: quantitative only</td><td>30 h quantitative</td><td>0.5 marks/h early, 0.3 late, starting from 55%</td><td>37 + 12 + 8 = <strong>57</strong></td></tr>
                        <tr><td>B: gap-weighted</td><td>10 h per section</td><td>Q 0.5, V 0.9, A 0.6 marks/h</td><td>27 + 21 + 14 = <strong>62</strong></td></tr>
                    </tbody>
                </table>
                <p>Plan B wins despite the section weights, because Plan A poured its last ten hours into a section already near its ceiling. Weightage set the ceiling; the measured gap set the return. The correct plan protects the strong section with a short consolidation block and then spends everything else where the slope is steepest.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>How should your study hours be distributed across the three HAT-1 sections?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Equal hours ignore both the section weights and your measured gaps, and they are the single most common planning error on this test." onclick="checkQuiz('quiz-1', this)">Equally, a third to each section</button>
                    <button class="quiz-option" data-correct="true" data-explain="Weightage sets the ceiling of a section's value; your measured gap sets the return on the next hour. The plan needs both." onclick="checkQuiz('quiz-1', this)">By marks, then biased toward your weakest measured returns</button>
                    <button class="quiz-option" data-correct="false" data-explain="Quantitative is worth 40 but it is also the section a technical candidate is strongest in, so its later hours buy the fewest marks per hour." onclick="checkQuiz('quiz-1', this)">Almost entirely on Quantitative, because it is worth the most</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>You are strong in Quantitative and two sections are weak. What does the floor rule require?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Skipping a 30-mark section gives away its entire value; no other section can repay 30 marks inside the same time budget." onclick="checkQuiz('quiz-2', this)">Skip the weakest section to protect the strongest</button>
                    <button class="quiz-option" data-correct="true" data-explain="Floors protect the total: bring each section to a minimum viable level first, then push the highest-return topics." onclick="checkQuiz('quiz-2', this)">Raise every section to a minimum floor, then push the highest returns</button>
                    <button class="quiz-option" data-correct="false" data-explain="Perfecting a section you already like is the classic inversion: the last marks there are the most expensive on the paper." onclick="checkQuiz('quiz-2', this)">Perfect your favourite section before touching the others</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Which material converts fastest into marks in the final weeks?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Reading speed improves slowly and noisily; it is the wrong thing to bet late preparation on." onclick="checkQuiz('quiz-3', this)">Untimed practice at increasing reading speed</button>
                    <button class="quiz-option" data-correct="true" data-explain="Rule-based material — agreement, prepositions, vocabulary roots, syllogisms, series, percentage templates — is right every time once learned, which makes it the best late investment." onclick="checkQuiz('quiz-3', this)">Rule-based topics such as grammar, vocabulary roots and syllogisms</button>
                    <button class="quiz-option" data-correct="false" data-explain="Starting an entirely new and rarely tested topic late is the lowest-yield choice available." onclick="checkQuiz('quiz-3', this)">A new topic you have never seen, in case it appears</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: on HAT-1, which section carries the most marks, and what does the model say to do with a section you are already strong in?</p>
                <p>The answer: Quantitative at 40 marks; protect it to a floor and then de-prioritise it, because its next hour buys fewer marks than an hour in a weak, rule-based section.</p>
                <div id="fill-1">
                    <p>On HAT-1, Quantitative carries <input type="text" class="fill-blank" data-answer="40" placeholder="?" aria-label="quantitative marks" /> marks, and Verbal and Analytical carry <input type="text" class="fill-blank" data-answer="30" placeholder="?" aria-label="other sections marks" /> each. The <input type="text" class="fill-blank" data-answer="floor" placeholder="?" aria-label="rule about minimum section level" /> rule says no section may be left weak enough to sink the total, and because there is no negative marking, a question narrowed to two options should always be <input type="text" class="fill-blank" data-answer="answered" placeholder="?" aria-label="action on a narrowed question" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are registering for HAT-1 with 24 hours a week for three weeks. Your diagnostic: Quantitative 30/40 (fast but careless), Verbal 10/30 (grammar never studied), Analytical 9/30 (no idea how to draw a puzzle). Allocate the three weeks and justify the split.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Quantitative is at 75%, so its remaining value is ten marks and the cheapest of those come from <em>carelessness</em>, not content: a two-hour block on unit checks, backsolving and estimation is enough. Take 3 hours.</p>
                    <p>Verbal at 10/30 and Analytical at 9/30 are the money. Verbal's gap is rule-based — agreement, prepositions, vocabulary, sentence completion — and rule-based material holds its value, so it deserves steady daily repetition: 9 hours across three weeks, 30 minutes a day, with a timed drill each week. Analytical's gap is procedural: seating and ordering puzzles, syllogisms, series and data interpretation all have a written procedure, and three or four procedures cover most of the section: 12 hours, blocked by family, then mixed timed sets.</p>
                    <p>That also fixes the ordering: learn the procedure, drill it blocked while it is fragile, then switch to mixed timed sets so the recognition itself gets trained. The final week is mocks and error repair, not new topics.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now know where the marks are and how to spend hours on them. The next lesson turns that into a calendar: a diagnostic, eight weeks of progressive overload, weekly mocks and an error log that feeds back into your next session.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-exam-overview">Previous: Know the Arena</a></span>
                <span><a href="/courses/hat/lessons/hat-diagnostic-test">Next: Your Baseline Diagnostic</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
