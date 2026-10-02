// underlayer_web — Dashboard: what am I doing (7.2.4, 7.2.5, 1.5.20).
//
// WHAT THIS PAGE ALREADY SHOWED, measured on 2026-10-02, because the
// instruction was to read it before building anything:
//
//   * Four stat cards (total / mastered / learning / reviewing), a Knowledge
//     Health card with three bars, a Review Queue card with two badges and a
//     Start Review button.
//
// AND WHAT EVERY ONE OF THOSE NUMBERS WAS: `course_id` was the literal "elf",
// hardcoded on line 14, on a platform with 34 courses.  So "Total Concepts 24"
// was true only for someone studying ELF, and for a learner deep into the RISC-V
// assembly course -- a course with a different number of concepts entirely --
// the dashboard reported ELF's numbers and said so with a straight face.  It is
// now driven by the same ?course_id= the rest of the progress API reads, and
// the manifest supplies the total instead of a constant.
//
// WHAT IT DID NOT SHOW, which is the whole of the request: nothing about WHICH
// COURSES the learner is in (the `enrollments` table existed with a full CRUD
// layer and zero rows, because nothing wrote to it), and nothing about WHICH
// QUIZES they got wrong (the per-attempt record did not exist -- see
// repository/src/exercise_attempts.ch for why no view could have shown it).
//
// SO THIS PAGE GAINS TWO LISTS, not a new page.  A parallel dashboard would
// have been the same six questions in a second place with its own stale copy
// of the answers; the two lists answer the two questions that had none.
using std::string
using std::vector
using underlayer_db::DbClient

public namespace underlayer_web {

    public func handle_dashboard(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = auth_get_learner_id(&raw db, req)
        var signed_in = learner_id.size() > 0
        if(!signed_in) { learner_id = string("demo") }
        var course_id = progress_course_id(req)

        var states = underlayer_repository::get_all_concept_states(&raw db, &learner_id, &course_id)
        var health = underlayer_learning::compute_knowledge_health(&raw states)
        var depth = underlayer_learning::compute_depth_score(&raw states)
        var total_concepts = manifest_concept_total(courses_dir, &course_id)
        if(total_concepts == 0) { total_concepts = health.total_concepts }
        var breadth = underlayer_learning::compute_breadth_score(&raw states, total_concepts)
        var cov = underlayer_learning::compute_course_coverage(&course_id, &raw states, total_concepts)

        var due_items = underlayer_repository::get_due_review_items(&raw db, &learner_id, &course_id, 1000)
        var new_count = 0
        var due_count = 0
        var i : size_t = 0
        while(i < due_items.size()) {
            var item = due_items.get_ptr(i)
            if(item.last_review == 0) { new_count = new_count + 1 }
            else { due_count = due_count + 1 }
            i = i + 1
        }

        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.injectDefaultComponentsTheme()
        page.appendTitle(std::string_view("Dashboard — Underlayer"))
        render_dashboard_css(&mut page)
        // THE ONBOARDING GATE (7.1.20).  A signed-in learner whose onboarding is
        // incomplete is sent to /onboarding.  __ulGate answers rather than
        // navigating, and THIS page is what acts on the answer -- see the note
        // in session_js.ch for why the helper must not redirect on its own.
        render_session_js(&mut page)

        #html {
            {render_nav_bar(&mut page)}
            {render_onboarding_gate(&mut page)}

            <div class="container" id="main-content" style="max-width: 1200px; margin: 0 auto; padding: 2rem;">
                <div class="wd-head">
                    <H1>Dashboard</H1>
                    <Text variant="muted">Where you are, and what to do next</Text>
                </div>

                <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 2rem;">
                    <Card>
                        <CardBody>
                            <Text variant="muted">Concepts in {course_id}</Text>
                            <Text style="font-size: 2rem; font-weight: bold;">{cov.concepts_total}</Text>
                        </CardBody>
                    </Card>
                    <Card>
                        <CardBody>
                            <Text variant="muted">Read</Text>
                            <Text style="font-size: 2rem; font-weight: bold; color: var(--primary);">{cov.concepts_started}</Text>
                        </CardBody>
                    </Card>
                    <Card>
                        <CardBody>
                            <Text variant="muted">Learned</Text>
                            <Text style="font-size: 2rem; font-weight: bold; color: var(--accent);">{cov.concepts_mastered}</Text>
                        </CardBody>
                    </Card>
                    <Card>
                        <CardBody>
                            <Text variant="muted">Review due</Text>
                            <Text style="font-size: 2rem; font-weight: bold; color: var(--destructive);">{cov.concepts_due}</Text>
                        </CardBody>
                    </Card>
                </div>

                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 2rem;">
                    <Card>
                        <CardHeader>
                            <CardTitle>What am I doing</CardTitle>
                        </CardHeader>
                        <CardBody>
                            <Text variant="muted">Courses you have opened: <span id="wd-courses-count">-</span></Text>
                            <div id="wd-courses" aria-live="polite"></div>
                        </CardBody>
                    </Card>
                    <Card>
                        <CardHeader>
                            <CardTitle>Which quizzes I failed</CardTitle>
                        </CardHeader>
                        <CardBody>
                            <Text variant="muted">Distinct questions you got wrong: <span id="wd-failures-count">-</span></Text>
                            <div id="wd-failures" aria-live="polite"></div>
                        </CardBody>
                    </Card>
                </div>

                <div style="display: grid; grid-template-columns: 2fr 1fr; gap: 1rem;">
                    <Card>
                        <CardHeader>
                            <CardTitle>Knowledge Health</CardTitle>
                        </CardHeader>
                        <CardBody>
                            <div style="margin-bottom: 1rem;">
                                <Text>Course progress</Text>
                                <Progress value={cov.progress_percentage} max={100} variant="success" />
                                <Caption>{cov.concepts_started} of {cov.concepts_total} concepts read</Caption>
                            </div>
                            <div style="margin-bottom: 1rem;">
                                <Text>Mastery (of what you have read)</Text>
                                <Progress value={cov.mastery_percentage} max={100} variant="info" />
                                <Caption>{cov.mastery_percentage}% learned</Caption>
                            </div>
                            <div style="margin-bottom: 1rem;">
                                <Text>Depth Score</Text>
                                <Progress value={depth} max={100.0} variant="info" />
                                <Caption>{depth}% understanding</Caption>
                            </div>
                            <div>
                                <Text>Breadth Score</Text>
                                <Progress value={breadth} max={100.0} variant="accent" />
                                <Caption>{breadth}% coverage</Caption>
                            </div>
                        </CardBody>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Review Queue</CardTitle>
                        </CardHeader>
                        <CardBody>
                            <div style="margin-bottom: 1rem;">
                                <Badge variant="info">New: {new_count}</Badge>
                            </div>
                            <div style="margin-bottom: 1rem;">
                                <Badge variant="warning">Due: {due_count}</Badge>
                            </div>
                            <div>
                                <Badge variant="success">Mastered: {health.mastered}</Badge>
                            </div>
                            <div style="margin-top: 1rem;">
                                <a href="/review" class="my-link">Start a review session</a>
                            </div>
                        </CardBody>
                    </Card>
                </div>
            </div>

            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">↑ Top</button>
        }

        render_dashboard_js(&mut page)

        var html_out = page.toString()
        var bv = html_out.to_view()
        res.set_header_view(std::string_view("Content-Type"), &std::string_view("text/html; charset=utf-8"))
        res.write_view(&bv)
    }

}