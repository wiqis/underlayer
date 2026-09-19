// HAT course — Work, pipes and rates: worker-days, combined work, filling and draining.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_work_rate() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Work, Pipes and Rates — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Work, Pipes and Rates</h1>
            <div class="lesson-meta">15 min · Module 2: Quantitative Reasoning · Rates</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Work questions are the quantitative section's most procedural family. "A can do a job in 12 days and B in 18" is not a problem to be intuited; it is a template to be applied, and the template never changes. Learn four setups — worker-days, combined rates, pipes, and partway joins — and you can convert a whole block of questions into mechanical arithmetic.</p>
                <p>The classic failure here is adding times. Two workers taking 12 and 18 days do <em>not</em> take 30 days together, and they do not take 15. The reason is worth understanding once, because it is the same reason average speed is not the average of speeds.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Convert every worker into a <strong>rate</strong>: the fraction of the job they finish in one unit of time.</p>
                <div class="formula">worker who takes a days alone has rate 1 &divide; a jobs per day</div>
                <p>When workers act together, their rates <em>add</em>, because in one day they collectively finish the sum of their daily shares.</p>
                <div class="formula">1 &divide; T = 1 &divide; a + 1 &divide; b &nbsp;&nbsp;so&nbsp;&nbsp; T = ab &divide; (a + b)</div>
                <p>For two workers the shortcut T = ab &divide; (a + b) is worth memorising: 12 and 18 days give (12 &times; 18) &divide; 30 = 7.2 days, and the answer is always less than the smaller of the two times — a one-second sanity check that kills most wrong options.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Setup 1 — Worker-days</h3>
                <p>If the work is measured in people rather than days, the total work is constant:</p>
                <div class="formula">workers &times; days = constant &nbsp;&nbsp;(more workers means fewer days)</div>
                <p>Fifteen workers finish a job in 20 days, so the job is 300 worker-days; 25 workers need 300 &divide; 25 = 12 days. If the question mentions hours per day, convert to worker-hours first: 15 workers &times; 20 days &times; 8 hours = 2,400 worker-hours.</p>
                <h3>Setup 2 — Combined rates</h3>
                <p>Add the fractions, then invert. Three workers follow the same rule: 1 &divide; T = 1 &divide; a + 1 &divide; b + 1 &divide; c, so 6, 12 and 12 days give 1/6 + 1/12 + 1/12 = 1/3, which is 3 days.</p>
                <h3>Setup 3 — Pipes filling and draining</h3>
                <p>An inlet adds its rate; an outlet subtracts. A pipe filling in 6 hours and a drain emptying in 9 hours have a net rate of 1/6 &minus; 1/9 = 1/18, so the tank fills in 18 hours — slower than the inlet alone, which is the point of the question.</p>
                <h3>Setup 4 — Joining, leaving, alternating</h3>
                <ul>
                    <li><strong>Joining partway:</strong> compute the fraction finished by the first worker, subtract it from 1, then divide the remainder by the new combined rate.</li>
                    <li><strong>Alternating days:</strong> the pair's two-day rate is 1/a + 1/b, so the number of two-day cycles is 1 &divide; (1/a + 1/b), and any remainder is handled in the order stated.</li>
                    <li><strong>Efficiency ratios:</strong> "B is twice as fast as A" means B's rate is double and B's time is half. Compare <em>rates</em>, not times, whenever the question uses the word efficient.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>The answer is always below the fastest time.</strong> Two or more workers together must beat the best individual time, and combined with a drain the result must be worse than the inlet alone. Checking against those two bounds takes two seconds and eliminates three of four options on most questions in this family.
                </div>
                <div class="callout callout-warn">
                    <strong>Never add times, and never add efficiencies as times.</strong> The two errors are mirror images: 12 and 18 days is not 30 and not 15, and a worker who is 50% more efficient than a 10-day worker takes 10 &times; 2/3 = 6.67 days, not 5 days.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. A finishes a job in 12 days, B in 18. Working together, how long?</h3>
                <p>1/12 + 1/18 = 3/36 + 2/36 = 5/36, so T = 36/5 = <strong>7.2 days</strong>. The shortcut agrees: 216 &divide; 30 = 7.2. Sanity check: less than 12, as it must be.</p>
                <h3>2. A works alone for 4 days, then B joins. A alone would need 10 days; B alone would need 15. When is the job finished?</h3>
                <p>A's four days produce 4/10 = 0.4 of the job, leaving 0.6. Working together the rate is 1/10 + 1/15 = 1/6, so the remaining work takes 0.6 &times; 6 = 3.6 days. Total: 4 + 3.6 = <strong>7.6 days</strong>.</p>
                <h3>3. Twelve workers build a wall in 15 days. How long would nine workers take?</h3>
                <p>Total work = 12 &times; 15 = 180 worker-days, so nine workers need 180 &divide; 9 = <strong>20 days</strong>. Fewer workers, more days — inverse proportion.</p>
                <h3>4. A is twice as fast as B, and together they finish in 8 days. How long would A take alone?</h3>
                <p>Let B's rate be r, so A's is 2r and the total is 3r = 1/8, giving r = 1/24. B alone would need 24 days and A alone <strong>12 days</strong>. Check: 1/12 + 1/24 = 3/24 = 1/8.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>A can paint a room in 6 days and B in 12. Together?</p>
                    <button class="quiz-option" data-correct="false" data-explain="9 days is the plain average of 6 and 12, which ignores that both work on every day." onclick="checkQuiz('quiz-1', this)">9 days</button>
                    <button class="quiz-option" data-correct="true" data-explain="1/6 + 1/12 = 3/12 = 1/4, so together they need 4 days, which is less than the faster worker alone." onclick="checkQuiz('quiz-1', this)">4 days</button>
                    <button class="quiz-option" data-correct="false" data-explain="18 days is the sum of the times, which is what happens when nobody works together." onclick="checkQuiz('quiz-1', this)">18 days</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Fifteen workers complete a job in 20 days. How many days for 25 workers at the same rate?</p>
                    <button class="quiz-option" data-correct="false" data-explain="33.3 days ignores the inverse relationship: more workers must take fewer days, not more." onclick="checkQuiz('quiz-2', this)">33.3 days</button>
                    <button class="quiz-option" data-correct="true" data-explain="The job is 15 &times; 20 = 300 worker-days, and 300 &divide; 25 = 12 days." onclick="checkQuiz('quiz-2', this)">12 days</button>
                    <button class="quiz-option" data-correct="false" data-explain="10 days would need 30 workers; with 25 the answer is 12 days." onclick="checkQuiz('quiz-2', this)">10 days</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>An inlet fills a tank in 4 hours and a drain empties it in 6 hours. With both open, how long to fill it?</p>
                    <button class="quiz-option" data-correct="false" data-explain="2.4 hours ignores the drain entirely; the drain slows the fill and must be subtracted." onclick="checkQuiz('quiz-3', this)">2.4 hours</button>
                    <button class="quiz-option" data-correct="true" data-explain="Net rate = 1/4 &minus; 1/6 = 3/12 &minus; 2/12 = 1/12, so the tank fills in 12 hours." onclick="checkQuiz('quiz-3', this)">12 hours</button>
                    <button class="quiz-option" data-correct="false" data-explain="10 hours corresponds to a net rate of 1/10, which is not what 1/4 minus 1/6 gives." onclick="checkQuiz('quiz-3', this)">10 hours</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>A does a job in 10 days and B in 15. They work together for 3 days. What fraction of the job remains?</p>
                    <button class="quiz-option" data-correct="false" data-explain="One third is the combined three-day rate written as 3 &times; 1/6, but the question asks what remains, which is the complement." onclick="checkQuiz('quiz-4', this)">1/3</button>
                    <button class="quiz-option" data-correct="true" data-explain="Combined rate 1/6, so three days complete half the job and half remains." onclick="checkQuiz('quiz-4', this)">1/2</button>
                    <button class="quiz-option" data-correct="false" data-explain="1/5 would leave more work undone than the seven days the pair actually needed." onclick="checkQuiz('quiz-4', this)">1/5</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: how do you turn "a days alone" into a rate, and what happens to rates when workers act together?</p>
                <p>The answer: the rate is 1 &divide; a jobs per day, and rates add when workers act together.</p>
                <div id="fill-1">
                    <p>A worker who needs a days alone has a rate of 1 divided by <input type="text" class="fill-blank" data-answer="a" placeholder="?" aria-label="denominator of the rate" /> jobs per day. When workers act together their rates <input type="text" class="fill-blank" data-answer="add" placeholder="?" aria-label="what happens to rates" />. For two workers taking 12 and 18 days, the combined time is <input type="text" class="fill-blank" data-answer="7.2" placeholder="?" aria-label="combined days" /> days, and the total work in a worker-days problem is workers <input type="text" class="fill-blank" data-answer="times" placeholder="?" aria-label="operation on workers and days" /> days.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A question reads: "Pipe A fills a tank in 8 hours. Pipe B fills it in 12 hours, and a drain C empties it in 24 hours. All three are opened. How long until the tank is full?" Solve it and give the sanity check.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Net rate = 1/8 + 1/12 &minus; 1/24. Over a common denominator of 24: 3/24 + 2/24 &minus; 1/24 = 4/24 = 1/6. So the tank fills in <strong>6 hours</strong>.</p>
                    <p>The sanity check is a bound test: without the drain, pipes A and B together fill the tank in 4.8 hours (1/8 + 1/12 = 5/24), so the answer must be greater than 4.8 and less than 8 (the best single pipe). Six hours satisfies both bounds, which eliminates any option outside that window without a single extra calculation.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Rates are done. The next lessons turn to counting and probability — how many ways something can happen, and how likely a given outcome is — which is the last block of quantitative material with its own vocabulary.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-rates-speed-distance">Previous: Speed, Distance and Time</a></span>
                <span><a href="/courses/hat/lessons/hat-counting-probability">Next: Counting and Probability</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
