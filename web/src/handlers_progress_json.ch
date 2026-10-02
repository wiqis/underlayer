// underlayer_web — Progress payload builder.  ALL the JSON, no SQL.
//
// WHY A SEPARATE FILE: handlers_progress.ch was already 372 lines, over the
// 250-line rule, and every field added here made that worse.  The builder
// lives alone so the field NAMES are in one readable place, which matters
// more than usual here because four of them were wrong.
//
// WHAT WAS WRONG WITH THE FIELD NAMES, measured 2026-10-02 against the
// running server:
//
//   progress_percentage  was (health_score * 100) where health_score is
//     mastered / rows-in-concept_states.  The denominator is what the learner
//     has already done, so it is 0/3 after three reads and the number cannot
//     move until a concept reaches "mastered", which nothing on the reading
//     path ever writes.  Now it is started / concepts-in-the-manifest.  The old
//     value is still on the wire, named mastery_percentage.
//
//   total_concepts, health_score, depth, breadth   were NEVER EMITTED, and
//     web/src/handlers_progress_page.ch reads all four.  That page therefore
//     rendered a hardcoded "24" (its own `|| 24` fallback firing) and a health
//     bar stuck at 0% for every learner on the platform.  All four are emitted
//     now, with the same names and the same units the page already expected:
//     health_score is a FRACTION (0..1), depth and breadth are 0..100.
//
//   course_id           was the literal "elf" regardless of the ?course_id=
//     the page was already sending.  Read from the query string, defaulting to
//     elf so an existing caller sees no change.
using std::string
using std::vector
using underlayer_db::DbClient
using underlayer_models::ConceptState

public namespace underlayer_web {

    // concepts_total: how many concepts the manifest says this course has.
    // 0 when the course has no manifest, which is the signal compute_course_coverage
    // uses to fall back to the row count rather than divide by nothing.
    public func manifest_concept_total(courses_dir : &string, course_id : &string) : int {
        var course = underlayer_repository::load_course(courses_dir, course_id)
        if(course.id.size() == 0) { return 0 }
        return course.concepts.size() as int
    }

    // The course_id to report on: the query string, else elf.
    public func progress_course_id(req : &http::Request) : string {
        var q = string("course_id")
        var v = req.query.get(&q.to_view())
        if(v.size() == 0) { return string("elf") }
        var cid = sv_to_string(&raw v)
        if(cid.size() == 0) { return string("elf") }
        return cid
    }

    public func append_coverage_json(
        body : *mut string,
        cov : &underlayer_learning::CourseCoverage,
        states : *vector<ConceptState>,
        health : &underlayer_learning::KnowledgeHealth
    ) {
        var depth = underlayer_learning::compute_depth_score(states)
        var breadth = underlayer_learning::compute_breadth_score(states, cov.concepts_total)
        body.append_view(",\"concepts_total\":")
        body.append_string(&underlayer_core::int_to_string(cov.concepts_total as i64))
        body.append_view(",\"concepts_started\":")
        body.append_string(&underlayer_core::int_to_string(cov.concepts_started as i64))
        body.append_view(",\"concepts_mastered\":")
        body.append_string(&underlayer_core::int_to_string(cov.concepts_mastered as i64))
        body.append_view(",\"concepts_due\":")
        body.append_string(&underlayer_core::int_to_string(cov.concepts_due as i64))
        // 6.1.3: progress = coverage.  Mastery is the other number, below.
        body.append_view(",\"progress_percentage\":")
        body.append_string(&underlayer_core::int_to_string(cov.progress_percentage as i64))
        body.append_view(",\"mastery_percentage\":")
        body.append_string(&underlayer_core::int_to_string(cov.mastery_percentage as i64))
        body.append_view(",\"total_source\":\"")
        body.append_string(&cov.source_total)
        body.append_view("\"")
        // health_score as a FRACTION: handlers_progress_page.ch does
        // Math.round(health * 100), and the dashboard prints
        // health.health_score * 100.0.  A 0-100 value here would print 9000%.
        body.append_view(",\"health_score\":")
        body.append_string(&underlayer_learning::f64_to_string(health.health_score))
        body.append_view(",\"depth\":")
        body.append_string(&underlayer_learning::f64_to_string(depth))
        body.append_view(",\"breadth\":")
        body.append_string(&underlayer_learning::f64_to_string(breadth))
        body.append_view(",\"unlearned\":")
        body.append_string(&underlayer_core::int_to_string(health.unlearned as i64))
    }

    // GET /api/me/overview — the one question the user actually asked:
    // which course am I taking, how far through it am I, and what have I got
    // wrong.  Three lists in one payload because the dashboard draws all three
    // at once and three round trips would make it flash between them.
    //
    // `courses` comes from enrollments, which the read path now writes, so it
    // is a list of courses the learner has actually OPENED -- not every course
    // in the collection with a zero on it, which is what "my courses" used to
    // mean everywhere else on the platform (a hardcoded elf).
    public func build_overview_json(db : *DbClient, courses_dir : &string, learner_id : &string) : string {
        var body = string("{\"learner_id\":\"")
        body.append_string(learner_id)
        body.append_view("\",\"courses\":[")
        var enrollments = underlayer_repository::get_learner_enrollments(db, learner_id)
        var total_started : i64 = 0
        var total_concepts : i64 = 0
        var i : size_t = 0
        while(i < enrollments.size()) {
            var e = enrollments.get_ptr(i)
            var cid = e.course_id.copy()
            var states = underlayer_repository::get_all_concept_states(db, learner_id, &cid)
            var total = manifest_concept_total(courses_dir, &cid)
            var cov = underlayer_learning::compute_course_coverage(&cid, &raw states, total)
            var course = underlayer_repository::load_course(courses_dir, &cid)
            var title = string("Underlayer")
            if(course.id.size() > 0) { title = course.title.copy() }
            if(i > 0) { body.append_view(",") }
            body.append_view("{\"course_id\":\"")
            body.append_string(&cid)
            body.append_view("\",\"title\":\"")
            var t_esc = underlayer_core::json_escape(&title.to_view())
            body.append_string(&t_esc)
            body.append_view("\",\"concepts_total\":")
            body.append_string(&underlayer_core::int_to_string(cov.concepts_total as i64))
            body.append_view(",\"concepts_started\":")
            body.append_string(&underlayer_core::int_to_string(cov.concepts_started as i64))
            body.append_view(",\"concepts_mastered\":")
            body.append_string(&underlayer_core::int_to_string(cov.concepts_mastered as i64))
            body.append_view(",\"concepts_due\":")
            body.append_string(&underlayer_core::int_to_string(cov.concepts_due as i64))
            body.append_view(",\"progress_percentage\":")
            body.append_string(&underlayer_core::int_to_string(cov.progress_percentage as i64))
            body.append_view(",\"mastery_percentage\":")
            body.append_string(&underlayer_core::int_to_string(cov.mastery_percentage as i64))
            body.append_view(",\"enrolled_at\":")
            body.append_string(&underlayer_core::int_to_string(e.enrolled_at))
            body.append_view(",\"last_accessed\":")
            body.append_string(&underlayer_core::int_to_string(e.last_accessed))
            body.append_view(",\"status\":\"")
            body.append_string(&e.status)
            body.append_view("\"}")
            total_started = total_started + (cov.concepts_started as i64)
            total_concepts = total_concepts + (cov.concepts_total as i64)
            i = i + 1
        }
        body.append_view("],\"courses_total\":")
        body.append_string(&underlayer_core::int_to_string(enrollments.size() as i64))
        body.append_view(",\"concepts_started_all\":")
        body.append_string(&underlayer_core::int_to_string(total_started))
        body.append_view(",\"concepts_total_all\":")
        body.append_string(&underlayer_core::int_to_string(total_concepts))
        body.append_view(",\"failed_exercises_count\":")
        var failed_n = underlayer_repository::count_failed_exercises(db, learner_id)
        body.append_string(&underlayer_core::int_to_string(failed_n as i64))
        body.append_view(",\"failed_exercises\":")
        append_failed_json(db, learner_id, &raw mut body)
        body.append_view("}")
        return body
    }

    // GET /api/exercises/failures — the same list on its own, so a page can
    // load just the failures without the whole overview.
    public func build_failures_json(db : *DbClient, learner_id : &string, limit : i64) : string {
        var body = string("{\"learner_id\":\"")
        body.append_string(learner_id)
        body.append_view("\",\"failed_exercises\":")
        append_failed_json(db, learner_id, &raw mut body)
        body.append_view("}")
        return body
    }

    // One row per MISSED exercise, most-missed first.  The question text comes
    // back with it so the dashboard can say what was missed without a second
    // request per row.
    func append_failed_json(db : *DbClient, learner_id : &string, body : *mut string) {
        var failed = underlayer_repository::get_failed_exercises(db, learner_id, 25)
        body.append_view("[")
        var i : size_t = 0
        while(i < failed.size()) {
            var f = failed.get_ptr(i)
            if(i > 0) { body.append_view(",") }
            body.append_view("{\"exercise_id\":\"")
            body.append_string(&f.exercise_id)
            body.append_view("\",\"concept_id\":\"")
            body.append_string(&f.concept_id)
            body.append_view("\",\"course_id\":\"")
            body.append_string(&f.course_id)
            body.append_view("\",\"misses\":")
            body.append_string(&underlayer_core::int_to_string(f.misses as i64))
            body.append_view(",\"last_missed\":")
            body.append_string(&underlayer_core::int_to_string(f.submitted_at))
            body.append_view(",\"question\":\"")
            var q_esc = underlayer_core::json_escape(&f.question.to_view())
            body.append_string(&q_esc)
            body.append_view("\",\"lesson_url\":\"/courses/")
            body.append_string(&f.course_id)
            body.append_view("/lessons/")
            body.append_string(&f.concept_id)
            body.append_view("\"}")
            i = i + 1
        }
        body.append_view("]")
    }

}