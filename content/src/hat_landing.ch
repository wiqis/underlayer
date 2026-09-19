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
            <p class="course-description">A preparation course for the HEC Higher Education Aptitude Test, written for HAT-1 candidates in engineering, computing and the physical sciences: test structure, weighted study planning, quantitative and verbal technique, analytical reasoning, and the technical foundations.</p>
            <div class="lesson-meta">5 modules · 21 concepts · Beginner-friendly · English</div>

            <div class="unit unit-why">
                <h2>How to Use This Course</h2>
                <p>Work through the modules in order if you are starting from scratch. Each concept is built from the same eight units — why it matters, a model, the real detail, a worked example, practice, recall, application and a link to the next concept — so you always know what a page is doing and where to find the technique it teaches.</p>
                <p>If you have limited time, the orientation module tells you where the marks are, and the quantitative and analytical modules carry the technique that pays off fastest. Take the practice questions seriously: the quiz feedback explains the reasoning behind every option, including the wrong ones.</p>
            </div>

            <div class="module-list">
                <div class="unit unit-model">
                    <h2>Module 1: Understanding the Test</h2>
                    <p>What the HAT is, how it is weighted, and how to plan six weeks of preparation.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/hat/lessons/hat-exam-overview">What the HAT Actually Is</a></li>
                        <li><a href="/courses/hat/lessons/hat-weightage-strategy">Weightage and Study Strategy</a></li>
                        <li><a href="/courses/hat/lessons/hat-study-plan">A Six-Week Study Plan</a></li>
                    </ul>
                </div>

                <div class="unit unit-reality">
                    <h2>Module 2: Quantitative Reasoning</h2>
                    <p>Arithmetic and approximation, percentages, ratio and rate, basic algebra, geometry, and statistics.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/hat/lessons/hat-arithmetic">Arithmetic You Can Do in Your Head</a></li>
                        <li><a href="/courses/hat/lessons/hat-percentages">Percentages and Percentage Change</a></li>
                        <li><a href="/courses/hat/lessons/hat-ratio-proportion">Ratio, Proportion and Rate</a></li>
                        <li><a href="/courses/hat/lessons/hat-algebra">Algebra Without Fear</a></li>
                        <li><a href="/courses/hat/lessons/hat-geometry">Geometry and Measurement</a></li>
                        <li><a href="/courses/hat/lessons/hat-data-probability">Data, Averages and Probability</a></li>
                    </ul>
                </div>

                <div class="unit unit-example">
                    <h2>Module 3: Verbal Reasoning</h2>
                    <p>Vocabulary by roots and context, analogies, sentence completion, grammar error identification, and timed reading.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/hat/lessons/hat-vocabulary">Vocabulary You Can Actually Learn</a></li>
                        <li><a href="/courses/hat/lessons/hat-analogies">Analogies and Word Relationships</a></li>
                        <li><a href="/courses/hat/lessons/hat-sentence-completion">Sentence Completion and Signal Words</a></li>
                        <li><a href="/courses/hat/lessons/hat-grammar-errors">Finding the Error: Grammar Rules</a></li>
                        <li><a href="/courses/hat/lessons/hat-reading-comprehension">Reading Comprehension Under Time</a></li>
                    </ul>
                </div>

                <div class="unit unit-interact">
                    <h2>Module 4: Analytical Reasoning</h2>
                    <p>Arguments and assumptions, ordering and grouping puzzles, tables and charts, and number and letter series.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/hat/lessons/hat-critical-reasoning">Assumptions, Conclusions and Arguments</a></li>
                        <li><a href="/courses/hat/lessons/hat-logic-deduction">Ordering, Grouping and Deduction</a></li>
                        <li><a href="/courses/hat/lessons/hat-data-interpretation">Tables, Charts and Graphs</a></li>
                        <li><a href="/courses/hat/lessons/hat-pattern-series">Number and Letter Series</a></li>
                    </ul>
                </div>

                <div class="unit unit-apply">
                    <h2>Module 5: Subject — Engineering and Computing</h2>
                    <p>The HAT-1 technical foundation: mechanics and electricity, computing fundamentals, and digital logic.</p>
                    <ul class="concept-list">
                        <li><a href="/courses/hat/lessons/hat-physics-mechanics">Physics and Mechanics for Engineering Candidates</a></li>
                        <li><a href="/courses/hat/lessons/hat-programming-fundamentals">Computing Fundamentals</a></li>
                        <li><a href="/courses/hat/lessons/hat-digital-logic">Digital Logic and Circuit Basics</a></li>
                    </ul>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>After the Course</h2>
                <p>Finish with a timed full-length mock under the pacing rules from Lesson 3, then review every question you missed by rule rather than by topic. Underlayer will schedule the concepts you practised for review, so the technique comes back when it is about to fade.</p>
            </div>
        </div>
    }

    render_hat_lesson_js(&mut page)

    return page.toString()
}
}
