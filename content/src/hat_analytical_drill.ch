// HAT course — Analytical drill: a timed 20-question mixed set with full answer key.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_analytical_drill() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Analytical Drill — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)
    render_hat_drill_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Analytical Drill: 20 Questions in 24 Minutes</h1>
            <div class="lesson-meta">30 min · Module 4: Analytical Reasoning · Timed drill</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The analytical section punishes hesitation more than the other two. Its questions are not hard individually; they are slow unless the procedure is already in your hands. This drill mixes the families in the order the paper tends to use them, and the clock is the real one: 72 seconds per question.</p>
                <p>Work with paper. Draw the strips, the grid, the compass and the family tree. Candidates who try to hold these puzzles in their heads take twice as long and score half as well — this drill exists to make that point once, cheaply.</p>
            </div>

            <div class="unit unit-model">
                <h2>The Protocol</h2>
                <ol>
                    <li><strong>24 minutes, drawing allowed, calculator irrelevant.</strong> Set a visible timer and write a, b, c, d answers.</li>
                    <li><strong>Draw for every puzzle.</strong> Sub-questions 1 to 5 and the whole of part E reward a diagram.</li>
                    <li><strong>At 12 minutes you should be at question 10.</strong> If not, apply the 40-second look and flag the slow items.</li>
                    <li><strong>Answer all 20.</strong> No negative marking, so blanks are self-inflicted zeros.</li>
                    <li><strong>Self-mark, log causes, retake in 7 days.</strong> Target: 16 or more correct inside 24 minutes.</li>
                </ol>
                <h3>Or take it timed, here in the browser</h3>
                <p>Everything below is the same paper with the same answer key. The runner adds the clock, marks your answers, explains every miss, and keeps your result so the retake in seven days can be compared against this one. Nothing is sent anywhere; the score stays in this browser.</p>
                <div id="hat-drill-root" class="hat-drill"><p>Loading the drill&hellip;</p></div>
                <noscript><p>The timed runner needs JavaScript. The printed paper and the answer key above work without it.</p></noscript>
            </div>

            <div class="unit unit-reality">
                <h2>The Paper</h2>
                <h3>Part A — Seating (Questions 1-3)</h3>
                <p>Five students A, B, C, D and E sit in a row of five seats, numbered 1 to 5 from left to right. C sits in the middle seat. A sits at the extreme left. D sits immediately to the right of C. B is not adjacent to E. E does not sit at either end.</p>
                <ol class="drill">
                    <li><strong>Q1.</strong> Who sits in seat 2?<br />(a) B &nbsp;&nbsp; (b) E &nbsp;&nbsp; (c) C &nbsp;&nbsp; (d) D</li>
                    <li><strong>Q2.</strong> Who sits at the extreme right?<br />(a) B &nbsp;&nbsp; (b) D &nbsp;&nbsp; (c) E &nbsp;&nbsp; (d) A</li>
                    <li><strong>Q3.</strong> Who sits immediately to the left of D?<br />(a) A &nbsp;&nbsp; (b) C &nbsp;&nbsp; (c) E &nbsp;&nbsp; (d) B</li>
                </ol>
                <h3>Part B — Scheduling (Questions 4-5)</h3>
                <p>Four talks T1, T2, T3 and T4 are held on four consecutive days, Monday to Thursday, one per day. T2 is on Tuesday. T4 is held after T3. T1 is not on Monday.</p>
                <ol class="drill" start="4">
                    <li><strong>Q4.</strong> Which talk is held on Monday?<br />(a) T1 &nbsp;&nbsp; (b) T3 &nbsp;&nbsp; (c) T4 &nbsp;&nbsp; (d) cannot be determined</li>
                    <li><strong>Q5.</strong> Which talk is held on Wednesday?<br />(a) T1 &nbsp;&nbsp; (b) T4 &nbsp;&nbsp; (c) T3 &nbsp;&nbsp; (d) cannot be determined</li>
                </ol>
                <h3>Part C — Syllogisms (Questions 6-7)</h3>
                <ol class="drill" start="6">
                    <li><strong>Q6.</strong> All poets are dreamers. No dreamers are practical. Which follows?<br />(a) No poets are practical &nbsp;&nbsp; (b) Some poets are practical &nbsp;&nbsp; (c) All practical people are poets &nbsp;&nbsp; (d) Nothing follows</li>
                    <li><strong>Q7.</strong> Some birds cannot fly. All penguins are birds. Which follows?<br />(a) Some penguins cannot fly &nbsp;&nbsp; (b) All penguins cannot fly &nbsp;&nbsp; (c) No penguins can fly &nbsp;&nbsp; (d) Nothing follows</li>
                </ol>
                <h3>Part D — Relations (Questions 8-9)</h3>
                <ol class="drill" start="8">
                    <li><strong>Q8.</strong> A is the mother of B. B is the sister of C. C is the father of D. How is A related to D?<br />(a) Mother &nbsp;&nbsp; (b) Aunt &nbsp;&nbsp; (c) Grandmother &nbsp;&nbsp; (d) Sister</li>
                    <li><strong>Q9.</strong> P is the brother of Q. Q is the wife of R. R is the father of S. How is P related to S?<br />(a) Father &nbsp;&nbsp; (b) Maternal uncle &nbsp;&nbsp; (c) Brother &nbsp;&nbsp; (d) Cousin</li>
                </ol>
                <h3>Part E — Directions (Questions 10-11)</h3>
                <ol class="drill" start="10">
                    <li><strong>Q10.</strong> A man walks 6 km south, then turns and walks 8 km east. How far is he from his starting point?<br />(a) 2 km &nbsp;&nbsp; (b) 10 km &nbsp;&nbsp; (c) 14 km &nbsp;&nbsp; (d) 48 km</li>
                    <li><strong>Q11.</strong> A woman starts facing north, turns right twice and then left once. Which direction is she facing?<br />(a) North &nbsp;&nbsp; (b) South &nbsp;&nbsp; (c) East &nbsp;&nbsp; (d) West</li>
                </ol>
                <h3>Part F — Coding (Questions 12-13)</h3>
                <ol class="drill" start="12">
                    <li><strong>Q12.</strong> If CAT is coded as DBU, how is DOG coded?<br />(a) EPH &nbsp;&nbsp; (b) CNG &nbsp;&nbsp; (c) EPI &nbsp;&nbsp; (d) FQI</li>
                    <li><strong>Q13.</strong> If MOTHER is coded as REHTOM, how is FATHER coded?<br />(a) GBUIFS &nbsp;&nbsp; (b) REHTAF &nbsp;&nbsp; (c) RETHAF &nbsp;&nbsp; (d) FATHEE</li>
                </ol>
                <h3>Part G — Series (Questions 14-16)</h3>
                <ol class="drill" start="14">
                    <li><strong>Q14.</strong> What comes next: 2, 5, 10, 17, 26, ?<br />(a) 35 &nbsp;&nbsp; (b) 37 &nbsp;&nbsp; (c) 39 &nbsp;&nbsp; (d) 40</li>
                    <li><strong>Q15.</strong> What comes next: 3, 6, 12, 24, ?<br />(a) 30 &nbsp;&nbsp; (b) 36 &nbsp;&nbsp; (c) 48 &nbsp;&nbsp; (d) 96</li>
                    <li><strong>Q16.</strong> What comes next: A, C, F, J, ?<br />(a) M &nbsp;&nbsp; (b) N &nbsp;&nbsp; (c) O &nbsp;&nbsp; (d) P</li>
                </ol>
                <h3>Part H — Data interpretation (Questions 17-18)</h3>
                <ol class="drill" start="17">
                    <li><strong>Q17.</strong> Enrolment rises from 300 to 350 students. What is the percentage increase?<br />(a) 14.3% &nbsp;&nbsp; (b) 16.7% &nbsp;&nbsp; (c) 25% &nbsp;&nbsp; (d) 50%</li>
                    <li><strong>Q18.</strong> Department A grows from 120 to 150 staff; department B from 80 to 100. Which grew faster in percentage terms?<br />(a) A &nbsp;&nbsp; (b) B &nbsp;&nbsp; (c) the same rate &nbsp;&nbsp; (d) cannot be determined from the totals</li>
                </ol>
                <h3>Part I — Data sufficiency (Questions 19-20)</h3>
                <ol class="drill" start="19">
                    <li><strong>Q19.</strong> What is the value of x? (1) x + y = 10 (2) y = 4<br />(a) (1) alone is sufficient &nbsp;&nbsp; (b) (2) alone is sufficient &nbsp;&nbsp; (c) both together, neither alone &nbsp;&nbsp; (d) neither, even together</li>
                    <li><strong>Q20.</strong> Is n an even number? (1) n is a multiple of 6 (2) n is greater than 10<br />(a) (1) alone is sufficient &nbsp;&nbsp; (b) (2) alone is sufficient &nbsp;&nbsp; (c) both together, neither alone &nbsp;&nbsp; (d) neither, even together</li>
                </ol>
            </div>

            <div class="unit unit-example">
                <h2>Answer Key</h2>
                <table>
                    <thead>
                        <tr><th scope="col">Q</th><th scope="col">Family</th><th scope="col">Answer</th><th scope="col">Reasoning</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1</td><td>Seating</td><td>(b) E</td><td>The only arrangement is A, E, C, D, B: C is middle, A is leftmost, D is immediately right of C, and E is not at an end, so E takes seat 2 and B seat 5</td></tr>
                        <tr><td>2</td><td>Seating</td><td>(a) B</td><td>Seat 5 is the extreme right in A, E, C, D, B</td></tr>
                        <tr><td>3</td><td>Seating</td><td>(b) C</td><td>D is in seat 4 and C in seat 3, so C is immediately to its left</td></tr>
                        <tr><td>4</td><td>Scheduling</td><td>(b) T3</td><td>T2 is fixed on Tuesday. T1 cannot be Monday, and T4 must come after T3, so T3 is forced onto Monday in every valid arrangement</td></tr>
                        <tr><td>5</td><td>Scheduling</td><td>(d) cannot be determined</td><td>The two valid arrangements are T3, T2, T1, T4 and T3, T2, T4, T1, so Wednesday is T1 in one and T4 in the other</td></tr>
                        <tr><td>6</td><td>Syllogism</td><td>(a) No poets are practical</td><td>Poets sit inside dreamers, and the dreamers circle avoids practical things entirely, so no poet is practical</td></tr>
                        <tr><td>7</td><td>Syllogism</td><td>(d) Nothing follows</td><td>The flightless birds may all lie outside the penguin circle; the overlap between penguins and non-flying birds is not guaranteed</td></tr>
                        <tr><td>8</td><td>Relations</td><td>(c) Grandmother</td><td>A is a parent of B, B and C are siblings so A is also C's parent, and C is D's father</td></tr>
                        <tr><td>9</td><td>Relations</td><td>(b) Maternal uncle</td><td>Q is S's mother through R, and P is Q's brother, which makes P S's uncle on the mother's side</td></tr>
                        <tr><td>10</td><td>Directions</td><td>(b) 10 km</td><td>6 km south and 8 km east form a 6-8-10 triangle; adding the legs gives the wrong 14 km</td></tr>
                        <tr><td>11</td><td>Directions</td><td>(c) East</td><td>North to east to south, then a left turn from south leads to east</td></tr>
                        <tr><td>12</td><td>Coding</td><td>(a) EPH</td><td>Every letter shifts one place forward: D to E, O to P, G to H</td></tr>
                        <tr><td>13</td><td>Coding</td><td>(b) REHTAF</td><td>The code reverses the word, so FATHER becomes REHTAF</td></tr>
                        <tr><td>14</td><td>Series</td><td>(b) 37</td><td>Differences are 3, 5, 7, 9 and then 11, so 26 + 11 = 37</td></tr>
                        <tr><td>15</td><td>Series</td><td>(c) 48</td><td>Each term doubles, so the next is 48; option 96 is the term after that</td></tr>
                        <tr><td>16</td><td>Series</td><td>(c) O</td><td>Letter gaps increase by one each time: plus 2, plus 3, plus 4, then plus 5 places from J gives O</td></tr>
                        <tr><td>17</td><td>Data</td><td>(b) 16.7%</td><td>50 divided by the original 300; dividing by 350 gives the trap answer 14.3%</td></tr>
                        <tr><td>18</td><td>Data</td><td>(c) the same rate</td><td>A grew 30 on 120 and B grew 20 on 80; both are 25%, so the smaller absolute rise is the same percentage</td></tr>
                        <tr><td>19</td><td>Sufficiency</td><td>(c) both together, neither alone</td><td>(1) leaves x dependent on y and (2) says nothing about x; together x = 6</td></tr>
                        <tr><td>20</td><td>Sufficiency</td><td>(a) (1) alone is sufficient</td><td>Every multiple of 6 is even, so the question is answered; being greater than 10 says nothing about parity</td></tr>
                    </tbody>
                </table>
            </div>

            <div class="unit unit-interact">
                <h2>Read Your Score</h2>
                <table>
                    <thead>
                        <tr><th scope="col">Score in 24 min</th><th scope="col">What it means</th><th scope="col">Next action</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>16-20</td><td>Procedures are in place</td><td>Rehearse under the real 30-mark budget: 36 minutes for the analytical section</td></tr>
                        <tr><td>12-15</td><td>One family is still slow or unreliable</td><td>Identify the family from the key and redo its lesson and quizzes before the retake</td></tr>
                        <tr><td>8-11</td><td>Drawing is not yet automatic</td><td>Redo parts A, B and E with a diagram on paper for every single item</td></tr>
                        <tr><td>Below 8</td><td>Rebuild the procedures</td><td>Work seating, ordering and syllogisms in order, then retake this set cold</td></tr>
                    </tbody>
                </table>
                <p>Also record your position at 12 minutes. Reaching question 10 by then is the pacing standard for the real paper, where analytical shares the clock with everything else.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Log the Result</h2>
                <div id="fill-1">
                    <p>This set has <input type="text" class="fill-blank" data-answer="20" placeholder="?" aria-label="questions in the drill" /> questions to be done in 24 minutes, with a pass mark of <input type="text" class="fill-blank" data-answer="16" placeholder="?" aria-label="pass mark" />. At the halfway point I should be at question <input type="text" class="fill-blank" data-answer="10" placeholder="?" aria-label="halfway position" />, and my retake goes in the calendar <input type="text" class="fill-blank" data-answer="7" placeholder="?" aria-label="days until retake" /> days from today.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You scored 14/20 and finished with three questions untouched. Your misses were Q5, Q7, Q11 and Q16. Write the repair plan, and say which single habit would have saved the most marks.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>Look at what the four misses have in common rather than treating them as four topics. Q5 is a "cannot be determined" answer you probably forced; Q7 is a syllogism where you supplied outside knowledge about penguins; Q11 is a turn sequence mis-applied; Q16 is a series where the gap pattern was not written down. Three of the four were caused by answering from memory instead of from paper.</p>
                    <p>The habit that would have saved the most marks is writing the diagram or the difference table before answering: a compass sketch for Q11, a gap table for Q16, circles for Q7. Untouched questions reinforce the same point — with 72 seconds per item there is no time to hold a puzzle in your head and also finish the set.</p>
                    <p>Plan: day 1, redo Q5, Q7, Q11 and Q16 from scratch, on paper, and write the rule each one tested. Day 2, a fresh mixed set of 20 with a diagram drawn for every single item, even where it feels unnecessary — the point is to break the shortcut habit. Day 3, retake this drill and compare both the score and the position at 12 minutes.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>All three sections are now covered and drilled. The final module turns to the thing that turns knowledge into a score on the day: full-length simulation, a defined review practice, score targets, and a taper that leaves you sharp rather than tired.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-pattern-series">Previous: Number and Letter Series</a></span>
                <span><a href="/courses/hat/lessons/hat-mock-protocol">Next: How to Run a Mock Test</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)
    render_hat_analytical_drill_bank(&mut page)
    render_hat_analytical_drill_config(&mut page)
    render_hat_drill_js(&mut page)

    return page.toString()
}
}
