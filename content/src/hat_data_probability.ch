// HAT course — Concept 9: Data, averages and probability.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_data_probability() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Data, Averages and Probability — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Data, Averages and Probability</h1>
            <div class="lesson-meta">15 min · Module 2: Quantitative Reasoning · Data handling</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Data questions are the ones candidates rush. The arithmetic is easy, so the eyes move fast — and the two failures that follow are predictable: reading the wrong row of a table, and answering a question about the mean when it asked for the median. Both produce answers that look fine.</p>
                <p>Probability questions share the same reading risk. They are almost never computational beyond a single fraction, but they are always asking a precise question — "at least one" and "exactly one" are different questions, and only one of them is on the paper.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Split the work into two steps that cannot be skipped.</p>
                <ol>
                    <li><strong>Read.</strong> Identify the row, column, unit and year being asked about. Underline them if you have to.</li>
                    <li><strong>Compute.</strong> Only then choose a formula.</li>
                </ol>
                <p>For averages, remember that the three "measures of centre" — mean, median and mode — answer different questions and can differ by a lot. The mean of 1, 2, 3, 4 and 40 is 10; the median is 3. A question that mentions an outlier is usually a hint that the mean is not the measure being asked about.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Mean.</strong> Add the values and divide by how many there are. The mean of 4, 8, 10 and 14 is 36 / 4 = 9. Reversed, if the mean of five numbers is 12, their total is 12 x 5 = 60 — this reverse form answers many questions in one step.</p>
                <p><strong>Median.</strong> Sort the values first, then take the middle one. For 3, 7, 9, 11 and 15 the median is 9. With an even count, average the two middle values: for 3, 7, 9 and 11, the median is (7 + 9) / 2 = 8. Sorting first is not optional — the median of an unsorted list is the single most common careless error in this topic.</p>
                <p><strong>Mode and range.</strong> The mode is the most frequent value: in 2, 3, 3, 5, 7 it is 3. The range is the largest value minus the smallest: 15 - 3 = 12.</p>
                <p><strong>Reading tables and charts.</strong> Percentages from a table are computed against the correct total. If 40 of 200 respondents chose an option, that is 40 / 200 = 20 percent. Watch for tables whose final row is a total row, because including it in an average double-counts everything.</p>
                <p><strong>Simple interest.</strong> Interest equals principal times rate times time, with the rate written as a decimal. On 5,000 at 8 percent for 2 years: 5000 x 0.08 x 2 = 800 of interest, so the amount is 5,800.</p>
                <p><strong>Probability as a fraction.</strong> Work out the favourable outcomes and the total equally likely outcomes, then write the fraction.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Situation</th><th scope="col">Favourable</th><th scope="col">Total</th><th scope="col">Probability</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>An even number on a fair die</td><td>2, 4, 6 (three)</td><td>6</td><td>3/6 = 1/2</td></tr>
                        <tr><td>A heart from a full deck</td><td>13</td><td>52</td><td>13/52 = 1/4</td></tr>
                        <tr><td>Two heads from two fair coins</td><td>HH (one)</td><td>HH, HT, TH, TT (four)</td><td>1/4</td></tr>
                    </tbody>
                </table>
                <p><strong>Independent events multiply.</strong> The probability of two independent things both happening is the product: a head then a head is 1/2 x 1/2 = 1/4.</p>
                <div class="callout callout-tip">
                    <strong>"At least one" is easier upside down.</strong> The probability of at least one head from two coins is 1 minus the probability of no heads, that is 1 - 1/4 = 3/4. Doing it directly means adding the cases; doing it upside down means one subtraction.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>A class of 40 students sits a test. The marks are grouped as follows.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Marks</th><th scope="col">Number of students</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>40 to 49</td><td>4</td></tr>
                        <tr><td>50 to 59</td><td>10</td></tr>
                        <tr><td>60 to 69</td><td>16</td></tr>
                        <tr><td>70 to 79</td><td>8</td></tr>
                        <tr><td>80 to 89</td><td>2</td></tr>
                    </tbody>
                </table>
                <p>First, a count check: 4 + 10 + 16 + 8 + 2 = 40, which matches the stated class size. Doing this check takes three seconds and catches a misread cell before it becomes a wrong answer.</p>
                <p><em>What percentage of students scored 60 or above?</em> That is the 16 + 8 + 2 = 26 students in the top three bands, so 26 / 40 = 0.65, which is 65 percent.</p>
                <p><em>What is the modal band?</em> The highest frequency is 16, which sits in the 60 to 69 band. Note that the mode is the most frequent <em>band</em>; if the question instead asked for the median band, the median is the 20th and 21st student in order, and cumulative counts (4, then 14, then 30) place both inside the 60 to 69 band as well.</p>
                <p><em>If a student is picked at random, what is the probability that they scored below 50?</em> Four students of 40, so 4 / 40 = 1/10.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What is the median of 3, 7, 9 and 11?</p>
                    <button class="quiz-option" data-correct="false" data-explain="9 is the mean of 3, 7, 9, 11 and 15. The median of 3, 7, 9 and 11 is the average of the two middle values." onclick="checkQuiz('quiz-1', this)">9</button>
                    <button class="quiz-option" data-correct="true" data-explain="With an even count, average the two middle values: (7 + 9) / 2 = 8." onclick="checkQuiz('quiz-1', this)">8</button>
                    <button class="quiz-option" data-correct="false" data-explain="7.5 is the mean of the list, not the median. The question asks for the middle value." onclick="checkQuiz('quiz-1', this)">7.5</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A fair die is rolled once. What is the probability of an even number?</p>
                    <button class="quiz-option" data-correct="true" data-explain="There are three favourable outcomes (2, 4, 6) out of six, so 3/6 reduces to 1/2." onclick="checkQuiz('quiz-2', this)">1/2</button>
                    <button class="quiz-option" data-correct="false" data-explain="1/6 is the probability of one specific number, not of any even number." onclick="checkQuiz('quiz-2', this)">1/6</button>
                    <button class="quiz-option" data-correct="false" data-explain="1/3 would be correct only if two of the six faces were even." onclick="checkQuiz('quiz-2', this)">1/3</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>The mean of five numbers is 12. What can you say about them?</p>
                    <button class="quiz-option" data-correct="false" data-explain="60 is the total of the five numbers, not their mean. Divide by the count." onclick="checkQuiz('quiz-3', this)">60</button>
                    <button class="quiz-option" data-correct="false" data-explain="15 is the range if the numbers span 3 to 15; the question gives a mean and a count, not a list." onclick="checkQuiz('quiz-3', this)">15</button>
                    <button class="quiz-option" data-correct="true" data-explain="Mean times count gives the total: 12 x 5 = 60, so the sum of the five numbers is 60." onclick="checkQuiz('quiz-3', this)">The sum of the five numbers is 60</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what must you do to a list before finding its median, and how do you compute "at least one" probability quickly?</p>
                <p>The answer is: sort the list first, and for an even count average the two middle values. For "at least one", subtract the probability of none from 1.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>The mean of 4, 8, 10 and 14 is <input type="text" class="fill-blank" data-answer="9" placeholder="?" aria-label="mean" />. If the mean of five numbers is 12, their total is <input type="text" class="fill-blank" data-answer="60" placeholder="?" aria-label="total" />. The probability of getting at least one head when two fair coins are tossed is <input type="text" class="fill-blank" data-answer="3/4" placeholder="?" aria-label="at least one head" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>In a survey of 250 people, 60 percent said they read news online, and of those, one third also read a printed newspaper. How many people read both, and how many read neither online news nor print?</p>
                <details>
                    <summary>Show the worked solution</summary>
                    <p>Online readership is 60 percent of 250, which is 150 people. One third of those, 150 / 3 = 50 people, also read print. So 50 people read both.</p>
                    <p>Now the harder half of the question, which needs a decision rather than a computation. Of the 250 people, 150 read online, so 100 do not. Among those 100, the question's wording — one third <em>of those who read online</em> read print too — says nothing about print-only readers, so the number who read neither cannot be determined from the information given. If an option says "cannot be determined", that is very often the correct answer to a question shaped like this one, and choosing it is a mark earned by reading precisely rather than by calculating.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>That completes the quantitative section: arithmetic, percentages, ratio, algebra, geometry and data. Every one of those techniques is tested through <em>words</em>, which is why the next module matters.</p>
                <p>Verbal Reasoning begins with the part of English that the HAT tests most predictably and that improves fastest with study: vocabulary. It carries marks in every category of the test, and it feeds the grammar, sentence-completion and reading sections that follow.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-geometry">Previous: Geometry and Measurement</a></span>
                <span><a href="/courses/hat/lessons/hat-vocabulary">Next: Vocabulary You Can Actually Learn</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
