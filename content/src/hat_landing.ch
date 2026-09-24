// HAT Course — Landing Page (static build)
// Shows the course structure and links to each concept. Mirrors
// elf_landing.ch so the static course build has the same shape.
//
// The web server serves /courses/hat from repository::load_course + the
// generic render_course_landing(course); this landing exists for the
// pre-rendered courses/hat/output build.

public namespace underlayer_content {

using std::string

using std::string_view

public func render_hat_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("HAT — Higher Education Aptitude Test — Underlayer")
    page.appendTitle(&title)

    render_hat_lesson_css(&mut page)

    #html {
        <div class="lesson hat-lesson">
            <a href="/" class="back-link">Back to Underlayer</a>
            <h1>HAT — Higher Education Aptitude Test</h1>
            <p class="course-description">A preparation course for the HEC Higher Education Aptitude Test, written for HAT-1 candidates in engineering, computing and the physical sciences: test structure and pacing, weighted study planning, the full quantitative, verbal and analytical syllabus, a timed-drill and mock programme, and an optional engineering background.</p>
            <div class="lesson-meta">6 modules · 69 concepts · Beginner to intermediate · English</div>

            <div class="unit unit-why">
                <h2>How to Use This Course</h2>
                <p>Work through the modules in order if you are starting from scratch. Each concept is built from the same eight units — why it matters, a model, the real detail, a worked example, practice, recall, application and a link to the next concept — so you always know what a page is doing and where to find the technique it teaches.</p>
                <p>HAT-1 weights the paper 40% quantitative, 30% verbal and 30% analytical, so the quantitative module is the longest and the drills at the end of each section are where speed is built. Take the practice questions seriously: the quiz feedback explains the reasoning behind every option, including the wrong ones.</p>
            </div>

            <div class="module-list">
                <div class="unit unit-model">
                    <h2>Module 1: Know the Arena</h2>
                    <p>What HAT-1 is, how it is weighted and paced, how to diagnose your baseline, and how to plan and execute eight weeks of preparation.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/hat/lessons/hat-exam-overview">Know the Arena: What HAT-1 Actually Is</a></li>
                        <li><a href="/courses/hat/lessons/hat-weightage-strategy">Weightage and Study Strategy</a></li>
                        <li><a href="/courses/hat/lessons/hat-diagnostic-test">Your Baseline Diagnostic: Start with Evidence</a></li>
                        <li><a href="/courses/hat/lessons/hat-study-plan">The Eight-Week Program: Training Like an Athlete</a></li>
                        <li><a href="/courses/hat/lessons/hat-time-budget">Your 120 Minutes: Time Budgets and Checkpoints</a></li>
                        <li><a href="/courses/hat/lessons/hat-triage-and-guessing">Triage and Guessing: Converting Attempts into Marks</a></li>
                    </ul>
                </div>

                <div class="unit unit-reality">
                    <h2>Module 2: Quantitative Reasoning</h2>
                    <p>Arithmetic and number sense, percentages, ratio and rate, algebra, sequences, geometry and mensuration, coordinate geometry, statistics, counting and probability, word problems and finance arithmetic, with a timed drill.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/hat/lessons/hat-arithmetic">Arithmetic You Can Do in Your Head</a></li>
                        <li><a href="/courses/hat/lessons/hat-number-properties">Number Properties: Divisibility, Primes, HCF and LCM</a></li>
                        <li><a href="/courses/hat/lessons/hat-fractions-decimals">Fractions, Decimals and the Conversion Table</a></li>
                        <li><a href="/courses/hat/lessons/hat-percentages">Percentages and Percentage Change</a></li>
                        <li><a href="/courses/hat/lessons/hat-ratio-proportion">Ratio, Proportion and Rate</a></li>
                        <li><a href="/courses/hat/lessons/hat-averages">Averages, Weighted Means and Mixtures</a></li>
                        <li><a href="/courses/hat/lessons/hat-rates-speed-distance">Speed, Distance and Time</a></li>
                        <li><a href="/courses/hat/lessons/hat-work-rate">Work, Pipes and Rates</a></li>
                        <li><a href="/courses/hat/lessons/hat-counting-probability">Counting and Probability</a></li>
                        <li><a href="/courses/hat/lessons/hat-exponents-roots">Powers, Roots and Surds</a></li>
                        <li><a href="/courses/hat/lessons/hat-algebra">Algebra Without Fear</a></li>
                        <li><a href="/courses/hat/lessons/hat-quadratic-equations">Quadratic Equations</a></li>
                        <li><a href="/courses/hat/lessons/hat-sequences">Sequences and Series</a></li>
                        <li><a href="/courses/hat/lessons/hat-geometry">Geometry and Measurement</a></li>
                        <li><a href="/courses/hat/lessons/hat-mensuration">Mensuration: Perimeter, Area and Volume</a></li>
                        <li><a href="/courses/hat/lessons/hat-coordinate-geometry">Coordinate Geometry</a></li>
                        <li><a href="/courses/hat/lessons/hat-data-probability">Data, Averages and Probability</a></li>
                        <li><a href="/courses/hat/lessons/hat-word-problems">Translating Word Problems</a></li>
                        <li><a href="/courses/hat/lessons/hat-profit-loss-discount">Profit, Loss and Discount</a></li>
                        <li><a href="/courses/hat/lessons/hat-interest">Simple and Compound Interest</a></li>
                        <li><a href="/courses/hat/lessons/hat-quant-drill">Quantitative Drill: 25 Questions in 30 Minutes</a></li>
                    </ul>
                </div>

                <div class="unit unit-example">
                    <h2>Module 3: Verbal Reasoning</h2>
                    <p>Vocabulary, synonyms and antonyms, analogies, sentence and paragraph completion, sentence correction, grammar and punctuation, idioms, reading comprehension, critical reading, and a timed drill.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/hat/lessons/hat-vocabulary">Vocabulary You Can Actually Learn</a></li>
                        <li><a href="/courses/hat/lessons/hat-synonyms-antonyms">Synonyms and Antonyms</a></li>
                        <li><a href="/courses/hat/lessons/hat-analogies">Analogies and Word Relationships</a></li>
                        <li><a href="/courses/hat/lessons/hat-sentence-completion">Sentence Completion and Signal Words</a></li>
                        <li><a href="/courses/hat/lessons/hat-paragraph-completion">Paragraph Completion and Coherence</a></li>
                        <li><a href="/courses/hat/lessons/hat-sentence-correction">Sentence Correction</a></li>
                        <li><a href="/courses/hat/lessons/hat-grammar-errors">Finding the Error: Grammar Rules</a></li>
                        <li><a href="/courses/hat/lessons/hat-grammar-agreement">Agreement, Pronouns and Modifiers</a></li>
                        <li><a href="/courses/hat/lessons/hat-grammar-tenses">Tenses, Articles and Conditionals</a></li>
                        <li><a href="/courses/hat/lessons/hat-grammar-punctuation">Punctuation and Sentence Boundaries</a></li>
                        <li><a href="/courses/hat/lessons/hat-prepositions-idioms">Prepositions, Idioms and Confused Words</a></li>
                        <li><a href="/courses/hat/lessons/hat-reading-comprehension">Reading Comprehension Under Time</a></li>
                        <li><a href="/courses/hat/lessons/hat-critical-reading">Critical Reading: Tone, Purpose and Inference</a></li>
                        <li><a href="/courses/hat/lessons/hat-verbal-drill">Verbal Drill: 30 Questions in 36 Minutes</a></li>
                    </ul>
                </div>

                <div class="unit unit-interact">
                    <h2>Module 4: Analytical Reasoning</h2>
                    <p>Critical reasoning, statement-based question types, deduction and puzzles, syllogisms and set logic, relations and directions, coding, data sufficiency and interpretation, series, and a timed drill.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/hat/lessons/hat-critical-reasoning">Assumptions, Conclusions and Arguments</a></li>
                        <li><a href="/courses/hat/lessons/hat-statement-assumption">Statement and Assumption</a></li>
                        <li><a href="/courses/hat/lessons/hat-statement-conclusion">Statement and Conclusion</a></li>
                        <li><a href="/courses/hat/lessons/hat-strong-weak-arguments">Strong and Weak Arguments</a></li>
                        <li><a href="/courses/hat/lessons/hat-course-of-action">Course of Action</a></li>
                        <li><a href="/courses/hat/lessons/hat-cause-effect">Cause and Effect: Correlation Is Not Causation</a></li>
                        <li><a href="/courses/hat/lessons/hat-logic-deduction">Ordering, Grouping and Deduction</a></li>
                        <li><a href="/courses/hat/lessons/hat-seating-arrangements">Seating Arrangements: Linear and Circular</a></li>
                        <li><a href="/courses/hat/lessons/hat-ordering-scheduling">Ordering, Grouping and Scheduling</a></li>
                        <li><a href="/courses/hat/lessons/hat-grouping-puzzles">Grouping and Selection Puzzles</a></li>
                        <li><a href="/courses/hat/lessons/hat-network-routing">Network Routing Sets</a></li>
                        <li><a href="/courses/hat/lessons/hat-syllogisms">Syllogisms: What Follows Necessarily</a></li>
                        <li><a href="/courses/hat/lessons/hat-sets-venn">Set-Based Deduction: Venn Diagrams</a></li>
                        <li><a href="/courses/hat/lessons/hat-relations-and-directions">Relations and Directions</a></li>
                        <li><a href="/courses/hat/lessons/hat-coding-decoding">Coding and Decoding</a></li>
                        <li><a href="/courses/hat/lessons/hat-data-sufficiency">Is the Information Enough? Data Sufficiency</a></li>
                        <li><a href="/courses/hat/lessons/hat-data-interpretation">Tables, Charts and Graphs</a></li>
                        <li><a href="/courses/hat/lessons/hat-pattern-series">Number and Letter Series</a></li>
                        <li><a href="/courses/hat/lessons/hat-analytical-drill">Analytical Drill: 20 Questions in 24 Minutes</a></li>
                    </ul>
                </div>

                <div class="unit unit-apply">
                    <h2>Module 5: The Athlete's Program</h2>
                    <p>Turning knowledge into a score: mock-test protocol, the error log, how to review, score targets, energy management and exam-day execution.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/hat/lessons/hat-mock-protocol">How to Run a Mock Test</a></li>
                        <li><a href="/courses/hat/lessons/hat-error-log">The Error Log: Your Only Real Study Material</a></li>
                        <li><a href="/courses/hat/lessons/hat-review-method">How to Review So It Sticks</a></li>
                        <li><a href="/courses/hat/lessons/hat-score-targets">What Score Do You Need? Targets and Projection</a></li>
                        <li><a href="/courses/hat/lessons/hat-energy-management">Energy, Sleep and Stamina</a></li>
                        <li><a href="/courses/hat/lessons/hat-exam-day">Exam Day: Execution Under Pressure</a></li>
                    </ul>
                </div>

                <div class="unit unit-connect">
                    <h2>Module 6: Engineering Foundations (Optional)</h2>
                    <p>Optional background in mechanics, computing and digital logic for engineering and computing candidates. This is not a separate section of the HAT-1 paper.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/hat/lessons/hat-physics-mechanics">Physics and Mechanics for Engineering Candidates</a></li>
                        <li><a href="/courses/hat/lessons/hat-programming-fundamentals">Computing Fundamentals</a></li>
                        <li><a href="/courses/hat/lessons/hat-digital-logic">Digital Logic and Circuit Basics</a></li>
                    </ul>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>After the Course</h2>
                <p>Finish with a timed full-length mock under the pacing rules from Module 1, then review every question you missed by rule rather than by topic. Underlayer will schedule the concepts you practised for review, so the technique comes back when it is about to fade.</p>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
