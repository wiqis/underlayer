// HAT course — Concept 26: Score targets, projection and the arithmetic of improvement.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_score_targets() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("What Score Do You Need? — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>What Score Do You Need? Targets and Projection</h1>
            <div class="lesson-meta">15 min · Module 5: The Athlete's Program · Targets</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>"Do my best" is not a target, and neither is "get a good score". A target you cannot measure against cannot tell you whether this week's work was the right work. Worse, without a target candidates fall into one of two failure modes: they study until they feel ready, which never arrives, or they panic at 45 out of 100 because they do not know where the line actually is.</p>
                <p>On the HAT the line is knowable. Qualifying sits at 50 marks out of 100 on most HAT streams, and competitive programmes expect meaningfully more. Knowing your number converts a vague anxiety into a simple arithmetic problem: how many more marks, from which sections, in how many weeks.</p>
            </div>

            <div class="unit unit-model">
                <h2>The Model: Two Numbers and a Gap</h2>
                <div class="formula">gap = target − current baseline</div>
                <p>Three quantities, each measurable:</p>
                <ul>
                    <li><strong>Target.</strong> The score your programme realistically requires — the qualifying line plus a margin for competition. Set it in marks out of 100, not as a feeling.</li>
                    <li><strong>Baseline.</strong> What you scored on a cold, full-condition mock. This is the only honest starting number.</li>
                    <li><strong>Gap.</strong> The difference, which must then be decomposed by section, because sections do not grow at the same rate.</li>
                </ul>
                <p>Achievable growth depends on how much of the gap sits in each category:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Type of mark</th><th scope="col">Typical recoverable gain</th><th scope="col">How it is gained</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Attention slips</td><td>High — often 5-10 marks</td><td>Check habits; two to three weeks</td></tr>
                        <tr><td>Unfinished questions</td><td>High — pacing fixes</td><td>Time budget and triage; two weeks</td></tr>
                        <tr><td>Standard question types</td><td>Moderate to high</td><td>Procedure drilling on known templates</td></tr>
                        <tr><td>Genuine content gaps</td><td>Moderate</td><td>Targeted re-study of specific concepts</td></tr>
                        <tr><td>Hardest 15% of the paper</td><td>Low</td><td>Deliberately not chased; secure the rest first</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-tip">
                    <strong>Improvement is a stack, not a slope.</strong> Gains arrive in this order: first all blanks get filled, then attention slips stop, then pacing is fixed, then procedures are drilled. A candidate at 45 can often reach 60 without learning a single new formula, purely from the first three layers.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Detail: Turning a Target into a Plan</h2>
                <p>Take a HAT-1 style baseline of 51/100: quantitative 25/40, verbal 19/30, analytical 7/30. Target: 72. Gap: 21 marks.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">Now</th><th scope="col">Target</th><th scope="col">Where the marks come from</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Quantitative (40)</td><td>25</td><td>31</td><td>6 marks: attention checks, one or two content gaps, two unfinished items</td></tr>
                        <tr><td>Verbal (30)</td><td>19</td><td>23</td><td>4 marks: vocabulary roots plus reading-passage time discipline</td></tr>
                        <tr><td>Analytical (30)</td><td>7</td><td>18</td><td>11 marks: diagramming, set budgeting, and actually attempting every set</td></tr>
                        <tr><td><strong>Total</strong></td><td><strong>51</strong></td><td><strong>72</strong></td><td>21 marks, of which 11 come from one section's procedure</td></tr>
                    </tbody>
                </table>
                <p>Two rules for setting section targets:</p>
                <ul>
                    <li><strong>Never set a target above the number of questions in the section.</strong> A 30-question section caps at 30; planning for 28 analytical answers when you have never finished the section is planning for a fantasy.</li>
                    <li><strong>Weight the target toward where the cheapest marks are</strong>, which is almost never the hardest section. In the example above, analytical is worth 11 marks of the 21 because the candidate left questions blank — the cheapest marks in the whole paper.</li>
                </ul>
                <h3>Projection: reading your own trend</h3>
                <p>One mock tells you where you are; a series tells you the rate. Plot your section scores after each mock and read the slope, not the point.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Mock</th><th scope="col">Quant</th><th scope="col">Verbal</th><th scope="col">Analytical</th><th scope="col">Total</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Baseline</td><td>25</td><td>19</td><td>7</td><td>51</td></tr>
                        <tr><td>Week 2</td><td>26</td><td>21</td><td>13</td><td>60</td></tr>
                        <tr><td>Week 4</td><td>29</td><td>22</td><td>16</td><td>67</td></tr>
                        <tr><td>Week 6</td><td>30</td><td>23</td><td>18</td><td>71</td></tr>
                    </tbody>
                </table>
                <p>Read that table carefully. Analytical climbs 11 marks in six weeks against a 5-mark gain in quantitative — and that is the expected shape, because analytical started with blanks and quantitative started with knowledge. If instead quantitative is flat and analytical is flat while verbal climbs, the plan is misallocated: you are practising what is already comfortable.</p>
                <div class="callout callout-warn">
                    <strong>The qualifying line is not a target.</strong> Fifty marks qualifies; it does not compete. Where a programme is oversubscribed, the admission decision is made among candidates above the line, and a 72 has a materially different outcome from a 52. Set the competitive number, not the pass mark.
                </div>
                <h3>Honest expectations</h3>
                <ul>
                    <li><strong>Six to eight weeks of focused work moves a typical candidate 15-25 marks</strong>, with most of it in the first four weeks (attention, pacing and procedures are quick to fix).</li>
                    <li><strong>Diminishing returns are real.</strong> Going from 50 to 70 is far cheaper than 70 to 85, because the last 15 marks live in the hardest questions and in verbal subtleties.</li>
                    <li><strong>A flat total can hide progress.</strong> If quantitative rose 5 while analytical fell 5, there was improvement and misallocation in the same week; check sections before drawing conclusions.</li>
                    <li><strong>Plateau at 3 weeks is normal.</strong> It usually means the easy layers are exhausted and the fix is depth on procedure, not another mock.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p>You have five weeks left. You are at 58 (quantitative 27/40, verbal 22/30, analytical 9/30) and your target is 70. Where do the 12 marks come from, and in what order?</p>
                <p>First, find the free marks. Twelve questions in the analytical section were unanswered; if four of them were answerable with a drawn diagram, that is 4 marks recoverable within one week by pacing alone, and roughly 6 more over two weeks from drilling the puzzle families. Most of the 12-mark gap can therefore come from that one section.</p>
                <p>Second, bank attention. Six of the candidate's misses across two papers were misreads — that is a check habit worth perhaps 2 marks, and it also protects the analytical gains.</p>
                <p>Third, hold the rest. Quantitative and verbal need maintenance, not investment: one timed set of 40 and one of 30 per week keeps the level while the effort goes where the gap is.</p>
                <p>Order of operations: week 1 pacing and diagramming, week 2 puzzle drilling plus the check habit, weeks 3-4 mixed sets and error-log review, week 5 a single dress-rehearsal mock and taper. Twelve marks in five weeks is unremarkable when 11 of them were sitting blank.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>You scored 52 and the qualifying line for your programme is 50. Have you achieved your target?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Qualifying is a threshold, not a competitive score; among candidates above the line the higher marks win, so 52 gives no margin and no protection." onclick="checkQuiz('quiz-1', this)">Yes — you are above the line, so the target is met</button>
                    <button class="quiz-option" data-correct="true" data-explain="You have cleared the threshold but set no margin; competitive programmes decide among candidates above the line, so the real target should be set meaningfully higher." onclick="checkQuiz('quiz-1', this)">No — the pass mark is not a competitive target</button>
                    <button class="quiz-option" data-correct="false" data-explain="You did qualify, so the result is not a failure; the issue is that treating a threshold as a target leaves you exposed to oversubscription." onclick="checkQuiz('quiz-1', this)">No — you failed, and must retake immediately</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A candidate is at 45 with 14 questions left blank across the paper. What is the most likely first source of improvement?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Content gaps are usually the smaller share at this level; the blanks indicate the clock and the diagram, both of which are procedure problems." onclick="checkQuiz('quiz-2', this)">Learning new formulas for the hardest topics</button>
                    <button class="quiz-option" data-correct="true" data-explain="Blanks mean the paper was not finished, so the first layer is pacing and triage: attempt everything, budget the sets, and stop paying a hard question the time of two easy ones." onclick="checkQuiz('quiz-2', this)">Fixing pacing so the paper gets attempted</button>
                    <button class="quiz-option" data-correct="false" data-explain="More mocks measure the same unfinished behaviour; you already know you leave 14 blank, and what is missing is the technique that stops it." onclick="checkQuiz('quiz-2', this)">Sitting more mocks to raise confidence</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Your totals are 60, 61, 60 across three mocks while quantitative rose 4 and analytical fell 4. What does the trend mean?</p>
                    <button class="quiz-option" data-correct="false" data-explain="A flat total with sections moving in opposite directions indicates misallocation, not stagnation; you are improving where you are already strong." onclick="checkQuiz('quiz-3', this)">You have plateaued and should study harder across all sections</button>
                    <button class="quiz-option" data-correct="true" data-explain="The components give the diagnosis: effort is going into quantitative while analytical — usually the cheaper section — loses ground, so reallocate rather than increase total hours." onclick="checkQuiz('quiz-3', this)">Effort is misallocated — move it to the falling section</button>
                    <button class="quiz-option" data-correct="false" data-explain="Marks are not fungible across sections in practice: a 4-mark gain in one section and a 4-mark loss in another is not a wash when the loss is in the cheaper, more learnable section." onclick="checkQuiz('quiz-3', this)">Nothing has changed: a rise cancels a fall</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what are the three quantities, and why is the qualifying line not a target?</p>
                <p>The answer: target, baseline and gap; because qualifying is only a threshold, and among candidates above it higher scores win, so a pass mark provides no margin.</p>
                <div id="fill-1">
                    <p>My target is set in marks out of <input type="text" class="fill-blank" data-answer="100" placeholder="?" aria-label="target denominator" />, my baseline comes from a cold <input type="text" class="fill-blank" data-answer="mock" placeholder="?" aria-label="how the baseline is measured" />, and the difference between them is the <input type="text" class="fill-blank" data-answer="gap" placeholder="?" aria-label="difference name" />. The first improvement layer is filling every blank, which is a problem of <input type="text" class="fill-blank" data-answer="pacing" placeholder="?" aria-label="what fixes blanks" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Write your own table: current section scores from your baseline mock, target section scores summing to your target total, and one sentence per section naming where those marks come from. Then order the layers — blanks, attention, pacing, procedures, content — and assign each to a week.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>The table forces the targets to be concrete and, crucially, to be reachable section by section. A 30-question section cannot yield 28 marks, so if your target requires impossible section numbers, the total target itself is wrong and must come down or another section must rise.</p>
                    <p>When you assign the marks, work from the cheapest layer upward. Count your blanks first: those are marks you can win with the clock alone. Then count attention slips from your log, which are habits rather than knowledge. Only then look at procedure and content. Most candidates find that 60-70% of their gap is recoverable without learning anything new.</p>
                    <p>Finally, sanity-check the timing. Six to eight weeks and roughly 15-25 marks of growth is the normal envelope for a focused candidate, with the biggest jumps in the first half. If your plan needs 30 marks in three weeks, it is not a plan — it is a wish, and it will end in a panic week that costs you the marks you already had.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Targets set, plan ordered, mocks scheduled, error log running. What remains is the performance itself: the last 48 hours, the morning routine, and the discipline of the final sweep.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-review-method">Previous: How to Review So It Sticks</a></span>
                <span><a href="/courses/hat/lessons/hat-energy-management">Next: Energy, Sleep and Stamina</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
