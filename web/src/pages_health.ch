// underlayer_web — The Knowledge Health page (/health).
//
// The page answers three questions a learner of a spaced-repetition course
// actually has, and which the platform could answer but never asked:
//
//   1. How much of this course have I covered?      compute_breadth_score
//   2. How well do I know what I have covered?      compute_depth_score
//   3. What will I still remember in a month?       compute_retention_projection
//
// Plus the goals the learner set, which until now could be written and never
// read (GET /api/goals did not exist).
//
// DESIGN RULE THAT SHAPES EVERY NUMBER HERE: a learner who has just started
// must not be shown a page of zeroes and percentages near zero. docs/course-design.md
// requires the collection to normalise struggle; "0% retained, 0% depth, 0 of 24"
// is the opposite. So when nothing has been attempted the page says so in
// words, explains what will fill each number, and links to the first thing worth
// doing -- it does not render empty bars and call that a result.
//
// See pages_health_render.ch for why the labels are worded the way they are
// ("concepts you have started", not "total concepts") and for the component
// pattern this page uses instead of a loop inside a `#html` block.
using std::string
using std::string_view
using std::vector
using underlayer_db::DbClient

public namespace underlayer_web {

    // The first lesson of the course, so the empty state can offer the next
    // action instead of a dead end. Empty string if the manifest has no concept.
    private func first_lesson_href(courses_dir : &string, course_id : &string) : string {
        var course = underlayer_repository::load_course_from_disk(courses_dir, course_id)
        var mi : size_t = 0
        while(mi < course.modules.size()) {
            // modules.get_ptr yields *Module, and the render helpers take
            // references, so each is re-borrowed rather than passed as a pointer.
            var mod = course.modules.get_ptr(mi)
            if(mod.concepts.size() > 0) {
                var first = mod.concepts.get_ptr(0)
                var first_id = first.copy()
                var href = string("/courses/")
                href.append_string(course_id)
                href.append_view(string_view("/lessons/"))
                href.append_string(&first_id)
                return href
            }
            mi = mi + 1
        }
        return string()
    }

    public func render_knowledge_health_page(db : *DbClient, courses_dir : &string, learner_id : &string, course_id : &string) : string {
        // `db` is already *DbClient, which is exactly what the repository calls
        // want, so it is forwarded directly. An earlier draft took &DbClient and
        // re-borrowed it, which produced **DbClient and the compiler was right.
        var states = underlayer_repository::get_all_concept_states(db, learner_id, course_id)
        var course_total = manifest_concept_total(courses_dir, course_id)

        // Coverage: the one breadth figure computed against the real total.
        var breadth = underlayer_learning::compute_breadth_score(&raw states, course_total)
        var depth = underlayer_learning::compute_depth_score(&raw states)
        var proj = underlayer_learning::compute_retention_projection(&raw states)

        // How many concepts have been started at all. This is the number the
        // health model's own "total_concepts" is, and it is not the same thing
        // as course_total, which is why both appear.
        var started : int = states.size() as int
        var has_history = started > 0

        // Depth and the retention projection are both averages over concepts
        // that have been ANSWERED, because stability comes from `streak` and
        // only answering moves it. A learner who has read five lessons and
        // answered none is therefore in the same position as one who has done
        // nothing -- and both produce 0.
        //
        // Rendering that 0 under "What you will remember" tells a reader who
        // has read five lessons that they will retain nothing, which is a
        // prediction with no data behind it. So `answered` is counted here and
        // the section says what is missing instead of printing the figure.
        var answered : int = 0
        var ai : size_t = 0
        while(ai < states.size()) {
            var st = states.get_ptr(ai)
            if(st.attempts > 0) { answered = answered + 1 }
            ai = ai + 1
        }
        var has_answers = answered > 0
        var answered_val = answered as i64
        var proj_note_answered = answered as i64

        // Per-module rows.
        var course = underlayer_repository::load_course_from_disk(courses_dir, course_id)
        var module_rows = vector<HealthModuleRow>()
        var mi : size_t = 0
        while(mi < course.modules.size()) {
            var mod = course.modules.get_ptr(mi)
            // `&mod.concepts` does not type-check through a get_ptr borrow
            // (`*mut string` against `&string`), and re-binding the field with
            // `=` moves it, which the compiler refuses ("cannot move this value
            // without re-initializing memory"). Copying the ids through a local
            // is the way through: the list is short and this runs once per
            // module per page render.
            var mod_concepts = vector<string>()
            var ci : size_t = 0
            while(ci < mod.concepts.size()) {
                var one = mod.concepts.get_ptr(ci)
                var one_copy = one.copy()
                mod_concepts.push_back(one_copy)
                ci = ci + 1
            }
            var mh = underlayer_learning::compute_module_health(&raw states, &raw mod_concepts)
            var row = HealthModuleRow::make()
            var mtitle = mod.title.copy()
            row.title = mtitle
            var mid = mod.id.copy()
            row.module_id = mid
            row.total = mh.total_concepts
            row.mastered = mh.mastered
            row.learning = mh.learning
            row.reviewing = mh.reviewing
            row.unlearned = mh.unlearned
            // Bar width is "mastered of the concepts in this module you have
            // started". A module with nothing started has no denominator, so it
            // renders 0% rather than dividing by zero.
            var pct : int = 0
            if(mh.total_concepts > 0) {
                pct = ((mh.mastered as f64) / (mh.total_concepts as f64) * 100.0) as int
            }
            if(pct < 0) { pct = 0 }
            if(pct > 100) { pct = 100 }
            row.pct = pct
            module_rows.push_back(row)
            mi = mi + 1
        }

        // Goals. Sourced through the same repository call GET /api/goals uses, so
        // this page cannot show a goal the API would not return.
        var goal_rows = vector<HealthGoalRow>()
        var raw_goals = underlayer_repository::list_learning_goals(db, learner_id)
        var now = underlayer_core::current_timestamp()
        var gi : size_t = 0
        while(gi < raw_goals.size()) {
            var g = raw_goals.get_ptr(gi)
            var grows = HealthGoalRow::make()
            var gcid = g.course_id.copy()
            grows.course_id = gcid
            grows.target_date = g.target_date
            var left = (g.target_date - now) / 86400
            if(left < 0) { left = 0 }
            grows.days_remaining = left
            if(g.target_date < now) { grows.overdue = true }
            goal_rows.push_back(grows)
            gi = gi + 1
        }

        // Locals for HTML interpolation (dots are not allowed in {..}).
        var breadth_val = underlayer_learning::f64_to_string(breadth)
        var depth_val = underlayer_learning::f64_to_string(depth)
        var proj30 = underlayer_learning::f64_to_string(proj.days_30)
        var proj60 = underlayer_learning::f64_to_string(proj.days_60)
        var proj90 = underlayer_learning::f64_to_string(proj.days_90)
        var breadth_pct = breadth as i64
        var depth_pct = depth as i64
        var started_val = started as i64
        var course_total_val = course_total as i64
        var left_to_start = course_total - started
        if(left_to_start < 0) { left_to_start = 0 }
        var left_val = left_to_start as i64
        var has_history_flag = has_history
        var has_answers_flag = has_answers
        // A ternary cannot live inside a `{...}` interpolation (dots are not
        // allowed there), so the plural is resolved here. Only reached when
        // has_answers is true, so it is never "0 answered concepts".
        var concepts_word = string("concepts")
        if(answered == 1) { concepts_word = string("concept") }
        var module_count = module_rows.size() as i64
        var goal_count = goal_rows.size() as i64
        var course_title_esc = underlayer_core::html_escape(&course.title)
        var first_href = first_lesson_href(courses_dir, course_id)
        var first_href_view = first_href.to_view()

        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Knowledge Health — Underlayer"))

        #html {
            {render_nav_bar(&mut page)}

            <div class="container" id="main-content">
                <div class="page-header">
                    <h1>Knowledge Health</h1>
                    <p class="subtitle">What you have covered in {course_title_esc}, how well you know it, and how much of it will still be there in a month.</p>
                </div>

                @if(!has_history_flag) {
                    <div class="empty-state">
                        <h2>Nothing measured yet</h2>
                        <p>Every number on this page comes from questions you have actually answered, so there is nothing to report until you answer some. That is not a problem with the page &mdash; it is the page being honest.</p>
                        <p>Answer a few questions in {course_title_esc} and this fills in: how much of the {course_total_val} concepts you have covered, how well you know them, and what you will have forgotten by day 30.</p>
                        @if(first_href.size() > 0) {
                            <p class="empty-cta"><a class="btn btn-primary" href={first_href_view}>Start with the first lesson</a></p>
                        }
                    </div>
                } @else {
                    <div class="stats-grid">
                        <div class="stat-card stat-coverage">
                            <div class="stat-number" id="coverage-val">{breadth_pct}%</div>
                            <div class="stat-label">of the course covered</div>
                            <div class="stat-sub">{started_val} of {course_total_val} concepts started</div>
                        </div>
                        <div class="stat-card stat-depth">
                            @if(has_answers_flag) {
                                <div class="stat-number" id="depth-val">{depth_pct}</div>
                                <div class="stat-label">depth score</div>
                                <div class="stat-sub">accuracy weighted by how often you have been asked</div>
                            } @else {
                                <div class="stat-number stat-pending" id="depth-val">&mdash;</div>
                                <div class="stat-label">depth score</div>
                                <div class="stat-sub">nothing answered yet, so there is no accuracy to weigh</div>
                            }
                        </div>
                        <div class="stat-card stat-left">
                            <div class="stat-number" id="left-val">{left_val}</div>
                            <div class="stat-label">concepts not started</div>
                            <div class="stat-sub">out of {course_total_val} in this course</div>
                        </div>
                    </div>

                    <div class="section-card">
                        <h2>What you will remember</h2>
                        @if(!has_answers_flag) {
                            <p class="section-desc">This estimate comes from how many times you have successfully <em>recalled</em> a concept, not how many times you have read it. Reading a lesson tells the platform you were there; only answering tells it what stuck. So this section is empty on purpose rather than showing you a number derived from nothing.</p>
                            <p class="proj-empty">You have started {started_val} of {course_total_val} concepts and answered questions in none of them yet. Answer a few and three figures appear here &mdash; what you will probably still recall in 30, 60 and 90 days.</p>
                            <p class="proj-note"><a href="/review">Answer your reviews</a> &mdash; that is what fills this in, and it is also the only thing that moves the numbers afterwards.</p>
                        } @else {
                            <p class="section-desc">An estimate from the forgetting curve, using how many times you have successfully recalled each concept. It is a prediction, not a measurement &mdash; the only way to move it is to answer the reviews.</p>
                            <div class="proj-grid">
                                <div class="proj-col">
                                    <div class="proj-val" id="proj-30">{proj30}%</div>
                                    <div class="proj-label">in 30 days</div>
                                </div>
                                <div class="proj-col">
                                    <div class="proj-val" id="proj-60">{proj60}%</div>
                                    <div class="proj-label">in 60 days</div>
                                </div>
                                <div class="proj-col">
                                    <div class="proj-val" id="proj-90">{proj90}%</div>
                                    <div class="proj-label">in 90 days</div>
                                </div>
                            </div>
                            <p class="proj-note">Based on {proj_note_answered} answered {concepts_word}. These numbers move in one direction on their own. That is what the review queue is for.</p>
                        }
                    </div>

                    <div class="section-card">
                        <h2>Module by module</h2>
                        <p class="section-desc">{module_count} modules. Each bar is the share of the concepts you have started in that module that you have mastered.</p>
                        <ul class="module-list">
                            {render_all_module_rows(&module_rows, &mut page)}
                        </ul>
                    </div>
                }

                <div class="section-card">
                    <h2>Your goals</h2>
                    @if(goal_count > 0) {
                        <p class="section-desc">{goal_count} set. Days left are counted from the target date you gave.</p>
                        <ul class="goal-list">
                            {render_all_goal_rows(&goal_rows, &mut page)}
                        </ul>
                    } @else {
                        <p class="section-desc">No target date set. A goal is the one thing on this platform that makes &ldquo;when will I know this&rdquo; answerable &mdash; without one, &ldquo;am I learning&rdquo; has no scale to be measured against.</p>
                        <p class="goal-cta"><a class="btn" href="/progress">Set a goal on the progress page</a></p>
                    }
                </div>
            </div>
        }

        #css {
            .container { max-width: 60rem; margin: 0 auto; padding: 2rem 1.25rem 4rem; }
            .page-header { margin-bottom: 1.75rem; }
            .page-header h1 { font-size: 1.75rem; margin: 0 0 0.35rem; }
            .subtitle { color: var(--muted, #6b7280); margin: 0; line-height: 1.55; }
            .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr)); gap: 1rem; margin-bottom: 1.75rem; }
            .stat-card { border: 1px solid var(--border, #e5e7eb); border-radius: 0.6rem; padding: 1.1rem; background: var(--surface, #ffffff); }
            .stat-number { font-size: 2rem; font-weight: 650; line-height: 1.1; }
            .stat-label { font-size: 0.9rem; margin-top: 0.3rem; }
            .stat-sub { font-size: 0.78rem; color: var(--muted, #6b7280); margin-top: 0.4rem; line-height: 1.4; }
            .stat-coverage .stat-number { color: #2563eb; }
            .stat-depth .stat-number { color: #7c3aed; }
            .stat-left .stat-number { color: #0891b2; }
            .section-card { border: 1px solid var(--border, #e5e7eb); border-radius: 0.6rem; padding: 1.25rem; margin-bottom: 1.25rem; background: var(--surface, #ffffff); }
            .section-card h2 { font-size: 1.1rem; margin: 0 0 0.4rem; }
            .section-desc { color: var(--muted, #6b7280); font-size: 0.88rem; margin: 0 0 1rem; line-height: 1.55; }
            .empty-state { border: 1px solid var(--border, #e5e7eb); border-left: 3px solid #2563eb; border-radius: 0.6rem; padding: 1.5rem; margin-bottom: 1.75rem; background: var(--surface, #ffffff); }
            .empty-state h2 { font-size: 1.1rem; margin: 0 0 0.6rem; }
            .empty-state p { margin: 0 0 0.8rem; line-height: 1.6; color: #374151; }
            .empty-cta { margin-top: 1.1rem; }
            .btn { display: inline-block; padding: 0.5rem 0.95rem; border-radius: 0.4rem; border: 1px solid var(--border, #d1d5db); text-decoration: none; font-size: 0.9rem; color: #111827; background: #f9fafb; }
            .btn-primary { background: #2563eb; border-color: #2563eb; color: #ffffff; }
            .proj-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; text-align: center; }
            .proj-val { font-size: 1.5rem; font-weight: 650; color: #b45309; }
            .proj-label { font-size: 0.82rem; color: var(--muted, #6b7280); margin-top: 0.25rem; }
            .proj-note { font-size: 0.82rem; color: var(--muted, #6b7280); margin: 1rem 0 0; }
            .proj-empty { font-size: 0.92rem; line-height: 1.6; margin: 0.75rem 0 0; }
            .proj-note a { color: #2563eb; }
            /* An em dash, not a 0: this card is deliberately showing that the
               figure is unavailable rather than that it is zero. */
            .stat-pending { color: var(--muted, #9ca3af); }
            .module-list, .goal-list { list-style: none; margin: 0; padding: 0; }
            .module-row { padding: 0.85rem 0; border-bottom: 1px solid var(--border, #f1f5f9); }
            .module-row:last-child { border-bottom: none; }
            .module-head { display: flex; justify-content: space-between; align-items: baseline; gap: 1rem; }
            .module-title { font-size: 0.95rem; font-weight: 550; }
            .module-count { font-size: 0.8rem; color: var(--muted, #6b7280); white-space: nowrap; }
            .bar-track { height: 0.45rem; background: #f1f5f9; border-radius: 0.25rem; overflow: hidden; margin: 0.5rem 0; }
            .bar-fill { height: 100%; background: #2563eb; border-radius: 0.25rem; }
            .module-breakdown { display: flex; gap: 0.5rem; flex-wrap: wrap; }
            .chip { font-size: 0.72rem; padding: 0.1rem 0.45rem; border-radius: 0.7rem; border: 1px solid var(--border, #e5e7eb); color: #374151; background: #f9fafb; }
            .chip-mastered { border-color: #a7f3d0; background: #ecfdf5; color: #065f46; }
            .chip-learning { border-color: #bfdbfe; background: #eff6ff; color: #1e40af; }
            .chip-reviewing { border-color: #ddd6fe; background: #f5f3ff; color: #5b21b6; }
            .chip-goal { border-color: #fde68a; background: #fffbeb; color: #92400e; }
            .chip-overdue { border-color: #fecaca; background: #fef2f2; color: #991b1b; }
            .goal-row { display: flex; align-items: center; gap: 0.75rem; padding: 0.6rem 0; border-bottom: 1px solid var(--border, #f1f5f9); }
            .goal-row:last-child { border-bottom: none; }
            .goal-course { font-size: 0.95rem; font-weight: 550; text-decoration: none; }
            .goal-cta { margin: 0.5rem 0 0; }
        }

        return page.toString()
    }

}