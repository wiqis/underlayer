// HAT course — Concept 8: Geometry and measurement.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_geometry() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Geometry and Measurement — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Geometry and Measurement</h1>
            <div class="lesson-meta">16 min · Module 2: Quantitative Reasoning · Core technique</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Geometry questions fail differently from arithmetic questions. An arithmetic slip usually produces an answer that is not among the options, so you notice. A geometry question answered with the circumference formula instead of the area formula, or with metres instead of square metres, produces a perfectly plausible number that happens to be wrong — and there is no internal signal to catch it.</p>
                <p>The defence is a small set of formulas you know exactly, plus a unit check on every answer. Those two habits cover nearly every geometry question on the paper.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Organise geometry into three questions, asked in this order:</p>
                <ol>
                    <li><strong>What shape is it?</strong> The shape names the formulas.</li>
                    <li><strong>Is it one dimension, two dimensions or three?</strong> One dimension gives a length (units), two give an area (square units), three give a volume (cubic units).</li>
                    <li><strong>Is a right angle present?</strong> If yes, Pythagoras is available; if not, look for similar triangles.</li>
                </ol>
                <p>The unit question is the cheapest error check available. If a question about painting a wall produces an answer in metres, you used a perimeter formula, and you can see that in one second.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Angles.</strong> Angles on a straight line add to 180 degrees; around a point they add to 360 degrees; the three angles of any triangle add to 180 degrees. When a question gives angles as multiples of x, write the sum as an equation: if the angles are 3x, 2x and 4x, then 9x = 180, so x = 20 and the angles are 60, 40 and 80 degrees.</p>
                <p><strong>Triangles.</strong> Area is one half times base times height: for a base of 12 and a height of 5, the area is 30 square units. Note that the height must be perpendicular to the base, not one of the slanted sides.</p>
                <p><strong>Pythagoras.</strong> In a right triangle, the square on the hypotenuse equals the sum of the squares on the other two sides. With legs 9 and 12: 81 + 144 = 225, so the hypotenuse is 15. The standard triples — 3, 4, 5 and its multiples 6, 8, 10 and 9, 12, 15 — appear constantly; recognising them saves the calculation.</p>
                <p><strong>Rectangles and squares.</strong> For a rectangle 14 by 9, the area is 126 square units and the perimeter is 2 x (14 + 9) = 46 units. For a square, area is the side squared and perimeter is four times the side.</p>
                <p><strong>Circles.</strong> Circumference is two pi r and area is pi r squared. With the common instruction to take pi as 22/7 and a radius of 7: circumference is 2 x 22/7 x 7 = 44, and area is 22/7 x 49 = 154.</p>
                <p><strong>Trapezium.</strong> Area is the average of the parallel sides times the height. With parallel sides 8 and 12 and a height of 5, the average is 10 and the area is 50.</p>
                <p><strong>Volume.</strong> A cube of side 4 has volume 64 and surface area 6 x 16 = 96. A cylinder of radius 7 and height 10 has volume 22/7 x 49 x 10 = 1540 cubic units.</p>
                <div class="callout callout-warn">
                    <strong>The diameter trap.</strong> Questions often give the diameter and ask for the area or circumference. Halve it first. A diameter of 14 is a radius of 7, and using 14 in pi r squared would quadruple the area.
                </div>
                <div class="callout callout-tip">
                    <strong>Similar shapes scale by the square.</strong> If every length in a shape is multiplied by 3, the area is multiplied by 9 and the volume by 27. Recognising this turns some multi-step questions into a single multiplication.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><em>A rectangular field is 40 metres by 30 metres. A path of uniform width 2 metres runs around the inside edge. A farmer wants to fence the entire outer boundary. What length of fencing is needed, and what area does the path occupy?</em></p>
                <p>Fencing is a perimeter, so one dimension: 2 x (40 + 30) = 140 metres.</p>
                <p>The path is an area, so two dimensions. The inner rectangle, excluding the path, is 40 - 2 - 2 = 36 metres by 30 - 2 - 2 = 26 metres. Its area is 36 x 26 = 936 square metres, and the whole field is 40 x 30 = 1200 square metres. The path occupies 1200 - 936 = 264 square metres.</p>
                <p>Two checks worth making. First, the units differ correctly between the two answers — metres for fencing, square metres for the path — which confirms both formulas were the right kind. Second, an estimate: the path is roughly a band of area (140 x 2) minus the four corner squares that get counted twice, which is 280 - 16 = 264. The estimate matches exactly, because it is the same computation arranged the other way.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>A right triangle has legs of 9 and 12. How long is the hypotenuse?</p>
                    <button class="quiz-option" data-correct="true" data-explain="81 + 144 = 225, and the square root of 225 is 15. This is the 3, 4, 5 triple scaled by 3." onclick="checkQuiz('quiz-1', this)">15</button>
                    <button class="quiz-option" data-correct="false" data-explain="21 comes from adding the legs, which has nothing to do with a right triangle's hypotenuse." onclick="checkQuiz('quiz-1', this)">21</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the square of the hypotenuse, not the hypotenuse itself. Take the square root." onclick="checkQuiz('quiz-1', this)">225</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Taking pi as 22/7, what is the circumference of a circle of radius 7?</p>
                    <button class="quiz-option" data-correct="false" data-explain="154 is the area of the circle with radius 7; the circumference is the distance around it." onclick="checkQuiz('quiz-2', this)">154</button>
                    <button class="quiz-option" data-correct="true" data-explain="2 x 22/7 x 7 = 44. Circumference is two pi r." onclick="checkQuiz('quiz-2', this)">44</button>
                    <button class="quiz-option" data-correct="false" data-explain="This would use the diameter 14 as the radius, and it also mixes the two formulas." onclick="checkQuiz('quiz-2', this)">88</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>A triangle's angles are 3x, 2x and 4x. What is the largest angle?</p>
                    <button class="quiz-option" data-correct="false" data-explain="The angles are 3x, 2x and 4x, so 9x = 180. Dividing 180 by 3 alone would solve a different equation." onclick="checkQuiz('quiz-3', this)">60 degrees</button>
                    <button class="quiz-option" data-correct="true" data-explain="9x = 180 gives x = 20, so the angles are 60, 40 and 80. The largest is 80 degrees." onclick="checkQuiz('quiz-3', this)">80 degrees</button>
                    <button class="quiz-option" data-correct="false" data-explain="100 comes from taking x = 25 rather than 20; 3x would then be 75, 2x would be 50 and 4x would be 100, summing to 225 instead of 180." onclick="checkQuiz('quiz-3', this)">100 degrees</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: how do you tell an area question from a perimeter question, and what does a right angle let you use?</p>
                <p>The answer is: ask whether the answer should be in single units (a length, perimeter or circumference) or square units (an area). A right angle allows Pythagoras — or recognition of a 3, 4, 5 style triple.</p>
                <p>Fill in the blanks from memory:</p>
                <div id="fill-1">
                    <p>A triangle with base 12 and perpendicular height 5 has area <input type="text" class="fill-blank" data-answer="30" placeholder="?" aria-label="triangle area" /> square units. A rectangle 14 by 9 has perimeter <input type="text" class="fill-blank" data-answer="46" placeholder="?" aria-label="perimeter" />. A cuboid measuring 2 by 3 by 5 has volume <input type="text" class="fill-blank" data-answer="30" placeholder="?" aria-label="volume" /> cubic units.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A cylindrical water tank has a diameter of 14 metres and a height of 10 metres. You need to paint the curved side only. What area must be painted, using pi as 22/7?</p>
                <details>
                    <summary>Show the worked solution</summary>
                    <p>The curved side of a cylinder unrolls into a rectangle whose width is the circumference and whose height is the cylinder's height. The diameter is 14, so the radius is 7, and the circumference is 2 x 22/7 x 7 = 44 metres. The height is 10 metres, so the area is 44 x 10 = 440 square metres.</p>
                    <p>Two traps are deliberately built into this question. The first is the diameter: using 14 as the radius would give 880 square metres, double the right answer, and 880 is a plausible-looking option. The second is "curved side only" — including the two circular ends would add 2 x 154 = 308 square metres, which is the answer to a question that was not asked. Both errors are avoided by writing down what the question wants before choosing a formula.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Geometry works with exact figures you are given. The final quantitative lesson works with data you have to read: tables, charts and summaries, along with the everyday probability questions that usually share those passages. It is the section where careful reading pays more than calculation.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-algebra">Previous: Algebra Without Fear</a></span>
                <span><a href="/courses/hat/lessons/hat-data-probability">Next: Data, Averages and Probability</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
