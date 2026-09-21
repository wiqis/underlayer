// HAT course  -  Mensuration: perimeter, area, surface area and volume of standard shapes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_mensuration() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Mensuration: Perimeter, Area and Volume - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Mensuration: Perimeter, Area and Volume</h1>
            <div class="lesson-meta">16 min &middot; Module 2: Quantitative Reasoning &middot; Geometry</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Mensuration questions are not hard arithmetic  -  they are formula selection and unit discipline. The examiner gives you a shape, some lengths, and a unit; the marks are lost by using the diameter as the radius, by mixing centimetres into a metre formula, or by choosing area when the question asks for volume. Knowing the formulas cold removes all three risks.</p>
                <p>These same formulas reappear in physics, in everyday shopping, and in any later question about capacity or material.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <ul>
                    <li><strong>Perimeter is one-dimensional.</strong> It measures the length of the boundary and is reported in cm or m.</li>
                    <li><strong>Area is two-dimensional.</strong> It measures a flat cover and is reported in cm&sup2; or m&sup2;.</li>
                    <li><strong>Volume is three-dimensional.</strong> It measures the space inside a solid and is reported in cm&sup3;, m&sup3; or litres.</li>
                    <li><strong>Every shape has one or two key lengths.</strong> Identify them, pick the formula that uses them, and only then substitute.</li>
                    <li><strong>Units must match.</strong> Convert everything to one unit before multiplying.</li>
                </ul>
                <p>The model omits composite shapes, which are handled by splitting them into the standard pieces and adding or subtracting. It also assumes regular figures; real irregular shapes need approximation.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Perimeter and area of flat shapes</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Shape</th><th scope="col">Perimeter</th><th scope="col">Area</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Rectangle</td><td>2(l + w)</td><td>l &times; w</td></tr>
                        <tr><td>Triangle</td><td>Sum of three sides</td><td>(1/2) &times; base &times; perpendicular height</td></tr>
                        <tr><td>Parallelogram</td><td>2(a + b)</td><td>base &times; perpendicular height</td></tr>
                        <tr><td>Trapezium</td><td>Sum of four sides</td><td>(1/2) &times; (a + b) &times; height</td></tr>
                    </tbody>
                </table>
                <h3>Circles, arcs and sectors</h3>
                <div class="formula">circumference = 2 &pi; r = &pi; d &nbsp;&nbsp;&nbsp; area = &pi; r&sup2;</div>
                <div class="formula">arc length = (&theta; &divide; 360) &times; 2 &pi; r &nbsp;&nbsp;&nbsp; sector area = (&theta; &divide; 360) &times; &pi; r&sup2;</div>
                <p>Here r is the radius, d is the diameter and &theta; is the angle of the sector in degrees. A radius is half the diameter  -  the most common single error in the whole topic.</p>
                <h3>Volume and surface area of solids</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Solid</th><th scope="col">Volume</th><th scope="col">Surface area</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Cube</td><td>s&sup3;</td><td>6 s&sup2;</td></tr>
                        <tr><td>Cuboid</td><td>l b h</td><td>2(lb + bh + hl)</td></tr>
                        <tr><td>Cylinder</td><td>&pi; r&sup2; h</td><td>2 &pi; r(r + h)</td></tr>
                        <tr><td>Sphere</td><td>(4/3) &pi; r&sup3;</td><td>4 &pi; r&sup2;</td></tr>
                        <tr><td>Cone</td><td>(1/3) &pi; r&sup2; h</td><td>&pi; r(l + r), with l = &radic;(r&sup2; + h&sup2;)</td></tr>
                    </tbody>
                </table>
                <h3>Conversions worth memorising</h3>
                <div class="formula">1 m = 100 cm &nbsp; 1 m&sup2; = 10,000 cm&sup2; &nbsp; 1 m&sup3; = 1,000,000 cm&sup3; &nbsp; 1 litre = 1000 cm&sup3; &nbsp; 1 m&sup3; = 1000 litres</div>
                <div class="callout callout-tip">
                    <strong>Curved or total?</strong> "Surface area" of a closed solid means total, including the ends. If a cylinder is open at the top, add only one circular end: 2 &pi; r h + &pi; r&sup2;.
                </div>
                <div class="callout callout-warn">
                    <strong>Traps.</strong> (1) Using the diameter in place of the radius. (2) Mixing units  -  20 cm inside a formula in metres. (3) Reporting area when the question asks for volume, or the reverse. (4) Squaring or cubing the unit without converting it, so 1 m&sup2; is wrongly written as 100 cm&sup2;.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>A cylinder has radius 7 cm and height 10 cm. Find its volume and its total surface area. Use &pi; = 22/7.</em></p>
                <p>Volume first. Substitute r = 7 and h = 10 into &pi; r&sup2; h:</p>
                <div class="formula">V = (22/7) &times; 7&sup2; &times; 10 = (22/7) &times; 49 &times; 10 = 22 &times; 7 &times; 10 = 1540 cm&sup3;</div>
                <p>Since 1 litre = 1000 cm&sup3;, this cylinder holds 1.54 litres.</p>
                <p>Now total surface area, which is two circles plus the curved wall:</p>
                <div class="formula">Total SA = 2 &pi; r&sup2; + 2 &pi; r h = 2 &pi; r(r + h) = 2 &times; (22/7) &times; 7 &times; (7 + 10)</div>
                <p>Cancel 7 with the denominator: 2 &times; 22 &times; 17 = <strong>748 cm&sup2;</strong>.</p>
                <p>Check the two parts separately: the two ends are 2 &times; (22/7) &times; 49 = 308 cm&sup2;, and the curved wall is 2 &times; (22/7) &times; 7 &times; 10 = 440 cm&sup2;. Their sum is 308 + 440 = 748 cm&sup2;, which matches.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>A trapezium has parallel sides of 8 cm and 12 cm and a height of 5 cm. What is its area?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Area = (1/2)(a + b)h = (1/2)(20)(5) = 50 cm&sup2;." onclick="checkQuiz('quiz-1', this)">50 cm&sup2;</button>
                    <button class="quiz-option" data-correct="false" data-explain="100 cm&sup2; forgets the factor of one half; that is the area of a parallelogram with base 20." onclick="checkQuiz('quiz-1', this)">100 cm&sup2;</button>
                    <button class="quiz-option" data-correct="false" data-explain="480 cm&sup2; multiplies all three numbers as if it were a cuboid." onclick="checkQuiz('quiz-1', this)">480 cm&sup2;</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A circle has radius 7 cm. What is its circumference? Use &pi; = 22/7.</p>
                    <button class="quiz-option" data-correct="true" data-explain="C = 2 &pi; r = 2 &times; (22/7) &times; 7 = 44 cm." onclick="checkQuiz('quiz-2', this)">44 cm</button>
                    <button class="quiz-option" data-correct="false" data-explain="22 cm is &pi; r, which is half the circumference  -  the diameter is used, not the radius." onclick="checkQuiz('quiz-2', this)">22 cm</button>
                    <button class="quiz-option" data-correct="false" data-explain="154 cm is &pi; r&sup2;, which is the area, not the circumference." onclick="checkQuiz('quiz-2', this)">154 cm</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>What is the volume of a sphere of radius 3 cm?</p>
                    <button class="quiz-option" data-correct="true" data-explain="V = (4/3) &pi; r&sup3; = (4/3) &times; &pi; &times; 27 = 36 &pi; cm&sup3;." onclick="checkQuiz('quiz-3', this)">36 &pi; cm&sup3;</button>
                    <button class="quiz-option" data-correct="false" data-explain="12 &pi; cm&sup3; drops the factor of one third and miscounts; (4/3) &times; 27 is 36." onclick="checkQuiz('quiz-3', this)">12 &pi; cm&sup3;</button>
                    <button class="quiz-option" data-correct="false" data-explain="36 cm&sup3; omits &pi;; the answer must stay in terms of &pi; here." onclick="checkQuiz('quiz-3', this)">36 cm&sup3;</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>One cubic metre equals how many litres?</p>
                    <button class="quiz-option" data-correct="false" data-explain="100 litres confuses the linear conversion 1 m = 100 cm with the capacity conversion." onclick="checkQuiz('quiz-4', this)">100 litres</button>
                    <button class="quiz-option" data-correct="true" data-explain="1 m&sup3; = 1,000,000 cm&sup3; and 1 litre = 1000 cm&sup3;, so 1 m&sup3; = 1000 litres." onclick="checkQuiz('quiz-4', this)">1000 litres</button>
                    <button class="quiz-option" data-correct="false" data-explain="10,000 litres would come from squaring the conversion; volume needs the cube." onclick="checkQuiz('quiz-4', this)">10,000 litres</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: write the area of a triangle and the volume of a cylinder, and state the relationship between one metre and one centimetre before you cube it.</p>
                <p>The triangle is half base times height; the cylinder is &pi; r&sup2; h; and 1 m = 100 cm, so 1 m&sup3; = 1,000,000 cm&sup3;.</p>
                <div id="fill-1">
                    <p>The area of a triangle is one half times the base times the <input type="text" class="fill-blank" data-answer="height" placeholder="?" aria-label="factor missing from triangle area" />. The volume of a cylinder is &pi; r&sup2; times <input type="text" class="fill-blank" data-answer="h" placeholder="?" aria-label="factor missing from cylinder volume" />. One litre is <input type="text" class="fill-blank" data-answer="1000" placeholder="?" aria-label="cubic centimetres in one litre" /> cm&sup3;. The circumference of a circle is 2 &pi; times the <input type="text" class="fill-blank" data-answer="radius" placeholder="?" aria-label="length in the circumference formula" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A cylindrical water tank has radius 0.7 m and height 1.5 m. How many litres does it hold? Use &pi; = 22/7.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Use the cylinder volume formula with r = 0.7 and h = 1.5:</p>
                    <p>V = &pi; r&sup2; h = (22/7) &times; 0.7&sup2; &times; 1.5 = (22/7) &times; 0.49 &times; 1.5.</p>
                    <p>Since 0.49 &divide; 7 = 0.07, this becomes 22 &times; 0.07 &times; 1.5 = 22 &times; 0.105 = 2.31 m&sup3;.</p>
                    <p>Convert to litres: 1 m&sup3; = 1000 litres, so the tank holds <strong>2310 litres</strong>.</p>
                    <p>The reasoning is the point. Every input was already in metres, so no linear conversion was needed; only the final cubic-to-capacity step was required. A candidate who converted 0.7 m to 70 cm early would get 2,310,000 cm&sup3;; the same answer, but far easier to lose a zero in.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Mensuration measures shapes in isolation. The next lesson places them on a grid, where points, distances, midpoints and straight lines are described by coordinates  -  the bridge from geometry to algebra.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-geometry">Previous: Geometry and Measurement</a></span>
                <span><a href="/courses/hat/lessons/hat-coordinate-geometry">Next: Coordinate Geometry</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
