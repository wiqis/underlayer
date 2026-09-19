// HAT course — Speed, distance and time: relative motion, trains and streams.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_rates_speed_distance() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Speed, Distance and Time — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Speed, Distance and Time</h1>
            <div class="lesson-meta">15 min · Module 2: Quantitative Reasoning · Rates</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Distance problems are the most predictable marks in the quantitative section. The question families are few — a single traveller, two travellers in opposite directions, a chase, a train crossing a platform, a boat on a river — and each has one standard setup. Learn the five setups and a whole block of questions stops requiring thought.</p>
                <p>They are also where unit mistakes are most expensive. An answer 18 times too big comes from mixing km/h with minutes, and it will always be one of the options.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>One equation governs everything in this family:</p>
                <div class="formula">distance = rate &times; time &nbsp;&nbsp;or&nbsp;&nbsp; rate = distance &divide; time &nbsp;&nbsp;or&nbsp;&nbsp; time = distance &divide; rate</div>
                <p>Write down the three quantities you know, in consistent units, then solve for the fourth. Ninety percent of mistakes here come from skipping the unit step, so make it a habit to write the unit beside every number before computing anything.</p>
                <p>The second idea is <strong>relative motion</strong>: when two objects move, only their relative speed matters, and it is the sum when they approach each other and the difference when one chases the other.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Unit conversions you must own</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Convert</th><th scope="col">Multiply by</th><th scope="col">Example</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>km/h to m/s</td><td>5 &divide; 18</td><td>54 km/h = 15 m/s</td></tr>
                        <tr><td>m/s to km/h</td><td>18 &divide; 5</td><td>20 m/s = 72 km/h</td></tr>
                        <tr><td>minutes to hours</td><td>&divide; 60</td><td>150 min = 2.5 h</td></tr>
                        <tr><td>km to m</td><td>&times; 1000</td><td>1.5 km = 1,500 m</td></tr>
                    </tbody>
                </table>
                <h3>The five standard setups</h3>
                <ol>
                    <li><strong>Single traveller.</strong> Pick the unknown, convert, apply distance = rate &times; time.</li>
                    <li><strong>Meeting.</strong> Two objects moving towards each other cover the whole gap at the sum of their speeds: time = gap &divide; (r&#8321; + r&#8322;).</li>
                    <li><strong>Chasing.</strong> The faster one closes the gap at the difference: time = gap &divide; (r&#8321; &minus; r&#8322;).</li>
                    <li><strong>Crossing.</strong> A train passing a pole covers its own length; passing a platform covers length + platform; passing another train covers the sum of both lengths.</li>
                    <li><strong>Streams.</strong> Downstream speed is still-water plus current; upstream is still-water minus current. So still-water = (down + up) &divide; 2 and current = (down &minus; up) &divide; 2.</li>
                </ol>
                <h3>Two patterns that turn hard questions into arithmetic</h3>
                <ul>
                    <li><strong>Equal distances at two speeds.</strong> The average speed is the harmonic mean 2ab &divide; (a + b), never the plain mean.</li>
                    <li><strong>Late and early.</strong> If two speeds give arrival times that differ by a known margin, the time difference equals (distance &divide; slower speed) &minus; (distance &divide; faster speed). That single equation yields the distance.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>Sketch before solving.</strong> A quick line with two arrows and the two speeds written on it removes more errors than any formula. For meeting and chasing questions the sketch also tells you immediately whether to add or subtract.
                </div>
                <div class="callout callout-warn">
                    <strong>The three classic traps.</strong> (1) Minutes left as minutes while speed is in km/h. (2) Forgetting that crossing a 200 m platform with a 100 m train means 300 m. (3) Averaging two speeds for equal distances — 30 and 60 give 40, not 45.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. A 120 m train travels at 54 km/h. How long does it take to cross a 180 m platform?</h3>
                <p>Convert first: 54 km/h = 54 &times; 5 &divide; 18 = 15 m/s. The distance covered from the moment the engine reaches the platform to the moment the last carriage leaves is 120 + 180 = 300 m. Time = 300 &divide; 15 = <strong>20 seconds</strong>.</p>
                <h3>2. Two towns are 180 km apart. A bus leaves one at 40 km/h and a car leaves the other at 50 km/h at the same time. When do they meet?</h3>
                <p>Approaching, so speeds add: 90 km/h. Time = 180 &divide; 90 = <strong>2 hours</strong>, so they meet 80 km from the bus's town.</p>
                <h3>3. A boat covers 12 km downstream in 1 hour and the same 12 km upstream in 2 hours. Find the still-water speed and the current.</h3>
                <p>Downstream speed = 12 km/h and upstream = 6 km/h. Still water = (12 + 6) &divide; 2 = <strong>9 km/h</strong>; current = (12 &minus; 6) &divide; 2 = <strong>3 km/h</strong>. Check: 9 + 3 = 12 downstream and 9 &minus; 3 = 6 upstream.</p>
                <h3>4. Walking at 4 km/h makes you 10 minutes late; at 5 km/h you arrive 5 minutes early. How far is the journey?</h3>
                <p>The time difference is 15 minutes, or 0.25 hours. Writing d for the distance: d &divide; 4 &minus; d &divide; 5 = 0.25, so d &divide; 20 = 0.25 and d = <strong>5 km</strong>. Check: 5 km at 4 km/h takes 75 minutes and at 5 km/h takes 60 minutes, a difference of 15 minutes.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>A car travels 150 km in 2 hours 30 minutes. What is its speed?</p>
                    <button class="quiz-option" data-correct="false" data-explain="75 km/h comes from dividing 150 by 2, ignoring the extra 30 minutes." onclick="checkQuiz('quiz-1', this)">75 km/h</button>
                    <button class="quiz-option" data-correct="true" data-explain="2 hours 30 minutes is 2.5 hours, and 150 &divide; 2.5 = 60 km/h. Converting minutes to hours is the entire question." onclick="checkQuiz('quiz-1', this)">60 km/h</button>
                    <button class="quiz-option" data-correct="false" data-explain="100 km/h would correspond to 1.5 hours; the unit conversion of 30 minutes to 0.5 hours is the key step." onclick="checkQuiz('quiz-1', this)">100 km/h</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A thief runs at 10 km/h, and a policeman starts 1 km behind at 12 km/h. How long until he catches up?</p>
                    <button class="quiz-option" data-correct="false" data-explain="10 km/h is one runner's speed, not the closing speed; chasing uses the difference of the speeds." onclick="checkQuiz('quiz-2', this)">1 hour</button>
                    <button class="quiz-option" data-correct="true" data-explain="Closing speed is 12 &minus; 10 = 2 km/h, and the gap is 1 km, so the catch takes half an hour." onclick="checkQuiz('quiz-2', this)">Half an hour</button>
                    <button class="quiz-option" data-correct="false" data-explain="Six minutes would close only 200 m at 2 km/h; the gap is 1 km." onclick="checkQuiz('quiz-2', this)">Six minutes</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>A train 200 m long crosses a pole in 10 seconds. What is its speed in km/h?</p>
                    <button class="quiz-option" data-correct="false" data-explain="20 m/s is the correct speed in metres per second, but the question asks for km/h, which needs multiplying by 18 and dividing by 5." onclick="checkQuiz('quiz-3', this)">20 km/h</button>
                    <button class="quiz-option" data-correct="true" data-explain="Crossing a pole covers the train's own length: 200 &divide; 10 = 20 m/s, and 20 &times; 18 &divide; 5 = 72 km/h." onclick="checkQuiz('quiz-3', this)">72 km/h</button>
                    <button class="quiz-option" data-correct="false" data-explain="40 km/h corresponds to about 11 m/s, which would take 18 seconds to clear the pole." onclick="checkQuiz('quiz-3', this)">40 km/h</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>A cyclist covers the first half of a journey at 10 km/h and the second half at 15 km/h. What is the average speed?</p>
                    <button class="quiz-option" data-correct="false" data-explain="12.5 is the plain mean of the two speeds, which is wrong because the slower half takes more time." onclick="checkQuiz('quiz-4', this)">12.5 km/h</button>
                    <button class="quiz-option" data-correct="true" data-explain="Equal distances at two speeds give the harmonic mean 2ab &divide; (a + b) = 300 &divide; 25 = 12 km/h." onclick="checkQuiz('quiz-4', this)">12 km/h</button>
                    <button class="quiz-option" data-correct="false" data-explain="13 km/h sits above the harmonic mean; the slower half always drags the average below the plain arithmetic mean." onclick="checkQuiz('quiz-4', this)">13 km/h</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: how do you convert km/h to m/s, and how do you combine the speeds of two objects moving towards each other?</p>
                <p>The answer: multiply by 5 and divide by 18; and add the speeds, because the gap closes at the sum of the rates.</p>
                <div id="fill-1">
                    <p>To convert km/h into m/s, multiply by <input type="text" class="fill-blank" data-answer="5" placeholder="?" aria-label="numerator of conversion" /> and divide by 18. Two objects approaching each other close the gap at the <input type="text" class="fill-blank" data-answer="sum" placeholder="?" aria-label="combination of approaching speeds" /> of their speeds, while a chase closes at the <input type="text" class="fill-blank" data-answer="difference" placeholder="?" aria-label="combination for chasing" />. A train crossing a pole covers its own <input type="text" class="fill-blank" data-answer="length" placeholder="?" aria-label="what a train covers crossing a pole" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A question says: "A man walks at 5 km/h for 2 hours, then cycles at 15 km/h for 40 minutes. What is his average speed for the whole journey?" Solve it, and name the wrong answer that the options will contain.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Distance on foot = 5 &times; 2 = 10 km. Distance cycled = 15 &times; (40 &divide; 60) = 15 &times; 2/3 = 10 km. Total distance 20 km; total time 2 hours 40 minutes = 8/3 hours. Average speed = 20 &divide; (8/3) = 20 &times; 3 &divide; 8 = <strong>7.5 km/h</strong>.</p>
                    <p>The expected distractor is 10 km/h, which is the plain mean of 5 and 15 — the trap for candidates who average the two speeds without weighting them by time. Because the two legs happen to cover equal distances here, the harmonic mean also gives 7.5, but the totals method is the one that works for every version of this question.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The equation distance = rate &times; time has a twin: work = rate &times; time. The next lesson applies exactly the same algebra to workers and pipes, where the trick is to convert every contributor into a fraction of the job per hour.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-averages">Previous: Averages and Weighted Means</a></span>
                <span><a href="/courses/hat/lessons/hat-work-rate">Next: Work, Pipes and Rates</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
