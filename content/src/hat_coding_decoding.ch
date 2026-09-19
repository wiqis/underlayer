// HAT course — Coding and decoding: identifying the transformation and applying it.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_coding_decoding() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Coding and Decoding — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Coding and Decoding</h1>
            <div class="lesson-meta">13 min · Module 4: Analytical Reasoning · Mechanical patterns</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Coding items are the most mechanical questions on the analytical section: a rule is demonstrated on one word, and you apply it to another. There is no reasoning to do and no diagram to draw — only a transformation to name. That makes them the fastest marks in the section when you know the catalogue, and a five-minute dead end when you do not.</p>
                <p>The skill is recognition: compare the given pairs letter by letter, and the transformation announces itself in the first two letters.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Ask one question: <strong>what happened to each letter?</strong> Work through the catalogue in order of likelihood and stop at the first match.</p>
                <ol>
                    <li><strong>Shift:</strong> is every letter moved by the same number of places? (CAT to DBU is +1.)</li>
                    <li><strong>Reversal:</strong> is the word written backwards? (MOTHER to REHTOM.)</li>
                    <li><strong>Shift and reverse together.</strong></li>
                    <li><strong>Position arithmetic:</strong> are letters replaced by their numbers, or by sums and differences of numbers?</li>
                    <li><strong>Substitution:</strong> a fixed mapping, such as vowels shifted and consonants kept.</li>
                    <li><strong>Word-level code:</strong> whole words replaced by invented words, solved by intersecting two sentences.</li>
                </ol>
                <p>Write the alphabet with its positions at the top of your rough sheet before the section starts. That single line converts every shift question into counting rather than recall.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The alphabet strip you should write out</h3>
                <pre>A  B  C  D  E  F  G  H  I  J  K  L  M
1  2  3  4  5  6  7  8  9  10 11 12 13
N  O  P  Q  R  S  T  U  V  W  X  Y  Z
14 15 16 17 18 19 20 21 22 23 24 25 26</pre>
                <p>Remember <strong>EJOTY</strong> as a shortcut: E is 5, J is 10, O is 15, T is 20, Y is 25. Any letter's position can then be found by stepping a few places from one of those anchors — Q is one before R, and R is 18, so Q is 17.</p>
                <h3>The transformations, with examples</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Rule</th><th scope="col">Given</th><th scope="col">Code</th><th scope="col">Then</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Shift +1</td><td>CAT</td><td>DBU</td><td>DOG becomes EPH</td></tr>
                        <tr><td>Reverse</td><td>MOTHER</td><td>REHTOM</td><td>FATHER becomes REHTAF</td></tr>
                        <tr><td>Shift +2 then reverse</td><td>CAT</td><td>VCE</td><td>DOG becomes IQF</td></tr>
                        <tr><td>Positions as numbers</td><td>MAN</td><td>13-1-14</td><td>The sum for DOG is 4 + 15 + 7 = 26</td></tr>
                        <tr><td>Mirror (A to Z, B to Y)</td><td>CAT</td><td>XZG</td><td>DOG becomes WLT</td></tr>
                        <tr><td>Vowels shifted +1, consonants unchanged</td><td>CAT</td><td>CBT</td><td>DOG becomes DPG</td></tr>
                    </tbody>
                </table>
                <h3>Word-level codes (the invented-language questions)</h3>
                <p>These give whole sentences in a made-up language and ask for a word's meaning. The method is intersection, not vocabulary:</p>
                <ul>
                    <li><strong>Line up the word counts.</strong> If the coded sentence has four words, the translation has four words, in the same order.</li>
                    <li><strong>Find a word that appears in two sentences,</strong> and the meaning that appears in both translations. That pair is a dictionary entry.</li>
                    <li><strong>Use elimination for the rest:</strong> once two of four words are known, the remaining pairs follow.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>Test the shift on two different letters before committing.</strong> A shift of +1 in the first letter pair and +3 in the second means the rule is not a uniform shift; check the third pair, because the real rule is often positional (first letter +1, second +2, third +3).
                </div>
                <div class="callout callout-warn">
                    <strong>Two traps.</strong> (1) Wrapping around the alphabet: shifting Z by +1 gives A, not an error. (2) Applying a mirror rule backwards — in the mirror code A and Z are partners, so mirroring twice returns the original word, which is exactly how you can check your answer.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. If CAT is coded as DBU, how is DOG coded?</h3>
                <p>Each letter has moved one place forward: C to D, A to B, T to U. So D to E, O to P, G to H: <strong>EPH</strong>.</p>
                <h3>2. If MOTHER is coded as REHTOM, how is FATHER coded?</h3>
                <p>The code is the word reversed. FATHER reversed letter by letter is <strong>REHTAF</strong>.</p>
                <h3>3. If A = 1 and Z = 26, what is the sum of the letters in DOG?</h3>
                <p>D is 4, O is 15, G is 7: 4 + 15 + 7 = <strong>26</strong>. Notice that DOG and CAT both sum to 26 — a coincidence of this particular pair, not a rule.</p>
                <h3>4. In a certain language, "pa ta ka" means "rain comes soon" and "ta ne da" means "comes the storm". Which word means "comes"?</h3>
                <p>The two sentences share the word "comes", and the only code word shared by "pa ta ka" and "ta ne da" is <strong>ta</strong>. So ta means comes, and the dictionary entry was found by intersection rather than by guessing.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>If CAT is coded as DBU, how is DOG coded?</p>
                    <button class="quiz-option" data-correct="true" data-explain="Every letter moves one place forward: D to E, O to P, G to H, giving EPH." onclick="checkQuiz('quiz-1', this)">EPH</button>
                    <button class="quiz-option" data-correct="false" data-explain="CNG applies the shift only to the first letter; the rule here is uniform across the word." onclick="checkQuiz('quiz-1', this)">CNG</button>
                    <button class="quiz-option" data-correct="false" data-explain="EPI shifts the last letter by two places, which breaks the uniform +1 rule." onclick="checkQuiz('quiz-1', this)">EPI</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>If MOTHER is coded as REHTOM, how is FATHER coded?</p>
                    <button class="quiz-option" data-correct="false" data-explain="This applies a +1 shift, but the code shown is a reversal, so the rule to apply is reversal." onclick="checkQuiz('quiz-2', this)">GBUIFS</button>
                    <button class="quiz-option" data-correct="true" data-explain="The code is the word written backwards, so FATHER becomes REHTAF." onclick="checkQuiz('quiz-2', this)">REHTAF</button>
                    <button class="quiz-option" data-correct="false" data-explain="This keeps the order and changes one letter, which is neither reversal nor shift." onclick="checkQuiz('quiz-2', this)">FATHEE</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>If A = 1 through to Z = 26, what is the sum of the letters in DOG?</p>
                    <button class="quiz-option" data-correct="false" data-explain="That is the sum for MAN, whose letters are 13, 1 and 14." onclick="checkQuiz('quiz-3', this)">28</button>
                    <button class="quiz-option" data-correct="true" data-explain="D is 4, O is 15 and G is 7, which sum to 26." onclick="checkQuiz('quiz-3', this)">26</button>
                    <button class="quiz-option" data-correct="false" data-explain="15 is the position of a single letter, O, rather than the sum of the three." onclick="checkQuiz('quiz-3', this)">15</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>In a code, each letter is replaced by the letter as far from the end of the alphabet as it is from the start (A becomes Z). What is the code for CAT?</p>
                    <button class="quiz-option" data-correct="false" data-explain="That would be a +1 shift; the mirror rule replaces each letter with its opposite number from the end of the alphabet." onclick="checkQuiz('quiz-4', this)">DBU</button>
                    <button class="quiz-option" data-correct="true" data-explain="Mirroring: C becomes X (position 3 to 24), A becomes Z and T becomes G, giving XZG." onclick="checkQuiz('quiz-4', this)">XZG</button>
                    <button class="quiz-option" data-correct="false" data-explain="This reverses the order of letters, which is a different rule from mirroring each letter in place." onclick="checkQuiz('quiz-4', this)">TAC</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what does EJOTY stand for, and how do you solve an invented-language code?</p>
                <p>The answer: E is 5, J is 10, O is 15, T is 20 and Y is 25, giving anchors for letter positions; and word-level codes are solved by intersecting two sentences to find the shared word.</p>
                <div id="fill-1">
                    <p>In the mirror code, A is paired with <input type="text" class="fill-blank" data-answer="Z" placeholder="?" aria-label="mirror partner of A" />. The memory trick EJOTY gives the positions 5, 10, 15, 20 and <input type="text" class="fill-blank" data-answer="25" placeholder="?" aria-label="position of Y" />. If every letter is moved one place forward, CAT becomes <input type="text" class="fill-blank" data-answer="DBU" placeholder="?" aria-label="code for CAT" />. Shared code words between two coded sentences are found by <input type="text" class="fill-blank" data-answer="intersection" placeholder="?" aria-label="method for word-level codes" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A code works like this: the first letter moves one place forward, the second two places forward, the third three places forward, and so on. What is the code for CAT, and what is the code for AB?</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>For CAT: C +1 = D, A +2 = C, T +3 = W, giving <strong>DCW</strong>. The positional rule is the giveaway when a uniform shift fails: if the first letter looks like +1 and the second like +2, the shift is positional, not constant.</p>
                    <p>For AB: A +1 = B, B +2 = D, giving <strong>BD</strong>. The rule works the same for any word length, which is the practical test of whether you have identified it correctly — apply it to a second known pair before answering.</p>
                    <p>Notice also the wrap-around: if a letter crosses Z it continues at A. That is why practising with letters near the end of the alphabet, such as Y and Z, is worth doing before the paper.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Patterns are done. The next lesson turns to a habit that saves marks across the whole quantitative and analytical sections: deciding whether the information you have is actually enough to answer — and being willing to choose "cannot be determined".</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-relations-and-directions">Previous: Relations and Directions</a></span>
                <span><a href="/courses/hat/lessons/hat-data-sufficiency">Next: Is the Information Enough?</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
