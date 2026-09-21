// HAT course — Set-based deduction: Venn diagrams, inclusion-exclusion and counting.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_sets_venn() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Set-Based Deduction: Venn Diagrams - Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Set-Based Deduction: Venn Diagrams</h1>
            <div class="lesson-meta">15 min &middot; Module 4: Analytical Reasoning &middot; Logic</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A large slice of the reasoning paper is arithmetic hidden inside language: how many people do at least one, how many do neither, how many do exactly one. Every one of those is a question about sets, and every one is solved by the same picture.</p>
                <p>Venn diagrams also give you a second, independent way to test a syllogism. When "all", "no" and "some" start to blur, the overlapping circles answer the question visually - which region must be empty, and which must contain at least one item.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A set is just a collection. Draw each set as a <strong>circle</strong> and every item as a dot placed where it belongs.</p>
                <ul>
                    <li><strong>Union</strong> A &cup; B - everything inside A, inside B, or inside both.</li>
                    <li><strong>Intersection</strong> A &cap; B - only the overlap, the items in both.</li>
                    <li><strong>Complement</strong> - everything outside a set, measured against the whole group under discussion.</li>
                    <li><strong>Count regions, not circles.</strong> The circles overlap; adding the two totals counts the overlap twice.</li>
                </ul>
                <p>What the model omits: the sizes. A Venn diagram shows which relationships are possible, but a counting question needs the actual number written into each region before you can answer.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Symbols to read fluently</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Symbol</th><th scope="col">Name</th><th scope="col">Means</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>A &cup; B</td><td>union</td><td>in A, in B, or in both</td></tr>
                        <tr><td>A &cap; B</td><td>intersection</td><td>in A and in B together</td></tr>
                        <tr><td>A&prime;</td><td>complement</td><td>not in A</td></tr>
                        <tr><td>n(A)</td><td>cardinality</td><td>the number of items in A</td></tr>
                    </tbody>
                </table>
                <h3>Inclusion-exclusion</h3>
                <div class="formula">n(A &cup; B) = n(A) + n(B) &minus; n(A &cap; B)</div>
                <p>The subtraction is the whole idea: the items in both circles were counted once in A and once in B, so they must be removed once. For three sets the pattern alternates:</p>
                <div class="formula">n(A &cup; B &cup; C) = n(A) + n(B) + n(C) &minus; n(A &cap; B) &minus; n(A &cap; C) &minus; n(B &cap; C) + n(A &cap; B &cap; C)</div>
                <h3>Translating the phrases</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Phrase</th><th scope="col">Region</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>at least one of the sets</td><td>the union</td></tr>
                        <tr><td>neither</td><td>outside the union - the complement</td></tr>
                        <tr><td>both A and B</td><td>the intersection A &cap; B</td></tr>
                        <tr><td>exactly one</td><td>the two single-set regions only, not the overlap</td></tr>
                    </tbody>
                </table>
                <h3>Venn as a syllogism test</h3>
                <ul>
                    <li><strong>All A are B</strong> - the part of A outside B is empty.</li>
                    <li><strong>No A are B</strong> - the overlap A &cap; B is empty.</li>
                    <li><strong>Some A are B</strong> - the overlap contains at least one item.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>Fill the overlap first.</strong> Work from the centre outward: put the "both" number in the middle, subtract it from each single total, and only then compute the outside. It prevents almost every counting error.
                </div>
                <div class="callout callout-warn">
                    <strong>Do not double count.</strong> The most common mistake is adding n(A) + n(B) + n(C) and forgetting the pairwise subtraction and the final addition of the triple overlap. If your union comes out larger than the total group, you have made exactly this error.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Example</h2>
                <h3>Two sets</h3>
                <p><em>In a class of 40 students, 25 play cricket, 20 play hockey and 10 play both.</em></p>
                <ul>
                    <li>Cricket only = 25 &minus; 10 = 15. Hockey only = 20 &minus; 10 = 10.</li>
                    <li>At least one = 25 + 20 &minus; 10 = 35, which agrees with 15 + 10 + 10.</li>
                    <li>Neither = 40 &minus; 35 = 5.</li>
                    <li>Exactly one = 15 + 10 = 25.</li>
                </ul>
                <h3>Three sets</h3>
                <p><em>120 people are surveyed. 60 like A, 45 like B and 35 like C. 20 like A and B, 15 like A and C, 10 like B and C, and 5 like all three.</em></p>
                <ul>
                    <li>All three = 5, so A and B only = 20 &minus; 5 = 15; A and C only = 15 &minus; 5 = 10; B and C only = 10 &minus; 5 = 5.</li>
                    <li>A only = 60 &minus; 15 &minus; 10 &minus; 5 = 30; B only = 45 &minus; 15 &minus; 5 &minus; 5 = 20; C only = 35 &minus; 10 &minus; 5 &minus; 5 = 15.</li>
                    <li>At least one = 60 + 45 + 35 &minus; 20 &minus; 15 &minus; 10 + 5 = 100. The seven regions sum to 30 + 20 + 15 + 15 + 10 + 5 + 5 = 100, confirming it.</li>
                    <li>Neither = 120 &minus; 100 = 20, and exactly one = 30 + 20 + 15 = 65.</li>
                </ul>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>In the class of 40, 25 play cricket and 20 play hockey, with 10 playing both. How many play at least one?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Adding 25 and 20 counts the 10 who play both twice, giving 45, which would exceed the class of 40." onclick="checkQuiz('quiz-1', this)">45</button>
                    <button class="quiz-option" data-correct="true" data-explain="Inclusion-exclusion gives 25 + 20 minus 10, which is 35, matching 15 plus 10 plus 10." onclick="checkQuiz('quiz-1', this)">35</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the cricket-only count after removing the overlap, not the total for at least one." onclick="checkQuiz('quiz-1', this)">15</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>Using the same class of 40, how many play neither game?</p>
                    <button class="quiz-option" data-correct="false" data-explain="10 students play both, not neither; the never-players are those outside the union." onclick="checkQuiz('quiz-2', this)">10</button>
                    <button class="quiz-option" data-correct="false" data-explain="25 is the number who play exactly one game, not the number who play none." onclick="checkQuiz('quiz-2', this)">25</button>
                    <button class="quiz-option" data-correct="true" data-explain="The union is 35, so the complement within 40 is 40 minus 35, which is 5." onclick="checkQuiz('quiz-2', this)">5</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>What does n(A &cup; B) count?</p>
                    <button class="quiz-option" data-correct="true" data-explain="The union includes everyone in A and everyone in B, with the overlap counted once." onclick="checkQuiz('quiz-3', this)">Items in A or in B or in both</button>
                    <button class="quiz-option" data-correct="false" data-explain="That is the intersection, A intersect B, which is only the overlap." onclick="checkQuiz('quiz-3', this)">Only the items in both A and B</button>
                    <button class="quiz-option" data-correct="false" data-explain="That is the exactly-one count, which excludes the overlap; the union includes it." onclick="checkQuiz('quiz-3', this)">Only the items in exactly one of A and B</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>In Venn terms, "All A are B" asserts that which region is empty?</p>
                    <button class="quiz-option" data-correct="false" data-explain="The overlap A intersect B is where the A items that are B live; it is not empty under this statement." onclick="checkQuiz('quiz-4', this)">The overlap of A and B</button>
                    <button class="quiz-option" data-correct="true" data-explain="All A inside B means no item lies in A while outside B, so the A-only region is empty." onclick="checkQuiz('quiz-4', this)">The part of A outside B</button>
                    <button class="quiz-option" data-correct="false" data-explain="The part of B outside A may be large; only the A side is constrained." onclick="checkQuiz('quiz-4', this)">The part of B outside A</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what does the subtraction in inclusion-exclusion remove, and how do you count the people who play neither game?</p>
                <p>The answer: it removes the double-counted overlap, and "neither" is the total minus the union.</p>
                <div id="fill-1">
                    <p>The items in both A and B form the <input type="text" class="fill-blank" data-answer="intersection" placeholder="?" aria-label="region shared by two sets" />. The formula for two sets is n(A) + n(B) &minus; n(A &cap; B), where the subtracted term removes the double-counted <input type="text" class="fill-blank" data-answer="overlap" placeholder="?" aria-label="what is subtracted" />. Everyone in at least one set forms the <input type="text" class="fill-blank" data-answer="union" placeholder="?" aria-label="region counting at least one" />, and the number in neither is the total minus that union, which for the class of 40 is <input type="text" class="fill-blank" data-answer="5" placeholder="?" aria-label="neither count" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>In a survey of 60 people, 35 read newspaper P, 25 read newspaper Q, and 15 read both. How many read at least one, how many read exactly one, and how many read neither?</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Write the overlap first: 15 people read both. Then P only = 35 &minus; 15 = 20, and Q only = 25 &minus; 15 = 10. At least one is the union, 35 + 25 &minus; 15 = 45, matching 20 + 10 + 15.</p>
                    <p>Exactly one excludes the overlap, so it is 20 + 10 = 30. Neither is the complement of the union against the total: 60 &minus; 45 = 15.</p>
                    <p>Check the arithmetic against the whole survey: the four regions are P only 20, Q only 10, both 15 and neither 15, and they sum to 60. If that sum misses the total, one of the regions has been miscounted - which is why the final consistency check is worth the ten seconds.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Sets give you a picture for every "all", "some" and "none" claim, and a formula for every "at least", "exactly" and "neither" count. The next lesson leaves circles for a different kind of spatial reasoning: relations and directions, where a set of statements about who is where is turned into a diagram and measured.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-syllogisms">Previous: Syllogisms</a></span>
                <span><a href="/courses/hat/lessons/hat-relations-and-directions">Next: Relations and Directions</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
