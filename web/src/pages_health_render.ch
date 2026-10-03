// underlayer_web — #html components for the Knowledge Health page (/health).
//
// WHY THIS PAGE EXISTS.  The platform has computed a knowledge-health model
// since 1.5.x and none of it was reachable by a person:
//
//   GET /api/health/knowledge             -> 200, {"total_concepts":0,...}
//   GET /api/health/knowledge/per-module  -> 200, [{...},{...}]
//   GET /api/health/knowledge/projection  -> 200, {"days_30":0.0,...}
//
// tools/integration_holes.py listed all three under "routes no UI can reach",
// next to the 16 /api/analytics/* routes. The endpoint is the thing to read if
// you want to know what a learner actually retains; nothing on the site asked.
// This page is that question, asked out loud.
//
// THE LABELS ARE NOT THE OBVIOUS ONES, and getting them wrong is the trap.
//
//   compute_knowledge_health(states) sets total_concepts = states.size(), and
//   `states` is one row per concept the learner has *touched*. So its
//   "total_concepts" is "concepts you have started", NOT "concepts in the
//   course". Labelling that number "Total concepts" would tell a learner who has
//   read 3 of 24 lessons that they are looking at 3 concepts, which reads as
//   "this course is nearly finished" -- the exact opposite of the truth.
//
//   So coverage comes from compute_breadth_score(states, course_total), which
//   is the one function here that is passed the real number of concepts in the
//   course, and it is the number shown as the headline. Per-module rows are
//   labelled with what they measure: concepts *in that module you have started*.
//
//   compute_knowledge_health's own health_score (mastered / started) is shown as
//   "mastered of what you started", because that is genuinely what it is.
//
// WHY SERVER-RENDERED.  Per courses_index_render.ch, a `#html` block cannot be
// split across blocks and `@{}` cannot lex, so loops are plain Chemical calling
// a component function with its own balanced block: {render_x(row, page)}.
// That also means every row is in the served HTML, which is why this page works
// with JavaScript disabled and is readable by a crawler or a text-mode reader.
// There is no #js on this page on purpose: nothing here needs to be fetched
// after the fact, so there is nothing to hydrate and nothing that can half-load.
using std::string
using std::string_view
using std::vector

public namespace underlayer_web {

    // One module's row. `pct` is the bar width in whole percent, precomputed in
    // plain Chemical so the block below interpolates a number and nothing else.
    public struct HealthModuleRow {
        var title : string
        var module_id : string
        var total : int
        var mastered : int
        var learning : int
        var reviewing : int
        var unlearned : int
        var pct : int

        @make
        func make() : HealthModuleRow {
            return HealthModuleRow {
                title = string(),
                module_id = string(),
                total = 0,
                mastered = 0,
                learning = 0,
                reviewing = 0,
                unlearned = 0,
                pct = 0
            }
        }
    }

    // One goal the learner has set, with the days left computed server-side by
    // the same code that serves GET /api/goals, so the page and the API cannot
    // disagree about how far away a deadline is.
    public struct HealthGoalRow {
        var course_id : string
        var target_date : i64
        var days_remaining : i64
        var overdue : bool

        @make
        func make() : HealthGoalRow {
            return HealthGoalRow {
                course_id = string(),
                target_date = 0,
                days_remaining = 0,
                overdue = false
            }
        }
    }

    // One module. A module the learner has not touched renders its bar at 0%
    // but keeps its real concept count visible, so "0 of 14" reads as "not
    // started yet" rather than as a mistake.
    public func render_health_module_row(row : *HealthModuleRow, page : &mut HtmlPage) {
        var pct_val = row.pct
        var total_val = row.total
        var mastered_val = row.mastered
        var learning_val = row.learning
        var reviewing_val = row.reviewing
        var title_esc = underlayer_core::html_escape(&row.title)
        var id_esc = underlayer_core::html_escape(&row.module_id)
        var bar_style = string("width:")
        var pct_str = underlayer_core::int_to_string(pct_val as i64)
        bar_style.append_string(&pct_str)
        bar_style.append_view(string_view("%"))
        var bar_style_view = bar_style.to_view()
        // Built here rather than inline: `id={"bar-" + id_esc}` does not
        // type-check, because string concatenation is not a primitive. The
        // codebase's own idiom for this is a template literal in the attribute
        // (see courses_path_render.ch:142, id={`route-${route.id}`}).
        #html {
            <li class="module-row">
                <div class="module-head">
                    <span class="module-title">{title_esc}</span>
                    <span class="module-count">{mastered_val} of {total_val} started</span>
                </div>
                <div class="bar-track"><div class="bar-fill" id={`bar-${id_esc}`} style={bar_style_view}></div></div>
                <div class="module-breakdown">
                    <span class="chip chip-mastered">{mastered_val} mastered</span>
                    <span class="chip chip-learning">{learning_val} learning</span>
                    <span class="chip chip-reviewing">{reviewing_val} reviewing</span>
                </div>
            </li>
        }
    }

    // Every module, in one call. This is the loop-inside-a-block the language
    // cannot write directly.
    public func render_all_module_rows(rows : &vector<HealthModuleRow>, page : &mut HtmlPage) {
        var i : size_t = 0
        while(i < rows.size()) {
            render_health_module_row(rows.get_ptr(i), page)
            i = i + 1
        }
    }

    // One goal. An overdue goal is labelled as missed rather than shown as a
    // negative countdown: a learner who set a date and did not hit it should be
    // able to set a new one, not be told they are -4 days from a deadline.
    public func render_health_goal_row(row : *HealthGoalRow, page : &mut HtmlPage) {
        var course_esc = underlayer_core::html_escape(&row.course_id)
        var days_val = row.days_remaining
        var course_link = string("/courses/")
        course_link.append_string(&row.course_id)
        var course_link_view = course_link.to_view()
        #html {
            <li class="goal-row">
                <a class="goal-course" href={course_link_view}>{course_esc}</a>
                @if(row.overdue) {
                    <span class="chip chip-overdue">target date passed &mdash; set a new one</span>
                } @else {
                    <span class="chip chip-goal">{days_val} days left</span>
                }
            </li>
        }
    }

    public func render_all_goal_rows(rows : &vector<HealthGoalRow>, page : &mut HtmlPage) {
        var i : size_t = 0
        while(i < rows.size()) {
            render_health_goal_row(rows.get_ptr(i), page)
            i = i + 1
        }
    }

}