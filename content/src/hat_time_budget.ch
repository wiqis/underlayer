// HAT course — Concept 4: Time budget and the three-pass protocol.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_time_budget() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Your 120 Minutes — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Your 120 Minutes: Time Budgets and Checkpoints</h1>
            <div class="lesson-meta">13 min · Module 1: Know the Arena · Technique</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Two candidates can know exactly the same mathematics and finish ten marks apart, because the clock is a section of the paper in its own right. The HAT gives you no per-section limit, which feels generous and is actually the trap: a single analytical puzzle that swallows nine minutes removes the time you needed for three verbal questions you would certainly have answered correctly.</p>
                <p>Budgeting is not about hurrying. It is about deciding <em>in advance</em> what each question is allowed to cost, so that the decision costs no thinking during the paper. Athletes do not decide their pace mid-race; they know their splits before the gun.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Model the paper as a <strong>budget you spend</strong>. You start with 7,200 seconds and every question draws from the same account.</p>
                <div class="formula">budget per question = 120 minutes &divide; 100 questions = 1.2 minutes = 72 seconds</div>
                <p>Weights tell you how large each section's bill is. On HAT-1 the marks split 40/30/30, and with 100 questions the papers roughly split the same way: about 40 quantitative, 30 verbal and 30 analytical questions. Spending in proportion to marks looks like this:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">Marks</th><th scope="col">Approx. questions</th><th scope="col">Neutral time</th><th scope="col">Time per question</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Quantitative</td><td>40</td><td>40</td><td>48 min</td><td>72 s</td></tr>
                        <tr><td>Verbal</td><td>30</td><td>30</td><td>36 min</td><td>72 s</td></tr>
                        <tr><td>Analytical</td><td>30</td><td>30</td><td>36 min</td><td>72 s</td></tr>
                    </tbody>
                </table>
                <p>The neutral split is your baseline, not your plan. The plan adds two things: a <strong>reserve</strong> and <strong>checkpoints</strong>.</p>
                <ul>
                    <li><strong>Reserve:</strong> keep about 8 minutes unspent at the 100-minute mark. That reserve pays for the three puzzles that need a second pass and for filling every remaining blank at the end.</li>
                    <li><strong>Checkpoint:</strong> at each checkpoint you compare your position with the plan and change pace — not at the end, when it is too late to matter.</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Here is a concrete HAT-1 plan. It front-loads Quantitative because that section is worth the most and because its questions vary most in cost, and it keeps a fifth of the paper in reserve.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Elapsed</th><th scope="col">Checkpoint</th><th scope="col">Action if behind</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0-8 min</td><td>Settle and run the first pass on the easiest quantitative questions</td><td>Skip anything that needs a written setup longer than one line</td></tr>
                        <tr><td>8-50 min</td><td>Quantitative completed to a first pass</td><td>Move on with gaps flagged; the second pass returns to them</td></tr>
                        <tr><td>50-85 min</td><td>Verbal completed</td><td>Give reading passages a hard 4-minute ceiling each</td></tr>
                        <tr><td>85-112 min</td><td>Analytical completed</td><td>Cap each puzzle setup at 6 minutes, then guess and leave</td></tr>
                        <tr><td>112-120 min</td><td>Final sweep</td><td>No blanks anywhere; re-check flagged items only</td></tr>
                    </tbody>
                </table>
                <p>Three structural facts about the clock deserve their own paragraph:</p>
                <ul>
                    <li><strong>Verbal questions are cheap to answer and expensive to read.</strong> A reading comprehension passage with four questions costs 3 to 5 minutes for the set; a vocabulary item costs 20 seconds. Budget per <em>item type</em>, not per section average.</li>
                    <li><strong>Analytical puzzles are sold in sets.</strong> One setup normally spawns three to five questions. Six to eight minutes for a five-question set is efficient; six minutes for one question is catastrophic. Either you draw the diagram and take the whole set, or you skip the whole set and spend its time on arithmetic.</li>
                    <li><strong>Quantitative is bimodal.</strong> Half its questions are 20-second questions and half are 90-second questions. The failure mode is not slowness, it is treating a 20-second item as if it deserved a 90-second effort.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>The 40-second look.</strong> When you read a question, give yourself 40 seconds. If you cannot see the route to an answer in that time, mark it and leave. You are not abandoning it; you are storing it for the second pass, where it will be cheaper because the easy questions around it are gone and your mind is clearer.
                </div>
                <div class="callout callout-warn">
                    <strong>The sunk-cost trap.</strong> Having spent three minutes on a question is not a reason to spend four. The three minutes are gone whether you stay or leave, and the only question that matters is whether the <em>next</em> minute is better spent here or on an untouched question that you know how to do.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p>It is minute 60 with a HAT-1 plan; you have completed 30 quantitative questions, 25 verbal and 5 analytical. Forty questions remain, and there are 60 minutes left. Do you keep the plan?</p>
                <p>Arithmetic first: 40 questions with 60 minutes is 90 seconds each, which is 25% more than the neutral 72 seconds - comfortable. What is left is 10 quantitative, 5 verbal and 25 analytical. Allocate 15 minutes to the remaining quantitative and verbal items and 40 minutes to the analytical block, holding 5 minutes as the reserve. That is 60 seconds per quantitative or verbal item and 96 seconds per analytical item - tighter than the neutral pace on the short items, but achievable, because you are now answering only questions you can see your way through.</p>
                <p>What changed at the checkpoint: not the plan's shape, but the reserve. Being behind at one checkpoint should spend the reserve, never the accuracy.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>The HAT has no per-section time limit. What does that fact actually change?</p>
                    <button class="quiz-option" data-correct="false" data-explain="No section limit means the opposite: a slow question in one section is paid for by the other sections, which makes overspending contagious." onclick="checkQuiz('quiz-1', this)">Nothing — every question still costs the same</button>
                    <button class="quiz-option" data-correct="true" data-explain="You control one pool of 7,200 seconds, so time taken by a hard question in any section is time removed from every other section." onclick="checkQuiz('quiz-1', this)">A slow question in one section is paid for by the others</button>
                    <button class="quiz-option" data-correct="false" data-explain="There is no requirement to finish a section before moving on; the single pool of time makes section hopping a legitimate technique." onclick="checkQuiz('quiz-1', this)">You must finish a section before starting the next</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>You have spent three minutes on a quantitative question and still see no route. What is the correct action?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Staying because time has already been spent is the sunk-cost fallacy; the spent minutes are gone either way, and the next minute is worth more elsewhere." onclick="checkQuiz('quiz-2', this)">Stay with it, since three minutes are already invested</button>
                    <button class="quiz-option" data-correct="true" data-explain="Flag it and leave. Because there is no negative marking, you lose nothing by returning later, and the freed minutes buy marks you can definitely collect." onclick="checkQuiz('quiz-2', this)">Mark it, move on, and return in the second pass</button>
                    <button class="quiz-option" data-correct="false" data-explain="Guessing immediately is not wrong in itself, but leaving the question behind while marking it lets you return with fresh eyes instead of closing it off for certain." onclick="checkQuiz('quiz-2', this)">Shade a random option and erase your working</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>A single analytical setup comes with five linked questions. What is a sensible budget for the whole set?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Five minutes per question, 25 minutes for the set, would consume a fifth of the paper on five marks." onclick="checkQuiz('quiz-3', this)">Five minutes per question, 25 minutes for the set</button>
                    <button class="quiz-option" data-correct="true" data-explain="Drawing the diagram once and reading five questions off it is efficient at roughly 6 to 8 minutes for the set, about 1.5 minutes per mark." onclick="checkQuiz('quiz-3', this)">Six to eight minutes for the set, diagram first</button>
                    <button class="quiz-option" data-correct="false" data-explain="Skipping every set is too expensive: analytical is a third of the paper, and sets answered from a correct diagram are among the most reliable marks available." onclick="checkQuiz('quiz-3', this)">Skip all sets to protect the quantitative section</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what is the neutral time per question, and what is the reserve for?</p>
                <p>The answer: 72 seconds; the reserve pays for second-pass puzzles and the final sweep that fills every blank.</p>
                <div id="fill-1">
                    <p>The paper gives me <input type="text" class="fill-blank" data-answer="120" placeholder="?" aria-label="total minutes" /> minutes for 100 questions, which is <input type="text" class="fill-blank" data-answer="72" placeholder="?" aria-label="seconds per question" /> seconds per question. I hold roughly <input type="text" class="fill-blank" data-answer="8" placeholder="?" aria-label="reserve minutes" /> minutes in reserve, and when I cannot see a route within <input type="text" class="fill-blank" data-answer="40" placeholder="?" aria-label="seconds before flagging" /> seconds I flag the question and move on.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are 45 minutes in. Quantitative is finished, verbal is done except one passage, and you have spent 11 minutes on a scheduling puzzle that is still not solved. There are 75 minutes left and 34 questions untouched. Write the decision.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Leave the puzzle now, with a provisional answer shaded, and finish the reading passage while your reading speed is fresh. Then take the untouched analytical sets in order, capped at eight minutes per set, and return to the abandoned puzzle only if the second pass finishes early. If it does not, the provisional answer stays — a guessed set is worth the same as a blank, and you will not leave it blank.</p>
                    <p>The numbers behind the decision: 34 questions in 75 minutes is 2.2 minutes each, so the pace is comfortable as long as no single item is allowed to become unbounded. Eleven minutes on one setup is already a third of a five-question set's entire value; the mistake was not the attempt, it was the absence of a cap before starting.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now have a budget and checkpoints. The next lesson is the other half of pacing: what to do with a question you cannot finish — the elimination arithmetic that makes guessing profitable, and the triage rules that decide which questions to skip on sight.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-study-plan">Previous: The Eight-Week Program</a></span>
                <span><a href="/courses/hat/lessons/hat-triage-and-guessing">Next: Triage and Guessing</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
