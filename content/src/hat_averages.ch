// HAT course — Averages: mean, median, mode, weighted means and mixture problems.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_averages() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Averages and Weighted Means — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Averages, Weighted Means and Mixtures</h1>
            <div class="lesson-meta">15 min · Module 2: Quantitative Reasoning · Data and rate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Averages are the cheapest marks in the quantitative section and the biggest trap in data interpretation. The cheap marks come from questions that only look like averages: "the average of five numbers is 24, and four of them are known" is a subtraction, not a statistics problem. The trap is the same word doing two different jobs — a weighted mean and an average of averages are not the same number.</p>
                <p>Averages also quietly power rate questions. Average speed is a weighted average, and nearly every candidate who loses marks there loses them to the belief that averaging two speeds is the same as finding the average speed.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of an average as a way of sharing a total evenly.</p>
                <div class="formula">mean = total &divide; count &nbsp;&nbsp;equivalently&nbsp;&nbsp; total = mean &times; count</div>
                <p>The second form is the one that solves questions. It says that an average question is almost always about a <em>total</em>: if you know the mean and the count, you know the sum without ever adding anything up.</p>
                <p>Two consequences worth holding:</p>
                <ul>
                    <li><strong>Below-average values pull down, above-average values pull up</strong>, by an amount equal to the deviation shared over the count.</li>
                    <li><strong>A weighted mean is not an average of averages.</strong> Groups of different sizes contribute in proportion to their size, so the combined mean always sits closer to the bigger group.</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Four measures, precisely defined</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Measure</th><th scope="col">Definition</th><th scope="col">Watch out for</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Mean</td><td>Sum divided by count</td><td>Sensitive to extremes: one huge value moves it far</td></tr>
                        <tr><td>Median</td><td>Middle value of the ordered list; with an even count, the mean of the two middle values</td><td>You must sort first, and an even count needs a half-step</td></tr>
                        <tr><td>Mode</td><td>The value that occurs most often</td><td>A set can have no mode, one mode, or several</td></tr>
                        <tr><td>Range</td><td>Largest minus smallest</td><td>Not a measure of centre — it is a crude spread</td></tr>
                    </tbody>
                </table>
                <h3>Working with totals</h3>
                <ul>
                    <li><strong>Adding a value:</strong> new mean = (old mean &times; old count + new value) &divide; (count + 1).</li>
                    <li><strong>Adding a value equal to the mean</strong> leaves the mean unchanged — a fact that answers many "what must the next score be?" questions instantly.</li>
                    <li><strong>Fixing a deficit:</strong> to raise a mean of 20 over 10 numbers to 22, the total must rise by 10 &times; 2 = 20.</li>
                </ul>
                <h3>Weighted means and the lever rule</h3>
                <div class="formula">combined mean = (n&#8321;m&#8321; + n&#8322;m&#8322;) &divide; (n&#8321; + n&#8322;)</div>
                <p>The same fact expressed as distances: the combined mean divides the gap between the two group means in the <em>inverse</em> ratio of the group sizes. Two groups of 30 and 20 students average 60 and 70; the combined mean sits 30/50 of the way from 70 towards 60, which is 64. The bigger group wins the tug of war.</p>
                <h3>Average speed is a weighted mean</h3>
                <div class="formula">average speed = total distance &divide; total time</div>
                <p>For two equal distances covered at speeds a and b, this simplifies to the harmonic mean 2ab &divide; (a + b). For unequal distances or unequal times, always go back to totals.</p>
                <div class="callout callout-tip">
                    <strong>The deviation shortcut.</strong> To average awkward numbers, guess a round value, list each number's deviation from it, average the deviations, and add the guess back. Averaging 47, 53 and 50: guess 50, deviations are &minus;3, +3, 0, which average to 0, so the mean is 50 — no three-digit addition required.
                </div>
                <div class="callout callout-warn">
                    <strong>The two averages traps.</strong> (1) Averaging two rates because the word "average" appears — 40 km/h and 60 km/h over equal distances gives 48 km/h, not 50. (2) Averaging two group means without weighting — 30 students at 60 and 20 at 70 give 64, not 65.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. The average of five numbers is 24. Four of them are 18, 30, 22 and 20. Find the fifth.</h3>
                <p>Total = 24 &times; 5 = 120. Known sum = 18 + 30 + 22 + 20 = 90. The fifth number is 120 &minus; 90 = <strong>30</strong>.</p>
                <h3>2. A car travels 60 km at 40 km/h and returns 60 km at 60 km/h. What is its average speed?</h3>
                <p>Time out = 60 &divide; 40 = 1.5 h; time back = 60 &divide; 60 = 1 h; total 120 km in 2.5 h = <strong>48 km/h</strong>. The shortcut 2ab &divide; (a + b) gives (2 &times; 40 &times; 60) &divide; 100 = 48, and the wrong answer 50 is always among the options.</p>
                <h3>3. A class of 30 students averages 60 marks; another of 20 averages 70. What is the combined average?</h3>
                <p>(30 &times; 60 + 20 &times; 70) &divide; 50 = (1,800 + 1,400) &divide; 50 = 3,200 &divide; 50 = <strong>64</strong>. Note that the answer is nearer 60, because there are more students there.</p>
                <h3>4. The mean of 12 numbers is 15. If the number 27 is removed, what is the new mean?</h3>
                <p>Old total = 180. Removing 27 leaves 153 over 11 numbers, which is <strong>13.9</strong>. Removing an above-average value pulls the mean down — a five-second sanity check before you compute.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>A batsman's average after 10 innings is 30. He scores 80 in the eleventh. What is his new average?</p>
                    <button class="quiz-option" data-correct="false" data-explain="55 is the arithmetic mean of 30 and 80, which treats the ten innings as a single number; averages must be weighted by count." onclick="checkQuiz('quiz-1', this)">55</button>
                    <button class="quiz-option" data-correct="true" data-explain="Old total 300, plus 80 gives 380 over 11 innings, which is 34.5. This is why one brilliant innings moves a long average only slightly." onclick="checkQuiz('quiz-1', this)">34.5</button>
                    <button class="quiz-option" data-correct="false" data-explain="38 would need a total of 418, which is 118 runs in the innings, not 80." onclick="checkQuiz('quiz-1', this)">38</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>What is the median of 7, 3, 9, 5, 11, 4?</p>
                    <button class="quiz-option" data-correct="false" data-explain="6.5 is the mean of the six values, not the median; the median requires sorting first." onclick="checkQuiz('quiz-2', this)">6.5</button>
                    <button class="quiz-option" data-correct="true" data-explain="Sorted: 3, 4, 5, 7, 9, 11. With six values the median is the mean of the third and fourth, which is (5 + 7) &divide; 2 = 6." onclick="checkQuiz('quiz-2', this)">6</button>
                    <button class="quiz-option" data-correct="false" data-explain="5 is the third value in the sorted list, but with an even count the median sits between the third and fourth values." onclick="checkQuiz('quiz-2', this)">5</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>A shop sells 40 kg of rice at Rs 100 per kg and 60 kg at Rs 150 per kg. What is the average price per kg of the mixture?</p>
                    <button class="quiz-option" data-correct="false" data-explain="125 is the average of the two prices, which ignores that more rice was sold at the higher price." onclick="checkQuiz('quiz-3', this)">Rs 125</button>
                    <button class="quiz-option" data-correct="true" data-explain="Total cost = 40 &times; 100 + 60 &times; 150 = 4,000 + 9,000 = 13,000 for 100 kg, so the average is Rs 130." onclick="checkQuiz('quiz-3', this)">Rs 130</button>
                    <button class="quiz-option" data-correct="false" data-explain="Rs 135 would require 60 kg at the higher price to dominate more than it does; the weighted mean is exactly 130." onclick="checkQuiz('quiz-3', this)">Rs 135</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>The mean of five numbers is 18. Four are 12, 20, 16 and 22. What is the fifth?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Total = 18 &times; 5 = 90, known sum = 70, so the fifth number is 20." onclick="checkQuiz('quiz-4', this)">20</button>
                    <button class="quiz-option" data-correct="false" data-explain="18 is the mean itself; the missing value is computed from the total, not taken from the mean." onclick="checkQuiz('quiz-4', this)">18</button>
                    <button class="quiz-option" data-correct="false" data-explain="24 would make the total 94, giving a mean of 18.8 rather than 18." onclick="checkQuiz('quiz-4', this)">24</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: write the two forms of the mean relationship, and the average speed for equal distances at 30 km/h and 60 km/h.</p>
                <p>The answer: mean = total &divide; count, equivalently total = mean &times; count; and 2ab &divide; (a + b) = 3,600 &divide; 90 = 40 km/h.</p>
                <div id="fill-1">
                    <p>An average is a total divided by a <input type="text" class="fill-blank" data-answer="count" placeholder="?" aria-label="divisor in the mean" />, so the total equals the mean multiplied by the count. A combined mean from two groups of different sizes is called a <input type="text" class="fill-blank" data-answer="weighted" placeholder="?" aria-label="type of mean" /> mean, and it sits nearer the <input type="text" class="fill-blank" data-answer="larger" placeholder="?" aria-label="which group the mean sits near" /> group. For equal distances at 40 and 60 km/h the average speed is <input type="text" class="fill-blank" data-answer="48" placeholder="?" aria-label="average speed" /> km/h.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A data interpretation table shows three departments with average salaries of Rs 60,000 (40 staff), Rs 80,000 (25 staff) and Rs 100,000 (5 staff). A question asks for the overall average salary. Another asks whether the overall average is above or below Rs 80,000. Answer both without a calculator.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Exact answer: (40 &times; 60,000 + 25 &times; 80,000 + 5 &times; 100,000) &divide; 70 = (2,400,000 + 2,000,000 + 500,000) &divide; 70 = 4,900,000 &divide; 70 = <strong>Rs 70,000</strong>.</p>
                    <p>The comparison question is answered by shape, not arithmetic: 40 of the 70 staff sit in the Rs 60,000 department, so the weighted mean must be dragged to the low side — below 80,000, and in fact 70,000. The lever rule gives this in five seconds: the mean sits 40/70 of the way from 80,000 towards 60,000, which is a drop of about 11,400 from 80,000.</p>
                    <p>Note the distractor that this question is designed to catch: the unweighted average of 60,000, 80,000 and 100,000 is 80,000, which is the option for candidates who forget that departments differ in size.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You can now handle totals, weighted groups and average speed. The next lesson specialises that last idea into its own question family — distance, speed and time — which is one of the most reliably repeatable five-mark blocks in the quantitative section.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-ratio-proportion">Previous: Ratio, Proportion and Rate</a></span>
                <span><a href="/courses/hat/lessons/hat-rates-speed-distance">Next: Speed, Distance and Time</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
