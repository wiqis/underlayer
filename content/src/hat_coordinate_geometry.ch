// HAT course  -  Coordinate geometry: distance, midpoint, slope and the equation of a line.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_coordinate_geometry() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Coordinate Geometry - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Coordinate Geometry</h1>
            <div class="lesson-meta">15 min &middot; Module 2: Quantitative Reasoning &middot; Geometry</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Coordinate geometry turns shapes into arithmetic. Once every point has an address (x, y), distances, midpoints, slopes and straight lines become formulas rather than drawings. Questions that look like they need a careful sketch  -  is this triangle isosceles, are these two lines perpendicular, where do they meet  -  are answered by substituting coordinates.</p>
                <p>It is also the bridge back to algebra: a line on the grid is exactly a linear equation, so slope and intercept carry their usual meanings.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <ul>
                    <li><strong>A point is an ordered pair.</strong> The first number is the horizontal x, the second is the vertical y; the order matters.</li>
                    <li><strong>Distance and midpoint come from the two points.</strong> Distance is Pythagoras on the horizontal and vertical gaps; midpoint is their average.</li>
                    <li><strong>Slope is rise over run.</strong> It measures steepness and direction, and it is the same anywhere on a straight line.</li>
                    <li><strong>Two numbers describe a line's tilt and position.</strong> Slope m and intercept c fully define y = mx + c.</li>
                    <li><strong>Parallel and perpendicular are slope conditions.</strong> No drawing is needed.</li>
                </ul>
                <p>The model omits vertical lines, which have undefined slope and cannot be written as y = mx + c; they take the form x = a constant. That single exception is a favourite trap.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Distance and midpoint</h3>
                <div class="formula">distance = &radic;( (x2 &minus; x1)&sup2; + (y2 &minus; y1)&sup2; )</div>
                <p>Mini-example: (1, 2) to (4, 6). Gaps are 4 &minus; 1 = 3 and 6 &minus; 2 = 4, so distance = &radic;(9 + 16) = &radic;25 = 5. The distance formula is Pythagoras with the horizontal and vertical gaps as the two short sides.</p>
                <div class="formula">midpoint = ( (x1 + x2) &divide; 2 , (y1 + y2) &divide; 2 )</div>
                <p>Mini-example: (1, 2) and (4, 6) again. Midpoint = ( (1 + 4) &divide; 2 , (2 + 6) &divide; 2 ) = (2.5, 4). Each coordinate is the average of the two endpoints — never a difference.</p>
                <h3>Slope and the equation of a line</h3>
                <div class="formula">m = (y2 &minus; y1) &divide; (x2 &minus; x1)</div>
                <p>Mini-example: (1, 2) to (4, 6). Rise is 6 &minus; 2 = 4, run is 4 &minus; 1 = 3, so m = 4/3. If the line falls left to right, m is negative — the sign is a free check.</p>
                <div class="formula">y = m x + c &nbsp;&nbsp;&nbsp; or &nbsp;&nbsp;&nbsp; y &minus; y1 = m (x &minus; x1)</div>
                <p>Mini-example with m = 4/3 through (1, 2): y &minus; 2 = (4/3)(x &minus; 1), so 3y &minus; 6 = 4x &minus; 4, giving 3y = 4x + 2 or y = (4/3)x + 2/3; the intercept c is 2/3. Use y = mx + c when you know the slope and want the intercept; use the point-slope form when you know the slope and one point. The y-intercept is c (set x = 0); the x-intercept is found by setting y = 0 and solving for x.</p>
                <h3>Parallel and perpendicular lines</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Relationship</th><th scope="col">Slope condition</th><th scope="col">Example</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Parallel</td><td>m1 = m2</td><td>y = 2x + 1 is parallel to y = 2x &minus; 7</td></tr>
                        <tr><td>Perpendicular</td><td>m1 &times; m2 = &minus;1</td><td>y = 2x has a perpendicular slope of &minus;1/2</td></tr>
                    </tbody>
                </table>
                <p>A horizontal line has slope 0; a vertical line has undefined slope, so it has no perpendicular condition in this form.</p>
                <div class="callout callout-tip">
                    <strong>Check a slope in one glance.</strong> If the line goes up from left to right, m is positive; down, negative. If your calculated m has the wrong sign, you subtracted the coordinates in an inconsistent order.
                </div>
                <div class="callout callout-warn">
                    <strong>Traps.</strong> (1) Subtracting x in one order and y in the other. (2) Forgetting the square root in the distance formula. (3) Writing (x1 &minus; x2) instead of the average ((x1 + x2) &divide; 2) for a midpoint. (4) Treating a perpendicular slope as the negative of m rather than the negative reciprocal of m.
                </div>
                <p>Each formula earns a thirty-second check before it is used. Distance: gaps first, then squares, then the root — if your answer is larger than both gaps by a lot, you probably added instead of taking the root. Midpoint: average, never difference; the result must sit halfway, so each coordinate of the midpoint lies between the two endpoints. Slope: rise over run in the same order top-to-bottom as right-to-left; the sign of m must match the visual direction of the line. Line equation: expand before simplifying, then verify by substituting the second point — one substitution catches almost every algebra slip.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <p><em>The points A(2, 1) and B(6, 9) are given. Find the distance AB, the midpoint, the slope, and the equation of the line through them.</em></p>
                <p>Distance: the gaps are 6 &minus; 2 = 4 and 9 &minus; 1 = 8, so</p>
                <div class="formula">AB = &radic;(4&sup2; + 8&sup2;) = &radic;(16 + 64) = &radic;80 = 4&radic;5 &asymp; 8.94</div>
                <p>Midpoint: average the coordinates, giving ( (2 + 6) &divide; 2 , (1 + 9) &divide; 2 ) = <strong>(4, 5)</strong>.</p>
                <p>Slope: m = (9 &minus; 1) &divide; (6 &minus; 2) = 8 &divide; 4 = <strong>2</strong>.</p>
                <p>Equation: use point-slope with A(2, 1) and m = 2. Then y &minus; 1 = 2(x &minus; 2), which expands to y = 2x &minus; 4 + 1, so <strong>y = 2x &minus; 3</strong>.</p>
                <p>Check with B(6, 9): 2 &times; 6 &minus; 3 = 9, which matches. The x-intercept is where y = 0, giving 2x = 3, so x = 1.5; a line perpendicular to this one would have slope &minus;1/2.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>What is the distance between (0, 0) and (6, 8)?</p>
                    <button class="quiz-option" data-correct="true" data-explain="&radic;(6&sup2; + 8&sup2;) = &radic;(36 + 64) = &radic;100 = 10." onclick="checkQuiz('quiz-1', this)">10</button>
                    <button class="quiz-option" data-correct="false" data-explain="14 is 6 + 8, the sum of the gaps, which ignores that they meet at a right angle." onclick="checkQuiz('quiz-1', this)">14</button>
                    <button class="quiz-option" data-correct="false" data-explain="48 is 6 &times; 8; the distance formula squares and adds the gaps, it does not multiply them." onclick="checkQuiz('quiz-1', this)">48</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>What is the slope of the line through (1, 2) and (4, 11)?</p>
                    <button class="quiz-option" data-correct="true" data-explain="m = (11 &minus; 2) &divide; (4 &minus; 1) = 9 &divide; 3 = 3." onclick="checkQuiz('quiz-2', this)">3</button>
                    <button class="quiz-option" data-correct="false" data-explain="1/3 is the reciprocal; rise over run is 9 over 3, not 3 over 9." onclick="checkQuiz('quiz-2', this)">1/3</button>
                    <button class="quiz-option" data-correct="false" data-explain="9 is only the rise; the slope must divide it by the run of 3." onclick="checkQuiz('quiz-2', this)">9</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>What is the midpoint of (&minus;2, 5) and (6, &minus;1)?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Average each coordinate: ((&minus;2 + 6) &divide; 2, (5 + (&minus;1)) &divide; 2) = (2, 2)." onclick="checkQuiz('quiz-3', this)">(2, 2)</button>
                    <button class="quiz-option" data-correct="false" data-explain="(4, 4) is the sum of the coordinates, not the average; the midpoint halves it." onclick="checkQuiz('quiz-3', this)">(4, 4)</button>
                    <button class="quiz-option" data-correct="false" data-explain="(&minus;4, 3) subtracts the coordinates in one order, which gives the gap, not the midpoint." onclick="checkQuiz('quiz-3', this)">(&minus;4, 3)</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>A line has slope 3. What is the slope of any line perpendicular to it?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Perpendicular slopes multiply to &minus;1, so the required slope is &minus;1/3." onclick="checkQuiz('quiz-4', this)">&minus;1/3</button>
                    <button class="quiz-option" data-correct="false" data-explain="&minus;3 is the negative of the slope, not the negative reciprocal; the product would be &minus;9, not &minus;1." onclick="checkQuiz('quiz-4', this)">&minus;3</button>
                    <button class="quiz-option" data-correct="false" data-explain="3 would make the lines parallel, since parallel lines share the same slope." onclick="checkQuiz('quiz-4', this)">3</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: write the slope formula and the condition that makes two lines perpendicular.</p>
                <p>The slope is (y2 &minus; y1) &divide; (x2 &minus; x1); two lines are perpendicular when the product of their slopes is &minus;1.</p>
                <div id="fill-1">
                    <p>The slope of the line through two points is the change in y divided by the <input type="text" class="fill-blank" data-answer="change in x" placeholder="?" aria-label="denominator of the slope formula" />. For perpendicular lines, the two slopes are negative <input type="text" class="fill-blank" data-answer="reciprocals" placeholder="?" aria-label="perpendicular slopes relationship" />. The midpoint of (2, 4) and (8, 10) has x-coordinate <input type="text" class="fill-blank" data-answer="5" placeholder="?" aria-label="x coordinate of the midpoint" /> and y-coordinate <input type="text" class="fill-blank" data-answer="7" placeholder="?" aria-label="y coordinate of the midpoint" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A triangle has vertices A(0, 0), B(4, 0) and C(0, 3). Find the length of each side, and decide whether the triangle is right-angled.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>AB runs along the x-axis from 0 to 4, so AB = 4. AC runs along the y-axis from 0 to 3, so AC = 3.</p>
                    <p>BC uses the distance formula: &radic;((4 &minus; 0)&sup2; + (0 &minus; 3)&sup2;) = &radic;(16 + 9) = &radic;25 = 5.</p>
                    <p>The sides are 3, 4 and 5. Since 3&sup2; + 4&sup2; = 9 + 16 = 25 = 5&sup2;, the converse of Pythagoras confirms a right angle, and because 5 is the longest side it must be opposite the right angle  -  at vertex A.</p>
                    <p>That also follows from the slopes: AB is horizontal (slope 0) and AC is vertical (undefined slope), and the axes meet at a right angle. The area is (1/2) &times; 4 &times; 3 = 6 square units.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Coordinates joined algebra to geometry. The next step is to read information that arrives already organised  -  tables, charts and averages  -  and to turn that data back into quantitative conclusions.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-mensuration">Previous: Mensuration</a></span>
                <span><a href="/courses/hat/lessons/hat-data-probability">Next: Data, Averages and Probability</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
