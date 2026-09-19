// HAT course — Counting and probability: the product rule, selections, and the complement.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_counting_probability() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Counting and Probability — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Counting and Probability</h1>
            <div class="lesson-meta">15 min · Module 2: Quantitative Reasoning · Counting</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Counting questions ask how many arrangements, committees or codes exist; probability questions ask how likely an outcome is. Both reduce to the same two ideas — multiply when choices happen in sequence, divide when you compare a part with a whole — and both are heavily represented because they are quick to mark and hard to fake.</p>
                <p>The single highest-yield trick in this whole family is the complement: "at least one" is almost always easier as "one minus none". Questions that take three minutes by listing take twenty seconds by complement.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Counting: <strong>multiply along a sequence of choices, add across alternatives.</strong> Probability: <strong>favourable outcomes divided by total outcomes</strong>, where both are counted the same way.</p>
                <div class="formula">probability = favourable &divide; total &nbsp;&nbsp;&nbsp; P(not A) = 1 &minus; P(A)</div>
                <p>The complementary rule deserves its own line because it is a technique, not a definition: whenever a question says <em>at least one</em>, ask what "none" looks like, because "none" is a single product while "at least one" is many cases.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <h3>The product rule</h3>
                <p>If a task has m ways for its first stage and n ways for its second, the pair has m &times; n ways. Three shirts and four trousers give 12 outfits; five digits with no repetition give 5 &times; 4 &times; 3 = 60 three-digit codes.</p>
                <h3>Permutations and combinations</h3>
                <table>
                    <thead>
                        <tr><th scope="col">Situation</th><th scope="col">Formula</th><th scope="col">Example</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Arranging all of n objects</td><td>n! </td><td>5 books: 120 orders</td></tr>
                        <tr><td>Choosing r from n, order matters</td><td>n! &divide; (n &minus; r)!</td><td>President and secretary from 5: 5 &times; 4 = 20</td></tr>
                        <tr><td>Choosing r from n, order irrelevant</td><td>n! &divide; (r! (n &minus; r)!)</td><td>Committee of 2 from 5: 10</td></tr>
                    </tbody>
                </table>
                <p>Values worth knowing cold: 4! = 24, 5! = 120, 6! = 720; selecting 2 from 5 gives 10, 2 from 10 gives 45, 3 from 6 gives 20, 3 from 7 gives 35. The dividing line is the word <em>arrange</em> or <em>order</em>: if different orders count as different outcomes, use permutations; if not, combinations.</p>
                <h3>Probability rules</h3>
                <ul>
                    <li>Probability is always between 0 and 1, so any option outside that range is dead.</li>
                    <li><strong>Independent events:</strong> multiply. Two heads in a row is 1/2 &times; 1/2 = 1/4.</li>
                    <li><strong>Mutually exclusive events:</strong> add. A die showing 2 or 3 is 1/6 + 1/6 = 1/3.</li>
                    <li><strong>Without replacement:</strong> the second denominator shrinks, so the second fraction changes. Two reds from four red and six blue is (4/10) &times; (3/9) = 2/15.</li>
                    <li><strong>At least one:</strong> use the complement. At least one head in three tosses is 1 &minus; (1/2)&sup3; = 7/8.</li>
                    <li><strong>Expected frequency</strong> is probability times trials: 1/4 of 200 is 50.</li>
                </ul>
                <div class="callout callout-tip">
                    <strong>The symmetry shortcut.</strong> If a question asks for the probability of an even number on a fair die, the equally likely outcomes are already the smallest unit — count them rather than forming fractions: 3 even out of 6 gives 1/2 directly.
                </div>
                <div class="callout callout-warn">
                    <strong>Three recurring errors.</strong> (1) Using combinations when the question says "arrange" (or the reverse). (2) Forgetting to shrink the denominator when the first item is not replaced. (3) Adding probabilities of events that are not mutually exclusive — rain and wind can happen together, so their probabilities must not simply be added.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked Examples</h2>
                <h3>1. A committee of 3 is chosen from 7 people. How many committees are possible?</h3>
                <p>Order is irrelevant, so use combinations: 7 &times; 6 &times; 5 &divide; (3 &times; 2 &times; 1) = 210 &divide; 6 = <strong>35</strong>.</p>
                <h3>2. Two fair dice are rolled. What is the probability that the sum is 8?</h3>
                <p>Total outcomes 6 &times; 6 = 36. Favourable pairs: (2,6), (3,5), (4,4), (5,3), (6,2) — five of them. Probability = 5/36, which is about 0.139.</p>
                <h3>3. A bag holds 4 red and 6 blue balls. Two are drawn without replacement. What is the probability both are red?</h3>
                <p>(4/10) &times; (3/9) = 12/90 = <strong>2/15</strong>. The second fraction uses 3/9 because one red ball has left the bag: forgetting that gives the wrong answer 16/100.</p>
                <h3>4. A coin is tossed four times. What is the probability of at least one head?</h3>
                <p>Complement: the only case with no head is TTTT, whose probability is (1/2)&#8308; = 1/16. So the answer is 1 &minus; 1/16 = <strong>15/16</strong>. Listing the fifteen favourable cases would take a minute; the complement takes ten seconds.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="quiz" id="quiz-1">
                    <p>A three-digit code is formed from 1 to 5 with no repetition. How many codes are possible?</p>
                    <button class="quiz-option" data-correct="false" data-explain="125 comes from 5 &times; 5 &times; 5, which allows a digit to repeat; the question forbids repetition." onclick="checkQuiz('quiz-1', this)">125</button>
                    <button class="quiz-option" data-correct="true" data-explain="First digit 5 choices, second 4, third 3, so 5 &times; 4 &times; 3 = 60 codes with no repetition." onclick="checkQuiz('quiz-1', this)">60</button>
                    <button class="quiz-option" data-correct="false" data-explain="15 is 5 + 4 + 3, which adds the choices instead of multiplying them along the sequence." onclick="checkQuiz('quiz-1', this)">15</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-2">
                    <p>A card is drawn from a standard pack. What is the probability that it is a heart or a king?</p>
                    <button class="quiz-option" data-correct="false" data-explain="17/52 double-counts the king of hearts, which is both a heart and a king." onclick="checkQuiz('quiz-2', this)">17/52</button>
                    <button class="quiz-option" data-correct="true" data-explain="13 hearts plus 4 kings minus the 1 double-counted king of hearts gives 16 favourable cards out of 52." onclick="checkQuiz('quiz-2', this)">16/52</button>
                    <button class="quiz-option" data-correct="false" data-explain="4/52 counts only the kings and ignores the hearts entirely." onclick="checkQuiz('quiz-2', this)">4/52</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-3">
                    <p>A fair coin is tossed twice. What is the probability of at least one tail?</p>
                    <button class="quiz-option" data-correct="false" data-explain="1/2 is the probability of a tail on one toss; the question asks about two tosses together." onclick="checkQuiz('quiz-3', this)">1/2</button>
                    <button class="quiz-option" data-correct="true" data-explain="P(no tail at all) = 1/4, so P(at least one tail) = 1 &minus; 1/4 = 3/4." onclick="checkQuiz('quiz-3', this)">3/4</button>
                    <button class="quiz-option" data-correct="false" data-explain="1/4 is the probability of no tails, which is the complement of the answer rather than the answer." onclick="checkQuiz('quiz-3', this)">1/4</button>
                    <div class="quiz-feedback"></div>
                </div>
                <div class="quiz" id="quiz-4">
                    <p>A box holds 3 defective and 7 good items. Two are chosen at random without replacement. What is the probability that both are good?</p>
                    <button class="quiz-option" data-correct="false" data-explain="49/100 treats the second draw as a fresh bag of ten, ignoring that one good item has already gone." onclick="checkQuiz('quiz-4', this)">49/100</button>
                    <button class="quiz-option" data-correct="true" data-explain="(7/10) &times; (6/9) = 42/90 = 7/15, the correct without-replacement probability." onclick="checkQuiz('quiz-4', this)">7/15</button>
                    <button class="quiz-option" data-correct="false" data-explain="3/10 is the probability of drawing a defective item, not the chance of two good draws." onclick="checkQuiz('quiz-4', this)">3/10</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: when do you multiply probabilities, and how do you handle "at least one"?</p>
                <p>The answer: multiply for independent events happening together; use 1 minus the probability of none for "at least one".</p>
                <div id="fill-1">
                    <p>Probabilities of independent events are <input type="text" class="fill-blank" data-answer="multiplied" placeholder="?" aria-label="operation for independent events" />. To find the probability of at least one success, subtract the probability of <input type="text" class="fill-blank" data-answer="none" placeholder="?" aria-label="complement case" /> from 1. When selecting without replacement, the denominator of the second draw <input type="text" class="fill-blank" data-answer="decreases" placeholder="?" aria-label="change in denominator" />. Choosing a committee ignores order, so it uses combinations rather than <input type="text" class="fill-blank" data-answer="permutations" placeholder="?" aria-label="ordered selections" />.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A question asks: "In how many ways can 2 boys and 2 girls be chosen from 4 boys and 3 girls?" Solve it, then say what changes if the question instead asks for the probability that a random committee of 4 contains exactly 2 girls.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Choosing is unordered, so multiply the two combinations: 2 boys from 4 is 6 ways (4 &times; 3 &divide; 2), and 2 girls from 3 is 3 ways, giving <strong>18</strong> committees.</p>
                    <p>For the probability version, count the total committees of 4 from 7 people: 7 &times; 6 &times; 5 &times; 4 &divide; 24 = 35. The probability is 18/35, which is about 0.514 — just over a half.</p>
                    <p>The lesson in the transformation is that counting and probability are the same skill applied twice: probability is a favourable count over a total count, so once the counting is right the probability is one division away.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You have now covered every quantitative family in this course. The next lesson stops teaching and starts training: a timed mixed set that forces you to choose the right technique under a clock, which is the only skill that matters on the day.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-work-rate">Previous: Work, Pipes and Rates</a></span>
                <span><a href="/courses/hat/lessons/hat-quant-drill">Next: Quantitative Drill</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
