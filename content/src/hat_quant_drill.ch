// HAT course — Quantitative drill: a timed 25-question mixed set with full solutions.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_quant_drill() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Quantitative Drill — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)
    render_hat_drill_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Quantitative Drill: 25 Questions in 30 Minutes</h1>
            <div class="lesson-meta">35 min · Module 2: Quantitative Reasoning · Timed drill</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>This is the first training session rather than a teaching session. Reading about percentages does not make you faster at percentages; doing twenty-five mixed questions against a clock does. Mixed practice is deliberately harder than blocked practice, because in the real paper nothing tells you which technique to use — recognising the type <em>is</em> the skill.</p>
                <p>Run this drill properly once, then again a week later, and compare the two scores. The gap between them is your learning rate, and it is the most honest feedback this course can give you.</p>
            </div>

            <div class="unit unit-model">
                <h2>The Protocol</h2>
                <ol>
                    <li><strong>30 minutes, no calculator, no pausing.</strong> Set a timer you can see. Write answers as a,b,c,d on paper.</li>
                    <li><strong>Answer all 25.</strong> There is no negative marking; a blank is a zero you chose.</li>
                    <li><strong>Stop at 30 minutes</strong> even if unfinished, and mark where you were: that number is your pacing data.</li>
                    <li><strong>Self-mark using the key below</strong>, writing the cause of every miss in one line.</li>
                    <li><strong>Retake the same set in 7 days.</strong> Target: 22 or more correct inside 30 minutes.</li>
                </ol>
                <p>The budget is 72 seconds per question, matching the real paper. If you finish early, spend the remaining time on the questions you flagged rather than stopping.</p>
                <h3>Or take it timed, here in the browser</h3>
                <p>Everything below is the same paper with the same answer key. The runner adds the clock, marks your answers, explains every miss, and keeps your result so the retake in seven days can be compared against this one. Nothing is sent anywhere; the score stays in this browser.</p>
                <div id="hat-drill-root" class="hat-drill"><p>Loading the drill&hellip;</p></div>
                <noscript><p>The timed runner needs JavaScript. The printed paper and the answer key above work without it.</p></noscript>
            </div>

            <div class="unit unit-reality">
                <h2>The Paper</h2>
                <ol class="drill">
                    <li><strong>Q1.</strong> What is 15% of 240?<br />(a) 24 &nbsp;&nbsp; (b) 36 &nbsp;&nbsp; (c) 45 &nbsp;&nbsp; (d) 16</li>
                    <li><strong>Q2.</strong> A price rises from Rs 80 to Rs 100. What is the percentage increase?<br />(a) 20% &nbsp;&nbsp; (b) 25% &nbsp;&nbsp; (c) 80% &nbsp;&nbsp; (d) 12.5%</li>
                    <li><strong>Q3.</strong> Divide Rs 180 in the ratio 2 : 3 : 4. What is the largest share?<br />(a) Rs 40 &nbsp;&nbsp; (b) Rs 60 &nbsp;&nbsp; (c) Rs 80 &nbsp;&nbsp; (d) Rs 90</li>
                    <li><strong>Q4.</strong> Three workers finish a job in 12 days. How long will four workers take at the same rate?<br />(a) 8 days &nbsp;&nbsp; (b) 9 days &nbsp;&nbsp; (c) 16 days &nbsp;&nbsp; (d) 48 days</li>
                    <li><strong>Q5.</strong> Solve for x: 3x + 7 = 22.<br />(a) 3 &nbsp;&nbsp; (b) 5 &nbsp;&nbsp; (c) 15 &nbsp;&nbsp; (d) 9.67</li>
                    <li><strong>Q6.</strong> What is the area of a triangle with base 10 cm and height 6 cm?<br />(a) 30 cm&sup2; &nbsp;&nbsp; (b) 60 cm&sup2; &nbsp;&nbsp; (c) 16 cm&sup2; &nbsp;&nbsp; (d) 80 cm&sup2;</li>
                    <li><strong>Q7.</strong> What is the mean of 4, 8, 10 and 14?<br />(a) 8 &nbsp;&nbsp; (b) 9 &nbsp;&nbsp; (c) 12 &nbsp;&nbsp; (d) 36</li>
                    <li><strong>Q8.</strong> A fair six-sided die is rolled once. What is the probability of an even number?<br />(a) 1/6 &nbsp;&nbsp; (b) 1/3 &nbsp;&nbsp; (c) 1/2 &nbsp;&nbsp; (d) 2/3</li>
                    <li><strong>Q9.</strong> What is the HCF of 84 and 126?<br />(a) 21 &nbsp;&nbsp; (b) 42 &nbsp;&nbsp; (c) 252 &nbsp;&nbsp; (d) 10,584</li>
                    <li><strong>Q10.</strong> What is the units digit of 2<sup>35</sup>?<br />(a) 2 &nbsp;&nbsp; (b) 4 &nbsp;&nbsp; (c) 6 &nbsp;&nbsp; (d) 8</li>
                    <li><strong>Q11.</strong> Which fraction is larger, 7/12 or 11/19?<br />(a) 7/12 &nbsp;&nbsp; (b) 11/19 &nbsp;&nbsp; (c) they are equal &nbsp;&nbsp; (d) cannot be determined</li>
                    <li><strong>Q12.</strong> The mean of 12 numbers is 15. If the number 27 is removed, what is the new mean?<br />(a) 13.9 &nbsp;&nbsp; (b) 12.75 &nbsp;&nbsp; (c) 14.5 &nbsp;&nbsp; (d) 15</li>
                    <li><strong>Q13.</strong> A train 120 m long travels at 54 km/h. How long does it take to cross a platform 180 m long?<br />(a) 8 s &nbsp;&nbsp; (b) 12 s &nbsp;&nbsp; (c) 20 s &nbsp;&nbsp; (d) 30 s</li>
                    <li><strong>Q14.</strong> A boat covers 12 km downstream in 1 hour and the same distance upstream in 2 hours. What is its speed in still water?<br />(a) 3 km/h &nbsp;&nbsp; (b) 6 km/h &nbsp;&nbsp; (c) 9 km/h &nbsp;&nbsp; (d) 12 km/h</li>
                    <li><strong>Q15.</strong> A can do a job in 12 days and B in 18 days. Working together, how long will they take?<br />(a) 6 days &nbsp;&nbsp; (b) 7.2 days &nbsp;&nbsp; (c) 15 days &nbsp;&nbsp; (d) 30 days</li>
                    <li><strong>Q16.</strong> An inlet pipe fills a tank in 6 hours and a drain empties it in 9 hours. With both open, how long does the tank take to fill?<br />(a) 3 h &nbsp;&nbsp; (b) 7.2 h &nbsp;&nbsp; (c) 15 h &nbsp;&nbsp; (d) 18 h</li>
                    <li><strong>Q17.</strong> Twelve workers complete a job in 15 days. How long would nine workers take at the same rate?<br />(a) 11.25 days &nbsp;&nbsp; (b) 16.5 days &nbsp;&nbsp; (c) 20 days &nbsp;&nbsp; (d) 28 days</li>
                    <li><strong>Q18.</strong> Two fair dice are rolled. What is the probability that the sum is 8?<br />(a) 1/6 &nbsp;&nbsp; (b) 1/9 &nbsp;&nbsp; (c) 5/36 &nbsp;&nbsp; (d) 4/36</li>
                    <li><strong>Q19.</strong> A bag holds 4 red and 6 blue balls. Two are drawn without replacement. What is the probability that both are red?<br />(a) 4/25 &nbsp;&nbsp; (b) 2/15 &nbsp;&nbsp; (c) 1/5 &nbsp;&nbsp; (d) 3/10</li>
                    <li><strong>Q20.</strong> A value falls by 20% and then rises by 20%. Compared with its starting value it is:<br />(a) unchanged &nbsp;&nbsp; (b) 4% lower &nbsp;&nbsp; (c) 4% higher &nbsp;&nbsp; (d) 2% lower</li>
                    <li><strong>Q21.</strong> Enrolment rises from 300 to 350 students. What is the percentage increase?<br />(a) 14.3% &nbsp;&nbsp; (b) 16.7% &nbsp;&nbsp; (c) 25% &nbsp;&nbsp; (d) 50%</li>
                    <li><strong>Q22.</strong> What is the simple interest on Rs 5,000 at 8% per year for 2 years?<br />(a) Rs 400 &nbsp;&nbsp; (b) Rs 800 &nbsp;&nbsp; (c) Rs 1,000 &nbsp;&nbsp; (d) Rs 5,800</li>
                    <li><strong>Q23.</strong> A car covers 150 km in 2 hours 30 minutes. What is its average speed?<br />(a) 55 km/h &nbsp;&nbsp; (b) 60 km/h &nbsp;&nbsp; (c) 75 km/h &nbsp;&nbsp; (d) 100 km/h</li>
                    <li><strong>Q24.</strong> A cyclist covers the first half of a journey at 10 km/h and the second half at 15 km/h. What is the average speed for the whole journey?<br />(a) 12 km/h &nbsp;&nbsp; (b) 12.5 km/h &nbsp;&nbsp; (c) 13 km/h &nbsp;&nbsp; (d) 25 km/h</li>
                    <li><strong>Q25.</strong> In how many ways can a committee of 3 be chosen from 7 people?<br />(a) 21 &nbsp;&nbsp; (b) 35 &nbsp;&nbsp; (c) 210 &nbsp;&nbsp; (d) 343</li>
                </ol>
            </div>

            <div class="unit unit-example">
                <h2>Answer Key and Solutions</h2>
                <p>Mark honestly, then read the solution for every question you missed <em>and</em> for every question you guessed. The trap column names the wrong answer you were probably choosing.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Q</th><th scope="col">Topic</th><th scope="col">Answer</th><th scope="col">Solution</th><th scope="col">Expected trap</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1</td><td>Percentages</td><td>(b) 36</td><td>10% is 24 and 5% is 12, so 15% is 36</td><td>(a) 24, the 10% value</td></tr>
                        <tr><td>2</td><td>Percentage change</td><td>(b) 25%</td><td>Change 20 divided by original 80</td><td>(a) 20%, dividing by the new value</td></tr>
                        <tr><td>3</td><td>Ratio</td><td>(c) 80</td><td>Parts total 9, one part is 20, largest is 4 parts</td><td>(d) 90, halving the total</td></tr>
                        <tr><td>4</td><td>Inverse proportion</td><td>(b) 9 days</td><td>36 worker-days over 4 workers</td><td>(c) 16, treating it as direct proportion</td></tr>
                        <tr><td>5</td><td>Algebra</td><td>(b) 5</td><td>3x = 15, so x = 5</td><td>(c) 15, stopping before dividing</td></tr>
                        <tr><td>6</td><td>Geometry</td><td>(a) 30 cm&sup2;</td><td>One half of 10 &times; 6</td><td>(b) 60, forgetting the half</td></tr>
                        <tr><td>7</td><td>Statistics</td><td>(b) 9</td><td>Sum 36 over 4 values</td><td>(d) 36, quoting the sum</td></tr>
                        <tr><td>8</td><td>Probability</td><td>(c) 1/2</td><td>Three even faces out of six</td><td>(b) 1/3, counting only 2 and 4</td></tr>
                        <tr><td>9</td><td>Number properties</td><td>(b) 42</td><td>84 = 2&sup2;&times;3&times;7 and 126 = 2&times;3&sup2;&times;7, so HCF = 2&times;3&times;7</td><td>(c) 252 is the LCM, (d) 10,584 the product</td></tr>
                        <tr><td>10</td><td>Number properties</td><td>(d) 8</td><td>The cycle 2, 4, 8, 6 has length 4 and 35 leaves remainder 3</td><td>(a) 2, using the exponent directly</td></tr>
                        <tr><td>11</td><td>Fractions</td><td>(a) 7/12</td><td>7 &times; 19 = 133 against 11 &times; 12 = 132</td><td>(b) 11/19, chosen from the larger numerator</td></tr>
                        <tr><td>12</td><td>Averages</td><td>(a) 13.9</td><td>Total 180 minus 27 is 153 over 11 values</td><td>(b) 12.75, dividing by 12 instead of 11</td></tr>
                        <tr><td>13</td><td>Speed</td><td>(c) 20 s</td><td>54 km/h is 15 m/s; 120 + 180 = 300 m</td><td>(b) 12 s, ignoring the train's own length</td></tr>
                        <tr><td>14</td><td>Boats</td><td>(c) 9 km/h</td><td>Downstream 12, upstream 6, so still water is their average</td><td>(a) 3 km/h, which is the current</td></tr>
                        <tr><td>15</td><td>Work</td><td>(b) 7.2 days</td><td>1/12 + 1/18 = 5/36, so the time is 36/5</td><td>(c) 15, averaging the two times</td></tr>
                        <tr><td>16</td><td>Pipes</td><td>(d) 18 h</td><td>1/6 &minus; 1/9 = 1/18</td><td>(c) 15, adding the times instead of subtracting rates</td></tr>
                        <tr><td>17</td><td>Worker-days</td><td>(c) 20 days</td><td>180 worker-days over 9 workers</td><td>(a) 11.25, treating it as direct proportion</td></tr>
                        <tr><td>18</td><td>Probability</td><td>(c) 5/36</td><td>Five pairs: (2,6), (3,5), (4,4), (5,3), (6,2)</td><td>(a) 1/6, forgetting that only one pair is a double</td></tr>
                        <tr><td>19</td><td>Probability</td><td>(b) 2/15</td><td>(4/10) &times; (3/9) = 12/90</td><td>(a) 4/25, drawing with replacement</td></tr>
                        <tr><td>20</td><td>Successive change</td><td>(b) 4% lower</td><td>100 becomes 80, then 96, because the rise is on a smaller base</td><td>(a) unchanged</td></tr>
                        <tr><td>21</td><td>Data interpretation</td><td>(b) 16.7%</td><td>50 divided by the original 300</td><td>(a) 14.3%, dividing by the new total</td></tr>
                        <tr><td>22</td><td>Interest</td><td>(b) Rs 800</td><td>5,000 &times; 8% &times; 2 years</td><td>(a) Rs 400, one year only</td></tr>
                        <tr><td>23</td><td>Speed</td><td>(b) 60 km/h</td><td>2 h 30 min is 2.5 hours</td><td>(c) 75 km/h, dividing by 2 hours</td></tr>
                        <tr><td>24</td><td>Average speed</td><td>(a) 12 km/h</td><td>Equal distances give 2ab &divide; (a + b) = 300 &divide; 25</td><td>(b) 12.5, the plain mean of 10 and 15</td></tr>
                        <tr><td>25</td><td>Counting</td><td>(b) 35</td><td>7 &times; 6 &times; 5 &divide; 3! = 210 &divide; 6</td><td>(c) 210, ordering the committee</td></tr>
                    </tbody>
                </table>
            </div>

            <div class="unit unit-interact">
                <h2>Read Your Score</h2>
                <table>
                    <thead>
                        <tr><th scope="col">Score in 30 min</th><th scope="col">What it means</th><th scope="col">Next action</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>22-25</td><td>On track for a strong quantitative section</td><td>Move to the verbal block; retake this set in a week to confirm</td></tr>
                        <tr><td>18-21</td><td>Solid, with two or three technique gaps</td><td>Return to the lessons behind the topics you missed twice</td></tr>
                        <tr><td>14-17</td><td>Knowledge present, speed or precision lacking</td><td>Redo the missed questions, then repeat timed sets of 25 every other day</td></tr>
                        <tr><td>Below 14</td><td>Fundamentals need rebuilding</td><td>Work the quantitative lessons in order, then retake this set cold</td></tr>
                    </tbody>
                </table>
                <p>If you did not finish inside 30 minutes, treat the unfinished count as the headline result: pacing, not knowledge, is then your first repair job.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Log the Result</h2>
                <div id="fill-1">
                    <p>This set has <input type="text" class="fill-blank" data-answer="25" placeholder="?" aria-label="questions in the set" /> questions to be done in 30 minutes, and a pass mark of <input type="text" class="fill-blank" data-answer="22" placeholder="?" aria-label="target score" /> or better. The paper's per-question budget is <input type="text" class="fill-blank" data-answer="72" placeholder="?" aria-label="seconds per question" /> seconds, and the retake goes in the calendar <input type="text" class="fill-blank" data-answer="7" placeholder="?" aria-label="days until retake" /> days from today.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You scored 19/25 and finished with two questions untouched. Your misses were Q12, Q15, Q16 and Q24. Write the repair plan for the next three days.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>The four misses are not four separate topics. Q15, Q16 and Q24 are all the same idea seen three ways — combining rates that do not behave like simple averages — and Q12 is the total form of the mean. So the repair is two lessons, not four review sessions: <em>Averages and Weighted Means</em> and <em>Work, Pipes and Rates</em>, plus <em>Speed, Distance and Time</em> for the harmonic-mean case.</p>
                    <p>Day 1: reread those three lessons and redo their Try It quizzes until every option's explanation is obvious. Day 2: redo only questions 12, 15, 16 and 24 from this paper, from scratch, with the clock running. Day 3: a fresh timed set of 25 questions, and compare the finish position — the two untouched questions say the real problem was pace on the rate questions, so the target is to finish all 25 with two minutes unused.</p>
                    <p>Write the plan as actions with dates, not as intentions: what you will do, on which day, and how you will know it worked.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Quantitative is drilled. The next module changes subject completely: verbal reasoning, 30 marks of rules about words — and the fastest marks on the paper to convert because a rule learned once is right every time.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-interest">Previous: Simple and Compound Interest</a></span>
                <span><a href="/courses/hat/lessons/hat-vocabulary">Next: Vocabulary You Can Actually Learn</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)
    render_hat_quant_drill_bank(&mut page)
    render_hat_quant_drill_config(&mut page)
    render_hat_drill_js(&mut page)

    return page.toString()
}
}
