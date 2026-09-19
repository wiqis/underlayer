// HAT course — Verbal drill: a timed 30-question set with full answer key.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_verbal_drill() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Verbal Drill — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/courses/hat" class="back-link">Back to course</a>
            <h1>Verbal Drill: 30 Questions in 36 Minutes</h1>
            <div class="lesson-meta">40 min · Module 3: Verbal Reasoning · Timed drill</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Verbal marks are won by two separate skills: knowing the material, and recognising the question type fast enough to apply it. This drill trains the second. Thirty items in thirty-six minutes is the real paper's verbal pace — 72 seconds each — and the mix is deliberate: vocabulary, relationships, sentence logic, grammar, collocations and a passage, in the order in which they tend to appear.</p>
                <p>The reading passage at the end is where most candidates lose their pacing. Discipline: four minutes for the passage and its four questions, no re-reading.</p>
            </div>

            <div class="unit unit-model">
                <h2>The Protocol</h2>
                <ol>
                    <li><strong>36 minutes, no dictionary, no notes.</strong> Answers as a, b, c, d on paper.</li>
                    <li><strong>Answer all 30.</strong> There is no negative marking, so blanks are donated marks.</li>
                    <li><strong>Order matters.</strong> Do vocabulary and analogies first — they are the fastest — and leave the passage for last if it suits your pacing.</li>
                    <li><strong>Self-mark with the key</strong>, and write the cause of each miss in one line.</li>
                    <li><strong>Retake in 7 days.</strong> Target: 25 or more, with the passage answered in under 4 minutes.</li>
                </ol>
            </div>

            <div class="unit unit-reality">
                <h2>The Paper</h2>
                <h3>Part A — Vocabulary (Questions 1-8)</h3>
                <ol class="drill">
                    <li><strong>Q1.</strong> LUCID most nearly means:<br />(a) dim &nbsp;&nbsp; (b) clear &nbsp;&nbsp; (c) loud &nbsp;&nbsp; (d) confused</li>
                    <li><strong>Q2.</strong> Choose the word most nearly opposite to CANDID.<br />(a) frank &nbsp;&nbsp; (b) evasive &nbsp;&nbsp; (c) honest &nbsp;&nbsp; (d) open</li>
                    <li><strong>Q3.</strong> GREGARIOUS most nearly means:<br />(a) solitary &nbsp;&nbsp; (b) sociable &nbsp;&nbsp; (c) hostile &nbsp;&nbsp; (d) silent</li>
                    <li><strong>Q4.</strong> EPHEMERAL most nearly means:<br />(a) eternal &nbsp;&nbsp; (b) short-lived &nbsp;&nbsp; (c) fragile &nbsp;&nbsp; (d) costly</li>
                    <li><strong>Q5.</strong> MITIGATE most nearly means:<br />(a) to worsen &nbsp;&nbsp; (b) to lessen &nbsp;&nbsp; (c) to measure &nbsp;&nbsp; (d) to deny</li>
                    <li><strong>Q6.</strong> PARSIMONIOUS most nearly means:<br />(a) generous &nbsp;&nbsp; (b) stingy &nbsp;&nbsp; (c) wealthy &nbsp;&nbsp; (d) wasteful</li>
                    <li><strong>Q7.</strong> Choose the word most nearly opposite to DILIGENT.<br />(a) hard-working &nbsp;&nbsp; (b) indolent &nbsp;&nbsp; (c) careful &nbsp;&nbsp; (d) punctual</li>
                    <li><strong>Q8.</strong> PREVALENT most nearly means:<br />(a) rare &nbsp;&nbsp; (b) widespread &nbsp;&nbsp; (c) ancient &nbsp;&nbsp; (d) valuable</li>
                </ol>
                <h3>Part B — Analogies (Questions 9-13)</h3>
                <ol class="drill" start="9">
                    <li><strong>Q9.</strong> PEN : WRITE :: KNIFE : ?<br />(a) sharp &nbsp;&nbsp; (b) cut &nbsp;&nbsp; (c) kitchen &nbsp;&nbsp; (d) metal</li>
                    <li><strong>Q10.</strong> DOCTOR : PATIENT :: LAWYER : ?<br />(a) court &nbsp;&nbsp; (b) client &nbsp;&nbsp; (c) judge &nbsp;&nbsp; (d) law</li>
                    <li><strong>Q11.</strong> SCALE : WEIGHT :: THERMOMETER : ?<br />(a) mercury &nbsp;&nbsp; (b) temperature &nbsp;&nbsp; (c) degrees &nbsp;&nbsp; (d) heat</li>
                    <li><strong>Q12.</strong> STARVATION : FOOD :: DEHYDRATION : ?<br />(a) thirst &nbsp;&nbsp; (b) water &nbsp;&nbsp; (c) desert &nbsp;&nbsp; (d) heat</li>
                    <li><strong>Q13.</strong> CHAPTER : BOOK :: ACT : ?<br />(a) scene &nbsp;&nbsp; (b) play &nbsp;&nbsp; (c) actor &nbsp;&nbsp; (d) stage</li>
                </ol>
                <h3>Part C — Sentence completion (Questions 14-19)</h3>
                <ol class="drill" start="14">
                    <li><strong>Q14.</strong> Although the plan was ambitious, it was ___.<br />(a) practical &nbsp;&nbsp; (b) impractical &nbsp;&nbsp; (c) approved &nbsp;&nbsp; (d) economical</li>
                    <li><strong>Q15.</strong> The professor was known for her ___ lectures: no student ever needed to ask for clarification.<br />(a) convoluted &nbsp;&nbsp; (b) lucid &nbsp;&nbsp; (c) lengthy &nbsp;&nbsp; (d) dull</li>
                    <li><strong>Q16.</strong> He was ___ in his praise, offering only the faintest compliments.<br />(a) lavish &nbsp;&nbsp; (b) sparing &nbsp;&nbsp; (c) excessive &nbsp;&nbsp; (d) sincere</li>
                    <li><strong>Q17.</strong> Because the evidence was ___, the court dismissed the case.<br />(a) conclusive &nbsp;&nbsp; (b) insufficient &nbsp;&nbsp; (c) overwhelming &nbsp;&nbsp; (d) documented</li>
                    <li><strong>Q18.</strong> The team worked ___, finishing every task two days before the deadline.<br />(a) negligently &nbsp;&nbsp; (b) diligently &nbsp;&nbsp; (c) reluctantly &nbsp;&nbsp; (d) nervously</li>
                    <li><strong>Q19.</strong> The decision was unanimous; every member ___.<br />(a) objected &nbsp;&nbsp; (b) agreed &nbsp;&nbsp; (c) abstained &nbsp;&nbsp; (d) hesitated</li>
                </ol>
                <h3>Part D — Grammar and error identification (Questions 20-23)</h3>
                <ol class="drill" start="20">
                    <li><strong>Q20.</strong> The list of items ___ long.<br />(a) are &nbsp;&nbsp; (b) is &nbsp;&nbsp; (c) have &nbsp;&nbsp; (d) were</li>
                    <li><strong>Q21.</strong> Neither the manager nor the clerks ___ ready when the audit began.<br />(a) was &nbsp;&nbsp; (b) were &nbsp;&nbsp; (c) is &nbsp;&nbsp; (d) has been</li>
                    <li><strong>Q22.</strong> Find the error: "She is senior than me in the department."<br />(a) senior &nbsp;&nbsp; (b) than &nbsp;&nbsp; (c) me &nbsp;&nbsp; (d) no error</li>
                    <li><strong>Q23.</strong> Which sentence is grammatically correct?<br />(a) Walking down the corridor, the report was found &nbsp;&nbsp; (b) Each of the candidates has submitted a form &nbsp;&nbsp; (c) Ten kilometres are a long walk &nbsp;&nbsp; (d) A number of students was absent</li>
                </ol>
                <h3>Part E — Prepositions and confused words (Questions 24-26)</h3>
                <ol class="drill" start="24">
                    <li><strong>Q24.</strong> All staff must comply ___ the new rules.<br />(a) to &nbsp;&nbsp; (b) with &nbsp;&nbsp; (c) by &nbsp;&nbsp; (d) for</li>
                    <li><strong>Q25.</strong> The delay had no ___ on the final schedule.<br />(a) affect &nbsp;&nbsp; (b) effect &nbsp;&nbsp; (c) effort &nbsp;&nbsp; (d) affected</li>
                    <li><strong>Q26.</strong> She is not afraid ___ criticism.<br />(a) from &nbsp;&nbsp; (b) of &nbsp;&nbsp; (c) to &nbsp;&nbsp; (d) with</li>
                </ol>
                <h3>Part F — Reading comprehension (Questions 27-30)</h3>
                <p>Sleep is not simply the absence of waking activity. Over the past two decades, experiments have shown that a night's sleep after learning alters how much of that material is retained the next day. In one representative design, participants memorised pairs of unrelated words in the evening; half then slept in the laboratory while the others stayed awake. On testing the following morning, the sleepers recalled substantially more pairs. Recordings of brain activity suggest that the benefit coincides with slow-wave sleep, the deepest stage of the night.</p>
                <p>Not everyone accepts that sleep actively strengthens memories. A rival account holds that sleep contributes mainly by shielding new memories from interference: wakefulness brings fresh experience, and fresh experience competes with what was learned earlier. On this view the sleepers recall more because they encountered less, not because sleep reorganised anything. Distinguishing the two explanations is difficult, since a sleeping brain cannot be prevented from processing what it has just learned. Both accounts agree on the practical point, however: material learned shortly before sleep tends to survive better.</p>
                <ol class="drill" start="27">
                    <li><strong>Q27.</strong> The passage is chiefly concerned with:<br />(a) proving that sleep deprivation causes permanent harm &nbsp;&nbsp; (b) the association between sleep and the retention of recently learned material &nbsp;&nbsp; (c) describing the stages of a normal night's sleep &nbsp;&nbsp; (d) showing that laboratory experiments on memory are unreliable</li>
                    <li><strong>Q28.</strong> In the experiment described, the participants who stayed awake:<br />(a) recalled more word pairs &nbsp;&nbsp; (b) recalled fewer word pairs &nbsp;&nbsp; (c) slept in the laboratory after testing &nbsp;&nbsp; (d) were tested in the evening</li>
                    <li><strong>Q29.</strong> The rival account is mentioned in order to:<br />(a) present an alternative explanation of the same result &nbsp;&nbsp; (b) show that the experiment was fabricated &nbsp;&nbsp; (c) explain why slow-wave sleep matters &nbsp;&nbsp; (d) argue that memory cannot be studied at all</li>
                    <li><strong>Q30.</strong> Which statement is best supported by the passage?<br />(a) Slow-wave sleep is the only stage that affects memory &nbsp;&nbsp; (b) Studying shortly before sleep may improve later recall &nbsp;&nbsp; (c) The two explanations have been fully distinguished &nbsp;&nbsp; (d) Sleep has no measurable effect on learning</li>
                </ol>
            </div>

            <div class="unit unit-example">
                <h2>Answer Key</h2>
                <table>
                    <thead>
                        <tr><th scope="col">Q</th><th scope="col">Type</th><th scope="col">Answer</th><th scope="col">Why</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1</td><td>Vocabulary</td><td>(b) clear</td><td>Lucid means clear and easy to understand; dim is the physical sense of light</td></tr>
                        <tr><td>2</td><td>Antonym</td><td>(b) evasive</td><td>Candid is frank; evasive is the opposite pole. The other options are synonyms of candid</td></tr>
                        <tr><td>3</td><td>Vocabulary</td><td>(b) sociable</td><td>From the root greg, a flock: gregarious people enjoy company</td></tr>
                        <tr><td>4</td><td>Vocabulary</td><td>(b) short-lived</td><td>Ephemeral is lasting a very short time; fragile is about breaking, not lasting</td></tr>
                        <tr><td>5</td><td>Vocabulary</td><td>(b) to lessen</td><td>Mitigate means to make less severe; its opposite pole is exacerbate</td></tr>
                        <tr><td>6</td><td>Vocabulary</td><td>(b) stingy</td><td>Parsimonious is excessively sparing with money; wasteful is its opposite</td></tr>
                        <tr><td>7</td><td>Antonym</td><td>(b) indolent</td><td>Diligent means hard-working; indolent means lazy. Option (a) is a synonym</td></tr>
                        <tr><td>8</td><td>Vocabulary</td><td>(b) widespread</td><td>Prevalent means common or widespread; rare is its opposite</td></tr>
                        <tr><td>9</td><td>Analogy</td><td>(b) cut</td><td>Object to the action it performs: a pen writes, a knife cuts</td></tr>
                        <tr><td>10</td><td>Analogy</td><td>(b) client</td><td>Professional to the person served: a doctor has patients, a lawyer has clients</td></tr>
                        <tr><td>11</td><td>Analogy</td><td>(b) temperature</td><td>Instrument to the quantity it measures; mercury is what it contains, degrees the unit</td></tr>
                        <tr><td>12</td><td>Analogy</td><td>(b) water</td><td>Condition to what is lacking: starvation is the lack of food, dehydration of water</td></tr>
                        <tr><td>13</td><td>Analogy</td><td>(b) play</td><td>Part to whole: a chapter is part of a book, an act is part of a play. Option (a) scene reverses the relation</td></tr>
                        <tr><td>14</td><td>Completion</td><td>(b) impractical</td><td>Although signals contrast, so the blank opposes ambitious</td></tr>
                        <tr><td>15</td><td>Completion</td><td>(b) lucid</td><td>The colon explains: no one needed clarification because the lectures were clear</td></tr>
                        <tr><td>16</td><td>Completion</td><td>(b) sparing</td><td>Faint compliments mean praise given reluctantly, that is sparing</td></tr>
                        <tr><td>17</td><td>Completion</td><td>(b) insufficient</td><td>Dismissal follows from evidence that was not enough; conclusive and overwhelming point the other way</td></tr>
                        <tr><td>18</td><td>Completion</td><td>(b) diligently</td><td>Finishing early indicates hard work, not reluctance or negligence</td></tr>
                        <tr><td>19</td><td>Completion</td><td>(b) agreed</td><td>Unanimous means all in agreement, so every member agreed</td></tr>
                        <tr><td>20</td><td>Agreement</td><td>(b) is</td><td>The subject is the singular list; items sits inside a prepositional phrase</td></tr>
                        <tr><td>21</td><td>Agreement</td><td>(b) were</td><td>With neither ... nor the verb follows the nearer subject, which is the plural clerks</td></tr>
                        <tr><td>22</td><td>Error</td><td>(b) than</td><td>Senior takes to, never than: senior to me</td></tr>
                        <tr><td>23</td><td>Error</td><td>(b)</td><td>Each is singular so has is right. (a) dangles, (c) treats a distance as plural, (d) needs were</td></tr>
                        <tr><td>24</td><td>Preposition</td><td>(b) with</td><td>Comply with is the fixed pairing</td></tr>
                        <tr><td>25</td><td>Confused word</td><td>(b) effect</td><td>A noun is required after had no; affect is the verb</td></tr>
                        <tr><td>26</td><td>Preposition</td><td>(b) of</td><td>Afraid of, like aware of and capable of</td></tr>
                        <tr><td>27</td><td>Main idea</td><td>(b)</td><td>The passage surveys the link between sleep and retention, including a dispute about its cause</td></tr>
                        <tr><td>28</td><td>Detail</td><td>(b)</td><td>The sleepers recalled substantially more, so those who stayed awake recalled fewer</td></tr>
                        <tr><td>29</td><td>Purpose</td><td>(a)</td><td>The interference account offers a different explanation of the same finding</td></tr>
                        <tr><td>30</td><td>Inference</td><td>(b)</td><td>The closing sentence states that material learned shortly before sleep survives better. The others overreach: only, fully and no measurable effect are not supported</td></tr>
                    </tbody>
                </table>
            </div>

            <div class="unit unit-interact">
                <h2>Read Your Score</h2>
                <table>
                    <thead>
                        <tr><th scope="col">Score in 36 min</th><th scope="col">What it means</th><th scope="col">Next action</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>25-30</td><td>Verbal is a source of marks, not damage</td><td>Hold with a daily ten-word review; spend remaining time on analytical puzzles</td></tr>
                        <tr><td>20-24</td><td>One or two weak families</td><td>Identify whether your misses cluster in vocabulary, grammar or the passage, and repair that one</td></tr>
                        <tr><td>15-19</td><td>Word knowledge needs volume</td><td>Ten new words a day with sentences; rerun parts A to C in three days</td></tr>
                        <tr><td>Below 15</td><td>Rebuild the rules</td><td>Work grammar agreement and prepositions again, then retake the full drill</td></tr>
                    </tbody>
                </table>
                <p>Note separately how long the passage took. If questions 27 to 30 took more than five minutes, the fix is a pacing change, not a vocabulary one: read the question stems before the passage, and answer detail questions without re-reading the whole text.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Log the Result</h2>
                <div id="fill-1">
                    <p>This drill has <input type="text" class="fill-blank" data-answer="30" placeholder="?" aria-label="questions in the drill" /> questions to be completed in 36 minutes, and the passage accounts for questions <input type="text" class="fill-blank" data-answer="27" placeholder="?" aria-label="first passage question" /> to 30. The pass mark is <input type="text" class="fill-blank" data-answer="25" placeholder="?" aria-label="pass mark" />, and my retake is scheduled in <input type="text" class="fill-blank" data-answer="7" placeholder="?" aria-label="days until retake" /> days.</p>
                    <button class="fill-check-btn" onclick="checkFillBlanks('fill-1')">Check answers</button>
                    <div class="fill-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You scored 21/30. Misses: Q2, Q7 (antonyms), Q13 (analogy), Q17 (completion), Q21, Q23 (agreement), Q27, Q30 (passage). Write the repair plan for four days.</p>
                <details>
                    <summary>Show the reasoning</summary>
                    <p>The misses fall into three clusters, not eight items. Q2 and Q7 say the antonym form is the problem: both times you chose a same-direction word, so the repair is the axis check in the synonyms lesson — first ask what the opposite pole is, then read all four options. Q21 and Q23 say agreement rules are still fragile, specifically neither ... nor and the dangle. Q27 and Q30 say the passage questions were answered from impression rather than from the text, because both are questions about scope.</p>
                    <p>So: day 1, the antonyms axis check and twenty antonym pairs, written out with their opposite poles. Day 2, agreement and modifiers, then redo Q21 and Q23 from scratch. Day 3, one new passage, answering stems first and justifying each choice with an exact sentence from the text. Day 4, rerun parts A and D of this drill under the clock and check that the antonym and agreement misses are gone.</p>
                    <p>Four days, three repairs — each one aimed at a cause you named from evidence, rather than at a general intention to do better.</p>
                </details>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Verbal is drilled. The next module is analytical reasoning, where the marks depend less on knowledge and more on written procedure: drawing the constraint, encoding the condition, eliminating rather than guessing.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/hat/lessons/hat-reading-comprehension">Previous: Reading Comprehension Under Time</a></span>
                <span><a href="/courses/hat/lessons/hat-critical-reasoning">Next: Assumptions, Conclusions and Arguments</a></span>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
