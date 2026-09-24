// HAT course — Concept 6: Ratio, proportion and rate.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_ratio_proportion() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Ratio, Proportion and Rate — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Ratio, Proportion and Rate</h1>
            <div class="lesson-meta">15 min · Module 2: Quantitative Reasoning · Core technique</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Word problems about sharing, mixing, working together, or travelling all reduce to one idea: how a change in one quantity moves another. Candidates who cannot tell direct proportion from inverse proportion will produce a confident, wrong answer in the same number of seconds as the right one — which is why this distinction is tested so often.</p>
                <p>The second half of the value here is arithmetic hygiene. Ratio questions hide a step — turning a ratio into parts — and skipping it is how 3-part questions become 2-part mistakes.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A ratio is a <em>recipe</em>. The ratio 2 : 3 : 4 does not say the quantities are 2, 3 and 4; it says they are 2 parts, 3 parts and 4 parts. Convert to real quantities in two steps:</p>
                <div class="formula">total parts = sum of the ratio terms, then one part = total divided by total parts</div>
                <p>Proportion is the statement that two ratios are equal, and it answers "if this scales, what does that become". The only decision is the <em>direction</em> of the scaling:</p>
                <ul>
                    <li><strong>Direct:</strong> more of one means more of the other. More hours worked, more pay. More kilometres, more fuel.</li>
                    <li><strong>Inverse:</strong> more of one means less of the other. More workers, fewer days. Faster speed, less time.</li>
                </ul>
                <p>Inverse proportion is where most errors happen, so make the check explicit: if the answer you computed moves in the same direction as the input you changed, you have used the wrong rule.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Splitting a quantity.</strong> Divide 4500 in the ratio 2 : 3 : 4. The terms total 9 parts, so one part is 4500 / 9 = 500. The shares are 1000, 1500 and 2000. Always verify: 1000 + 1500 + 2000 = 4500, and the shares keep the ratio when divided by 500.</p>
                <p><strong>Simplifying.</strong> Divide both terms by their highest common factor. 24 : 36 becomes 2 : 3. Keep ratios in whole numbers where you can; decimals in a ratio usually mean a step was missed.</p>
                <p><strong>Direct proportion.</strong> Set up a proportion and cross-multiply. If 3 identical pens cost 120, what do 7 cost? One pen is 40, so 7 cost 280. The cross-multiplied check: 3 / 120 = 7 / 280, both equal 0.025.</p>
                <p><strong>Inverse proportion.</strong> Use the product, not the ratio. If 12 workers build a wall in 10 days, the job is 12 x 10 = 120 worker-days. With 15 workers it takes 120 / 15 = 8 days. The sanity check is the direction: more workers, fewer days.</p>
                <p><strong>Rate problems.</strong> A rate is a ratio with different units. At 60 kilometres per hour, a distance of 120 kilometres takes 2 hours, and 90 minutes is 1.5 hours, so the same rate covers 90 kilometres. Convert time to hours before multiplying — the most common slip here is treating 90 minutes as 0.9 hours.</p>
                <p><strong>Mixtures.</strong> Track the <em>amount of the substance</em>, not the percentage. Forty litres of a solution that is 20 percent salt contains 20 percent of 40, that is 8 litres of salt. Add 10 litres of water and the solution is 50 litres, but the salt is still 8 litres, so it is now 8 / 50 = 16 percent.</p>
                <p><strong>Combining two mixtures</strong> is a weighted average. Mix 2 parts of a 30 percent solution with 3 parts of a 20 percent solution: the salt is 2 &times; 30 + 3 &times; 20 = 120 parts against 5 parts of solution, giving 120 / 5 = 24 percent.</p>
                <p><strong>A full mixture, step by step.</strong> A 60-litre mixture is 40 percent acid. How much water must be added to turn it into a 25 percent solution? Track acid, never the percentage. Acid now: 40 percent of 60 = 24 litres. Water does not change the acid, so after adding w litres the acid is still 24 and the total is 60 + w. Set 24 / (60 + w) = 0.25, so 60 + w = 96 and w = 36 litres. Check: 24 / 96 = 0.25. The same layout works when a stronger solution is mixed in instead of water — only the acid term changes.</p>
                <div class="callout callout-warn">
                    <strong>Wrong-direction answer.</strong> More workers on a fixed job must mean <em>fewer</em> days; a bigger map scale number must mean a <em>smaller</em> map distance; a diluted mixture must be <em>weaker</em>, not stronger. Before you write the answer, name how it should move when the input moves. If your arithmetic moved it the other way, you used the direct rule on an inverse problem (or divided by the wrong part), and recomputing with the same rule will only confirm the error. Fix the rule first, then recompute.
                </div>
                <div class="callout callout-tip">
                    <strong>The one-line test for direction.</strong> Ask which way your answer must move. "More workers means fewer days" or "more workers means more days"? If your arithmetic moves the answer the wrong way, you have inverted the proportion, and no amount of recomputation will fix a wrong rule.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>A map uses a scale of 1 to 50,000. Two towns are 3 centimetres apart on the map. What is the real distance in kilometres?</em></p>
                <p>Step 1, the direction: a bigger distance on the map means a bigger real distance, so this is direct proportion. One centimetre on the map represents 50,000 centimetres in reality, so 3 centimetres represent 150,000 centimetres.</p>
                <p>Step 2, the units: 150,000 centimetres is 1,500 metres, which is 1.5 kilometres. The unit conversion is where most candidates lose the mark, not the proportion.</p>
                <p>Now the same question as an inverse case. If the map scale were 1 to 100,000 and the real distance were 1.5 kilometres, the map distance would be smaller: 150,000 centimetres in reality divided by 100,000 gives 1.5 centimetres on the map. Same three numbers, opposite direction, and the sanity check — a larger scale number means a smaller map distance — catches the error before the answer is written down.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>Divide 4500 in the ratio 2 : 3 : 4.</p>
                    <button class="quiz-option" data-correct="true" data-explain="Nine parts total, so one part is 500. The shares are 2 x 500, 3 x 500 and 4 x 500: 1000, 1500 and 2000." onclick="checkQuiz('quiz-1', this)">1000, 1500 and 2000</button>
                    <button class="quiz-option" data-correct="false" data-explain="These numbers are in the ratio 2 : 3 : 4 but they total 2250, not 4500. The parts step was skipped." onclick="checkQuiz('quiz-1', this)">500, 750 and 1000</button>
                    <button class="quiz-option" data-correct="false" data-explain="Dividing 4500 by 3 gives 1500 apiece, which is an equal split and ignores the ratio entirely." onclick="checkQuiz('quiz-1', this)">1500, 1500 and 1500</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>If 12 workers build a wall in 10 days, how long will 15 workers take?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This is direct proportion, which would mean more workers need more days. It ignores that the job is a fixed amount of work." onclick="checkQuiz('quiz-2', this)">16 days</button>
                    <button class="quiz-option" data-correct="true" data-explain="The job is 12 x 10 = 120 worker-days. With 15 workers: 120 / 15 = 8 days. More workers, fewer days." onclick="checkQuiz('quiz-2', this)">8 days</button>
                    <button class="quiz-option" data-correct="false" data-explain="10 days is the original figure and takes no account of the extra workers." onclick="checkQuiz('quiz-2', this)">10 days</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Forty litres of a solution is 20 percent salt. After adding 10 litres of water, what is the salt concentration?</p>
                    <button class="quiz-option" data-correct="false" data-explain="20 percent is the salt concentration before the water was added; dilution must lower it." onclick="checkQuiz('quiz-3', this)">20%</button>
                    <button class="quiz-option" data-correct="true" data-explain="Salt stays at 8 litres while the solution grows to 50 litres: 8 / 50 = 16 percent." onclick="checkQuiz('quiz-3', this)">16%</button>
                    <button class="quiz-option" data-correct="false" data-explain="10 percent would require the salt to fall as well. Adding water changes the total volume, not the amount of salt." onclick="checkQuiz('quiz-3', this)">10%</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what is the difference between direct and inverse proportion, and which one applies when more workers join a fixed job?</p>
                <p>The answer is: in direct proportion both quantities grow together; in inverse proportion one grows as the other falls. A fixed job is inverse proportion, so more workers means fewer days.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>Dividing 4500 in the ratio 2 : 3 : 4 means the parts total 9, so one part is <input type="text" class="fill-blank" data-answer="500" placeholder="?" aria-label="one part" />. If 12 workers take 10 days, the job is <input type="text" class="fill-blank" data-answer="120" placeholder="?" aria-label="worker-days" /> worker-days, so 15 workers take 8 days. A solution of 40 litres that is 20 percent salt contains 8 litres of salt, and after adding 10 litres of water it is <input type="text" class="fill-blank" data-answer="16" placeholder="?" aria-label="new concentration percent" /> percent salt.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A recipe for 4 people uses 300 grams of rice and 200 grams of lentils. You must cook for 10 people and you want to keep the ratio. You have 800 grams of rice and 450 grams of lentils. What is the minimum you can cook for, and which ingredient limits you?</p>
                <details>
                    <summary>Show the worked solution</summary>
                    <p>Scale the recipe by 10 / 4 = 2.5: the exact amounts needed are 750 grams of rice and 500 grams of lentils. You have enough rice (800 is more than 750) but not enough lentils (450 is less than 500). So the limiting ingredient is the lentils.</p>
                    <p>To find how many people you can actually cater for, invert the ratio from the lentils: 450 grams supports 450 / 200 = 2.25 times the original recipe, which is 2.25 x 4 = 9 people. Check the rice at that scale: 2.25 x 300 = 675 grams, which fits inside the 800 available, so the lentils remain the limit.</p>
                    <p>The reasoning pattern to keep — scale by a factor, compare both ingredients, then identify the binding constraint — is the same pattern used in every ratio-and-capacity question, whatever the units.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Ratios compare quantities that are already known. The next lesson handles the summary of a group: the average, the weighted average, and the mixture. It is where ratio reasoning pays off directly, because a weighted mean is just a ratio in disguise.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-percentages">Previous: Percentages and Percentage Change</a></span>
                <span><a href="/courses/hat/lessons/hat-averages">Next: Averages and Weighted Means</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
