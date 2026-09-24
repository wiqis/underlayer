// HAT course — Network routing sets: one-way circuits, two-way radios, intermediaries.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_network_routing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Network Routing Sets — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Network Routing Sets</h1>
            <div class="lesson-meta">18 min · Module 4: Analytical Reasoning · Question type</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Some analytical sets give you a small network — nodes connected by channels that behave differently — and then hang several questions off the same picture. The official HAT sample paper spends six of its ten analytical questions on exactly this shape: seven supervisors, a one-way message circuit, a two-way radio, and a stream of "can this message reach that supervisor through exactly one intermediary?" items.</p>
                <p>That is the highest-leverage set on the paper. You read the setup once and answer six questions from one diagram. Candidates who skip drawing the diagram answer those six questions by re-reading the paragraph each time, lose the clock, and guess. Candidates who draw it once collect six marks in under four minutes.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Model the network as two kinds of line on one page, and never mix them up.</p>
                <ul>
                    <li><strong>A one-way circuit is an arrow.</strong> Traffic follows the arrow direction only. From A to B is free; from B back to A needs a different route.</li>
                    <li><strong>A two-way radio is a plain line.</strong> Traffic travels either way along it, one hop at a time.</li>
                    <li><strong>An intermediary is any intermediate node.</strong> Count the nodes strictly between sender and receiver on your chosen path — the endpoints do not count.</li>
                    <li><strong>Shortest first.</strong> "Exactly one intermediary" means a three-node path: sender — middle — receiver. "A minimum of two" means at least four nodes end to end.</li>
                </ul>
                <p>The model omits capacity and collisions: the real questions never ask how many messages fit, only whether a route exists and how long it is.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>The reading order that works.</strong> (1) Copy every channel onto your diagram, arrows for the circuit, plain lines for the radio. (2) Mark which nodes have no radio at all — they can only be reached or left by the circuit. (3) Only then read question one.</p>
                <p><strong>Four question shapes, one skill each.</strong></p>
                <table>
                    <thead>
                        <tr><th scope="col">Shape</th><th scope="col">What it asks</th><th scope="col">Method</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Exactly k intermediaries</td><td>A path of length k + 1 hops</td><td>Walk candidates; count the middle nodes</td></tr>
                        <tr><td>Minimum intermediaries</td><td>The shortest legal path</td><td>Breadth-first: try 1 hop, then 2, then 3</td></tr>
                        <tr><td>Requires both channels</td><td>No all-circuit or all-radio path exists</td><td>Prove the single-channel routes fail</td></tr>
                        <tr><td>Forced waypoint</td><td>Every path goes through node X</td><td>Remove X; if the target becomes unreachable, X is forced</td></tr>
                    </tbody>
                </table>
                <p><strong>Direction is the trap, not arithmetic.</strong> On a one-way circuit the reverse hop simply does not exist: if the circuit only runs C &rarr; D, then a message from D to C must find another channel or another way round the loop. Radio hops are symmetric, so it is almost always the circuit's direction that decides a question.</p>
                <div class="callout callout-tip">
                    <strong>Write the path as a node string.</strong> F-G-D-E-A is easier to count and check than a mental route. Intermediaries are every letter except the first and the last: G, D, E — three of them.
                </div>
                <div class="callout callout-warn">
                    <strong>Do not teleport along the circuit.</strong> The circuit is a fixed loop of hops; you cannot jump from A to D just because both sit on it. Each arrow is one hop, and every node you pass through is an intermediary you must count.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Use this network throughout — it has the same two-channel shape as the sample paper:</p>
                <pre>One-way circuit:  A -&gt; B -&gt; C -&gt; D -&gt; E -&gt; A
Two-way radio:    B - F,  F - G,  D - G
(Any node may act as an intermediary.)</pre>
                <p><strong>Question 1 — exactly one intermediary from B to D?</strong> Walk the circuit: B &rarr; C &rarr; D. The middle node is C, and no two-hop all-radio path exists because B and D share no radio line. Answer: <strong>C</strong>.</p>
                <p><strong>Question 2 — shortest route from F to A?</strong> F's radio exits are B and G. Via B the only onward move is the circuit B &rarr; C &rarr; D &rarr; E &rarr; A, giving F-B-C-D-E-A with four intermediaries. Via G: G's radio reaches D, and D continues on the circuit D &rarr; E &rarr; A, giving F-G-D-E-A with three intermediaries — G, D and E. Answer: <strong>3 intermediaries</strong>, the path F-G-D-E-A.</p>
                <p><strong>Question 3 — which pair needs both channels?</strong> A to F: every move from A is on the circuit (A &rarr; B &rarr; C &rarr; D &rarr; E &rarr; A), and F hangs only off the radio, so the path A-B-F uses the circuit A &rarr; B and then the radio B - F. Two channels, one intermediary. Answer: <strong>A to F</strong>.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>A message from B to D uses exactly one intermediary. Which node is it?</p>
                    <button class="quiz-option" data-correct="true" data-explain="The circuit gives B to C to D in two hops, so C is the single middle node. No radio path connects B to D directly." onclick="checkQuiz('quiz-1', this)">C</button>
                    <button class="quiz-option" data-correct="false" data-explain="E is not on any two-hop route from B to D: reaching E from B takes B-C-D-E on the circuit, which is too long." onclick="checkQuiz('quiz-1', this)">E</button>
                    <button class="quiz-option" data-correct="false" data-explain="F would mean the path B-F-..., but F's only radio partners are B and G, and G does not reach D in one further radio hop from F without passing another node." onclick="checkQuiz('quiz-1', this)">F</button>
                    <button class="quiz-option" data-correct="false" data-explain="A lies behind B on the circuit (E to A to B); going B to A would mean travelling against the arrows, which the one-way circuit forbids." onclick="checkQuiz('quiz-1', this)">A</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>What is the minimum number of intermediaries for a message from F to A?</p>
                    <button class="quiz-option" data-correct="false" data-explain="One intermediary would be a path F-M-A. No node M shares a radio line with both F and A, and A has no radio at all, so one is impossible." onclick="checkQuiz('quiz-2', this)">1</button>
                    <button class="quiz-option" data-correct="false" data-explain="Two intermediaries needs a four-node path. F's exits are B and G; from B the circuit must still traverse C, D, E to reach A, and from G you must touch D before the circuit can run to A — neither fits in four nodes." onclick="checkQuiz('quiz-2', this)">2</button>
                    <button class="quiz-option" data-correct="true" data-explain="F-G-D-E-A passes through G, D and E: three intermediaries. The alternative via B (F-B-C-D-E-A) has four, so three is the minimum." onclick="checkQuiz('quiz-2', this)">3</button>
                    <button class="quiz-option" data-correct="false" data-explain="Four is the count via B (F-B-C-D-E-A with B, C, D, E), which is a valid route but not the shortest." onclick="checkQuiz('quiz-2', this)">4</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>Which pair requires using both the circuit and the radio?</p>
                    <button class="quiz-option" data-correct="false" data-explain="B to D is B-C-D on the circuit alone; neither endpoint touches the radio on this path." onclick="checkQuiz('quiz-3', this)">B to D</button>
                    <button class="quiz-option" data-correct="false" data-explain="F to G is the single radio line F-G; no circuit node is involved." onclick="checkQuiz('quiz-3', this)">F to G</button>
                    <button class="quiz-option" data-correct="true" data-explain="A sits only on the circuit and F only on the radio, so every path must use a circuit hop (A to B) and a radio hop (B to F): A-B-F." onclick="checkQuiz('quiz-3', this)">A to F</button>
                    <button class="quiz-option" data-correct="false" data-explain="C to D is the direct circuit arrow C to D — one hop, one channel, zero intermediaries." onclick="checkQuiz('quiz-3', this)">C to D</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>A message travels from G to B through the fewest possible intermediaries. Which node does it pass through?</p>
                    <button class="quiz-option" data-correct="false" data-explain="Going through D means G-D, but D cannot reach B on the circuit without first running D-E-A-B — far longer than the radio hop through F." onclick="checkQuiz('quiz-4', this)">D</button>
                    <button class="quiz-option" data-correct="true" data-explain="G-F-B uses the two radio lines G-F and F-B, giving exactly one intermediary, F. That beats any route that touches the circuit." onclick="checkQuiz('quiz-4', this)">F</button>
                    <button class="quiz-option" data-correct="false" data-explain="E lies on the circuit between D and A; reaching E from G already costs G-D-E, and E still has to run E-A-B to reach B." onclick="checkQuiz('quiz-4', this)">E</button>
                    <button class="quiz-option" data-correct="false" data-explain="C sits between B and D on the circuit; entering C from G would require arriving at D first and moving against the one-way flow D from C, which is impossible." onclick="checkQuiz('quiz-4', this)">C</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what does "exactly two intermediaries" mean in hops, and which channel type is directional?</p>
                <p>The answer is: a four-node path sender-X-Y-receiver, three hops with two middle nodes; only the one-way circuit is directional — the radio works either way.</p>
                <div id="fill-1">
                    <p>On the one-way circuit, traffic may travel only along the <input type="text" class="fill-blank" data-answer="arrow" placeholder="?" aria-label="circuit direction" />, while the two-way radio works in <input type="text" class="fill-blank" data-answer="both" placeholder="?" aria-label="radio direction" /> directions. An intermediary is any node strictly <input type="text" class="fill-blank" data-answer="between" placeholder="?" aria-label="intermediary position" /> the sender and the receiver, and the endpoints are never counted. A path with exactly one intermediary has <input type="text" class="fill-blank" data-answer="two" placeholder="?" aria-label="hops for one intermediary" /> hops.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Show that a message from E to F requires both channels, and give a shortest route with its intermediary count.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>E and F sit on different sides of the network: E is on the one-way circuit only, F on the radio only. So any path must include at least one circuit hop and at least one radio hop — both channels are mandatory.</p>
                    <p>Shortest route: E &rarr; A &rarr; B then B - F gives E-A-B-F, with intermediaries A and B — two of them. The radio hops B-F and F-G never shorten this, because from G you would still need G-D and then D-E-A-B to start from the wrong side.</p>
                    <p>Check the reverse direction while you are here: F to E is the same three hops read backwards on the radio legs, but the circuit legs must still run with the arrows (D to E, not E to D), which is why path-finding on these sets is directional even when the endpoints look symmetric.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You can now draw a two-channel network once and answer every question hung on it: exact hop counts, minimum intermediaries, both-channel proofs and forced waypoints. The next lesson returns to verbal deduction — syllogisms — where the diagram is Venn circles instead of routing lines, but the habit is the same: draw the structure before reading the options.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-grouping-puzzles">Previous: Grouping and Selection Puzzles</a></span>
                <span><a href="/courses/hat/lessons/hat-syllogisms">Next: Syllogisms</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
