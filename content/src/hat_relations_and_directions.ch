// HAT course — Blood relations and direction sense: drawing the tree and the map.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_relations_and_directions() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Relations and Directions — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Relations and Directions</h1>
            <div class="lesson-meta">15 min · Module 4: Analytical Reasoning · Maps and trees</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Two question families that look different and are solved identically: family relationships, where the drawing is a tree, and direction sense, where the drawing is a compass map. In both, the sentences are instructions for drawing — and once the drawing exists, the answer is visible rather than deduced.</p>
                <p>Both families are also traps for anyone who tries to hold them in their head. "A is the mother of B, B is the sister of C, C is the father of D" is four nodes and three edges when drawn, and a tangle of pronouns when not.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p><strong>Relations:</strong> draw people as letters, connect them with labelled edges (parent, spouse, sibling), and mark gender wherever the question depends on it.</p>
                <div class="formula">start from yourself &rarr; draw each relation as an edge &rarr; read the path between the two people named</div>
                <p><strong>Directions:</strong> draw north as up, and treat every turn as a change of heading applied to the current one.</p>
                <div class="formula">right turn from north = east &nbsp;·&nbsp; left turn from east = north &nbsp;·&nbsp; displacement = net north-south and east-west</div>
                <p>In both families, never answer from the sentence; answer from the drawing.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>Relations: the edges you will meet</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Phrase</th><th scope="col">What it means</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Only son of my grandfather</td><td>My father (if the grandfather is my father's father)</td></tr>
                        <tr><td>My father's brother</td><td>My uncle; his children are my cousins</td></tr>
                        <tr><td>My mother's brother's son</td><td>My cousin</td></tr>
                        <tr><td>Daughter of my father's sister</td><td>My cousin</td></tr>
                        <tr><td>Brother of my wife's father</td><td>My father-in-law's brother, not a blood relative of mine</td></tr>
                        <tr><td>Son of my grandfather's only daughter</td><td>My brother or me - the only daughter is my mother, so her son is my brother or me</td></tr>
                    </tbody>
                </table>
                <p>Two disciplines make relationship items reliable: write the gender on the node as soon as a word like mother, sister, son tells you, and read the path backwards as well as forwards, because many questions ask the relation in the opposite direction to the sentence.</p>
                <h3>Missing gender is a legitimate answer</h3>
                <p>If the person named could be either male or female, the correct answer is "uncle or aunt", "brother or sister". Questions designed this way test whether you noticed that the gender was never given; do not force a choice.</p>
                <h3>Directions: the compass in words</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Facing</th><th scope="col">Turn right</th><th scope="col">Turn left</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>North</td><td>East</td><td>West</td></tr>
                        <tr><td>East</td><td>South</td><td>North</td></tr>
                        <tr><td>South</td><td>West</td><td>East</td></tr>
                        <tr><td>West</td><td>North</td><td>South</td></tr>
                    </tbody>
                </table>
                <p>A <em>half turn</em> reverses the heading, and a <em>full turn</em> restores it. Shadow questions follow the sun: at sunrise a person's shadow points west, at sunset it points east, and at noon it is shortest and points north in the northern hemisphere.</p>
                <h3>Distance from the start</h3>
                <p>Do not add up the legs of the walk. Add the north-south legs into one net displacement and the east-west legs into another, then use the right-angled triangle rule:</p>
                <div class="formula">distance from start = square root of (net east-west)&sup2; + (net north-south)&sup2;</div>
                <div class="callout callout-tip">
                    <strong>Look for the 3-4-5 family.</strong> Test makers love pairs such as 6 km and 8 km, or 9 km and 12 km, because the answer 10 km or 15 km is exact. If your nets are 6 and 8, write 10 without computing a root.
                </div>
                <div class="callout callout-warn">
                    <strong>The three direction traps.</strong> (1) Turning relative to the original heading instead of the current one. (2) Adding distances travelled instead of computing net displacement. (3) Answering "where is he facing" with "where is he from the start" — the two questions are different.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. Pointing at a photograph, Ali says, "She is the daughter of my grandfather's only son." How is she related to Ali?</h3>
                <p>Draw it: Ali's grandfather has one son, who is Ali's father. The daughter of Ali's father is Ali's <strong>sister</strong>. The phrase "only son" exists to prevent you from considering an uncle's daughter.</p>
                <h3>2. A is the mother of B. B is the sister of C. C is the father of D. How is A related to D?</h3>
                <p>Edges: A is a parent of B; B and C are siblings, so A is also a parent of C; C is a parent of D. Therefore A is D's <strong>grandmother</strong> — the gender came from the word "mother" two sentences earlier.</p>
                <h3>3. P is the brother of Q. Q is the wife of R. R is the father of S. How is P related to S?</h3>
                <p>Q is S's mother (through R, S's father), and P is Q's brother, so P is S's <strong>maternal uncle</strong>.</p>
                <h3>4. A man walks 6 km south, then 8 km east. How far is he from his starting point?</h3>
                <p>Net displacement: 6 km south and 8 km east, a 6-8-10 triangle, so he is <strong>10 km</strong> from the start. Adding the legs (14 km) is the trap.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>X is the son of Y. Y is the sister of Z. How is Z related to X?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Y's brother Z is X's uncle, but Z could equally be Y's sister, which makes Z X's aunt; the gender is never stated." onclick="checkQuiz('quiz-1', this)">Uncle</button>
                    <button class="quiz-option" data-correct="true" data-explain="Z is the sibling of X's mother, so Z is X's aunt or uncle — the sentence never says which." onclick="checkQuiz('quiz-1', this)">Uncle or aunt</button>
                    <button class="quiz-option" data-correct="false" data-explain="Z is one generation above X, as a sibling of X's parent, not a cousin of the same generation." onclick="checkQuiz('quiz-1', this)">Cousin</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A man walks 5 km north, turns right and walks 3 km, turns right again and walks 5 km. How far is he from his starting point?</p>
                    <button class="quiz-option" data-correct="false" data-explain="13 km adds the three legs together, which measures the distance walked rather than the distance from the start." onclick="checkQuiz('quiz-2', this)">13 km</button>
                    <button class="quiz-option" data-correct="true" data-explain="North 5 and south 5 cancel, leaving 3 km east, so he is 3 km from the start." onclick="checkQuiz('quiz-2', this)">3 km</button>
                    <button class="quiz-option" data-correct="false" data-explain="5 km is the north-south leg, which cancels out entirely against the third leg." onclick="checkQuiz('quiz-2', this)">5 km</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>A man starts facing north, turns right twice and then turns left once. Which direction is he facing now?</p>
                    <button class="quiz-option" data-correct="false" data-explain="South would need two right turns and no left turn; the extra left turn brings him back to east." onclick="checkQuiz('quiz-3', this)">South</button>
                    <button class="quiz-option" data-correct="true" data-explain="North to east to south, then a left turn from south gives east." onclick="checkQuiz('quiz-3', this)">East</button>
                    <button class="quiz-option" data-correct="false" data-explain="West requires three left turns from north, or a different combination than the one given." onclick="checkQuiz('quiz-3', this)">West</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>At sunrise, a man standing in an open field has his shadow pointing:</p>
                    <button class="quiz-option" data-correct="false" data-explain="East is where the sun is, so the shadow falls away from it, to the west." onclick="checkQuiz('quiz-4', this)">east</button>
                    <button class="quiz-option" data-correct="true" data-explain="At sunrise the sun is in the east, so the shadow is cast in the opposite direction, to the west." onclick="checkQuiz('quiz-4', this)">west</button>
                    <button class="quiz-option" data-correct="false" data-explain="A shadow points north only around noon in the northern hemisphere, when the sun is highest and to the south." onclick="checkQuiz('quiz-4', this)">north</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: how do you find the distance from the start, and what do you do when a person's gender is never given?</p>
                <p>The answer: combine the north-south legs and the east-west legs separately and use the right-angled triangle rule; and answer "uncle or aunt" rather than forcing a choice.</p>
                <div id="fill-1">
                    <p>To find the distance from the starting point, add the north-south legs into one net displacement and the east-west legs into another, then apply the <input type="text" class="fill-blank" data-answer="triangle" placeholder="?" aria-label="rule used for displacement" /> rule. A right turn from facing east leads to <input type="text" class="fill-blank" data-answer="south" placeholder="?" aria-label="direction after right turn from east" />. At sunset a shadow points <input type="text" class="fill-blank" data-answer="east" placeholder="?" aria-label="shadow direction at sunset" />. When the gender of a relative is never stated, the answer is uncle or <input type="text" class="fill-blank" data-answer="aunt" placeholder="?" aria-label="the other possibility" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>"A woman walks 4 km north, then turns left and walks 3 km, then turns left again and walks 4 km. How far is she from the start, and in which direction?" Answer both, then explain what changes if the third leg is 6 km instead of 4 km.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Leg one: 4 km north. Facing north, a left turn gives west, so leg two is 3 km west. Facing west, a left turn gives south, so leg three is 4 km south. Net: the north and south legs cancel, leaving 3 km west of the start — she is <strong>3 km from the start, to the west</strong>. Note that this is the same arithmetic as the earlier 5-3-5 walk; the pattern of three legs turning the same way always leaves you beside your starting point.</p>
                    <p>With the third leg at 6 km instead of 4 km, the net north-south becomes 4 &minus; 6 = 2 km to the south, and the net east-west stays 3 km west. The distance becomes the hypotenuse of 2 and 3, which is the square root of 13, about 3.6 km, in the direction south-west of the start. The compass direction changed from west to south-west, which is why the question "how far" and the question "in what direction" must both be answered from the same net-displacement calculation.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Trees and maps are done. The next lesson is a small, entirely mechanical family that rewards pattern recognition rather than drawing: coding and decoding, where a letter or number transformation is stated once and applied to a new word.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-syllogisms">Previous: Syllogisms</a></span>
                <span><a href="/courses/hat/lessons/hat-coding-decoding">Next: Coding and Decoding</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
