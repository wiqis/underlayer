// HAT course — Concept 19: Physics and mechanics for engineering candidates.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_physics_mechanics() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Physics and Mechanics for Engineering Candidates — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Physics and Mechanics for Engineering Candidates</h1>
            <div class="lesson-meta">20 min · Module 5: Subject — Engineering and Computing · Foundation</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The subject portion of HAT-1 is where the test stops being general and starts being about the degree you are applying for. For most engineering and computing candidates it is drawn from first-year physics and mathematics, which means the content is not new — it is the material from your intermediate or A-level course.</p>
                <p>The difficulty is not conceptual. It is that a test gives you about a minute per question, and formulae you last used years ago are not recalled in a minute. This lesson is about the small number of relations that cover most numerical questions, and about avoiding the unit errors that produce a plausible wrong answer.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Nearly every mechanics numerical follows this three-step pattern.</p>
                <ol>
                    <li><strong>List the given quantities with their symbols</strong> — u, v, a, t, s, m, F, W, P.</li>
                    <li><strong>Find the equation that contains those symbols</strong> and the one you are asked for.</li>
                    <li><strong>Convert to SI units before substituting,</strong> and check that the answer's unit matches the quantity.</li>
                </ol>
                <p>Step three is not bookkeeping. A large fraction of wrong options in the subject portion are the result of mixing grams with kilograms or centimetres with metres, and the option set usually contains that value.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Kinematics</strong> for motion in a straight line with constant acceleration.</p>
                <div class="formula">v = u + at &nbsp;&nbsp;·&nbsp;&nbsp; s = ut + &frac12;at&sup2; &nbsp;&nbsp;·&nbsp;&nbsp; v&sup2; = u&sup2; + 2as</div>
                <p>Pick the equation that omits the quantity you neither know nor need. In projectile questions, horizontal and vertical motion are treated independently: the horizontal velocity is constant, and the vertical motion is uniformly accelerated by gravity with g taken as 9.8 m/s&sup2;, or 10 in questions that say so.</p>
                <p><strong>Newton's laws.</strong> The first says a body stays at rest or in uniform motion unless a resultant force acts. The second gives the quantitative relation.</p>
                <div class="formula">F = ma &nbsp;&nbsp;·&nbsp;&nbsp; weight = mg &nbsp;&nbsp;·&nbsp;&nbsp; friction &le; &mu;N</div>
                <p>The third says forces come in equal and opposite pairs acting on different bodies — and a favourite exam trap is a question about a horse pulling a cart or a person pushing a wall, where the pair being described acts on two separate objects and therefore cannot cancel for either one of them.</p>
                <p><strong>Work, energy and power.</strong></p>
                <div class="formula">W = Fs cos&theta; &nbsp;&nbsp;·&nbsp;&nbsp; KE = &frac12;mv&sup2; &nbsp;&nbsp;·&nbsp;&nbsp; PE = mgh &nbsp;&nbsp;·&nbsp;&nbsp; P = W / t</div>
                <p>Mechanical energy is conserved when only conservative forces act, which is the assumption behind most energy questions. Note that work done perpendicular to the motion is zero, so a force carrying an object horizontally does no work against gravity.</p>
                <p><strong>Momentum and impulse.</strong></p>
                <div class="formula">p = mv &nbsp;&nbsp;·&nbsp;&nbsp; impulse = F&Delta;t = &Delta;p</div>
                <p>Momentum is conserved in collisions and explosions when external forces are negligible. Elastic collisions also conserve kinetic energy; inelastic ones do not, which is the distinction most collision questions are really testing.</p>
                <p><strong>Electricity, the other large area.</strong></p>
                <div class="formula">V = IR &nbsp;&nbsp;·&nbsp;&nbsp; P = VI &nbsp;&nbsp;·&nbsp;&nbsp; P = I&sup2;R &nbsp;&nbsp;·&nbsp;&nbsp; resistances in series add, in parallel they add as reciprocals</div>
                <p><strong>Units to keep straight.</strong> Force in newtons, energy and work in joules, power in watts, charge in coulombs, potential difference in volts, resistance in ohms, frequency in hertz. Prefixes are a common source of error: 1 kN is 1000 N, 1 mJ is 0.001 J, and 1 &mu;m is 10&#8315;&#8309; m.</p>
                <div class="callout callout-tip">
                    <strong>Dimensional check.</strong> If the answer you computed is meant to be a velocity and its unit works out to m/s&sup2;, you have used the wrong equation or dropped a term. The check costs a few seconds and catches errors that no amount of re-arithmetic would.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>A car starts from rest and accelerates uniformly at 2 m/s&sup2; for 5 seconds. How far does it travel?</em></p>
                <p>List the givens: u = 0 (starting from rest), a = 2 m/s&sup2;, t = 5 s. You are asked for s, and v is unknown and not required. The equation that contains u, a, t and s, and omits v, is s = ut + &frac12;at&sup2;.</p>
                <p>Substituting: s = 0 &times; 5 + &frac12; &times; 2 &times; 25, which is 25 m.</p>
                <p>Notice what the third step of the method would have caught. If the accelerations had been given in km/h&sup2; or the time in minutes, the substitution would have produced a number in the same magnitude but with the wrong unit, and the option set would very likely contain it. Converting first, and asking "is 25 in metres a sensible stopping distance for these inputs?", is what separates the correct option from the trap.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>A car starting from rest accelerates at 2 m/s&sup2; for 5 s. What is its final velocity?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Using v equals u plus at: 0 plus 2 times 5 is 10 m/s." onclick="checkQuiz('quiz-1', this)">10 m/s</button>
                    <button class="quiz-option" data-correct="false" data-explain="50 m/s would come from multiplying the acceleration by the square of the time, which is not what v = u + at says." onclick="checkQuiz('quiz-1', this)">50 m/s</button>
                    <button class="quiz-option" data-correct="false" data-explain="5 m/s treats the acceleration as 1 m/s squared, ignoring the given value of 2." onclick="checkQuiz('quiz-1', this)">5 m/s</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A force acts on a 4 kg mass and produces an acceleration of 3 m/s&sup2;. What is the force?</p>
                    <button class="quiz-option" data-correct="false" data-explain="That would be dividing mass by acceleration. Newton's second law multiplies them: F = ma." onclick="checkQuiz('quiz-2', this)">1.33 N</button>
                    <button class="quiz-option" data-correct="true" data-explain="F equals ma: 4 times 3 is 12 N." onclick="checkQuiz('quiz-2', this)">12 N</button>
                    <button class="quiz-option" data-correct="false" data-explain="7 N adds the numbers instead of multiplying them; mass and acceleration are multiplied in F = ma." onclick="checkQuiz('quiz-2', this)">7 N</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>A 12 V supply is connected across a 4 ohm resistor. What current flows?</p>
                    <button class="quiz-option" data-correct="false" data-explain="48 A multiplies volts by ohms. Ohm's law divides voltage by resistance." onclick="checkQuiz('quiz-3', this)">48 A</button>
                    <button class="quiz-option" data-correct="true" data-explain="From V = IR, the current is V divided by R, so 12 divided by 4 is 3 A." onclick="checkQuiz('quiz-3', this)">3 A</button>
                    <button class="quiz-option" data-correct="false" data-explain="0.33 A inverts the ratio. Current is voltage divided by resistance, not resistance divided by voltage." onclick="checkQuiz('quiz-3', this)">0.33 A</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: which kinematics equation omits v, and what does the work-energy relation say about a force perpendicular to the displacement?</p>
                <p>The answer is: s = ut + &frac12;at&sup2;; and a perpendicular force does no work, because work depends on the component of force along the displacement, so cos 90&deg; is zero.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>The SI unit of force is the <input type="text" class="fill-blank" data-answer="newton" placeholder="?" aria-label="SI unit of force" />, and the SI unit of power is the <input type="text" class="fill-blank" data-answer="watt" placeholder="?" aria-label="SI unit of power" />. Kinetic energy is given by one half times mass times <input type="text" class="fill-blank" data-answer="velocity squared" placeholder="?" aria-label="second factor in kinetic energy" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Take five numerical questions from your intermediate physics paper and solve them using the three-step method: list the givens, choose the equation that omits the unwanted quantity, convert to SI before substituting.</p>
                <details>
                    <summary>What to watch for while you practise</summary>
                    <p>Time yourself. The point of the exercise is not accuracy on untimed work, which you already have, but recall speed under a minute per question.</p>
                    <p>Keep a list of the mistakes you make, and expect them to cluster in two places. The first is unit conversion, particularly grams to kilograms and centimetres to metres. The second is choosing the wrong kinematics equation, which usually means a quantity you did not need was treated as known. Both are mechanical, and both disappear after a handful of repetitions.</p>
                    <p>Finally, write the formula down before substituting numbers. Candidates who substitute directly from the question tend to reach the options without a record of what they did, so when the answer is not among the options there is nothing to check. A written equation gives you a one-line audit.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Physics covers the mechanics questions. The next concept turns to computing, where a different set of basics is tested — number systems, logic and the fundamentals of how programs are structured.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-pattern-series">Previous: Number and Letter Series</a></span>
                <span><a href="/courses/hat/lessons/hat-programming-fundamentals">Next: Computing Fundamentals</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
