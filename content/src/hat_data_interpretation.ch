// HAT course — Concept 17: Data interpretation (tables, charts, graphs).
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_data_interpretation() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Tables, Charts and Graphs — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Tables, Charts and Graphs</h1>
            <div class="lesson-meta">16 min · Module 4: Analytical Reasoning · Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Data interpretation questions hand you a table or a chart and ask for a number, a comparison or a trend. The arithmetic is deliberately simple — mostly percentage change, share of total, and ratios — because the difficulty is meant to be in reading the display correctly, not in the calculation.</p>
                <p>That is also where candidates lose the marks. The wrong answers on these questions are not random; they are the results of specific, repeated misreadings. Once you know how the trap answers are built, you can often spot the correct option without computing all four of them.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Read the display before you read the question, and read the question before you compute.</p>
                <ol>
                    <li><strong>Check the axes and the units.</strong> Are the numbers in hundreds, thousands or millions? Does the vertical axis start at zero?</li>
                    <li><strong>Write down the totals</strong> if the display does not give them. Half the questions compare a part with a whole.</li>
                    <li><strong>Classify the question</strong> before calculating: percentage change, share of total, ratio, or trend.</li>
                    <li><strong>Estimate first, compute second.</strong> If the options are far apart, you only need an approximate value.</li>
                </ol>
                <p>Step three is what makes the section fast. Each question type has one formula and one characteristic wrong answer, and once you recognise the type you can predict the trap.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Percentage change divides by the original value, never the new one.</strong> This single point accounts for a large share of all errors in the section, because both computations produce plausible-looking numbers.</p>
                <div class="formula">percentage change = (new value &minus; old value) &divide; old value &times; 100</div>
                <p><strong>Share of total is a different question.</strong> If a department has 100 of 350 students, its share is 100/350, which has nothing to do with how much it grew. Questions are written to sit one next to the other precisely because candidates confuse them.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Question wording</th><th scope="col">Operation</th><th scope="col">Typical trap</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>By what percent did it increase?</td><td>change &divide; original</td><td>Dividing by the new value</td></tr>
                        <tr><td>What fraction of the total is it?</td><td>part &divide; whole</td><td>Using the previous year's total</td></tr>
                        <tr><td>How many times larger?</td><td>A &divide; B</td><td>Reporting the difference instead of the ratio</td></tr>
                        <tr><td>What percentage more than B is A?</td><td>(A &minus; B) &divide; B</td><td>Dividing by A</td></tr>
                    </tbody>
                </table>
                <p><strong>Read pie charts and axes with suspicion.</strong> A pie chart shows share, never absolute values, so it cannot answer a question about growth in numbers. A bar chart whose vertical axis does not start at zero exaggerates differences visually, and any conclusion drawn from the bars' relative heights alone is unsafe.</p>
                <p><strong>Percentages of percentages.</strong> If a figure falls 20% and then rises 20%, it has not returned to its starting point: 100 becomes 80, then 96. Falls and rises are computed on different bases, so they are never symmetrical.</p>
                <p><strong>Average, total and rate are three different things.</strong> A total divided by a number of years gives an average, which need not equal any single year's value and says nothing about the trend. Always check whether a question wants a total, an average, or a rate.</p>
                <div class="callout callout-warn">
                    <strong>Sanity-check the magnitude.</strong> A "percentage" larger than 100 is often correct in growth questions, but a share of a whole larger than 100% never is. If your answer violates the meaning of the quantity, the arithmetic is wrong even if the steps looked right.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>A university reports enrolment by department for two years.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Department</th><th scope="col">2024</th><th scope="col">2025</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Computer Science</td><td>120</td><td>150</td></tr>
                        <tr><td>Electrical Engineering</td><td>80</td><td>100</td></tr>
                        <tr><td>Mechanical Engineering</td><td>100</td><td>100</td></tr>
                    </tbody>
                </table>
                <p>First, write the totals that the table does not show: 300 in 2024 and 350 in 2025. Almost every question in the set uses them.</p>
                <p><strong>Which department grew fastest in percentage terms?</strong> Computer Science grew by 30 on a base of 120, which is 25%. Electrical Engineering grew by 20 on a base of 80, which is also 25%. Mechanical Engineering did not grow. The answer is therefore that the two are tied — and the trap answer is Computer Science, because it grew by the larger number. Absolute growth and percentage growth are different quantities, and the department with the bigger increase is not necessarily the one with the higher growth rate.</p>
                <p><strong>By what percentage did total enrolment rise?</strong> The change is 50 on an original of 300, so 50/300, which is 16.7%. The trap here is 50/350, which is 14.3% — the error of dividing by the new total. Both numbers are plausible, and only the formula tells you which is intended.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Using the table above, by what percentage did total enrolment rise from 2024 to 2025?</p>
                    <button class="quiz-option" data-correct="true" data-explain="The change is 50 and the original total is 300, so 50 divided by 300 is 16.7%. Percentage change always divides by the original value." onclick="checkQuiz('quiz-1', this)">16.7%</button>
                    <button class="quiz-option" data-correct="false" data-explain="14.3% is 50 divided by 350, the new total. That is the classic error of dividing by the wrong base." onclick="checkQuiz('quiz-1', this)">14.3%</button>
                    <button class="quiz-option" data-correct="false" data-explain="25% is the individual growth of two departments, not the rise in the total." onclick="checkQuiz('quiz-1', this)">25%</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Which department grew fastest in percentage terms?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Computer Science grew by more students, but 30 on a base of 120 is 25%, the same rate as Electrical Engineering." onclick="checkQuiz('quiz-2', this)">Computer Science</button>
                    <button class="quiz-option" data-correct="false" data-explain="Electrical Engineering also grew 25%, so it is not uniquely fastest." onclick="checkQuiz('quiz-2', this)">Electrical Engineering</button>
                    <button class="quiz-option" data-correct="true" data-explain="Both grew 25%, so the answer is a tie. The department with the larger absolute increase is the trap." onclick="checkQuiz('quiz-2', this)">They are tied</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>In 2025, what share of total enrolment is Mechanical Engineering?</p>
                    <button class="quiz-option" data-correct="false" data-explain="100 over 300 is the 2024 share. The question asks about 2025, whose total is 350." onclick="checkQuiz('quiz-3', this)">33.3%</button>
                    <button class="quiz-option" data-correct="true" data-explain="100 divided by the 2025 total of 350 gives 28.6%. Use the total for the year the question asks about." onclick="checkQuiz('quiz-3', this)">28.6%</button>
                    <button class="quiz-option" data-correct="false" data-explain="25% is the growth rate of the other two departments, not a share of the total." onclick="checkQuiz('quiz-3', this)">25%</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what is the formula for percentage change, and why does a 20% fall followed by a 20% rise not restore the original value?</p>
                <p>The answer is: change divided by the original value, times 100; and because the fall is computed on the original while the rise is computed on the reduced figure, so 100 becomes 80 and then 96.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>Percentage change is calculated by dividing the change by the <input type="text" class="fill-blank" data-answer="original" placeholder="?" aria-label="the base of a percentage change" /> value. A pie chart shows <input type="text" class="fill-blank" data-answer="share" placeholder="?" aria-label="what a pie chart shows" /> rather than absolute numbers. A bar chart whose vertical axis does not start at <input type="text" class="fill-blank" data-answer="zero" placeholder="?" aria-label="where the axis should start" /> exaggerates differences.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Take any table from a newspaper's business page, a textbook or your own university's results, and build four questions from it: one percentage change, one share of total, one ratio, and one trend. Then write the trap answer for each one.</p>
                <details>
                    <summary>Why writing the trap matters</summary>
                    <p>Anyone can compute from a table. The skill the paper rewards is recognising the wrong answer before you have finished the calculation, and the only way to build that recognition is to construct the traps yourself.</p>
                    <p>The traps follow the same short list every time. Divide by the new total instead of the original. Use the wrong year's total. Confuse absolute change with percentage change. Compare a part with the wrong whole. Report a difference where a ratio was asked for. Once you have written one of each, the options in the real paper start announcing themselves.</p>
                    <p>Two habits make the whole section cheap. Write the totals on the page before answering anything, because the questions are often chained and later ones reuse the same total. And estimate before computing — if two options are 16.7% and 14.3%, you must compute, but if they are 16.7% and 60%, a rough estimate is enough and saves the clock.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Data interpretation works with numbers on a page. The next concept works with sequences, where the numbers follow a rule that is not written down and your task is to state it: number and letter series.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-data-sufficiency">Previous: Data Sufficiency</a></span>
                <span><a href="/courses/hat/lessons/hat-pattern-series">Next: Number and Letter Series</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
